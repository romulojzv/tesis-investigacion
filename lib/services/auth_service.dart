import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_profile.dart';

class AuthService {
  final SupabaseClient? _clientOverride;

  AuthService({SupabaseClient? client}) : _clientOverride = client;

  SupabaseClient get _client => _clientOverride ?? Supabase.instance.client;

  SupabaseClient? get clientOrNull => _clientOverride;

  User? get currentUser => _client.auth.currentUser;

  Session? get currentSession => _client.auth.currentSession;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  /// Normaliza el código de acceso ingresado por el estudiante.
  static String normalizarCodigoAcceso(String codigo) {
    return codigo.trim().toUpperCase();
  }

  /// Construye internamente el correo técnico sintético determinista.
  static String construirEmailSintetico(String codigoAcceso) {
    final normalizado = normalizarCodigoAcceso(codigoAcceso);
    return '${normalizado.toLowerCase()}@estudiantes.cuentosmagicos.internal';
  }

  /// Inicia sesión para un estudiante usando su Código de Acceso y PIN.
  Future<UserProfile> loginEstudiante({
    required String codigoAcceso,
    required String pin,
  }) async {
    final codigoLimpio = normalizarCodigoAcceso(codigoAcceso);
    final pinLimpio = pin.trim();

    if (codigoLimpio.isEmpty) {
      throw const AuthException('Por favor, ingresa tu código de acceso.');
    }

    if (pinLimpio.length != 6 || int.tryParse(pinLimpio) == null) {
      throw const AuthException('El PIN debe tener exactamente 6 números.');
    }

    final emailSintetico = construirEmailSintetico(codigoLimpio);

    try {
      final res = await _client.auth.signInWithPassword(
        email: emailSintetico,
        password: pinLimpio,
      );

      if (res.user == null) {
        throw const AuthException('No se pudo iniciar sesión.');
      }

      final perfil = await obtenerPerfilActual();

      if (perfil == null) {
        await logout();
        throw const AuthException(
          'No se encontró el perfil de estudiante. Consulta con tu docente.',
        );
      }

      if (perfil.rol != UserRole.estudiante) {
        await logout();
        throw const AuthException(
          'Esta cuenta no corresponde a un perfil de estudiante.',
        );
      }

      return perfil;
    } on AuthException {
      rethrow;
    } catch (e) {
      debugPrint('[AuthService] Error inesperado en loginEstudiante: $e');
      throw AuthException(
        'Código de acceso o PIN incorrectos. Intenta nuevamente.',
      );
    }
  }

  /// Inicia sesión para un docente usando su correo y contraseña.
  Future<UserProfile> loginDocente({
    required String email,
    required String password,
  }) async {
    final correoLimpio = email.trim();

    if (correoLimpio.isEmpty) {
      throw const AuthException('Por favor, ingresa tu correo institucional.');
    }

    if (password.isEmpty) {
      throw const AuthException('Por favor, ingresa tu contraseña.');
    }

    try {
      final res = await _client.auth.signInWithPassword(
        email: correoLimpio,
        password: password,
      );

      if (res.user == null) {
        throw const AuthException('Credenciales inválidas.');
      }

      final perfil = await obtenerPerfilActual();

      if (perfil == null) {
        await logout();
        throw const AuthException(
          'No se encontró el perfil docente para esta cuenta.',
        );
      }

      if (perfil.rol != UserRole.docente) {
        await logout();
        throw const AuthException(
          'Esta cuenta no cuenta con rol docente autorizado.',
        );
      }

      return perfil;
    } on AuthException {
      rethrow;
    } catch (e) {
      debugPrint('[AuthService] Error inesperado en loginDocente: $e');
      throw AuthException(
        'Correo o contraseña incorrectos. Verifica tus credenciales.',
      );
    }
  }

  /// Carga el perfil del usuario actualmente autenticado desde public.profiles.
  Future<UserProfile?> obtenerPerfilActual() async {
    final user = currentUser;
    if (user == null) {
      return null;
    }

    try {
      final data = await _client
          .from('profiles')
          .select('id, nombre, rol, codigo_acceso, created_at')
          .eq('id', user.id)
          .maybeSingle();

      if (data == null) {
        return null;
      }

      return UserProfile.fromMap(data);
    } catch (e) {
      debugPrint('[AuthService] Error obteniendo perfil actual: $e');
      return null;
    }
  }

  /// Cierra la sesión activa en Supabase Auth.
  Future<void> logout() async {
    try {
      await _client.auth.signOut();
    } catch (e) {
      debugPrint('[AuthService] Error al cerrar sesión: $e');
    }
  }
}
