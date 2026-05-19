// 식당 모델 — 백엔드 schemas.py 와 매핑
class Menu {
  final String name;
  final int price;
  final String photoUrl;
  final String icon;
  final int hue;
  final bool isRepresentative;

  const Menu({
    required this.name,
    required this.price,
    required this.photoUrl,
    required this.icon,
    required this.hue,
    required this.isRepresentative,
  });

  factory Menu.fromJson(Map<String, dynamic> j) => Menu(
        name: j['name'] ?? '',
        price: j['price'] ?? 0,
        photoUrl: j['photo_url'] ?? '',
        icon: j['icon'] ?? 'stew',
        hue: j['hue'] ?? 28,
        isRepresentative: j['is_representative'] ?? false,
      );
}

class CrowdByHour {
  final String hourLabel;
  final double crowdRatio;
  final bool isNow;

  const CrowdByHour({
    required this.hourLabel,
    required this.crowdRatio,
    this.isNow = false,
  });

  factory CrowdByHour.fromJson(Map<String, dynamic> j) => CrowdByHour(
        hourLabel: j['hour_label'] ?? '',
        crowdRatio: (j['crowd_ratio'] ?? 0.0).toDouble(),
        isNow: j['is_now'] ?? false,
      );
}

class PriceInfo {
  final int pricePerPerson;
  final double confidence;
  final String displayMode;  // exact / range / unknown
  final String displayText;
  final String source;

  const PriceInfo({
    required this.pricePerPerson,
    required this.confidence,
    required this.displayMode,
    required this.displayText,
    required this.source,
  });

  factory PriceInfo.fromJson(Map<String, dynamic> j) => PriceInfo(
        pricePerPerson: j['price_per_person'] ?? 0,
        confidence: (j['confidence'] ?? 0.5).toDouble(),
        displayMode: j['display_mode'] ?? 'unknown',
        displayText: j['display_text'] ?? '',
        source: j['source'] ?? '',
      );
}

/// 추천 결과 카드용 (리스트)
class RestaurantCard {
  final String id;
  final String name;
  final String category;
  final String crowdLevel;
  final double rating;
  final int reviewCount;
  final int walkMinutes;
  final int price;
  final double priceConfidence;
  final List<String> tags;
  final String photoUrl;
  final String heroIcon;
  final int heroHue;
  final double? score;

  const RestaurantCard({
    required this.id,
    required this.name,
    required this.category,
    required this.crowdLevel,
    required this.rating,
    required this.reviewCount,
    required this.walkMinutes,
    required this.price,
    required this.priceConfidence,
    required this.tags,
    required this.photoUrl,
    required this.heroIcon,
    required this.heroHue,
    this.score,
  });

  factory RestaurantCard.fromJson(Map<String, dynamic> j) => RestaurantCard(
        id: j['id'] ?? '',
        name: j['name'] ?? '',
        category: j['category'] ?? '',
        crowdLevel: j['crowd_level'] ?? '보통',
        rating: (j['rating'] ?? 0.0).toDouble(),
        reviewCount: j['review_count'] ?? 0,
        walkMinutes: j['walk_minutes'] ?? 0,
        price: j['price'] ?? 0,
        priceConfidence: (j['price_confidence'] ?? 0.5).toDouble(),
        tags: List<String>.from(j['tags'] ?? []),
        photoUrl: j['photo_url'] ?? '',
        heroIcon: j['hero_icon'] ?? 'stew',
        heroHue: j['hero_hue'] ?? 28,
        score: j['score'] != null ? (j['score'] as num).toDouble() : null,
      );
}

/// 식당 상세
class RestaurantDetail {
  final String id;
  final String name;
  final String category;
  final String address;
  final double lat;
  final double lng;
  final String hours;
  final bool isOpen;
  final String? phone;
  final double rating;
  final int reviewCount;
  final int walkMinutes;
  final int price;
  final double priceConfidence;
  final String crowdLevel;
  final List<String> tags;
  final List<String> features;
  final String photoUrl;
  final String heroIcon;
  final int heroHue;
  final List<Menu> menus;
  final List<CrowdByHour> crowdByHour;
  final PriceInfo? priceInfo;

  const RestaurantDetail({
    required this.id,
    required this.name,
    required this.category,
    required this.address,
    required this.lat,
    required this.lng,
    required this.hours,
    required this.isOpen,
    this.phone,
    required this.rating,
    required this.reviewCount,
    required this.walkMinutes,
    required this.price,
    required this.priceConfidence,
    required this.crowdLevel,
    required this.tags,
    required this.features,
    required this.photoUrl,
    required this.heroIcon,
    required this.heroHue,
    required this.menus,
    required this.crowdByHour,
    this.priceInfo,
  });

  factory RestaurantDetail.fromJson(Map<String, dynamic> j) => RestaurantDetail(
        id: j['id'] ?? '',
        name: j['name'] ?? '',
        category: j['category'] ?? '',
        address: j['address'] ?? '',
        lat: (j['lat'] ?? 0.0).toDouble(),
        lng: (j['lng'] ?? 0.0).toDouble(),
        hours: j['hours'] ?? '',
        isOpen: j['is_open'] ?? true,
        phone: j['phone'],
        rating: (j['rating'] ?? 0.0).toDouble(),
        reviewCount: j['review_count'] ?? 0,
        walkMinutes: j['walk_minutes'] ?? 0,
        price: j['price'] ?? 0,
        priceConfidence: (j['price_confidence'] ?? 0.5).toDouble(),
        crowdLevel: j['crowd_level'] ?? '보통',
        tags: List<String>.from(j['tags'] ?? []),
        features: List<String>.from(j['features'] ?? []),
        photoUrl: j['photo_url'] ?? '',
        heroIcon: j['hero_icon'] ?? 'stew',
        heroHue: j['hero_hue'] ?? 28,
        menus: (j['menus'] as List? ?? []).map((m) => Menu.fromJson(m)).toList(),
        crowdByHour: (j['crowd_by_hour'] as List? ?? [])
            .map((c) => CrowdByHour.fromJson(c))
            .toList(),
        priceInfo: j['price_info'] != null ? PriceInfo.fromJson(j['price_info']) : null,
      );
}

/// 추천 응답 전체
class RecommendResponse {
  final int total;
  final int radiusMeters;
  final int budgetCap;
  final String summary;
  final List<RestaurantCard> results;

  const RecommendResponse({
    required this.total,
    required this.radiusMeters,
    required this.budgetCap,
    required this.summary,
    required this.results,
  });

  factory RecommendResponse.fromJson(Map<String, dynamic> j) => RecommendResponse(
        total: j['total'] ?? 0,
        radiusMeters: j['radius_meters'] ?? 0,
        budgetCap: j['budget_cap'] ?? 0,
        summary: j['summary'] ?? '',
        results: (j['results'] as List? ?? [])
            .map((r) => RestaurantCard.fromJson(r))
            .toList(),
      );
}
