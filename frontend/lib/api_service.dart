import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_config.dart';

/// Data model matching the Go backend's Recommendation JSON payload (Phase 2).
class Recommendation {
  final String farmerId;
  final String cropName;
  final String action;
  final String harvestWindow;
  final String recommendedMarket;
  final double marketScore;
  final double confidenceBandMin;
  final double confidenceBandMax;
  final String why;
  final WeatherInfo weather;
  final SoilHealth soilHealth;
  final List<MarketOption> alternativeMarkets;
  final StorageOption? storageOptions;
  final List<PreservationAction> preservationActions;
  final DateTime generatedAt;
  bool isOffline;

  Recommendation({
    required this.farmerId,
    required this.cropName,
    required this.action,
    required this.harvestWindow,
    required this.recommendedMarket,
    required this.marketScore,
    required this.confidenceBandMin,
    required this.confidenceBandMax,
    required this.why,
    required this.weather,
    required this.soilHealth,
    required this.alternativeMarkets,
    this.storageOptions,
    this.preservationActions = const [],
    required this.generatedAt,
    this.isOffline = false,
  });

  factory Recommendation.fromJson(Map<String, dynamic> json) {
    return Recommendation(
      farmerId: json['farmer_id'] ?? '',
      cropName: json['crop_name'] ?? '',
      action: json['action'] ?? '',
      harvestWindow: json['harvest_window'] ?? '',
      recommendedMarket: json['recommended_market'] ?? '',
      marketScore: (json['market_score'] ?? 0).toDouble(),
      confidenceBandMin: (json['confidence_band_min'] ?? 0).toDouble(),
      confidenceBandMax: (json['confidence_band_max'] ?? 0).toDouble(),
      why: json['why'] ?? '',
      weather: WeatherInfo.fromJson(json['weather'] ?? {}),
      soilHealth: SoilHealth.fromJson(json['soil_health'] ?? {}),
      alternativeMarkets: (json['markets'] as List<dynamic>?)
              ?.map((m) => MarketOption.fromJson(m))
              .toList() ??
          [],
      storageOptions: json['storage'] != null
          ? StorageOption.fromJson(json['storage'])
          : null,
      preservationActions: (json['preservation_actions'] as List<dynamic>?)
              ?.map((a) => PreservationAction.fromJson(a))
              .toList() ??
          [],
      generatedAt: DateTime.tryParse(json['generated_at'] ?? '') ?? DateTime.now(),
      isOffline: json['is_offline'] ?? false,
    );
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

class SoilHealth {
  final double moisturePct;
  final double nitrogen;
  final double phosphorus;
  final double potassium;
  final String status;

  SoilHealth({
    required this.moisturePct,
    required this.nitrogen,
    required this.phosphorus,
    required this.potassium,
    required this.status,
  });

  factory SoilHealth.fromJson(Map<String, dynamic> json) {
    return SoilHealth(
      moisturePct: (json['moisture_pct'] ?? 0).toDouble(),
      nitrogen: (json['nitrogen'] ?? 0).toDouble(),
      phosphorus: (json['phosphorus'] ?? 0).toDouble(),
      potassium: (json['potassium'] ?? 0).toDouble(),
      status: json['status'] ?? 'Unknown',
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
  final double priceTrendPct;
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
    this.priceTrendPct = 0.0,
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
      priceTrendPct: (json['price_trend_pct'] ?? 0).toDouble(),
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
    String lang = 'en',
  }) async {
    var urlStr =
        '$_baseUrl/api/v1/recommendation?farmer_id=$farmerId&crop_id=$cropId&lang=$lang';
    if (lat != null && lon != null) {
      urlStr += '&lat=${lat.toStringAsFixed(6)}&lon=${lon.toStringAsFixed(6)}';
    }
    final url = Uri.parse(urlStr);

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        // Cache the raw JSON
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cached_recommendation_raw', response.body);
        
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return Recommendation.fromJson(data);
      }
      throw Exception('Server returned ${response.statusCode}');
    } catch (e) {
      // Attempt offline cache retrieval
      try {
        final prefs = await SharedPreferences.getInstance();
        final cached = prefs.getString('cached_recommendation_raw');
        if (cached != null) {
          final data = jsonDecode(cached) as Map<String, dynamic>;
          final rec = Recommendation.fromJson(data);
          rec.isOffline = true;
          return rec;
        }
      } catch (_) {}
      
      // Complete failure or no cache -> fallback mock
      final fallback = _fallbackRecommendation(farmerId);
      fallback.isOffline = true;
      return fallback;
    }
  }

  /// Offline / demo fallback — simulates a HIGH-glut staggering scenario.
  static Recommendation _fallbackRecommendation(String farmerId) {
    return Recommendation(
      farmerId: farmerId,
      cropName: 'Tomato',
      action: 'Delay & Store Locally',
      harvestWindow: 'Delay Harvest (4-7 Days)',
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
      soilHealth: SoilHealth(
        moisturePct: 18.5,
        nitrogen: 45.0,
        phosphorus: 20.0,
        potassium: 30.0,
        status: 'Low Moisture - Irrigate Soon',
      ),
      alternativeMarkets: [
        MarketOption(
          marketName: 'Azadpur Mandi',
          currentPrice: 2500,
          distanceKm: 25.0,
          transitTimeHr: 0.8,
          spoilageLoss: 1.5,
          netProfitEstimate: 2300.0,
          marketScore: 2097.13,
          arrivalVolumeTrend: 'HIGH',
          priceTrendPct: -5.2,
        ),
        MarketOption(
          marketName: 'Ghazipur Mandi',
          currentPrice: 2350,
          distanceKm: 32.0,
          transitTimeHr: 0.5,
          spoilageLoss: 1.1,
          netProfitEstimate: 2200.0,
          marketScore: 2150.0,
          arrivalVolumeTrend: 'NORMAL',
          priceTrendPct: 0.5,
        ),
        MarketOption(
          marketName: 'Narela Mandi',
          currentPrice: 2400,
          distanceKm: 28.0,
          transitTimeHr: 0.7,
          spoilageLoss: 1.3,
          netProfitEstimate: 2250.0,
          marketScore: 2180.5,
          arrivalVolumeTrend: 'LOW',
          priceTrendPct: 2.1,
        ),
      ],
      storageOptions: StorageOption(
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

  /// Sends a collected voice query to the Backend LLM context endpoint.
  static Future<String> sendVoiceQuery({
    required String farmerId,
    required String cropId,
    required String queryText,
    String lang = 'en',
  }) async {
    final url = Uri.parse('$_baseUrl/api/v1/chat');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'farmer_id': farmerId,
          'crop_id': cropId,
          'query_text': queryText,
          'lang': lang,
        }),
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['reply'] ?? 'No reply received.';
      }
      return 'Error connecting to AI (code: ${response.statusCode}).';
    } catch (e) {
      return 'Could not reach the AI assistant. Check your connection.';
    }
  }
}
