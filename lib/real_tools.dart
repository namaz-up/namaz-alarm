import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

const Color _green = Color(0xFF075442);
const Color _darkGreen = Color(0xFF063C32);
const Color _gold = Color(0xFFC5A04A);

class RealFaceDetectionScreen extends StatefulWidget {
  final bool continueToQr;

  const RealFaceDetectionScreen({
    super.key,
    this.continueToQr = false,
  });

  @override
  State<RealFaceDetectionScreen> createState() =>
      _RealFaceDetectionScreenState();
}

class _RealFaceDetectionScreenState
    extends State<RealFaceDetectionScreen> {
  CameraController? _camera;
  FaceDetector? _detector;
  bool _initializing = true;
  bool _processing = false;
  String? _error;
  String _message = 'Position your face inside the camera view.';

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();

      if (cameras.isEmpty) {
        throw Exception('No camera was found on this device.');
      }

      final frontCameras = cameras
          .where((camera) =>
              camera.lensDirection == CameraLensDirection.front)
          .toList();

      final selectedCamera =
          frontCameras.isNotEmpty ? frontCameras.first : cameras.first;

      final controller = CameraController(
        selectedCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await controller.initialize();

      final detector = FaceDetector(
        options: FaceDetectorOptions(
          performanceMode: FaceDetectorMode.fast,
          enableLandmarks: false,
          enableContours: false,
          enableClassification: false,
        ),
      );

      if (!mounted) {
        await controller.dispose();
        await detector.close();
        return;
      }

      setState(() {
        _camera = controller;
        _detector = detector;
        _initializing = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _initializing = false;
        _error = 'Could not start face detection. '
            'Check camera permission and try again.\n$e';
      });
    }
  }

  Future<void> _detectFace() async {
    if (_processing || _camera == null || _detector == null) return;

    setState(() {
      _processing = true;
      _error = null;
      _message = 'Checking the captured image...';
    });

    try {
      final photo = await _camera!.takePicture();
      final inputImage = InputImage.fromFilePath(photo.path);
      final faces = await _detector!.processImage(inputImage);

      if (faces.isEmpty) {
        if (mounted) {
          setState(() {
            _message = 'No face detected. Adjust your position and retry.';
          });
        }
        return;
      }

      if (!mounted) return;

      setState(() {
        _message = 'Face detected successfully!';
      });

      if (widget.continueToQr) {
        await Future.delayed(const Duration(milliseconds: 500));

        if (!mounted) return;

        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const WashroomQrScannerScreen(),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Face detected successfully.')),
        );
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = 'Face detection failed. Please try again.';
        _message = 'Check the camera and retry.';
      });
    } finally {
      if (mounted) {
        setState(() => _processing = false);
      }
    }
  }

  @override
  void dispose() {
    _camera?.dispose();
    _detector?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Face Detection')),
      body: SafeArea(
        child: _initializing
            ? const Center(child: CircularProgressIndicator())
            : _error != null && _camera == null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _error!,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      Container(
                        height: 360,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: _camera != null &&
                                _camera!.value.isInitialized
                            ? CameraPreview(_camera!)
                            : const Center(
                                child: Text(
                                  'Camera unavailable',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        _message,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 17),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ],
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 54,
                        child: FilledButton.icon(
                          onPressed:
                              _processing ? null : _detectFace,
                          icon: const Icon(Icons.face),
                          label: Text(
                            _processing
                                ? 'Checking...'
                                : 'Detect My Face',
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: _green,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'This detects whether a face is present. It does '
                        'not verify your identity or prove that a live '
                        'person is in front of the camera.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.black54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}

class WashroomQrGeneratorScreen extends StatefulWidget {
  const WashroomQrGeneratorScreen({super.key});

  @override
  State<WashroomQrGeneratorScreen> createState() =>
      _WashroomQrGeneratorScreenState();
}

class _WashroomQrGeneratorScreenState
    extends State<WashroomQrGeneratorScreen> {
  final TextEditingController _controller =
      TextEditingController(text: 'NAMAZ-ALARM-WASHROOM-001');

  String _savedCode = 'NAMAZ-ALARM-WASHROOM-001';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadCode();
  }

  Future<void> _loadCode() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('washroom_qr_code');

    if (!mounted || saved == null || saved.isEmpty) return;

    setState(() {
      _savedCode = saved;
      _controller.text = saved;
    });
  }

  Future<void> _saveCode() async {
    final code = _controller.text.trim();

    if (code.isEmpty) {
      _showMessage('Enter a QR code value first.');
      return;
    }

    setState(() => _saving = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('washroom_qr_code', code);

      if (!mounted) return;

      setState(() {
        _savedCode = code;
        _saving = false;
      });

      _showMessage('Washroom QR code saved on this device.');
    } catch (e) {
      if (!mounted) return;

      setState(() => _saving = false);
      _showMessage('Could not save the QR code.');
    }
  }

  Future<void> _shareQr() async {
    try {
      final qrPainter = QrPainter(
        data: _savedCode,
        version: QrVersions.auto,
        errorCorrectionLevel: QrErrorCorrectLevel.H,
      );

      final ui.Image image = await qrPainter.toImage(900);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) {
        _showMessage('Could not generate QR image.');
        return;
      }

      final Uint8List bytes = byteData.buffer.asUint8List();
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/namaz_washroom_qr.png');

      await file.writeAsBytes(bytes, flush: true);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Namaz Alarm washroom QR code',
      );
    } catch (e) {
      _showMessage('Could not share the QR image.');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Washroom QR Generator')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Create your washroom QR code',
            style: TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.bold,
              color: _darkGreen,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            decoration: const InputDecoration(
              labelText: 'QR code value',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: _saving ? null : _saveCode,
            style: FilledButton.styleFrom(
              backgroundColor: _green,
              foregroundColor: Colors.white,
            ),
            child: Text(_saving ? 'Saving...' : 'Save QR Code'),
          ),
          const SizedBox(height: 24),
          Center(
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: QrImageView(
                data: _savedCode,
                version: QrVersions.auto,
                size: 240,
                backgroundColor: Colors.white,
                errorCorrectionLevel: QrErrorCorrectLevel.H,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Saved value: $_savedCode',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _shareQr,
            icon: const Icon(Icons.share),
            label: const Text('Export / Share QR Image'),
          ),
          const SizedBox(height: 12),
          const Text(
            'Print and place the QR code in your washroom. '
            'A QR code is not secret: someone could photograph or copy it.',
            style: TextStyle(color: Colors.black54),
          ),
        ],
      ),
    );
  }
}

class WashroomQrScannerScreen extends StatefulWidget {
  const WashroomQrScannerScreen({super.key});

  @override
  State<WashroomQrScannerScreen> createState() =>
      _WashroomQrScannerScreenState();
}

class _WashroomQrScannerScreenState
    extends State<WashroomQrScannerScreen> {
  final MobileScannerController _scanner =
      MobileScannerController();

  bool _handled = false;
  String? _message;

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handled) return;

    final String? value = capture.barcodes
        .map((barcode) => barcode.rawValue)
        .firstWhere(
          (value) => value != null && value.isNotEmpty,
          orElse: () => null,
        );

    if (value == null) return;

    _handled = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final expected = prefs.getString('washroom_qr_code');

      if (!mounted) return;

      if (expected != null &&
          expected.isNotEmpty &&
          value == expected) {
        await _scanner.stop();

        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const ChallengeCompleteScreen(),
          ),
        );
      } else {
        setState(() {
          _message =
              'QR code does not match the saved washroom code.';
          _handled = false;
        });
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _message = 'Could not verify the QR code.';
        _handled = false;
      });
    }
  }

  @override
  void dispose() {
    _scanner.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Washroom QR')),
      body: Column(
        children: [
          Expanded(
            child: MobileScanner(
              controller: _scanner,
              onDetect: _onDetect,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Text(
                  'Point your camera at the washroom QR code.',
                  textAlign: TextAlign.center,
                ),
                if (_message != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _message!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ChallengeCompleteScreen extends StatelessWidget {
  const ChallengeCompleteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Challenge Complete')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.check_circle,
                color: _green,
                size: 90,
              ),
              const SizedBox(height: 20),
              const Text(
                'Well Done!',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: _darkGreen,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'The face check and QR challenge are complete.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () {
                  Navigator.of(context)
                      .popUntil((route) => route.isFirst);
                },
                child: const Text('Finish'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
