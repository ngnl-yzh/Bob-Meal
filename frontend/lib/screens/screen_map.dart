// 화면 — 주변 식당 지도
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../models/restaurant.dart';
import '../services/api_service.dart';
import '../config.dart';
import '../theme.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/crowd_badge.dart';

class ScreenMap extends StatefulWidget {
  final int navIndex;
  final ValueChanged<int> onNavTap;
  final ValueChanged<String> onPickRestaurant;

  const ScreenMap({
    super.key,
    required this.navIndex,
    required this.onNavTap,
    required this.onPickRestaurant,
  });

  @override
  State<ScreenMap> createState() => _ScreenMapState();
}

class _ScreenMapState extends State<ScreenMap> {
  List<RestaurantMapItem> _restaurants = [];
  bool _loading = true;
  String? _error;
  double? _userLat;
  double? _userLng;
  RestaurantMapItem? _selected;
  String _filterCategory = '전체';
  final MapController _mapCtrl = MapController();

  static const _categories = ['전체', '한식', '일식', '중식', '양식', '분식', '카페'];

  // 카테고리별 색상
  static const _catColors = {
    '한식': Color(0xFFEF4444),
    '일식': Color(0xFF3B82F6),
    '중식': Color(0xFFF97316),
    '양식': Color(0xFF10B981),
    '분식': Color(0xFFF59E0B),
    '카페': Color(0xFF8B5CF6),
  };

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _getLocation();
    // GPS 성공 여부와 관계없이 용봉동 식당 로드 (실패 시 중심 좌표로 폴백)
    await _loadRestaurants();
  }

  Future<void> _getLocation() async {
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) {
        if (mounted) setState(() { _error = 'location_denied'; _loading = false; });
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      ).timeout(const Duration(seconds: 10));
      if (mounted) setState(() { _userLat = pos.latitude; _userLng = pos.longitude; });
    } catch (_) {
      if (mounted) setState(() { _error = 'location_error'; _loading = false; });
    }
  }

  Future<void> _loadRestaurants() async {
    // GPS 미취득 시 용봉동 중심으로 폴백
    final queryLat = _userLat ?? AppConfig.focusLat;
    final queryLng = _userLng ?? AppConfig.focusLng;
    try {
      setState(() { _loading = true; _error = null; });
      final list = await ApiService.instance.getNearbyRestaurants(
        lat: queryLat,
        lng: queryLng,
        radiusM: AppConfig.focusRadiusM,
      );
      if (mounted) setState(() { _restaurants = list; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  List<RestaurantMapItem> get _filtered => _filterCategory == '전체'
      ? _restaurants
      : _restaurants.where((r) => r.category == _filterCategory).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(child: _buildBody()),
          AppBottomNav(currentIndex: widget.navIndex, onTap: widget.onNavTap),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: kCard,
      padding: EdgeInsets.fromLTRB(
          16, MediaQuery.of(context).padding.top + 10, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('주변 식당',
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: kInk,
                    letterSpacing: -0.4,
                  )),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: kBrand.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(AppConfig.focusAreaName,
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: kBrand,
                    )),
              ),
              const SizedBox(width: 4),
              if (!_loading && _restaurants.isNotEmpty)
                Text('${_filtered.length}개',
                    style: const TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 13,
                      color: kInk3,
                      fontWeight: FontWeight.w500,
                    )),
              const Spacer(),
              if (!_loading)
                GestureDetector(
                  onTap: _loadRestaurants,
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: kBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.refresh_rounded, size: 16, color: kInk2),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          // 카테고리 필터
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (_, i) {
                final cat = _categories[i];
                final active = _filterCategory == cat;
                return GestureDetector(
                  onTap: () => setState(() {
                    _filterCategory = cat;
                    _selected = null;
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: active ? kBrand : kBg,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: active ? kBrand : const Color(0xFFE5E7EB),
                      ),
                    ),
                    child: Text(cat,
                        style: TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: active ? Colors.white : kInk2,
                        )),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: kBrand, strokeWidth: 2.5),
            SizedBox(height: 14),
            Text('주변 식당 불러오는 중...',
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 13,
                  color: kInk2,
                )),
          ],
        ),
      );
    }

    if (_error == 'location_denied') {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.location_off_rounded, size: 48, color: kInk3),
              const SizedBox(height: 16),
              const Text('위치 권한이 필요해요',
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: kInk,
                  )),
              const SizedBox(height: 8),
              const Text('설정 앱에서 위치 권한을 허용해주세요',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: 'Pretendard', fontSize: 13, color: kInk2)),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 48, color: kInk3),
            const SizedBox(height: 16),
            const Text('불러오기 실패',
                style: TextStyle(fontFamily: 'Pretendard', fontSize: 15, fontWeight: FontWeight.w700, color: kInk)),
            const SizedBox(height: 8),
            OutlinedButton(onPressed: _loadRestaurants, child: const Text('다시 시도')),
          ],
        ),
      );
    }

    return Stack(
      children: [
        // 지도
        FlutterMap(
          mapController: _mapCtrl,
          options: MapOptions(
            initialCenter: _userLat != null
                ? LatLng(_userLat!, _userLng!)
                : const LatLng(AppConfig.focusLat, AppConfig.focusLng),
            initialZoom: 15.0, // 용봉동 단위 — 더 좁게
            onTap: (_, __) => setState(() => _selected = null),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.hankkirog.hankkirog',
            ),
            // 식당 마커
            MarkerLayer(
              markers: [
                // 내 위치
                if (_userLat != null)
                  Marker(
                    point: LatLng(_userLat!, _userLng!),
                    width: 20,
                    height: 20,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2.5),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF3B82F6).withOpacity(0.4),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  ),
                // 식당 핀
                ..._filtered.map((r) {
                  final isSelected = _selected?.id == r.id;
                  final color = _catColors[r.category] ?? kBrand;
                  return Marker(
                    point: LatLng(r.lat, r.lng),
                    width: isSelected ? 44 : 36,
                    height: isSelected ? 44 : 36,
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _selected = r);
                        _mapCtrl.move(LatLng(r.lat, r.lng), 15);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          color: isSelected ? color : color.withOpacity(0.85),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: isSelected ? 3 : 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: color.withOpacity(0.4),
                              blurRadius: isSelected ? 12 : 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          _catIcon(r.category),
                          size: isSelected ? 20 : 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ],
        ),

        // 내 위치로 이동 버튼
        if (_userLat != null)
          Positioned(
            right: 14,
            top: 14,
            child: GestureDetector(
              onTap: () => _mapCtrl.move(LatLng(_userLat!, _userLng!), 14),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(Icons.my_location_rounded,
                    size: 20, color: Color(0xFF3B82F6)),
              ),
            ),
          ),

        // 선택된 식당 카드 (하단 슬라이드)
        if (_selected != null)
          Positioned(
            left: 16, right: 16, bottom: 16,
            child: _buildSelectedCard(_selected!),
          ),
      ],
    );
  }

  Widget _buildSelectedCard(RestaurantMapItem r) {
    final color = _catColors[r.category] ?? kBrand;
    return GestureDetector(
      onTap: () => widget.onPickRestaurant(r.id),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // 카테고리 아이콘
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(_catIcon(r.category), color: color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(r.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Pretendard',
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: kInk,
                              letterSpacing: -0.3,
                            )),
                      ),
                      CrowdBadge(level: r.crowdLevel),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(r.category,
                          style: const TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 12,
                            color: kInk3,
                          )),
                      const SizedBox(width: 6),
                      const Text('·', style: TextStyle(color: kInk3)),
                      const SizedBox(width: 6),
                      const Icon(Icons.star_rounded,
                          size: 11, color: Color(0xFFF59E0B)),
                      const SizedBox(width: 2),
                      Text(r.rating.toStringAsFixed(1),
                          style: const TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: kInk,
                          )),
                      const Spacer(),
                      Text(
                        '약 ${_fmt(r.price)}원',
                        style: const TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: kInk,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded, color: kInk3, size: 20),
          ],
        ),
      ),
    );
  }

  IconData _catIcon(String cat) {
    switch (cat) {
      case '한식': return Icons.rice_bowl_rounded;
      case '일식': return Icons.set_meal_rounded;
      case '중식': return Icons.ramen_dining_rounded;
      case '양식': return Icons.local_pizza_rounded;
      case '분식': return Icons.fastfood_rounded;
      case '카페': return Icons.coffee_rounded;
      default: return Icons.restaurant_rounded;
    }
  }

  String _fmt(int p) => p
      .toString()
      .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
}
