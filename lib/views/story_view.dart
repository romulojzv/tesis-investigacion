import 'package:flutter/material.dart';

import '../controllers/story_controller.dart';
import '../models/cuento.dart';

class StoryView extends StatefulWidget {
  final StoryController controller;

  const StoryView({
    super.key,
    required this.controller,
  });

  @override
  State<StoryView> createState() => _StoryViewState();
}

class _StoryViewState extends State<StoryView> {
  final TextEditingController _personajeController =
      TextEditingController();

  final TextEditingController _decisionController =
      TextEditingController();

  String _resultado = '';

  late Cuento _cuento;

  @override
  void initState() {
    super.initState();

    _cuento = Cuento(
      id: 'cuento-demo',
      titulo: 'Aventura de prueba',
      personajePrincipal: 'Personaje',
    );
  }

  Future<void> _agregarEscenaInicial() async {
    final nombre = _personajeController.text.trim();

    if (nombre.isEmpty) {
      setState(() {
        _resultado = 'Ingrese el nombre del personaje.';
      });
      return;
    }

    _cuento = Cuento(
      id: 'cuento-demo',
      titulo: 'Aventura de prueba',
      personajePrincipal: nombre,
    );

    await widget.controller.agregarEscena(
      cuento: _cuento,
      contenido:
          '$nombre llegó a un bosque misterioso y encontró dos caminos.',
    );

    setState(() {
      _resultado =
          'Escena inicial creada correctamente para $nombre.';
    });
  }

  Future<void> _generarContexto() async {
    final decision = _decisionController.text.trim();

    if (_cuento.escenas.isEmpty) {
      setState(() {
        _resultado =
            'Primero debe generarse la escena inicial.';
      });
      return;
    }

    if (decision.isEmpty) {
      setState(() {
        _resultado =
            'Ingrese una decisión narrativa.';
      });
      return;
    }

    final contexto =
        await widget.controller.prepararContinuacion(
      cuento: _cuento,
      decision: decision,
    );

    setState(() {
      _resultado = contexto;
    });
  }

  @override
  void dispose() {
    _personajeController.dispose();
    _decisionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cuentos Mágicos'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Prototipo de continuidad narrativa',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),

            TextField(
              controller: _personajeController,
              decoration: const InputDecoration(
                labelText: 'Nombre del personaje',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 12),

            ElevatedButton(
              onPressed: _agregarEscenaInicial,
              child: const Text(
                'Crear escena inicial',
              ),
            ),

            const SizedBox(height: 24),

            TextField(
              controller: _decisionController,
              decoration: const InputDecoration(
                labelText:
                    'Decisión del estudiante',
                hintText:
                    'Ejemplo: Tomar el camino de la izquierda',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 12),

            ElevatedButton(
              onPressed: _generarContexto,
              child: const Text(
                'Preparar continuación',
              ),
            ),

            const SizedBox(height: 24),

            const Text(
              'Resultado:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            Expanded(
              child: SingleChildScrollView(
                child: SelectableText(_resultado),
              ),
            ),
          ],
        ),
      ),
    );
  }
}