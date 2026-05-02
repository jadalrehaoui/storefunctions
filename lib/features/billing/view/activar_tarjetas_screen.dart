import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class ActivarTarjetasScreen extends StatefulWidget {
  const ActivarTarjetasScreen({super.key});

  @override
  State<ActivarTarjetasScreen> createState() => _ActivarTarjetasScreenState();
}

class _ActivarTarjetasScreenState extends State<ActivarTarjetasScreen>
    with SingleTickerProviderStateMixin {
  // USB scanner sink: scanners emulate keyboards and end with Enter.
  final TextEditingController _scannerSink = TextEditingController();
  final FocusNode _scannerFocus = FocusNode();

  // Camera scanner.
  late final MobileScannerController _camera = MobileScannerController(
    formats: const [
      BarcodeFormat.pdf417,
      BarcodeFormat.qrCode,
      BarcodeFormat.code128,
      BarcodeFormat.dataMatrix,
    ],
    detectionSpeed: DetectionSpeed.normal,
    detectionTimeoutMs: 800,
  );
  bool _cameraSupported = true;
  bool _cameraEnabled = true;

  // Visual flash on success.
  late final AnimationController _flash = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 350),
  );

  // State.
  String? _currentRaw;
  String? _currentParsed;
  String? _currentFormat;
  String? _lastDedupeKey;
  DateTime _lastScanAt = DateTime.fromMillisecondsSinceEpoch(0);
  final List<_ScanRecord> _history = [];

  static const int _historyMax = 10;
  static const Duration _dedupeWindow = Duration(milliseconds: 1500);

  @override
  void initState() {
    super.initState();
    _cameraSupported = defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scannerFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _scannerSink.dispose();
    _scannerFocus.dispose();
    _camera.dispose();
    _flash.dispose();
    super.dispose();
  }

  /// Both camera + USB sources funnel here.
  void _handleScan(String rawText, {String format = 'unknown'}) {
    final now = DateTime.now();
    final key = '$format|$rawText';
    if (key == _lastDedupeKey &&
        now.difference(_lastScanAt) < _dedupeWindow) {
      return;
    }
    _lastDedupeKey = key;
    _lastScanAt = now;

    final parsed = _parseId(rawText);

    setState(() {
      _currentRaw = rawText;
      _currentParsed = parsed;
      _currentFormat = format;
      _history.insert(
        0,
        _ScanRecord(
          timestamp: now,
          raw: rawText,
          parsed: parsed,
          format: format,
        ),
      );
      if (_history.length > _historyMax) _history.removeLast();
    });

    Clipboard.setData(ClipboardData(text: parsed));
    SystemSound.play(SystemSoundType.alert);
    _flash.forward(from: 0);
  }

  /// Parses common ID formats. AAMVA PDF417 driver's licenses include a `DAQ`
  /// field with the license number. Falls back to the raw payload.
  String _parseId(String raw) {
    // AAMVA: extract DAQ (license number) — line-prefixed field.
    final daq = RegExp(r'^DAQ([^\r\n]+)', multiLine: true).firstMatch(raw);
    if (daq != null) return daq.group(1)!.trim();
    // Some scanners send a JSON-ish payload; try common ID keys.
    final json = RegExp(r'"(?:id|license|cardId)"\s*:\s*"([^"]+)"')
        .firstMatch(raw);
    if (json != null) return json.group(1)!.trim();
    return raw.trim();
  }

  void _onSinkSubmitted(String value) {
    final v = value.trim();
    if (v.isEmpty) return;
    _handleScan(v, format: 'usb');
    _scannerSink.clear();
    _scannerFocus.requestFocus();
  }

  void _onCameraDetect(BarcodeCapture capture) {
    for (final b in capture.barcodes) {
      final text = b.rawValue;
      if (text == null || text.isEmpty) continue;
      _handleScan(text, format: _formatLabel(b.format));
      return;
    }
  }

  String _formatLabel(BarcodeFormat f) {
    switch (f) {
      case BarcodeFormat.pdf417:
        return 'PDF417';
      case BarcodeFormat.qrCode:
        return 'QR';
      case BarcodeFormat.code128:
        return 'Code128';
      case BarcodeFormat.dataMatrix:
        return 'DataMatrix';
      default:
        return f.name;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      // Click anywhere to keep USB-scanner focus on the sink.
      onTap: () => _scannerFocus.requestFocus(),
      behavior: HitTestBehavior.translucent,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Activar Tarjetas',
                        style: theme.textTheme.headlineSmall),
                    const Spacer(),
                    if (_cameraSupported)
                      IconButton.outlined(
                        onPressed: () {
                          setState(() => _cameraEnabled = !_cameraEnabled);
                          if (_cameraEnabled) {
                            _camera.start();
                          } else {
                            _camera.stop();
                          }
                        },
                        icon: Icon(_cameraEnabled
                            ? Icons.videocam_outlined
                            : Icons.videocam_off_outlined),
                        tooltip: _cameraEnabled
                            ? 'Apagar cámara'
                            : 'Encender cámara',
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(flex: 5, child: _buildLeftPanel(theme)),
                      const SizedBox(width: 16),
                      Expanded(flex: 4, child: _buildRightPanel(theme)),
                    ],
                  ),
                ),
                _buildHiddenSink(),
              ],
            ),
          ),
          // Visual flash overlay.
          IgnorePointer(
            child: AnimatedBuilder(
              animation: _flash,
              builder: (context, _) => Container(
                color: Colors.greenAccent
                    .withValues(alpha: _flash.value * 0.35),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeftPanel(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(12),
            border:
                Border.all(color: theme.colorScheme.outlineVariant, width: 1),
          ),
          height: 280,
          clipBehavior: Clip.antiAlias,
          child: !_cameraSupported
              ? Center(
                  child: Text(
                    'Cámara no soportada en esta plataforma.\nUsa el lector USB.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: Colors.white70),
                  ),
                )
              : !_cameraEnabled
                  ? Center(
                      child: Text(
                        'Cámara apagada',
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: Colors.white70),
                      ),
                    )
                  : MobileScanner(
                      controller: _camera,
                      onDetect: _onCameraDetect,
                      errorBuilder: (context, error, child) => Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'Error de cámara: ${error.errorCode.name}\nUsa el lector USB.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(color: Colors.white70),
                          ),
                        ),
                      ),
                    ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('ID DETECTADO',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      )),
                  const Spacer(),
                  if (_currentFormat != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _currentFormat!,
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: SelectableText(
                  _currentParsed ?? '—',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 36,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  FilledButton.icon(
                    onPressed: _currentParsed == null
                        ? null
                        : () {
                            Clipboard.setData(
                                ClipboardData(text: _currentParsed!));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Copiado al portapapeles'),
                                  duration: Duration(seconds: 1)),
                            );
                          },
                    icon: const Icon(Icons.copy_outlined, size: 16),
                    label: const Text('Copiar'),
                  ),
                  const SizedBox(width: 8),
                  if (_currentRaw != null && _currentRaw != _currentParsed)
                    Expanded(
                      child: Text(
                        'Raw: ${_currentRaw!.length > 80 ? '${_currentRaw!.substring(0, 80)}…' : _currentRaw!}',
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer
                                .withValues(alpha: 0.7),
                            fontFamily: 'monospace'),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRightPanel(ThemeData theme) {
    final timeFmt = DateFormat('HH:mm:ss');
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow,
              border: Border(
                bottom: BorderSide(color: theme.colorScheme.outlineVariant),
              ),
            ),
            child: Row(
              children: [
                Text('Últimos escaneos',
                    style: theme.textTheme.titleSmall),
                const Spacer(),
                if (_history.isNotEmpty)
                  TextButton.icon(
                    onPressed: () => setState(_history.clear),
                    icon: const Icon(Icons.delete_sweep_outlined, size: 14),
                    label: const Text('Limpiar'),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _history.isEmpty
                ? Center(
                    child: Text('Sin escaneos aún',
                        style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant)),
                  )
                : ListView.separated(
                    itemCount: _history.length,
                    separatorBuilder: (_, __) =>
                        Divider(height: 1, color: theme.colorScheme.outlineVariant),
                    itemBuilder: (context, i) {
                      final r = _history[i];
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(timeFmt.format(r.timestamp),
                                    style: theme.textTheme.labelSmall?.copyWith(
                                        color: theme
                                            .colorScheme.onSurfaceVariant)),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.secondaryContainer,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    r.format,
                                    style: theme.textTheme.labelSmall
                                        ?.copyWith(fontSize: 10),
                                  ),
                                ),
                                const Spacer(),
                                IconButton(
                                  onPressed: () => Clipboard.setData(
                                      ClipboardData(text: r.parsed)),
                                  icon: const Icon(Icons.copy_outlined,
                                      size: 14),
                                  tooltip: 'Copiar ID',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                      minWidth: 24, minHeight: 24),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              r.parsed,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (r.raw != r.parsed)
                              Text(
                                'raw: ${r.raw.length > 60 ? '${r.raw.substring(0, 60)}…' : r.raw}',
                                style: theme.textTheme.labelSmall?.copyWith(
                                    fontFamily: 'monospace',
                                    color:
                                        theme.colorScheme.onSurfaceVariant),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  /// Hidden but always-focused field that captures USB scanner keystrokes.
  /// Scanners send the payload very fast and end with a newline (Enter).
  Widget _buildHiddenSink() {
    return SizedBox(
      width: 1,
      height: 1,
      child: Opacity(
        opacity: 0,
        child: TextField(
          controller: _scannerSink,
          focusNode: _scannerFocus,
          autofocus: true,
          // No minLines/maxLines + textInputAction.send means Enter triggers submit.
          textInputAction: TextInputAction.send,
          onSubmitted: _onSinkSubmitted,
        ),
      ),
    );
  }
}

class _ScanRecord {
  final DateTime timestamp;
  final String raw;
  final String parsed;
  final String format;

  _ScanRecord({
    required this.timestamp,
    required this.raw,
    required this.parsed,
    required this.format,
  });
}
