import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'package:flutter_background/flutter_background.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => DistanceTracker()),
        
      ],
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: TrackerScreen(),
    );
  }
}

class TrackerScreen extends StatelessWidget {
  const TrackerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tracker = Provider.of<DistanceTracker>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Distance Tracker'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              'Total Distance: ${tracker.totalDistance.toStringAsFixed(2)} meters',
            ),
            Text(
              'Waiting Time: ${tracker.waitingTimer.elapsed.inSeconds} seconds',
            ),
            ElevatedButton(
              onPressed: () {
                tracker.toggleWaiting();
              },
              child: Text(tracker.isWaiting ? 'Resume' : 'Wait'),
            ),
          ],
        ),
      ),
    );
  }
}

class DistanceTracker extends ChangeNotifier {
  Position? _currentPosition;
  double _totalDistance = 0.0;
  bool _isWaiting = false;
  final Stopwatch _waitingTimer = Stopwatch();
  StreamSubscription<Position>? _positionStream;

  double get totalDistance => _totalDistance;
  Stopwatch get waitingTimer => _waitingTimer;
  bool get isWaiting => _isWaiting;

  DistanceTracker() {
    _init();
  }

  Future<void> _init() async {
    await _startBackgroundTask();
    _getCurrentLocation();
  }

  Future<void> _startBackgroundTask() async {
    // Включение фоновой работы
    const androidConfig = FlutterBackgroundAndroidConfig(
      notificationTitle: "Background Tracking",
      notificationText: "App is tracking your movement",
      notificationImportance: AndroidNotificationImportance.normal,
    );
    bool hasPermissions = await FlutterBackground.hasPermissions;
    if (!hasPermissions) {
      hasPermissions = await FlutterBackground.initialize(androidConfig: androidConfig);
    }

    if (hasPermissions) {
      FlutterBackground.enableBackgroundExecution();
    }
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Location services are disabled.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error(
          'Location permissions are permanently denied, we cannot request permissions.');
    }

    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 1,
      ),
    ).listen((Position position) {
      double speed = position.speed * 3.6; // Конвертация в км/ч
      if (speed > 10 && _isWaiting) {
        toggleWaiting(); // Остановка ожидания при превышении скорости 10 км/ч
      }

      if (_currentPosition != null && !_isWaiting) {
        _totalDistance += Geolocator.distanceBetween(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          position.latitude,
          position.longitude,
        );
      }
      _currentPosition = position;

      notifyListeners();
    });
  }

  void toggleWaiting() {
    if (_isWaiting) {
      _waitingTimer.stop();
    } else {
      _waitingTimer.start();
    }
    _isWaiting = !_isWaiting;
    notifyListeners();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    FlutterBackground.disableBackgroundExecution();
    super.dispose();
  }
}
