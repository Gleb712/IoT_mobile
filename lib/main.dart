// весь импорт оставлен без изменений
import 'package:firebase_core/firebase_core.dart';
import 'options.dart';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  bool isConnected = false;

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    isConnected = true;
  } catch (e) {
    print("Ошибка инициализации Firebase: $e");
  }

  runApp(MyApp(isConnected: isConnected));
}

class MyApp extends StatelessWidget {
  final bool isConnected;

  const MyApp({Key? key, required this.isConnected}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Температура',
      theme: ThemeData.dark().copyWith(
        primaryColor: Colors.orange,
        scaffoldBackgroundColor: Colors.transparent,
      ),
      home: MyHomePage(isConnected: isConnected),
    );
  }
}

class MyHomePage extends StatefulWidget {
  final bool isConnected;

  const MyHomePage({Key? key, required this.isConnected}) : super(key: key);

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String _smokeLevel = 'Загрузка...';
  final DatabaseReference _databaseReference = FirebaseDatabase.instance.ref();
  MqttClient? _client;

  @override
  void initState() {
    super.initState();
    if (widget.isConnected) {
      _listenToSmokeLevel();
    }
    _connectToMqtt();
  }

  void _listenToSmokeLevel() {
    _databaseReference
        .child('smoke_level')
        .onValue
        .listen(
          (event) {
            setState(() {
              try {
                final data = event.snapshot.value;
                _smokeLevel = data != null ? data.toString() : 'Нет данных';
              } catch (e) {
                _smokeLevel = 'Ошибка: $e';
                print('Ошибка: $e');
              }
            });
          },
          onError: (error) {
            setState(() {
              _smokeLevel = 'Ошибка прослушивания: $error';
            });
            print('Ошибка прослушивания: $error');
          },
        );
  }

  Future<void> _connectToMqtt() async {
    _client = await connect();
  }

  Future<void> _sendMqttMessage(String topic, String message) async {
    if (_client != null &&
        _client!.connectionStatus!.state == MqttConnectionState.connected) {
      final builder = MqttClientPayloadBuilder();
      builder.addString(message);
      _client!.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
    } else {
      print('MQTT client is not connected');
    }
  }

  // В build() внутри _MyHomePageState
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Температура'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity, // Растягиваем фон на весь экран
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.blue, // сверху — холод
              Colors.red, // снизу — жар
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 10),
              Text(
                widget.isConnected
                    ? "Подключено к Firebase"
                    : "Ошибка подключения",
                style: const TextStyle(color: Colors.white70),
              ),
              const Spacer(),
              Container(
                width: 260, // Увеличен круг
                height: 260,
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.1),
                  border: Border.all(color: Colors.white38, width: 3),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Температура',
                      style: TextStyle(fontSize: 24, color: Colors.white70),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '$_smokeLevel°C',
                      style: const TextStyle(
                        fontSize: 56,
                        fontWeight: FontWeight.bold,
                        color: Colors.orangeAccent,
                        shadows: [
                          Shadow(
                            blurRadius: 6,
                            color: Colors.black87,
                            offset: Offset(2, 2),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 16,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed:
                          () => _sendMqttMessage('iot_lab1/mode', 'auto'),
                      child: const Text('Auto Mode'),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed:
                          () => _sendMqttMessage('iot_lab1/mode', 'manual'),
                      child: const Text('Manual Mode'),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed:
                          () =>
                              _sendMqttMessage('iot_lab1/actuator', 'activate'),
                      child: const Text('Activate Actuator'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

Future<MqttClient> connect() async {
  MqttServerClient client = MqttServerClient.withPort(
    'mqtt.eclipseprojects.io',
    'flutter_mqtt_client',
    1883,
  );
  client.logging(on: true);
  client.keepAlivePeriod = 60;
  client.onConnected = onConnected;
  client.onDisconnected = onDisconnected;
  client.onUnsubscribed = onUnsubscribed;
  client.onSubscribed = onSubscribed;
  client.onSubscribeFail = onSubscribeFail;
  client.pongCallback = pong;

  final connMess = MqttConnectMessage()
      .authenticateAs("username", "password")
      .withWillTopic('willtopic')
      .withWillMessage('My Will message')
      .startClean()
      .withWillQos(MqttQos.atLeastOnce);
  client.connectionMessage = connMess;
  try {
    print('Connecting');
    await client.connect();
  } catch (e) {
    print('Exception: $e');
    client.disconnect();
  }
  print("connected");

  client.updates!.listen((List<MqttReceivedMessage<MqttMessage?>>? c) {
    final recMessage = c![0].payload as MqttPublishMessage;
    final payload = MqttPublishPayload.bytesToStringAsString(
      recMessage.payload.message,
    );
    print('Received message:$payload from topic: ${c[0].topic}');
  });

  return client;
}

void onConnected() => print('Connected');
void onDisconnected() => print('Disconnected');
void onSubscribed(String topic) => print('Subscribed topic: $topic');
void onSubscribeFail(String topic) => print('Failed to subscribe $topic');
void onUnsubscribed(String? topic) => print('Unsubscribed topic: $topic');
void pong() => print('Ping response client callback invoked');
