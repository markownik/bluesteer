// This is a generated file - do not edit.
//
// Generated from bluesteer.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

class SessionSource extends $pb.ProtobufEnum {
  static const SessionSource SESSION_SOURCE_UNSPECIFIED =
      SessionSource._(0, _omitEnumNames ? '' : 'SESSION_SOURCE_UNSPECIFIED');
  static const SessionSource SESSION_SOURCE_HOST_SPAWNED =
      SessionSource._(1, _omitEnumNames ? '' : 'SESSION_SOURCE_HOST_SPAWNED');
  static const SessionSource SESSION_SOURCE_WRAPPED =
      SessionSource._(2, _omitEnumNames ? '' : 'SESSION_SOURCE_WRAPPED');
  static const SessionSource SESSION_SOURCE_ATTACHED =
      SessionSource._(3, _omitEnumNames ? '' : 'SESSION_SOURCE_ATTACHED');
  static const SessionSource SESSION_SOURCE_DISCOVERED =
      SessionSource._(4, _omitEnumNames ? '' : 'SESSION_SOURCE_DISCOVERED');

  static const $core.List<SessionSource> values = <SessionSource>[
    SESSION_SOURCE_UNSPECIFIED,
    SESSION_SOURCE_HOST_SPAWNED,
    SESSION_SOURCE_WRAPPED,
    SESSION_SOURCE_ATTACHED,
    SESSION_SOURCE_DISCOVERED,
  ];

  static final $core.List<SessionSource?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 4);
  static SessionSource? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const SessionSource._(super.value, super.name);
}

class SessionStatus extends $pb.ProtobufEnum {
  static const SessionStatus SESSION_STATUS_UNSPECIFIED =
      SessionStatus._(0, _omitEnumNames ? '' : 'SESSION_STATUS_UNSPECIFIED');
  static const SessionStatus SESSION_STATUS_BUSY =
      SessionStatus._(1, _omitEnumNames ? '' : 'SESSION_STATUS_BUSY');
  static const SessionStatus SESSION_STATUS_WAITING_INPUT =
      SessionStatus._(2, _omitEnumNames ? '' : 'SESSION_STATUS_WAITING_INPUT');
  static const SessionStatus SESSION_STATUS_WAITING_PERMISSION =
      SessionStatus._(
          3, _omitEnumNames ? '' : 'SESSION_STATUS_WAITING_PERMISSION');
  static const SessionStatus SESSION_STATUS_IDLE =
      SessionStatus._(4, _omitEnumNames ? '' : 'SESSION_STATUS_IDLE');
  static const SessionStatus SESSION_STATUS_EXITED =
      SessionStatus._(5, _omitEnumNames ? '' : 'SESSION_STATUS_EXITED');

  static const $core.List<SessionStatus> values = <SessionStatus>[
    SESSION_STATUS_UNSPECIFIED,
    SESSION_STATUS_BUSY,
    SESSION_STATUS_WAITING_INPUT,
    SESSION_STATUS_WAITING_PERMISSION,
    SESSION_STATUS_IDLE,
    SESSION_STATUS_EXITED,
  ];

  static final $core.List<SessionStatus?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 5);
  static SessionStatus? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const SessionStatus._(super.value, super.name);
}

class NotificationType extends $pb.ProtobufEnum {
  static const NotificationType NOTIFICATION_TYPE_UNSPECIFIED =
      NotificationType._(
          0, _omitEnumNames ? '' : 'NOTIFICATION_TYPE_UNSPECIFIED');
  static const NotificationType NOTIFICATION_TYPE_PERMISSION_PROMPT =
      NotificationType._(
          1, _omitEnumNames ? '' : 'NOTIFICATION_TYPE_PERMISSION_PROMPT');
  static const NotificationType NOTIFICATION_TYPE_IDLE_PROMPT =
      NotificationType._(
          2, _omitEnumNames ? '' : 'NOTIFICATION_TYPE_IDLE_PROMPT');
  static const NotificationType NOTIFICATION_TYPE_TURN_FINISHED =
      NotificationType._(
          3, _omitEnumNames ? '' : 'NOTIFICATION_TYPE_TURN_FINISHED');
  static const NotificationType NOTIFICATION_TYPE_SESSION_ENDED =
      NotificationType._(
          4, _omitEnumNames ? '' : 'NOTIFICATION_TYPE_SESSION_ENDED');
  static const NotificationType NOTIFICATION_TYPE_OTHER =
      NotificationType._(5, _omitEnumNames ? '' : 'NOTIFICATION_TYPE_OTHER');

  static const $core.List<NotificationType> values = <NotificationType>[
    NOTIFICATION_TYPE_UNSPECIFIED,
    NOTIFICATION_TYPE_PERMISSION_PROMPT,
    NOTIFICATION_TYPE_IDLE_PROMPT,
    NOTIFICATION_TYPE_TURN_FINISHED,
    NOTIFICATION_TYPE_SESSION_ENDED,
    NOTIFICATION_TYPE_OTHER,
  ];

  static final $core.List<NotificationType?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 5);
  static NotificationType? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const NotificationType._(super.value, super.name);
}

const $core.bool _omitEnumNames =
    $core.bool.fromEnvironment('protobuf.omit_enum_names');
