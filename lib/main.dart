import 'dart:async';
import 'dart:io';
import 'package:adhan/adhan.dart';
import 'package:alarm/alarm.dart';
import 'package:camera/camera.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:path_provider/path_provider.dart';
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

AlarmSettings buildSettings(int id, DateTime time, String? sound) {
  return AlarmSettings(
    id: id,
    dateTime: time,
    assetAudioPath: sound ?? 'assets/drum.wav',
    loopAudio: true,
    vibrate: true,
    warningNotificationOnKill: false,
    androidFullScreenIntent: true,
    androidStopAlarmOnTermination: false,
    volumeSettings: VolumeSettings.fixed(volume: 1.0, volumeEnforced: true),
    notificationSettings: const NotificationSettings(
      title: 'Fajr time',
      body: 'Wake up for namaz',
      androidStopAlarmOnDismiss: false,
    ),
  );
}

// Returns the saved custom sound path, or null to use the default drum.
Future<String?> savedSound() async {
  final sp = await SharedPreferences.getInstance();
  final path = sp.getString('sound');
  if (path != null && File(path).existsSync()) return path;
  return null;
}

// Sets alarms for the next 7 days. Opening the app again refreshes them.
Future<String> scheduleFajr() async {
  final sp = await SharedPreferences.getInstance();
  final lat = sp.getDouble('lat');
  final lng = sp.getDouble('lng');
  if (lat == null || lng == null) return 'Location not saved yet.';
  final sound = await savedSound();
  final params = CalculationMethod.karachi.getParameters();
  final now = DateTime.now();
  DateTime? first;
  for (int i = 0; i < 7; i++) {
    final day = now.add(Duration(days: i));
    final times = PrayerTimes(
        Coordinates(lat, lng), DateComponents.from(day), params);
    final fajr = times.fajr.toLocal();
    if (fajr.isAfter(now)) {
      await Alarm.set(alarmSettings: buildSettings(100 + i, fajr, sound));
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
      options: FaceDetectorOptions(
          enableClassification: true,
          performanceMode: FaceDetectorMode.accurate));
  CameraController? cam;
  Timer? timer;
  CameraDescription? camDesc;
  bool busy = false;
  String status = 'Looking for your face...';
  String soundName = 'Drum (default)';

  @override
  void initState() {
    super.initState();
    sub = Alarm.ringing.listen((alarmSet) {
      if (alarmSet.alarms.isEmpty) return;
      ringingId = alarmSet.alarms.first.id;
      beginVerification();
    });
    loadSoundName();
  }

  Future<void> loadSoundName() async {
    final sp = await SharedPreferences.getInstance();
    final path = await savedSound();
    if (mounted) {
      setState(() => soundName =
          path == null ? 'Drum (default)' : (sp.getString('soundName') ?? 'My sound'));
    }
  }

  Future<void> pickSound() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.audio);
      if (result == null || result.files.single.path == null) return;
      final name = result.files.single.name;
      final safe = name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
      final dir = await getApplicationDocumentsDirectory();
      final dest = await File(result.files.single.path!)
          .copy('${dir.path}/alarm_sound_$safe');
      final sp = await SharedPreferences.getInstance();
      await sp.setString('sound', dest.path);
      await sp.setString('soundName', name);
      final msg = await scheduleFajr();
      await loadSoundName();
      if (mounted) setState(() => info = 'Sound saved: $name. $msg');
    } catch (e) {
      if (mounted) setState(() => info = 'Could not use that file: $e');
    }
  }

  Future<void> useDefaultSound() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove('sound');
    await sp.remove('soundName');
    final msg = await scheduleFajr();
    await loadSoundName();
    if (mounted) setState(() => info = 'Using the drum sound. $msg');
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
    final sound = await savedSound();
    await Alarm.set(
        alarmSettings: buildSettings(testAlarmId,
            DateTime.now().add(const Duration(seconds: 15)), sound));
    if (mounted) setState(() => info = 'Test alarm will ring in 15 seconds.');
  }

  Future<void> beginVerification() async {
    if (step != 0) return;
    setState(() {
      step = 1;
      status = 'Looking for your face...';
    });
    try {
      final cams = await availableCameras();
      final front = cams.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.front,
          orElse: () => cams.first);
      camDesc = front;
      cam = CameraController(front, ResolutionPreset.medium,
          enableAudio: false, imageFormatGroup: ImageFormatGroup.nv21);
      await cam!.initialize();
      if (!mounted) return;
      setState(() {});
      await cam!.startImageStream(onFrame);
    } catch (e) {
      // Camera failed: go to the QR step so you are never stuck.
      if (mounted) setState(() => step = 2);
    }
  }

  void setStatus(String t) {
    if (mounted) setState(() => status = t);
  }

  InputImage? toInputImage(CameraImage image) {
    final desc = camDesc;
    if (desc == null) return null;
    final rotation = InputImageRotationValue.fromRawValue(desc.sensorOrientation);
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (rotation == null || format != InputImageFormat.nv21) return null;
    if (image.planes.length != 1) return null;
    final plane = image.planes.first;
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  // Runs on every camera frame. Face must be visible and smiling.
  Future<void> onFrame(CameraImage image) async {
    if (busy || step != 1) return;
    busy = true;
    try {
      final input = toInputImage(image);
      if (input == null) {
        setStatus('Camera picture format not supported on this phone.');
      } else {
        final faces = await detector.processImage(input);
        if (faces.isEmpty) {
          setStatus('No face found. Hold the phone in front of your face, in light.');
        } else {
          final p = faces.first.smilingProbability ?? 0;
          if (p > 0.5) {
            final c = cam;
            cam = null;
            if (mounted) setState(() => step = 2);
            try {
              await c?.stopImageStream();
            } catch (_) {}
            await c?.dispose();
          } else {
            setStatus('Face found. Smile bigger! (${(p * 100).round()}%)');
          }
        }
      }
    } catch (e) {
      setStatus('Face check problem: $e');
    }
    await Future.delayed(const Duration(milliseconds: 300));
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
    try {
      await c?.stopImageStream();
    } catch (_) {}
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
      const SizedBox(height: 12),
      OutlinedButton(
          onPressed: pickSound,
          child: const Text('3. Choose my own alarm sound from phone')),
      Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text('Current sound: $soundName')),
      TextButton(
          onPressed: useDefaultSound,
          child: const Text('Use the default drum sound')),
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
                  ? 'Look at the camera and smile'
                  : 'Go to the washroom tap and scan the QR code',
              style: const TextStyle(fontSize: 22))),
      if (step == 1)
        Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(status, textAlign: TextAlign.center)),
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
