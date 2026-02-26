import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'api_service.dart';

void main() {
  runApp(const AgriChainApp());
}

class AgriChainApp extends StatelessWidget {
  const AgriChainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AgriChain',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2E7D32),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const DashboardScreen(),
    );
  }
}

// ═══════════════════════════════════════════════
//  DASHBOARD SCREEN
// ═══════════════════════════════════════════════

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Recommendation? _recommendation;
  bool _loading = true;
  String? _error;

  Position? _position;
  String _locationStatus = 'Detecting location…';
  bool _locationDenied = false;

  final String _farmerId = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890';
  final String _cropId = 'c3d4e5f6-a7b8-9012-cdef-123456789012';

  @override
  void initState() {
    super.initState();
    _initLocationThenFetch();
  }

  // ─── LOCATION DETECTION ───────────────────────

  Future<void> _initLocationThenFetch() async {
    setState(() {
      _loading = true;
      _error = null;
      _locationStatus = 'Detecting location…';
    });

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        _locationStatus = 'Location services disabled — using default location';
        _locationDenied = true;
      });
      _fetchRecommendation();
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() {
          _locationStatus = 'Location permission denied — using default location';
          _locationDenied = true;
        });
        _fetchRecommendation();
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() {
        _locationStatus = 'Location permanently denied — using default location';
        _locationDenied = true;
      });
      _fetchRecommendation();
      return;
    }

    try {
      Position? pos;
      pos = await Geolocator.getLastKnownPosition();
      if (pos != null) {
        setState(() {
          _position = pos;
          _locationStatus =
              'Location: ${pos!.latitude.toStringAsFixed(4)}°N, ${pos.longitude.toStringAsFixed(4)}°E';
          _locationDenied = false;
        });
      } else {
        setState(() {
          _locationStatus = 'Getting GPS fix…';
        });
        pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.low,
            timeLimit: Duration(seconds: 30),
          ),
        );
        setState(() {
          _position = pos;
          _locationStatus =
              'Location: ${pos!.latitude.toStringAsFixed(4)}°N, ${pos.longitude.toStringAsFixed(4)}°E';
          _locationDenied = false;
        });
      }
    } catch (e) {
      debugPrint('Location error: $e');
      setState(() {
        _locationStatus = 'Could not get GPS — using default location';
        _locationDenied = true;
      });
    }

    _fetchRecommendation();
  }

  Future<void> _fetchRecommendation() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rec = await ApiService.getRecommendation(
        farmerId: _farmerId,
        cropId: _cropId,
        lat: _position?.latitude,
        lon: _position?.longitude,
      );
      setState(() {
        _recommendation = rec;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F8E9),
      appBar: AppBar(
        title: const Text(
          'AgriChain',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _initLocationThenFetch,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Color(0xFF2E7D32)),
            const SizedBox(height: 16),
            Text(
              _locationStatus,
              style: const TextStyle(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            const Text(
              'Analysing markets…',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _initLocationThenFetch,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final rec = _recommendation!;
    return RefreshIndicator(
      onRefresh: _initLocationThenFetch,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildLocationBanner(),
          const SizedBox(height: 12),
          _buildRecommendationCard(rec),
          const SizedBox(height: 12),
          _buildConfidenceBandCard(rec),
          const SizedBox(height: 12),
          if (rec.storage != null) ...[
            _buildStorageCard(rec.storage!),
            const SizedBox(height: 12),
          ],
          _buildWeatherCard(rec.weather),
          const SizedBox(height: 12),
          _buildMarketsCard(rec.markets),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ─── LOCATION BANNER ──────────────────────────

  Widget _buildLocationBanner() {
    final icon = _locationDenied ? Icons.location_off : Icons.my_location;
    final color = _locationDenied ? Colors.orange : const Color(0xFF2E7D32);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _locationStatus,
              style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w500),
            ),
          ),
          if (_locationDenied)
            GestureDetector(
              onTap: () => Geolocator.openLocationSettings(),
              child: Text(
                'Enable',
                style: TextStyle(
                  fontSize: 13,
                  color: color,
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ─── PRIMARY RECOMMENDATION CARD (Phase 2) ────

  Widget _buildRecommendationCard(Recommendation rec) {
    // Phase 2: Change color based on action type
    final isStore = rec.isStoreAction;
    final isHarvest = rec.action.toLowerCase().contains('harvest') ||
        rec.action.toLowerCase().contains('sell');

    Color actionColor;
    IconData actionIcon;

    if (isStore) {
      actionColor = const Color(0xFFF57F17); // Amber/warning for "Delay & Store"
      actionIcon = Icons.warehouse;
    } else if (isHarvest) {
      actionColor = const Color(0xFF2E7D32); // Green for "Sell at Mandi"
      actionIcon = Icons.agriculture;
    } else {
      actionColor = const Color(0xFFE65100); // Orange for "Wait"
      actionIcon = Icons.hourglass_top;
    }

    final reasons = _parseReasons(rec.why);

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Top section: Action ──
          Container(
            decoration: BoxDecoration(
              color: actionColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
            child: Column(
              children: [
                Icon(actionIcon, size: 48, color: Colors.white),
                const SizedBox(height: 12),
                Text(
                  rec.action,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  '${rec.cropName}  •  ${rec.recommendedMarket}',
                  style: const TextStyle(fontSize: 15, color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          // ── Market score banner ──
          Container(
            color: actionColor.withAlpha(25),
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.star, color: Color(0xFFFFC107), size: 20),
                const SizedBox(width: 6),
                Text(
                  'Market Score: ${rec.marketScore.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: actionColor,
                  ),
                ),
              ],
            ),
          ),

          // ── "Why are we suggesting this?" ──
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 20),
              childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              leading: Icon(Icons.lightbulb_outline, color: actionColor),
              title: Text(
                'Why are we suggesting this?',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: actionColor,
                ),
              ),
              children: reasons.map((reason) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• ', style: TextStyle(fontSize: 14, height: 1.5)),
                      Expanded(
                        child: Text(
                          reason,
                          style: const TextStyle(fontSize: 14, height: 1.5),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  List<String> _parseReasons(String why) {
    final parts = why.split(RegExp(r'\d+\.\s+'));
    return parts.where((p) => p.trim().isNotEmpty).map((p) => p.trim()).toList();
  }

  // ─── CONFIDENCE BAND CARD (Phase 2) ───────────

  Widget _buildConfidenceBandCard(Recommendation rec) {
    final isStore = rec.isStoreAction;
    final bandColor = isStore ? const Color(0xFFF57F17) : const Color(0xFF2E7D32);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.trending_up, color: bandColor),
                const SizedBox(width: 8),
                const Text(
                  'Expected Market Range',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // Price range display
            Container(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    bandColor.withAlpha(30),
                    bandColor.withAlpha(60),
                    bandColor.withAlpha(30),
                  ],
                ),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: bandColor.withAlpha(100)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    children: [
                      Text(
                        '₹${rec.confidenceBandMin.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: bandColor,
                        ),
                      ),
                      Text(
                        'Low',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      Icon(Icons.swap_horiz, color: bandColor, size: 28),
                      Text(
                        '±10%',
                        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      Text(
                        '₹${rec.confidenceBandMax.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: bandColor,
                        ),
                      ),
                      Text(
                        'High',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (isStore) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber, color: Color(0xFFF57F17), size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Market is oversupplied. Prices may drop below this range if sold immediately.',
                        style: TextStyle(fontSize: 12, color: Color(0xFFE65100)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ─── STORAGE CARD (Phase 2) ───────────────────

  Widget _buildStorageCard(StorageOption storage) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: const Color(0xFFFFF8E1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.warehouse, color: Color(0xFFF57F17)),
                SizedBox(width: 8),
                Text(
                  'Recommended Storage',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFF57F17).withAlpha(80)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    storage.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFF57F17),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _storageStat(
                        '${storage.distanceKm.toStringAsFixed(1)} km',
                        'Distance',
                        Icons.near_me,
                      ),
                      _storageStat(
                        '₹${storage.pricePerKg.toStringAsFixed(1)}/kg',
                        'Per Day',
                        Icons.payments,
                      ),
                      _storageStat(
                        '${storage.capacityMT.toStringAsFixed(0)} MT',
                        'Capacity',
                        Icons.inventory_2,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _storageStat(String value, String label, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFFF57F17), size: 22),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
      ],
    );
  }

  // ─── WEATHER CARD ─────────────────────────────

  Widget _buildWeatherCard(WeatherInfo weather) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.wb_sunny, color: Color(0xFFFFA000)),
                SizedBox(width: 8),
                Text(
                  'Weather Conditions',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _weatherStat(
                  '${weather.currentTemp.toStringAsFixed(1)}°C',
                  'Temperature',
                  Icons.thermostat,
                ),
                _weatherStat(
                  '${weather.humidity.toStringAsFixed(0)}%',
                  'Humidity',
                  Icons.water_drop,
                ),
                _weatherStat(
                  weather.condition,
                  'Condition',
                  Icons.cloud,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _weatherStat(String value, String label, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFF2E7D32), size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  // ─── MARKETS COMPARISON CARD (Phase 2) ────────

  Widget _buildMarketsCard(List<MarketOption> markets) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.store, color: Color(0xFF2E7D32)),
                SizedBox(width: 8),
                Text(
                  'Market Comparison',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...markets.asMap().entries.map((entry) {
              final idx = entry.key;
              final m = entry.value;
              final isBest = idx == 0;
              final isHigh = m.arrivalVolumeTrend == 'HIGH';
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isBest
                      ? const Color(0xFF2E7D32).withAlpha(25)
                      : isHigh
                          ? const Color(0xFFFFF3E0)
                          : Colors.grey.withAlpha(13),
                  borderRadius: BorderRadius.circular(10),
                  border: isBest
                      ? Border.all(color: const Color(0xFF2E7D32), width: 1.5)
                      : isHigh
                          ? Border.all(
                              color: const Color(0xFFF57F17).withAlpha(120))
                          : null,
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (isBest)
                                _badge('BEST', const Color(0xFF2E7D32)),
                              if (isHigh)
                                _badge('HIGH SUPPLY', const Color(0xFFF57F17)),
                              if (m.arrivalVolumeTrend == 'LOW')
                                _badge('LOW SUPPLY', const Color(0xFF1565C0)),
                              Flexible(
                                child: Text(
                                  m.marketName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '₹${m.currentPrice.toStringAsFixed(0)}/q  •  ${m.transitTimeHr.toStringAsFixed(1)} hr  •  ${m.spoilageLoss.toStringAsFixed(1)}% loss',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      m.marketScore.toStringAsFixed(0),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isBest
                            ? const Color(0xFF2E7D32)
                            : Colors.black54,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
