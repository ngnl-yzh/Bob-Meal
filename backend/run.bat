@echo off
echo ====================================
echo   식당 추천 API 서버 시작
echo ====================================
cd /d %~dp0
pip install -r requirements.txt --quiet
echo.
echo 서버 주소: http://127.0.0.1:8000
echo API 문서:  http://127.0.0.1:8000/docs
echo.
python -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
pause
