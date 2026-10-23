// File generated for Unibooks - Universidad de Cundinamarca
// Configuración oficial de Firebase vinculada al proyecto unibooks-udec
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        return android;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyD9c-IrZiGf6oHkRJR4aIyRLAdFtp2eAFo',
    appId: '1:545500598323:web:7b8781c2d8a2c9aa01d346',
    messagingSenderId: '545500598323',
    projectId: 'unibooks-udec',
    authDomain: 'unibooks-udec.firebaseapp.com',
    storageBucket: 'unibooks-udec.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyD9c-IrZiGf6oHkRJR4aIyRLAdFtp2eAFo',
    appId: '1:545500598323:android:7b8781c2d8a2c9aa01d346',
    messagingSenderId: '545500598323',
    projectId: 'unibooks-udec',
    storageBucket: 'unibooks-udec.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyD9c-IrZiGf6oHkRJR4aIyRLAdFtp2eAFo',
    appId: '1:545500598323:ios:7b8781c2d8a2c9aa01d346',
    messagingSenderId: '545500598323',
    projectId: 'unibooks-udec',
    storageBucket: 'unibooks-udec.firebasestorage.app',
    iosBundleId: 'co.edu.ucundinamarca.unibooks_app',
  );
}
