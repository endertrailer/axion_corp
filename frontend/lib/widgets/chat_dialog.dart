import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../api_service.dart';
import '../l10n/translations.dart';

class ChatMessage {
  final String text;
  final bool isUser;

  ChatMessage({required this.text, required this.isUser});
}

class ChatDialog extends StatefulWidget {
  final String lang;
  final String farmerId;
  final String cropId;
  final FlutterTts flutterTts;
  final Color activeColor;

  const ChatDialog({
    super.key,
    required this.lang,
    required this.farmerId,
    required this.cropId,
    required this.flutterTts,
    required this.activeColor,
  });

  @override
  State<ChatDialog> createState() => _ChatDialogState();
}

class _ChatDialogState extends State<ChatDialog> {
  final TextEditingController _textController = TextEditingController();
  final List<ChatMessage> _messages = [];
  
  bool _isTyping = false;
  bool _isListening = false;
  stt.SpeechToText _speechToText = stt.SpeechToText();

  @override
  void initState() {
    super.initState();
    _messages.add(
      ChatMessage(text: AppTranslations.t('assistant_hello', widget.lang), isUser: false),
    );
    _initStt();
  }

  Future<void> _initStt() async {
    var status = await Permission.microphone.status;
    if (!status.isGranted) {
      await Permission.microphone.request();
    }
    await _speechToText.initialize(
      onError: (val) => print('STT Error: $val'),
      onStatus: (val) {
        if (val == 'done' || val == 'notListening') {
          if (mounted) setState(() => _isListening = false);
        }
      },
    );
  }

  void _startListening() async {
    if (!_isListening) {
      bool available = await _speechToText.initialize();
      if (available) {
        setState(() => _isListening = true);
        
        String sttLocaleId = widget.lang == 'en' ? 'en-IN' : '${widget.lang}-IN';
        
        _speechToText.listen(
          onResult: (val) {
            setState(() {
              _textController.text = val.recognizedWords;
              _isTyping = val.recognizedWords.isNotEmpty;
            });
            if (val.finalResult) {
              setState(() => _isListening = false);
              _sendMessage(val.recognizedWords, isVoice: true);
            }
          },
          localeId: sttLocaleId,
        );
      }
    }
  }

  void _stopListening() async {
    await _speechToText.stop();
    setState(() => _isListening = false);
  }
  
  void _sendMessage(String text, {bool isVoice = false}) async {
    if (text.trim().isEmpty) return;
    
    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
      _textController.clear();
      _isTyping = false;
      _messages.add(ChatMessage(text: '...', isUser: false)); // Loading typing indicator
    });

    try {
      final reply = await ApiService.sendVoiceQuery(
        farmerId: widget.farmerId,
        cropId: widget.cropId,
        queryText: text,
        lang: widget.lang,
      );

      if (mounted) {
        setState(() {
          _messages.removeLast(); // Remove loading
          _messages.add(ChatMessage(text: reply, isUser: false));
        });
      }

      await widget.flutterTts.stop();
      if (isVoice) {
        await widget.flutterTts.speak(reply);
      }

    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.removeLast();
          _messages.add(ChatMessage(text: 'I could not connect to the network right now. Please try again.', isUser: false));
        });
      }
    }
  }

  Widget _buildMessageBubble(ChatMessage message) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 12.0),
        padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 14.0),
        decoration: BoxDecoration(
          color: message.isUser ? const Color(0xFF1976D2) : Colors.grey[200],
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: message.isUser ? const Radius.circular(16) : Radius.zero,
            bottomRight: message.isUser ? Radius.zero : const Radius.circular(16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(20),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          message.text,
          style: TextStyle(
            color: message.isUser ? Colors.white : Colors.black87,
            fontSize: 15,
          ),
        ),
      ),
    );
  }

  Widget _buildActionChip(String translationKey) {
    return ActionChip(
      label: Text(
        AppTranslations.t(translationKey, widget.lang),
        style: TextStyle(fontWeight: FontWeight.w600, color: widget.activeColor),
      ),
      backgroundColor: widget.activeColor.withAlpha(15),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: widget.activeColor.withAlpha(40)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      onPressed: () => _sendMessage(AppTranslations.t(translationKey, widget.lang)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [widget.activeColor, widget.activeColor.withAlpha(200)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Colors.white24,
                  child: Icon(Icons.smart_toy, color: Colors.white),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AgriChain Assistant',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Your Digital Advisor',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          // Messages List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                return _buildMessageBubble(_messages[index]);
              },
            ),
          ),

          // Quick Actions
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _buildActionChip('weather_check'),
                const SizedBox(width: 8),
                _buildActionChip('what_should_i_do'),
                const SizedBox(width: 8),
                _buildActionChip('ranked_preservation_actions'),
                const SizedBox(width: 8),
                _buildActionChip('market_prices_action'),
              ],
            ),
          ),

          // Input Area
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12).copyWith(
              bottom: MediaQuery.of(context).viewInsets.bottom + 12,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(10),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    onChanged: (val) {
                      setState(() {
                        _isTyping = val.trim().isNotEmpty;
                      });
                    },
                    decoration: InputDecoration(
                      hintText: AppTranslations.t('type_message', widget.lang),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey[100],
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onSubmitted: (val) => _sendMessage(val, isVoice: false),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: _isListening ? Colors.redAccent : widget.activeColor,
                  child: IconButton(
                    icon: Icon(
                      _isTyping 
                          ? Icons.send 
                          : (_isListening ? Icons.stop : Icons.mic),
                      color: _isListening ? Colors.redAccent : Colors.white,
                    ),
                    onPressed: () {
                      if (_isTyping) {
                        _sendMessage(_textController.text, isVoice: false);
                      } else {
                        if (_isListening) {
                          _stopListening();
                        } else {
                          _startListening();
                        }
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
