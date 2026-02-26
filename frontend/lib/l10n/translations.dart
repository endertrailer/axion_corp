/// Static translation map for AgriChain UI elements.
/// Supports English (en), Hindi (hi), and Marathi (mr).
class AppTranslations {
  static const Map<String, Map<String, String>> _translations = {
    // ── Actions ──
    'harvest_now': {
      'en': 'Harvest Now',
      'hi': 'अभी कटाई करें',
      'mr': 'आता कापणी करा',
    },
    'sell_at_mandi': {
      'en': 'Sell at Mandi',
      'hi': 'मंडी में बेचें',
      'mr': 'बाजारात विका',
    },
    'delay_store': {
      'en': 'Delay & Store Locally',
      'hi': 'रुकें और स्थानीय भंडारण करें',
      'mr': 'थांबा आणि स्थानिक साठवणूक करा',
    },
    'wait': {
      'en': 'Wait',
      'hi': 'प्रतीक्षा करें',
      'mr': 'थांबा',
    },

    // ── UI Labels ──
    'why_suggesting': {
      'en': 'Why are we suggesting this?',
      'hi': 'हम यह क्यों सुझा रहे हैं?',
      'mr': 'आम्ही हे का सुचवत आहोत?',
    },
    'select_language': {
      'en': 'Select Language',
      'hi': 'भाषा चुनें',
      'mr': 'भाषा निवडा',
    },
    'market_comparison': {
      'en': 'Market Comparison',
      'hi': 'बाजार तुलना',
      'mr': 'बाजार तुलना',
    },
    'weather_conditions': {
      'en': 'Weather Conditions',
      'hi': 'मौसम की स्थिति',
      'mr': 'हवामान परिस्थिती',
    },
    'expected_market_range': {
      'en': 'Expected Market Range',
      'hi': 'अपेक्षित बाजार दर',
      'mr': 'अपेक्षित बाजार श्रेणी',
    },
    'recommended_storage': {
      'en': 'Recommended Storage',
      'hi': 'सुझावित भंडारण',
      'mr': 'शिफारस केलेले साठवणूक',
    },
    'market_score': {
      'en': 'Market Score',
      'hi': 'बाजार स्कोर',
      'mr': 'बाजार गुण',
    },
    'temperature': {
      'en': 'Temperature',
      'hi': 'तापमान',
      'mr': 'तापमान',
    },
    'humidity': {
      'en': 'Humidity',
      'hi': 'नमी',
      'mr': 'आर्द्रता',
    },
    'condition': {
      'en': 'Condition',
      'hi': 'स्थिति',
      'mr': 'स्थिती',
    },
    'distance': {
      'en': 'Distance',
      'hi': 'दूरी',
      'mr': 'अंतर',
    },
    'per_day': {
      'en': 'Per Day',
      'hi': 'प्रति दिन',
      'mr': 'प्रति दिन',
    },
    'capacity': {
      'en': 'Capacity',
      'hi': 'क्षमता',
      'mr': 'क्षमता',
    },
    'low': {
      'en': 'Low',
      'hi': 'न्यूनतम',
      'mr': 'कमी',
    },
    'high': {
      'en': 'High',
      'hi': 'अधिकतम',
      'mr': 'जास्त',
    },
    'best': {
      'en': 'BEST',
      'hi': 'सर्वश्रेष्ठ',
      'mr': 'सर्वोत्तम',
    },
    'high_supply': {
      'en': 'HIGH SUPPLY',
      'hi': 'अधिक आवक',
      'mr': 'जास्त आवक',
    },
    'low_supply': {
      'en': 'LOW SUPPLY',
      'hi': 'कम आवक',
      'mr': 'कमी आवक',
    },
    'detecting_location': {
      'en': 'Detecting location…',
      'hi': 'स्थान पता लगा रहे हैं…',
      'mr': 'स्थान शोधत आहे…',
    },
    'analysing_markets': {
      'en': 'Analysing markets…',
      'hi': 'बाजारों का विश्लेषण…',
      'mr': 'बाजारांचे विश्लेषण…',
    },
    'retry': {
      'en': 'Retry',
      'hi': 'पुनः प्रयास',
      'mr': 'पुन्हा प्रयत्न करा',
    },
    'refresh': {
      'en': 'Refresh',
      'hi': 'रिफ्रेश',
      'mr': 'रिफ्रेश',
    },
    'oversupply_warning': {
      'en': 'Market is oversupplied. Prices may drop below this range if sold immediately.',
      'hi': 'बाजार में अत्यधिक आवक है। तुरंत बेचने पर कीमतें इस सीमा से नीचे गिर सकती हैं।',
      'mr': 'बाजारात अतिरिक्त आवक आहे. लगेच विकल्यास किमती या श्रेणीच्या खाली जाऊ शकतात.',
    },
  };

  /// Get a translated string for the given key and language code.
  static String t(String key, String lang) {
    return _translations[key]?[lang] ?? _translations[key]?['en'] ?? key;
  }

  /// Translate an action string from the API to the selected language.
  static String translateAction(String action, String lang) {
    if (lang == 'en') return action;

    final lower = action.toLowerCase();
    if (lower.contains('store')) return t('delay_store', lang);
    if (lower.contains('sell') || lower.contains('harvest')) {
      if (lower.contains('harvest')) return t('harvest_now', lang);
      return t('sell_at_mandi', lang);
    }
    if (lower.contains('wait')) return t('wait', lang);
    return action;
  }
}
