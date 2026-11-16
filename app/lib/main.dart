import 'dart:async';

import 'package:flutter/material.dart';

import 'app.dart';
import 'di/dependencies.dart';
import 'domain/repositories/auth_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await setupDependencies();

  final authRepository = injector.getRepository<AuthRepository>();

  // Restaura a sessão salva no dispositivo antes de montar o app, para que a
  // primeira rota já reflita o estado real (Home ou autenticação).
  await authRepository.restoreSession();

  runApp(const MeuBuzuApp());

  // A validação e a renovação acontecem em segundo plano: o app abre mesmo
  // offline, mantendo a sessão local de forma otimista.
  unawaited(authRepository.validateSession());
}
