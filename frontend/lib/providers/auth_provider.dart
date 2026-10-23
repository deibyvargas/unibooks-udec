import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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

  Future<void> _initSession() async {
    _isLoading = true;
    notifyListeners();

    try {
      final user = _auth.currentUser;
      if (user != null) {
        _currentUser = await _authService.getUserProfile(user.uid);
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
    await _authService.logout();
    _currentUser = null;
    notifyListeners();
  }
}
