import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/user_profile.dart';
import '../services/auth_service.dart';

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

class LoginView extends StatefulWidget {
  final AuthService authService;
  final ValueChanged<UserProfile> onLoginExitoso;

  const LoginView({
    super.key,
    required this.authService,
    required this.onLoginExitoso,
  });

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  UserRole _rolSeleccionado = UserRole.estudiante;

  // Controladores Estudiante
  final _codigoController = TextEditingController();
  final _pinController = TextEditingController();

  // Controladores Docente
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _ocultarPin = true;
  bool _ocultarPassword = true;
  bool _cargando = false;
  String? _mensajeError;

  @override
  void dispose() {
    _codigoController.dispose();
    _pinController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_cargando) return;

    setState(() {
      _cargando = true;
      _mensajeError = null;
    });

    try {
      UserProfile perfil;
      if (_rolSeleccionado == UserRole.estudiante) {
        perfil = await widget.authService.loginEstudiante(
          codigoAcceso: _codigoController.text.trim().toUpperCase(),
          pin: _pinController.text.trim(),
        );
      } else {
        perfil = await widget.authService.loginDocente(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      }

      if (mounted) {
        widget.onLoginExitoso(perfil);
      }
    } catch (e) {
      if (mounted) {
        final errorTexto = e.toString().replaceFirst(
          RegExp(r'^Exception:\s*'),
          '',
        );
        setState(() {
          _mensajeError = errorTexto.replaceFirst('AuthException: ', '');
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _cargando = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F0),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // TÍTULO Y LOGO AMIGABLE
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFE0B2),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Icon(
                      Icons.auto_stories,
                      size: 44,
                      color: Color(0xFFF39C12),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    '✨ Cuentos Mágicos ✨',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFF39C12),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '¡Bienvenido a tu mundo de aventuras y lectura!',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Color(0xFF6D4C41)),
                  ),
                  const SizedBox(height: 32),

                  // SELECTOR DE MODO (ESTUDIANTE / DOCENTE)
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFECB3),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.all(5),
                    child: Row(
                      children: [
                        Expanded(
                          child: _TabButton(
                            titulo: '🎒 Soy estudiante',
                            activo: _rolSeleccionado == UserRole.estudiante,
                            onTap: () {
                              if (_cargando) return;
                              setState(() {
                                _rolSeleccionado = UserRole.estudiante;
                                _mensajeError = null;
                              });
                            },
                          ),
                        ),
                        Expanded(
                          child: _TabButton(
                            titulo: '👨‍🏫 Soy docente',
                            activo: _rolSeleccionado == UserRole.docente,
                            onTap: () {
                              if (_cargando) return;
                              setState(() {
                                _rolSeleccionado = UserRole.docente;
                                _mensajeError = null;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // TARJETA DE FORMULARIO
                  Material(
                    color: Colors.white,
                    elevation: 5,
                    borderRadius: BorderRadius.circular(28),
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_mensajeError != null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFEBEE),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFEF9A9A),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.error_outline,
                                    color: Color(0xFFC62828),
                                    size: 22,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      _mensajeError!,
                                      style: const TextStyle(
                                        color: Color(0xFFC62828),
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),
                          ],

                          if (_rolSeleccionado == UserRole.estudiante)
                            _buildFormularioEstudiante()
                          else
                            _buildFormularioDocente(),

                          const SizedBox(height: 24),

                          // BOTÓN DE ACCIÓN
                          ElevatedButton(
                            onPressed: _cargando ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFF39C12),
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: const Color(0xFFFFCC80),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                              elevation: 3,
                            ),
                            child: _cargando
                                ? const SizedBox(
                                    height: 22,
                                    width: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    _rolSeleccionado == UserRole.estudiante
                                        ? '🚀 ¡Entrar a mi aventura!'
                                        : '📚 Iniciar sesión docente',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ],
                      ),
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

  Widget _buildFormularioEstudiante() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Código de acceso',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: Color(0xFF4E342E),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _codigoController,
          textCapitalization: TextCapitalization.characters,
          textInputAction: TextInputAction.next,
          inputFormatters: [_UpperCaseTextFormatter()],
          decoration: InputDecoration(
            hintText: 'Ej: 4A26-001',
            prefixIcon: const Icon(Icons.badge, color: Color(0xFFF39C12)),
            filled: true,
            fillColor: const Color(0xFFFAFAFA),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFFFCC80)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFFFE0B2)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFF39C12), width: 2),
            ),
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'PIN secreto (6 dígitos)',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: Color(0xFF4E342E),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _pinController,
          obscureText: _ocultarPin,
          keyboardType: TextInputType.number,
          maxLength: 6,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
          decoration: InputDecoration(
            counterText: '',
            hintText: '••••••',
            prefixIcon: const Icon(Icons.lock, color: Color(0xFFF39C12)),
            suffixIcon: IconButton(
              icon: Icon(
                _ocultarPin ? Icons.visibility_off : Icons.visibility,
                color: const Color(0xFF8D6E63),
              ),
              onPressed: () => setState(() => _ocultarPin = !_ocultarPin),
            ),
            filled: true,
            fillColor: const Color(0xFFFAFAFA),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFFFCC80)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFFFE0B2)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFF39C12), width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFormularioDocente() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Correo electrónico institucional',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: Color(0xFF4E342E),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            hintText: 'docente@colegio.edu.pe',
            prefixIcon: const Icon(
              Icons.email_outlined,
              color: Color(0xFFF39C12),
            ),
            filled: true,
            fillColor: const Color(0xFFFAFAFA),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFFFCC80)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFFFE0B2)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFF39C12), width: 2),
            ),
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'Contraseña',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: Color(0xFF4E342E),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _passwordController,
          obscureText: _ocultarPassword,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
          decoration: InputDecoration(
            hintText: 'Tu contraseña segura',
            prefixIcon: const Icon(
              Icons.lock_outline,
              color: Color(0xFFF39C12),
            ),
            suffixIcon: IconButton(
              icon: Icon(
                _ocultarPassword ? Icons.visibility_off : Icons.visibility,
                color: const Color(0xFF8D6E63),
              ),
              onPressed: () =>
                  setState(() => _ocultarPassword = !_ocultarPassword),
            ),
            filled: true,
            fillColor: const Color(0xFFFAFAFA),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFFFCC80)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFFFE0B2)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFF39C12), width: 2),
            ),
          ),
        ),
      ],
    );
  }
}

class _TabButton extends StatelessWidget {
  final String titulo;
  final bool activo;
  final VoidCallback onTap;

  const _TabButton({
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
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: activo ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          boxShadow: activo
              ? [
                  BoxShadow(
                    color: Colors.black.withAlpha(20),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          titulo,
          textAlign: TextAlign.center,
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
