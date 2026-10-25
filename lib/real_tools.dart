import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

const Color _green = Color(0xFF075442);
const Color _darkGreen = Color(0xFF063C32);

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
  bool _completed = false;
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
        throw Exception('No camera found.');
      }

      final frontCameras = cameras
          .where(
            (camera) =>
                camera.lensDirection == CameraLensDirection.front,
          )
          .toList();

      final selectedCamera =
          frontCameras.isNotEmpty ? frontCameras.first : cameras.first;

      final controller = CameraController(
        selectedCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.nv21,
      );

      await controller.initialize();

      final detector = FaceDetector(
        options: FaceDetectorOptions(
          performanceMode: FaceDetectorMode.fast,
          enableLandmarks: false,
          enableContours: false,
          enableClassification: false,
          minFaceSize: 0.10,
        ),
      );

      if (!mounted) {
        await controller.dispose();
        await detector.close();
        return;
      }

      _camera = controller;
      _detector = detector;

      await controller.startImageStream(_processCameraImage);

      if (!mounted) return;

      setState(() {
        _initializing = false;
        _message = 'Looking for your face...';
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

  Future<void> _processCameraImage(CameraImage image) async {
    if (_processing || _completed || _detector == null || _camera == null) {
      return;
    }

    _processing = true;

    try {
      final camera = _camera!;
      final rotation = InputImageRotationValue.fromRawValue(
        camera.description.sensorOrientation,
      );

      if (rotation == null) return;

      final format = InputImageFormatValue.fromRawValue(image.format.raw);

      if (format == null) return;

      final WriteBuffer buffer = WriteBuffer();

      for (final plane in image.planes) {
        buffer.putUint8List(plane.bytes);
      }

      final bytes = buffer.done().buffer.asUint8List();

      final inputImage = InputImage.fromBytes(
        bytes: bytes,
        metadata: InputImageMetadata(
          size: Size(
            image.width.toDouble(),
            image.height.toDouble(),
          ),
          rotation: rotation,
          format: format,
          bytesPerRow: image.planes.first.bytesPerRow,
        ),
      );

      final faces = await _detector!.processImage(inputImage);

      if (!mounted || _completed) return;

      if (faces.isNotEmpty) {
        _completed = true;

        setState(() {
          _message = 'Face detected successfully!';
        });

        await _camera!.stopImageStream();

        if (!mounted) return;

        if (widget.continueToQr) {
          await Future.delayed(const Duration(milliseconds: 500));

          if (!mounted) return;

          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const WashroomQrScannerScreen(),
            ),
          );

          if (!mounted) return;

          Navigator.of(context).pop(true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Face detected successfully.')),
          );
        }
      } else {
        setState(() {
          _message = 'Looking for your face...';
        });
      }
    } catch (e) {
      // Continue trying on subsequent camera frames.
    } finally {
      _processing = false;
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
      appBar: AppBar(title: const Text('Automatic Face Detection')),
      body: SafeArea(
        child: _initializing
            ? const Center(child: CircularProgressIndicator())
            : _error != null
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
                        height: 380,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(24),
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
                      const SizedBox(height: 24),
                      Icon(
                        _completed ? Icons.check_circle : Icons.face,
                        size: 54,
                        color: _green,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _message,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Keep your face clearly visible in the camera. '
                        'Detection happens automatically. This checks '
                        'for a face; it does not verify identity or '
                        'prove that a live person is present.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.black54,
                          fontSize: 13,
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
            'A QR code can be photographed or copied.',
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
  final MobileScannerController _scanner = MobileScannerController();

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

      if (expected != null && expected.isNotEmpty && value == expected) {
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
          _message = 'QR code does not match the saved washroom code.';
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
              const Icon(Icons.check_circle, color: _green, size: 90),
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
                  Navigator.of(context).popUntil((route) => route.isFirst);
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
