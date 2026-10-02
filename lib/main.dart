import 'package:flutter/material.dart';

import 'views/home_view.dart';

void main() {
  runApp(const CuentosMagicosApp());
}

class CuentosMagicosApp extends StatelessWidget {
  const CuentosMagicosApp({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Cuentos Mágicos',
      theme: ThemeData(
        useMaterial3: true,
      ),
      home: HomeView(
        onDibujar: () {
          debugPrint('Seleccionó Dibujar');
        },
        onUsarPdf: () {
          debugPrint('Seleccionó PDF');
        },
      ),
    );
  }
}