import 'dart:math';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:ai_kit/ai_kit.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
// import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:vosk_flutter/vosk_flutter.dart';
import '../Providers/qwen_offline_provider.dart';
import '../Providers/hybrid_provider.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _isModelInstalled = false;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;

  int _downloadedBytes = 0;
  int _totalBytes = 0;
  String _eta = '';
  int _lastBytes = 0;
  DateTime? _lastTime;

  final stt.SpeechToText _speechToText = stt.SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();
  bool _isListening = false;
  bool _isJarvisMode = true;

  VoskFlutterPlugin? _vosk;
  Model? _voskModel;
  Recognizer? _voskRecognizer;
  SpeechService? _speechService;
  bool _isWakeWordInitialized = false;
  bool _isProcessingCommand = false;
  TextEditingController? _chatController;
  void Function()? _onSendCallback;

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = (log(bytes) / log(1024)).floor();
    return '${(bytes / pow(1024, i)).toStringAsFixed(1)} ${suffixes[i]}';
  }

  @override
  void initState() {
    super.initState();
    _checkModel();
    _initSpeechAndTts();

    // Initialize Vosk for Wake Word
    _initVosk();
  }

  Future<void> _initVosk() async {
    try {
      var status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        debugPrint("Microphone permission denied.");
        return;
      }

      _vosk = VoskFlutterPlugin.instance();
      final modelLoader = ModelLoader();
      final enSmallModelPath = await modelLoader.loadFromAssets(
        'assets/models/vosk-model-small-en-us-0.15.zip',
      );

      _voskModel = await _vosk!.createModel(enSmallModelPath);
      _voskRecognizer = await _vosk!.createRecognizer(
        model: _voskModel!,
        sampleRate: 16000,
      );

      _speechService = await _vosk!.initSpeechService(_voskRecognizer!);

      _speechService!.onPartial().listen((e) {
        if (_isProcessingCommand) return;
        final text = e.toString().toLowerCase();
        if (text.contains("jarvis")) {
          _isProcessingCommand = true;
          _voskCallback();
        }
      });

      _speechService!.onResult().listen((e) {
        if (_isProcessingCommand) return;
        final text = e.toString().toLowerCase();
        if (text.contains("jarvis")) {
          _isProcessingCommand = true;
          _voskCallback();
        }
      });

      _isWakeWordInitialized = true;

      if (_isJarvisMode) {
        await _speechService!.start();
      }
    } catch (err) {
      debugPrint("Vosk error: $err");
    }
  }

  void _voskCallback() async {
    // Jarvis detected!
    try {
      await _speechService
          ?.stop(); // Pause wake word detection while processing
    } catch (e) {
      debugPrint("Error stopping Vosk: $e");
    }

    await _flutterTts.speak("Yes sir?");

    // Start listening for the actual command using standard SpeechToText
    bool available = await _speechToText.initialize(
      onStatus: (status) {
        // If STT stops listening (e.g. timeout or done), resume vosk
        if (status == 'done' || status == 'notListening') {
          if (_isJarvisMode) {
            // Add a small delay to avoid conflicts
            Future.delayed(const Duration(seconds: 2), () {
              _isProcessingCommand = false;
              _speechService?.start();
            });
          } else {
            _isProcessingCommand = false;
          }
        }
      },
    );

    if (available) {
      _speechToText.listen(
        onResult: (val) {
          if (val.finalResult) {
            _speechToText.stop();
            if (_chatController != null &&
                _onSendCallback != null &&
                val.recognizedWords.isNotEmpty) {
              _chatController!.text = val.recognizedWords;
              _onSendCallback!();
            }
          }
        },
        listenOptions: stt.SpeechListenOptions(
          listenFor: const Duration(seconds: 10),
          cancelOnError: true,
          partialResults: false,
        ),
      );
    } else {
      // If STT fails to initialize, resume Vosk
      _isProcessingCommand = false;
      if (_isJarvisMode) _speechService?.start();
    }
  }

  @override
  void dispose() {
    _speechService?.cancel();
    _speechService?.dispose();
    _voskRecognizer?.dispose();
    _voskModel?.dispose();
    super.dispose();
  }

  void _initSpeechAndTts() async {
    // _speechToText.initialize() is called when needed to prevent mic conflict with Vosk
    await _flutterTts.setLanguage("en-US");
    // To support Bengali, you can switch language via _flutterTts.setLanguage("bn-BD");
  }

  void _initializeQwenProvider(String path) {
    try {
      for (var name in AIKit.instance.providerNames) {
        final provider = AIKit.instance.getProvider(name);
        if (provider is HybridProvider &&
            provider.offlineProvider is QwenOfflineProvider) {
          final qwen = provider.offlineProvider as QwenOfflineProvider;
          qwen.modelPath = path;
          qwen.initialize();
        }
      }
    } catch (e) {
      print('Error initializing Qwen: $e');
    }
  }

  Future<void> _checkModel() async {
    final dir = await getApplicationDocumentsDirectory();
    final modelFile = File('${dir.path}/qwen2.5-3b.gguf');
    if (await modelFile.exists()) {
      _initializeQwenProvider(modelFile.path);
      setState(() {
        _isModelInstalled = true;
      });
    }
  }

  Future<void> _downloadModel() async {
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
    });

    try {
      final dir = await getApplicationDocumentsDirectory();
      final modelPath = '${dir.path}/qwen2.5-3b.gguf';
      final dio = Dio();

      const url =
          'https://huggingface.co/Qwen/Qwen2.5-3B-Instruct-GGUF/resolve/main/qwen2.5-3b-instruct-q4_k_m.gguf';

      _lastBytes = 0;
      _lastTime = DateTime.now();
      _eta = 'Calculating...';

      await dio.download(
        url,
        modelPath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            final now = DateTime.now();
            final duration = now.difference(_lastTime ?? now).inMilliseconds;

            // Update ETA roughly every 1 second
            if (duration >= 1000) {
              final bytesSinceLast = received - _lastBytes;
              final speedBps = bytesSinceLast / (duration / 1000);
              final bytesRemaining = total - received;

              if (speedBps > 0) {
                final secondsRemaining = (bytesRemaining / speedBps).round();
                if (secondsRemaining > 60) {
                  _eta =
                      '${secondsRemaining ~/ 60}m ${secondsRemaining % 60}s remaining';
                } else {
                  _eta = '${secondsRemaining}s remaining';
                }
              }

              _lastBytes = received;
              _lastTime = now;
            }

            setState(() {
              _downloadedBytes = received;
              _totalBytes = total;
              _downloadProgress = received / total;
            });
          }
        },
      );

      _initializeQwenProvider(modelPath);

      setState(() {
        _isDownloading = false;
        _isModelInstalled = true;
      });
    } catch (e) {
      setState(() {
        _isDownloading = false;
      });
      debugPrint('Download failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download failed. Please check internet connection.'),
          ),
        );
      }
    }
  }

  void _toggleJarvisMode() async {
    setState(() {
      _isJarvisMode = !_isJarvisMode;
    });

    if (_isJarvisMode) {
      if (_isWakeWordInitialized) {
        try {
          _isProcessingCommand = false;
          await _speechService?.start();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Jarvis Mode Activated. Say "Jarvis" to wake.'),
              ),
            );
          }
        } catch (e) {
          debugPrint("Error starting Vosk: $e");
        }
      } else {
        // Try initializing again if key was just added
        await _initVosk();
        if (!_isWakeWordInitialized && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Please add your Picovoice AccessKey to .env file to use Jarvis Mode.',
              ),
            ),
          );
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Jarvis Mode Activated. Say "Jarvis" to wake.'),
            ),
          );
        }
      }
    } else {
      try {
        await _speechService?.stop();
        _speechToText.stop();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Jarvis Mode Deactivated.')),
          );
        }
      } catch (e) {
        debugPrint("Error stopping Porcupine: $e");
      }
    }
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
        actions: [
          IconButton(
            icon: Icon(
              _isJarvisMode ? Icons.smart_toy : Icons.smart_toy_outlined,
              color: _isJarvisMode ? Colors.blue : Colors.black,
            ),
            tooltip: 'Jarvis Mode',
            onPressed: _toggleJarvisMode,
          ),
        ],
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
                _chatController = controller;
                _onSendCallback = onSend;
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
                          color: _isListening
                              ? Colors.redAccent
                              : const Color(0xFF2D2D2D),
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
                          ),
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
                      'To ensure 100% offline capability, we need to download the AI model once.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(color: Colors.black54),
                    ),
                    const SizedBox(height: 24),
                    if (_isDownloading)
                      Column(
                        children: [
                          if (_eta.isNotEmpty)
                            Text(
                              _eta,
                              style: GoogleFonts.poppins(
                                color: Colors.blueGrey,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(
                            value: _downloadProgress,
                            color: Colors.green,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${(_downloadProgress * 100).toStringAsFixed(1)}%',
                            style: const TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '(${_formatBytes(_downloadedBytes)} / ${_formatBytes(_totalBytes)})',
                            style: GoogleFonts.poppins(
                              color: Colors.black54,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      )
                    else
                      Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Colors.deepPurple, Colors.purpleAccent],
                          ),
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child: ElevatedButton(
                          onPressed: _downloadModel,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 12,
                            ),
                          ),
                          child: const Text('Download Now'),
                        ),
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}
