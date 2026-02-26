import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'api_service.dart';
import 'l10n/translations.dart';
import 'widgets/chat_dialog.dart';

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

  // Language state
  String _lang = 'en';
  bool _langInitDone = false;

  final String _farmerId = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890';
  final String _cropId = 'c3d4e5f6-a7b8-9012-cdef-123456789012';

  FlutterTts flutterTts = FlutterTts();
  bool isSpeaking = false;

  String _t(String key) => AppTranslations.t(key, _lang);

  @override
  void initState() {
    super.initState();
    _loadLanguagePreference();
    _initTts();
  }



  Future<void> _initTts() async {
    await flutterTts.setVolume(1.0);
    await flutterTts.setSpeechRate(0.45);
    await flutterTts.setPitch(1.0);
    
    flutterTts.setCompletionHandler(() {
      setState(() {
        isSpeaking = false;
      });
    });
  }

  Future<void> _speak(String text) async {
    if (isSpeaking) {
      await flutterTts.stop();
      setState(() => isSpeaking = false);
      return;
    }

    // Default to Indian English, else use the selected language's ISO format
    String locale = _lang == 'en' ? 'en-IN' : '$_lang-IN';
    
    await flutterTts.setLanguage(locale);
    setState(() => isSpeaking = true);
    await flutterTts.speak(text);
  }

  @override
  void dispose() {
    flutterTts.stop();
    super.dispose();
  }

  /// Loads saved language or shows first-launch picker.
  Future<void> _loadLanguagePreference() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('app_language');

    if (saved != null) {
      setState(() {
        _lang = saved;
        _langInitDone = true;
      });
      _initLocationThenFetch();
    } else {
      // First launch — show language picker after the frame renders
      setState(() => _langInitDone = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showLanguagePickerDialog(firstLaunch: true);
      });
    }
  }

  /// Persists the language choice.
  Future<void> _saveLanguage(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_language', code);
  }

  // ─── LANGUAGE PICKER DIALOG ───────────────────

  void _showLanguagePickerDialog({bool firstLaunch = false}) {
    showDialog(
      context: context,
      barrierDismissible: !firstLaunch,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
                decoration: const BoxDecoration(
                  color: Color(0xFF2E7D32),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.language, color: Colors.white, size: 36),
                    const SizedBox(height: 8),
                    Text(
                      firstLaunch ? 'Welcome to AgriChain' : AppTranslations.t('select_language', _lang),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      AppTranslations.t('choose_your_language', _lang),
                      style: const TextStyle(fontSize: 13, color: Colors.white70),
                    ),
                  ],
                ),
              ),

              // Language grid
              SizedBox(
                height: 400,
                child: GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 2.6,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: supportedLanguages.length,
                  itemBuilder: (context, index) {
                    final lang = supportedLanguages[index];
                    final isSelected = lang.code == _lang;
                    return InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () {
                        setState(() => _lang = lang.code);
                        _saveLanguage(lang.code);
                        Navigator.of(ctx).pop();
                        if (firstLaunch) _initLocationThenFetch();
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF2E7D32).withAlpha(30)
                              : Colors.grey.withAlpha(20),
                          borderRadius: BorderRadius.circular(10),
                          border: isSelected
                              ? Border.all(color: const Color(0xFF2E7D32), width: 2)
                              : Border.all(color: Colors.grey.withAlpha(60)),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              lang.nativeName,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                color: isSelected ? const Color(0xFF2E7D32) : Colors.black87,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              lang.englishName,
                              style: TextStyle(
                                fontSize: 10,
                                color: isSelected ? const Color(0xFF2E7D32) : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ─── LOCATION DETECTION ───────────────────────

  Future<void> _initLocationThenFetch() async {
    setState(() {
      _loading = true;
      _error = null;
      _locationStatus = _t('detecting_location');
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
          _locationDenied = false;
        });
        await _updateLocationStatus(pos);
      } else {
        setState(() => _locationStatus = 'Getting GPS fix…');
        pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.low,
            timeLimit: Duration(seconds: 30),
          ),
        );
        setState(() {
          _position = pos;
          _locationDenied = false;
        });
        await _updateLocationStatus(pos!);
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

  Future<void> _updateLocationStatus(Position pos) async {
    try {
      final placemarks = await placemarkFromCoordinates(pos.latitude, pos.longitude);
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        final placeName = [p.locality, p.administrativeArea].where((e) => e != null && e.isNotEmpty).join(', ');
        if (placeName.isNotEmpty) {
          setState(() {
            _locationStatus = '$placeName (${pos.latitude.toStringAsFixed(2)}°, ${pos.longitude.toStringAsFixed(2)}°)';
          });
          return;
        }
      }
    } catch (e) {
      debugPrint('Geocoding error: $e');
    }
    // Fallback if geocoding fails
    setState(() {
      _locationStatus = 'Location: ${pos.latitude.toStringAsFixed(4)}°N, ${pos.longitude.toStringAsFixed(4)}°E';
    });
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
        lang: _lang,
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

  // ─── BUILD ────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Find current language name for the AppBar button
    final currentLangInfo = supportedLanguages.firstWhere(
      (l) => l.code == _lang,
      orElse: () => supportedLanguages[0],
    );

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
          // Language switch button
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => _showLanguagePickerDialog(),
            child: Container(
              margin: const EdgeInsets.only(right: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(40),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.language, size: 16, color: Colors.white),
                  const SizedBox(width: 4),
                  Text(
                    currentLangInfo.nativeName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _initLocationThenFetch,
            tooltip: _t('refresh'),
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Left: Change Location
            FloatingActionButton.extended(
              heroTag: 'changeLocBtn',
              onPressed: _showLocationPicker,
              icon: const Icon(Icons.edit_location_alt),
              label: Text(_t('change_location') != 'change_location' ? _t('change_location') : 'Change Location'),
              backgroundColor: const Color(0xFF2E7D32),
              foregroundColor: Colors.white,
            ),
            // Right: Floating AI Mic
            FloatingActionButton(
              heroTag: 'aiMicBtn',
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (ctx) => Padding(
                    padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 40),
                    child: ChatDialog(
                      lang: _lang,
                      farmerId: _farmerId,
                      cropId: _cropId,
                      flutterTts: flutterTts,
                    ),
                  ),
                );
              },
              backgroundColor: const Color(0xFF2E7D32),
              child: const Icon(Icons.smart_toy),
            ),
          ],
        ),
      ),
    );
  }

  void _showLocationPicker() async {
    final LatLng? selected = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MapLocationPickerScreen(
          initialPosition: _position != null 
              ? LatLng(_position!.latitude, _position!.longitude)
              : const LatLng(21.1458, 79.0882), // Default Center of India roughly
        ),
      ),
    );

    if (selected != null) {
      setState(() {
        _position = Position(
          latitude: selected.latitude,
          longitude: selected.longitude,
          timestamp: DateTime.now(),
          accuracy: 1, altitude: 1, heading: 1, speed: 1, speedAccuracy: 1,
          altitudeAccuracy: 1, headingAccuracy: 1,
        );
        _locationDenied = false;
        _locationStatus = 'Detecting region...';
      });
      await _updateLocationStatus(_position!);
      _fetchRecommendation();
    }
  }

  Widget _buildBody() {
    if (!_langInitDone) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF2E7D32)));
    }

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
            Text(
              _t('analysing_markets'),
              style: const TextStyle(fontSize: 16, color: Colors.grey),
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
                label: Text(_t('retry')),
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
          if (rec.isOffline) _buildOfflineBanner(),
          if (rec.isOffline) const SizedBox(height: 12),
          _buildRecommendationCard(rec),
          const SizedBox(height: 12),
          _buildConfidenceBandCard(rec),
          const SizedBox(height: 12),
          if (rec.storageOptions != null) ...[
            _buildStorageCard(rec.storageOptions!),
            const SizedBox(height: 12),
          ],
          if (rec.preservationActions.isNotEmpty) ...[
            _buildRankedPreservationActions(rec.preservationActions),
            const SizedBox(height: 12),
          ],
          _buildSoilHealthCard(rec.soilHealth),
          const SizedBox(height: 12),
          _buildWeatherCard(rec.weather),
          const SizedBox(height: 12),
          _buildMarketsCard(rec.alternativeMarkets),
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
                  fontSize: 13, color: color,
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ─── OFFLINE BANNER ───────────────────────────────

  Widget _buildOfflineBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.orange.withAlpha(25),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange.withAlpha(80)),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off, color: Colors.orange, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _t('offline') == 'offline' 
                  ? 'Viewing cached offline data. Check connection to refresh.' 
                  : _t('offline'),
              style: const TextStyle(fontSize: 13, color: Colors.orange, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  // ─── PRIMARY RECOMMENDATION CARD ──────────────

  Widget _buildRecommendationCard(Recommendation rec) {
    final isStore = rec.isStoreAction;
    final isHarvest = rec.action.toLowerCase().contains('harvest') ||
        rec.action.toLowerCase().contains('sell');

    Color actionColor;
    IconData actionIcon;
    if (isStore) {
      actionColor = const Color(0xFFF57F17);
      actionIcon = Icons.warehouse;
    } else if (isHarvest) {
      actionColor = const Color(0xFF2E7D32);
      actionIcon = Icons.agriculture;
    } else {
      actionColor = const Color(0xFFE65100);
      actionIcon = Icons.hourglass_top;
    }

    final localizedAction = AppTranslations.translateAction(rec.action, _lang);
    final reasons = _parseReasons(rec.why);

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
                  localizedAction,
                  style: const TextStyle(
                    fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  '${rec.cropName}  •  ${rec.recommendedMarket}',
                  style: const TextStyle(fontSize: 15, color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
                if (rec.harvestWindow.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(50),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_t('harvest_window')}: ${rec.harvestWindow}',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Container(
            color: actionColor.withAlpha(25),
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.star, color: Color(0xFFFFC107), size: 20),
                const SizedBox(width: 6),
                Text(
                  '${_t('market_score')}: ${rec.marketScore.toStringAsFixed(0)}',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: actionColor),
                ),
              ],
            ),
          ),
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 20),
              childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              leading: Icon(Icons.lightbulb_outline, color: actionColor),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      _t('why_suggesting'),
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: actionColor),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      isSpeaking ? Icons.volume_up : Icons.volume_down,
                      color: isSpeaking ? Colors.white : Colors.white70,
                    ),
                    onPressed: () => _speak(rec.why),
                    tooltip: _t('listen_recommendation') != 'listen_recommendation' ? _t('listen_recommendation') : 'Listen',
                  ),
                ],
              ),
              children: reasons.map((reason) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• ', style: TextStyle(fontSize: 14, height: 1.5)),
                      Expanded(
                        child: Text(reason, style: const TextStyle(fontSize: 14, height: 1.5)),
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

  // ─── CONFIDENCE BAND CARD ─────────────────────

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
                Expanded(
                  child: Text(
                    _t('expected_market_range'),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  bandColor.withAlpha(30), bandColor.withAlpha(60), bandColor.withAlpha(30),
                ]),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: bandColor.withAlpha(100)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(children: [
                    Text('₹${rec.confidenceBandMin.toStringAsFixed(0)}',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: bandColor)),
                    Text(_t('low'), style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  ]),
                  Column(children: [
                    Icon(Icons.swap_horiz, color: bandColor, size: 28),
                    Text('±10%', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                  ]),
                  Column(children: [
                    Text('₹${rec.confidenceBandMax.toStringAsFixed(0)}',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: bandColor)),
                    Text(_t('high'), style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  ]),
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
                child: Row(children: [
                  const Icon(Icons.warning_amber, color: Color(0xFFF57F17), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_t('oversupply_warning'),
                        style: const TextStyle(fontSize: 12, color: Color(0xFFE65100))),
                  ),
                ]),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ─── STORAGE CARD ─────────────────────────────

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
            Row(children: [
              const Icon(Icons.warehouse, color: Color(0xFFF57F17)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(_t('recommended_storage'),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ]),
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
                  Text(storage.name,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFF57F17))),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _storageStat('${storage.distanceKm.toStringAsFixed(1)} km', _t('distance'), Icons.near_me),
                      _storageStat('₹${storage.pricePerKg.toStringAsFixed(1)}/kg', _t('per_day'), Icons.payments),
                      _storageStat('${storage.capacityMT.toStringAsFixed(0)} MT', _t('capacity'), Icons.inventory_2),
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
    return Column(children: [
      Icon(icon, color: const Color(0xFFF57F17), size: 22),
      const SizedBox(height: 4),
      Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
      Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
    ]);
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
            Row(children: [
              const Icon(Icons.wb_sunny, color: Color(0xFFFFA000)),
              const SizedBox(width: 8),
              Text(_t('weather_conditions'),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _weatherStat('${weather.currentTemp.toStringAsFixed(1)}°C', _t('temperature'), Icons.thermostat),
                _weatherStat('${weather.humidity.toStringAsFixed(0)}%', _t('humidity'), Icons.water_drop),
                _weatherStat(weather.condition, _t('condition'), Icons.cloud),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _weatherStat(String value, String label, IconData icon) {
    return Column(children: [
      Icon(icon, color: const Color(0xFF2E7D32), size: 24),
      const SizedBox(height: 4),
      Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
    ]);
  }

  // ─── SOIL HEALTH CARD ─────────────────────────────

  Widget _buildSoilHealthCard(SoilHealth soil) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.grass, color: Color(0xFF689F38)),
              const SizedBox(width: 8),
              Text(_t('soil_health'),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _weatherStat('${soil.moisturePct.toStringAsFixed(1)}%', _t('moisture'), Icons.water_drop),
                _weatherStat(soil.nitrogen.toStringAsFixed(0), 'N', Icons.science),
                _weatherStat(soil.phosphorus.toStringAsFixed(0), 'P', Icons.science),
                _weatherStat(soil.potassium.toStringAsFixed(0), 'K', Icons.science),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: soil.moisturePct < 20 ? Colors.orange.withAlpha(30) : Colors.green.withAlpha(30),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                soil.status,
                style: TextStyle(
                  color: soil.moisturePct < 20 ? Colors.orange[800] : Colors.green[800],
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── MARKETS COMPARISON CARD ──────────────────

  Widget _buildMarketsCard(List<MarketOption> markets) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.store, color: Color(0xFF2E7D32)),
              const SizedBox(width: 8),
              Text(_t('market_comparison'),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ]),
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
                      : isHigh ? const Color(0xFFFFF3E0) : Colors.grey.withAlpha(13),
                  borderRadius: BorderRadius.circular(10),
                  border: isBest
                      ? Border.all(color: const Color(0xFF2E7D32), width: 1.5)
                      : isHigh ? Border.all(color: const Color(0xFFF57F17).withAlpha(120)) : null,
                ),
                child: Row(children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          if (isBest) _badge(_t('best'), const Color(0xFF2E7D32)),
                          if (isHigh) _badge(_t('high_supply'), const Color(0xFFF57F17)),
                          if (m.arrivalVolumeTrend == 'LOW') _badge(_t('low_supply'), const Color(0xFF1565C0)),
                          if (m.priceTrendPct != 0) 
                            _badge('${m.priceTrendPct > 0 ? '+' : ''}${m.priceTrendPct.toStringAsFixed(1)}%', 
                                   m.priceTrendPct > 0 ? const Color(0xFF2E7D32) : const Color(0xFFD32F2F)),
                          Flexible(
                            child: Text(m.marketName,
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          ),
                        ]),
                        const SizedBox(height: 4),
                        Text(
                          '₹${m.currentPrice.toStringAsFixed(0)}/q  •  ${m.transitTimeHr.toStringAsFixed(1)} hr  •  ${m.spoilageLoss.toStringAsFixed(1)}% loss',
                          style: const TextStyle(fontSize: 12, color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                  Text(m.marketScore.toStringAsFixed(0),
                      style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold,
                        color: isBest ? const Color(0xFF2E7D32) : Colors.black54,
                      )),
                ]),
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
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
      child: Text(text,
          style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
    );
  }

  // ─── RANKED PRESERVATION ACTIONS ────────────────

  Widget _buildRankedPreservationActions(List<PreservationAction> actions) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.shield, color: Color(0xFF1565C0)),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Ranked Preservation Actions',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ]),
            const SizedBox(height: 12),
            ...actions.map((a) {
              return Card(
                elevation: 0,
                color: const Color(0xFFF8F9FA),
                shape: RoundedRectangleBorder(
                  side: const BorderSide(color: Color(0xFFE0E0E0), width: 1),
                  borderRadius: BorderRadius.circular(8),
                ),
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFF1565C0),
                    radius: 16,
                    child: Text(
                      '#${a.rank}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                  title: Text(
                    a.actionName,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  subtitle: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Cost: ${a.costEstimate}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                      Text(a.effectiveness, style: const TextStyle(fontSize: 11, color: Color(0xFF2E7D32), fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════
//  MAP LOCATION PICKER SCREEN
// ═══════════════════════════════════════════════

class MapLocationPickerScreen extends StatefulWidget {
  final LatLng initialPosition;

  const MapLocationPickerScreen({super.key, required this.initialPosition});

  @override
  State<MapLocationPickerScreen> createState() => _MapLocationPickerScreenState();
}

class _MapLocationPickerScreenState extends State<MapLocationPickerScreen> {
  final MapController _mapController = MapController();
  late LatLng _selectedPosition;

  @override
  void initState() {
    super.initState();
    _selectedPosition = widget.initialPosition;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Location', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF2E7D32),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _selectedPosition,
              initialZoom: 6.0,
              onTap: (tapPosition, point) {
                setState(() {
                  _selectedPosition = point;
                });
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.agrichain',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _selectedPosition,
                    width: 40,
                    height: 40,
                    child: const Icon(
                      Icons.location_on,
                      color: Colors.red,
                      size: 40,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Positioned(
            bottom: 24,
            left: 24,
            right: 24,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context, _selectedPosition);
              },
              icon: const Icon(Icons.check, color: Colors.white),
              label: const Text(
                'Confirm Location',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(240),
                borderRadius: BorderRadius.circular(8),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
              ),
              child: const Text(
                'Tap anywhere on the map to select a farm location',
                style: TextStyle(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
          )
        ],
      ),
    );
  }
}
