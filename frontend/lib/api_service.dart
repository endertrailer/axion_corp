import 'dart:convert';
import 'package:http/http.dart' as http;

/// Data model matching the Go backend's Recommendation JSON payload.
class Recommendation {
  final String farmerId;
  final String cropName;
  final String action;
  final String recommendedMarket;
  final double marketScore;
  final String why;
  final WeatherInfo weather;
  final List<MarketOption> markets;
  final DateTime generatedAt;

  Recommendation({
    required this.farmerId,
    required this.cropName,
    required this.action,
    required this.recommendedMarket,
    required this.marketScore,
    required this.why,
    required this.weather,
    required this.markets,
    required this.generatedAt,
  });

  factory Recommendation.fromJson(Map<String, dynamic> json) {
    return Recommendation(
      farmerId: json['farmer_id'] ?? '',
      cropName: json['crop_name'] ?? '',
      action: json['action'] ?? '',
      recommendedMarket: json['recommended_market'] ?? '',
      marketScore: (json['market_score'] ?? 0).toDouble(),
      why: json['why'] ?? '',
      weather: WeatherInfo.fromJson(json['weather'] ?? {}),
      markets: (json['markets'] as List<dynamic>?)
              ?.map((m) => MarketOption.fromJson(m))
              .toList() ??
          [],
      generatedAt: DateTime.tryParse(json['generated_at'] ?? '') ?? DateTime.now(),
    );
  }
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
  final double transitTimeHr;
  final double spoilageLoss;
  final double marketScore;

  MarketOption({
    required this.marketName,
    required this.currentPrice,
    required this.transitTimeHr,
    required this.spoilageLoss,
    required this.marketScore,
  });

  factory MarketOption.fromJson(Map<String, dynamic> json) {
    return MarketOption(
      marketName: json['market_name'] ?? '',
      currentPrice: (json['current_price'] ?? 0).toDouble(),
      transitTimeHr: (json['transit_time_hr'] ?? 0).toDouble(),
      spoilageLoss: (json['spoilage_loss_pct'] ?? 0).toDouble(),
      marketScore: (json['market_score'] ?? 0).toDouble(),
    );
  }
}

/// Service to communicate with the AgriChain Go backend.
class ApiService {
  // Change this to your backend URL.
  // For Android emulator use 10.0.2.2; for a real device use the machine's LAN IP.
  static const String _baseUrl = 'http://10.0.2.2:8080';

  /// Fetches a recommendation for the given farmer and crop.
  static Future<Recommendation> getRecommendation({
    required String farmerId,
    required String cropId,
  }) async {
    final url = Uri.parse(
      '$_baseUrl/api/v1/recommendation?farmer_id=$farmerId&crop_id=$cropId',
    );

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return Recommendation.fromJson(data);
      }
      throw Exception('Server returned ${response.statusCode}');
    } catch (e) {
      // Return a realistic demo recommendation if the backend is unreachable
      return _fallbackRecommendation(farmerId);
    }
  }

  /// Offline / demo fallback so the UI always works.
  static Recommendation _fallbackRecommendation(String farmerId) {
    return Recommendation(
      farmerId: farmerId,
      cropName: 'Tomato',
      action: 'Harvest Now',
      recommendedMarket: 'Azadpur Mandi',
      marketScore: 2342.50,
      why: '1. Current temperature (32.4°C) is close to the ideal 25.0°C for Tomato, '
          'making conditions favorable for harvest. '
          '2. Azadpur Mandi offers the best effective price at ₹2500/quintal after '
          'accounting for 0.8 hrs transit and 1.5% estimated spoilage (Market Score: 2343). '
          '3. High humidity (78%) detected — consider immediate transport to reduce '
          'moisture-related decay.',
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
          transitTimeHr: 0.8,
          spoilageLoss: 1.5,
          marketScore: 2342.50,
        ),
        MarketOption(
          marketName: 'Ghazipur Mandi',
          currentPrice: 2350,
          transitTimeHr: 0.5,
          spoilageLoss: 1.1,
          marketScore: 2294.35,
        ),
        MarketOption(
          marketName: 'Vashi APMC',
          currentPrice: 2800,
          transitTimeHr: 18.2,
          spoilageLoss: 12.3,
          marketScore: 1545.60,
        ),
      ],
      generatedAt: DateTime.now(),
    );
  }
}
