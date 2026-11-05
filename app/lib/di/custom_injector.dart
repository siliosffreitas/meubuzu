import 'package:auto_injector/auto_injector.dart';

import '../domain/contracts/contracts.dart';

/// Custom dependency injection wrapper around [AutoInjector].
///
/// Provides methods to register and retrieve dependencies with proper lifecycle management.
/// Supports resetting all dependencies on logout to ensure clean state for new user sessions.
class CustomInjector {
  AutoInjector _injector = AutoInjector();
  bool _isCommitted = false;

  void addRepository<T extends Repository>(Function constructor) {
    _injector.addLazySingleton<T>(
      constructor,
      config: BindConfig(onDispose: (instance) => instance.dispose()),
    );
  }

  void addService<T extends Service>(Function constructor) {
    _injector.addSingleton<T>(constructor);
  }

  void addViewModel<T extends ViewmodelBase>(Function constructor) {
    _injector.add<T>(
      constructor, // factory
    );
  }

  void addViewModelParam<T extends ViewmodelBase, P>(
    T Function(P) constructor,
  ) {
    _injector.addInstance<T Function(P)>(constructor, key: T.toString());
  }

  void commit() {
    _injector.commit();
    _isCommitted = true;
  }

  void dispose() => _injector.dispose();

  /// Resets all registered dependencies by disposing and recreating the injector.
  ///
  /// This should be called on logout to clear all cached data and ensure
  /// fresh instances are created for the next user session.
  void reset() {
    if (_isCommitted) {
      _injector.dispose();
      _injector = AutoInjector();
      _isCommitted = false;
    }
  }

  /// Returns true if the injector has been committed and is ready for use.
  bool get isReady => _isCommitted;

  T getViewModel<T extends ViewmodelBase>() => _injector.get<T>();

  T getViewModelParam<T extends ViewmodelBase, P>(P param) {
    final constructor = _injector.get<T Function(P)>(key: T.toString());
    return constructor(param);
  }

  T getRepository<T extends Repository>() => _injector.get<T>();

  T getService<T extends Service>() => _injector.get<T>();
}
