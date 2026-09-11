sealed class AppException implements Exception {
  const AppException(this.message);

  final String message;

  @override
  String toString() => message;
}

final class StorageException extends AppException {
  const StorageException(super.message);
}

final class SubscriptionException extends AppException {
  const SubscriptionException(super.message);
}

final class VpnException extends AppException {
  const VpnException(super.message);
}

final class VpnPermissionException extends VpnException {
  const VpnPermissionException(super.message);
}

final class ConnectionVerificationException extends VpnException {
  const ConnectionVerificationException(super.message);
}
