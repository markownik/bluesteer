// This is a generated file - do not edit.
//
// Generated from bluesteer.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports
// ignore_for_file: unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use sessionSourceDescriptor instead')
const SessionSource$json = {
  '1': 'SessionSource',
  '2': [
    {'1': 'SESSION_SOURCE_UNSPECIFIED', '2': 0},
    {'1': 'SESSION_SOURCE_HOST_SPAWNED', '2': 1},
    {'1': 'SESSION_SOURCE_WRAPPED', '2': 2},
    {'1': 'SESSION_SOURCE_ATTACHED', '2': 3},
    {'1': 'SESSION_SOURCE_DISCOVERED', '2': 4},
  ],
};

/// Descriptor for `SessionSource`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List sessionSourceDescriptor = $convert.base64Decode(
    'Cg1TZXNzaW9uU291cmNlEh4KGlNFU1NJT05fU09VUkNFX1VOU1BFQ0lGSUVEEAASHwobU0VTU0'
    'lPTl9TT1VSQ0VfSE9TVF9TUEFXTkVEEAESGgoWU0VTU0lPTl9TT1VSQ0VfV1JBUFBFRBACEhsK'
    'F1NFU1NJT05fU09VUkNFX0FUVEFDSEVEEAMSHQoZU0VTU0lPTl9TT1VSQ0VfRElTQ09WRVJFRB'
    'AE');

@$core.Deprecated('Use sessionStatusDescriptor instead')
const SessionStatus$json = {
  '1': 'SessionStatus',
  '2': [
    {'1': 'SESSION_STATUS_UNSPECIFIED', '2': 0},
    {'1': 'SESSION_STATUS_BUSY', '2': 1},
    {'1': 'SESSION_STATUS_WAITING_INPUT', '2': 2},
    {'1': 'SESSION_STATUS_WAITING_PERMISSION', '2': 3},
    {'1': 'SESSION_STATUS_IDLE', '2': 4},
    {'1': 'SESSION_STATUS_EXITED', '2': 5},
  ],
};

/// Descriptor for `SessionStatus`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List sessionStatusDescriptor = $convert.base64Decode(
    'Cg1TZXNzaW9uU3RhdHVzEh4KGlNFU1NJT05fU1RBVFVTX1VOU1BFQ0lGSUVEEAASFwoTU0VTU0'
    'lPTl9TVEFUVVNfQlVTWRABEiAKHFNFU1NJT05fU1RBVFVTX1dBSVRJTkdfSU5QVVQQAhIlCiFT'
    'RVNTSU9OX1NUQVRVU19XQUlUSU5HX1BFUk1JU1NJT04QAxIXChNTRVNTSU9OX1NUQVRVU19JRE'
    'xFEAQSGQoVU0VTU0lPTl9TVEFUVVNfRVhJVEVEEAU=');

@$core.Deprecated('Use notificationTypeDescriptor instead')
const NotificationType$json = {
  '1': 'NotificationType',
  '2': [
    {'1': 'NOTIFICATION_TYPE_UNSPECIFIED', '2': 0},
    {'1': 'NOTIFICATION_TYPE_PERMISSION_PROMPT', '2': 1},
    {'1': 'NOTIFICATION_TYPE_IDLE_PROMPT', '2': 2},
    {'1': 'NOTIFICATION_TYPE_TURN_FINISHED', '2': 3},
    {'1': 'NOTIFICATION_TYPE_SESSION_ENDED', '2': 4},
    {'1': 'NOTIFICATION_TYPE_OTHER', '2': 5},
  ],
};

/// Descriptor for `NotificationType`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List notificationTypeDescriptor = $convert.base64Decode(
    'ChBOb3RpZmljYXRpb25UeXBlEiEKHU5PVElGSUNBVElPTl9UWVBFX1VOU1BFQ0lGSUVEEAASJw'
    'ojTk9USUZJQ0FUSU9OX1RZUEVfUEVSTUlTU0lPTl9QUk9NUFQQARIhCh1OT1RJRklDQVRJT05f'
    'VFlQRV9JRExFX1BST01QVBACEiMKH05PVElGSUNBVElPTl9UWVBFX1RVUk5fRklOSVNIRUQQAx'
    'IjCh9OT1RJRklDQVRJT05fVFlQRV9TRVNTSU9OX0VOREVEEAQSGwoXTk9USUZJQ0FUSU9OX1RZ'
    'UEVfT1RIRVIQBQ==');

@$core.Deprecated('Use envelopeDescriptor instead')
const Envelope$json = {
  '1': 'Envelope',
  '2': [
    {
      '1': 'host_hello',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.bluesteer.v1.HostHello',
      '9': 0,
      '10': 'hostHello'
    },
    {
      '1': 'session_list',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.bluesteer.v1.SessionList',
      '9': 0,
      '10': 'sessionList'
    },
    {
      '1': 'session_state',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.bluesteer.v1.SessionState',
      '9': 0,
      '10': 'sessionState'
    },
    {
      '1': 'term_snapshot',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.bluesteer.v1.TermSnapshot',
      '9': 0,
      '10': 'termSnapshot'
    },
    {
      '1': 'term_output',
      '3': 5,
      '4': 1,
      '5': 11,
      '6': '.bluesteer.v1.TermOutput',
      '9': 0,
      '10': 'termOutput'
    },
    {
      '1': 'scrollback',
      '3': 6,
      '4': 1,
      '5': 11,
      '6': '.bluesteer.v1.Scrollback',
      '9': 0,
      '10': 'scrollback'
    },
    {
      '1': 'notification',
      '3': 7,
      '4': 1,
      '5': 11,
      '6': '.bluesteer.v1.Notification',
      '9': 0,
      '10': 'notification'
    },
    {
      '1': 'ack',
      '3': 8,
      '4': 1,
      '5': 11,
      '6': '.bluesteer.v1.Ack',
      '9': 0,
      '10': 'ack'
    },
    {
      '1': 'projects',
      '3': 9,
      '4': 1,
      '5': 11,
      '6': '.bluesteer.v1.Projects',
      '9': 0,
      '10': 'projects'
    },
    {
      '1': 'host_goodbye',
      '3': 10,
      '4': 1,
      '5': 11,
      '6': '.bluesteer.v1.HostGoodbye',
      '9': 0,
      '10': 'hostGoodbye'
    },
    {
      '1': 'list_sessions',
      '3': 20,
      '4': 1,
      '5': 11,
      '6': '.bluesteer.v1.ListSessions',
      '9': 0,
      '10': 'listSessions'
    },
    {
      '1': 'subscribe',
      '3': 21,
      '4': 1,
      '5': 11,
      '6': '.bluesteer.v1.Subscribe',
      '9': 0,
      '10': 'subscribe'
    },
    {
      '1': 'unsubscribe',
      '3': 22,
      '4': 1,
      '5': 11,
      '6': '.bluesteer.v1.Unsubscribe',
      '9': 0,
      '10': 'unsubscribe'
    },
    {
      '1': 'new_session',
      '3': 23,
      '4': 1,
      '5': 11,
      '6': '.bluesteer.v1.NewSession',
      '9': 0,
      '10': 'newSession'
    },
    {
      '1': 'attach_background',
      '3': 24,
      '4': 1,
      '5': 11,
      '6': '.bluesteer.v1.AttachBackground',
      '9': 0,
      '10': 'attachBackground'
    },
    {
      '1': 'term_input',
      '3': 25,
      '4': 1,
      '5': 11,
      '6': '.bluesteer.v1.TermInput',
      '9': 0,
      '10': 'termInput'
    },
    {
      '1': 'resize',
      '3': 26,
      '4': 1,
      '5': 11,
      '6': '.bluesteer.v1.Resize',
      '9': 0,
      '10': 'resize'
    },
    {
      '1': 'fetch_scrollback',
      '3': 27,
      '4': 1,
      '5': 11,
      '6': '.bluesteer.v1.FetchScrollback',
      '9': 0,
      '10': 'fetchScrollback'
    },
    {
      '1': 'stop_session',
      '3': 28,
      '4': 1,
      '5': 11,
      '6': '.bluesteer.v1.StopSession',
      '9': 0,
      '10': 'stopSession'
    },
    {
      '1': 'ping',
      '3': 29,
      '4': 1,
      '5': 11,
      '6': '.bluesteer.v1.Ping',
      '9': 0,
      '10': 'ping'
    },
    {
      '1': 'pong',
      '3': 30,
      '4': 1,
      '5': 11,
      '6': '.bluesteer.v1.Pong',
      '9': 0,
      '10': 'pong'
    },
    {
      '1': 'remote_hello',
      '3': 31,
      '4': 1,
      '5': 11,
      '6': '.bluesteer.v1.RemoteHello',
      '9': 0,
      '10': 'remoteHello'
    },
    {
      '1': 'pair_confirm',
      '3': 32,
      '4': 1,
      '5': 11,
      '6': '.bluesteer.v1.PairConfirm',
      '9': 0,
      '10': 'pairConfirm'
    },
  ],
  '8': [
    {'1': 'body'},
  ],
};

/// Descriptor for `Envelope`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List envelopeDescriptor = $convert.base64Decode(
    'CghFbnZlbG9wZRI4Cgpob3N0X2hlbGxvGAEgASgLMhcuYmx1ZXN0ZWVyLnYxLkhvc3RIZWxsb0'
    'gAUglob3N0SGVsbG8SPgoMc2Vzc2lvbl9saXN0GAIgASgLMhkuYmx1ZXN0ZWVyLnYxLlNlc3Np'
    'b25MaXN0SABSC3Nlc3Npb25MaXN0EkEKDXNlc3Npb25fc3RhdGUYAyABKAsyGi5ibHVlc3RlZX'
    'IudjEuU2Vzc2lvblN0YXRlSABSDHNlc3Npb25TdGF0ZRJBCg10ZXJtX3NuYXBzaG90GAQgASgL'
    'MhouYmx1ZXN0ZWVyLnYxLlRlcm1TbmFwc2hvdEgAUgx0ZXJtU25hcHNob3QSOwoLdGVybV9vdX'
    'RwdXQYBSABKAsyGC5ibHVlc3RlZXIudjEuVGVybU91dHB1dEgAUgp0ZXJtT3V0cHV0EjoKCnNj'
    'cm9sbGJhY2sYBiABKAsyGC5ibHVlc3RlZXIudjEuU2Nyb2xsYmFja0gAUgpzY3JvbGxiYWNrEk'
    'AKDG5vdGlmaWNhdGlvbhgHIAEoCzIaLmJsdWVzdGVlci52MS5Ob3RpZmljYXRpb25IAFIMbm90'
    'aWZpY2F0aW9uEiUKA2FjaxgIIAEoCzIRLmJsdWVzdGVlci52MS5BY2tIAFIDYWNrEjQKCHByb2'
    'plY3RzGAkgASgLMhYuYmx1ZXN0ZWVyLnYxLlByb2plY3RzSABSCHByb2plY3RzEj4KDGhvc3Rf'
    'Z29vZGJ5ZRgKIAEoCzIZLmJsdWVzdGVlci52MS5Ib3N0R29vZGJ5ZUgAUgtob3N0R29vZGJ5ZR'
    'JBCg1saXN0X3Nlc3Npb25zGBQgASgLMhouYmx1ZXN0ZWVyLnYxLkxpc3RTZXNzaW9uc0gAUgxs'
    'aXN0U2Vzc2lvbnMSNwoJc3Vic2NyaWJlGBUgASgLMhcuYmx1ZXN0ZWVyLnYxLlN1YnNjcmliZU'
    'gAUglzdWJzY3JpYmUSPQoLdW5zdWJzY3JpYmUYFiABKAsyGS5ibHVlc3RlZXIudjEuVW5zdWJz'
    'Y3JpYmVIAFILdW5zdWJzY3JpYmUSOwoLbmV3X3Nlc3Npb24YFyABKAsyGC5ibHVlc3RlZXIudj'
    'EuTmV3U2Vzc2lvbkgAUgpuZXdTZXNzaW9uEk0KEWF0dGFjaF9iYWNrZ3JvdW5kGBggASgLMh4u'
    'Ymx1ZXN0ZWVyLnYxLkF0dGFjaEJhY2tncm91bmRIAFIQYXR0YWNoQmFja2dyb3VuZBI4Cgp0ZX'
    'JtX2lucHV0GBkgASgLMhcuYmx1ZXN0ZWVyLnYxLlRlcm1JbnB1dEgAUgl0ZXJtSW5wdXQSLgoG'
    'cmVzaXplGBogASgLMhQuYmx1ZXN0ZWVyLnYxLlJlc2l6ZUgAUgZyZXNpemUSSgoQZmV0Y2hfc2'
    'Nyb2xsYmFjaxgbIAEoCzIdLmJsdWVzdGVlci52MS5GZXRjaFNjcm9sbGJhY2tIAFIPZmV0Y2hT'
    'Y3JvbGxiYWNrEj4KDHN0b3Bfc2Vzc2lvbhgcIAEoCzIZLmJsdWVzdGVlci52MS5TdG9wU2Vzc2'
    'lvbkgAUgtzdG9wU2Vzc2lvbhIoCgRwaW5nGB0gASgLMhIuYmx1ZXN0ZWVyLnYxLlBpbmdIAFIE'
    'cGluZxIoCgRwb25nGB4gASgLMhIuYmx1ZXN0ZWVyLnYxLlBvbmdIAFIEcG9uZxI+CgxyZW1vdG'
    'VfaGVsbG8YHyABKAsyGS5ibHVlc3RlZXIudjEuUmVtb3RlSGVsbG9IAFILcmVtb3RlSGVsbG8S'
    'PgoMcGFpcl9jb25maXJtGCAgASgLMhkuYmx1ZXN0ZWVyLnYxLlBhaXJDb25maXJtSABSC3BhaX'
    'JDb25maXJtQgYKBGJvZHk=');

@$core.Deprecated('Use hostHelloDescriptor instead')
const HostHello$json = {
  '1': 'HostHello',
  '2': [
    {'1': 'protocol_version', '3': 1, '4': 1, '5': 13, '10': 'protocolVersion'},
    {'1': 'host_name', '3': 2, '4': 1, '5': 9, '10': 'hostName'},
    {'1': 'host_version', '3': 3, '4': 1, '5': 9, '10': 'hostVersion'},
    {'1': 'capabilities', '3': 4, '4': 3, '5': 9, '10': 'capabilities'},
  ],
};

/// Descriptor for `HostHello`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List hostHelloDescriptor = $convert.base64Decode(
    'CglIb3N0SGVsbG8SKQoQcHJvdG9jb2xfdmVyc2lvbhgBIAEoDVIPcHJvdG9jb2xWZXJzaW9uEh'
    'sKCWhvc3RfbmFtZRgCIAEoCVIIaG9zdE5hbWUSIQoMaG9zdF92ZXJzaW9uGAMgASgJUgtob3N0'
    'VmVyc2lvbhIiCgxjYXBhYmlsaXRpZXMYBCADKAlSDGNhcGFiaWxpdGllcw==');

@$core.Deprecated('Use sessionStateDescriptor instead')
const SessionState$json = {
  '1': 'SessionState',
  '2': [
    {'1': 'session_id', '3': 1, '4': 1, '5': 9, '10': 'sessionId'},
    {
      '1': 'source',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.bluesteer.v1.SessionSource',
      '10': 'source'
    },
    {'1': 'command', '3': 3, '4': 1, '5': 9, '10': 'command'},
    {'1': 'cwd', '3': 4, '4': 1, '5': 9, '10': 'cwd'},
    {'1': 'title', '3': 5, '4': 1, '5': 9, '10': 'title'},
    {
      '1': 'status',
      '3': 6,
      '4': 1,
      '5': 14,
      '6': '.bluesteer.v1.SessionStatus',
      '10': 'status'
    },
    {'1': 'rows', '3': 7, '4': 1, '5': 13, '10': 'rows'},
    {'1': 'cols', '3': 8, '4': 1, '5': 13, '10': 'cols'},
    {'1': 'exit_code', '3': 9, '4': 1, '5': 5, '10': 'exitCode'},
  ],
};

/// Descriptor for `SessionState`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List sessionStateDescriptor = $convert.base64Decode(
    'CgxTZXNzaW9uU3RhdGUSHQoKc2Vzc2lvbl9pZBgBIAEoCVIJc2Vzc2lvbklkEjMKBnNvdXJjZR'
    'gCIAEoDjIbLmJsdWVzdGVlci52MS5TZXNzaW9uU291cmNlUgZzb3VyY2USGAoHY29tbWFuZBgD'
    'IAEoCVIHY29tbWFuZBIQCgNjd2QYBCABKAlSA2N3ZBIUCgV0aXRsZRgFIAEoCVIFdGl0bGUSMw'
    'oGc3RhdHVzGAYgASgOMhsuYmx1ZXN0ZWVyLnYxLlNlc3Npb25TdGF0dXNSBnN0YXR1cxISCgRy'
    'b3dzGAcgASgNUgRyb3dzEhIKBGNvbHMYCCABKA1SBGNvbHMSGwoJZXhpdF9jb2RlGAkgASgFUg'
    'hleGl0Q29kZQ==');

@$core.Deprecated('Use sessionListDescriptor instead')
const SessionList$json = {
  '1': 'SessionList',
  '2': [
    {
      '1': 'sessions',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.bluesteer.v1.SessionState',
      '10': 'sessions'
    },
  ],
};

/// Descriptor for `SessionList`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List sessionListDescriptor = $convert.base64Decode(
    'CgtTZXNzaW9uTGlzdBI2CghzZXNzaW9ucxgBIAMoCzIaLmJsdWVzdGVlci52MS5TZXNzaW9uU3'
    'RhdGVSCHNlc3Npb25z');

@$core.Deprecated('Use termSnapshotDescriptor instead')
const TermSnapshot$json = {
  '1': 'TermSnapshot',
  '2': [
    {'1': 'session_id', '3': 1, '4': 1, '5': 9, '10': 'sessionId'},
    {'1': 'seq', '3': 2, '4': 1, '5': 4, '10': 'seq'},
    {'1': 'rows', '3': 3, '4': 1, '5': 13, '10': 'rows'},
    {'1': 'cols', '3': 4, '4': 1, '5': 13, '10': 'cols'},
    {'1': 'vt', '3': 5, '4': 1, '5': 12, '10': 'vt'},
    {'1': 'compressed', '3': 6, '4': 1, '5': 8, '10': 'compressed'},
  ],
};

/// Descriptor for `TermSnapshot`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List termSnapshotDescriptor = $convert.base64Decode(
    'CgxUZXJtU25hcHNob3QSHQoKc2Vzc2lvbl9pZBgBIAEoCVIJc2Vzc2lvbklkEhAKA3NlcRgCIA'
    'EoBFIDc2VxEhIKBHJvd3MYAyABKA1SBHJvd3MSEgoEY29scxgEIAEoDVIEY29scxIOCgJ2dBgF'
    'IAEoDFICdnQSHgoKY29tcHJlc3NlZBgGIAEoCFIKY29tcHJlc3NlZA==');

@$core.Deprecated('Use termOutputDescriptor instead')
const TermOutput$json = {
  '1': 'TermOutput',
  '2': [
    {'1': 'session_id', '3': 1, '4': 1, '5': 9, '10': 'sessionId'},
    {'1': 'seq', '3': 2, '4': 1, '5': 4, '10': 'seq'},
    {'1': 'data', '3': 3, '4': 1, '5': 12, '10': 'data'},
    {'1': 'compressed', '3': 4, '4': 1, '5': 8, '10': 'compressed'},
  ],
};

/// Descriptor for `TermOutput`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List termOutputDescriptor = $convert.base64Decode(
    'CgpUZXJtT3V0cHV0Eh0KCnNlc3Npb25faWQYASABKAlSCXNlc3Npb25JZBIQCgNzZXEYAiABKA'
    'RSA3NlcRISCgRkYXRhGAMgASgMUgRkYXRhEh4KCmNvbXByZXNzZWQYBCABKAhSCmNvbXByZXNz'
    'ZWQ=');

@$core.Deprecated('Use scrollbackDescriptor instead')
const Scrollback$json = {
  '1': 'Scrollback',
  '2': [
    {'1': 'session_id', '3': 1, '4': 1, '5': 9, '10': 'sessionId'},
    {'1': 'from_line', '3': 2, '4': 1, '5': 13, '10': 'fromLine'},
    {'1': 'lines', '3': 3, '4': 3, '5': 12, '10': 'lines'},
    {'1': 'total_lines', '3': 4, '4': 1, '5': 13, '10': 'totalLines'},
  ],
};

/// Descriptor for `Scrollback`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List scrollbackDescriptor = $convert.base64Decode(
    'CgpTY3JvbGxiYWNrEh0KCnNlc3Npb25faWQYASABKAlSCXNlc3Npb25JZBIbCglmcm9tX2xpbm'
    'UYAiABKA1SCGZyb21MaW5lEhQKBWxpbmVzGAMgAygMUgVsaW5lcxIfCgt0b3RhbF9saW5lcxgE'
    'IAEoDVIKdG90YWxMaW5lcw==');

@$core.Deprecated('Use notificationDescriptor instead')
const Notification$json = {
  '1': 'Notification',
  '2': [
    {'1': 'session_id', '3': 1, '4': 1, '5': 9, '10': 'sessionId'},
    {
      '1': 'type',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.bluesteer.v1.NotificationType',
      '10': 'type'
    },
    {'1': 'text', '3': 3, '4': 1, '5': 9, '10': 'text'},
  ],
};

/// Descriptor for `Notification`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List notificationDescriptor = $convert.base64Decode(
    'CgxOb3RpZmljYXRpb24SHQoKc2Vzc2lvbl9pZBgBIAEoCVIJc2Vzc2lvbklkEjIKBHR5cGUYAi'
    'ABKA4yHi5ibHVlc3RlZXIudjEuTm90aWZpY2F0aW9uVHlwZVIEdHlwZRISCgR0ZXh0GAMgASgJ'
    'UgR0ZXh0');

@$core.Deprecated('Use ackDescriptor instead')
const Ack$json = {
  '1': 'Ack',
  '2': [
    {'1': 'cmd_id', '3': 1, '4': 1, '5': 4, '10': 'cmdId'},
    {'1': 'ok', '3': 2, '4': 1, '5': 8, '10': 'ok'},
    {'1': 'error', '3': 3, '4': 1, '5': 9, '10': 'error'},
    {'1': 'session_id', '3': 4, '4': 1, '5': 9, '10': 'sessionId'},
  ],
};

/// Descriptor for `Ack`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List ackDescriptor = $convert.base64Decode(
    'CgNBY2sSFQoGY21kX2lkGAEgASgEUgVjbWRJZBIOCgJvaxgCIAEoCFICb2sSFAoFZXJyb3IYAy'
    'ABKAlSBWVycm9yEh0KCnNlc3Npb25faWQYBCABKAlSCXNlc3Npb25JZA==');

@$core.Deprecated('Use projectsDescriptor instead')
const Projects$json = {
  '1': 'Projects',
  '2': [
    {'1': 'recent_cwds', '3': 1, '4': 3, '5': 9, '10': 'recentCwds'},
  ],
};

/// Descriptor for `Projects`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List projectsDescriptor = $convert.base64Decode(
    'CghQcm9qZWN0cxIfCgtyZWNlbnRfY3dkcxgBIAMoCVIKcmVjZW50Q3dkcw==');

@$core.Deprecated('Use hostGoodbyeDescriptor instead')
const HostGoodbye$json = {
  '1': 'HostGoodbye',
  '2': [
    {'1': 'reason', '3': 1, '4': 1, '5': 9, '10': 'reason'},
  ],
};

/// Descriptor for `HostGoodbye`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List hostGoodbyeDescriptor = $convert
    .base64Decode('CgtIb3N0R29vZGJ5ZRIWCgZyZWFzb24YASABKAlSBnJlYXNvbg==');

@$core.Deprecated('Use listSessionsDescriptor instead')
const ListSessions$json = {
  '1': 'ListSessions',
  '2': [
    {'1': 'cmd_id', '3': 1, '4': 1, '5': 4, '10': 'cmdId'},
  ],
};

/// Descriptor for `ListSessions`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listSessionsDescriptor = $convert
    .base64Decode('CgxMaXN0U2Vzc2lvbnMSFQoGY21kX2lkGAEgASgEUgVjbWRJZA==');

@$core.Deprecated('Use subscribeDescriptor instead')
const Subscribe$json = {
  '1': 'Subscribe',
  '2': [
    {'1': 'cmd_id', '3': 1, '4': 1, '5': 4, '10': 'cmdId'},
    {'1': 'session_id', '3': 2, '4': 1, '5': 9, '10': 'sessionId'},
    {'1': 'rows', '3': 3, '4': 1, '5': 13, '10': 'rows'},
    {'1': 'cols', '3': 4, '4': 1, '5': 13, '10': 'cols'},
    {'1': 'scrollback_lines', '3': 5, '4': 1, '5': 13, '10': 'scrollbackLines'},
  ],
};

/// Descriptor for `Subscribe`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List subscribeDescriptor = $convert.base64Decode(
    'CglTdWJzY3JpYmUSFQoGY21kX2lkGAEgASgEUgVjbWRJZBIdCgpzZXNzaW9uX2lkGAIgASgJUg'
    'lzZXNzaW9uSWQSEgoEcm93cxgDIAEoDVIEcm93cxISCgRjb2xzGAQgASgNUgRjb2xzEikKEHNj'
    'cm9sbGJhY2tfbGluZXMYBSABKA1SD3Njcm9sbGJhY2tMaW5lcw==');

@$core.Deprecated('Use unsubscribeDescriptor instead')
const Unsubscribe$json = {
  '1': 'Unsubscribe',
  '2': [
    {'1': 'cmd_id', '3': 1, '4': 1, '5': 4, '10': 'cmdId'},
    {'1': 'session_id', '3': 2, '4': 1, '5': 9, '10': 'sessionId'},
  ],
};

/// Descriptor for `Unsubscribe`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List unsubscribeDescriptor = $convert.base64Decode(
    'CgtVbnN1YnNjcmliZRIVCgZjbWRfaWQYASABKARSBWNtZElkEh0KCnNlc3Npb25faWQYAiABKA'
    'lSCXNlc3Npb25JZA==');

@$core.Deprecated('Use newSessionDescriptor instead')
const NewSession$json = {
  '1': 'NewSession',
  '2': [
    {'1': 'cmd_id', '3': 1, '4': 1, '5': 4, '10': 'cmdId'},
    {'1': 'preset', '3': 2, '4': 1, '5': 9, '10': 'preset'},
    {'1': 'cwd', '3': 3, '4': 1, '5': 9, '10': 'cwd'},
    {'1': 'args', '3': 4, '4': 3, '5': 9, '10': 'args'},
    {'1': 'rows', '3': 5, '4': 1, '5': 13, '10': 'rows'},
    {'1': 'cols', '3': 6, '4': 1, '5': 13, '10': 'cols'},
    {'1': 'low_bandwidth', '3': 7, '4': 1, '5': 8, '10': 'lowBandwidth'},
  ],
};

/// Descriptor for `NewSession`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List newSessionDescriptor = $convert.base64Decode(
    'CgpOZXdTZXNzaW9uEhUKBmNtZF9pZBgBIAEoBFIFY21kSWQSFgoGcHJlc2V0GAIgASgJUgZwcm'
    'VzZXQSEAoDY3dkGAMgASgJUgNjd2QSEgoEYXJncxgEIAMoCVIEYXJncxISCgRyb3dzGAUgASgN'
    'UgRyb3dzEhIKBGNvbHMYBiABKA1SBGNvbHMSIwoNbG93X2JhbmR3aWR0aBgHIAEoCFIMbG93Qm'
    'FuZHdpZHRo');

@$core.Deprecated('Use attachBackgroundDescriptor instead')
const AttachBackground$json = {
  '1': 'AttachBackground',
  '2': [
    {'1': 'cmd_id', '3': 1, '4': 1, '5': 4, '10': 'cmdId'},
    {'1': 'claude_session_id', '3': 2, '4': 1, '5': 9, '10': 'claudeSessionId'},
    {'1': 'rows', '3': 3, '4': 1, '5': 13, '10': 'rows'},
    {'1': 'cols', '3': 4, '4': 1, '5': 13, '10': 'cols'},
  ],
};

/// Descriptor for `AttachBackground`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List attachBackgroundDescriptor = $convert.base64Decode(
    'ChBBdHRhY2hCYWNrZ3JvdW5kEhUKBmNtZF9pZBgBIAEoBFIFY21kSWQSKgoRY2xhdWRlX3Nlc3'
    'Npb25faWQYAiABKAlSD2NsYXVkZVNlc3Npb25JZBISCgRyb3dzGAMgASgNUgRyb3dzEhIKBGNv'
    'bHMYBCABKA1SBGNvbHM=');

@$core.Deprecated('Use termInputDescriptor instead')
const TermInput$json = {
  '1': 'TermInput',
  '2': [
    {'1': 'session_id', '3': 1, '4': 1, '5': 9, '10': 'sessionId'},
    {'1': 'data', '3': 2, '4': 1, '5': 12, '10': 'data'},
  ],
};

/// Descriptor for `TermInput`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List termInputDescriptor = $convert.base64Decode(
    'CglUZXJtSW5wdXQSHQoKc2Vzc2lvbl9pZBgBIAEoCVIJc2Vzc2lvbklkEhIKBGRhdGEYAiABKA'
    'xSBGRhdGE=');

@$core.Deprecated('Use resizeDescriptor instead')
const Resize$json = {
  '1': 'Resize',
  '2': [
    {'1': 'cmd_id', '3': 1, '4': 1, '5': 4, '10': 'cmdId'},
    {'1': 'session_id', '3': 2, '4': 1, '5': 9, '10': 'sessionId'},
    {'1': 'rows', '3': 3, '4': 1, '5': 13, '10': 'rows'},
    {'1': 'cols', '3': 4, '4': 1, '5': 13, '10': 'cols'},
  ],
};

/// Descriptor for `Resize`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List resizeDescriptor = $convert.base64Decode(
    'CgZSZXNpemUSFQoGY21kX2lkGAEgASgEUgVjbWRJZBIdCgpzZXNzaW9uX2lkGAIgASgJUglzZX'
    'NzaW9uSWQSEgoEcm93cxgDIAEoDVIEcm93cxISCgRjb2xzGAQgASgNUgRjb2xz');

@$core.Deprecated('Use fetchScrollbackDescriptor instead')
const FetchScrollback$json = {
  '1': 'FetchScrollback',
  '2': [
    {'1': 'cmd_id', '3': 1, '4': 1, '5': 4, '10': 'cmdId'},
    {'1': 'session_id', '3': 2, '4': 1, '5': 9, '10': 'sessionId'},
    {'1': 'from_line', '3': 3, '4': 1, '5': 13, '10': 'fromLine'},
    {'1': 'count', '3': 4, '4': 1, '5': 13, '10': 'count'},
  ],
};

/// Descriptor for `FetchScrollback`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List fetchScrollbackDescriptor = $convert.base64Decode(
    'Cg9GZXRjaFNjcm9sbGJhY2sSFQoGY21kX2lkGAEgASgEUgVjbWRJZBIdCgpzZXNzaW9uX2lkGA'
    'IgASgJUglzZXNzaW9uSWQSGwoJZnJvbV9saW5lGAMgASgNUghmcm9tTGluZRIUCgVjb3VudBgE'
    'IAEoDVIFY291bnQ=');

@$core.Deprecated('Use stopSessionDescriptor instead')
const StopSession$json = {
  '1': 'StopSession',
  '2': [
    {'1': 'cmd_id', '3': 1, '4': 1, '5': 4, '10': 'cmdId'},
    {'1': 'session_id', '3': 2, '4': 1, '5': 9, '10': 'sessionId'},
    {'1': 'signal', '3': 3, '4': 1, '5': 5, '10': 'signal'},
  ],
};

/// Descriptor for `StopSession`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List stopSessionDescriptor = $convert.base64Decode(
    'CgtTdG9wU2Vzc2lvbhIVCgZjbWRfaWQYASABKARSBWNtZElkEh0KCnNlc3Npb25faWQYAiABKA'
    'lSCXNlc3Npb25JZBIWCgZzaWduYWwYAyABKAVSBnNpZ25hbA==');

@$core.Deprecated('Use pingDescriptor instead')
const Ping$json = {
  '1': 'Ping',
  '2': [
    {'1': 'nonce', '3': 1, '4': 1, '5': 4, '10': 'nonce'},
  ],
};

/// Descriptor for `Ping`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List pingDescriptor =
    $convert.base64Decode('CgRQaW5nEhQKBW5vbmNlGAEgASgEUgVub25jZQ==');

@$core.Deprecated('Use pongDescriptor instead')
const Pong$json = {
  '1': 'Pong',
  '2': [
    {'1': 'nonce', '3': 1, '4': 1, '5': 4, '10': 'nonce'},
  ],
};

/// Descriptor for `Pong`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List pongDescriptor =
    $convert.base64Decode('CgRQb25nEhQKBW5vbmNlGAEgASgEUgVub25jZQ==');

@$core.Deprecated('Use remoteHelloDescriptor instead')
const RemoteHello$json = {
  '1': 'RemoteHello',
  '2': [
    {'1': 'protocol_version', '3': 1, '4': 1, '5': 13, '10': 'protocolVersion'},
    {'1': 'device_name', '3': 2, '4': 1, '5': 9, '10': 'deviceName'},
    {'1': 'app_version', '3': 3, '4': 1, '5': 9, '10': 'appVersion'},
  ],
};

/// Descriptor for `RemoteHello`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List remoteHelloDescriptor = $convert.base64Decode(
    'CgtSZW1vdGVIZWxsbxIpChBwcm90b2NvbF92ZXJzaW9uGAEgASgNUg9wcm90b2NvbFZlcnNpb2'
    '4SHwoLZGV2aWNlX25hbWUYAiABKAlSCmRldmljZU5hbWUSHwoLYXBwX3ZlcnNpb24YAyABKAlS'
    'CmFwcFZlcnNpb24=');

@$core.Deprecated('Use pairConfirmDescriptor instead')
const PairConfirm$json = {
  '1': 'PairConfirm',
  '2': [
    {'1': 'cmd_id', '3': 1, '4': 1, '5': 4, '10': 'cmdId'},
  ],
};

/// Descriptor for `PairConfirm`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List pairConfirmDescriptor =
    $convert.base64Decode('CgtQYWlyQ29uZmlybRIVCgZjbWRfaWQYASABKARSBWNtZElk');
