import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_profile.dart';
import '../services/auth_service.dart';
import 'login_view.dart';
import 'teacher_home_view.dart';

class AuthGate extends StatefulWidget {
  final AuthService authService;
  final Widget Function(BuildContext context, UserProfile perfil)
  studentBuilder;

  const AuthGate({
    super.key,
    required this.authService,
    required this.studentBuilder,
  });

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  UserProfile? _perfil;
  bool _cargando = true;
  String? _errorMensaje;
  StreamSubscription<AuthState>? _subAuth;

  @override
  void initState() {
    super.initState();
    _iniciarObservadorAuth();
  }

  void _iniciarObservadorAuth() {
    // 1. Escuchar cambios de estado en Supabase Auth
    _subAuth = widget.authService.authStateChanges.listen((data) {
      final session = data.session;
      final event = data.event;

      if (event == AuthChangeEvent.signedOut || session == null) {
        if (mounted) {
          setState(() {
            _perfil = null;
            _cargando = false;
            _errorMensaje = null;
          });
        }
      } else if (event == AuthChangeEvent.signedIn ||
          event == AuthChangeEvent.tokenRefreshed ||
          event == AuthChangeEvent.initialSession) {
        _cargarPerfilUsuario();
      }
    });

    // 2. Comprobar sesión actual inicial
    if (widget.authService.currentSession == null) {
      _perfil = null;
      _cargando = false;
    } else {
      _cargarPerfilUsuario();
    }
  }

  Future<void> _cargarPerfilUsuario() async {
    if (!mounted) return;

    // Regla estricta: si no hay sesión activa, invalidar perfil y mostrar login
    if (widget.authService.currentSession == null) {
      if (mounted) {
        setState(() {
          _perfil = null;
          _cargando = false;
        });
      }
      return;
    }

    setState(() {
      _cargando = true;
      _errorMensaje = null;
    });

    try {
      final perfil = await widget.authService.obtenerPerfilActual();

      if (!mounted) return;

      // Verificar nuevamente la sesión tras la llamada asíncrona
      if (widget.authService.currentSession == null || perfil == null) {
        await widget.authService.logout();
        if (!mounted) return;
        setState(() {
          _perfil = null;
          _cargando = false;
          if (perfil == null) {
            _errorMensaje =
                'La sesión no cuenta con un perfil educativo registrado.';
          }
        });
        return;
      }

      setState(() {
        _perfil = perfil;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      await widget.authService.logout();
      if (!mounted) return;
      setState(() {
        _perfil = null;
        _cargando = false;
        _errorMensaje = 'Error cargando información de usuario: $e';
      });
    }
  }

  @override
  void dispose() {
    _subAuth?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return _buildCargando();
    }

    // FUENTE DE VERDAD ESTRICTA:
    // 7. StudentHomeView NO puede construirse si currentSession == null.
    // 8. TeacherHomeView NO puede construirse si currentSession == null.
    // Si no hay sesión activa, el perfil anterior NO puede reutilizarse.
    final session = widget.authService.currentSession;
    if (session == null) {
      _perfil = null;
      return _buildLoginView();
    }

    final perfil = _perfil;
    if (perfil == null) {
      return _buildCargando();
    }

    // CON SESIÓN DOCENTE -> TeacherHomeView
    if (perfil.rol == UserRole.docente) {
      return TeacherHomeView(
        perfil: perfil,
        client: widget.authService.clientOrNull,
        onLogout: () async {
          await widget.authService.logout();
        },
      );
    }

    // CON SESIÓN ESTUDIANTE -> Flujo de estudiante
    return widget.studentBuilder(context, perfil);
  }

  Widget _buildCargando() {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F0),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFFFFE0B2),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Icon(
                Icons.auto_stories,
                size: 40,
                color: Color(0xFFF39C12),
              ),
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(color: Color(0xFFF39C12)),
            const SizedBox(height: 16),
            const Text(
              'Cargando tu experiencia mágica...',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6D4C41),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginView() {
    return Stack(
      children: [
        LoginView(
          authService: widget.authService,
          onLoginExitoso: (nuevoPerfil) {
            if (mounted && widget.authService.currentSession != null) {
              setState(() {
                _perfil = nuevoPerfil;
                _cargando = false;
                _errorMensaje = null;
              });
            }
          },
        ),
        if (_errorMensaje != null)
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFC62828),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _errorMensaje!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
