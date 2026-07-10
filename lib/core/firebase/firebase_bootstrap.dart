import 'package:firebase_core/firebase_core.dart';

import '../../firebase_options.dart';

class FirebaseBootstrap {
  FirebaseBootstrap._();

  static Future<void> init() async {
    if (Firebase.apps.isNotEmpty) return;
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  }
}
