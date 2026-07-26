/// Base type for recoverable errors surfaced from the data layer up to
/// the presentation layer, so screens can show a message instead of
/// crashing on an unhandled exception.
sealed class Failure {
  const Failure(this.message);

  final String message;
}

class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'ไม่สามารถเชื่อมต่อเครือข่ายได้']);
}

class ServerFailure extends Failure {
  const ServerFailure([super.message = 'เกิดข้อผิดพลาดจากเซิร์ฟเวอร์']);
}

class CacheFailure extends Failure {
  const CacheFailure([super.message = 'ไม่พบข้อมูลที่บันทึกไว้ในเครื่อง']);
}

class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure([super.message = 'กรุณาเข้าสู่ระบบใหม่อีกครั้ง']);
}

/// Lightweight Either-style result so use cases don't need to throw for
/// expected failure paths (network down, validation error, etc).
sealed class Result<T> {
  const Result();

  R when<R>({
    required R Function(T value) success,
    required R Function(Failure failure) failure,
  }) {
    final self = this;
    if (self is Success<T>) return success(self.value);
    if (self is Error<T>) return failure(self.failure);
    throw StateError('Unreachable');
  }
}

class Success<T> extends Result<T> {
  const Success(this.value);
  final T value;
}

class Error<T> extends Result<T> {
  const Error(this.failure);
  final Failure failure;
}
