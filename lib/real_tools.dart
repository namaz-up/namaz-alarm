import 'dart:io';

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

const Color green = Color(0xFF075442);
const Color darkGreen = Color(0xFF063C32);
const Color gold = Color(0xFFC5A04A);
const Color cream = Color(0xFFFFFCF4);

const String defaultWashroomQr = 'NAMAZ-ALARM-WASHROOM-001';

// =====================================================
// LIVE SELFIE SCREEN
// =====================================================

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
  XFile? _selfie;

  bool _loading = true;
  bool _takingPhoto = false;
  bool _openingScanner = false;

  String? _error;

  @override
  void initState() {
    super.initState();
    _startCamera();
  }

  Future<void> _startCamera() async {
    try {
      final cameras = await availableCameras();

      if (cameras.isEmpty) {
        throw Exception('No camera found.');
      }

      CameraDescription selectedCamera = cameras.first;

      for (final camera in cameras) {
        if (camera.lensDirection == CameraLensDirection.front) {
          selectedCamera = camera;
          break;
        }
      }

      final controller = CameraController(
        selectedCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await controller.initialize();

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _camera = controller;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error =
            'Unable to open the camera. Please check camera permission.';
      });
    }
  }

  Future<void> _takeSelfie() async {
    final camera = _camera;

    if (camera == null ||
        !camera.value.isInitialized ||
        _takingPhoto) {
      return;
    }

    setState(() {
      _takingPhoto = true;
      _error = null;
    });

    try {
      final photo = await camera.takePicture();

      if (!mounted) return;

      setState(() {
        _selfie = photo;
        _takingPhoto = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _takingPhoto = false;
        _error = 'Could not capture the selfie. Please try again.';
      });
    }
  }

  Future<void> _retakeSelfie() async {
    if (_openingScanner) return;

    setState(() {
      _selfie = null;
      _error = null;
    });
  }

  // FIX: Release the selfie camera before opening the QR scanner.
  Future<void> _continueToQr() async {
    if (_selfie == null || _openingScanner) return;

    if (!widget.continueToQr) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Live selfie captured successfully.'),
        ),
      );
      return;
    }

    setState(() {
      _openingScanner = true;
    });

    final oldCamera = _camera;
    _camera = null;

    try {
      if (oldCamera != null) {
        await oldCamera.dispose();
      }

      if (!mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const WashroomQrScannerScreen(),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open the QR scanner. Please try again.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _openingScanner = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _camera?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cream,
      appBar: AppBar(
        title: const Text('Live Selfie'),
        backgroundColor: cream,
        foregroundColor: darkGreen,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const Text(
                'Wake Up Challenge',
                style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                  color: darkGreen,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Take a selfie using your front camera to continue.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15),
              ),
              const SizedBox(height: 20),

              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    width: double.infinity,
                    color: Colors.black,
                    child: _loading
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: gold,
                            ),
                          )
                        : _error != null
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Text(
                                    _error!,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              )
                            : _selfie != null
                                ? Image.file(
                                    File(_selfie!.path),
                                    fit: BoxFit.contain,
                                  )
                                : _camera != null &&
                                        _camera!.value.isInitialized
                                    ? CameraPreview(_camera!)
                                    : const Center(
                                        child: Text(
                                          'Camera unavailable',
                                          style: TextStyle(
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              if (_selfie == null)
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed:
                        _loading || _takingPhoto || _error != null
                            ? null
                            : _takeSelfie,
                    icon: const Icon(Icons.camera_alt),
                    label: Text(
                      _takingPhoto
                          ? 'Capturing...'
                          : 'Take Live Selfie',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                )
              else ...[
                const Text(
                  'Selfie captured!',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: green,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed:
                            _openingScanner ? null : _retakeSelfie,
                        child: const Text('Retake'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed:
                            _openingScanner ? null : _continueToQr,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: green,
                          foregroundColor: Colors.white,
                        ),
                        child: Text(
                          _openingScanner
                              ? 'Opening Scanner...'
                              : widget.continueToQr
                                  ? 'Scan QR'
                                  : 'Finish',
                        ),
                      ),
                    ),
                  ],
                ),
              ],

              if (_error != null) ...[
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _error = null;
                      _loading = true;
                    });
                    _startCamera();
                  },
                  child: const Text('Try Again'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// =====================================================
// WASHROOM QR GENERATOR
// =====================================================

class WashroomQrGeneratorScreen extends StatefulWidget {
  const WashroomQrGeneratorScreen({super.key});

  @override
  State<WashroomQrGeneratorScreen> createState() =>
      _WashroomQrGeneratorScreenState();
}

class _WashroomQrGeneratorScreenState
    extends State<WashroomQrGeneratorScreen> {
  final TextEditingController _controller =
      TextEditingController(text: defaultWashroomQr);

  String _qrValue = defaultWashroomQr;

  Future<void> _saveQr() async {
    final value = _controller.text.trim();

    if (value.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a QR code value.'),
        ),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();

    await prefs.setString('washroom_qr_code', value);

    if (!mounted) return;

    setState(() {
      _qrValue = value;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Washroom QR code saved.'),
      ),
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
      backgroundColor: cream,
      appBar: AppBar(
        title: const Text('Washroom QR Generator'),
        backgroundColor: cream,
        foregroundColor: darkGreen,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Create Your Washroom QR',
            style: TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.bold,
              color: darkGreen,
            ),
          ),
          const SizedBox(height: 20),

          TextField(
            controller: _controller,
            decoration: const InputDecoration(
              labelText: 'QR code value',
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 12),

          ElevatedButton(
            onPressed: _saveQr,
            style: ElevatedButton.styleFrom(
              backgroundColor: green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Save QR Code'),
          ),

          const SizedBox(height: 25),

          Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: QrImageView(
                data: _qrValue,
                version: QrVersions.auto,
                size: 240,
              ),
            ),
          ),

          const SizedBox(height: 12),

          const Text(
            'Print this QR code and place it in your washroom.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// =====================================================
// WASHROOM QR SCANNER
// =====================================================

class WashroomQrScannerScreen extends StatefulWidget {
  const WashroomQrScannerScreen({super.key});

  @override
  State<WashroomQrScannerScreen> createState() =>
      _WashroomQrScannerScreenState();
}

class _WashroomQrScannerScreenState
    extends State<WashroomQrScannerScreen> {
  bool _processing = false;

  final MobileScannerController _scannerController =
      MobileScannerController();

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_processing) return;

    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue;

      if (value == null || value.isEmpty) continue;

      _processing = true;

      try {
        await _scannerController.stop();

        final prefs = await SharedPreferences.getInstance();

        final expected =
            prefs.getString('washroom_qr_code') ??
                defaultWashroomQr;

        if (!mounted) return;

        if (value == expected) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => const ChallengeCompleteScreen(),
            ),
          );
        } else {
          _processing = false;

          await _scannerController.start();

          if (!mounted) return;

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Incorrect QR code. Scan your washroom QR.',
              ),
            ),
          );
        }
      } catch (e) {
        _processing = false;

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Scanner error. Please try again.'),
          ),
        );
      }

      return;
    }
  }

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cream,
      appBar: AppBar(
        title: const Text('Scan Washroom QR'),
        backgroundColor: cream,
        foregroundColor: darkGreen,
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              'Go to your washroom and scan the QR code to complete the challenge.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
          ),

          Expanded(
            child: MobileScanner(
              controller: _scannerController,
              onDetect: _onDetect,
            ),
          ),
        ],
      ),
    );
  }
}

// =====================================================
// CHALLENGE COMPLETED
// =====================================================

class ChallengeCompleteScreen extends StatelessWidget {
  const ChallengeCompleteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cream,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.check_circle,
                color: green,
                size: 90,
              ),

              const SizedBox(height: 20),

              const Text(
                'Challenge Completed!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: darkGreen,
                ),
              ),

              const SizedBox(height: 12),

              const Text(
                'You completed the selfie and washroom QR challenge.',
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 25),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).popUntil(
                      (route) => route.isFirst,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: green,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Finish'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
