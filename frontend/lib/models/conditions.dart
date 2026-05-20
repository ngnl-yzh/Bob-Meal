// 사용자 조건 입력 모델
class Conditions {
  final String identity;      // 학생 / 직장인
  final String purpose;       // 혼밥 / 친목 / 회식 / 소개팅 / 비즈니스
  final String mealTime;      // 아침 / 점심 / 저녁 / 술자리
  final int partySize;        // 1~20
  final String locationType;  // gps / search
  final double? lat;
  final double? lng;
  final String transport;     // 도보 / 자전거 / 대중교통 / 자동차
  final int availableMinutes; // 30 / 60 / 90 / 120
  final String priceMode;     // default / custom
  final int? priceMax;
  final String sort;          // 추천순 / 거리순 / 가격순
  final DateTime? targetDateTime; // null = 지금, 설정 시 해당 시각 기준 추천

  const Conditions({
    this.identity = '학생',
    this.purpose = '혼밥',
    this.mealTime = '점심',
    this.partySize = 1,
    this.locationType = 'gps',
    this.lat,
    this.lng,
    this.transport = '도보',
    this.availableMinutes = 60,
    this.priceMode = 'default',
    this.priceMax,
    this.sort = '추천순',
    this.targetDateTime,
  });

  Conditions copyWith({
    String? identity,
    String? purpose,
    String? mealTime,
    int? partySize,
    String? locationType,
    double? lat,
    double? lng,
    String? transport,
    int? availableMinutes,
    String? priceMode,
    int? priceMax,
    String? sort,
    DateTime? targetDateTime,
    bool clearTargetDateTime = false,
  }) {
    return Conditions(
      identity: identity ?? this.identity,
      purpose: purpose ?? this.purpose,
      mealTime: mealTime ?? this.mealTime,
      partySize: partySize ?? this.partySize,
      locationType: locationType ?? this.locationType,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      transport: transport ?? this.transport,
      availableMinutes: availableMinutes ?? this.availableMinutes,
      priceMode: priceMode ?? this.priceMode,
      priceMax: priceMax ?? this.priceMax,
      sort: sort ?? this.sort,
      targetDateTime: clearTargetDateTime ? null : (targetDateTime ?? this.targetDateTime),
    );
  }

  int get budgetCap {
    if (priceMode == 'custom' && priceMax != null) return priceMax!;
    return identity == '학생' ? 8000 : 12000;
  }

  String get timeLabel {
    switch (availableMinutes) {
      case 30: return '30분';
      case 60: return '1시간';
      case 90: return '1.5시간';
      case 120: return '2시간+';
      default: return '${availableMinutes}분';
    }
  }

  Map<String, dynamic> toJson() => {
        'identity': identity,
        'purpose': purpose,
        'meal_time': mealTime,
        'party_size': partySize,
        'location_type': locationType,
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
        'transport': transport,
        'available_minutes': availableMinutes,
        'price_mode': priceMode,
        if (priceMax != null && priceMode == 'custom') 'price_max': priceMax,
        'sort': sort,
        if (targetDateTime != null)
          'target_datetime':
              '${targetDateTime!.year.toString().padLeft(4, '0')}-'
              '${targetDateTime!.month.toString().padLeft(2, '0')}-'
              '${targetDateTime!.day.toString().padLeft(2, '0')}T'
              '${targetDateTime!.hour.toString().padLeft(2, '0')}:'
              '${targetDateTime!.minute.toString().padLeft(2, '0')}',
      };
}
