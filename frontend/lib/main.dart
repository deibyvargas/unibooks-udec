import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/catalog_provider.dart';
import 'providers/trade_provider.dart';
import 'providers/chat_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/main_navigation_screen.dart';
import 'screens/admin/admin_dashboard_screen.dart';

import 'core/navigation/app_navigator.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const UnibooksApp());
}

class UnibooksApp extends StatelessWidget {
  const UnibooksApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => CatalogProvider()),
        ChangeNotifierProvider(create: (_) => TradeProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
      ],
      child: MaterialApp(
        title: 'Unibooks - Universidad de Cundinamarca',
        debugShowCheckedModeBanner: false,
        navigatorKey: AppNavigator.navigatorKey,
        theme: AppTheme.lightTheme,
        initialRoute: '/',
        routes: {
          '/': (context) => const AppRootRouter(),
          '/register': (context) => const RegisterScreen(),
          '/login': (context) => const LoginScreen(),
          '/home': (context) => const ProtectedRoute(child: MainNavigationScreen()),
          '/catalog': (context) => const ProtectedRoute(child: MainNavigationScreen()),
          '/dashboard': (context) => const ProtectedRoute(child: AdminDashboardScreen()),
        },
        onGenerateRoute: (settings) {
          return MaterialPageRoute(builder: (_) => const AppRootRouter());
        },
      ),
    );
  }
}

/// Enrutador Principal con Redirección Obligatoria a Registro
class AppRootRouter extends StatelessWidget {
  const AppRootRouter({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (auth.isLoading && auth.currentUser == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Regla Obligatoria: Si no hay sesión activa, la vista inicial es RegisterScreen (o Login si fue suspendido)
    if (!auth.isAuthenticated) {
      if (auth.errorMessage != null && auth.errorMessage!.contains('suspendida')) {
        return const LoginScreen();
      }
      return const RegisterScreen();
    }

    return const MainNavigationScreen();
  }
}

/// Protección de Rutas: Bloquea accesos directos si no hay sesión autenticada
class ProtectedRoute extends StatelessWidget {
  final Widget child;
  const ProtectedRoute({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (auth.isLoading && auth.currentUser == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (!auth.isAuthenticated) {
      if (auth.errorMessage != null && auth.errorMessage!.contains('suspendida')) {
        return const LoginScreen();
      }
      return const RegisterScreen();
    }

    return child;
  }
}
