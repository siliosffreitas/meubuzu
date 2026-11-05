import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'ui/core/theme/app_theme.dart';
import 'ui/routing/app_router.dart';

class MeuBuzuApp extends StatefulWidget {
  const MeuBuzuApp({super.key, this.router});

  /// Router opcional para testes. Quando não informado, o app cria um com
  /// [AppRouter].
  final GoRouter? router;

  @override
  State<MeuBuzuApp> createState() => _MeuBuzuAppState();
}

class _MeuBuzuAppState extends State<MeuBuzuApp> {
  late final GoRouter _router = widget.router ?? AppRouter().createRouter();

  @override
  void dispose() {
    if (widget.router == null) {
      _router.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'MeuBuzu',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      // A Home é a rota inicial para facilitar os testes. O fluxo de
      // autenticação está disponível em /auth (veja ui/routing/app_router.dart).
      routerConfig: _router,
    );
  }
}
