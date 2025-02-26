import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class MobileScannerQR extends StatelessWidget {
  final Function(String) onQrScanned;
  const MobileScannerQR({Key? key, required this.onQrScanned}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MobileScanner(
      onDetect: (barcodeCapture) {
        if (barcodeCapture.barcodes.isNotEmpty) {
          final code = barcodeCapture.barcodes.first.rawValue;
          if (code != null && code.isNotEmpty) {
            onQrScanned(code);
          }
        }
      },
    );
  }
}
