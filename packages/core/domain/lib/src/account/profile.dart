import '../auth/auth_contracts.dart';

enum AccountRole { client, barber }

class AccountProfile {
  const AccountProfile({
    required this.name,
    required this.email,
    required this.role,
    this.offline = false,
  });

  final String name;
  final String email;
  final AccountRole role;
  final bool offline;
}

abstract interface class ProfileRepository {
  Future<AppResult<AccountProfile>> loadProfile();
  Future<AppResult<AccountProfile>> updateName(String name);
}

class LoadProfileUseCase {
  const LoadProfileUseCase(this.repository);
  final ProfileRepository repository;

  Future<AppResult<AccountProfile>> call() => repository.loadProfile();
}

String initialProfileName(String name) =>
    name.length > UpdateProfileNameUseCase.maxLength
    ? name.substring(0, UpdateProfileNameUseCase.maxLength)
    : name;

class UpdateProfileNameUseCase {
  const UpdateProfileNameUseCase(this.repository);
  final ProfileRepository repository;

  static const maxLength = 120;

  Future<AppResult<AccountProfile>> call(String name) async {
    final normalized = name.trim();
    if (normalized.isEmpty || normalized.length > maxLength) {
      return const Failure(AuthError.profileNameLength);
    }
    return repository.updateName(normalized);
  }
}
