import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:tesis_investigacion/services/document_service.dart';

void main() {
  group('DocumentService', () {
    late DocumentService service;

    setUp(() {
      service = DocumentService();
    });

    test('acepta firma PDF válida', () {
      final bytes = Uint8List.fromList([
        0x25, // %
        0x50, // P
        0x44, // D
        0x46, // F
        0x2D, // -
        0x31,
        0x2E,
        0x37,
      ]);

      expect(service.validarPdf(bytes), isTrue);
    });

    test('rechaza archivo sin firma PDF', () {
      final bytes = Uint8List.fromList([1, 2, 3, 4, 5]);

      expect(service.validarPdf(bytes), isFalse);
    });

    test('rechaza PDF vacío', () async {
      expect(
        () => service.procesarPdf(
          nombreArchivo: 'cuento.pdf',
          pdfBytes: Uint8List(0),
        ),
        throwsArgumentError,
      );
    });

    test('rechaza nombre de archivo vacío', () async {
      final bytes = Uint8List.fromList([0x25, 0x50, 0x44, 0x46, 0x2D]);

      expect(
        () => service.procesarPdf(nombreArchivo: '   ', pdfBytes: bytes),
        throwsArgumentError,
      );
    });
  });
}
