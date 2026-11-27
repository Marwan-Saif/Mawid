import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/primary_button.dart';
import '../l10n/desk_strings.dart';

/// Reception points the camera at the QR on the customer's booking (their phone or a printout).
/// Typing the code works too: on a desktop without a camera, or with a scratched screen.
class ScanPage extends StatefulWidget {
  const ScanPage({super.key, required this.onCode});

  /// Null means checked in; the page closes itself.
  final Future<Failure?> Function(String code) onCode;

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  final _scanner = MobileScannerController(detectionSpeed: DetectionSpeed.noDuplicates);
  final _code = TextEditingController();
  bool _busy = false;
  Failure? _failure;
  String? _lastScanned;

  @override
  void dispose() {
    _scanner.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit(String code) async {
    if (_busy || code.trim().isEmpty) return;
    setState(() {
      _busy = true;
      _failure = null;
    });
    final failure = await widget.onCode(code);
    if (!mounted) return;
    if (failure == null) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _busy = false;
        _failure = failure;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = context.desk;
    final c = context.colors;
    return Scaffold(
      appBar: AppBar(title: Text(d.scanTitle)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpace.lg),
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(color: Colors.black, child: Center(child: Icon(Icons.qr_code_scanner, color: c.border, size: 64))),
                  MobileScanner(
                    controller: _scanner,
                    onDetect: (capture) {
                      final raw = capture.barcodes.map((b) => b.rawValue).whereType<String>().firstOrNull;
                      if (raw == null || raw == _lastScanned) return;
                      _lastScanned = raw;
                      _submit(raw);
                    },
                  ),
                  IgnorePointer(
                    child: Center(
                      child: FractionallySizedBox(
                        widthFactor: .62,
                        heightFactor: .62,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white, width: 3),
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (_busy) const ColoredBox(color: Color(0x66000000), child: Center(child: CircularProgressIndicator())),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpace.md),
          Text(d.scanHint, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: AppSpace.xl),
          Text(d.typeCode, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: AppSpace.sm),
          TextField(
            controller: _code,
            textCapitalization: TextCapitalization.characters,
            textDirection: TextDirection.ltr,
            autocorrect: false,
            decoration: InputDecoration(labelText: d.codeLabel, prefixIcon: const Icon(Icons.keyboard_outlined)),
            onSubmitted: _submit,
          ),
          if (_failure != null) ...[
            const SizedBox(height: AppSpace.md),
            Text(d.failure(_failure!, context.l10n), style: TextStyle(color: c.danger, fontWeight: FontWeight.w600)),
          ],
          const SizedBox(height: AppSpace.lg),
          PrimaryButton(label: d.checkIn, icon: Icons.how_to_reg_outlined, loading: _busy, onPressed: () => _submit(_code.text)),
        ],
      ),
    );
  }
}
