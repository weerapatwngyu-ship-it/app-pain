import 'package:equatable/equatable.dart';

/// Matches the four roles from the architecture doc's user table.
enum UserRole { patient, caregiver, provider, admin }

class User extends Equatable {
  const User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
  });

  final String id;
  final String name;
  final String email;
  final UserRole role;

  @override
  List<Object?> get props => [id, name, email, role];
}
