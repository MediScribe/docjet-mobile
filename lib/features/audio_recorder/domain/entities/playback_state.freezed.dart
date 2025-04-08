// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'playback_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$PlaybackState {
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() initial,
    required TResult Function() loading,
    required TResult Function(Duration currentPosition, Duration totalDuration)
        playing,
    required TResult Function(Duration currentPosition, Duration totalDuration)
        paused,
    required TResult Function() stopped,
    required TResult Function() completed,
    required TResult Function(
            String message, Duration? currentPosition, Duration? totalDuration)
        error,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? initial,
    TResult? Function()? loading,
    TResult? Function(Duration currentPosition, Duration totalDuration)?
        playing,
    TResult? Function(Duration currentPosition, Duration totalDuration)? paused,
    TResult? Function()? stopped,
    TResult? Function()? completed,
    TResult? Function(
            String message, Duration? currentPosition, Duration? totalDuration)?
        error,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? initial,
    TResult Function()? loading,
    TResult Function(Duration currentPosition, Duration totalDuration)? playing,
    TResult Function(Duration currentPosition, Duration totalDuration)? paused,
    TResult Function()? stopped,
    TResult Function()? completed,
    TResult Function(
            String message, Duration? currentPosition, Duration? totalDuration)?
        error,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_Initial value) initial,
    required TResult Function(_Loading value) loading,
    required TResult Function(_Playing value) playing,
    required TResult Function(_Paused value) paused,
    required TResult Function(_Stopped value) stopped,
    required TResult Function(_Completed value) completed,
    required TResult Function(_Error value) error,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_Initial value)? initial,
    TResult? Function(_Loading value)? loading,
    TResult? Function(_Playing value)? playing,
    TResult? Function(_Paused value)? paused,
    TResult? Function(_Stopped value)? stopped,
    TResult? Function(_Completed value)? completed,
    TResult? Function(_Error value)? error,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_Initial value)? initial,
    TResult Function(_Loading value)? loading,
    TResult Function(_Playing value)? playing,
    TResult Function(_Paused value)? paused,
    TResult Function(_Stopped value)? stopped,
    TResult Function(_Completed value)? completed,
    TResult Function(_Error value)? error,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PlaybackStateCopyWith<$Res> {
  factory $PlaybackStateCopyWith(
          PlaybackState value, $Res Function(PlaybackState) then) =
      _$PlaybackStateCopyWithImpl<$Res, PlaybackState>;
}

/// @nodoc
class _$PlaybackStateCopyWithImpl<$Res, $Val extends PlaybackState>
    implements $PlaybackStateCopyWith<$Res> {
  _$PlaybackStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of PlaybackState
  /// with the given fields replaced by the non-null parameter values.
}

/// @nodoc
abstract class _$$InitialImplCopyWith<$Res> {
  factory _$$InitialImplCopyWith(
          _$InitialImpl value, $Res Function(_$InitialImpl) then) =
      __$$InitialImplCopyWithImpl<$Res>;
}

/// @nodoc
class __$$InitialImplCopyWithImpl<$Res>
    extends _$PlaybackStateCopyWithImpl<$Res, _$InitialImpl>
    implements _$$InitialImplCopyWith<$Res> {
  __$$InitialImplCopyWithImpl(
      _$InitialImpl _value, $Res Function(_$InitialImpl) _then)
      : super(_value, _then);

  /// Create a copy of PlaybackState
  /// with the given fields replaced by the non-null parameter values.
}

/// @nodoc

class _$InitialImpl implements _Initial {
  const _$InitialImpl();

  @override
  String toString() {
    return 'PlaybackState.initial()';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is _$InitialImpl);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() initial,
    required TResult Function() loading,
    required TResult Function(Duration currentPosition, Duration totalDuration)
        playing,
    required TResult Function(Duration currentPosition, Duration totalDuration)
        paused,
    required TResult Function() stopped,
    required TResult Function() completed,
    required TResult Function(
            String message, Duration? currentPosition, Duration? totalDuration)
        error,
  }) {
    return initial();
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? initial,
    TResult? Function()? loading,
    TResult? Function(Duration currentPosition, Duration totalDuration)?
        playing,
    TResult? Function(Duration currentPosition, Duration totalDuration)? paused,
    TResult? Function()? stopped,
    TResult? Function()? completed,
    TResult? Function(
            String message, Duration? currentPosition, Duration? totalDuration)?
        error,
  }) {
    return initial?.call();
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? initial,
    TResult Function()? loading,
    TResult Function(Duration currentPosition, Duration totalDuration)? playing,
    TResult Function(Duration currentPosition, Duration totalDuration)? paused,
    TResult Function()? stopped,
    TResult Function()? completed,
    TResult Function(
            String message, Duration? currentPosition, Duration? totalDuration)?
        error,
    required TResult orElse(),
  }) {
    if (initial != null) {
      return initial();
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_Initial value) initial,
    required TResult Function(_Loading value) loading,
    required TResult Function(_Playing value) playing,
    required TResult Function(_Paused value) paused,
    required TResult Function(_Stopped value) stopped,
    required TResult Function(_Completed value) completed,
    required TResult Function(_Error value) error,
  }) {
    return initial(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_Initial value)? initial,
    TResult? Function(_Loading value)? loading,
    TResult? Function(_Playing value)? playing,
    TResult? Function(_Paused value)? paused,
    TResult? Function(_Stopped value)? stopped,
    TResult? Function(_Completed value)? completed,
    TResult? Function(_Error value)? error,
  }) {
    return initial?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_Initial value)? initial,
    TResult Function(_Loading value)? loading,
    TResult Function(_Playing value)? playing,
    TResult Function(_Paused value)? paused,
    TResult Function(_Stopped value)? stopped,
    TResult Function(_Completed value)? completed,
    TResult Function(_Error value)? error,
    required TResult orElse(),
  }) {
    if (initial != null) {
      return initial(this);
    }
    return orElse();
  }
}

abstract class _Initial implements PlaybackState {
  const factory _Initial() = _$InitialImpl;
}

/// @nodoc
abstract class _$$LoadingImplCopyWith<$Res> {
  factory _$$LoadingImplCopyWith(
          _$LoadingImpl value, $Res Function(_$LoadingImpl) then) =
      __$$LoadingImplCopyWithImpl<$Res>;
}

/// @nodoc
class __$$LoadingImplCopyWithImpl<$Res>
    extends _$PlaybackStateCopyWithImpl<$Res, _$LoadingImpl>
    implements _$$LoadingImplCopyWith<$Res> {
  __$$LoadingImplCopyWithImpl(
      _$LoadingImpl _value, $Res Function(_$LoadingImpl) _then)
      : super(_value, _then);

  /// Create a copy of PlaybackState
  /// with the given fields replaced by the non-null parameter values.
}

/// @nodoc

class _$LoadingImpl implements _Loading {
  const _$LoadingImpl();

  @override
  String toString() {
    return 'PlaybackState.loading()';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is _$LoadingImpl);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() initial,
    required TResult Function() loading,
    required TResult Function(Duration currentPosition, Duration totalDuration)
        playing,
    required TResult Function(Duration currentPosition, Duration totalDuration)
        paused,
    required TResult Function() stopped,
    required TResult Function() completed,
    required TResult Function(
            String message, Duration? currentPosition, Duration? totalDuration)
        error,
  }) {
    return loading();
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? initial,
    TResult? Function()? loading,
    TResult? Function(Duration currentPosition, Duration totalDuration)?
        playing,
    TResult? Function(Duration currentPosition, Duration totalDuration)? paused,
    TResult? Function()? stopped,
    TResult? Function()? completed,
    TResult? Function(
            String message, Duration? currentPosition, Duration? totalDuration)?
        error,
  }) {
    return loading?.call();
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? initial,
    TResult Function()? loading,
    TResult Function(Duration currentPosition, Duration totalDuration)? playing,
    TResult Function(Duration currentPosition, Duration totalDuration)? paused,
    TResult Function()? stopped,
    TResult Function()? completed,
    TResult Function(
            String message, Duration? currentPosition, Duration? totalDuration)?
        error,
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
    required TResult Function(_Initial value) initial,
    required TResult Function(_Loading value) loading,
    required TResult Function(_Playing value) playing,
    required TResult Function(_Paused value) paused,
    required TResult Function(_Stopped value) stopped,
    required TResult Function(_Completed value) completed,
    required TResult Function(_Error value) error,
  }) {
    return loading(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_Initial value)? initial,
    TResult? Function(_Loading value)? loading,
    TResult? Function(_Playing value)? playing,
    TResult? Function(_Paused value)? paused,
    TResult? Function(_Stopped value)? stopped,
    TResult? Function(_Completed value)? completed,
    TResult? Function(_Error value)? error,
  }) {
    return loading?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_Initial value)? initial,
    TResult Function(_Loading value)? loading,
    TResult Function(_Playing value)? playing,
    TResult Function(_Paused value)? paused,
    TResult Function(_Stopped value)? stopped,
    TResult Function(_Completed value)? completed,
    TResult Function(_Error value)? error,
    required TResult orElse(),
  }) {
    if (loading != null) {
      return loading(this);
    }
    return orElse();
  }
}

abstract class _Loading implements PlaybackState {
  const factory _Loading() = _$LoadingImpl;
}

/// @nodoc
abstract class _$$PlayingImplCopyWith<$Res> {
  factory _$$PlayingImplCopyWith(
          _$PlayingImpl value, $Res Function(_$PlayingImpl) then) =
      __$$PlayingImplCopyWithImpl<$Res>;
  @useResult
  $Res call({Duration currentPosition, Duration totalDuration});
}

/// @nodoc
class __$$PlayingImplCopyWithImpl<$Res>
    extends _$PlaybackStateCopyWithImpl<$Res, _$PlayingImpl>
    implements _$$PlayingImplCopyWith<$Res> {
  __$$PlayingImplCopyWithImpl(
      _$PlayingImpl _value, $Res Function(_$PlayingImpl) _then)
      : super(_value, _then);

  /// Create a copy of PlaybackState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? currentPosition = null,
    Object? totalDuration = null,
  }) {
    return _then(_$PlayingImpl(
      currentPosition: null == currentPosition
          ? _value.currentPosition
          : currentPosition // ignore: cast_nullable_to_non_nullable
              as Duration,
      totalDuration: null == totalDuration
          ? _value.totalDuration
          : totalDuration // ignore: cast_nullable_to_non_nullable
              as Duration,
    ));
  }
}

/// @nodoc

class _$PlayingImpl implements _Playing {
  const _$PlayingImpl(
      {required this.currentPosition, required this.totalDuration});

  @override
  final Duration currentPosition;
  @override
  final Duration totalDuration;

  @override
  String toString() {
    return 'PlaybackState.playing(currentPosition: $currentPosition, totalDuration: $totalDuration)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PlayingImpl &&
            (identical(other.currentPosition, currentPosition) ||
                other.currentPosition == currentPosition) &&
            (identical(other.totalDuration, totalDuration) ||
                other.totalDuration == totalDuration));
  }

  @override
  int get hashCode => Object.hash(runtimeType, currentPosition, totalDuration);

  /// Create a copy of PlaybackState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PlayingImplCopyWith<_$PlayingImpl> get copyWith =>
      __$$PlayingImplCopyWithImpl<_$PlayingImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() initial,
    required TResult Function() loading,
    required TResult Function(Duration currentPosition, Duration totalDuration)
        playing,
    required TResult Function(Duration currentPosition, Duration totalDuration)
        paused,
    required TResult Function() stopped,
    required TResult Function() completed,
    required TResult Function(
            String message, Duration? currentPosition, Duration? totalDuration)
        error,
  }) {
    return playing(currentPosition, totalDuration);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? initial,
    TResult? Function()? loading,
    TResult? Function(Duration currentPosition, Duration totalDuration)?
        playing,
    TResult? Function(Duration currentPosition, Duration totalDuration)? paused,
    TResult? Function()? stopped,
    TResult? Function()? completed,
    TResult? Function(
            String message, Duration? currentPosition, Duration? totalDuration)?
        error,
  }) {
    return playing?.call(currentPosition, totalDuration);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? initial,
    TResult Function()? loading,
    TResult Function(Duration currentPosition, Duration totalDuration)? playing,
    TResult Function(Duration currentPosition, Duration totalDuration)? paused,
    TResult Function()? stopped,
    TResult Function()? completed,
    TResult Function(
            String message, Duration? currentPosition, Duration? totalDuration)?
        error,
    required TResult orElse(),
  }) {
    if (playing != null) {
      return playing(currentPosition, totalDuration);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_Initial value) initial,
    required TResult Function(_Loading value) loading,
    required TResult Function(_Playing value) playing,
    required TResult Function(_Paused value) paused,
    required TResult Function(_Stopped value) stopped,
    required TResult Function(_Completed value) completed,
    required TResult Function(_Error value) error,
  }) {
    return playing(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_Initial value)? initial,
    TResult? Function(_Loading value)? loading,
    TResult? Function(_Playing value)? playing,
    TResult? Function(_Paused value)? paused,
    TResult? Function(_Stopped value)? stopped,
    TResult? Function(_Completed value)? completed,
    TResult? Function(_Error value)? error,
  }) {
    return playing?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_Initial value)? initial,
    TResult Function(_Loading value)? loading,
    TResult Function(_Playing value)? playing,
    TResult Function(_Paused value)? paused,
    TResult Function(_Stopped value)? stopped,
    TResult Function(_Completed value)? completed,
    TResult Function(_Error value)? error,
    required TResult orElse(),
  }) {
    if (playing != null) {
      return playing(this);
    }
    return orElse();
  }
}

abstract class _Playing implements PlaybackState {
  const factory _Playing(
      {required final Duration currentPosition,
      required final Duration totalDuration}) = _$PlayingImpl;

  Duration get currentPosition;
  Duration get totalDuration;

  /// Create a copy of PlaybackState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PlayingImplCopyWith<_$PlayingImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$PausedImplCopyWith<$Res> {
  factory _$$PausedImplCopyWith(
          _$PausedImpl value, $Res Function(_$PausedImpl) then) =
      __$$PausedImplCopyWithImpl<$Res>;
  @useResult
  $Res call({Duration currentPosition, Duration totalDuration});
}

/// @nodoc
class __$$PausedImplCopyWithImpl<$Res>
    extends _$PlaybackStateCopyWithImpl<$Res, _$PausedImpl>
    implements _$$PausedImplCopyWith<$Res> {
  __$$PausedImplCopyWithImpl(
      _$PausedImpl _value, $Res Function(_$PausedImpl) _then)
      : super(_value, _then);

  /// Create a copy of PlaybackState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? currentPosition = null,
    Object? totalDuration = null,
  }) {
    return _then(_$PausedImpl(
      currentPosition: null == currentPosition
          ? _value.currentPosition
          : currentPosition // ignore: cast_nullable_to_non_nullable
              as Duration,
      totalDuration: null == totalDuration
          ? _value.totalDuration
          : totalDuration // ignore: cast_nullable_to_non_nullable
              as Duration,
    ));
  }
}

/// @nodoc

class _$PausedImpl implements _Paused {
  const _$PausedImpl(
      {required this.currentPosition, required this.totalDuration});

  @override
  final Duration currentPosition;
  @override
  final Duration totalDuration;

  @override
  String toString() {
    return 'PlaybackState.paused(currentPosition: $currentPosition, totalDuration: $totalDuration)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PausedImpl &&
            (identical(other.currentPosition, currentPosition) ||
                other.currentPosition == currentPosition) &&
            (identical(other.totalDuration, totalDuration) ||
                other.totalDuration == totalDuration));
  }

  @override
  int get hashCode => Object.hash(runtimeType, currentPosition, totalDuration);

  /// Create a copy of PlaybackState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PausedImplCopyWith<_$PausedImpl> get copyWith =>
      __$$PausedImplCopyWithImpl<_$PausedImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() initial,
    required TResult Function() loading,
    required TResult Function(Duration currentPosition, Duration totalDuration)
        playing,
    required TResult Function(Duration currentPosition, Duration totalDuration)
        paused,
    required TResult Function() stopped,
    required TResult Function() completed,
    required TResult Function(
            String message, Duration? currentPosition, Duration? totalDuration)
        error,
  }) {
    return paused(currentPosition, totalDuration);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? initial,
    TResult? Function()? loading,
    TResult? Function(Duration currentPosition, Duration totalDuration)?
        playing,
    TResult? Function(Duration currentPosition, Duration totalDuration)? paused,
    TResult? Function()? stopped,
    TResult? Function()? completed,
    TResult? Function(
            String message, Duration? currentPosition, Duration? totalDuration)?
        error,
  }) {
    return paused?.call(currentPosition, totalDuration);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? initial,
    TResult Function()? loading,
    TResult Function(Duration currentPosition, Duration totalDuration)? playing,
    TResult Function(Duration currentPosition, Duration totalDuration)? paused,
    TResult Function()? stopped,
    TResult Function()? completed,
    TResult Function(
            String message, Duration? currentPosition, Duration? totalDuration)?
        error,
    required TResult orElse(),
  }) {
    if (paused != null) {
      return paused(currentPosition, totalDuration);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_Initial value) initial,
    required TResult Function(_Loading value) loading,
    required TResult Function(_Playing value) playing,
    required TResult Function(_Paused value) paused,
    required TResult Function(_Stopped value) stopped,
    required TResult Function(_Completed value) completed,
    required TResult Function(_Error value) error,
  }) {
    return paused(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_Initial value)? initial,
    TResult? Function(_Loading value)? loading,
    TResult? Function(_Playing value)? playing,
    TResult? Function(_Paused value)? paused,
    TResult? Function(_Stopped value)? stopped,
    TResult? Function(_Completed value)? completed,
    TResult? Function(_Error value)? error,
  }) {
    return paused?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_Initial value)? initial,
    TResult Function(_Loading value)? loading,
    TResult Function(_Playing value)? playing,
    TResult Function(_Paused value)? paused,
    TResult Function(_Stopped value)? stopped,
    TResult Function(_Completed value)? completed,
    TResult Function(_Error value)? error,
    required TResult orElse(),
  }) {
    if (paused != null) {
      return paused(this);
    }
    return orElse();
  }
}

abstract class _Paused implements PlaybackState {
  const factory _Paused(
      {required final Duration currentPosition,
      required final Duration totalDuration}) = _$PausedImpl;

  Duration get currentPosition;
  Duration get totalDuration;

  /// Create a copy of PlaybackState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PausedImplCopyWith<_$PausedImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$StoppedImplCopyWith<$Res> {
  factory _$$StoppedImplCopyWith(
          _$StoppedImpl value, $Res Function(_$StoppedImpl) then) =
      __$$StoppedImplCopyWithImpl<$Res>;
}

/// @nodoc
class __$$StoppedImplCopyWithImpl<$Res>
    extends _$PlaybackStateCopyWithImpl<$Res, _$StoppedImpl>
    implements _$$StoppedImplCopyWith<$Res> {
  __$$StoppedImplCopyWithImpl(
      _$StoppedImpl _value, $Res Function(_$StoppedImpl) _then)
      : super(_value, _then);

  /// Create a copy of PlaybackState
  /// with the given fields replaced by the non-null parameter values.
}

/// @nodoc

class _$StoppedImpl implements _Stopped {
  const _$StoppedImpl();

  @override
  String toString() {
    return 'PlaybackState.stopped()';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is _$StoppedImpl);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() initial,
    required TResult Function() loading,
    required TResult Function(Duration currentPosition, Duration totalDuration)
        playing,
    required TResult Function(Duration currentPosition, Duration totalDuration)
        paused,
    required TResult Function() stopped,
    required TResult Function() completed,
    required TResult Function(
            String message, Duration? currentPosition, Duration? totalDuration)
        error,
  }) {
    return stopped();
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? initial,
    TResult? Function()? loading,
    TResult? Function(Duration currentPosition, Duration totalDuration)?
        playing,
    TResult? Function(Duration currentPosition, Duration totalDuration)? paused,
    TResult? Function()? stopped,
    TResult? Function()? completed,
    TResult? Function(
            String message, Duration? currentPosition, Duration? totalDuration)?
        error,
  }) {
    return stopped?.call();
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? initial,
    TResult Function()? loading,
    TResult Function(Duration currentPosition, Duration totalDuration)? playing,
    TResult Function(Duration currentPosition, Duration totalDuration)? paused,
    TResult Function()? stopped,
    TResult Function()? completed,
    TResult Function(
            String message, Duration? currentPosition, Duration? totalDuration)?
        error,
    required TResult orElse(),
  }) {
    if (stopped != null) {
      return stopped();
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_Initial value) initial,
    required TResult Function(_Loading value) loading,
    required TResult Function(_Playing value) playing,
    required TResult Function(_Paused value) paused,
    required TResult Function(_Stopped value) stopped,
    required TResult Function(_Completed value) completed,
    required TResult Function(_Error value) error,
  }) {
    return stopped(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_Initial value)? initial,
    TResult? Function(_Loading value)? loading,
    TResult? Function(_Playing value)? playing,
    TResult? Function(_Paused value)? paused,
    TResult? Function(_Stopped value)? stopped,
    TResult? Function(_Completed value)? completed,
    TResult? Function(_Error value)? error,
  }) {
    return stopped?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_Initial value)? initial,
    TResult Function(_Loading value)? loading,
    TResult Function(_Playing value)? playing,
    TResult Function(_Paused value)? paused,
    TResult Function(_Stopped value)? stopped,
    TResult Function(_Completed value)? completed,
    TResult Function(_Error value)? error,
    required TResult orElse(),
  }) {
    if (stopped != null) {
      return stopped(this);
    }
    return orElse();
  }
}

abstract class _Stopped implements PlaybackState {
  const factory _Stopped() = _$StoppedImpl;
}

/// @nodoc
abstract class _$$CompletedImplCopyWith<$Res> {
  factory _$$CompletedImplCopyWith(
          _$CompletedImpl value, $Res Function(_$CompletedImpl) then) =
      __$$CompletedImplCopyWithImpl<$Res>;
}

/// @nodoc
class __$$CompletedImplCopyWithImpl<$Res>
    extends _$PlaybackStateCopyWithImpl<$Res, _$CompletedImpl>
    implements _$$CompletedImplCopyWith<$Res> {
  __$$CompletedImplCopyWithImpl(
      _$CompletedImpl _value, $Res Function(_$CompletedImpl) _then)
      : super(_value, _then);

  /// Create a copy of PlaybackState
  /// with the given fields replaced by the non-null parameter values.
}

/// @nodoc

class _$CompletedImpl implements _Completed {
  const _$CompletedImpl();

  @override
  String toString() {
    return 'PlaybackState.completed()';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is _$CompletedImpl);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() initial,
    required TResult Function() loading,
    required TResult Function(Duration currentPosition, Duration totalDuration)
        playing,
    required TResult Function(Duration currentPosition, Duration totalDuration)
        paused,
    required TResult Function() stopped,
    required TResult Function() completed,
    required TResult Function(
            String message, Duration? currentPosition, Duration? totalDuration)
        error,
  }) {
    return completed();
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? initial,
    TResult? Function()? loading,
    TResult? Function(Duration currentPosition, Duration totalDuration)?
        playing,
    TResult? Function(Duration currentPosition, Duration totalDuration)? paused,
    TResult? Function()? stopped,
    TResult? Function()? completed,
    TResult? Function(
            String message, Duration? currentPosition, Duration? totalDuration)?
        error,
  }) {
    return completed?.call();
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? initial,
    TResult Function()? loading,
    TResult Function(Duration currentPosition, Duration totalDuration)? playing,
    TResult Function(Duration currentPosition, Duration totalDuration)? paused,
    TResult Function()? stopped,
    TResult Function()? completed,
    TResult Function(
            String message, Duration? currentPosition, Duration? totalDuration)?
        error,
    required TResult orElse(),
  }) {
    if (completed != null) {
      return completed();
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_Initial value) initial,
    required TResult Function(_Loading value) loading,
    required TResult Function(_Playing value) playing,
    required TResult Function(_Paused value) paused,
    required TResult Function(_Stopped value) stopped,
    required TResult Function(_Completed value) completed,
    required TResult Function(_Error value) error,
  }) {
    return completed(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_Initial value)? initial,
    TResult? Function(_Loading value)? loading,
    TResult? Function(_Playing value)? playing,
    TResult? Function(_Paused value)? paused,
    TResult? Function(_Stopped value)? stopped,
    TResult? Function(_Completed value)? completed,
    TResult? Function(_Error value)? error,
  }) {
    return completed?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_Initial value)? initial,
    TResult Function(_Loading value)? loading,
    TResult Function(_Playing value)? playing,
    TResult Function(_Paused value)? paused,
    TResult Function(_Stopped value)? stopped,
    TResult Function(_Completed value)? completed,
    TResult Function(_Error value)? error,
    required TResult orElse(),
  }) {
    if (completed != null) {
      return completed(this);
    }
    return orElse();
  }
}

abstract class _Completed implements PlaybackState {
  const factory _Completed() = _$CompletedImpl;
}

/// @nodoc
abstract class _$$ErrorImplCopyWith<$Res> {
  factory _$$ErrorImplCopyWith(
          _$ErrorImpl value, $Res Function(_$ErrorImpl) then) =
      __$$ErrorImplCopyWithImpl<$Res>;
  @useResult
  $Res call(
      {String message, Duration? currentPosition, Duration? totalDuration});
}

/// @nodoc
class __$$ErrorImplCopyWithImpl<$Res>
    extends _$PlaybackStateCopyWithImpl<$Res, _$ErrorImpl>
    implements _$$ErrorImplCopyWith<$Res> {
  __$$ErrorImplCopyWithImpl(
      _$ErrorImpl _value, $Res Function(_$ErrorImpl) _then)
      : super(_value, _then);

  /// Create a copy of PlaybackState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? message = null,
    Object? currentPosition = freezed,
    Object? totalDuration = freezed,
  }) {
    return _then(_$ErrorImpl(
      message: null == message
          ? _value.message
          : message // ignore: cast_nullable_to_non_nullable
              as String,
      currentPosition: freezed == currentPosition
          ? _value.currentPosition
          : currentPosition // ignore: cast_nullable_to_non_nullable
              as Duration?,
      totalDuration: freezed == totalDuration
          ? _value.totalDuration
          : totalDuration // ignore: cast_nullable_to_non_nullable
              as Duration?,
    ));
  }
}

/// @nodoc

class _$ErrorImpl implements _Error {
  const _$ErrorImpl(
      {required this.message, this.currentPosition, this.totalDuration});

  @override
  final String message;
  @override
  final Duration? currentPosition;
  @override
  final Duration? totalDuration;

  @override
  String toString() {
    return 'PlaybackState.error(message: $message, currentPosition: $currentPosition, totalDuration: $totalDuration)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ErrorImpl &&
            (identical(other.message, message) || other.message == message) &&
            (identical(other.currentPosition, currentPosition) ||
                other.currentPosition == currentPosition) &&
            (identical(other.totalDuration, totalDuration) ||
                other.totalDuration == totalDuration));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, message, currentPosition, totalDuration);

  /// Create a copy of PlaybackState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ErrorImplCopyWith<_$ErrorImpl> get copyWith =>
      __$$ErrorImplCopyWithImpl<_$ErrorImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() initial,
    required TResult Function() loading,
    required TResult Function(Duration currentPosition, Duration totalDuration)
        playing,
    required TResult Function(Duration currentPosition, Duration totalDuration)
        paused,
    required TResult Function() stopped,
    required TResult Function() completed,
    required TResult Function(
            String message, Duration? currentPosition, Duration? totalDuration)
        error,
  }) {
    return error(message, currentPosition, totalDuration);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? initial,
    TResult? Function()? loading,
    TResult? Function(Duration currentPosition, Duration totalDuration)?
        playing,
    TResult? Function(Duration currentPosition, Duration totalDuration)? paused,
    TResult? Function()? stopped,
    TResult? Function()? completed,
    TResult? Function(
            String message, Duration? currentPosition, Duration? totalDuration)?
        error,
  }) {
    return error?.call(message, currentPosition, totalDuration);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? initial,
    TResult Function()? loading,
    TResult Function(Duration currentPosition, Duration totalDuration)? playing,
    TResult Function(Duration currentPosition, Duration totalDuration)? paused,
    TResult Function()? stopped,
    TResult Function()? completed,
    TResult Function(
            String message, Duration? currentPosition, Duration? totalDuration)?
        error,
    required TResult orElse(),
  }) {
    if (error != null) {
      return error(message, currentPosition, totalDuration);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_Initial value) initial,
    required TResult Function(_Loading value) loading,
    required TResult Function(_Playing value) playing,
    required TResult Function(_Paused value) paused,
    required TResult Function(_Stopped value) stopped,
    required TResult Function(_Completed value) completed,
    required TResult Function(_Error value) error,
  }) {
    return error(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_Initial value)? initial,
    TResult? Function(_Loading value)? loading,
    TResult? Function(_Playing value)? playing,
    TResult? Function(_Paused value)? paused,
    TResult? Function(_Stopped value)? stopped,
    TResult? Function(_Completed value)? completed,
    TResult? Function(_Error value)? error,
  }) {
    return error?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_Initial value)? initial,
    TResult Function(_Loading value)? loading,
    TResult Function(_Playing value)? playing,
    TResult Function(_Paused value)? paused,
    TResult Function(_Stopped value)? stopped,
    TResult Function(_Completed value)? completed,
    TResult Function(_Error value)? error,
    required TResult orElse(),
  }) {
    if (error != null) {
      return error(this);
    }
    return orElse();
  }
}

abstract class _Error implements PlaybackState {
  const factory _Error(
      {required final String message,
      final Duration? currentPosition,
      final Duration? totalDuration}) = _$ErrorImpl;

  String get message;
  Duration? get currentPosition;
  Duration? get totalDuration;

  /// Create a copy of PlaybackState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ErrorImplCopyWith<_$ErrorImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
