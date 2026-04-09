export 'failure.dart';
import 'failure.dart';

class UseCase {
  static Either<Failure, T> success<T>(T data) => Right(data);
  static Either<Failure, T> failure<T>(Failure failure) => Left(failure);
}

class Either<L, R> {
  final L? _left;
  final R? _right;
  final bool _isRight;

  const Either.left(this._left) : _right = null, _isRight = false;
  const Either.right(this._right) : _left = null, _isRight = true;

  bool get isRight => _isRight;
  bool get isLeft => !_isRight;

  T fold<T>(T Function(L left) leftFn, T Function(R right) rightFn) {
    return _isRight ? rightFn(_right as R) : leftFn(_left as L);
  }

  R getOrElse(R Function(L left) fn) {
    return _isRight ? _right as R : fn(_left as L);
  }
}

class Left<L, R> extends Either<L, R> {
  const Left(L value) : super.left(value);
}

class Right<L, R> extends Either<L, R> {
  const Right(R value) : super.right(value);
}
