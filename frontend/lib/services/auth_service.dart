import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';

/// Resultado estructurado de las operaciones de autenticación
class AuthResult {
  final bool isSuccess;
  final String? errorMessage;
  final UserModel? userModel;
  final User? firebaseUser;

  AuthResult({
    required this.isSuccess,
    this.errorMessage,
    this.userModel,
    this.firebaseUser,
  });

  factory AuthResult.success({UserModel? userModel, User? firebaseUser}) {
    return AuthResult(
      isSuccess: true,
      userModel: userModel,
      firebaseUser: firebaseUser,
    );
  }

  factory AuthResult.error(String message) {
    return AuthResult(
      isSuccess: false,
      errorMessage: message,
    );
  }
}

/// Servicio centralizado de Autenticación 100% Nativo en la Nube con Google Firebase
class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Correo del Administrador principal del sistema institucional
  static const String adminEmail = 'vargasdeiby54@gmail.com';
  static const String udecDomain = '@ucundinamarca.edu.co';

  /// Usuario actualmente autenticado en Firebase Auth
  User? get currentFirebaseUser => _auth.currentUser;

  /// Stream reactivo de cambios en el estado de autenticación
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Validador de dominio institucional UDEC con excepción para el Administrador
  bool isValidEmail(String email) {
    final clean = email.trim().toLowerCase();
    return clean == adminEmail || clean.endsWith(udecDomain);
  }

  /// Registro de nuevo usuario en Firebase Auth y Firestore
  Future<AuthResult> register({
    required String email,
    required String password,
    required String nombreCompleto,
    String? telefono,
    String? sedeId,
    String? programaId,
  }) async {
    final cleanEmail = email.trim().toLowerCase();

    // 1. Validación de correo institucional
    if (!isValidEmail(cleanEmail)) {
      return AuthResult.error(
        'Debes utilizar tu correo institucional de la Universidad de Cundinamarca ($udecDomain).',
      );
    }

    // 2. Validación de contraseña
    if (password.length < 6) {
      return AuthResult.error(
        'La contraseña debe tener un mínimo de 6 caracteres.',
      );
    }

    try {
      // 3. Creación en Firebase Authentication
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: cleanEmail,
        password: password,
      );

      final firebaseUser = userCredential.user;
      if (firebaseUser == null) {
        return AuthResult.error('No se pudo inicializar la cuenta en Firebase.');
      }

      await firebaseUser.updateDisplayName(nombreCompleto.trim());

      // 4. Determinación de Rol
      final rol = (cleanEmail == adminEmail) ? 'ADMINISTRADOR' : 'ESTUDIANTE';

      // 5. Creación del documento en Cloud Firestore (colección: usuarios)
      final userModel = UserModel(
        id: firebaseUser.uid,
        firebaseUid: firebaseUser.uid,
        email: cleanEmail,
        nombreCompleto: nombreCompleto.trim(),
        telefono: telefono?.trim(),
        sedePrincipalId: sedeId,
        programaId: programaId,
        rol: rol,
        estado: 'ACTIVO',
        reputacionPromedio: 5.0,
        totalCalificaciones: 0,
      );

      await _firestore
          .collection('usuarios')
          .doc(firebaseUser.uid)
          .set(userModel.toJson());

      return AuthResult.success(
        userModel: userModel,
        firebaseUser: firebaseUser,
      );
    } on FirebaseAuthException catch (e) {
      return AuthResult.error(_parseFirebaseAuthError(e));
    } catch (e) {
      return AuthResult.error('Error inesperado al registrar usuario: $e');
    }
  }

  /// Inicio de sesión directo contra Firebase Authentication y sincronización con Firestore
  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    final cleanEmail = email.trim().toLowerCase();

    // 1. Validación de regla institucional
    if (!isValidEmail(cleanEmail)) {
      return AuthResult.error(
        'Ingreso restringido a correos institucionales ($udecDomain).',
      );
    }

    try {
      // 2. Autenticación en Firebase Auth
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: cleanEmail,
        password: password,
      );

      final firebaseUser = userCredential.user;
      if (firebaseUser == null) {
        return AuthResult.error('Credenciales no válidas.');
      }

      // 3. Cargar perfil desde Cloud Firestore
      final doc = await _firestore.collection('usuarios').doc(firebaseUser.uid).get();

      UserModel userModel;
      if (doc.exists && doc.data() != null) {
        userModel = UserModel.fromJson(doc.data()!);
      } else {
        // Fallback resiliente: creación si el documento no existía
        final rol = (cleanEmail == adminEmail) ? 'ADMINISTRADOR' : 'ESTUDIANTE';
        userModel = UserModel(
          id: firebaseUser.uid,
          firebaseUid: firebaseUser.uid,
          email: cleanEmail,
          nombreCompleto: firebaseUser.displayName ?? cleanEmail.split('@')[0],
          rol: rol,
          estado: 'ACTIVO',
          reputacionPromedio: 5.0,
          totalCalificaciones: 0,
        );
        await _firestore
            .collection('usuarios')
            .doc(firebaseUser.uid)
            .set(userModel.toJson());
      }

      return AuthResult.success(
        userModel: userModel,
        firebaseUser: firebaseUser,
      );
    } on FirebaseAuthException catch (e) {
      return AuthResult.error(_parseFirebaseAuthError(e));
    } catch (e) {
      return AuthResult.error('Error al iniciar sesión: $e');
    }
  }

  /// Obtiene los datos del usuario actual desde Firestore
  Future<UserModel?> getUserProfile(String uid) async {
    try {
      final doc = await _firestore.collection('usuarios').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        return UserModel.fromJson(doc.data()!);
      }
    } catch (_) {}
    return null;
  }

  /// Cierre de sesión en Firebase
  Future<void> logout() async {
    await _auth.signOut();
  }

  /// Conversión de códigos de excepción de Firebase a español comprensible
  static String _parseFirebaseAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No existe ningún usuario registrado con este correo institucional.';
      case 'wrong-password':
        return 'La contraseña ingresada es incorrecta.';
      case 'invalid-credential':
        return 'Credenciales inválidas. Revisa tu correo y contraseña.';
      case 'email-already-in-use':
        return 'Este correo institucional ya tiene una cuenta activa en Unibooks.';
      case 'weak-password':
        return 'La contraseña es muy débil. Debe tener como mínimo 6 caracteres.';
      case 'user-disabled':
        return 'Esta cuenta ha sido desactivada por el administrador institucional.';
      case 'invalid-email':
        return 'El formato del correo electrónico es inválido.';
      case 'too-many-requests':
        return 'Demasiados intentos fallidos consecutivos. Por favor espera un momento.';
      case 'network-request-failed':
        return 'Error de conexión de red. Verifica tus datos móviles o Wi-Fi.';
      default:
        return e.message ?? 'Ocurrió un error de autenticación con Firebase (${e.code}).';
    }
  }
}
