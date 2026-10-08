import 'package:flutter/material.dart';

import '../models/cuento.dart';
import '../models/user_profile.dart';
import '../repositories/cuento_repository.dart';

class StudentHomeView extends StatefulWidget {
  final UserProfile perfil;
  final VoidCallback onDibujar;
  final VoidCallback onUsarPdf;
  final ValueChanged<Cuento>? onAbrirCuento;
  final VoidCallback onLogout;
  final CuentoRepository cuentoRepository;

  const StudentHomeView({
    super.key,
    required this.perfil,
    required this.onDibujar,
    required this.onUsarPdf,
    this.onAbrirCuento,
    required this.onLogout,
    required this.cuentoRepository,
  });

  @override
  State<StudentHomeView> createState() => _StudentHomeViewState();
}

class _StudentHomeViewState extends State<StudentHomeView> {
  int _tabSeleccionado = 0; // 0 = Nueva aventura, 1 = Mis aventuras

  List<Cuento>? _misCuentos;
  bool _cargandoCuentos = false;
  String? _errorCuentos;

  @override
  void initState() {
    super.initState();
    _cargarMisCuentos();
  }

  Future<void> _cargarMisCuentos() async {
    setState(() {
      _cargandoCuentos = true;
      _errorCuentos = null;
    });

    try {
      final cuentos = await widget.cuentoRepository.listarCuentosPorEstudiante(
        widget.perfil.id,
      );
      if (mounted) {
        setState(() {
          _misCuentos = cuentos;
          _cargandoCuentos = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorCuentos = 'No se pudieron cargar tus aventuras.';
          _cargandoCuentos = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F0),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 24),
          child: Column(
            children: [
              // ENCABEZADO CON SALUDO Y BOTÓN SALIR
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFE0B2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.face,
                            color: Color(0xFFF39C12),
                            size: 32,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '¡Hola, ${widget.perfil.nombre}! 🌟',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF4E342E),
                                ),
                              ),
                              if (widget.perfil.codigoAcceso != null)
                                Container(
                                  margin: const EdgeInsets.only(top: 4),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFECB3),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'Código: ${widget.perfil.codigoAcceso}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF795548),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: widget.onLogout,
                    icon: const Icon(Icons.logout, size: 18),
                    label: const Text('Cerrar sesión'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFC0392B),
                      side: const BorderSide(color: Color(0xFFE6B0AA)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // SELECTOR: NUEVA AVENTURA / MIS AVENTURAS
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFFFECB3),
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _TabItem(
                      titulo: '🚀 Nueva aventura',
                      activo: _tabSeleccionado == 0,
                      onTap: () => setState(() => _tabSeleccionado = 0),
                    ),
                    const SizedBox(width: 6),
                    _TabItem(
                      titulo: '📚 Mis aventuras',
                      activo: _tabSeleccionado == 1,
                      onTap: () {
                        setState(() => _tabSeleccionado = 1);
                        _cargarMisCuentos();
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // CONTENIDO DE LA PESTAÑA
              Expanded(
                child: _tabSeleccionado == 0
                    ? _buildNuevaAventura()
                    : _buildMisAventuras(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================
  // PESTAÑA: NUEVA AVENTURA (REUTILIZA EXACTAMENTE EL FLUJO)
  // =========================================================
  Widget _buildNuevaAventura() {
    return Column(
      children: [
        const Text(
          'Elige cómo quieres comenzar tu aventura mágica',
          style: TextStyle(fontSize: 18, color: Color(0xFF6D4C41)),
        ),
        const SizedBox(height: 32),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _StudentOptionCard(
                icono: Icons.brush,
                titulo: 'Dibujar',
                descripcion: 'Crea un dibujo y conviértelo en el inicio de una historia mágica.',
                onTap: widget.onDibujar,
              ),
              const SizedBox(width: 32),
              _StudentOptionCard(
                icono: Icons.picture_as_pdf,
                titulo: 'Usar un PDF',
                descripcion: 'Selecciona una lectura y transfórmala en una aventura interactiva.',
                onTap: widget.onUsarPdf,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // =========================================================
  // PESTAÑA: MIS AVENTURAS
  // =========================================================
  Widget _buildMisAventuras() {
    if (_cargandoCuentos) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFF39C12)),
      );
    }

    if (_errorCuentos != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Color(0xFFE74C3C)),
            const SizedBox(height: 12),
            Text(
              _errorCuentos!,
              style: const TextStyle(fontSize: 16, color: Color(0xFF7F8C8D)),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _cargarMisCuentos,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    final cuentos = _misCuentos ?? [];

    if (cuentos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFFFE0B2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.auto_stories,
                size: 56,
                color: Color(0xFFF39C12),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Aún no tienes aventuras guardadas',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF4E342E),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '¡Comienza creando una aventura dibujando o subiendo un PDF!',
              style: TextStyle(fontSize: 15, color: Color(0xFF6D4C41)),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => setState(() => _tabSeleccionado = 0),
              icon: const Icon(Icons.add),
              label: const Text('Crear mi primera aventura'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF39C12),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: cuentos.length,
      itemBuilder: (context, index) {
        final cuento = cuentos[index];
        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 8,
            ),
            leading: CircleAvatar(
              backgroundColor: const Color(0xFFFFE0B2),
              child: Icon(
                cuento.origen == CuentoOrigen.pdf
                    ? Icons.picture_as_pdf
                    : Icons.brush,
                color: const Color(0xFFF39C12),
              ),
            ),
            title: Text(
              cuento.titulo,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 17,
                color: Color(0xFF4E342E),
              ),
            ),
            subtitle: Text(
              'Protagonista: ${cuento.personajePrincipal} • Origen: ${cuento.origenDatabase.toUpperCase()}',
              style: const TextStyle(color: Color(0xFF6D4C41)),
            ),
            trailing: const Icon(Icons.chevron_right, color: Color(0xFFF39C12)),
            onTap: () {
              if (widget.onAbrirCuento != null) {
                widget.onAbrirCuento!(cuento);
              }
            },
          ),
        );
      },
    );
  }
}

class _TabItem extends StatelessWidget {
  final String titulo;
  final bool activo;
  final VoidCallback onTap;

  const _TabItem({
    required this.titulo,
    required this.activo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: activo ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: activo
              ? [
                  BoxShadow(
                    color: Colors.black.withAlpha(15),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          titulo,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: activo ? const Color(0xFFE67E22) : const Color(0xFF795548),
          ),
        ),
      ),
    );
  }
}

class _StudentOptionCard extends StatefulWidget {
  final IconData icono;
  final String titulo;
  final String descripcion;
  final VoidCallback onTap;

  const _StudentOptionCard({
    required this.icono,
    required this.titulo,
    required this.descripcion,
    required this.onTap,
  });

  @override
  State<_StudentOptionCard> createState() => _StudentOptionCardState();
}

class _StudentOptionCardState extends State<_StudentOptionCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 330,
        height: 290,
        transform: _hover
            ? Matrix4.translationValues(0, -8, 0)
            : Matrix4.identity(),
        child: Material(
          color: Colors.white,
          elevation: _hover ? 10 : 3,
          borderRadius: BorderRadius.circular(28),
          child: InkWell(
            borderRadius: BorderRadius.circular(28),
            onTap: widget.onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFE0B2),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Icon(
                      widget.icono,
                      size: 44,
                      color: const Color(0xFFF39C12),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    widget.titulo,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF4E342E),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.descripcion,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.35,
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
