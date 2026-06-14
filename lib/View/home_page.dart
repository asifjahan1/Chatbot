import 'package:flutter/material.dart';
import 'package:ai_kit/ai_kit.dart';
import 'package:google_fonts/google_fonts.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

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
      body: AIChatView(
        systemPrompt:
            'You are a helpful and friendly AI assistant. Please respond in Bengali or English as requested.',
        suggestions: const [
          'What can you do?',
          'Tell me a joke!',
          'Write a poem about Flutter.',
        ],
        showUsage: true, // Shows token usage
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
                        hintStyle: GoogleFonts.poppins(color: Colors.grey),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
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
      ),
    );
  }
}
