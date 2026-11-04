import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/presentation/auth_email/auth_email_page.dart';

class MeuBuzuApp extends StatelessWidget {
  const MeuBuzuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MeuBuzu',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const AuthEmailPage(repository: FakeAuthRepository()),
    );
  }
}
