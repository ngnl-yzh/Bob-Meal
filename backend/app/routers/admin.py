"""
관리자 엔드포인트 — 식당 수집 등 운영 작업

보안:
  모든 관리자 API는 X-Admin-Key 헤더 검증 필요.
  Railway 환경변수 ADMIN_SECRET_KEY 에 임의 비밀값을 설정하세요.
  미설정 시 관리자 기능 비활성화.
"""
import json
import httpx
from fastapi import APIRouter, BackgroundTasks, HTTPException, Header
from fastapi.responses import JSONResponse, HTMLResponse
from app.config import get_settings

router = APIRouter(prefix="/admin", tags=["관리자"])
settings = get_settings()

# 수집 상태 추적 (메모리 + DB 영속화)
_collect_status: dict = {"running": False, "last": None, "count": 0}


def _load_collect_status():
    """서버 시작 시 DB에서 마지막 수집 상태 복원. 수집 중이었으면 '중단됨'으로 표시."""
    global _collect_status
    try:
        from app.database import SessionLocal
        from app.models import SystemSetting
        import json
        db = SessionLocal()
        try:
            row = db.query(SystemSetting).filter(SystemSetting.key == "last_collect").first()
            if row:
                saved = json.loads(row.value)
                # 이전에 "수집 중"이었으면 중단된 것
                last = saved.get("status", "")
                if last.startswith("수집 중:"):
                    last = f"⚠️ 중단됨: 배포/재시작으로 중단 (마지막 저장: {saved.get('count', 0):,}개)"
                _collect_status["last"] = last
                _collect_status["count"] = saved.get("count", 0)
        finally:
            db.close()
    except Exception:
        pass


# ─── 관리자 키 검증 ───────────────────────────────────────────────
def _verify_admin(x_admin_key: str = Header(..., alias="X-Admin-Key")):
    """
    X-Admin-Key 헤더로 관리자 인증.
    ADMIN_SECRET_KEY 환경변수가 설정돼 있어야 함.
    """
    if not settings.ADMIN_SECRET_KEY:
        raise HTTPException(
            status_code=503,
            detail=(
                "관리자 기능이 비활성화돼 있습니다. "
                "Railway 환경변수에 ADMIN_SECRET_KEY 를 설정하세요."
            ),
        )
    if x_admin_key != settings.ADMIN_SECRET_KEY:
        raise HTTPException(status_code=403, detail="관리자 키가 올바르지 않습니다.")


def _save_collect_status(status: str, count: int):
    """수집 상태를 DB에 저장 (서버 재시작 후에도 유지)"""
    try:
        from app.database import SessionLocal
        from app.models import SystemSetting
        db = SessionLocal()
        try:
            import json
            val = json.dumps({"status": status, "count": count}, ensure_ascii=False)
            row = db.query(SystemSetting).filter(SystemSetting.key == "last_collect").first()
            if row:
                row.value = val
            else:
                db.add(SystemSetting(key="last_collect", value=val))
            db.commit()
        finally:
            db.close()
    except Exception:
        pass  # DB 저장 실패해도 수집은 계속


def _run_collect(region: str, limit: int | None, mark_inactive: bool = False):
    """백그라운드 수집 실행"""
    global _collect_status
    _collect_status["running"] = True
    _collect_status["count"] = 0
    _collect_status["last"] = "수집 시작 중..."
    try:
        import sys, os
        # Railway: 실행 디렉토리가 backend/ 이므로 collect_restaurants.py 가 cwd에 있음
        backend_dir = os.getcwd()  # uvicorn 실행 위치 = backend/
        if backend_dir not in sys.path:
            sys.path.insert(0, backend_dir)

        # 혹시 모듈 캐시에 남아있으면 제거 후 재임포트
        if "collect_restaurants" in sys.modules:
            del sys.modules["collect_restaurants"]

        from collect_restaurants import collect

        if region == "all":
            regions = ["gwangju", "jeonnam"]
        else:
            regions = [region]  # bukgu / yongbong / gwangju / jeonnam
        count = collect(
            regions,
            limit=limit,
            progress_status=_collect_status,
            mark_inactive=mark_inactive,
        )
        _collect_status["count"] = count
        suffix = " (폐업 감지 활성화)" if mark_inactive else ""
        _collect_status["last"] = f"✅ 완료: {count:,}개 수집{suffix}"
        _save_collect_status(_collect_status["last"], count)
    except Exception as e:
        import traceback
        msg = f"❌ 오류: {e} | {traceback.format_exc()[-300:]}"
        _collect_status["last"] = msg
        _save_collect_status(msg, _collect_status.get("count", 0))
    finally:
        _collect_status["running"] = False


# ─── 관리자 웹 UI ─────────────────────────────────────────────────
_ADMIN_HTML = """<!DOCTYPE html>
<html lang="ko">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>한끼로그 관리자</title>
  <style>
    :root {
      --primary: #FF6B35;
      --bg: #f4f5f7;
      --card: #fff;
      --border: #e0e0e0;
      --text: #222;
      --muted: #888;
      --success: #22c55e;
      --error: #ef4444;
      --warning: #f59e0b;
    }
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body { font-family: -apple-system, 'Apple SD Gothic Neo', 'Noto Sans KR', sans-serif;
           background: var(--bg); color: var(--text); font-size: 14px; }

    /* ── Login ── */
    #login-overlay {
      position: fixed; inset: 0; background: #fff;
      display: flex; align-items: center; justify-content: center; z-index: 200;
    }
    .login-card {
      background: #fff; border-radius: 18px; padding: 48px 40px;
      box-shadow: 0 8px 32px rgba(0,0,0,.12); width: 360px; text-align: center;
    }
    .login-logo { font-size: 44px; margin-bottom: 10px; }
    .login-card h2 { font-size: 22px; margin-bottom: 6px; }
    .login-card p { color: var(--muted); margin-bottom: 28px; font-size: 13px; }
    .login-card input {
      width: 100%; padding: 12px 16px; border: 1.5px solid var(--border);
      border-radius: 10px; font-size: 15px; margin-bottom: 14px;
      outline: none; font-family: inherit; transition: border-color .15s;
    }
    .login-card input:focus { border-color: var(--primary); }
    #login-error { color: var(--error); margin-top: 10px; font-size: 13px; min-height: 18px; }

    /* ── Buttons ── */
    .btn {
      border: none; border-radius: 10px; padding: 11px 22px; font-size: 14px;
      font-weight: 600; cursor: pointer; font-family: inherit; transition: opacity .15s;
    }
    .btn-primary { background: var(--primary); color: #fff; width: 100%; }
    .btn-primary:hover { opacity: .88; }
    .btn-secondary {
      background: #f0f0f0; color: var(--text); border: none;
      border-radius: 9px; padding: 9px 18px; font-size: 13px;
      font-weight: 600; cursor: pointer; font-family: inherit;
    }
    .btn-secondary:hover { background: #e0e0e0; }
    .btn-danger { background: #fee2e2; color: #991b1b; }
    .btn-danger:hover { background: #fecaca; }
    .btn:disabled { opacity: .45; cursor: not-allowed; }

    /* ── Header ── */
    header {
      background: #fff; border-bottom: 1px solid var(--border);
      padding: 0 28px; height: 58px; display: flex; align-items: center;
      justify-content: space-between; position: sticky; top: 0; z-index: 50;
      box-shadow: 0 1px 4px rgba(0,0,0,.06);
    }
    header .logo { font-size: 18px; font-weight: 700; display: flex; align-items: center; gap: 8px; }
    .logout-btn {
      background: none; border: 1.5px solid var(--border); border-radius: 8px;
      padding: 6px 14px; cursor: pointer; font-size: 13px; font-family: inherit;
      color: var(--muted); transition: background .15s;
    }
    .logout-btn:hover { background: #f5f5f5; }

    /* ── Layout ── */
    main { max-width: 1380px; margin: 0 auto; padding: 24px 20px 40px; }
    #dashboard { display: none; }

    /* ── Stat Cards ── */
    .cards-row {
      display: grid; grid-template-columns: repeat(auto-fill, minmax(160px, 1fr));
      gap: 14px; margin-bottom: 22px;
    }
    .stat-card {
      background: #fff; border-radius: 14px; padding: 18px 20px;
      box-shadow: 0 1px 4px rgba(0,0,0,.07);
    }
    .stat-card .lbl { font-size: 11px; color: var(--muted); text-transform: uppercase;
                       letter-spacing: .5px; margin-bottom: 6px; }
    .stat-card .val { font-size: 26px; font-weight: 700; }
    .stat-card .sub { font-size: 11px; color: var(--muted); margin-top: 4px; }

    /* ── Section ── */
    .section {
      background: #fff; border-radius: 14px; padding: 22px 24px;
      margin-bottom: 20px; box-shadow: 0 1px 4px rgba(0,0,0,.07);
    }
    .section-title { font-size: 15px; font-weight: 700; margin-bottom: 16px;
                     display: flex; align-items: center; gap: 8px; }

    /* ── Collect Bar ── */
    .collect-row { display: flex; gap: 10px; align-items: center; flex-wrap: wrap; }
    .collect-row select, .collect-row input[type=number] {
      padding: 9px 12px; border: 1.5px solid var(--border); border-radius: 9px;
      font-size: 13px; font-family: inherit; outline: none; background: #fff;
      transition: border-color .15s;
    }
    .collect-row select:focus, .collect-row input:focus { border-color: var(--primary); }
    .collect-row label { font-size: 13px; display: flex; align-items: center; gap: 6px; cursor: pointer; }

    /* ── Status Pill ── */
    .status-wrap { margin-top: 14px; }
    .status-pill {
      display: inline-flex; align-items: center; gap: 8px;
      padding: 7px 16px; border-radius: 20px; font-size: 13px;
      background: var(--bg); max-width: 100%; word-break: break-all;
    }
    .status-pill.running { background: #fff3e0; color: #b45309; }
    .status-pill.done { background: #dcfce7; color: #166534; }
    .status-pill.error { background: #fee2e2; color: #991b1b; }
    .status-pill.warn { background: #fef9c3; color: #854d0e; }
    .spinner {
      display: inline-block; width: 13px; height: 13px;
      border: 2px solid currentColor; border-top-color: transparent;
      border-radius: 50%; animation: spin .7s linear infinite; flex-shrink: 0;
    }
    @keyframes spin { to { transform: rotate(360deg); } }

    /* ── Tabs ── */
    .tabs { display: flex; gap: 4px; margin-bottom: 16px; }
    .tab-btn {
      background: none; border: none; padding: 8px 18px; border-radius: 8px;
      cursor: pointer; font-size: 13px; font-weight: 500; color: var(--muted);
      font-family: inherit; transition: background .15s;
    }
    .tab-btn.active { background: var(--primary); color: #fff; }
    .tab-btn:hover:not(.active) { background: #ebebeb; }

    /* ── Toolbar ── */
    .toolbar {
      display: flex; gap: 8px; margin-bottom: 14px;
      align-items: center; flex-wrap: wrap;
    }
    .toolbar input, .toolbar select {
      padding: 8px 13px; border: 1.5px solid var(--border); border-radius: 9px;
      font-size: 13px; font-family: inherit; outline: none; background: #fff;
      transition: border-color .15s;
    }
    .toolbar input:focus, .toolbar select:focus { border-color: var(--primary); }
    .toolbar input { min-width: 200px; }
    .result-count { font-size: 12px; color: var(--muted); margin-left: auto; }

    /* ── Table ── */
    .table-wrap { overflow-x: auto; }
    table { width: 100%; border-collapse: collapse; font-size: 13px; }
    thead th {
      text-align: left; padding: 9px 12px; color: var(--muted);
      font-weight: 600; font-size: 11px; text-transform: uppercase;
      border-bottom: 2px solid var(--border); background: #fafafa;
      white-space: nowrap; cursor: pointer; user-select: none;
    }
    thead th:hover { background: #f0f0f0; }
    tbody td { padding: 9px 12px; border-bottom: 1px solid #f0f0f0; vertical-align: middle; }
    tbody tr:hover { background: #fafbff; }
    tbody tr.row-inactive { opacity: .5; }
    .cell-name { font-weight: 600; }
    .cell-addr {
      color: var(--muted); font-size: 12px; max-width: 200px;
      overflow: hidden; text-overflow: ellipsis; white-space: nowrap;
    }

    /* ── Badges ── */
    .badge {
      display: inline-block; padding: 2px 8px; border-radius: 10px;
      font-size: 11px; font-weight: 600; white-space: nowrap;
    }
    .badge-ok   { background: #dcfce7; color: #166534; }
    .badge-off  { background: #fee2e2; color: #991b1b; }
    .badge-cat  { background: #e0f2fe; color: #075985; }
    .badge-menu { background: #f3e8ff; color: #6b21a8; }
    .naver-link { color: #009900; text-decoration: none; font-size: 11px; }
    .naver-link:hover { text-decoration: underline; }
    .no-val { color: #ccc; font-size: 11px; }

    /* ── Pagination ── */
    .pagination { display: flex; gap: 5px; justify-content: center; margin-top: 16px; flex-wrap: wrap; }
    .page-btn {
      background: #fff; border: 1.5px solid var(--border); border-radius: 7px;
      padding: 5px 11px; cursor: pointer; font-size: 13px; font-family: inherit;
      transition: background .12s;
    }
    .page-btn.active { background: var(--primary); color: #fff; border-color: var(--primary); }
    .page-btn:hover:not(.active) { background: #f0f0f0; }

    .empty-msg { text-align: center; padding: 40px; color: var(--muted); }
    .loading-msg { text-align: center; padding: 48px; color: var(--muted); }
  </style>
</head>
<body>

<!-- ── 로그인 오버레이 ── -->
<div id="login-overlay">
  <div class="login-card">
    <div class="login-logo">🍚</div>
    <h2>한끼로그 관리자</h2>
    <p>관리자 키를 입력하세요</p>
    <input type="password" id="key-input" placeholder="X-Admin-Key" />
    <button class="btn btn-primary" onclick="doLogin()">로그인</button>
    <div id="login-error"></div>
  </div>
</div>

<!-- ── 대시보드 ── -->
<div id="dashboard">
  <header>
    <div class="logo">🍚 한끼로그 관리자</div>
    <button class="logout-btn" onclick="doLogout()">로그아웃</button>
  </header>
  <main>

    <!-- 연구 범위 배너 -->
    <div style="background:#fff3e0;border-left:4px solid #FF6B35;border-radius:10px;padding:12px 18px;margin-bottom:18px;display:flex;align-items:center;gap:10px;font-size:13px;">
      <span style="font-size:18px;">🔬</span>
      <span><strong>연구 단계</strong> — 서비스 범위: <strong>광주광역시 북구</strong>
        (위도 35.13~35.28 · 경도 126.83~127.02)</span>
    </div>

    <!-- 통계 카드 -->
    <div class="cards-row">
      <div class="stat-card">
        <div class="lbl">전체 식당</div>
        <div class="val" id="s-total">-</div>
      </div>
      <div class="stat-card">
        <div class="lbl">활성</div>
        <div class="val" id="s-active" style="color:var(--success)">-</div>
      </div>
      <div class="stat-card">
        <div class="lbl">비활성(폐업추정)</div>
        <div class="val" id="s-inactive" style="color:var(--error)">-</div>
      </div>
      <div class="stat-card">
        <div class="lbl">가입 유저</div>
        <div class="val" id="s-users">-</div>
      </div>
      <div class="stat-card">
        <div class="lbl">메뉴 수집 식당</div>
        <div class="val" id="s-menu" style="color:#7c3aed">-</div>
      </div>
      <div class="stat-card">
        <div class="lbl">네이버 연동</div>
        <div class="val" id="s-naver" style="color:#009900">-</div>
      </div>
    </div>

    <!-- 수집 제어 -->
    <div class="section">
      <div class="section-title">📥 데이터 수집</div>
      <div class="collect-row">
        <select id="c-region">
          <option value="bukgu" selected>🔬 광주 북구 (연구 범위)</option>
          <option value="yongbong">🔍 용봉동 (세밀 수집)</option>
          <option value="gwangju">광주 전체</option>
          <option value="jeonnam">전남</option>
          <option value="all">전체 (광주 + 전남)</option>
        </select>
        <input type="number" id="c-limit" placeholder="최대 건수 (기본: 전체)" min="1" max="99999" style="width:190px" />
        <label>
          <input type="checkbox" id="c-inactive" />
          폐업 감지 활성화
        </label>
        <button class="btn btn-secondary" id="c-btn" onclick="startCollect()" style="background:var(--primary);color:#fff;">수집 시작</button>
        <button class="btn btn-secondary" onclick="loadAll()">새로고침</button>
      </div>
      <div class="status-wrap" id="status-wrap"></div>
    </div>

    <!-- 식당 목록 -->
    <div class="section">
      <div class="section-title">🏪 수집된 식당</div>

      <div class="tabs">
        <button class="tab-btn active" onclick="setTab('bukgu',this)">🔬 광주 북구</button>
        <button class="tab-btn" onclick="setTab('yongbong',this)">용봉동</button>
        <button class="tab-btn" onclick="setTab('all',this)">전체</button>
        <button class="tab-btn" onclick="setTab('광주',this)">광주</button>
        <button class="tab-btn" onclick="setTab('전남',this)">전남</button>
        <button class="tab-btn" onclick="setTab('기타',this)">기타</button>
      </div>

      <div class="toolbar">
        <input id="q-name" placeholder="식당명 / 주소 검색..." oninput="renderTable()" />
        <select id="q-cat" onchange="renderTable()">
          <option value="">카테고리 전체</option>
          <option>한식</option><option>중식</option><option>일식</option>
          <option>분식</option><option>카페</option><option>양식</option><option>패스트푸드</option>
        </select>
        <select id="q-dong" onchange="renderTable()">
          <option value="">동/읍/면 전체</option>
        </select>
        <select id="q-active" onchange="renderTable()">
          <option value="">활성+비활성</option>
          <option value="1">활성만</option>
          <option value="0">비활성만</option>
        </select>
        <span class="result-count" id="r-count"></span>
      </div>

      <div class="table-wrap">
        <table>
          <thead>
            <tr>
              <th onclick="sortBy('name')">이름 ↕</th>
              <th onclick="sortBy('category')">카테고리</th>
              <th>지역</th>
              <th onclick="sortBy('_dong')">동/읍/면 ↕</th>
              <th>주소</th>
              <th onclick="sortBy('price')">가격 ↕</th>
              <th onclick="sortBy('rating')">평점 ↕</th>
              <th onclick="sortBy('menu_count')">메뉴 ↕</th>
              <th>네이버</th>
              <th onclick="sortBy('is_active')">상태 ↕</th>
            </tr>
          </thead>
          <tbody id="t-body"></tbody>
        </table>
      </div>
      <div id="t-loading" class="loading-msg" style="display:none">불러오는 중...</div>
      <div class="pagination" id="t-pages"></div>
    </div>

  </main>
</div>

<script>
const PER_PAGE = 50;
let adminKey = sessionStorage.getItem('hkAdminKey') || '';
let allData = [];
let filtered = [];
let curRegion = 'bukgu'; // 연구 단계 기본값
let curPage = 1;
let sortField = 'name';
let sortAsc = true;
let pollTimer = null;

// ── 로그인 ───────────────────────────────────────────
async function doLogin() {
  const key = document.getElementById('key-input').value.trim();
  if (!key) return;
  const resp = await fetch('/admin/stats', { headers: { 'X-Admin-Key': key } });
  if (resp.ok) {
    sessionStorage.setItem('hkAdminKey', key);
    adminKey = key;
    show();
    const d = await resp.json();
    applyStats(d);
    loadAll();
  } else {
    document.getElementById('login-error').textContent = '관리자 키가 올바르지 않습니다.';
  }
}
document.getElementById('key-input').addEventListener('keydown', e => { if (e.key === 'Enter') doLogin(); });

function doLogout() {
  sessionStorage.removeItem('hkAdminKey');
  location.reload();
}

function show() {
  document.getElementById('login-overlay').style.display = 'none';
  document.getElementById('dashboard').style.display = 'block';
}

// 자동 로그인
(async () => {
  if (!adminKey) return;
  const resp = await fetch('/admin/stats', { headers: { 'X-Admin-Key': adminKey } });
  if (resp.ok) {
    show();
    applyStats(await resp.json());
    loadAll();
  } else {
    sessionStorage.removeItem('hkAdminKey');
  }
})();

// ── 통계 ─────────────────────────────────────────────
function applyStats(d) {
  set('s-total',    fmt(d.restaurants));
  set('s-active',   fmt(d.restaurants_active));
  set('s-inactive', fmt(d.restaurants_inactive));
  set('s-users',    fmt(d.users));
}

function updateMenuNaverStats() {
  const withMenu  = allData.filter(r => (r.menu_count || 0) > 0).length;
  const withNaver = allData.filter(r => r.naver_place_id).length;
  set('s-menu',  fmt(withMenu));
  set('s-naver', fmt(withNaver));
}

// ── 수집 ─────────────────────────────────────────────
async function startCollect() {
  const region = v('c-region');
  const limit  = v('c-limit');
  const mark   = document.getElementById('c-inactive').checked;
  let url = '/admin/collect?region=' + region;
  if (limit) url += '&limit=' + limit;
  if (mark)  url += '&mark_inactive=true';
  const resp = await fetch(url, { method: 'POST', headers: { 'X-Admin-Key': adminKey } });
  if (resp.ok) {
    document.getElementById('c-btn').disabled = true;
    startPolling();
  } else {
    const err = await resp.json().catch(() => ({}));
    alert('오류: ' + (err.detail || '알 수 없는 오류'));
  }
}

function startPolling() {
  if (pollTimer) clearInterval(pollTimer);
  checkStatus();
  pollTimer = setInterval(async () => {
    const running = await checkStatus();
    if (!running) {
      clearInterval(pollTimer);
      pollTimer = null;
      document.getElementById('c-btn').disabled = false;
      loadAll();
      fetch('/admin/stats', { headers: { 'X-Admin-Key': adminKey } })
        .then(r => r.ok && r.json()).then(d => d && applyStats(d));
    }
  }, 3000);
}

async function checkStatus() {
  const resp = await fetch('/admin/collect/status', { headers: { 'X-Admin-Key': adminKey } });
  if (!resp.ok) return false;
  const d = await resp.json();
  const msg = d.last || '없음';
  let cls = 'status-pill';
  if (d.running)             cls += ' running';
  else if (msg.startsWith('✅')) cls += ' done';
  else if (msg.startsWith('❌')) cls += ' error';
  else if (msg.startsWith('⚠️')) cls += ' warn';

  const countStr = d.count ? ` &nbsp;(${fmt(d.count)}개)` : '';
  document.getElementById('status-wrap').innerHTML =
    `<span class="${cls}">${d.running ? '<span class="spinner"></span>' : ''}${escH(msg)}${countStr}</span>`;
  return d.running;
}

// ── 데이터 로드 ────────────────────────────────────────
async function loadAll() {
  document.getElementById('t-loading').style.display = 'block';
  document.getElementById('t-body').innerHTML = '';
  document.getElementById('t-pages').innerHTML = '';

  const resp = await fetch('/admin/restaurants', { headers: { 'X-Admin-Key': adminKey } });
  document.getElementById('t-loading').style.display = 'none';
  if (!resp.ok) return;
  const data = await resp.json();

  // 주소 파싱 및 캐싱
  allData = (data.restaurants || []).map(r => {
    const p = parseAddr(r.address || '');
    return { ...r, _region: p.region, _dong: p.dong };
  });

  updateMenuNaverStats();
  populateDongFilter();
  renderTable();
  checkStatus();
}

// ── 주소 파싱 ─────────────────────────────────────────
function parseAddr(addr) {
  let region = '기타';
  if (addr.includes('광주광역시') || /^광주\s/.test(addr)) region = '광주';
  else if (addr.includes('전라남도') || /^전남\s/.test(addr)) region = '전남';

  // 동/읍/면 추출 — "북구 용봉동" → "용봉동"
  const m = addr.match(/([가-힣]+[동읍면])/g);
  // 마지막 매치가 실제 동 (앞쪽은 구/시 이름일 수 있음)
  const dong = m && m.length > 0 ? m[m.length - 1] : '-';
  return { region, dong };
}

// ── 필터 드롭다운 ──────────────────────────────────────
function populateDongFilter() {
  let base;
  if (curRegion === 'bukgu') {
    base = allData.filter(r =>
      (r.address || '').includes('북구') ||
      (r.lat >= 35.13 && r.lat <= 35.28 && r.lng >= 126.83 && r.lng <= 127.02)
    );
  } else if (curRegion === 'yongbong') {
    base = allData.filter(r =>
      (r.address || '').includes('용봉동') ||
      (r.lat >= 35.158 && r.lat <= 35.194 && r.lng >= 126.884 && r.lng <= 126.934)
    );
  } else if (curRegion === 'all') {
    base = allData;
  } else {
    base = allData.filter(r => r._region === curRegion);
  }
  const dongs = [...new Set(base.map(r => r._dong))].filter(d => d !== '-').sort();
  const sel = document.getElementById('q-dong');
  sel.innerHTML = '<option value="">동/읍/면 전체</option>' +
    dongs.map(d => `<option>${escH(d)}</option>`).join('');
}

// ── 탭 ───────────────────────────────────────────────
function setTab(region, btn) {
  curRegion = region; curPage = 1;
  document.querySelectorAll('.tab-btn').forEach(b => b.classList.remove('active'));
  btn.classList.add('active');
  populateDongFilter();
  renderTable();
}

// ── 정렬 ─────────────────────────────────────────────
function sortBy(field) {
  if (sortField === field) sortAsc = !sortAsc;
  else { sortField = field; sortAsc = true; }
  curPage = 1;
  renderTable();
}

// ── 렌더 ─────────────────────────────────────────────
function getFiltered() {
  const q      = v('q-name').toLowerCase();
  const cat    = v('q-cat');
  const dong   = v('q-dong');
  const active = v('q-active');

  let list = allData;
  if (curRegion === 'bukgu') {
    // 연구 범위: 주소에 북구 포함 OR 북구 bbox 내 좌표
    list = list.filter(r =>
      (r.address || '').includes('북구') ||
      (r.lat >= 35.13 && r.lat <= 35.28 && r.lng >= 126.83 && r.lng <= 127.02)
    );
  } else if (curRegion === 'yongbong') {
    list = list.filter(r =>
      (r.address || '').includes('용봉동') ||
      (r.lat >= 35.158 && r.lat <= 35.194 && r.lng >= 126.884 && r.lng <= 126.934)
    );
  } else if (curRegion !== 'all') {
    list = list.filter(r => r._region === curRegion);
  }
  if (q)      list = list.filter(r => (r.name||'').toLowerCase().includes(q) || (r.address||'').toLowerCase().includes(q));
  if (cat)    list = list.filter(r => r.category === cat);
  if (dong)   list = list.filter(r => r._dong === dong);
  if (active === '1') list = list.filter(r => r.is_active);
  if (active === '0') list = list.filter(r => !r.is_active);

  // 정렬
  list = [...list].sort((a, b) => {
    let va = a[sortField] ?? '', vb = b[sortField] ?? '';
    if (typeof va === 'string') { va = va.toLowerCase(); vb = (vb||'').toLowerCase(); }
    if (va < vb) return sortAsc ? -1 :  1;
    if (va > vb) return sortAsc ?  1 : -1;
    return 0;
  });
  return list;
}

function renderTable() {
  filtered = getFiltered();
  set('r-count', fmt(filtered.length) + '개');

  const start = (curPage - 1) * PER_PAGE;
  const page  = filtered.slice(start, start + PER_PAGE);

  const tbody = document.getElementById('t-body');
  if (page.length === 0) {
    tbody.innerHTML = `<tr><td colspan="10" class="empty-msg">검색 결과가 없습니다</td></tr>`;
  } else {
    tbody.innerHTML = page.map(r => {
      const price = r.price ? fmt(r.price) + '원' : '<span class="no-val">-</span>';
      const rating = r.rating ? r.rating.toFixed(1) + ' ⭐' : '<span class="no-val">-</span>';
      const menuEl = (r.menu_count||0) > 0
        ? `<span class="badge badge-menu">${r.menu_count}개</span>`
        : '<span class="no-val">-</span>';
      const naverEl = r.naver_place_id
        ? `<a class="naver-link" href="https://map.naver.com/v5/entry/place/${r.naver_place_id}" target="_blank">🗺️ ${r.naver_place_id}</a>`
        : '<span class="no-val">-</span>';
      const statusEl = r.is_active
        ? '<span class="badge badge-ok">활성</span>'
        : '<span class="badge badge-off">비활성</span>';
      return `<tr class="${r.is_active ? '' : 'row-inactive'}">
        <td class="cell-name">${escH(r.name||'')}</td>
        <td><span class="badge badge-cat">${escH(r.category||'')}</span></td>
        <td>${r._region}</td>
        <td>${r._dong}</td>
        <td class="cell-addr" title="${escH(r.address||'')}">${escH(r.address||'-')}</td>
        <td>${price}</td>
        <td>${rating}</td>
        <td>${menuEl}</td>
        <td>${naverEl}</td>
        <td>${statusEl}</td>
      </tr>`;
    }).join('');
  }

  renderPages();
}

function renderPages() {
  const total = filtered.length;
  const pages = Math.ceil(total / PER_PAGE);
  const el = document.getElementById('t-pages');
  if (pages <= 1) { el.innerHTML = ''; return; }

  let html = '';
  const lo = Math.max(1, curPage - 3);
  const hi = Math.min(pages, curPage + 3);
  if (curPage > 1) html += pg('‹', curPage - 1);
  if (lo > 1) { html += pg('1', 1); if (lo > 2) html += '<span style="padding:0 4px">…</span>'; }
  for (let i = lo; i <= hi; i++) html += pg(i, i, i === curPage);
  if (hi < pages) { if (hi < pages-1) html += '<span style="padding:0 4px">…</span>'; html += pg(pages, pages); }
  if (curPage < pages) html += pg('›', curPage + 1);
  el.innerHTML = html;
}

function pg(label, n, active) {
  return `<button class="page-btn${active?' active':''}" onclick="goPage(${n})">${label}</button>`;
}
function goPage(n) { curPage = n; renderTable(); window.scrollTo(0,0); }

// ── 유틸 ─────────────────────────────────────────────
function v(id) { return document.getElementById(id).value; }
function set(id, txt) { const el = document.getElementById(id); if (el) el.innerHTML = txt; }
function fmt(n) { return Number(n).toLocaleString('ko-KR'); }
function escH(s) {
  return String(s||'')
    .replace(/&/g,'&amp;').replace(/</g,'&lt;')
    .replace(/>/g,'&gt;').replace(/"/g,'&quot;');
}
</script>
</body>
</html>"""


@router.get("/ui", response_class=HTMLResponse, include_in_schema=False, summary="관리자 웹 UI")
def admin_ui():
    """관리자 웹 대시보드 (브라우저에서 직접 접속)"""
    return HTMLResponse(content=_ADMIN_HTML)


@router.post("/collect", summary="식당 데이터 수집 시작")
def start_collect(
    background_tasks: BackgroundTasks,
    region: str = "bukgu",         # bukgu (기본) / yongbong / gwangju / jeonnam / all
    limit: int | None = None,
    mark_inactive: bool = False,  # True = 수집 후 미발견 식당 비활성화 (3개월 주기 재수집용)
    x_admin_key: str = Header(..., alias="X-Admin-Key"),
):
    """
    카카오 로컬 API로 식당 데이터를 수집합니다.
    백그라운드로 실행되며 즉시 응답을 반환합니다.

    - **region**: yongbong (기본·연구 범위) / gwangju / jeonnam / all
    - **limit**: 최대 수집 건수 (생략하면 무제한)
    - **mark_inactive**: True 시 이번 수집에서 발견되지 않은 식당을 폐업·이전으로 처리
      → region=all 로 **전체 수집** 후에만 사용하세요

    헤더: `X-Admin-Key: {ADMIN_SECRET_KEY 값}`
    """
    _verify_admin(x_admin_key)

    if not settings.KAKAO_REST_API_KEY:
        raise HTTPException(
            status_code=500,
            detail="KAKAO_REST_API_KEY 가 설정되지 않았습니다. Railway 환경변수를 확인하세요."
        )
    if _collect_status["running"]:
        raise HTTPException(status_code=409, detail="이미 수집 중입니다. /admin/collect/status 확인")

    background_tasks.add_task(_run_collect, region, limit, mark_inactive)
    return {
        "message": f"수집 시작 ({region}){' — 폐업 감지 활성화' if mark_inactive else ''}",
        "status_url": "/admin/collect/status",
    }


@router.get("/collect/status", summary="수집 상태 확인")
def collect_status(x_admin_key: str = Header(..., alias="X-Admin-Key")):
    """현재 수집 진행 상태를 반환합니다. 서버 재시작 후에도 마지막 결과를 표시합니다."""
    _verify_admin(x_admin_key)
    if not _collect_status["running"] and _collect_status["last"] is None:
        _load_collect_status()
    return _collect_status


@router.get("/restaurants", summary="식당 목록 (관리자용, 메뉴수 포함)")
def list_restaurants_admin(
    x_admin_key: str = Header(..., alias="X-Admin-Key"),
):
    """
    수집된 식당 전체 목록을 반환합니다.
    메뉴 수, 네이버 연동 여부, 활성 상태 등 운영 정보 포함.
    """
    _verify_admin(x_admin_key)
    from app.database import SessionLocal
    from app.models import Restaurant, Menu
    from sqlalchemy import func as sql_func

    db = SessionLocal()
    try:
        rows = (
            db.query(Restaurant, sql_func.count(Menu.id).label("menu_count"))
            .outerjoin(Menu, Menu.restaurant_id == Restaurant.id)
            .group_by(Restaurant.id)
            .order_by(Restaurant.name)
            .all()
        )
        data = []
        for r, menu_count in rows:
            data.append({
                "id": r.id,
                "name": r.name,
                "category": r.category,
                "address": r.address,
                "price": r.price,
                "rating": r.rating,
                "review_count": r.review_count,
                "naver_place_id": r.naver_place_id or "",
                "is_active": r.is_active,
                "menu_count": menu_count,
                "last_seen_at": r.last_seen_at.isoformat() if r.last_seen_at else None,
                "created_at": r.created_at.isoformat() if r.created_at else None,
            })
        return {"count": len(data), "restaurants": data}
    finally:
        db.close()


@router.delete("/restaurants/all", summary="식당 데이터 전체 삭제 (재수집용)")
def delete_all_restaurants(
    confirm: str = "",
    x_admin_key: str = Header(..., alias="X-Admin-Key"),
):
    """
    식당 데이터를 전부 삭제합니다. 재수집 전 초기화 용도.

    **반드시** `?confirm=DELETE_ALL` 파라미터를 붙여야 실행됩니다.
    실수로 호출해도 데이터가 삭제되지 않도록 보호합니다.
    """
    _verify_admin(x_admin_key)
    if confirm != "DELETE_ALL":
        raise HTTPException(
            status_code=400,
            detail="?confirm=DELETE_ALL 파라미터를 추가해야 삭제됩니다. (실수 방지)"
        )
    from app.database import SessionLocal
    from app.models import Restaurant
    db = SessionLocal()
    try:
        count = db.query(Restaurant).count()
        db.query(Restaurant).delete()
        db.commit()
        return {"deleted": count, "message": f"{count:,}개 삭제 완료. 이제 /admin/collect 로 재수집하세요."}
    finally:
        db.close()


@router.get("/stats", summary="DB 통계")
def db_stats(x_admin_key: str = Header(..., alias="X-Admin-Key")):
    """식당/유저 수 등 간단한 통계"""
    _verify_admin(x_admin_key)
    from app.database import SessionLocal
    from app.models import Restaurant, User
    db = SessionLocal()
    try:
        total      = db.query(Restaurant).count()
        active     = db.query(Restaurant).filter(Restaurant.is_active == True).count()
        inactive   = total - active
        return {
            "restaurants": total,
            "restaurants_active": active,
            "restaurants_inactive": inactive,
            "users": db.query(User).count(),
        }
    finally:
        db.close()


@router.get("/test-kakao", summary="카카오 API 키 테스트")
def test_kakao(x_admin_key: str = Header(..., alias="X-Admin-Key")):
    """
    카카오 로컬 API 키가 올바른지 테스트합니다.
    광주 중심부 1개 좌표로 실제 API 호출 후 전체 응답을 반환합니다.
    """
    _verify_admin(x_admin_key)

    if not settings.KAKAO_REST_API_KEY:
        return {"error": "KAKAO_REST_API_KEY 미설정"}

    url = "https://dapi.kakao.com/v2/local/search/category.json"
    params = {
        "category_group_code": "FD6",
        "x": 126.9162,
        "y": 35.1468,
        "radius": 500,
        "page": 1,
        "size": 3,
    }
    headers = {"Authorization": f"KakaoAK {settings.KAKAO_REST_API_KEY}"}

    try:
        with httpx.Client(timeout=10.0) as client:
            resp = client.get(url, params=params, headers=headers)
        return {
            "status_code": resp.status_code,
            "kakao_key_used": settings.KAKAO_REST_API_KEY[:8] + "...",  # 앞 8자리만 표시
            "response_body": resp.json() if resp.headers.get("content-type", "").startswith("application/json") else resp.text[:500],
        }
    except Exception as e:
        return {"error": str(e)}


@router.get("/backup/restaurants", summary="식당 데이터 JSON 백업")
def backup_restaurants(
    x_admin_key: str = Header(..., alias="X-Admin-Key"),
    limit: int = 10000,
):
    """
    식당 데이터를 JSON 형태로 내보냅니다. (데이터 보존용)
    Railway 재배포 전 이 엔드포인트로 백업하세요.

    헤더: `X-Admin-Key: {ADMIN_SECRET_KEY 값}`
    """
    _verify_admin(x_admin_key)
    from app.database import SessionLocal
    from app.models import Restaurant
    db = SessionLocal()
    try:
        rows = db.query(Restaurant).limit(limit).all()
        data = []
        for r in rows:
            data.append({
                "id": r.id,
                "name": r.name,
                "category": r.category,
                "address": r.address,
                "lat": r.lat,
                "lng": r.lng,
                "phone": r.phone or "",
                "hours": r.hours or "",
                "open_hour": r.open_hour,
                "close_hour": r.close_hour,
                "has_alcohol": r.has_alcohol,
                "meal_times": r.meal_times,
                "rating": r.rating,
                "review_count": r.review_count,
                "price": r.price,
                "price_confidence": r.price_confidence,
                "crowd_level": r.crowd_level,
                "tags": r.tags,
                "features": r.features,
                "schedule_json": r.schedule_json,
                "hero_icon": r.hero_icon,
                "hero_hue": r.hero_hue,
                "photo_url": r.photo_url or "",
                "naver_place_id": r.naver_place_id or "",
            })
        return JSONResponse(
            content={"count": len(data), "restaurants": data},
            headers={"Content-Disposition": "attachment; filename=restaurants_backup.json"},
        )
    finally:
        db.close()
