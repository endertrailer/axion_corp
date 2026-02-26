import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';

/// Data model matching the Go backend's Recommendation JSON payload (Phase 2).
class Recommendation {
  final String farmerId;
  final String cropName;
  final String action;
  final String recommendedMarket;
  final double marketScore;
  final double confidenceBandMin;
  final double confidenceBandMax;
  final String why;
  final String whyHi;
  final String whyMr;
  final WeatherInfo weather;
  final List<MarketOption> markets;
  final StorageOption? storage;
  final List<PreservationAction> preservationActions;
  final DateTime generatedAt;

  Recommendation({
    required this.farmerId,
    required this.cropName,
    required this.action,
    required this.recommendedMarket,
    required this.marketScore,
    required this.confidenceBandMin,
    required this.confidenceBandMax,
    required this.why,
    this.whyHi = '',
    this.whyMr = '',
    required this.weather,
    required this.markets,
    this.storage,
    this.preservationActions = const [],
    required this.generatedAt,
  });

  factory Recommendation.fromJson(Map<String, dynamic> json) {
    return Recommendation(
      farmerId: json['farmer_id'] ?? '',
      cropName: json['crop_name'] ?? '',
      action: json['action'] ?? '',
      recommendedMarket: json['recommended_market'] ?? '',
      marketScore: (json['market_score'] ?? 0).toDouble(),
      confidenceBandMin: (json['confidence_band_min'] ?? 0).toDouble(),
      confidenceBandMax: (json['confidence_band_max'] ?? 0).toDouble(),
      why: json['why'] ?? '',
      whyHi: json['explainability_string_hi'] ?? '',
      whyMr: json['explainability_string_mr'] ?? '',
      weather: WeatherInfo.fromJson(json['weather'] ?? {}),
      markets: (json['markets'] as List<dynamic>?)
              ?.map((m) => MarketOption.fromJson(m))
              .toList() ??
          [],
      storage: json['storage'] != null
          ? StorageOption.fromJson(json['storage'])
          : null,
      preservationActions: (json['preservation_actions'] as List<dynamic>?)
              ?.map((a) => PreservationAction.fromJson(a))
              .toList() ??
          [],
      generatedAt: DateTime.tryParse(json['generated_at'] ?? '') ?? DateTime.now(),
    );
  }

  /// Get the explainability string for the given language code.
  String getWhyForLang(String lang) {
    switch (lang) {
      case 'hi':
        return whyHi.isNotEmpty ? whyHi : why;
      case 'mr':
        return whyMr.isNotEmpty ? whyMr : why;
      default:
        return why;
    }
  }

  bool get isStoreAction => action.toLowerCase().contains('store');
}

class WeatherInfo {
  final double currentTemp;
  final double humidity;
  final double tempDelta;
  final String condition;

  WeatherInfo({
    required this.currentTemp,
    required this.humidity,
    required this.tempDelta,
    required this.condition,
  });

  factory WeatherInfo.fromJson(Map<String, dynamic> json) {
    return WeatherInfo(
      currentTemp: (json['current_temp_c'] ?? 0).toDouble(),
      humidity: (json['humidity_pct'] ?? 0).toDouble(),
      tempDelta: (json['temp_delta_from_ideal'] ?? 0).toDouble(),
      condition: json['condition'] ?? 'Unknown',
    );
  }
}

class MarketOption {
  final String marketName;
  final double currentPrice;
  final double distanceKm;
  final double transitTimeHr;
  final double spoilageLoss;
  final double netProfitEstimate;
  final double marketScore;
  final String arrivalVolumeTrend;
  final bool isAIRecommended;

  MarketOption({
    required this.marketName,
    required this.currentPrice,
    required this.distanceKm,
    required this.transitTimeHr,
    required this.spoilageLoss,
    required this.netProfitEstimate,
    required this.marketScore,
    required this.arrivalVolumeTrend,
    this.isAIRecommended = false,
  });

  factory MarketOption.fromJson(Map<String, dynamic> json) {
    return MarketOption(
      marketName: json['market_name'] ?? '',
      currentPrice: (json['current_price'] ?? 0).toDouble(),
      distanceKm: (json['distance_km'] ?? 0).toDouble(),
      transitTimeHr: (json['transit_time_hr'] ?? 0).toDouble(),
      spoilageLoss: (json['spoilage_loss_pct'] ?? 0).toDouble(),
      netProfitEstimate: (json['net_profit_estimate'] ?? 0).toDouble(),
      marketScore: (json['market_score'] ?? 0).toDouble(),
      arrivalVolumeTrend: json['arrival_volume_trend'] ?? 'NORMAL',
      isAIRecommended: json['is_ai_recommended'] ?? false,
    );
  }
}

class StorageOption {
  final String name;
  final double distanceKm;
  final double pricePerKg;
  final double capacityMT;

  StorageOption({
    required this.name,
    required this.distanceKm,
    required this.pricePerKg,
    required this.capacityMT,
  });

  factory StorageOption.fromJson(Map<String, dynamic> json) {
    return StorageOption(
      name: json['name'] ?? '',
      distanceKm: (json['distance_km'] ?? 0).toDouble(),
      pricePerKg: (json['price_per_kg'] ?? 0).toDouble(),
      capacityMT: (json['capacity_mt'] ?? 0).toDouble(),
    );
  }
}

class PreservationAction {
  final String actionName;
  final String costEstimate;
  final String effectiveness;
  final int rank;

  PreservationAction({
    required this.actionName,
    required this.costEstimate,
    required this.effectiveness,
    required this.rank,
  });

  factory PreservationAction.fromJson(Map<String, dynamic> json) {
    return PreservationAction(
      actionName: json['action_name'] ?? '',
      costEstimate: json['cost_estimate'] ?? '',
      effectiveness: json['effectiveness'] ?? '',
      rank: json['rank'] ?? 0,
    );
  }
}

/// Service to communicate with the AgriChain Go backend.
class ApiService {
  static String get _baseUrl => ApiConfig.baseUrl;

  /// Fetches a recommendation for the given farmer and crop.
  static Future<Recommendation> getRecommendation({
    required String farmerId,
    required String cropId,
    double? lat,
    double? lon,
  }) async {
    var urlStr =
        '$_baseUrl/api/v1/recommendation?farmer_id=$farmerId&crop_id=$cropId';
    if (lat != null && lon != null) {
      urlStr += '&lat=${lat.toStringAsFixed(6)}&lon=${lon.toStringAsFixed(6)}';
    }
    final url = Uri.parse(urlStr);

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return Recommendation.fromJson(data);
      }
      throw Exception('Server returned ${response.statusCode}');
    } catch (e) {
      return _fallbackRecommendation(farmerId);
    }
  }

  /// Offline / demo fallback — simulates a HIGH-glut staggering scenario.
  static Recommendation _fallbackRecommendation(String farmerId) {
    return Recommendation(
      farmerId: farmerId,
      cropName: 'Tomato',
      action: 'Delay & Store Locally',
      recommendedMarket: 'Azadpur Mandi',
      marketScore: 2097.13,
      confidenceBandMin: 2250,
      confidenceBandMax: 2750,
      why: '1. Price is likely between ₹2250 and ₹2750. However, due to a massive arrival surge at Azadpur Mandi, we recommend storing at Narela Cold Storage for ₹2.0/kg to prevent distress sales. '
          '2. Current temperature (32.4°C) with Partly Cloudy conditions. '
          '3. Once arrivals normalise, sell at Azadpur Mandi for the best effective return (Market Score: 2097). '
          '4. Storage at Narela Cold Storage has 500 MT capacity available at ₹2.0/kg/day, located 28.5 km from your farm.',
      weather: WeatherInfo(
        currentTemp: 32.4,
        humidity: 78.0,
        tempDelta: 7.4,
        condition: 'Partly Cloudy',
      ),
      markets: [
        MarketOption(
          marketName: 'Azadpur Mandi',
          currentPrice: 2500,
          distanceKm: 25.0,
          transitTimeHr: 0.8,
          spoilageLoss: 1.5,
          netProfitEstimate: 2300.0,
          marketScore: 2097.13,
          arrivalVolumeTrend: 'HIGH',
        ),
        MarketOption(
          marketName: 'Ghazipur Mandi',
          currentPrice: 2350,
          distanceKm: 32.0,
          transitTimeHr: 0.5,
          spoilageLoss: 1.1,
          netProfitEstimate: 2200.0,
          marketScore: 2435.65,
          arrivalVolumeTrend: 'LOW',
        ),
        MarketOption(
          marketName: 'Vashi APMC',
          currentPrice: 2800,
          distanceKm: 1450.0,
          transitTimeHr: 18.2,
          spoilageLoss: 12.3,
          netProfitEstimate: 2100.0,
          marketScore: 1545.60,
          arrivalVolumeTrend: 'NORMAL',
        ),
      ],
      storage: StorageOption(
        name: 'Narela Cold Storage',
        distanceKm: 28.5,
        pricePerKg: 2.0,
        capacityMT: 500,
      ),
      preservationActions: [
        PreservationAction(
          actionName: 'Use Ventilated Plastic Crates',
          costEstimate: '₹50/crate',
          effectiveness: 'High (Prevents 80% crushing)',
          rank: 1,
        ),
        PreservationAction(
          actionName: 'Apply Neem-based Anti-fungal',
          costEstimate: '₹120/acre',
          effectiveness: 'Medium (Delays rot)',
          rank: 2,
        ),
        PreservationAction(
          actionName: 'Cover with Tarpaulin in Transit',
          costEstimate: '₹300/trip',
          effectiveness: 'Low (Basic heat shield)',
          rank: 3,
        ),
      ],
      generatedAt: DateTime.now(),
    );
  }
}
