import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../core/navigation/app_navigator.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  StreamSubscription<DocumentSnapshot>? _userDocSub;

  UserModel? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _currentUser != null;

  AuthProvider() {
    _initSession();
  }

  void _startUserLiveWatcher(String uid) {
    _userDocSub?.cancel();
    _userDocSub = _firestore.collection('usuarios').doc(uid).snapshots().listen((snap) async {
      if (snap.exists && snap.data() != null) {
        final data = Map<String, dynamic>.from(snap.data() as Map);
        final bool isSuspended = data['estado'] == 'SUSPENDIDO' ||
            data['status'] == 'suspended' ||
            data['is_suspended'] == true ||
            data['activo'] == false;

        if (isSuspended) {
          debugPrint('[AuthProvider] Alerta de seguridad: Usuario suspendido por un Administrador.');
          _errorMessage = 'Tu cuenta ha sido suspendida por un administrador';
          _userDocSub?.cancel();
          _userDocSub = null;
          _currentUser = null;
          await _authService.logout();
          notifyListeners();
          AppNavigator.navigateToLoginWithSuspensionNotice('Tu cuenta ha sido suspendida por un administrador');
        } else {
          data['id'] = snap.id;
          _currentUser = UserModel.fromJson(data);
          notifyListeners();
        }
      }
    });
  }

  Future<void> _initSession() async {
    _isLoading = true;
    notifyListeners();

    try {
      final user = _auth.currentUser;
      if (user != null) {
        final profile = await _authService.getUserProfile(user.uid);
        if (profile != null && (profile.estado == 'SUSPENDIDO' || !profile.isActivo)) {
          _errorMessage = 'Tu cuenta ha sido suspendida por un administrador';
          await _authService.logout();
          _currentUser = null;
        } else {
          _currentUser = profile;
          if (_currentUser != null) {
            _startUserLiveWatcher(user.uid);
          }
        }
      } else {
        _currentUser = null;
      }
    } catch (e) {
      debugPrint('[AuthProvider] Error en _initSession: $e');
      _currentUser = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }

    // Escuchar cambios de sesión en Firebase en tiempo real
    _authService.authStateChanges.listen((user) async {
      if (user == null) {
        _userDocSub?.cancel();
        _userDocSub = null;
        _currentUser = null;
        notifyListeners();
      }
    });
  }

  Future<bool> loginWithCredentials({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await _authService.login(email: email, password: password);
    _isLoading = false;

    if (result.isSuccess) {
      _currentUser = result.userModel;
      if (_currentUser != null) {
        _startUserLiveWatcher(_currentUser!.firebaseUid);
      }
      notifyListeners();
      return true;
    } else {
      _errorMessage = result.errorMessage;
      notifyListeners();
      return false;
    }
  }

  Future<bool> register({
    required String email,
    required String password,
    required String nombreCompleto,
    String? sedeId,
    String? programaId,
    String? telefono,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await _authService.register(
      email: email,
      password: password,
      nombreCompleto: nombreCompleto,
      sedeId: sedeId,
      programaId: programaId,
      telefono: telefono,
    );

    _isLoading = false;

    if (result.isSuccess) {
      _currentUser = result.userModel;
      if (_currentUser != null) {
        _startUserLiveWatcher(_currentUser!.firebaseUid);
      }
      notifyListeners();
      return true;
    } else {
      _errorMessage = result.errorMessage;
      notifyListeners();
      return false;
    }
  }

  Future<void> loadUserProfile() async {
    final user = _auth.currentUser;
    if (user != null) {
      _currentUser = await _authService.getUserProfile(user.uid);
      notifyListeners();
    }
  }

  Future<bool> updateAvatar(String newAvatarUrl) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _firestore.collection('usuarios').doc(user.uid).update({
        'avatar_url': newAvatarUrl,
      });
      _currentUser = await _authService.getUserProfile(user.uid);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    return false;
  }

  Future<void> logout() async {
    _userDocSub?.cancel();
    _userDocSub = null;
    await _authService.logout();
    _currentUser = null;
    notifyListeners();
  }
}
