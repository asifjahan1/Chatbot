import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:ai_kit/ai_kit.dart';
import 'View/home_page.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'Providers/gemma_provider.dart';
import 'Providers/hybrid_provider.dart';
import 'Providers/qwen_offline_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  // Initialize Flutter Gemma (kept as fallback or if user switches)
  await FlutterGemma.initialize();

  // Initialize Qwen Offline Provider
  // Note: the modelPath will be set dynamically once the model is downloaded.
  final qwenOffline = QwenOfflineProvider();
  // qwenOffline.initialize() will be called when the model is downloaded.

  // Initialize AI Kit with Hybrid Provider
  AIKit.init(
    providers: [
      HybridProvider(
        onlineProvider: OpenAIProvider(
          model: 'qwen/qwen-2.5-7b-instruct',
          baseUrl: 'https://openrouter.ai/api/v1',
          apiKey: dotenv.env['OPENROUTER_API_KEY'] ?? '',
        ),
        offlineProvider: qwenOffline,
      ),
      HybridProvider(
        onlineProvider: GeminiProvider(
          model: 'gemini-1.5-flash',
          apiKey: dotenv.env['GEMINI_API_KEY'] ?? '',
        ),
        offlineProvider: GemmaProvider(),
      ),
    ],
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(360, 690),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (_, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'X E R V I S',
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          ),
          home: const HomePage(),
        );
      },
    );
  }
}
