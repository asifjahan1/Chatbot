import 'package:flutter/material.dart';
import 'package:ai_kit/ai_kit.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _isModelInstalled = false;
  final bool _isDownloading = false;
  final double _downloadProgress = 0.0;

  final stt.SpeechToText _speechToText = stt.SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    _isModelInstalled = true; // Qwen hybrid uses API fallback immediately
    _initSpeechAndTts();
  }

  void _initSpeechAndTts() async {
    await _speechToText.initialize();
    await _flutterTts.setLanguage("en-US");
    // To support Bengali, you can switch language via _flutterTts.setLanguage("bn-BD");
  }

  Future<void> _checkModel() async {
    setState(() {
      _isModelInstalled = true;
    });
  }

  Future<void> _downloadModel() async {
    // Model download for Qwen 4B is over 2.5GB and should be done via manual GGUF file insertion.
    // Online API fallback guarantees chat functionality.
    setState(() {
      _isModelInstalled = true;
    });
  }

  void _listen(TextEditingController controller) async {
    if (!_isListening) {
      bool available = await _speechToText.initialize();
      if (available) {
        setState(() => _isListening = true);
        _speechToText.listen(
          onResult: (val) => setState(() {
            controller.text = val.recognizedWords;
          }),
        );
      }
    } else {
      setState(() => _isListening = false);
      _speechToText.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 211, 219, 219),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'AI Chatbot',
          style: GoogleFonts.acme(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: _isModelInstalled
          ? AIChatView(
              systemPrompt:
                  'You are a helpful and friendly AI assistant. Please respond in Bengali or English as requested.',
              suggestions: const [
                'What can you do?',
                'Tell me a joke!',
                'Write a poem about Flutter.',
              ],
              showUsage: true,
              onResponse: (response) {
                if (response.text.isNotEmpty) {
                  _flutterTts.speak(response.text);
                }
              },
              theme: AIChatTheme(
                primaryColor: const Color(0xFFC6C1D2),
                userBubbleColor: const Color(0xFFC1D7D5),
                aiBubbleColor: const Color(0xFF2D2D2D),
                backgroundColor: const Color.fromARGB(255, 203, 214, 216),
                userTextColor: Colors.black87,
                aiTextColor: Colors.white,
                inputBackgroundColor: const Color(0xFFC6C1D2),
                showTimestamp: false,
                surfaceColor: const Color(0xFFC1D7D5),
                textColor: Colors.white,
                secondaryTextColor: Colors.white,
                inputBorderColor: Colors.white,
                errorColor: Colors.greenAccent,
              ),
              inputBuilder: (context, controller, onSend) {
                return Padding(
                  padding: const EdgeInsets.only(
                    left: 16.0,
                    right: 16.0,
                    bottom: 24.0,
                    top: 8.0,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 10,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: controller,
                            style: GoogleFonts.poppins(color: Colors.black87),
                            onSubmitted: (_) => onSend(),
                            decoration: InputDecoration(
                              hintText: 'Type a message...',
                              hintStyle: GoogleFonts.poppins(
                                color: Colors.grey,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: _isListening ? Colors.redAccent : const Color(0xFF2D2D2D),
                          shape: BoxShape.circle,
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 10,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: IconButton(
                          icon: Icon(
                            _isListening ? Icons.mic : Icons.mic_none,
                            color: Colors.white,
                          ),
                          onPressed: () => _listen(controller),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: const BoxDecoration(
                          color: Color(0xFF2D2D2D),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 10,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: IconButton(
                          icon: const Icon(
                            Icons.rocket_launch,
                            color: Colors.white,
                          ), // Change this icon to whatever you like!
                          onPressed: onSend,
                        ),
                      ),
                    ],
                  ),
                );
              },
            )
          : Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.cloud_download,
                      size: 64,
                      color: Colors.blueGrey,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Offline AI Model Required',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'To ensure 100% offline capability, we need to download the AI model (approx 280MB) once.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(color: Colors.black54),
                    ),
                    const SizedBox(height: 24),
                    if (_isDownloading)
                      Column(
                        children: [
                          LinearProgressIndicator(value: _downloadProgress),
                          const SizedBox(height: 8),
                          Text(
                            '${(_downloadProgress * 100).toStringAsFixed(1)}%', style: TextStyle(color: Colors.green),
                          ),
                        ],
                      )
                    else
                      ElevatedButton(
                        onPressed: _downloadModel,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 12,
                          ),
                        ),
                        child: const Text('Download Now'),
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}
