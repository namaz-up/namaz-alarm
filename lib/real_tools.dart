
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _washroomCodeKey = 'namaz_alarm_washroom_qr_code';

Future<String> getRegisteredWashroomCode() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(_washroomCodeKey) ?? 'NAMAZ-WASHROOM-001';
}

/// Camera capture + on-device ML Kit face detection. A detected face is not
/// identity verification or proof of liveness.
class RealFaceDetectionScreen extends StatefulWidget {
  const RealFaceDetectionScreen({super.key, this.continueToQr = false});
  final bool continueToQr;

  @override
  State<RealFaceDetectionScreen> createState() => _RealFaceDetectionScreenState();
}

class _RealFaceDetectionScreenState extends State<RealFaceDetectionScreen> {
  CameraController? _camera;
  final FaceDetector _detector = FaceDetector(
    options: FaceDetectorOptions(
      performanceMode: FaceDetectorMode.accurate,
      minFaceSize: 0.12,
    ),
  );
  bool _busy = false;
  String _status = 'Starting front cameraâ€¦';
  bool _success = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    final permission = await Permission.camera.request();
    if (!permission.isGranted) {
      if (mounted) setState(() => _status = 'Camera permission denied. Enable it in Android Settings.');
      return;
    }
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) throw Exception('No camera is available.');
      final fronts = cameras.where((c) => c.lensDirection == CameraLensDirection.front);
      final selected = fronts.isNotEmpty ? fronts.first : cameras.first;
      final camera = CameraController(selected, ResolutionPreset.medium, enableAudio: false);
      await camera.initialize();
      if (!mounted) { await camera.dispose(); return; }
      setState(() {
        _camera = camera;
        _status = 'Center your face, then tap Detect Face.';
      });
    } catch (e) {
      if (mounted) setState(() => _status = 'Camera could not start: $e');
    }
  }

  Future<void> _detect() async {
    final camera = _camera;
    if (camera == null || !camera.value.isInitialized || _busy) return;
    setState(() { _busy = true; _status = 'Capturing and checking imageâ€¦'; });
    try {
      final photo = await camera.takePicture();
      final input = InputImage.fromFilePath(photo.path);
      final faces = await _detector.processImage(input);
      if (!mounted) return;
      if (faces.isEmpty) {
        setState(() => _status = 'No face detected. Improve lighting and try again.');
        return;
      }
      setState(() { _success = true; _status = 'Face detected successfully.'; });
      if (widget.continueToQr) {
        await Future.delayed(const Duration(milliseconds: 450));
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const WashroomQrScannerScreen()),
          );
        }
      }
    } catch (e) {
      if (mounted) setState(() => _status = 'Detection failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _camera?.dispose();
    _detector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final camera = _camera;
    return Scaffold(
      appBar: AppBar(title: const Text('Face Detection')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: camera != null && camera.value.isInitialized
                  ? CameraPreview(camera)
                  : const Center(child: CircularProgressIndicator()),
            ),
          ),
          const SizedBox(height: 18),
          Icon(_success ? Icons.check_circle : Icons.face_retouching_natural,
              size: 44, color: _success ? Colors.green : const Color(0xFF075442)),
          const SizedBox(height: 10),
          Text(_status, textAlign: TextAlign.center),
          const SizedBox(height: 14),
          SizedBox(width: double.infinity, child: FilledButton.icon(
            onPressed: _busy || camera == null ? null : _detect,
            icon: const Icon(Icons.camera_alt),
            label: Text(_busy ? 'Checkingâ€¦' : 'Detect Face'),
          )),
          const SizedBox(height: 12),
        ]),
      ),
    );
  }
}

/// Generates and saves/shares a printable QR image. The code is stored locally.
class WashroomQrGeneratorScreen extends StatefulWidget {
  const WashroomQrGeneratorScreen({super.key});
  @override
  State<WashroomQrGeneratorScreen> createState() => _WashroomQrGeneratorScreenState();
}

class _WashroomQrGeneratorScreenState extends State<WashroomQrGeneratorScreen> {
  final _controller = TextEditingController();
  final _qrKey = GlobalKey();
  bool _loading = true;
  bool _sharing = false;

  @override
  void initState() {
    super.initState();
    _loadCode();
  }

  Future<void> _loadCode() async {
    _controller.text = await getRegisteredWashroomCode();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _saveCode() async {
    final code = _controller.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a code first.')));
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_washroomCodeKey, code);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Washroom code registered on this device.')));
  }

  Future<void> _shareQr() async {
    if (_controller.text.trim().isEmpty) return;
    setState(() => _sharing = true);
    try {
      await _saveCode();
      await WidgetsBinding.instance.endOfFrame;
      final boundary = _qrKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) throw Exception('QR image is not ready.');
      final ui.Image image = await boundary.toImage(pixelRatio: 3);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('Could not render QR image.');
      final Directory dir = await getTemporaryDirectory();
      final File file = File('${dir.path}/namaz-washroom-qr.png');
      await file.writeAsBytes(byteData.buffer.asUint8List(), flush: true);
      await Share.shareXFiles([XFile(file.path)], text: 'Namaz Alarm washroom QR code');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('QR export failed: $e')));
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Washroom QR Generator')),
    body: _loading ? const Center(child: CircularProgressIndicator()) : ListView(
      padding: const EdgeInsets.all(22),
      children: [
        const Text('Register a code, then print this QR and place it in your washroom.'),
        const SizedBox(height: 16),
        TextField(controller: _controller, decoration: const InputDecoration(
          labelText: 'Washroom code', border: OutlineInputBorder(),
        ), onChanged: (_) => setState(() {})),
        const SizedBox(height: 22),
        Center(child: RepaintBoundary(key: _qrKey, child: Container(
          color: Colors.white, padding: const EdgeInsets.all(18),
          child: QrImageView(
            data: _controller.text.trim().isEmpty ? 'NAMAZ-WASHROOM-001' : _controller.text.trim(),
            size: 240, version: QrVersions.auto, errorCorrectionLevel: QrErrorCorrectLevel.H,
            backgroundColor: Colors.white,
          ),
        ))),
        const SizedBox(height: 10),
        Center(child: SelectableText(_controller.text)),
        const SizedBox(height: 20),
        FilledButton.icon(onPressed: _saveCode, icon: const Icon(Icons.save), label: const Text('Register Washroom Code')),
        const SizedBox(height: 10),
        OutlinedButton.icon(onPressed: _sharing ? null : _shareQr,
          icon: const Icon(Icons.ios_share), label: Text(_sharing ? 'Preparing QRâ€¦' : 'Save / Share QR Image')),
        const SizedBox(height: 10),
        const Text('Important: the scanner must use the same registered code. A static QR can be copied; it does not prove the phone is physically in the washroom.',
          style: TextStyle(color: Colors.black54)),
      ],
    ),
  );
}

/// Scans a real QR using the camera and compares it with the locally registered code.
class WashroomQrScannerScreen extends StatefulWidget {
  const WashroomQrScannerScreen({super.key});
  @override
  State<WashroomQrScannerScreen> createState() => _WashroomQrScannerScreenState();
}

class _WashroomQrScannerScreenState extends State<WashroomQrScannerScreen> {
  bool _handled = false;
  String _status = 'Point the camera at your registered washroom QR code.';

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handled) return;
    final values = capture.barcodes.map((b) => b.rawValue).whereType<String>();
    final value = values.isEmpty ? null : values.first;
    if (value == null) return;
    final expected = await getRegisteredWashroomCode();
    if (!mounted) return;
    if (value.trim() == expected.trim()) {
      setState(() { _handled = true; _status = 'QR verified! Challenge complete.'; });
      await Future.delayed(const Duration(milliseconds: 250));
      if (mounted) Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const ChallengeCompleteScreen()));
    } else {
      setState(() => _status = 'This QR does not match the registered washroom code. Try again.');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Washroom QR Scanner')),
    body: Column(children: [
      Expanded(child: MobileScanner(onDetect: _onDetect)),
      Padding(padding: const EdgeInsets.all(20), child: Text(_status, textAlign: TextAlign.center)),
    ]),
  );
}

class ChallengeCompleteScreen extends StatelessWidget {
  const ChallengeCompleteScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Challenge Complete')),
    body: Center(child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.check_circle, color: Color(0xFF075442), size: 76),
        const SizedBox(height: 18),
        const Text('Wake-up challenge complete', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        const Text('You can now prepare for Salah.', textAlign: TextAlign.center),
        const SizedBox(height: 20),
        FilledButton(onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst), child: const Text('Finish')),
      ]),
    )),
  );
}
