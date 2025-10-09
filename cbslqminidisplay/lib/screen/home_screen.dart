import 'dart:async';

import 'package:cbslqminidisplay/messages/notification.dart';
import 'package:cbslqminidisplay/services/json_parser.dart';
import 'package:cbslqminidisplay/services/mqtt_service.dart';
import 'package:cbslqminidisplay/services/topic_storage.dart';
import 'package:flutter/material.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String number = "0000";
  bool _isConnected = false;

  // To keep the reconnection attempts in check
  Timer? _connectionChecker;

  // Mqtt topics for token display
  List<String>? _mqttTopics;

  // To avoid spamming error messages
  bool _hasShownRetryMessage = false;

  @override
  void initState() {
    super.initState();
    _connectMQTT();
  }

  @override
  void dispose() {
    _connectionChecker?.cancel(); // stop loop when screen is destroyed
    super.dispose();
  }

  void _connectMQTT() async {
    try {
      // Load all token topics from file
      _mqttTopics = await TopicStorage.loadAllTokenTopics();

      if (_mqttTopics == null || _mqttTopics!.isEmpty) {
        print("⚠️ No topics found in topic.txt. Cannot subscribe.");

        MessageUtils.showErrorMessage(context,
            'No MQTT topics found for this tab. Please check topic.txt');

        //_startConnectionChecker();
      }

      await MQTTService.connect();
      setState(() {
        _isConnected = true;

        if (_isConnected == true) {
          MessageUtils.showSuccessMessage(context, 'MQTT broker connected');
        } else {
          MessageUtils.showErrorMessage(context, 'MQTT broker disconnected');
        }

        //MessageUtils.showSuccessMessage(context, 'MQTT broker connected');
      });

      // 🔹 Start periodic connectivity checker
      _startConnectionChecker();

      MQTTService.setOnDisconnected(() {
        if (mounted && _isConnected) {
          setState(() {
            _isConnected = false;
          });
          Future.microtask(() {
            MessageUtils.showErrorMessage(context,
                'MQTT broker disconnected. Attempting to reconnect...');
          });
          _attemptReconnect();
        }
      });

      MQTTService.setOnConnected(() {
        if (mounted) {
          setState(() {
            _isConnected = true;
          });
          Future.microtask(() {
            MessageUtils.showSuccessMessage(context, 'MQTT broker connected');
          });
        } else {
          MessageUtils.showErrorMessage(context, 'MQTT broker disconnected');
        }
      });

      print('📡 Subscribing to topics: $_mqttTopics');
      MQTTService.subscribeToMultiple(_mqttTopics!, (message, topic) {
        if (topic.endsWith('BREAK_RESPONSE')) {
          print('🔄 Updating UI with CLOSED for BREAK_RESPONSE');
          setState(() {
            number = 'CLOSED';
          });
        } else {
          final tokenNumber = TokenParser.extractToken(message);
          print('📝 TOKEN RECEIVED: $tokenNumber');

          if (tokenNumber != null && mounted) {
            print('🔄 Updating UI with token: $tokenNumber');
            setState(() {
              number = tokenNumber;
            });
          } else {
            MessageUtils.showErrorMessage(
                context, 'No token extracted from message');
            print('❌ No token extracted from message');
          }
        }
      });
    } catch (e) {
      print('⚠️ MQTT connection error: $e');
      MessageUtils.showErrorMessage(context, 'MQTT connection error: $e');
    }
  }

  // Reconnect with MQTT brocker
  void _attemptReconnect() async {
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted || _isConnected) return;

    try {
      await MQTTService.isConnected();
      if (mounted) {
        setState(() {
          _isConnected = true;
        });
        MessageUtils.showSuccessMessage(context, 'Reconnected to MQTT broker');
      }
    } catch (e) {
      if (mounted && !_isConnected) {
        print('Reconnection attempt failed, retrying...');
        _attemptReconnect();
      }
    }
  }

  void _requestNextToken() {
    MQTTService.requestNextToken();
  }

  // Periodically checks connectivity every 2 seconds
  // void _startConnectionChecker() {
  //   _connectionChecker =
  //       Timer.periodic(const Duration(seconds: 2), (timer) async {
  //     if (!MQTTService.isConnected()) {
  //       if (mounted) {
  //         MessageUtils.showErrorMessage(
  //             context, 'Lost connection. Retrying...');
  //       }
  //       try {
  //         await MQTTService.reconnect();
  //       } catch (e) {
  //         print("⚠️ Retry failed: $e");
  //       }
  //     }
  //   });
  // }

  void _startConnectionChecker() {
    _connectionChecker =
        Timer.periodic(const Duration(seconds: 2), (timer) async {
      if (!MQTTService.isConnected()) {
        if (mounted) {
          setState(() {
            _isConnected = false;
          });

          // 🔹 Show error only once per disconnect
          if (!_hasShownRetryMessage) {
            MessageUtils.showErrorMessage(
                context, 'Lost connection. Retrying...');
            _hasShownRetryMessage = true;
          }
        }

        try {
          // 🔹 Attempt reconnection
          await MQTTService.reconnectAndResubscribe();

          // ✅ If reconnection succeeded
          if (MQTTService.isConnected() && mounted) {
            setState(() => _isConnected = true);
            _hasShownRetryMessage = false; // reset for next disconnect
            MessageUtils.showSuccessMessage(
                context, 'Reconnected to MQTT broker');
          }
        } catch (e) {
          // ⚠️ Reconnect failed, keep retrying silently
          print("⚠️ Retry attempt failed: $e");
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 0, 0, 0),
      body: SafeArea(
        child: Stack(
          children: [
            // Main content (big number)
            Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return Center(
                        child: FittedBox(
                          fit: BoxFit.contain,
                          child: Text(
                            number,
                            style: const TextStyle(
                              fontSize: 550,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              backgroundColor: Color.fromARGB(255, 0, 0, 0),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),

            // 🔹 Connection status dot in top-right corner
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: _isConnected ? Colors.green : Colors.red,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
