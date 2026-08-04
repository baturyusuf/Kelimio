sealed class AppFailure implements Exception {
  const AppFailure({this.requestId, this.cause});

  final String? requestId;
  final Object? cause;

  bool get isRetryable => false;
}

final class ConfigurationFailure extends AppFailure {
  const ConfigurationFailure(this.missingDefines);

  final List<String> missingDefines;
}

final class AuthenticationRequiredFailure extends AppFailure {
  const AuthenticationRequiredFailure({super.requestId, super.cause});
}

final class ForbiddenFailure extends AppFailure {
  const ForbiddenFailure({
    this.code,
    this.detail,
    super.requestId,
    super.cause,
  });

  final String? code;
  final String? detail;
}

final class AuthenticationCancelledFailure extends AppFailure {
  const AuthenticationCancelledFailure({super.cause});
}

final class NetworkFailure extends AppFailure {
  const NetworkFailure({super.requestId, super.cause});

  @override
  bool get isRetryable => true;
}

final class TimeoutFailure extends AppFailure {
  const TimeoutFailure({super.requestId, super.cause});

  @override
  bool get isRetryable => true;
}

final class ServerFailure extends AppFailure {
  const ServerFailure({
    required this.status,
    this.code,
    this.detail,
    super.requestId,
    super.cause,
  });

  final int status;
  final String? code;
  final String? detail;

  @override
  bool get isRetryable => status >= 500 || status == 429;
}

enum ServiceOperatingMode { conserve, readOnly, suspended }

final class OperatingModeFailure extends AppFailure {
  const OperatingModeFailure({
    required this.mode,
    super.requestId,
    super.cause,
  });

  final ServiceOperatingMode mode;

  @override
  bool get isRetryable => true;
}

final class ValidationFailure extends AppFailure {
  const ValidationFailure({
    this.code,
    this.detail,
    super.requestId,
    super.cause,
  });

  final String? code;
  final String? detail;
}

final class ConflictFailure extends AppFailure {
  const ConflictFailure({this.code, this.detail, super.requestId, super.cause});

  final String? code;
  final String? detail;
}

final class ContentChangedFailure extends AppFailure {
  const ContentChangedFailure({this.detail, super.requestId, super.cause});

  final String? detail;
}

final class EnergyDepletedFailure extends AppFailure {
  const EnergyDepletedFailure({this.detail, super.requestId, super.cause});

  final String? detail;
}

final class ProtocolFailure extends AppFailure {
  const ProtocolFailure(this.message, {super.requestId, super.cause});

  final String message;
}

final class UnknownFailure extends AppFailure {
  const UnknownFailure({super.requestId, super.cause});
}
