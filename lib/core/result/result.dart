import '../errors/app_error.dart';

/// Generic Result type representing either a [Success] or a [Failure].
sealed class Result<T> {
  const Result();

  /// Returns true if the result represents a success.
  bool get isSuccess => this is Success<T>;

  /// Returns true if the result represents a failure.
  bool get isFailure => this is Failure<T>;

  /// Returns the success data or null.
  T? get dataOrNull => switch (this) {
        Success<T>(data: final d) => d,
        Failure<T>() => null,
      };

  /// Returns the failure error or null.
  AppError? get errorOrNull => switch (this) {
        Success<T>() => null,
        Failure<T>(error: final e) => e,
      };

  /// Transforms the data using [fn] if this is [Success].
  Result<R> map<R>(R Function(T data) fn) {
    return switch (this) {
      Success<T>(data: final d) => Success<R>(fn(d)),
      Failure<T>(error: final e) => Failure<R>(e),
    };
  }

  /// Pattern-matches over [onSuccess] and [onFailure].
  R when<R>({
    required R Function(T data) onSuccess,
    required R Function(AppError error) onFailure,
  }) {
    return switch (this) {
      Success<T>(data: final d) => onSuccess(d),
      Failure<T>(error: final e) => onFailure(e),
    };
  }
}

/// Success variant carrying data of type [T].
final class Success<T> extends Result<T> {
  final T data;
  const Success(this.data);

  @override
  String toString() => 'Success($data)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Success<T> && other.data == data);

  @override
  int get hashCode => data.hashCode;
}

/// Failure variant carrying an [AppError].
final class Failure<T> extends Result<T> {
  final AppError error;
  const Failure(this.error);

  @override
  String toString() => 'Failure($error)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Failure<T> && other.error == error);

  @override
  int get hashCode => error.hashCode;
}
