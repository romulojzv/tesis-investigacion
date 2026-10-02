import 'package:flutter/material.dart';

class HomeView extends StatelessWidget {
  final VoidCallback onDibujar;
  final VoidCallback onUsarPdf;

  const HomeView({
    super.key,
    required this.onDibujar,
    required this.onUsarPdf,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F0),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 40,
            vertical: 32,
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),

              const Text(
                '✨ Cuentos Mágicos ✨',
                style: TextStyle(
                  fontSize: 38,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFF39C12),
                ),
              ),

              const SizedBox(height: 12),

              const Text(
                'Elige cómo quieres comenzar tu aventura',
                style: TextStyle(
                  fontSize: 20,
                  color: Color(0xFF6D4C41),
                ),
              ),

              const SizedBox(height: 48),

              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _OpcionCard(
                      icono: Icons.brush,
                      titulo: 'Dibujar',
                      descripcion:
                          'Crea un dibujo y conviértelo en el inicio de una historia mágica.',
                      onTap: onDibujar,
                    ),

                    const SizedBox(width: 32),

                    _OpcionCard(
                      icono: Icons.picture_as_pdf,
                      titulo: 'Usar un PDF',
                      descripcion:
                          'Selecciona una lectura y transfórmala en una aventura interactiva.',
                      onTap: onUsarPdf,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OpcionCard extends StatefulWidget {
  final IconData icono;
  final String titulo;
  final String descripcion;
  final VoidCallback onTap;

  const _OpcionCard({
    required this.icono,
    required this.titulo,
    required this.descripcion,
    required this.onTap,
  });

  @override
  State<_OpcionCard> createState() => _OpcionCardState();
}

class _OpcionCardState extends State<_OpcionCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 330,
        height: 300,
        transform: _hover
            ? Matrix4.translationValues(0, -8, 0)
            : Matrix4.identity(),
        child: Material(
          color: Colors.white,
          elevation: _hover ? 10 : 4,
          borderRadius: BorderRadius.circular(28),
          child: InkWell(
            borderRadius: BorderRadius.circular(28),
            onTap: widget.onTap,
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFE0B2),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Icon(
                      widget.icono,
                      size: 48,
                      color: const Color(0xFFF39C12),
                    ),
                  ),

                  const SizedBox(height: 24),

                  Text(
                    widget.titulo,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF4E342E),
                    ),
                  ),

                  const SizedBox(height: 14),

                  Text(
                    widget.descripcion,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.4,
                      color: Color(0xFF6D4C41),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}