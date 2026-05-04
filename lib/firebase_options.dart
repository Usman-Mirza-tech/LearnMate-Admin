import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    throw UnsupportedError(
      'DefaultFirebaseOptions are only configured for web in this project.',
    );
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBk1yFSOqVDxDdZyoVByYPrZzkiHT6sPn8',
    appId: '1:821713751952:web:eaf0eecc0e0964231c2d15',
    messagingSenderId: '821713751952',
    projectId: 'learn-mate-c3af7',
    authDomain: 'learn-mate-c3af7.firebaseapp.com',
    storageBucket: 'learn-mate-c3af7.firebasestorage.app',
  );
}
