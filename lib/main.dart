import 'dart:async';
import 'package:adhan/adhan.dart';
import 'package:alarm/alarm.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Text inside the QR code you paste near the washroom tap.
const washroomCode = 'WASHROOM-TAP-001';
// Emergency stop code (change it to your own number).
const emergencyCode = '2468';
const testAlarmId = 1;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Alarm.init();
  runApp(const MaterialApp(
      debugShowCheckedModeBanner: false, home: HomePage()));
}

AlarmSettings buildSettings(int id, DateTime time) {
  return AlarmSettings(
    id: id,
    dateTime: time,
    assetAudioPath: 'assets/drum.wav',
    loopAudio: true,
    vibrate: true,
    volume: 1.0,
    notificationTitle: 'Fajr time',
    notificationBody: 'Wake up for namaz',
    enableNotificationOnKill: true,
    androidFullScreenIntent: true,
  );
}

// Sets alarms for the next 7 days. Opening the app again refreshes them.
Future<String> scheduleFajr() async {
  final sp = await SharedPreferences.getInstance();
  final lat = sp.getDouble('lat');
  final lng = sp.getDouble('lng');
  if (lat == null || lng == null) return 'Location not saved yet.';
  final params = CalculationMethod.karachi.getParameters();
  final now = DateTime.now();
  DateTime? first;
  for (int i = 0; i < 7; i++) {
    final day = now.add(Duration(days: i));
    final times = PrayerTimes(
        Coordinates(lat, lng), DateComponents.from(day), params);
    final fajr = times.fajr.toLocal();
    if (fajr.isAfter(now)) {
      await Alarm.set(alarmSettings: buildSettings(100 + i, fajr));
      first ??= fajr;
    }
  }
  if (first == null) return 'No upcoming Fajr found.';
  final h = first.hour.toString().padLeft(2, '0');
  final m = first.minute.toString().padLeft(2, '0');
  return 'Next Fajr alarm: ${first.day}/${first.month} at $h:$m';
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int step = 0; // 0 home, 1 face scan, 2 washroom QR scan
  int? ringingId;
  String info = 'Press the first button to start.';
  StreamSubscription? sub;
  final detector = FaceDetector(
      options: FaceDetectorOptions(enableClassification: true));
  CameraController? cam;
  Timer? timer;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    sub = Alarm.ringStream.stream.listen((settings) {
      ringingId = settings.id;
      beginVerification();
    });
  }

  Future<void> setup() async {
    setState(() => info = 'Working...');
    await Permission.notification.request();
    await Permission.scheduleExactAlarm.request();
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      final pos = await Geolocator.getCurrentPosition();
      final sp = await SharedPreferences.getInstance();
      await sp.setDouble('lat', pos.latitude);
      await sp.setDouble('lng', pos.longitude);
    } catch (e) {
      if (mounted) setState(() => info = 'Turn on phone location and try again.');
      return;
    }
    final msg = await scheduleFajr();
    if (mounted) setState(() => info = msg);
  }

  Future<void> testAlarm() async {
    await Permission.notification.request();
    await Permission.scheduleExactAlarm.request();
    await Alarm.set(
        alarmSettings: buildSettings(
            testAlarmId, DateTime.now().add(const Duration(seconds: 15))));
    if (mounted) setState(() => info = 'Test alarm will ring in 15 seconds.');
  }

  Future<void> beginVerification() async {
    if (step != 0) return;
    setState(() => step = 1);
    try {
      final cams = await availableCameras();
      final front = cams.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.front,
          orElse: () => cams.first);
      cam = CameraController(front, ResolutionPreset.medium,
          enableAudio: false);
      await cam!.initialize();
      if (!mounted) return;
      setState(() {});
      timer = Timer.periodic(const Duration(seconds: 1), (_) => checkFace());
    } catch (e) {
      if (mounted) setState(() => step = 2);
    }
  }

  // Face must be visible and smiling, so a sleeping face fails.
  Future<void> checkFace() async {
    if (busy || cam == null || !cam!.value.isInitialized) return;
    busy = true;
    try {
      final pic = await cam!.takePicture();
      final faces =
          await detector.processImage(InputImage.fromFilePath(pic.path));
      if (faces.isNotEmpty && (faces.first.smilingProbability ?? 0) > 0.7) {
        timer?.cancel();
        final c = cam;
        cam = null;
        if (mounted) setState(() => step = 2);
        await c?.dispose();
      }
    } catch (_) {}
    busy = false;
  }

  void onQr(BarcodeCapture capture) {
    if (step == 2 && capture.barcodes.any((b) => b.rawValue == washroomCode)) {
      finish();
    }
  }

  Future<void> finish() async {
    timer?.cancel();
    final c = cam;
    cam = null;
    await c?.dispose();
    if (ringingId != null) {
      await Alarm.stop(ringingId!);
    } else {
      await Alarm.stopAll();
    }
    ringingId = null;
    final msg = await scheduleFajr();
    if (mounted) {
      setState(() {
        step = 0;
        info = 'Alarm stopped. Go pray. $msg';
      });
    }
  }

  Future<void> emergency() async {
    final c = TextEditingController();
    final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text('Emergency code'),
              content: TextField(
                  controller: c, keyboardType: TextInputType.number),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, c.text == emergencyCode),
                    child: const Text('Stop alarm'))
              ],
            ));
    if (ok == true) finish();
  }

  @override
  void dispose() {
    sub?.cancel();
    timer?.cancel();
    cam?.dispose();
    detector.close();
    super.dispose();
  }

  Widget home() {
    return ListView(padding: const EdgeInsets.all(16), children: [
      Text(info, style: const TextStyle(fontSize: 18)),
      const SizedBox(height: 20),
      ElevatedButton(
          onPressed: setup,
          child: const Text('1. Allow permissions and set Fajr alarms')),
      const SizedBox(height: 12),
      OutlinedButton(
          onPressed: testAlarm, child: const Text('2. Test alarm (15 seconds)')),
      const SizedBox(height: 20),
      const Text(
          'Washroom QR code text:\n$washroomCode\n\nOpen this app once every few days so alarms stay set.'),
    ]);
  }

  Widget verify() {
    return Column(children: [
      Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
              step == 1
                  ? 'Look at the camera and smile 😊'
                  : 'Go to the washroom tap and scan the QR code 💧',
              style: const TextStyle(fontSize: 22))),
      Expanded(
          child: step == 1
              ? (cam != null && cam!.value.isInitialized
                  ? CameraPreview(cam!)
                  : const Center(child: CircularProgressIndicator()))
              : MobileScanner(onDetect: onQr)),
      TextButton(onPressed: emergency, child: const Text('Emergency stop')),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: step == 0,
      child: Scaffold(
        appBar: AppBar(title: const Text('Namaz Alarm')),
        body: SafeArea(child: step == 0 ? home() : verify()),
      ),
    );
  }
}
