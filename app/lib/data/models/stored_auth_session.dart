import '../../domain/models/auth_user.dart';
import '../../domain/models/city.dart';

/// Sessão serializada no armazenamento seguro do dispositivo.
class StoredAuthSession {
  const StoredAuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
    this.selectedCity,
  });

  final String accessToken;
  final String refreshToken;
  final AuthUser user;

  /// Cidade escolhida pelo usuário, persistida junto da sessão.
  final City? selectedCity;

  StoredAuthSession copyWith({
    String? accessToken,
    String? refreshToken,
    AuthUser? user,
    City? selectedCity,
    bool clearCity = false,
  }) {
    return StoredAuthSession(
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      user: user ?? this.user,
      selectedCity: clearCity ? null : selectedCity ?? this.selectedCity,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'accessToken': accessToken,
      'refreshToken': refreshToken,
      'user': user.toJson(),
      'selectedCity': selectedCity?.toJson(),
    };
  }

  static StoredAuthSession? fromJson(Map<String, dynamic> json) {
    final accessToken = json['accessToken'];
    final refreshToken = json['refreshToken'];
    final user = json['user'];

    if (accessToken is! String ||
        accessToken.isEmpty ||
        refreshToken is! String ||
        refreshToken.isEmpty ||
        user is! Map<String, dynamic>) {
      return null;
    }

    return StoredAuthSession(
      accessToken: accessToken,
      refreshToken: refreshToken,
      user: AuthUser.fromJson(user),
      selectedCity: City.fromJsonOrNull(json['selectedCity']),
    );
  }
}
