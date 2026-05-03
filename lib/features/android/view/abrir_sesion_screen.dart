import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:webview_flutter/webview_flutter.dart';

const _golfitoUrl = 'https://golfito.hacienda.go.cr/golfito/';

/// JS that searches the active page for the most likely cédula input and
/// fills it with the scanned value. Returns true if a field was filled.
/// Resilient to ASP.NET WebForms and JS frameworks (uses the native value
/// setter so React/Angular validators pick up the change).
const _autofillScript = r'''
(function(cedula) {
  try {
    const inputs = Array.from(document.querySelectorAll(
      'input[type=text], input[type=tel], input[type=number], input:not([type])'
    ));
    const kws = ['cedula','cédula','identif','documento','cliente','dimex','didi'];
    let target = inputs.find(el => {
      const blob = ((el.name||'') + ' ' + (el.id||'') + ' ' +
        (el.placeholder||'') + ' ' + (el.getAttribute('aria-label')||'') + ' ' +
        (el.getAttribute('nombremostrar')||'')).toLowerCase();
      return kws.some(k => blob.includes(k));
    });
    if (!target) return false;
    const setter = Object.getOwnPropertyDescriptor(
      window.HTMLInputElement.prototype, 'value'
    ).set;
    setter.call(target, cedula);
    target.dispatchEvent(new Event('input', { bubbles: true }));
    target.dispatchEvent(new Event('change', { bubbles: true }));
    target.focus();
    return true;
  } catch (e) { return false; }
})
''';

class AbrirSesionScreen extends StatefulWidget {
  const AbrirSesionScreen({super.key});

  @override
  State<AbrirSesionScreen> createState() => _AbrirSesionScreenState();
}

class _AbrirSesionScreenState extends State<AbrirSesionScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  final TextRecognizer _recognizer =
      TextRecognizer(script: TextRecognitionScript.latin);
  late final WebViewController _webController;
  bool _initializing = true;
  String? _initError;
  bool _processing = false;
  bool _streaming = false;
  String? _detectedId;

  static const _orientations = <DeviceOrientation, int>{
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _webController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) => _tryAutofill(),
      ))
      ..loadRequest(Uri.parse(_golfitoUrl));
    _setup();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopStream();
    _controller?.dispose();
    _recognizer.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _stopStream();
    } else if (state == AppLifecycleState.resumed && _detectedId == null) {
      _startStream();
    }
  }

  Future<void> _setup() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() {
          _initError = 'No hay cámaras disponibles.';
          _initializing = false;
        });
        return;
      }
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        back,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.nv21,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      _controller = controller;
      setState(() => _initializing = false);
      _startStream();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _initError = 'Error iniciando cámara: $e';
        _initializing = false;
      });
    }
  }

  void _startStream() {
    final controller = _controller;
    if (controller == null || _streaming) return;
    _streaming = true;
    controller.startImageStream(_onFrame);
  }

  Future<void> _stopStream() async {
    final controller = _controller;
    if (controller == null || !_streaming) return;
    _streaming = false;
    try {
      await controller.stopImageStream();
    } catch (_) {}
  }

  Future<void> _onFrame(CameraImage image) async {
    if (_processing || _detectedId != null) return;
    _processing = true;
    try {
      final input = _toInputImage(image);
      if (input == null) return;
      final result = await _recognizer.processImage(input);
      final id = _extractCedula(result.text);
      if (id != null && mounted && _detectedId == null) {
        setState(() => _detectedId = id);
        await _stopStream();
        await Clipboard.setData(ClipboardData(text: id));
        final filled = await _tryAutofill();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                filled
                    ? 'Cédula $id rellenada'
                    : 'Cédula $id copiada',
              ),
            ),
          );
        }
      }
    } catch (_) {
      // Frame failed — keep scanning.
    } finally {
      _processing = false;
    }
  }

  InputImage? _toInputImage(CameraImage image) {
    final controller = _controller;
    if (controller == null || !Platform.isAndroid) return null;
    final camera = controller.description;
    final compensation = _orientations[controller.value.deviceOrientation];
    if (compensation == null) return null;
    final rotation = InputImageRotationValue.fromRawValue(
      camera.lensDirection == CameraLensDirection.front
          ? (camera.sensorOrientation + compensation) % 360
          : (camera.sensorOrientation - compensation + 360) % 360,
    );
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (rotation == null ||
        format != InputImageFormat.nv21 ||
        image.planes.length != 1) {
      return null;
    }
    final plane = image.planes.first;
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: InputImageFormat.nv21,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  /// Costa Rican IDs:
  ///   - Cédula nacional: 9 digits, often `X-XXXX-XXXX`
  ///   - DIDI (diplomática): 10 digits
  ///   - DIMEX (residentes): 11 or 12 digits
  String? _extractCedula(String text) {
    final pattern = RegExp(r'(?<![\d-])(\d[\d \-]{8,13}\d)(?![\d-])');
    String? best;
    for (final m in pattern.allMatches(text)) {
      final raw = m.group(1)!;
      final digits = raw.replaceAll(RegExp(r'\D'), '');
      if (digits.length >= 9 && digits.length <= 12) {
        if (best == null || digits.length > best.length) {
          best = digits;
        }
      }
    }
    return best;
  }

  void _resetScan() {
    setState(() => _detectedId = null);
    _startStream();
  }

  Future<bool> _tryAutofill() async {
    final id = _detectedId;
    if (id == null) return false;
    try {
      final result = await _webController.runJavaScriptReturningResult(
        '($_autofillScript)(${jsonEncode(id)})',
      );
      return result == true || result == 'true' || result == 1;
    } catch (_) {
      return false;
    }
  }

  Future<void> _copy() async {
    final id = _detectedId;
    if (id == null) return;
    await Clipboard.setData(ClipboardData(text: id));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copiado al portapapeles')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.28,
          child: Container(
            color: Colors.black,
            width: double.infinity,
            child: _buildPreview(),
          ),
        ),
        _buildResultStrip(),
        Expanded(
          child: WebViewWidget(controller: _webController),
        ),
      ],
    );
  }

  Widget _buildPreview() {
    if (_initializing) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }
    if (_initError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            _initError!,
            style: const TextStyle(color: Colors.white),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const SizedBox.shrink();
    }
    return Stack(
      alignment: Alignment.center,
      children: [
        CameraPreview(controller),
        IgnorePointer(
          child: Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white70, width: 2),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        if (_detectedId == null)
          const Positioned(
            bottom: 8,
            child: Text(
              'Apunte a la cédula',
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
      ],
    );
  }

  Widget _buildResultStrip() {
    final id = _detectedId;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Row(
        children: [
          Expanded(
            child: Text(
              id ?? 'Esperando cédula…',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.1,
                color: id == null
                    ? Theme.of(context).hintColor
                    : Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Copiar',
            onPressed: id == null ? null : _copy,
            icon: const Icon(Icons.copy),
          ),
          IconButton(
            tooltip: 'Escanear de nuevo',
            onPressed: id == null ? null : _resetScan,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
    );
  }
}
