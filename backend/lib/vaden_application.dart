// GENERATED CODE - DO NOT MODIFY BY HAND
// Aggregated Vaden application file
// ignore_for_file: prefer_function_declarations_over_variables, implementation_imports
import 'package:backend/config/app_configuration.dart';
import 'package:backend/config/app_controller_advice.dart';
import 'package:dio/src/dio_exception.dart' show DioException;
import 'package:backend/config/dio/dio_configuration.dart';
import 'package:backend/config/postgres/postgres_configuration.dart';
import 'package:backend/config/resources/resource_configuration.dart';
import 'package:backend/src/hello_controller.dart';

import 'dart:convert';
import 'dart:io';
import 'package:vaden/vaden.dart';

class VadenApp implements DartVadenApplication {
  final _router = Router();
  final _injector = AutoInjector();

  @override
  AutoInjector get injector => _injector;

  @override
  Router get router => _router;

  VadenApp();

  @override
  Future<HttpServer> run(List<String> args) async {
    _injector.tryGet<CommandLineRunner>()?.run(args);
    _injector.tryGet<ApplicationRunner>()?.run(this);
    final pipeline = _injector.get<Pipeline>();
    final handler = pipeline.addHandler((request) async {
      try {
        final response = await _router(request);
        return response;
      } catch (e, stack) {
        print(e);
        print(stack);
        return _handleException(e);
      }
    });

    final settings = _injector.get<ApplicationSettings>();
    final port = settings['server']['port'] ?? 8080;
    final host = settings['server']['host'] ?? '0.0.0.0';

    final server = await serve(handler, host, port);

    return server;
  }

  @override
  Future<void> setup() async {
    final paths = <String, dynamic>{};
    final apis = <Api>[];
    final asyncBeans = <Future<void> Function()>[];
    _injector.addLazySingleton<DSON>(_DSON.new);

    final configurationAppConfiguration = AppConfiguration();

    _injector.addLazySingleton(configurationAppConfiguration.settings);
    _injector.addLazySingleton(configurationAppConfiguration.globalMiddleware);

    final configurationDioConfiguration = DioConfiguration();

    _injector.addLazySingleton(configurationDioConfiguration.dioApoiaseConfig);

    final configurationPostgresConfiguration = PostgresConfiguration();

    asyncBeans.add(() async {
      final result = await configurationPostgresConfiguration.connection(
        _injector(),
      );
      _injector.uncommit();
      _injector.addInstance(result);
      _injector.commit();
    });

    final configurationResourceConfiguration = ResourceConfiguration();

    _injector.addLazySingleton(
      configurationResourceConfiguration.configStorage,
    );
    _injector.addLazySingleton(configurationResourceConfiguration.resources);

    _injector.add(HelloController.new);
    final routerHelloController = Router();
    var pipelineHelloControllerhello = const Pipeline();
    final handlerHelloControllerhello = (Request request) async {
      final ctrl = _injector.get<HelloController>();
      final result = ctrl.hello();
      return Response.ok(result, headers: {'Content-Type': 'text/plain'});
    };
    routerHelloController.get(
      '/',
      pipelineHelloControllerhello.addHandler(handlerHelloControllerhello),
    );
    var pipelineHelloControllerping = const Pipeline();
    final handlerHelloControllerping = (Request request) async {
      final ctrl = _injector.get<HelloController>();
      final result = ctrl.ping();
      return Response.ok(result, headers: {'Content-Type': 'text/plain'});
    };
    routerHelloController.get(
      '/ping',
      pipelineHelloControllerping.addHandler(handlerHelloControllerping),
    );
    _router.mount('/hello', routerHelloController.call);

    _injector.addLazySingleton(AppControllerAdvice.new);

    _injector.addLazySingleton(OpenApiConfig.create(paths, apis).call);
    _injector.commit();

    for (final asyncBean in asyncBeans) {
      await asyncBean();
    }
  }

  Future<Response> _handleException(dynamic e) async {
    final controllerAdviceAppControllerAdvice = _injector
        .get<AppControllerAdvice>();
    if (e is DioException) {
      return await controllerAdviceAppControllerAdvice.handleDioException(e);
    }

    if (e is ResponseException) {
      return await controllerAdviceAppControllerAdvice.handleResponseException(
        e,
      );
    }

    if (e is Exception) {
      return controllerAdviceAppControllerAdvice.handleException(e);
    }

    return Response.internalServerError(
      body: jsonEncode({'error': 'Internal server error'}),
    );
  }

  PType? _parse<PType>(String? value) {
    if (value == null) {
      return null;
    }

    if (PType == int) {
      return int.parse(value) as PType;
    } else if (PType == double) {
      return double.parse(value) as PType;
    } else if (PType == bool) {
      return bool.parse(value) as PType;
    } else {
      return value as PType;
    }
  }
}

class _DSON extends DSON {
  @override
  (
    Map<Type, FromJsonFunction>,
    Map<Type, ToJsonFunction>,
    Map<Type, ToOpenApiNormalMap>,
  )
  getMaps() {
    final fromJsonMap = <Type, FromJsonFunction>{};
    final toJsonMap = <Type, ToJsonFunction>{};
    final toOpenApiMap = <Type, ToOpenApiNormalMap>{};

    return (fromJsonMap, toJsonMap, toOpenApiMap);
  }
}
