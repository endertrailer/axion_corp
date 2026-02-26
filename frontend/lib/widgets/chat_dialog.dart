import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../api_service.dart';

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

  const ChatDialog({
    super.key,
    required this.lang,
    required this.farmerId,
    required this.cropId,
    required this.flutterTts,
  });

  @override
  State<ChatDialog> createState() => _ChatDialogState();
}

class _ChatDialogState extends State<ChatDialog> {
  final TextEditingController _textController = TextEditingController();
  final List<ChatMessage> _messages = [
    ChatMessage(text: 'Namaskaar! How can I help you with your farm today?', isUser: false),
  ];
  
  bool _isTyping = false;
  bool _isListening = false;
  stt.SpeechToText _speechToText = stt.SpeechToText();

  @override
  void initState() {
    super.initState();
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
            if (val.finalResult) {
              setState(() => _isListening = false);
              _sendMessage(val.recognizedWords);
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
  
  void _sendMessage(String text) async {
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
      await widget.flutterTts.speak(reply);

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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF1976D2), // Blue dashboard style
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Colors.white,
                  child: Icon(Icons.smart_toy, color: Color(0xFF1976D2)),
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                ActionChip(
                  label: const Text('Weather check'),
                  onPressed: () => _sendMessage('Weather check'),
                ),
                const SizedBox(width: 8),
                ActionChip(
                  label: const Text('What should I do?'),
                  onPressed: () => _sendMessage('What should I do?'),
                ),
                const SizedBox(width: 8),
                ActionChip(
                  label: const Text('Market prices'),
                  onPressed: () => _sendMessage('Market prices'),
                ),
              ],
            ),
          ),

          // Input Area
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8).copyWith(
              bottom: MediaQuery.of(context).viewInsets.bottom + 8,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey[300]!)),
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
                      hintText: 'Type your message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey[100],
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onSubmitted: _sendMessage,
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: const Color(0xFF1976D2),
                  child: IconButton(
                    icon: Icon(
                      _isTyping 
                          ? Icons.send 
                          : (_isListening ? Icons.stop : Icons.mic),
                      color: _isListening ? Colors.redAccent : Colors.white,
                    ),
                    onPressed: () {
                      if (_isTyping) {
                        _sendMessage(_textController.text);
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
