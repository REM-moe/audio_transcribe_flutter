import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'simple_web_audio_controller.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Voice Transcription',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'SF Pro Display',
      ),
      home: const VoiceRecorderPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class VoiceRecorderPage extends StatelessWidget {
  const VoiceRecorderPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Use simple web-compatible controller
    final SimpleWebAudioController controller = Get.put(
      SimpleWebAudioController(),
    );

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              // Header
              const SizedBox(height: 40),
              Text(
                'Voice Transcription (Web)',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                'Tap the microphone to start recording',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white.withOpacity(0.7),
                ),
              ),

              // Microphone Section
              Expanded(
                flex: 2,
                child: Center(child: _buildMicrophoneButton(controller)),
              ),

              // Status Text
              _buildStatusText(controller),

              const SizedBox(height: 12),

              // Test Server Button
              ElevatedButton.icon(
                onPressed: () => controller.testServerConnection(),
                icon: const Icon(Icons.wifi_find, color: Colors.white),
                label: const Text(
                  'Test Server',
                  style: TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade600,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Transcribed Text Section
              Expanded(flex: 2, child: _buildTranscriptionCard(controller)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMicrophoneButton(SimpleWebAudioController controller) {
    return GestureDetector(
      onTap: () => controller.onMicPressed(),
      child: AnimatedBuilder(
        animation: controller.pulseAnimation,
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              // Outer ripple effect for recording
              Obx(() {
                if (controller.isRecording.value) {
                  return Stack(children: _buildRippleWaves(controller));
                }
                return const SizedBox.shrink();
              }),

              // Main microphone button
              Obx(
                () => Transform.scale(
                  scale: controller.isRecording.value
                      ? controller.pulseAnimation.value
                      : 1.0,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: controller.isRecording.value
                            ? [Colors.red.shade400, Colors.red.shade600]
                            : controller.isProcessing.value
                            ? [Colors.orange.shade400, Colors.orange.shade600]
                            : [Colors.blue.shade400, Colors.blue.shade600],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color:
                              (controller.isRecording.value
                                      ? Colors.red
                                      : Colors.blue)
                                  .withOpacity(0.3),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Icon(
                      controller.isRecording.value
                          ? Icons.stop
                          : controller.isProcessing.value
                          ? Icons.hourglass_empty
                          : Icons.mic,
                      size: 50,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _buildRippleWaves(SimpleWebAudioController controller) {
    return List.generate(3, (index) {
      return AnimatedBuilder(
        animation: controller.waveAnimation,
        builder: (context, child) {
          return Container(
            width: 120 + (index * 40) * controller.waveAnimation.value,
            height: 120 + (index * 40) * controller.waveAnimation.value,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.red.withOpacity(0.3 - (index * 0.1)),
                width: 2,
              ),
            ),
          );
        },
      );
    });
  }

  Widget _buildStatusText(SimpleWebAudioController controller) {
    return Obx(() {
      String statusText;
      Color statusColor;

      if (controller.isRecording.value) {
        statusText = '🎙️ Recording...';
        statusColor = Colors.red;
      } else if (controller.isProcessing.value) {
        statusText = '⚡ Processing...';
        statusColor = Colors.orange;
      } else {
        statusText = '🎯 Ready to record';
        statusColor = Colors.green;
      }

      return Text(
        statusText,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: statusColor,
        ),
      );
    });
  }

  Widget _buildTranscriptionCard(SimpleWebAudioController controller) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.text_snippet, color: Colors.white.withOpacity(0.8)),
              const SizedBox(width: 8),
              Text(
                'Transcription',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              child: Obx(
                () => Text(
                  controller.transcribedText.value.isEmpty
                      ? 'Your transcribed text will appear here...'
                      : controller.transcribedText.value,
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.5,
                    color: controller.transcribedText.value.isEmpty
                        ? Colors.white.withOpacity(0.5)
                        : Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
