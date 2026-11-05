import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/home/presentation/home_page.dart';

class MeuBuzuApp extends StatelessWidget {
  const MeuBuzuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MeuBuzu',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      // A autenticação continua disponível em features/auth. A Home é a tela
      // inicial temporária para facilitar os testes.
      home: const HomePage(),
    );
  }
}
