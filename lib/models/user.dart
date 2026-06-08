import '../utils/json_helpers.dart';

class User {
  final int id;
  final String username;
  final String? email;
  final String? avatarUrl;
  final bool? emailVerified;
  final int? registrationOrder;
  final String? registrationDate;
  final String? joinDuration;
  final bool isBot;

  User({
    required this.id,
    required this.username,
    this.email,
    this.avatarUrl,
    this.emailVerified,
    this.registrationOrder,
    this.registrationDate,
    this.joinDuration,
    this.isBot = false,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: JsonHelpers.parseInt(json, 'id', 'uid') ?? 0,
      username: JsonHelpers.parseString(json, 'username') ?? '',
      email: JsonHelpers.parseString(json, 'email'),
      avatarUrl: JsonHelpers.parseString(
          json, 'avatar_url', 'avatarUrl', 'avatar', 'userAvatar'),
      emailVerified: json['emailVerified'] as bool?,
      registrationOrder:
          JsonHelpers.parseInt(json, 'registrationOrder'),
      registrationDate:
          JsonHelpers.parseString(json, 'registrationDate'),
      joinDuration:
          JsonHelpers.parseString(json, 'joinDuration'),
      isBot: json['isBot'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'email': email,
        'avatar_url': avatarUrl,
        'emailVerified': emailVerified,
        'registrationOrder': registrationOrder,
        'registrationDate': registrationDate,
        'joinDuration': joinDuration,
        'isBot': isBot,
      };
}
