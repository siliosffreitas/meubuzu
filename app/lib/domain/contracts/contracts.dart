import 'package:flutter/foundation.dart';

/// Contrato base para recursos com ciclo de vida gerenciado pelo injetor.
abstract interface class Repository {
  /// Libera os recursos do repositório.
  void dispose();
}

/// Marcador para services compartilhados registrados no injetor.
abstract interface class Service {}

/// Contrato base dos view models observáveis pelo app.
abstract class ViewmodelBase extends ChangeNotifier {}
