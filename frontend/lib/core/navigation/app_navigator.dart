import 'package:flutter/material.dart';

class AppNavigator {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  static BuildContext? get currentContext => navigatorKey.currentContext;

  /// Cierra la sesión activa y redirige obligatoriamente al login cuando la cuenta es suspendida
  static void navigateToLoginWithSuspensionNotice(String message) {
    navigatorKey.currentState?.pushNamedAndRemoveUntil('/login', (route) => false);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = navigatorKey.currentContext;
      if (ctx != null) {
        showDialog(
          context: ctx,
          barrierDismissible: false,
          builder: (dialogCtx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: const [
                Icon(Icons.block_rounded, color: Colors.red, size: 28),
                SizedBox(width: 10),
                Text('Acceso Restringido', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
              ],
            ),
            content: Text(
              message,
              style: const TextStyle(fontSize: 14),
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('Entendido'),
              ),
            ],
          ),
        );
      }
    });
  }
}
