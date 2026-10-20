// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'library.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SyncEvent {





@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is SyncEvent);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'SyncEvent()';
}


}

/// @nodoc
class $SyncEventCopyWith<$Res>  {
$SyncEventCopyWith(SyncEvent _, $Res Function(SyncEvent) __);
}


/// Adds pattern-matching-related methods to [SyncEvent].
extension SyncEventPatterns on SyncEvent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( SyncEvent_Connecting value)?  connecting,TResult Function( SyncEvent_Downloading value)?  downloading,TResult Function( SyncEvent_Saving value)?  saving,TResult Function( SyncEvent_Done value)?  done,TResult Function( SyncEvent_Failed value)?  failed,required TResult orElse(),}){
final _that = this;
switch (_that) {
case SyncEvent_Connecting() when connecting != null:
return connecting(_that);case SyncEvent_Downloading() when downloading != null:
return downloading(_that);case SyncEvent_Saving() when saving != null:
return saving(_that);case SyncEvent_Done() when done != null:
return done(_that);case SyncEvent_Failed() when failed != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( SyncEvent_Connecting value)  connecting,required TResult Function( SyncEvent_Downloading value)  downloading,required TResult Function( SyncEvent_Saving value)  saving,required TResult Function( SyncEvent_Done value)  done,required TResult Function( SyncEvent_Failed value)  failed,}){
final _that = this;
switch (_that) {
case SyncEvent_Connecting():
return connecting(_that);case SyncEvent_Downloading():
return downloading(_that);case SyncEvent_Saving():
return saving(_that);case SyncEvent_Done():
return done(_that);case SyncEvent_Failed():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( SyncEvent_Connecting value)?  connecting,TResult? Function( SyncEvent_Downloading value)?  downloading,TResult? Function( SyncEvent_Saving value)?  saving,TResult? Function( SyncEvent_Done value)?  done,TResult? Function( SyncEvent_Failed value)?  failed,}){
final _that = this;
switch (_that) {
case SyncEvent_Connecting() when connecting != null:
return connecting(_that);case SyncEvent_Downloading() when downloading != null:
return downloading(_that);case SyncEvent_Saving() when saving != null:
return saving(_that);case SyncEvent_Done() when done != null:
return done(_that);case SyncEvent_Failed() when failed != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  connecting,TResult Function( String what)?  downloading,TResult Function()?  saving,TResult Function( SourceInfo source)?  done,TResult Function( String message)?  failed,required TResult orElse(),}) {final _that = this;
switch (_that) {
case SyncEvent_Connecting() when connecting != null:
return connecting();case SyncEvent_Downloading() when downloading != null:
return downloading(_that.what);case SyncEvent_Saving() when saving != null:
return saving();case SyncEvent_Done() when done != null:
return done(_that.source);case SyncEvent_Failed() when failed != null:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  connecting,required TResult Function( String what)  downloading,required TResult Function()  saving,required TResult Function( SourceInfo source)  done,required TResult Function( String message)  failed,}) {final _that = this;
switch (_that) {
case SyncEvent_Connecting():
return connecting();case SyncEvent_Downloading():
return downloading(_that.what);case SyncEvent_Saving():
return saving();case SyncEvent_Done():
return done(_that.source);case SyncEvent_Failed():
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  connecting,TResult? Function( String what)?  downloading,TResult? Function()?  saving,TResult? Function( SourceInfo source)?  done,TResult? Function( String message)?  failed,}) {final _that = this;
switch (_that) {
case SyncEvent_Connecting() when connecting != null:
return connecting();case SyncEvent_Downloading() when downloading != null:
return downloading(_that.what);case SyncEvent_Saving() when saving != null:
return saving();case SyncEvent_Done() when done != null:
return done(_that.source);case SyncEvent_Failed() when failed != null:
return failed(_that.message);case _:
  return null;

}
}

}

/// @nodoc


class SyncEvent_Connecting extends SyncEvent {
  const SyncEvent_Connecting(): super._();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is SyncEvent_Connecting);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'SyncEvent.connecting()';
}


}




/// @nodoc


class SyncEvent_Downloading extends SyncEvent {
  const SyncEvent_Downloading({required this.what}): super._();
  

 final  String what;

/// Create a copy of SyncEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SyncEvent_DownloadingCopyWith<SyncEvent_Downloading> get copyWith => _$SyncEvent_DownloadingCopyWithImpl<SyncEvent_Downloading>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is SyncEvent_Downloading&&(identical(other.what, what) || other.what == what));
}


@override
int get hashCode {
    return Object.hash(runtimeType,what);
}

@override
String toString() {
    return 'SyncEvent.downloading(what: $what)';
}


}

/// @nodoc
abstract mixin class $SyncEvent_DownloadingCopyWith<$Res> implements $SyncEventCopyWith<$Res> {
  factory $SyncEvent_DownloadingCopyWith(SyncEvent_Downloading value, $Res Function(SyncEvent_Downloading) _then) = _$SyncEvent_DownloadingCopyWithImpl;
@useResult
$Res call({
 String what
});




}
/// @nodoc
class _$SyncEvent_DownloadingCopyWithImpl<$Res>
    implements $SyncEvent_DownloadingCopyWith<$Res> {
  _$SyncEvent_DownloadingCopyWithImpl(this._self, this._then);

  final SyncEvent_Downloading _self;
  final $Res Function(SyncEvent_Downloading) _then;

/// Create a copy of SyncEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? what = null,}) {
  return _then(SyncEvent_Downloading(
what: null == what ? _self.what : what // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class SyncEvent_Saving extends SyncEvent {
  const SyncEvent_Saving(): super._();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is SyncEvent_Saving);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'SyncEvent.saving()';
}


}




/// @nodoc


class SyncEvent_Done extends SyncEvent {
  const SyncEvent_Done({required this.source}): super._();
  

 final  SourceInfo source;

/// Create a copy of SyncEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SyncEvent_DoneCopyWith<SyncEvent_Done> get copyWith => _$SyncEvent_DoneCopyWithImpl<SyncEvent_Done>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is SyncEvent_Done&&(identical(other.source, source) || other.source == source));
}


@override
int get hashCode {
    return Object.hash(runtimeType,source);
}

@override
String toString() {
    return 'SyncEvent.done(source: $source)';
}


}

/// @nodoc
abstract mixin class $SyncEvent_DoneCopyWith<$Res> implements $SyncEventCopyWith<$Res> {
  factory $SyncEvent_DoneCopyWith(SyncEvent_Done value, $Res Function(SyncEvent_Done) _then) = _$SyncEvent_DoneCopyWithImpl;
@useResult
$Res call({
 SourceInfo source
});




}
/// @nodoc
class _$SyncEvent_DoneCopyWithImpl<$Res>
    implements $SyncEvent_DoneCopyWith<$Res> {
  _$SyncEvent_DoneCopyWithImpl(this._self, this._then);

  final SyncEvent_Done _self;
  final $Res Function(SyncEvent_Done) _then;

/// Create a copy of SyncEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? source = null,}) {
  return _then(SyncEvent_Done(
source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as SourceInfo,
  ));
}


}

/// @nodoc


class SyncEvent_Failed extends SyncEvent {
  const SyncEvent_Failed({required this.message}): super._();
  

 final  String message;

/// Create a copy of SyncEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SyncEvent_FailedCopyWith<SyncEvent_Failed> get copyWith => _$SyncEvent_FailedCopyWithImpl<SyncEvent_Failed>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is SyncEvent_Failed&&(identical(other.message, message) || other.message == message));
}


@override
int get hashCode {
    return Object.hash(runtimeType,message);
}

@override
String toString() {
    return 'SyncEvent.failed(message: $message)';
}


}

/// @nodoc
abstract mixin class $SyncEvent_FailedCopyWith<$Res> implements $SyncEventCopyWith<$Res> {
  factory $SyncEvent_FailedCopyWith(SyncEvent_Failed value, $Res Function(SyncEvent_Failed) _then) = _$SyncEvent_FailedCopyWithImpl;
@useResult
$Res call({
 String message
});




}
/// @nodoc
class _$SyncEvent_FailedCopyWithImpl<$Res>
    implements $SyncEvent_FailedCopyWith<$Res> {
  _$SyncEvent_FailedCopyWithImpl(this._self, this._then);

  final SyncEvent_Failed _self;
  final $Res Function(SyncEvent_Failed) _then;

/// Create a copy of SyncEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? message = null,}) {
  return _then(SyncEvent_Failed(
message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
