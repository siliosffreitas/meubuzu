import 'package:meubuzu/domain/models/tracked_line.dart';

import '../contracts/contracts.dart';

abstract interface class TrackingRepository implements Repository {
  Stream<List<TrackedLine>> get trackingRoutes;
}