class AuthUser {
  final int id;
  final String username;
  final String displayName;
  final String role;

  const AuthUser({
    required this.id,
    required this.username,
    required this.displayName,
    required this.role,
  });

  bool get isAdmin => role == 'admin';
  String get roleLabel => isAdmin ? 'Admin' : 'Reception / Front Desk';

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
        id: json['id'] as int,
        username: json['username'] as String,
        displayName: json['display_name'] as String,
        role: json['role'] as String,
      );
}

class AuthSession {
  final String accessToken;
  final AuthUser user;
  final DateTime? expiresAt;

  const AuthSession({
    required this.accessToken,
    required this.user,
    this.expiresAt,
  });

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    final userData = json['user'];
    if (userData is! Map) {
      throw const FormatException('Expected an authenticated user object.');
    }
    return AuthSession(
      accessToken: json['access_token'] as String,
      user: AuthUser.fromJson(Map<String, dynamic>.from(userData)),
      expiresAt: DateTime.tryParse(json['expires_at']?.toString() ?? ''),
    );
  }
}

class PasswordResetRequestItem {
  final int id;
  final int? userId;
  final String username;
  final DateTime createdAt;

  const PasswordResetRequestItem({
    required this.id,
    required this.userId,
    required this.username,
    required this.createdAt,
  });

  factory PasswordResetRequestItem.fromJson(Map<String, dynamic> json) =>
      PasswordResetRequestItem(
        id: json['id'] as int,
        userId: json['user_id'] as int?,
        username: json['requested_username'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}
