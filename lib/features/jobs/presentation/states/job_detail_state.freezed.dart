// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'job_detail_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$JobDetailState {
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() loading,
    required TResult Function(Job job) loaded,
    required TResult Function() notFound,
    required TResult Function(String message) error,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? loading,
    TResult? Function(Job job)? loaded,
    TResult? Function()? notFound,
    TResult? Function(String message)? error,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? loading,
    TResult Function(Job job)? loaded,
    TResult Function()? notFound,
    TResult Function(String message)? error,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(JobDetailLoading value) loading,
    required TResult Function(JobDetailLoaded value) loaded,
    required TResult Function(JobDetailNotFound value) notFound,
    required TResult Function(JobDetailError value) error,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(JobDetailLoading value)? loading,
    TResult? Function(JobDetailLoaded value)? loaded,
    TResult? Function(JobDetailNotFound value)? notFound,
    TResult? Function(JobDetailError value)? error,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(JobDetailLoading value)? loading,
    TResult Function(JobDetailLoaded value)? loaded,
    TResult Function(JobDetailNotFound value)? notFound,
    TResult Function(JobDetailError value)? error,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $JobDetailStateCopyWith<$Res> {
  factory $JobDetailStateCopyWith(
          JobDetailState value, $Res Function(JobDetailState) then) =
      _$JobDetailStateCopyWithImpl<$Res, JobDetailState>;
}

/// @nodoc
class _$JobDetailStateCopyWithImpl<$Res, $Val extends JobDetailState>
    implements $JobDetailStateCopyWith<$Res> {
  _$JobDetailStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of JobDetailState
  /// with the given fields replaced by the non-null parameter values.
}

/// @nodoc
abstract class _$$JobDetailLoadingImplCopyWith<$Res> {
  factory _$$JobDetailLoadingImplCopyWith(_$JobDetailLoadingImpl value,
          $Res Function(_$JobDetailLoadingImpl) then) =
      __$$JobDetailLoadingImplCopyWithImpl<$Res>;
}

/// @nodoc
class __$$JobDetailLoadingImplCopyWithImpl<$Res>
    extends _$JobDetailStateCopyWithImpl<$Res, _$JobDetailLoadingImpl>
    implements _$$JobDetailLoadingImplCopyWith<$Res> {
  __$$JobDetailLoadingImplCopyWithImpl(_$JobDetailLoadingImpl _value,
      $Res Function(_$JobDetailLoadingImpl) _then)
      : super(_value, _then);

  /// Create a copy of JobDetailState
  /// with the given fields replaced by the non-null parameter values.
}

/// @nodoc

class _$JobDetailLoadingImpl implements JobDetailLoading {
  const _$JobDetailLoadingImpl();

  @override
  String toString() {
    return 'JobDetailState.loading()';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is _$JobDetailLoadingImpl);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() loading,
    required TResult Function(Job job) loaded,
    required TResult Function() notFound,
    required TResult Function(String message) error,
  }) {
    return loading();
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? loading,
    TResult? Function(Job job)? loaded,
    TResult? Function()? notFound,
    TResult? Function(String message)? error,
  }) {
    return loading?.call();
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? loading,
    TResult Function(Job job)? loaded,
    TResult Function()? notFound,
    TResult Function(String message)? error,
    required TResult orElse(),
  }) {
    if (loading != null) {
      return loading();
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(JobDetailLoading value) loading,
    required TResult Function(JobDetailLoaded value) loaded,
    required TResult Function(JobDetailNotFound value) notFound,
    required TResult Function(JobDetailError value) error,
  }) {
    return loading(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(JobDetailLoading value)? loading,
    TResult? Function(JobDetailLoaded value)? loaded,
    TResult? Function(JobDetailNotFound value)? notFound,
    TResult? Function(JobDetailError value)? error,
  }) {
    return loading?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(JobDetailLoading value)? loading,
    TResult Function(JobDetailLoaded value)? loaded,
    TResult Function(JobDetailNotFound value)? notFound,
    TResult Function(JobDetailError value)? error,
    required TResult orElse(),
  }) {
    if (loading != null) {
      return loading(this);
    }
    return orElse();
  }
}

abstract class JobDetailLoading implements JobDetailState {
  const factory JobDetailLoading() = _$JobDetailLoadingImpl;
}

/// @nodoc
abstract class _$$JobDetailLoadedImplCopyWith<$Res> {
  factory _$$JobDetailLoadedImplCopyWith(_$JobDetailLoadedImpl value,
          $Res Function(_$JobDetailLoadedImpl) then) =
      __$$JobDetailLoadedImplCopyWithImpl<$Res>;
  @useResult
  $Res call({Job job});
}

/// @nodoc
class __$$JobDetailLoadedImplCopyWithImpl<$Res>
    extends _$JobDetailStateCopyWithImpl<$Res, _$JobDetailLoadedImpl>
    implements _$$JobDetailLoadedImplCopyWith<$Res> {
  __$$JobDetailLoadedImplCopyWithImpl(
      _$JobDetailLoadedImpl _value, $Res Function(_$JobDetailLoadedImpl) _then)
      : super(_value, _then);

  /// Create a copy of JobDetailState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? job = null,
  }) {
    return _then(_$JobDetailLoadedImpl(
      job: null == job
          ? _value.job
          : job // ignore: cast_nullable_to_non_nullable
              as Job,
    ));
  }
}

/// @nodoc

class _$JobDetailLoadedImpl implements JobDetailLoaded {
  const _$JobDetailLoadedImpl({required this.job});

  @override
  final Job job;

  @override
  String toString() {
    return 'JobDetailState.loaded(job: $job)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$JobDetailLoadedImpl &&
            (identical(other.job, job) || other.job == job));
  }

  @override
  int get hashCode => Object.hash(runtimeType, job);

  /// Create a copy of JobDetailState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$JobDetailLoadedImplCopyWith<_$JobDetailLoadedImpl> get copyWith =>
      __$$JobDetailLoadedImplCopyWithImpl<_$JobDetailLoadedImpl>(
          this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() loading,
    required TResult Function(Job job) loaded,
    required TResult Function() notFound,
    required TResult Function(String message) error,
  }) {
    return loaded(job);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? loading,
    TResult? Function(Job job)? loaded,
    TResult? Function()? notFound,
    TResult? Function(String message)? error,
  }) {
    return loaded?.call(job);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? loading,
    TResult Function(Job job)? loaded,
    TResult Function()? notFound,
    TResult Function(String message)? error,
    required TResult orElse(),
  }) {
    if (loaded != null) {
      return loaded(job);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(JobDetailLoading value) loading,
    required TResult Function(JobDetailLoaded value) loaded,
    required TResult Function(JobDetailNotFound value) notFound,
    required TResult Function(JobDetailError value) error,
  }) {
    return loaded(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(JobDetailLoading value)? loading,
    TResult? Function(JobDetailLoaded value)? loaded,
    TResult? Function(JobDetailNotFound value)? notFound,
    TResult? Function(JobDetailError value)? error,
  }) {
    return loaded?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(JobDetailLoading value)? loading,
    TResult Function(JobDetailLoaded value)? loaded,
    TResult Function(JobDetailNotFound value)? notFound,
    TResult Function(JobDetailError value)? error,
    required TResult orElse(),
  }) {
    if (loaded != null) {
      return loaded(this);
    }
    return orElse();
  }
}

abstract class JobDetailLoaded implements JobDetailState {
  const factory JobDetailLoaded({required final Job job}) =
      _$JobDetailLoadedImpl;

  Job get job;

  /// Create a copy of JobDetailState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$JobDetailLoadedImplCopyWith<_$JobDetailLoadedImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$JobDetailNotFoundImplCopyWith<$Res> {
  factory _$$JobDetailNotFoundImplCopyWith(_$JobDetailNotFoundImpl value,
          $Res Function(_$JobDetailNotFoundImpl) then) =
      __$$JobDetailNotFoundImplCopyWithImpl<$Res>;
}

/// @nodoc
class __$$JobDetailNotFoundImplCopyWithImpl<$Res>
    extends _$JobDetailStateCopyWithImpl<$Res, _$JobDetailNotFoundImpl>
    implements _$$JobDetailNotFoundImplCopyWith<$Res> {
  __$$JobDetailNotFoundImplCopyWithImpl(_$JobDetailNotFoundImpl _value,
      $Res Function(_$JobDetailNotFoundImpl) _then)
      : super(_value, _then);

  /// Create a copy of JobDetailState
  /// with the given fields replaced by the non-null parameter values.
}

/// @nodoc

class _$JobDetailNotFoundImpl implements JobDetailNotFound {
  const _$JobDetailNotFoundImpl();

  @override
  String toString() {
    return 'JobDetailState.notFound()';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is _$JobDetailNotFoundImpl);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() loading,
    required TResult Function(Job job) loaded,
    required TResult Function() notFound,
    required TResult Function(String message) error,
  }) {
    return notFound();
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? loading,
    TResult? Function(Job job)? loaded,
    TResult? Function()? notFound,
    TResult? Function(String message)? error,
  }) {
    return notFound?.call();
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? loading,
    TResult Function(Job job)? loaded,
    TResult Function()? notFound,
    TResult Function(String message)? error,
    required TResult orElse(),
  }) {
    if (notFound != null) {
      return notFound();
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(JobDetailLoading value) loading,
    required TResult Function(JobDetailLoaded value) loaded,
    required TResult Function(JobDetailNotFound value) notFound,
    required TResult Function(JobDetailError value) error,
  }) {
    return notFound(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(JobDetailLoading value)? loading,
    TResult? Function(JobDetailLoaded value)? loaded,
    TResult? Function(JobDetailNotFound value)? notFound,
    TResult? Function(JobDetailError value)? error,
  }) {
    return notFound?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(JobDetailLoading value)? loading,
    TResult Function(JobDetailLoaded value)? loaded,
    TResult Function(JobDetailNotFound value)? notFound,
    TResult Function(JobDetailError value)? error,
    required TResult orElse(),
  }) {
    if (notFound != null) {
      return notFound(this);
    }
    return orElse();
  }
}

abstract class JobDetailNotFound implements JobDetailState {
  const factory JobDetailNotFound() = _$JobDetailNotFoundImpl;
}

/// @nodoc
abstract class _$$JobDetailErrorImplCopyWith<$Res> {
  factory _$$JobDetailErrorImplCopyWith(_$JobDetailErrorImpl value,
          $Res Function(_$JobDetailErrorImpl) then) =
      __$$JobDetailErrorImplCopyWithImpl<$Res>;
  @useResult
  $Res call({String message});
}

/// @nodoc
class __$$JobDetailErrorImplCopyWithImpl<$Res>
    extends _$JobDetailStateCopyWithImpl<$Res, _$JobDetailErrorImpl>
    implements _$$JobDetailErrorImplCopyWith<$Res> {
  __$$JobDetailErrorImplCopyWithImpl(
      _$JobDetailErrorImpl _value, $Res Function(_$JobDetailErrorImpl) _then)
      : super(_value, _then);

  /// Create a copy of JobDetailState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? message = null,
  }) {
    return _then(_$JobDetailErrorImpl(
      message: null == message
          ? _value.message
          : message // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc

class _$JobDetailErrorImpl implements JobDetailError {
  const _$JobDetailErrorImpl({required this.message});

  @override
  final String message;

  @override
  String toString() {
    return 'JobDetailState.error(message: $message)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$JobDetailErrorImpl &&
            (identical(other.message, message) || other.message == message));
  }

  @override
  int get hashCode => Object.hash(runtimeType, message);

  /// Create a copy of JobDetailState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$JobDetailErrorImplCopyWith<_$JobDetailErrorImpl> get copyWith =>
      __$$JobDetailErrorImplCopyWithImpl<_$JobDetailErrorImpl>(
          this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() loading,
    required TResult Function(Job job) loaded,
    required TResult Function() notFound,
    required TResult Function(String message) error,
  }) {
    return error(message);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? loading,
    TResult? Function(Job job)? loaded,
    TResult? Function()? notFound,
    TResult? Function(String message)? error,
  }) {
    return error?.call(message);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? loading,
    TResult Function(Job job)? loaded,
    TResult Function()? notFound,
    TResult Function(String message)? error,
    required TResult orElse(),
  }) {
    if (error != null) {
      return error(message);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(JobDetailLoading value) loading,
    required TResult Function(JobDetailLoaded value) loaded,
    required TResult Function(JobDetailNotFound value) notFound,
    required TResult Function(JobDetailError value) error,
  }) {
    return error(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(JobDetailLoading value)? loading,
    TResult? Function(JobDetailLoaded value)? loaded,
    TResult? Function(JobDetailNotFound value)? notFound,
    TResult? Function(JobDetailError value)? error,
  }) {
    return error?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(JobDetailLoading value)? loading,
    TResult Function(JobDetailLoaded value)? loaded,
    TResult Function(JobDetailNotFound value)? notFound,
    TResult Function(JobDetailError value)? error,
    required TResult orElse(),
  }) {
    if (error != null) {
      return error(this);
    }
    return orElse();
  }
}

abstract class JobDetailError implements JobDetailState {
  const factory JobDetailError({required final String message}) =
      _$JobDetailErrorImpl;

  String get message;

  /// Create a copy of JobDetailState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$JobDetailErrorImplCopyWith<_$JobDetailErrorImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
