/// Conta autenticada no aplicativo.
class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    this.accessLevel = 'catalog_only',
  });

  final String id;
  final String email;

  /// Nível de acesso vigente no backend (`catalog_only`, `trial`, `paid`...).
  final String accessLevel;

  AuthUser copyWith({String? id, String? email, String? accessLevel}) {
    return AuthUser(
      id: id ?? this.id,
      email: email ?? this.email,
      accessLevel: accessLevel ?? this.accessLevel,
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'email': email, 'accessLevel': accessLevel};
  }

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      accessLevel: json['accessLevel'] as String? ?? 'catalog_only',
    );
  }
}
