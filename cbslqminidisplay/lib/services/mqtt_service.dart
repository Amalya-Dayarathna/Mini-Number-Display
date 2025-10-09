import 'package:cbslqminidisplay/messages/notification.dart';
import 'package:cbslqminidisplay/services/topic_storage.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

class MQTTService {
  static late MqttServerClient client;
  static Function(String, String)? _messageCallback;
  static Function()? _onDisconnected;
  static Function()? _onConnected;
  static bool _isListening = false;
  static String? _currentTopic;
  static bool _isReconnecting = false;

  static Future<MqttServerClient> connect() async {
    // wait 3 seconds before connecting
    print("⏳ Waiting 15 seconds before connecting...");

    await Future.delayed(const Duration(seconds: 15));

    client = MqttServerClient(
      '100.0.0.0',
      'flutter_client_${DateTime.now().millisecondsSinceEpoch}',
    );
    client.port = 100;
    client.logging(on: false);
    client.keepAlivePeriod = 20;

    client.onConnected = () {
      print('✅ Connected to MQTT broker');
      if (_onConnected != null) {
        _onConnected!();
      }
    };
    client.onDisconnected = () {
      print('❌ Disconnected from MQTT broker');
      if (_onDisconnected != null) {
        _onDisconnected!();
      }
    };

    try {
      await client.connect();
      _setupMessageListener();
    } catch (e) {
      print('⚠️ Connection failed: $e');
      client.disconnect();
      throw Exception('MQTT Connection failed: $e');
    }
    return client;
  }

  static void _setupMessageListener() {
    if (!_isListening) {
      client.updates!.listen((List<MqttReceivedMessage<MqttMessage>> c) {
        final recMess = c[0].payload as MqttPublishMessage;
        final topic = c[0].topic;
        final message =
            MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
        print('📩 Received message on topic $topic: $message');
        if (_messageCallback != null) {
          _messageCallback!(message, topic);
        }
      });
      _isListening = true;
      print('🔊 Message listener setup complete');
    }
  }

  static void subscribe(String topic, Function(String, String) onMessage) {
    print('📡 Attempting to subscribe to: $topic');
    _messageCallback = onMessage;
    _currentTopic = topic;
    client.subscribe(topic, MqttQos.atMostOnce);
    print('✅ Subscribed to: $topic');
  }

  static void subscribeToMultiple(
      List<String> topics, Function(String, String) onMessage) {
    print('📡 Attempting to subscribe to multiple topics: $topics');
    _messageCallback = onMessage;
    for (String topic in topics) {
      client.subscribe(topic, MqttQos.atMostOnce);
      print('✅ Subscribed to: $topic');
    }
  }

  static void setOnDisconnected(Function() callback) {
    _onDisconnected = callback;
  }

  static void setOnConnected(Function() callback) {
    _onConnected = callback;
  }

  static bool isConnected() {
    return client.connectionStatus?.state == MqttConnectionState.connected;
  }

  static Future<void> reconnectAndResubscribe() async {
    if (_isReconnecting) return;
    _isReconnecting = true;

    while (!isConnected()) {
      try {
        print("🔄 Trying to reconnect to MQTT broker...");

        client.disconnect();
        await Future.delayed(const Duration(seconds: 2));

        client = MqttServerClient(
          '100.0.0.0',
          'flutter_client_${DateTime.now().millisecondsSinceEpoch}',
        );
        client.port = 100;
        client.logging(on: false);
        client.keepAlivePeriod = 20;

        client.onConnected = () {
          print('✅ Reconnected to MQTT broker');
          _isReconnecting = false;
          if (_onConnected != null) _onConnected!();
        };
        client.onDisconnected = () {
          print('❌ Disconnected again');
          if (!_isReconnecting && _onDisconnected != null) _onDisconnected!();
        };

        await client.connect();
        _isListening = false;
        _setupMessageListener();

        if (_currentTopic != null && _messageCallback != null) {
          client.subscribe(_currentTopic!, MqttQos.atMostOnce);
          print('✅ Resubscribed to $_currentTopic');
        }
      } catch (e) {
        print("⚠️ Reconnection attempt failed: $e");
        await Future.delayed(const Duration(seconds: 2)); // wait and retry
      }
    }

    _isReconnecting = false;
  }

  // static void requestNextToken() {
  //   final requestMessage = '{"action": "getNextToken"}';
  //   final builder = MqttClientPayloadBuilder();
  //   builder.addString(requestMessage);
  //   client.publishMessage(
  //       'QMS/2/4/NEXT_TOKEN_REQUEST', MqttQos.atMostOnce, builder.payload!);
  //   print('📤 Requested next token from broker');
  // }

  static Future<void> requestNextToken() async {
    try {
      // Load topic from topic.txt
      String? topic = await TopicStorage.loadTopic();

      if (topic == null || topic.isEmpty) {
        print("⚠️ Cannot send request: topic.txt is empty or missing");
        return;
      }

      final requestMessage = '{"action": "getNextToken"}';
      final builder = MqttClientPayloadBuilder();
      builder.addString(requestMessage);

      client.publishMessage(topic, MqttQos.atMostOnce, builder.payload!);
      print('📤 Requested next token on topic: $topic');
    } catch (e) {
      print('⚠️ Failed to request next token: $e');
    }
  }
}
