import 'package:flutter/material.dart';

import 'app.dart';
import 'di/dependencies.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await setupDependencies();
  runApp(const MeuBuzuApp());
}
