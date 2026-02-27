import 'package:flutter/material.dart';
import '../l10n/translations.dart';

class CropItem {
  final String id;
  final String translationKey;
  final String emoji;
  final Color themeColor;

  const CropItem(this.id, this.translationKey, this.emoji, this.themeColor);
}

const List<CropItem> masterCropList = [
  // Vegetables
  CropItem('c3d4e5f6-a7b8-9012-cdef-123456789012', 'crop_tomato', '🍅', Color(0xFFE53935)),
  CropItem('d4e5f6a7-b890-12cd-ef12-345678901234', 'crop_onion', '🧅', Color(0xFFD81B60)),
  CropItem('e5f6a7b8-9012-cdef-1234-567890123456', 'crop_potato', '🥔', Color(0xFF8D6E63)),
  CropItem('f6a7b8c9-0123-def0-2345-678901234567', 'crop_brinjal', '🍆', Color(0xFF8E24AA)),
  CropItem('a7b8c9d0-1234-ef01-3456-789012345678', 'crop_cabbage', '🥬', Color(0xFF43A047)),
  CropItem('b8c9d0e1-2345-f012-4567-890123456789', 'crop_cauliflower', '🥦', Color(0xFFCFD8DC)),
  CropItem('c9d0e1f2-3456-0123-5678-901234567890', 'crop_spinach', '🍃', Color(0xFF2E7D32)),
  CropItem('d0e1f2a3-4567-1234-6789-012345678901', 'crop_carrot', '🥕', Color(0xFFF4511E)),
  CropItem('e1f2a3b4-5678-2345-7890-123456789012', 'crop_radish', '🌿', Color(0xFF00ACC1)),
  CropItem('f2a3b4c5-6789-3456-8901-234567890123', 'crop_garlic', '🧄', Color(0xFFB0BEC5)),
  
  // Fruits
  CropItem('a3b4c5d6-7890-4567-9012-345678901234', 'crop_apple', '🍎', Color(0xFFD32F2F)),
  CropItem('b4c5d6e7-8901-5678-0123-456789012345', 'crop_banana', '🍌', Color(0xFFFBC02D)),
  CropItem('c5d6e7f8-9012-6789-1234-567890123456', 'crop_mango', '🥭', Color(0xFFFFA000)),
  CropItem('d6e7f8a9-0123-7890-2345-678901234567', 'crop_orange', '🍊', Color(0xFFFF9800)),
  CropItem('e7f8a9b0-1234-8901-3456-789012345678', 'crop_grapes', '🍇', Color(0xFF6A1B9A)),
  CropItem('f8a9b0c1-2345-9012-4567-890123456789', 'crop_papaya', '🍈', Color(0xFFFFB300)),
  CropItem('a9b0c1d2-3456-0123-5678-901234567890', 'crop_guava', '🍐', Color(0xFF7CB342)),
  CropItem('b0c1d2e3-4567-1234-6789-012345678901', 'crop_pineapple', '🍍', Color(0xFFF57F17)),
  CropItem('c1d2e3f4-5678-2345-7890-123456789012', 'crop_pomegranate', '🍎', Color(0xFFC62828)),
  
  // Cash Crops & Grains
  CropItem('d2e3f4a5-6789-3456-8901-234567890123', 'crop_wheat', '🌾', Color(0xFFFBC02D)),
  CropItem('e3f4a5b6-7890-4567-9012-345678901234', 'crop_rice', '🍚', Color(0xFFB0BEC5)),
  CropItem('f4a5b6c7-8901-5678-0123-456789012345', 'crop_sugarcane', '🎋', Color(0xFF8BC34A)),
  CropItem('a5b6c7d8-9012-6789-1234-567890123456', 'crop_cotton', '☁️', Color(0xFF90A4AE)),
  CropItem('b6c7d8e9-0123-7890-2345-678901234567', 'crop_maize', '🌽', Color(0xFFFFCA28)),
  CropItem('c7d8e9f0-1234-8901-3456-789012345678', 'crop_tea', '☕', Color(0xFF388E3C)),
  CropItem('d8e9f0a1-2345-9012-4567-890123456789', 'crop_coffee', '☕', Color(0xFF5D4037)),
  CropItem('e9f0a1b2-3456-0123-5678-901234567890', 'crop_mustard', '🌼', Color(0xFFFFD54F)),
  
  // Spices
  CropItem('f0a1b2c3-4567-1234-6789-012345678901', 'crop_ginger', '🫚', Color(0xFFA1887F)),
  CropItem('a1b2c3d4-5678-2345-7890-123456789012', 'crop_turmeric', '🟡', Color(0xFFFFB300)),
  CropItem('b2c3d4e5-6789-3456-8901-234567890123', 'crop_coriander', '🌿', Color(0xFF4CAF50)),
  CropItem('c3d4e5f6-7890-4567-9012-345678901234', 'crop_cumin', '🫘', Color(0xFF795548)),
  CropItem('d4e5f6a7-8901-5678-0123-456789012345', 'crop_black_pepper', '⚫', Color(0xFF424242)),
];

class CropPickerScreen extends StatefulWidget {
  final String lang;
  final Color activeColor;

  const CropPickerScreen({super.key, required this.lang, required this.activeColor});

  @override
  State<CropPickerScreen> createState() => _CropPickerScreenState();
}

class _CropPickerScreenState extends State<CropPickerScreen> {
  String _searchQuery = "";

  @override
  Widget build(BuildContext context) {
    // Filter the crops based on the search query translating to the target language
    // and falling back to English matches as well just in case.
    final filteredCrops = masterCropList.where((crop) {
      if (_searchQuery.isEmpty) return true;
      
      final localizedName = AppTranslations.t(crop.translationKey, widget.lang).toLowerCase();
      final englishName = AppTranslations.t(crop.translationKey, 'en').toLowerCase();
      final query = _searchQuery.toLowerCase();
      
      return localizedName.contains(query) || englishName.contains(query);
    }).toList();

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(AppTranslations.t('select_your_crop', widget.lang), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: widget.activeColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          Container(
            color: widget.activeColor,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: TextField(
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: AppTranslations.t('search_crop', widget.lang),
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.85,
              ),
              itemCount: filteredCrops.length,
              itemBuilder: (context, index) {
                final crop = filteredCrops[index];
                return InkWell(
                  onTap: () {
                    // Return the selected crop ID securely through the Navigator
                    Navigator.pop(context, crop.id);
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(10),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          crop.emoji,
                          style: const TextStyle(fontSize: 36),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: crop.themeColor.withAlpha(20),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                          AppTranslations.t(crop.translationKey, widget.lang),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: crop.themeColor.withOpacity(0.9),
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
  }
}
