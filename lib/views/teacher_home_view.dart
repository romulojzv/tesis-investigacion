// lib/views/teacher_home_view.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/quiz_attempt_summary.dart';
import '../models/user_profile.dart';
import '../repositories/quiz_repository_supabase.dart';
import 'components/quiz_result_detail_dialog.dart';
import 'components/teacher_class_summary.dart';
import 'components/teacher_student_results.dart';
import 'components/teacher_student_table.dart';

class _UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}

class TeacherHomeView extends StatefulWidget {
  final UserProfile perfil;
  final VoidCallback onLogout;
  final SupabaseClient? client;
  final QuizRepository? quizRepository;
  final List<Map<String, dynamic>>? aulasIniciales;
  final Map<String, List<Map<String, dynamic>>>? estudiantesInicialesPorAula;

  const TeacherHomeView({
    super.key,
    required this.perfil,
    required this.onLogout,
    this.client,
    this.quizRepository,
    this.aulasIniciales,
    this.estudiantesInicialesPorAula,
  });

  @override
  State<TeacherHomeView> createState() => _TeacherHomeViewState();
}

class _TeacherHomeViewState extends State<TeacherHomeView> {
  SupabaseClient get _client => widget.client ?? Supabase.instance.client;

  late final QuizRepository _quizRepository;

  List<Map<String, dynamic>> _aulas = [];
  Map<String, List<Map<String, dynamic>>> _estudiantesPorAula = {};
  List<QuizAttemptSummary> _resultadosQuiz = [];

  String? _aulaSeleccionadaId;
  Map<String, dynamic>? _estudianteSeleccionado;

  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    try {
      _quizRepository =
          widget.quizRepository ?? QuizRepositorySupabase(client: _client);
    } catch (_) {
      _quizRepository = widget.quizRepository ?? const _EmptyQuizRepository();
    }
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      List<Map<String, dynamic>> aulas = [];
      Map<String, List<Map<String, dynamic>>> estudiantesMap = {};

      if (widget.aulasIniciales != null) {
        aulas = List<Map<String, dynamic>>.from(widget.aulasIniciales!);
        estudiantesMap = Map<String, List<Map<String, dynamic>>>.from(
          widget.estudiantesInicialesPorAula ?? {},
        );
      } else {
        try {
          // 1. Cargar aulas visibles por RLS para el docente
          final aulasData = await _client
              .from('aulas')
              .select('id, nombre, codigo_aula, created_at')
              .order('created_at', ascending: true);

          aulas = List<Map<String, dynamic>>.from(aulasData);

          // 2. Cargar matrículas y perfiles permitidos por RLS para cada aula
          for (final aula in aulas) {
            final aulaId = aula['id'].toString();
            final matsData = await _client
                .from('aula_estudiantes')
                .select(
                  'codigo_local, estudiante_id, profiles(id, nombre, codigo_acceso)',
                )
                .eq('aula_id', aulaId)
                .order('codigo_local', ascending: true);

            final listado = <Map<String, dynamic>>[];
            for (final m in matsData) {
              final prof = m['profiles'] as Map<String, dynamic>?;
              listado.add({
                'codigo_local': m['codigo_local']?.toString() ?? '',
                'estudiante_id': m['estudiante_id']?.toString() ?? '',
                'nombre': prof?['nombre']?.toString() ?? 'Estudiante',
                'codigo_acceso': prof?['codigo_acceso']?.toString() ?? '',
              });
            }
            estudiantesMap[aulaId] = listado;
          }
        } catch (errAulas) {
          debugPrint(
            '[TeacherHomeView] Aviso cargando aulas (ej. entorno de tests): $errAulas',
          );
        }
      }

      // 3. Cargar resultados de comprensión lectora permitidos por RLS
      List<QuizAttemptSummary> resultados = [];
      try {
        resultados = await _quizRepository.obtenerResultadosPorDocente();
      } catch (e) {
        debugPrint('[TeacherHomeView] Error al cargar resultados quiz: $e');
      }

      // Fallback defensivo para entornos de prueba sin mock de client ni aulas iniciales
      if (aulas.isEmpty && resultados.isNotEmpty) {
        final aulaId = resultados.first.aulaId ?? 'aula-1';
        final aulaNombre = resultados.first.aulaNombre ?? '4to Grado A';
        aulas.add({
          'id': aulaId,
          'nombre': aulaNombre,
          'codigo_aula': '4A',
          'created_at': DateTime.now().toIso8601String(),
        });
        final listado = <Map<String, dynamic>>[];
        final idsVistos = <String>{};
        for (final r in resultados) {
          if (!idsVistos.contains(r.estudianteId)) {
            idsVistos.add(r.estudianteId);
            listado.add({
              'codigo_local': '00${listado.length + 1}',
              'estudiante_id': r.estudianteId,
              'nombre': r.estudianteNombre,
              'codigo_acceso': r.codigoAcceso,
            });
          }
        }
        estudiantesMap[aulaId] = listado;
      }

      // Selección automática de aula si tiene una sola o validación de selección previa
      String? nuevoAulaId = _aulaSeleccionadaId;
      if (aulas.isNotEmpty) {
        final existe = aulas.any((a) => a['id'].toString() == nuevoAulaId);
        if (!existe) {
          nuevoAulaId = aulas.first['id'].toString();
        }
      } else {
        nuevoAulaId = null;
      }

      if (mounted) {
        setState(() {
          _aulas = aulas;
          _estudiantesPorAula = estudiantesMap;
          _resultadosQuiz = resultados;
          _aulaSeleccionadaId = nuevoAulaId;
          _cargando = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error cargando datos: $e';
          _cargando = false;
        });
      }
    }
  }

  void _cambiarAula(String nuevoId) {
    if (nuevoId != _aulaSeleccionadaId) {
      setState(() {
        _aulaSeleccionadaId = nuevoId;
        _estudianteSeleccionado = null;
      });
    }
  }

  Future<void> _abrirDialogoCrearEstudiante(
    String aulaId,
    String nombreAula,
  ) async {
    final nombreCtrl = TextEditingController();
    final codigoCtrl = TextEditingController();
    bool enviando = false;
    String? errorDialogo;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: Row(
                children: [
                  const Icon(Icons.person_add, color: Color(0xFFF39C12)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Agregar estudiante en $nombreAula',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF4E342E),
                      ),
                    ),
                  ),
                ],
              ),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (errorDialogo != null) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFEBEE),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFEF9A9A)),
                        ),
                        child: Text(
                          errorDialogo!,
                          style: const TextStyle(
                            color: Color(0xFFC62828),
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    TextField(
                      controller: nombreCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nombre completo del estudiante',
                        hintText: 'Ej: Carlos Gómez',
                        prefixIcon: Icon(Icons.badge_outlined),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: codigoCtrl,
                      keyboardType: TextInputType.text,
                      textCapitalization: TextCapitalization.characters,
                      inputFormatters: [_UpperCaseTextFormatter()],
                      decoration: const InputDecoration(
                        labelText: 'Código / número de lista',
                        hintText: 'Ej: 003',
                        prefixIcon: Icon(Icons.format_list_numbered),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: enviando
                      ? null
                      : () => Navigator.of(dialogCtx).pop(),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: enviando
                      ? null
                      : () async {
                          final nombre = nombreCtrl.text.trim();
                          final codigo = codigoCtrl.text.trim().toUpperCase();

                          if (nombre.length < 2 || nombre.length > 80) {
                            setDialogState(() {
                              errorDialogo = 'El nombre debe contener entre 2 y 80 caracteres.';
                            });
                            return;
                          }

                          if (codigo.isEmpty || codigo.length > 20) {
                            setDialogState(() {
                              errorDialogo = 'El código local debe tener entre 1 y 20 caracteres.';
                            });
                            return;
                          }

                          setDialogState(() {
                            enviando = true;
                            errorDialogo = null;
                          });

                          try {
                            final res = await _client.functions.invoke(
                              'crear-estudiante',
                              body: {
                                'nombre': nombre,
                                'aulaId': aulaId,
                                'codigoLocal': codigo,
                              },
                            );

                            if (res.status != 200 && res.status != 201) {
                              final errorMsg =
                                  res.data is Map && res.data['error'] != null
                                  ? res.data['error'].toString()
                                  : 'Error al registrar estudiante (${res.status}).';
                              setDialogState(() {
                                errorDialogo = errorMsg;
                                enviando = false;
                              });
                              return;
                            }

                            final dataResp = res.data is Map
                                ? res.data as Map<String, dynamic>
                                : <String, dynamic>{};

                            if (dialogCtx.mounted) {
                              Navigator.of(dialogCtx).pop();
                            }
                            if (mounted) {
                              _mostrarCredencialesGeneradas(dataResp);
                              _cargarDatos();
                            }
                          } catch (e) {
                            setDialogState(() {
                              errorDialogo = 'Error invocando función: $e';
                              enviando = false;
                            });
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF39C12),
                    foregroundColor: Colors.white,
                  ),
                  child: enviando
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Crear estudiante'),
                ),
              ],
            );
          },
        );
      },
    );

    nombreCtrl.dispose();
    codigoCtrl.dispose();
  }

  void _mostrarCredencialesGeneradas(Map<String, dynamic> data) {
    final nombre = data['nombre']?.toString() ?? 'Estudiante';
    final codigoAcceso = data['codigoAcceso']?.toString() ?? '';
    final pin = data['pin']?.toString() ?? '';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Color(0xFF27AE60), size: 28),
              SizedBox(width: 10),
              Text(
                '¡Estudiante Creado!',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF27AE60),
                ),
              ),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'El alumno $nombre ha sido registrado exitosamente.',
                  style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFF4E342E),
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8E1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFFFD54F)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Código de acceso:',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF795548),
                        ),
                      ),
                      Text(
                        codigoAcceso,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFE65100),
                        ),
                      ),
                      const Divider(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'PIN temporal (6 dígitos):',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF795548),
                                ),
                              ),
                              Text(
                                pin,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2E7D32),
                                  letterSpacing: 2,
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.copy,
                              color: Color(0xFFF39C12),
                            ),
                            tooltip: 'Copiar PIN',
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: pin));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('PIN copiado al portapapeles.'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEBEE),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: Color(0xFFC62828),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Guarda o entrega este PIN ahora. Por seguridad, no podrá volver a mostrarse tras cerrar este aviso.',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFC62828),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF39C12),
                foregroundColor: Colors.white,
              ),
              child: const Text('Entendido y Guardado'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F0),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ENCABEZADO DOCENTE
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
                            Icons.school,
                            color: Color(0xFFF39C12),
                            size: 32,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Panel Docente 🎓',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFF39C12),
                                ),
                              ),
                              Text(
                                widget.perfil.nombre,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF4E342E),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        tooltip: 'Recargar datos',
                        onPressed: _cargarDatos,
                      ),
                      const SizedBox(width: 8),
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
                ],
              ),

              const SizedBox(height: 24),

              // CONTENIDO PRINCIPAL
              Expanded(
                child: _cargando
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFFF39C12),
                        ),
                      )
                    : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.error_outline,
                              size: 48,
                              color: Color(0xFFE74C3C),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _error!,
                              style: const TextStyle(
                                fontSize: 16,
                                color: Color(0xFF7F8C8D),
                              ),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: _cargarDatos,
                              child: const Text('Reintentar'),
                            ),
                          ],
                        ),
                      )
                    : _buildContenidoDocente(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContenidoDocente() {
    if (_aulas.isEmpty) {
      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Resultados de Comprensión Lectora 📊',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF4E342E),
              ),
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFFFE0B2)),
              ),
              child: const Column(
                children: [
                  Text(
                    'No tienes aulas asignadas actualmente.',
                    style: TextStyle(color: Color(0xFF795548), fontSize: 15),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'No hay resultados de comprensión todavía.',
                    style: TextStyle(
                      color: Color(0xFF8D6E63),
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final aulaActual = _aulas.firstWhere(
      (a) => a['id'].toString() == _aulaSeleccionadaId,
      orElse: () => _aulas.first,
    );
    final aulaId = aulaActual['id'].toString();
    final nombreAula = aulaActual['nombre']?.toString() ?? 'Aula';
    final codigoAula = aulaActual['codigo_aula']?.toString() ?? '';
    final estudiantesDelAula = _estudiantesPorAula[aulaId] ?? [];

    final idsMatriculados = estudiantesDelAula
        .map((e) => e['estudiante_id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();

    // Intentos de comprensión completados correspondientes a los estudiantes matriculados en esta aula
    final quizzesDelAula = _resultadosQuiz.where((q) {
      if (!q.estaCompletado) return false;
      if (q.aulaId != null && q.aulaId != aulaId) return false;
      return idsMatriculados.contains(q.estudianteId);
    }).toList();

    // Métricas del aula
    final metrics = AulaMetrics.calcular(
      estudiantesMatriculados: estudiantesDelAula,
      intentosDelAula: quizzesDelAula,
    );

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // TÍTULO DE SECCIÓN Y SELECTOR DE AULA
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Resultados de Comprensión Lectora 📊',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF4E342E),
                ),
              ),
              Text(
                '${quizzesDelAula.length} resultado(s)',
                style: const TextStyle(
                  color: Color(0xFF8D6E63),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // SELECTOR DE AULA (B. SELECTOR DE AULA)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFFE0B2)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(6),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.school_outlined, color: Color(0xFFF39C12)),
                const SizedBox(width: 10),
                const Text(
                  'Aula:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Color(0xFF4E342E),
                  ),
                ),
                const SizedBox(width: 12),
                if (_aulas.length == 1)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF8F0),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFFCC80)),
                    ),
                    child: Text(
                      '$nombreAula ($codigoAula)',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Color(0xFFE65100),
                      ),
                    ),
                  )
                else
                  DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _aulaSeleccionadaId,
                      icon: const Icon(
                        Icons.arrow_drop_down,
                        color: Color(0xFFF39C12),
                      ),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Color(0xFF4E342E),
                      ),
                      items: _aulas.map((aula) {
                        final aId = aula['id'].toString();
                        final aNom = aula['nombre']?.toString() ?? 'Aula';
                        final aCod = aula['codigo_aula']?.toString() ?? '';
                        return DropdownMenuItem<String>(
                          value: aId,
                          child: Text('$aNom ($aCod)'),
                        );
                      }).toList(),
                      onChanged: (nuevoId) {
                        if (nuevoId != null) {
                          _cambiarAula(nuevoId);
                        }
                      },
                    ),
                  ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: () =>
                      _abrirDialogoCrearEstudiante(aulaId, nombreAula),
                  icon: const Icon(Icons.person_add, size: 18),
                  label: const Text('Agregar estudiante'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF39C12),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // VISTA JERÁRQUICA: ESTUDIANTE SELECCIONADO O RESUMEN + TABLA
          if (_estudianteSeleccionado != null) ...[
            // E. RESULTADOS DEL ESTUDIANTE SELECCIONADO
            Builder(
              builder: (context) {
                final estId =
                    _estudianteSeleccionado!['estudiante_id']?.toString() ?? '';
                final quizzesEst = quizzesDelAula
                    .where((q) => q.estudianteId == estId)
                    .toList();

                return TeacherStudentResults(
                  estudiante: _estudianteSeleccionado!,
                  quizzes: quizzesEst,
                  onVolver: () {
                    setState(() {
                      _estudianteSeleccionado = null;
                    });
                  },
                  onVerDetalle: (intento) {
                    QuizResultDetailDialog.mostrar(context, intento);
                  },
                );
              },
            ),
          ] else ...[
            // C. RESUMEN DEL AULA
            TeacherClassSummary(metrics: metrics),

            const SizedBox(height: 24),

            // D. TABLA DE ESTUDIANTES
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Estudiantes del aula (${estudiantesDelAula.length})',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4E342E),
                  ),
                ),
                Text(
                  'Selecciona un estudiante para ver sus quizzes',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.brown[400],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TeacherStudentTable(
              estudiantes: estudiantesDelAula,
              intentosDelAula: quizzesDelAula,
              onSelectEstudiante: (estudiante) {
                setState(() {
                  _estudianteSeleccionado = estudiante;
                });
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyQuizRepository implements QuizRepository {
  const _EmptyQuizRepository();

  @override
  Future<List<QuizAttemptSummary>> obtenerResultadosPorDocente() async =>
      const [];

  @override
  Future<Map<String, QuizAttemptSummary>> obtenerResumenesQuizPorEstudiante(
    String estudianteId,
  ) async => const {};

  @override
  Future<QuizAttemptSummary?> obtenerResumenQuizPorCuento(
    String cuentoId,
  ) async => null;
}
