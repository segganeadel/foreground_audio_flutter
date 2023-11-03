import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:just_audio/just_audio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeService();
  runApp(const MyApp());
}

Future<AudioPlayer> sound() async {
  final _player = AudioPlayer();
  String audioasset = 'assets/Time.mp3';
  await _player.setAudioSource(AudioSource.asset(audioasset));
  return _player;
}

Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  /// OPTIONAL, using custom notification channel id
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'my_foreground', // id
    'MY FOREGROUND SERVICE', // title
    description:
        'This channel is used for important notifications.', // description
    importance: Importance.low, // importance must be at low or higher level
  );

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: true,
      isForegroundMode: true,
      notificationChannelId: 'my_foreground',
      initialNotificationTitle: 'Chargement',
      initialNotificationContent: 'Initialisation...',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(),
  );
}

void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });

    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });
  }

  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  final player = await sound();

  service.on('playPauseSong').listen((event) {
    if (player.playing) {
      player.pause();
    } else {
      player.play();
    }
  });

  // bring to foreground
  Timer.periodic(const Duration(seconds: 1), (timer) async {
    if (service is AndroidServiceInstance) {
      if (await service.isForegroundService()) {
        service.setForegroundNotificationInfo(
          title: "Foreground audio",
          content: player.playing ? 'Playing' : 'Paused',
        );
      }
    }
  });
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool click = false;
  String text = "Stop Service";

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Service App'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ElevatedButton(
                child: const Text("Foreground Mode"),
                onPressed: () {
                  FlutterBackgroundService().invoke("setAsForeground");
                },
              ),
              ElevatedButton(
                child: const Text("Background Mode"),
                onPressed: () {
                  FlutterBackgroundService().invoke("setAsBackground");
                },
              ),
              ElevatedButton(
                child: Text(text),
                onPressed: () async {
                  final service = FlutterBackgroundService();
                  var isRunning = await service.isRunning();
                  if (isRunning) {
                    service.invoke("stopService");
                  } else {
                    service.startService();
                  }

                  if (!isRunning) {
                    text = 'Stop Service';
                  } else {
                    text = 'Start Service';
                  }
                  setState(() {});
                },
              )
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () async {
            final service = FlutterBackgroundService();
            var isRunning = await service.isRunning();
            if (isRunning) {
              service.invoke("playPauseSong");
            }
            setState(() {
              click = !click;
            });
          },
          child: Icon((click == false) ? Icons.play_arrow : Icons.pause),
        ),
      ),
    );
  }
}
