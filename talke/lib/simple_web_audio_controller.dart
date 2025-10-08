import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';

class SimpleWebAudioController extends GetxController
    with GetTickerProviderStateMixin {
  // Observable states
  final transcribedText = ''.obs;
  final isRecording = false.obs;
  final isProcessing = false.obs;

  // Web MediaRecorder
  html.MediaRecorder? _mediaRecorder;
  html.MediaStream? _mediaStream;
  List<html.Blob> _audioChunks = [];

  // Animation controllers
  late AnimationController pulseController;
  late AnimationController waveController;
  late Animation<double> pulseAnimation;
  late Animation<double> waveAnimation;

  static const String serverUrl = 'http://192.168.1.29:5000';

  @override
  void onInit() {
    super.onInit();
    _initializeAnimations();
    _initializeMediaRecorder();
  }

  void _initializeAnimations() {
    pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    pulseAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: pulseController, curve: Curves.easeInOut),
    );

    waveController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    waveAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: waveController, curve: Curves.easeInOut));
  }

  Future<void> _initializeMediaRecorder() async {
    try {
      print('🎙️ Initializing web media recorder...');
      // No setup needed here, we'll get permission when recording starts
      print('✅ Media recorder ready');
    } catch (e) {
      print('❌ Error initializing media recorder: $e');
    }
  }

  Future<void> startRecording() async {
    try {
      print('🎙️ Starting web recording with MediaRecorder...');

      // Get microphone permission and stream
      _mediaStream = await html.window.navigator.mediaDevices!.getUserMedia({
        'audio': {
          'sampleRate': 16000,
          'channelCount': 1,
          'echoCancellation': true,
          'noiseSuppression': true,
        },
      });

      _audioChunks.clear();

      // Create MediaRecorder
      _mediaRecorder = html.MediaRecorder(_mediaStream!, {
        'mimeType': 'audio/webm;codecs=opus',
      });

      // Handle data available
      _mediaRecorder!.addEventListener('dataavailable', (html.Event event) {
        final html.BlobEvent blobEvent = event as html.BlobEvent;
        if (blobEvent.data!.size > 0) {
          _audioChunks.add(blobEvent.data!);
          print('📁 Audio chunk received: ${blobEvent.data!.size} bytes');
        }
      });

      // Start recording
      _mediaRecorder!.start();

      // Update states
      isRecording.value = true;
      transcribedText.value = '';

      // Start animations
      pulseController.repeat(reverse: true);
      waveController.repeat(reverse: true);

      print('✅ Web recording started with MediaRecorder');
    } catch (e) {
      print('❌ Error starting recording: $e');
      _showError('Failed to start recording: $e');
    }
  }

  Future<void> stopRecording() async {
    try {
      print('🛑 Stopping web recording...');

      if (_mediaRecorder != null && _mediaRecorder!.state == 'recording') {
        _mediaRecorder!.stop();

        // Wait a bit for the data to be available
        await Future.delayed(const Duration(milliseconds: 500));

        // Stop media stream
        _mediaStream?.getTracks().forEach((track) => track.stop());

        print('🛑 Recording stopped successfully');

        // Update states
        isRecording.value = false;
        isProcessing.value = true;

        // Stop animations
        pulseController.stop();
        waveController.stop();

        if (_audioChunks.isNotEmpty) {
          print('📁 Processing ${_audioChunks.length} audio chunks...');
          await _processAudioChunks();
        } else {
          print('❌ No audio chunks received');
          _showError('Recording failed - no audio data');
          isProcessing.value = false;
        }
      }
    } catch (e) {
      print('❌ Error stopping recording: $e');
      _showError('Failed to stop recording: $e');
      isRecording.value = false;
      isProcessing.value = false;
    }
  }

  Future<void> _processAudioChunks() async {
    try {
      // Combine all audio chunks into one blob
      final html.Blob audioBlob = html.Blob(_audioChunks, 'audio/webm');
      print('📁 Combined audio blob: ${audioBlob.size} bytes');

      // Convert blob to base64
      final html.FileReader reader = html.FileReader();
      reader.readAsArrayBuffer(audioBlob);

      await reader.onLoad.first;
      final Uint8List audioBytes = Uint8List.fromList(
        reader.result as List<int>,
      );

      print('📁 Audio bytes: ${audioBytes.length}');
      await _sendAudioToServer(audioBytes);
    } catch (e) {
      print('❌ Error processing audio chunks: $e');
      _showError('Failed to process audio: $e');
      isProcessing.value = false;
    }
  }

  Future<void> _sendAudioToServer(Uint8List audioBytes) async {
    try {
      print('🚀 Sending audio to server');
      print('🌐 Server URL: $serverUrl/transcribe');

      // Encode audio to base64
      final String base64Audio = base64Encode(audioBytes);

      print('📋 Request details:');
      print('   URL: $serverUrl/transcribe');
      print('   Audio bytes: ${audioBytes.length}');
      print('   Base64 length: ${base64Audio.length} characters');

      // Send as JSON
      final Map<String, dynamic> requestData = {
        'audio_data': base64Audio,
        'filename': 'web_recording.webm',
      };

      print('📤 Sending JSON request...');
      final response = await http
          .post(
            Uri.parse('$serverUrl/transcribe'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(requestData),
          )
          .timeout(
            const Duration(minutes: 5),
            onTimeout: () {
              print('⏰ Request timed out after 5 minutes');
              throw Exception('Request timeout');
            },
          );

      print('📡 Got response! Status: ${response.statusCode}');
      print('📡 Response body: ${response.body}');

      if (response.statusCode == 200) {
        print('📊 Parsing JSON response...');
        try {
          var jsonResponse = json.decode(response.body);
          print('📊 Parsed JSON: $jsonResponse');

          String extractedText = '';
          if (jsonResponse is Map<String, dynamic>) {
            extractedText =
                jsonResponse['text']?.toString() ?? 'No text transcribed';
          } else {
            extractedText = 'Invalid response format';
          }

          print('📊 Extracted text: $extractedText');

          // Update state
          transcribedText.value = extractedText;
          isProcessing.value = false;

          print('✅ Transcription successful: ${transcribedText.value}');
          _showSuccess('Transcription completed!');
        } catch (e) {
          print('❌ JSON parsing error: $e');
          transcribedText.value = 'Error parsing server response';
          isProcessing.value = false;
          _showError('Failed to parse server response: $e');
        }
      } else {
        print('❌ Server error response: ${response.body}');
        _showError('Server error (${response.statusCode}): ${response.body}');
        isProcessing.value = false;
      }
    } catch (e) {
      print('❌ Network error details: $e');
      print('❌ Error type: ${e.runtimeType}');
      _showError('Network error: $e');
      isProcessing.value = false;
    }
  }

  void onMicPressed() {
    if (isRecording.value) {
      stopRecording();
    } else if (!isProcessing.value) {
      startRecording();
    }
  }

  Future<void> testServerConnection() async {
    try {
      print('🔍 Testing server connection...');
      var response = await http.get(Uri.parse('$serverUrl/health'));
      print(
        '🔍 Health check response: ${response.statusCode} - ${response.body}',
      );
      if (response.statusCode == 200) {
        _showSuccess('✅ Server is reachable!');
      } else {
        _showError('❌ Server responded with status: ${response.statusCode}');
      }
    } catch (e) {
      print('🔍 Health check failed: $e');
      _showError('❌ Cannot reach server: $e');
    }
  }

  void _showError(String message) {
    Get.snackbar(
      'Error',
      message,
      backgroundColor: Colors.red,
      colorText: Colors.white,
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(16),
    );
  }

  void _showSuccess(String message) {
    Get.snackbar(
      'Success',
      message,
      backgroundColor: Colors.green,
      colorText: Colors.white,
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(16),
    );
  }

  @override
  void onClose() {
    _mediaStream?.getTracks().forEach((track) => track.stop());
    pulseController.dispose();
    waveController.dispose();
    super.onClose();
  }
}
