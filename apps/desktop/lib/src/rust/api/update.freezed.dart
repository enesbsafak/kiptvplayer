// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'update.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$UpdateProgress {





@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is UpdateProgress);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'UpdateProgress()';
}


}

/// @nodoc
class $UpdateProgressCopyWith<$Res>  {
$UpdateProgressCopyWith(UpdateProgress _, $Res Function(UpdateProgress) __);
}


/// Adds pattern-matching-related methods to [UpdateProgress].
extension UpdateProgressPatterns on UpdateProgress {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( UpdateProgress_Downloading value)?  downloading,TResult Function( UpdateProgress_Ready value)?  ready,TResult Function( UpdateProgress_Failed value)?  failed,required TResult orElse(),}){
final _that = this;
switch (_that) {
case UpdateProgress_Downloading() when downloading != null:
return downloading(_that);case UpdateProgress_Ready() when ready != null:
return ready(_that);case UpdateProgress_Failed() when failed != null:
return failed(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( UpdateProgress_Downloading value)  downloading,required TResult Function( UpdateProgress_Ready value)  ready,required TResult Function( UpdateProgress_Failed value)  failed,}){
final _that = this;
switch (_that) {
case UpdateProgress_Downloading():
return downloading(_that);case UpdateProgress_Ready():
return ready(_that);case UpdateProgress_Failed():
return failed(_that);}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( UpdateProgress_Downloading value)?  downloading,TResult? Function( UpdateProgress_Ready value)?  ready,TResult? Function( UpdateProgress_Failed value)?  failed,}){
final _that = this;
switch (_that) {
case UpdateProgress_Downloading() when downloading != null:
return downloading(_that);case UpdateProgress_Ready() when ready != null:
return ready(_that);case UpdateProgress_Failed() when failed != null:
return failed(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( double fraction)?  downloading,TResult Function( String path)?  ready,TResult Function( String message)?  failed,required TResult orElse(),}) {final _that = this;
switch (_that) {
case UpdateProgress_Downloading() when downloading != null:
return downloading(_that.fraction);case UpdateProgress_Ready() when ready != null:
return ready(_that.path);case UpdateProgress_Failed() when failed != null:
return failed(_that.message);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( double fraction)  downloading,required TResult Function( String path)  ready,required TResult Function( String message)  failed,}) {final _that = this;
switch (_that) {
case UpdateProgress_Downloading():
return downloading(_that.fraction);case UpdateProgress_Ready():
return ready(_that.path);case UpdateProgress_Failed():
return failed(_that.message);}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( double fraction)?  downloading,TResult? Function( String path)?  ready,TResult? Function( String message)?  failed,}) {final _that = this;
switch (_that) {
case UpdateProgress_Downloading() when downloading != null:
return downloading(_that.fraction);case UpdateProgress_Ready() when ready != null:
return ready(_that.path);case UpdateProgress_Failed() when failed != null:
return failed(_that.message);case _:
  return null;

}
}

}

/// @nodoc


class UpdateProgress_Downloading extends UpdateProgress {
  const UpdateProgress_Downloading({required this.fraction}): super._();
  

 final  double fraction;

/// Create a copy of UpdateProgress
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UpdateProgress_DownloadingCopyWith<UpdateProgress_Downloading> get copyWith => _$UpdateProgress_DownloadingCopyWithImpl<UpdateProgress_Downloading>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is UpdateProgress_Downloading&&(identical(other.fraction, fraction) || other.fraction == fraction));
}


@override
int get hashCode {
    return Object.hash(runtimeType,fraction);
}

@override
String toString() {
    return 'UpdateProgress.downloading(fraction: $fraction)';
}


}

/// @nodoc
abstract mixin class $UpdateProgress_DownloadingCopyWith<$Res> implements $UpdateProgressCopyWith<$Res> {
  factory $UpdateProgress_DownloadingCopyWith(UpdateProgress_Downloading value, $Res Function(UpdateProgress_Downloading) _then) = _$UpdateProgress_DownloadingCopyWithImpl;
@useResult
$Res call({
 double fraction
});




}
/// @nodoc
class _$UpdateProgress_DownloadingCopyWithImpl<$Res>
    implements $UpdateProgress_DownloadingCopyWith<$Res> {
  _$UpdateProgress_DownloadingCopyWithImpl(this._self, this._then);

  final UpdateProgress_Downloading _self;
  final $Res Function(UpdateProgress_Downloading) _then;

/// Create a copy of UpdateProgress
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? fraction = null,}) {
  return _then(UpdateProgress_Downloading(
fraction: null == fraction ? _self.fraction : fraction // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

/// @nodoc


class UpdateProgress_Ready extends UpdateProgress {
  const UpdateProgress_Ready({required this.path}): super._();
  

 final  String path;

/// Create a copy of UpdateProgress
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UpdateProgress_ReadyCopyWith<UpdateProgress_Ready> get copyWith => _$UpdateProgress_ReadyCopyWithImpl<UpdateProgress_Ready>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is UpdateProgress_Ready&&(identical(other.path, path) || other.path == path));
}


@override
int get hashCode {
    return Object.hash(runtimeType,path);
}

@override
String toString() {
    return 'UpdateProgress.ready(path: $path)';
}


}

/// @nodoc
abstract mixin class $UpdateProgress_ReadyCopyWith<$Res> implements $UpdateProgressCopyWith<$Res> {
  factory $UpdateProgress_ReadyCopyWith(UpdateProgress_Ready value, $Res Function(UpdateProgress_Ready) _then) = _$UpdateProgress_ReadyCopyWithImpl;
@useResult
$Res call({
 String path
});




}
/// @nodoc
class _$UpdateProgress_ReadyCopyWithImpl<$Res>
    implements $UpdateProgress_ReadyCopyWith<$Res> {
  _$UpdateProgress_ReadyCopyWithImpl(this._self, this._then);

  final UpdateProgress_Ready _self;
  final $Res Function(UpdateProgress_Ready) _then;

/// Create a copy of UpdateProgress
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? path = null,}) {
  return _then(UpdateProgress_Ready(
path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class UpdateProgress_Failed extends UpdateProgress {
  const UpdateProgress_Failed({required this.message}): super._();
  

 final  String message;

/// Create a copy of UpdateProgress
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UpdateProgress_FailedCopyWith<UpdateProgress_Failed> get copyWith => _$UpdateProgress_FailedCopyWithImpl<UpdateProgress_Failed>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is UpdateProgress_Failed&&(identical(other.message, message) || other.message == message));
}


@override
int get hashCode {
    return Object.hash(runtimeType,message);
}

@override
String toString() {
    return 'UpdateProgress.failed(message: $message)';
}


}

/// @nodoc
abstract mixin class $UpdateProgress_FailedCopyWith<$Res> implements $UpdateProgressCopyWith<$Res> {
  factory $UpdateProgress_FailedCopyWith(UpdateProgress_Failed value, $Res Function(UpdateProgress_Failed) _then) = _$UpdateProgress_FailedCopyWithImpl;
@useResult
$Res call({
 String message
});




}
/// @nodoc
class _$UpdateProgress_FailedCopyWithImpl<$Res>
    implements $UpdateProgress_FailedCopyWith<$Res> {
  _$UpdateProgress_FailedCopyWithImpl(this._self, this._then);

  final UpdateProgress_Failed _self;
  final $Res Function(UpdateProgress_Failed) _then;

/// Create a copy of UpdateProgress
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? message = null,}) {
  return _then(UpdateProgress_Failed(
message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
