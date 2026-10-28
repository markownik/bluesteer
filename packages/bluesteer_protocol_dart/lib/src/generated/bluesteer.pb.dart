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

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

import 'bluesteer.pbenum.dart';

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

export 'bluesteer.pbenum.dart';

enum Envelope_Body {
  hostHello,
  sessionList,
  sessionState,
  termSnapshot,
  termOutput,
  scrollback,
  notification,
  ack,
  projects,
  listSessions,
  subscribe,
  unsubscribe,
  newSession,
  attachBackground,
  termInput,
  resize,
  fetchScrollback,
  stopSession,
  ping,
  pong,
  remoteHello,
  pairConfirm,
  notSet
}

class Envelope extends $pb.GeneratedMessage {
  factory Envelope({
    HostHello? hostHello,
    SessionList? sessionList,
    SessionState? sessionState,
    TermSnapshot? termSnapshot,
    TermOutput? termOutput,
    Scrollback? scrollback,
    Notification? notification,
    Ack? ack,
    Projects? projects,
    ListSessions? listSessions,
    Subscribe? subscribe,
    Unsubscribe? unsubscribe,
    NewSession? newSession,
    AttachBackground? attachBackground,
    TermInput? termInput,
    Resize? resize,
    FetchScrollback? fetchScrollback,
    StopSession? stopSession,
    Ping? ping,
    Pong? pong,
    RemoteHello? remoteHello,
    PairConfirm? pairConfirm,
  }) {
    final result = Envelope._();
    if (hostHello != null) result.hostHello = hostHello;
    if (sessionList != null) result.sessionList = sessionList;
    if (sessionState != null) result.sessionState = sessionState;
    if (termSnapshot != null) result.termSnapshot = termSnapshot;
    if (termOutput != null) result.termOutput = termOutput;
    if (scrollback != null) result.scrollback = scrollback;
    if (notification != null) result.notification = notification;
    if (ack != null) result.ack = ack;
    if (projects != null) result.projects = projects;
    if (listSessions != null) result.listSessions = listSessions;
    if (subscribe != null) result.subscribe = subscribe;
    if (unsubscribe != null) result.unsubscribe = unsubscribe;
    if (newSession != null) result.newSession = newSession;
    if (attachBackground != null) result.attachBackground = attachBackground;
    if (termInput != null) result.termInput = termInput;
    if (resize != null) result.resize = resize;
    if (fetchScrollback != null) result.fetchScrollback = fetchScrollback;
    if (stopSession != null) result.stopSession = stopSession;
    if (ping != null) result.ping = ping;
    if (pong != null) result.pong = pong;
    if (remoteHello != null) result.remoteHello = remoteHello;
    if (pairConfirm != null) result.pairConfirm = pairConfirm;
    return result;
  }

  Envelope._();

  factory Envelope.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Envelope()..mergeFromBuffer(data, registry);
  factory Envelope.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Envelope()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, Envelope_Body> _Envelope_BodyByTag = {
    1: Envelope_Body.hostHello,
    2: Envelope_Body.sessionList,
    3: Envelope_Body.sessionState,
    4: Envelope_Body.termSnapshot,
    5: Envelope_Body.termOutput,
    6: Envelope_Body.scrollback,
    7: Envelope_Body.notification,
    8: Envelope_Body.ack,
    9: Envelope_Body.projects,
    20: Envelope_Body.listSessions,
    21: Envelope_Body.subscribe,
    22: Envelope_Body.unsubscribe,
    23: Envelope_Body.newSession,
    24: Envelope_Body.attachBackground,
    25: Envelope_Body.termInput,
    26: Envelope_Body.resize,
    27: Envelope_Body.fetchScrollback,
    28: Envelope_Body.stopSession,
    29: Envelope_Body.ping,
    30: Envelope_Body.pong,
    31: Envelope_Body.remoteHello,
    32: Envelope_Body.pairConfirm,
    0: Envelope_Body.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Envelope',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'bluesteer.v1'),
      createEmptyInstance: Envelope.$_createMessage)
    ..oo(0, [
      1,
      2,
      3,
      4,
      5,
      6,
      7,
      8,
      9,
      20,
      21,
      22,
      23,
      24,
      25,
      26,
      27,
      28,
      29,
      30,
      31,
      32
    ])
    ..aOM<HostHello>(1, _omitFieldNames ? '' : 'hostHello',
        subBuilder: HostHello.$_createMessage)
    ..aOM<SessionList>(2, _omitFieldNames ? '' : 'sessionList',
        subBuilder: SessionList.$_createMessage)
    ..aOM<SessionState>(3, _omitFieldNames ? '' : 'sessionState',
        subBuilder: SessionState.$_createMessage)
    ..aOM<TermSnapshot>(4, _omitFieldNames ? '' : 'termSnapshot',
        subBuilder: TermSnapshot.$_createMessage)
    ..aOM<TermOutput>(5, _omitFieldNames ? '' : 'termOutput',
        subBuilder: TermOutput.$_createMessage)
    ..aOM<Scrollback>(6, _omitFieldNames ? '' : 'scrollback',
        subBuilder: Scrollback.$_createMessage)
    ..aOM<Notification>(7, _omitFieldNames ? '' : 'notification',
        subBuilder: Notification.$_createMessage)
    ..aOM<Ack>(8, _omitFieldNames ? '' : 'ack', subBuilder: Ack.$_createMessage)
    ..aOM<Projects>(9, _omitFieldNames ? '' : 'projects',
        subBuilder: Projects.$_createMessage)
    ..aOM<ListSessions>(20, _omitFieldNames ? '' : 'listSessions',
        subBuilder: ListSessions.$_createMessage)
    ..aOM<Subscribe>(21, _omitFieldNames ? '' : 'subscribe',
        subBuilder: Subscribe.$_createMessage)
    ..aOM<Unsubscribe>(22, _omitFieldNames ? '' : 'unsubscribe',
        subBuilder: Unsubscribe.$_createMessage)
    ..aOM<NewSession>(23, _omitFieldNames ? '' : 'newSession',
        subBuilder: NewSession.$_createMessage)
    ..aOM<AttachBackground>(24, _omitFieldNames ? '' : 'attachBackground',
        subBuilder: AttachBackground.$_createMessage)
    ..aOM<TermInput>(25, _omitFieldNames ? '' : 'termInput',
        subBuilder: TermInput.$_createMessage)
    ..aOM<Resize>(26, _omitFieldNames ? '' : 'resize',
        subBuilder: Resize.$_createMessage)
    ..aOM<FetchScrollback>(27, _omitFieldNames ? '' : 'fetchScrollback',
        subBuilder: FetchScrollback.$_createMessage)
    ..aOM<StopSession>(28, _omitFieldNames ? '' : 'stopSession',
        subBuilder: StopSession.$_createMessage)
    ..aOM<Ping>(29, _omitFieldNames ? '' : 'ping',
        subBuilder: Ping.$_createMessage)
    ..aOM<Pong>(30, _omitFieldNames ? '' : 'pong',
        subBuilder: Pong.$_createMessage)
    ..aOM<RemoteHello>(31, _omitFieldNames ? '' : 'remoteHello',
        subBuilder: RemoteHello.$_createMessage)
    ..aOM<PairConfirm>(32, _omitFieldNames ? '' : 'pairConfirm',
        subBuilder: PairConfirm.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Envelope clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Envelope copyWith(void Function(Envelope) updates) =>
      super.copyWith((message) => updates(message as Envelope)) as Envelope;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Envelope() / Envelope.new instead')
  static Envelope create() => Envelope._();
  static $pb.GeneratedMessage $_createMessage() => Envelope._();
  @$core.override
  Envelope createEmptyInstance() => Envelope._();
  @$core.pragma('dart2js:noInline')
  static Envelope getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Envelope>(Envelope.$_createMessage);
  static Envelope? _defaultInstance;

  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  @$pb.TagNumber(5)
  @$pb.TagNumber(6)
  @$pb.TagNumber(7)
  @$pb.TagNumber(8)
  @$pb.TagNumber(9)
  @$pb.TagNumber(20)
  @$pb.TagNumber(21)
  @$pb.TagNumber(22)
  @$pb.TagNumber(23)
  @$pb.TagNumber(24)
  @$pb.TagNumber(25)
  @$pb.TagNumber(26)
  @$pb.TagNumber(27)
  @$pb.TagNumber(28)
  @$pb.TagNumber(29)
  @$pb.TagNumber(30)
  @$pb.TagNumber(31)
  @$pb.TagNumber(32)
  Envelope_Body whichBody() => _Envelope_BodyByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  @$pb.TagNumber(5)
  @$pb.TagNumber(6)
  @$pb.TagNumber(7)
  @$pb.TagNumber(8)
  @$pb.TagNumber(9)
  @$pb.TagNumber(20)
  @$pb.TagNumber(21)
  @$pb.TagNumber(22)
  @$pb.TagNumber(23)
  @$pb.TagNumber(24)
  @$pb.TagNumber(25)
  @$pb.TagNumber(26)
  @$pb.TagNumber(27)
  @$pb.TagNumber(28)
  @$pb.TagNumber(29)
  @$pb.TagNumber(30)
  @$pb.TagNumber(31)
  @$pb.TagNumber(32)
  void clearBody() => $_clearField($_whichOneof(0));

  /// Host → Remote
  @$pb.TagNumber(1)
  HostHello get hostHello => $_getN(0);
  @$pb.TagNumber(1)
  set hostHello(HostHello value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasHostHello() => $_has(0);
  @$pb.TagNumber(1)
  void clearHostHello() => $_clearField(1);
  @$pb.TagNumber(1)
  HostHello ensureHostHello() => $_ensure(0);

  @$pb.TagNumber(2)
  SessionList get sessionList => $_getN(1);
  @$pb.TagNumber(2)
  set sessionList(SessionList value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasSessionList() => $_has(1);
  @$pb.TagNumber(2)
  void clearSessionList() => $_clearField(2);
  @$pb.TagNumber(2)
  SessionList ensureSessionList() => $_ensure(1);

  @$pb.TagNumber(3)
  SessionState get sessionState => $_getN(2);
  @$pb.TagNumber(3)
  set sessionState(SessionState value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasSessionState() => $_has(2);
  @$pb.TagNumber(3)
  void clearSessionState() => $_clearField(3);
  @$pb.TagNumber(3)
  SessionState ensureSessionState() => $_ensure(2);

  @$pb.TagNumber(4)
  TermSnapshot get termSnapshot => $_getN(3);
  @$pb.TagNumber(4)
  set termSnapshot(TermSnapshot value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasTermSnapshot() => $_has(3);
  @$pb.TagNumber(4)
  void clearTermSnapshot() => $_clearField(4);
  @$pb.TagNumber(4)
  TermSnapshot ensureTermSnapshot() => $_ensure(3);

  @$pb.TagNumber(5)
  TermOutput get termOutput => $_getN(4);
  @$pb.TagNumber(5)
  set termOutput(TermOutput value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasTermOutput() => $_has(4);
  @$pb.TagNumber(5)
  void clearTermOutput() => $_clearField(5);
  @$pb.TagNumber(5)
  TermOutput ensureTermOutput() => $_ensure(4);

  @$pb.TagNumber(6)
  Scrollback get scrollback => $_getN(5);
  @$pb.TagNumber(6)
  set scrollback(Scrollback value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasScrollback() => $_has(5);
  @$pb.TagNumber(6)
  void clearScrollback() => $_clearField(6);
  @$pb.TagNumber(6)
  Scrollback ensureScrollback() => $_ensure(5);

  @$pb.TagNumber(7)
  Notification get notification => $_getN(6);
  @$pb.TagNumber(7)
  set notification(Notification value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasNotification() => $_has(6);
  @$pb.TagNumber(7)
  void clearNotification() => $_clearField(7);
  @$pb.TagNumber(7)
  Notification ensureNotification() => $_ensure(6);

  @$pb.TagNumber(8)
  Ack get ack => $_getN(7);
  @$pb.TagNumber(8)
  set ack(Ack value) => $_setField(8, value);
  @$pb.TagNumber(8)
  $core.bool hasAck() => $_has(7);
  @$pb.TagNumber(8)
  void clearAck() => $_clearField(8);
  @$pb.TagNumber(8)
  Ack ensureAck() => $_ensure(7);

  @$pb.TagNumber(9)
  Projects get projects => $_getN(8);
  @$pb.TagNumber(9)
  set projects(Projects value) => $_setField(9, value);
  @$pb.TagNumber(9)
  $core.bool hasProjects() => $_has(8);
  @$pb.TagNumber(9)
  void clearProjects() => $_clearField(9);
  @$pb.TagNumber(9)
  Projects ensureProjects() => $_ensure(8);

  /// Remote → Host
  @$pb.TagNumber(20)
  ListSessions get listSessions => $_getN(9);
  @$pb.TagNumber(20)
  set listSessions(ListSessions value) => $_setField(20, value);
  @$pb.TagNumber(20)
  $core.bool hasListSessions() => $_has(9);
  @$pb.TagNumber(20)
  void clearListSessions() => $_clearField(20);
  @$pb.TagNumber(20)
  ListSessions ensureListSessions() => $_ensure(9);

  @$pb.TagNumber(21)
  Subscribe get subscribe => $_getN(10);
  @$pb.TagNumber(21)
  set subscribe(Subscribe value) => $_setField(21, value);
  @$pb.TagNumber(21)
  $core.bool hasSubscribe() => $_has(10);
  @$pb.TagNumber(21)
  void clearSubscribe() => $_clearField(21);
  @$pb.TagNumber(21)
  Subscribe ensureSubscribe() => $_ensure(10);

  @$pb.TagNumber(22)
  Unsubscribe get unsubscribe => $_getN(11);
  @$pb.TagNumber(22)
  set unsubscribe(Unsubscribe value) => $_setField(22, value);
  @$pb.TagNumber(22)
  $core.bool hasUnsubscribe() => $_has(11);
  @$pb.TagNumber(22)
  void clearUnsubscribe() => $_clearField(22);
  @$pb.TagNumber(22)
  Unsubscribe ensureUnsubscribe() => $_ensure(11);

  @$pb.TagNumber(23)
  NewSession get newSession => $_getN(12);
  @$pb.TagNumber(23)
  set newSession(NewSession value) => $_setField(23, value);
  @$pb.TagNumber(23)
  $core.bool hasNewSession() => $_has(12);
  @$pb.TagNumber(23)
  void clearNewSession() => $_clearField(23);
  @$pb.TagNumber(23)
  NewSession ensureNewSession() => $_ensure(12);

  @$pb.TagNumber(24)
  AttachBackground get attachBackground => $_getN(13);
  @$pb.TagNumber(24)
  set attachBackground(AttachBackground value) => $_setField(24, value);
  @$pb.TagNumber(24)
  $core.bool hasAttachBackground() => $_has(13);
  @$pb.TagNumber(24)
  void clearAttachBackground() => $_clearField(24);
  @$pb.TagNumber(24)
  AttachBackground ensureAttachBackground() => $_ensure(13);

  @$pb.TagNumber(25)
  TermInput get termInput => $_getN(14);
  @$pb.TagNumber(25)
  set termInput(TermInput value) => $_setField(25, value);
  @$pb.TagNumber(25)
  $core.bool hasTermInput() => $_has(14);
  @$pb.TagNumber(25)
  void clearTermInput() => $_clearField(25);
  @$pb.TagNumber(25)
  TermInput ensureTermInput() => $_ensure(14);

  @$pb.TagNumber(26)
  Resize get resize => $_getN(15);
  @$pb.TagNumber(26)
  set resize(Resize value) => $_setField(26, value);
  @$pb.TagNumber(26)
  $core.bool hasResize() => $_has(15);
  @$pb.TagNumber(26)
  void clearResize() => $_clearField(26);
  @$pb.TagNumber(26)
  Resize ensureResize() => $_ensure(15);

  @$pb.TagNumber(27)
  FetchScrollback get fetchScrollback => $_getN(16);
  @$pb.TagNumber(27)
  set fetchScrollback(FetchScrollback value) => $_setField(27, value);
  @$pb.TagNumber(27)
  $core.bool hasFetchScrollback() => $_has(16);
  @$pb.TagNumber(27)
  void clearFetchScrollback() => $_clearField(27);
  @$pb.TagNumber(27)
  FetchScrollback ensureFetchScrollback() => $_ensure(16);

  @$pb.TagNumber(28)
  StopSession get stopSession => $_getN(17);
  @$pb.TagNumber(28)
  set stopSession(StopSession value) => $_setField(28, value);
  @$pb.TagNumber(28)
  $core.bool hasStopSession() => $_has(17);
  @$pb.TagNumber(28)
  void clearStopSession() => $_clearField(28);
  @$pb.TagNumber(28)
  StopSession ensureStopSession() => $_ensure(17);

  @$pb.TagNumber(29)
  Ping get ping => $_getN(18);
  @$pb.TagNumber(29)
  set ping(Ping value) => $_setField(29, value);
  @$pb.TagNumber(29)
  $core.bool hasPing() => $_has(18);
  @$pb.TagNumber(29)
  void clearPing() => $_clearField(29);
  @$pb.TagNumber(29)
  Ping ensurePing() => $_ensure(18);

  @$pb.TagNumber(30)
  Pong get pong => $_getN(19);
  @$pb.TagNumber(30)
  set pong(Pong value) => $_setField(30, value);
  @$pb.TagNumber(30)
  $core.bool hasPong() => $_has(19);
  @$pb.TagNumber(30)
  void clearPong() => $_clearField(30);
  @$pb.TagNumber(30)
  Pong ensurePong() => $_ensure(19);

  @$pb.TagNumber(31)
  RemoteHello get remoteHello => $_getN(20);
  @$pb.TagNumber(31)
  set remoteHello(RemoteHello value) => $_setField(31, value);
  @$pb.TagNumber(31)
  $core.bool hasRemoteHello() => $_has(20);
  @$pb.TagNumber(31)
  void clearRemoteHello() => $_clearField(31);
  @$pb.TagNumber(31)
  RemoteHello ensureRemoteHello() => $_ensure(20);

  @$pb.TagNumber(32)
  PairConfirm get pairConfirm => $_getN(21);
  @$pb.TagNumber(32)
  set pairConfirm(PairConfirm value) => $_setField(32, value);
  @$pb.TagNumber(32)
  $core.bool hasPairConfirm() => $_has(21);
  @$pb.TagNumber(32)
  void clearPairConfirm() => $_clearField(32);
  @$pb.TagNumber(32)
  PairConfirm ensurePairConfirm() => $_ensure(21);
}

class HostHello extends $pb.GeneratedMessage {
  factory HostHello({
    $core.int? protocolVersion,
    $core.String? hostName,
    $core.String? hostVersion,
    $core.Iterable<$core.String>? capabilities,
  }) {
    final result = HostHello._();
    if (protocolVersion != null) result.protocolVersion = protocolVersion;
    if (hostName != null) result.hostName = hostName;
    if (hostVersion != null) result.hostVersion = hostVersion;
    if (capabilities != null) result.capabilities.addAll(capabilities);
    return result;
  }

  HostHello._();

  factory HostHello.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      HostHello()..mergeFromBuffer(data, registry);
  factory HostHello.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      HostHello()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'HostHello',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'bluesteer.v1'),
      createEmptyInstance: HostHello.$_createMessage)
    ..aI(1, _omitFieldNames ? '' : 'protocolVersion',
        fieldType: $pb.PbFieldType.OU3)
    ..aOS(2, _omitFieldNames ? '' : 'hostName')
    ..aOS(3, _omitFieldNames ? '' : 'hostVersion')
    ..pPS(4, _omitFieldNames ? '' : 'capabilities')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  HostHello clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  HostHello copyWith(void Function(HostHello) updates) =>
      super.copyWith((message) => updates(message as HostHello)) as HostHello;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use HostHello() / HostHello.new instead')
  static HostHello create() => HostHello._();
  static $pb.GeneratedMessage $_createMessage() => HostHello._();
  @$core.override
  HostHello createEmptyInstance() => HostHello._();
  @$core.pragma('dart2js:noInline')
  static HostHello getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<HostHello>(HostHello.$_createMessage);
  static HostHello? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get protocolVersion => $_getIZ(0);
  @$pb.TagNumber(1)
  set protocolVersion($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasProtocolVersion() => $_has(0);
  @$pb.TagNumber(1)
  void clearProtocolVersion() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get hostName => $_getSZ(1);
  @$pb.TagNumber(2)
  set hostName($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasHostName() => $_has(1);
  @$pb.TagNumber(2)
  void clearHostName() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get hostVersion => $_getSZ(2);
  @$pb.TagNumber(3)
  set hostVersion($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasHostVersion() => $_has(2);
  @$pb.TagNumber(3)
  void clearHostVersion() => $_clearField(3);

  @$pb.TagNumber(4)
  $pb.PbList<$core.String> get capabilities => $_getList(3);
}

class SessionState extends $pb.GeneratedMessage {
  factory SessionState({
    $core.String? sessionId,
    SessionSource? source,
    $core.String? command,
    $core.String? cwd,
    $core.String? title,
    SessionStatus? status,
    $core.int? rows,
    $core.int? cols,
    $core.int? exitCode,
  }) {
    final result = SessionState._();
    if (sessionId != null) result.sessionId = sessionId;
    if (source != null) result.source = source;
    if (command != null) result.command = command;
    if (cwd != null) result.cwd = cwd;
    if (title != null) result.title = title;
    if (status != null) result.status = status;
    if (rows != null) result.rows = rows;
    if (cols != null) result.cols = cols;
    if (exitCode != null) result.exitCode = exitCode;
    return result;
  }

  SessionState._();

  factory SessionState.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SessionState()..mergeFromBuffer(data, registry);
  factory SessionState.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SessionState()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SessionState',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'bluesteer.v1'),
      createEmptyInstance: SessionState.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'sessionId')
    ..aE<SessionSource>(2, _omitFieldNames ? '' : 'source',
        enumValues: SessionSource.values)
    ..aOS(3, _omitFieldNames ? '' : 'command')
    ..aOS(4, _omitFieldNames ? '' : 'cwd')
    ..aOS(5, _omitFieldNames ? '' : 'title')
    ..aE<SessionStatus>(6, _omitFieldNames ? '' : 'status',
        enumValues: SessionStatus.values)
    ..aI(7, _omitFieldNames ? '' : 'rows', fieldType: $pb.PbFieldType.OU3)
    ..aI(8, _omitFieldNames ? '' : 'cols', fieldType: $pb.PbFieldType.OU3)
    ..aI(9, _omitFieldNames ? '' : 'exitCode')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SessionState clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SessionState copyWith(void Function(SessionState) updates) =>
      super.copyWith((message) => updates(message as SessionState))
          as SessionState;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use SessionState() / SessionState.new instead')
  static SessionState create() => SessionState._();
  static $pb.GeneratedMessage $_createMessage() => SessionState._();
  @$core.override
  SessionState createEmptyInstance() => SessionState._();
  @$core.pragma('dart2js:noInline')
  static SessionState getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SessionState>(
          SessionState.$_createMessage);
  static SessionState? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get sessionId => $_getSZ(0);
  @$pb.TagNumber(1)
  set sessionId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSessionId() => $_has(0);
  @$pb.TagNumber(1)
  void clearSessionId() => $_clearField(1);

  @$pb.TagNumber(2)
  SessionSource get source => $_getN(1);
  @$pb.TagNumber(2)
  set source(SessionSource value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasSource() => $_has(1);
  @$pb.TagNumber(2)
  void clearSource() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get command => $_getSZ(2);
  @$pb.TagNumber(3)
  set command($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasCommand() => $_has(2);
  @$pb.TagNumber(3)
  void clearCommand() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get cwd => $_getSZ(3);
  @$pb.TagNumber(4)
  set cwd($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasCwd() => $_has(3);
  @$pb.TagNumber(4)
  void clearCwd() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get title => $_getSZ(4);
  @$pb.TagNumber(5)
  set title($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasTitle() => $_has(4);
  @$pb.TagNumber(5)
  void clearTitle() => $_clearField(5);

  @$pb.TagNumber(6)
  SessionStatus get status => $_getN(5);
  @$pb.TagNumber(6)
  set status(SessionStatus value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasStatus() => $_has(5);
  @$pb.TagNumber(6)
  void clearStatus() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.int get rows => $_getIZ(6);
  @$pb.TagNumber(7)
  set rows($core.int value) => $_setUnsignedInt32(6, value);
  @$pb.TagNumber(7)
  $core.bool hasRows() => $_has(6);
  @$pb.TagNumber(7)
  void clearRows() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.int get cols => $_getIZ(7);
  @$pb.TagNumber(8)
  set cols($core.int value) => $_setUnsignedInt32(7, value);
  @$pb.TagNumber(8)
  $core.bool hasCols() => $_has(7);
  @$pb.TagNumber(8)
  void clearCols() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.int get exitCode => $_getIZ(8);
  @$pb.TagNumber(9)
  set exitCode($core.int value) => $_setSignedInt32(8, value);
  @$pb.TagNumber(9)
  $core.bool hasExitCode() => $_has(8);
  @$pb.TagNumber(9)
  void clearExitCode() => $_clearField(9);
}

class SessionList extends $pb.GeneratedMessage {
  factory SessionList({
    $core.Iterable<SessionState>? sessions,
  }) {
    final result = SessionList._();
    if (sessions != null) result.sessions.addAll(sessions);
    return result;
  }

  SessionList._();

  factory SessionList.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SessionList()..mergeFromBuffer(data, registry);
  factory SessionList.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SessionList()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SessionList',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'bluesteer.v1'),
      createEmptyInstance: SessionList.$_createMessage)
    ..pPM<SessionState>(1, _omitFieldNames ? '' : 'sessions',
        subBuilder: SessionState.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SessionList clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SessionList copyWith(void Function(SessionList) updates) =>
      super.copyWith((message) => updates(message as SessionList))
          as SessionList;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use SessionList() / SessionList.new instead')
  static SessionList create() => SessionList._();
  static $pb.GeneratedMessage $_createMessage() => SessionList._();
  @$core.override
  SessionList createEmptyInstance() => SessionList._();
  @$core.pragma('dart2js:noInline')
  static SessionList getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SessionList>(
          SessionList.$_createMessage);
  static SessionList? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<SessionState> get sessions => $_getList(0);
}

/// Full screen state as VT sequences the remote feeds to its emulator verbatim.
class TermSnapshot extends $pb.GeneratedMessage {
  factory TermSnapshot({
    $core.String? sessionId,
    $fixnum.Int64? seq,
    $core.int? rows,
    $core.int? cols,
    $core.List<$core.int>? vt,
    $core.bool? compressed,
  }) {
    final result = TermSnapshot._();
    if (sessionId != null) result.sessionId = sessionId;
    if (seq != null) result.seq = seq;
    if (rows != null) result.rows = rows;
    if (cols != null) result.cols = cols;
    if (vt != null) result.vt = vt;
    if (compressed != null) result.compressed = compressed;
    return result;
  }

  TermSnapshot._();

  factory TermSnapshot.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TermSnapshot()..mergeFromBuffer(data, registry);
  factory TermSnapshot.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TermSnapshot()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TermSnapshot',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'bluesteer.v1'),
      createEmptyInstance: TermSnapshot.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'sessionId')
    ..a<$fixnum.Int64>(2, _omitFieldNames ? '' : 'seq', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aI(3, _omitFieldNames ? '' : 'rows', fieldType: $pb.PbFieldType.OU3)
    ..aI(4, _omitFieldNames ? '' : 'cols', fieldType: $pb.PbFieldType.OU3)
    ..a<$core.List<$core.int>>(
        5, _omitFieldNames ? '' : 'vt', $pb.PbFieldType.OY)
    ..aOB(6, _omitFieldNames ? '' : 'compressed')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TermSnapshot clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TermSnapshot copyWith(void Function(TermSnapshot) updates) =>
      super.copyWith((message) => updates(message as TermSnapshot))
          as TermSnapshot;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use TermSnapshot() / TermSnapshot.new instead')
  static TermSnapshot create() => TermSnapshot._();
  static $pb.GeneratedMessage $_createMessage() => TermSnapshot._();
  @$core.override
  TermSnapshot createEmptyInstance() => TermSnapshot._();
  @$core.pragma('dart2js:noInline')
  static TermSnapshot getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<TermSnapshot>(
          TermSnapshot.$_createMessage);
  static TermSnapshot? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get sessionId => $_getSZ(0);
  @$pb.TagNumber(1)
  set sessionId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSessionId() => $_has(0);
  @$pb.TagNumber(1)
  void clearSessionId() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get seq => $_getI64(1);
  @$pb.TagNumber(2)
  set seq($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSeq() => $_has(1);
  @$pb.TagNumber(2)
  void clearSeq() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get rows => $_getIZ(2);
  @$pb.TagNumber(3)
  set rows($core.int value) => $_setUnsignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasRows() => $_has(2);
  @$pb.TagNumber(3)
  void clearRows() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get cols => $_getIZ(3);
  @$pb.TagNumber(4)
  set cols($core.int value) => $_setUnsignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasCols() => $_has(3);
  @$pb.TagNumber(4)
  void clearCols() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.List<$core.int> get vt => $_getN(4);
  @$pb.TagNumber(5)
  set vt($core.List<$core.int> value) => $_setBytes(4, value);
  @$pb.TagNumber(5)
  $core.bool hasVt() => $_has(4);
  @$pb.TagNumber(5)
  void clearVt() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.bool get compressed => $_getBF(5);
  @$pb.TagNumber(6)
  set compressed($core.bool value) => $_setBool(5, value);
  @$pb.TagNumber(6)
  $core.bool hasCompressed() => $_has(5);
  @$pb.TagNumber(6)
  void clearCompressed() => $_clearField(6);
}

/// Raw PTY output following the last snapshot or output message.
class TermOutput extends $pb.GeneratedMessage {
  factory TermOutput({
    $core.String? sessionId,
    $fixnum.Int64? seq,
    $core.List<$core.int>? data,
    $core.bool? compressed,
  }) {
    final result = TermOutput._();
    if (sessionId != null) result.sessionId = sessionId;
    if (seq != null) result.seq = seq;
    if (data != null) result.data = data;
    if (compressed != null) result.compressed = compressed;
    return result;
  }

  TermOutput._();

  factory TermOutput.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TermOutput()..mergeFromBuffer(data, registry);
  factory TermOutput.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TermOutput()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TermOutput',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'bluesteer.v1'),
      createEmptyInstance: TermOutput.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'sessionId')
    ..a<$fixnum.Int64>(2, _omitFieldNames ? '' : 'seq', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$core.List<$core.int>>(
        3, _omitFieldNames ? '' : 'data', $pb.PbFieldType.OY)
    ..aOB(4, _omitFieldNames ? '' : 'compressed')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TermOutput clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TermOutput copyWith(void Function(TermOutput) updates) =>
      super.copyWith((message) => updates(message as TermOutput)) as TermOutput;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use TermOutput() / TermOutput.new instead')
  static TermOutput create() => TermOutput._();
  static $pb.GeneratedMessage $_createMessage() => TermOutput._();
  @$core.override
  TermOutput createEmptyInstance() => TermOutput._();
  @$core.pragma('dart2js:noInline')
  static TermOutput getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<TermOutput>(TermOutput.$_createMessage);
  static TermOutput? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get sessionId => $_getSZ(0);
  @$pb.TagNumber(1)
  set sessionId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSessionId() => $_has(0);
  @$pb.TagNumber(1)
  void clearSessionId() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get seq => $_getI64(1);
  @$pb.TagNumber(2)
  set seq($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSeq() => $_has(1);
  @$pb.TagNumber(2)
  void clearSeq() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.List<$core.int> get data => $_getN(2);
  @$pb.TagNumber(3)
  set data($core.List<$core.int> value) => $_setBytes(2, value);
  @$pb.TagNumber(3)
  $core.bool hasData() => $_has(2);
  @$pb.TagNumber(3)
  void clearData() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.bool get compressed => $_getBF(3);
  @$pb.TagNumber(4)
  set compressed($core.bool value) => $_setBool(3, value);
  @$pb.TagNumber(4)
  $core.bool hasCompressed() => $_has(3);
  @$pb.TagNumber(4)
  void clearCompressed() => $_clearField(4);
}

class Scrollback extends $pb.GeneratedMessage {
  factory Scrollback({
    $core.String? sessionId,
    $core.int? fromLine,
    $core.Iterable<$core.List<$core.int>>? lines,
    $core.int? totalLines,
  }) {
    final result = Scrollback._();
    if (sessionId != null) result.sessionId = sessionId;
    if (fromLine != null) result.fromLine = fromLine;
    if (lines != null) result.lines.addAll(lines);
    if (totalLines != null) result.totalLines = totalLines;
    return result;
  }

  Scrollback._();

  factory Scrollback.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Scrollback()..mergeFromBuffer(data, registry);
  factory Scrollback.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Scrollback()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Scrollback',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'bluesteer.v1'),
      createEmptyInstance: Scrollback.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'sessionId')
    ..aI(2, _omitFieldNames ? '' : 'fromLine', fieldType: $pb.PbFieldType.OU3)
    ..p<$core.List<$core.int>>(
        3, _omitFieldNames ? '' : 'lines', $pb.PbFieldType.PY)
    ..aI(4, _omitFieldNames ? '' : 'totalLines', fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Scrollback clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Scrollback copyWith(void Function(Scrollback) updates) =>
      super.copyWith((message) => updates(message as Scrollback)) as Scrollback;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Scrollback() / Scrollback.new instead')
  static Scrollback create() => Scrollback._();
  static $pb.GeneratedMessage $_createMessage() => Scrollback._();
  @$core.override
  Scrollback createEmptyInstance() => Scrollback._();
  @$core.pragma('dart2js:noInline')
  static Scrollback getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Scrollback>(Scrollback.$_createMessage);
  static Scrollback? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get sessionId => $_getSZ(0);
  @$pb.TagNumber(1)
  set sessionId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSessionId() => $_has(0);
  @$pb.TagNumber(1)
  void clearSessionId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get fromLine => $_getIZ(1);
  @$pb.TagNumber(2)
  set fromLine($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasFromLine() => $_has(1);
  @$pb.TagNumber(2)
  void clearFromLine() => $_clearField(2);

  @$pb.TagNumber(3)
  $pb.PbList<$core.List<$core.int>> get lines => $_getList(2);

  @$pb.TagNumber(4)
  $core.int get totalLines => $_getIZ(3);
  @$pb.TagNumber(4)
  set totalLines($core.int value) => $_setUnsignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasTotalLines() => $_has(3);
  @$pb.TagNumber(4)
  void clearTotalLines() => $_clearField(4);
}

class Notification extends $pb.GeneratedMessage {
  factory Notification({
    $core.String? sessionId,
    NotificationType? type,
    $core.String? text,
  }) {
    final result = Notification._();
    if (sessionId != null) result.sessionId = sessionId;
    if (type != null) result.type = type;
    if (text != null) result.text = text;
    return result;
  }

  Notification._();

  factory Notification.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Notification()..mergeFromBuffer(data, registry);
  factory Notification.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Notification()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Notification',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'bluesteer.v1'),
      createEmptyInstance: Notification.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'sessionId')
    ..aE<NotificationType>(2, _omitFieldNames ? '' : 'type',
        enumValues: NotificationType.values)
    ..aOS(3, _omitFieldNames ? '' : 'text')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Notification clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Notification copyWith(void Function(Notification) updates) =>
      super.copyWith((message) => updates(message as Notification))
          as Notification;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Notification() / Notification.new instead')
  static Notification create() => Notification._();
  static $pb.GeneratedMessage $_createMessage() => Notification._();
  @$core.override
  Notification createEmptyInstance() => Notification._();
  @$core.pragma('dart2js:noInline')
  static Notification getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Notification>(
          Notification.$_createMessage);
  static Notification? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get sessionId => $_getSZ(0);
  @$pb.TagNumber(1)
  set sessionId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSessionId() => $_has(0);
  @$pb.TagNumber(1)
  void clearSessionId() => $_clearField(1);

  @$pb.TagNumber(2)
  NotificationType get type => $_getN(1);
  @$pb.TagNumber(2)
  set type(NotificationType value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasType() => $_has(1);
  @$pb.TagNumber(2)
  void clearType() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get text => $_getSZ(2);
  @$pb.TagNumber(3)
  set text($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasText() => $_has(2);
  @$pb.TagNumber(3)
  void clearText() => $_clearField(3);
}

class Ack extends $pb.GeneratedMessage {
  factory Ack({
    $fixnum.Int64? cmdId,
    $core.bool? ok,
    $core.String? error,
    $core.String? sessionId,
  }) {
    final result = Ack._();
    if (cmdId != null) result.cmdId = cmdId;
    if (ok != null) result.ok = ok;
    if (error != null) result.error = error;
    if (sessionId != null) result.sessionId = sessionId;
    return result;
  }

  Ack._();

  factory Ack.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Ack()..mergeFromBuffer(data, registry);
  factory Ack.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Ack()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Ack',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'bluesteer.v1'),
      createEmptyInstance: Ack.$_createMessage)
    ..a<$fixnum.Int64>(1, _omitFieldNames ? '' : 'cmdId', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aOB(2, _omitFieldNames ? '' : 'ok')
    ..aOS(3, _omitFieldNames ? '' : 'error')
    ..aOS(4, _omitFieldNames ? '' : 'sessionId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Ack clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Ack copyWith(void Function(Ack) updates) =>
      super.copyWith((message) => updates(message as Ack)) as Ack;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Ack() / Ack.new instead')
  static Ack create() => Ack._();
  static $pb.GeneratedMessage $_createMessage() => Ack._();
  @$core.override
  Ack createEmptyInstance() => Ack._();
  @$core.pragma('dart2js:noInline')
  static Ack getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Ack>(Ack.$_createMessage);
  static Ack? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get cmdId => $_getI64(0);
  @$pb.TagNumber(1)
  set cmdId($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasCmdId() => $_has(0);
  @$pb.TagNumber(1)
  void clearCmdId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.bool get ok => $_getBF(1);
  @$pb.TagNumber(2)
  set ok($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasOk() => $_has(1);
  @$pb.TagNumber(2)
  void clearOk() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get error => $_getSZ(2);
  @$pb.TagNumber(3)
  set error($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasError() => $_has(2);
  @$pb.TagNumber(3)
  void clearError() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get sessionId => $_getSZ(3);
  @$pb.TagNumber(4)
  set sessionId($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasSessionId() => $_has(3);
  @$pb.TagNumber(4)
  void clearSessionId() => $_clearField(4);
}

class Projects extends $pb.GeneratedMessage {
  factory Projects({
    $core.Iterable<$core.String>? recentCwds,
  }) {
    final result = Projects._();
    if (recentCwds != null) result.recentCwds.addAll(recentCwds);
    return result;
  }

  Projects._();

  factory Projects.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Projects()..mergeFromBuffer(data, registry);
  factory Projects.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Projects()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Projects',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'bluesteer.v1'),
      createEmptyInstance: Projects.$_createMessage)
    ..pPS(1, _omitFieldNames ? '' : 'recentCwds')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Projects clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Projects copyWith(void Function(Projects) updates) =>
      super.copyWith((message) => updates(message as Projects)) as Projects;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Projects() / Projects.new instead')
  static Projects create() => Projects._();
  static $pb.GeneratedMessage $_createMessage() => Projects._();
  @$core.override
  Projects createEmptyInstance() => Projects._();
  @$core.pragma('dart2js:noInline')
  static Projects getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Projects>(Projects.$_createMessage);
  static Projects? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<$core.String> get recentCwds => $_getList(0);
}

class ListSessions extends $pb.GeneratedMessage {
  factory ListSessions({
    $fixnum.Int64? cmdId,
  }) {
    final result = ListSessions._();
    if (cmdId != null) result.cmdId = cmdId;
    return result;
  }

  ListSessions._();

  factory ListSessions.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListSessions()..mergeFromBuffer(data, registry);
  factory ListSessions.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListSessions()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListSessions',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'bluesteer.v1'),
      createEmptyInstance: ListSessions.$_createMessage)
    ..a<$fixnum.Int64>(1, _omitFieldNames ? '' : 'cmdId', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListSessions clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListSessions copyWith(void Function(ListSessions) updates) =>
      super.copyWith((message) => updates(message as ListSessions))
          as ListSessions;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ListSessions() / ListSessions.new instead')
  static ListSessions create() => ListSessions._();
  static $pb.GeneratedMessage $_createMessage() => ListSessions._();
  @$core.override
  ListSessions createEmptyInstance() => ListSessions._();
  @$core.pragma('dart2js:noInline')
  static ListSessions getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ListSessions>(
          ListSessions.$_createMessage);
  static ListSessions? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get cmdId => $_getI64(0);
  @$pb.TagNumber(1)
  set cmdId($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasCmdId() => $_has(0);
  @$pb.TagNumber(1)
  void clearCmdId() => $_clearField(1);
}

class Subscribe extends $pb.GeneratedMessage {
  factory Subscribe({
    $fixnum.Int64? cmdId,
    $core.String? sessionId,
    $core.int? rows,
    $core.int? cols,
    $core.int? scrollbackLines,
  }) {
    final result = Subscribe._();
    if (cmdId != null) result.cmdId = cmdId;
    if (sessionId != null) result.sessionId = sessionId;
    if (rows != null) result.rows = rows;
    if (cols != null) result.cols = cols;
    if (scrollbackLines != null) result.scrollbackLines = scrollbackLines;
    return result;
  }

  Subscribe._();

  factory Subscribe.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Subscribe()..mergeFromBuffer(data, registry);
  factory Subscribe.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Subscribe()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Subscribe',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'bluesteer.v1'),
      createEmptyInstance: Subscribe.$_createMessage)
    ..a<$fixnum.Int64>(1, _omitFieldNames ? '' : 'cmdId', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aOS(2, _omitFieldNames ? '' : 'sessionId')
    ..aI(3, _omitFieldNames ? '' : 'rows', fieldType: $pb.PbFieldType.OU3)
    ..aI(4, _omitFieldNames ? '' : 'cols', fieldType: $pb.PbFieldType.OU3)
    ..aI(5, _omitFieldNames ? '' : 'scrollbackLines',
        fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Subscribe clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Subscribe copyWith(void Function(Subscribe) updates) =>
      super.copyWith((message) => updates(message as Subscribe)) as Subscribe;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Subscribe() / Subscribe.new instead')
  static Subscribe create() => Subscribe._();
  static $pb.GeneratedMessage $_createMessage() => Subscribe._();
  @$core.override
  Subscribe createEmptyInstance() => Subscribe._();
  @$core.pragma('dart2js:noInline')
  static Subscribe getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Subscribe>(Subscribe.$_createMessage);
  static Subscribe? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get cmdId => $_getI64(0);
  @$pb.TagNumber(1)
  set cmdId($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasCmdId() => $_has(0);
  @$pb.TagNumber(1)
  void clearCmdId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get sessionId => $_getSZ(1);
  @$pb.TagNumber(2)
  set sessionId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSessionId() => $_has(1);
  @$pb.TagNumber(2)
  void clearSessionId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get rows => $_getIZ(2);
  @$pb.TagNumber(3)
  set rows($core.int value) => $_setUnsignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasRows() => $_has(2);
  @$pb.TagNumber(3)
  void clearRows() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get cols => $_getIZ(3);
  @$pb.TagNumber(4)
  set cols($core.int value) => $_setUnsignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasCols() => $_has(3);
  @$pb.TagNumber(4)
  void clearCols() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get scrollbackLines => $_getIZ(4);
  @$pb.TagNumber(5)
  set scrollbackLines($core.int value) => $_setUnsignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasScrollbackLines() => $_has(4);
  @$pb.TagNumber(5)
  void clearScrollbackLines() => $_clearField(5);
}

class Unsubscribe extends $pb.GeneratedMessage {
  factory Unsubscribe({
    $fixnum.Int64? cmdId,
    $core.String? sessionId,
  }) {
    final result = Unsubscribe._();
    if (cmdId != null) result.cmdId = cmdId;
    if (sessionId != null) result.sessionId = sessionId;
    return result;
  }

  Unsubscribe._();

  factory Unsubscribe.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Unsubscribe()..mergeFromBuffer(data, registry);
  factory Unsubscribe.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Unsubscribe()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Unsubscribe',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'bluesteer.v1'),
      createEmptyInstance: Unsubscribe.$_createMessage)
    ..a<$fixnum.Int64>(1, _omitFieldNames ? '' : 'cmdId', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aOS(2, _omitFieldNames ? '' : 'sessionId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Unsubscribe clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Unsubscribe copyWith(void Function(Unsubscribe) updates) =>
      super.copyWith((message) => updates(message as Unsubscribe))
          as Unsubscribe;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Unsubscribe() / Unsubscribe.new instead')
  static Unsubscribe create() => Unsubscribe._();
  static $pb.GeneratedMessage $_createMessage() => Unsubscribe._();
  @$core.override
  Unsubscribe createEmptyInstance() => Unsubscribe._();
  @$core.pragma('dart2js:noInline')
  static Unsubscribe getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Unsubscribe>(
          Unsubscribe.$_createMessage);
  static Unsubscribe? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get cmdId => $_getI64(0);
  @$pb.TagNumber(1)
  set cmdId($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasCmdId() => $_has(0);
  @$pb.TagNumber(1)
  void clearCmdId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get sessionId => $_getSZ(1);
  @$pb.TagNumber(2)
  set sessionId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSessionId() => $_has(1);
  @$pb.TagNumber(2)
  void clearSessionId() => $_clearField(2);
}

class NewSession extends $pb.GeneratedMessage {
  factory NewSession({
    $fixnum.Int64? cmdId,
    $core.String? preset,
    $core.String? cwd,
    $core.Iterable<$core.String>? args,
    $core.int? rows,
    $core.int? cols,
    $core.bool? lowBandwidth,
  }) {
    final result = NewSession._();
    if (cmdId != null) result.cmdId = cmdId;
    if (preset != null) result.preset = preset;
    if (cwd != null) result.cwd = cwd;
    if (args != null) result.args.addAll(args);
    if (rows != null) result.rows = rows;
    if (cols != null) result.cols = cols;
    if (lowBandwidth != null) result.lowBandwidth = lowBandwidth;
    return result;
  }

  NewSession._();

  factory NewSession.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      NewSession()..mergeFromBuffer(data, registry);
  factory NewSession.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      NewSession()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'NewSession',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'bluesteer.v1'),
      createEmptyInstance: NewSession.$_createMessage)
    ..a<$fixnum.Int64>(1, _omitFieldNames ? '' : 'cmdId', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aOS(2, _omitFieldNames ? '' : 'preset')
    ..aOS(3, _omitFieldNames ? '' : 'cwd')
    ..pPS(4, _omitFieldNames ? '' : 'args')
    ..aI(5, _omitFieldNames ? '' : 'rows', fieldType: $pb.PbFieldType.OU3)
    ..aI(6, _omitFieldNames ? '' : 'cols', fieldType: $pb.PbFieldType.OU3)
    ..aOB(7, _omitFieldNames ? '' : 'lowBandwidth')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  NewSession clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  NewSession copyWith(void Function(NewSession) updates) =>
      super.copyWith((message) => updates(message as NewSession)) as NewSession;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use NewSession() / NewSession.new instead')
  static NewSession create() => NewSession._();
  static $pb.GeneratedMessage $_createMessage() => NewSession._();
  @$core.override
  NewSession createEmptyInstance() => NewSession._();
  @$core.pragma('dart2js:noInline')
  static NewSession getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<NewSession>(NewSession.$_createMessage);
  static NewSession? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get cmdId => $_getI64(0);
  @$pb.TagNumber(1)
  set cmdId($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasCmdId() => $_has(0);
  @$pb.TagNumber(1)
  void clearCmdId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get preset => $_getSZ(1);
  @$pb.TagNumber(2)
  set preset($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasPreset() => $_has(1);
  @$pb.TagNumber(2)
  void clearPreset() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get cwd => $_getSZ(2);
  @$pb.TagNumber(3)
  set cwd($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasCwd() => $_has(2);
  @$pb.TagNumber(3)
  void clearCwd() => $_clearField(3);

  @$pb.TagNumber(4)
  $pb.PbList<$core.String> get args => $_getList(3);

  @$pb.TagNumber(5)
  $core.int get rows => $_getIZ(4);
  @$pb.TagNumber(5)
  set rows($core.int value) => $_setUnsignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasRows() => $_has(4);
  @$pb.TagNumber(5)
  void clearRows() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get cols => $_getIZ(5);
  @$pb.TagNumber(6)
  set cols($core.int value) => $_setUnsignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasCols() => $_has(5);
  @$pb.TagNumber(6)
  void clearCols() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.bool get lowBandwidth => $_getBF(6);
  @$pb.TagNumber(7)
  set lowBandwidth($core.bool value) => $_setBool(6, value);
  @$pb.TagNumber(7)
  $core.bool hasLowBandwidth() => $_has(6);
  @$pb.TagNumber(7)
  void clearLowBandwidth() => $_clearField(7);
}

class AttachBackground extends $pb.GeneratedMessage {
  factory AttachBackground({
    $fixnum.Int64? cmdId,
    $core.String? claudeSessionId,
    $core.int? rows,
    $core.int? cols,
  }) {
    final result = AttachBackground._();
    if (cmdId != null) result.cmdId = cmdId;
    if (claudeSessionId != null) result.claudeSessionId = claudeSessionId;
    if (rows != null) result.rows = rows;
    if (cols != null) result.cols = cols;
    return result;
  }

  AttachBackground._();

  factory AttachBackground.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      AttachBackground()..mergeFromBuffer(data, registry);
  factory AttachBackground.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      AttachBackground()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AttachBackground',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'bluesteer.v1'),
      createEmptyInstance: AttachBackground.$_createMessage)
    ..a<$fixnum.Int64>(1, _omitFieldNames ? '' : 'cmdId', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aOS(2, _omitFieldNames ? '' : 'claudeSessionId')
    ..aI(3, _omitFieldNames ? '' : 'rows', fieldType: $pb.PbFieldType.OU3)
    ..aI(4, _omitFieldNames ? '' : 'cols', fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AttachBackground clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AttachBackground copyWith(void Function(AttachBackground) updates) =>
      super.copyWith((message) => updates(message as AttachBackground))
          as AttachBackground;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use AttachBackground() / AttachBackground.new instead')
  static AttachBackground create() => AttachBackground._();
  static $pb.GeneratedMessage $_createMessage() => AttachBackground._();
  @$core.override
  AttachBackground createEmptyInstance() => AttachBackground._();
  @$core.pragma('dart2js:noInline')
  static AttachBackground getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<AttachBackground>(
          AttachBackground.$_createMessage);
  static AttachBackground? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get cmdId => $_getI64(0);
  @$pb.TagNumber(1)
  set cmdId($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasCmdId() => $_has(0);
  @$pb.TagNumber(1)
  void clearCmdId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get claudeSessionId => $_getSZ(1);
  @$pb.TagNumber(2)
  set claudeSessionId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasClaudeSessionId() => $_has(1);
  @$pb.TagNumber(2)
  void clearClaudeSessionId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get rows => $_getIZ(2);
  @$pb.TagNumber(3)
  set rows($core.int value) => $_setUnsignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasRows() => $_has(2);
  @$pb.TagNumber(3)
  void clearRows() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get cols => $_getIZ(3);
  @$pb.TagNumber(4)
  set cols($core.int value) => $_setUnsignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasCols() => $_has(3);
  @$pb.TagNumber(4)
  void clearCols() => $_clearField(4);
}

class TermInput extends $pb.GeneratedMessage {
  factory TermInput({
    $core.String? sessionId,
    $core.List<$core.int>? data,
  }) {
    final result = TermInput._();
    if (sessionId != null) result.sessionId = sessionId;
    if (data != null) result.data = data;
    return result;
  }

  TermInput._();

  factory TermInput.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TermInput()..mergeFromBuffer(data, registry);
  factory TermInput.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TermInput()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TermInput',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'bluesteer.v1'),
      createEmptyInstance: TermInput.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'sessionId')
    ..a<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'data', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TermInput clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TermInput copyWith(void Function(TermInput) updates) =>
      super.copyWith((message) => updates(message as TermInput)) as TermInput;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use TermInput() / TermInput.new instead')
  static TermInput create() => TermInput._();
  static $pb.GeneratedMessage $_createMessage() => TermInput._();
  @$core.override
  TermInput createEmptyInstance() => TermInput._();
  @$core.pragma('dart2js:noInline')
  static TermInput getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<TermInput>(TermInput.$_createMessage);
  static TermInput? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get sessionId => $_getSZ(0);
  @$pb.TagNumber(1)
  set sessionId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSessionId() => $_has(0);
  @$pb.TagNumber(1)
  void clearSessionId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get data => $_getN(1);
  @$pb.TagNumber(2)
  set data($core.List<$core.int> value) => $_setBytes(1, value);
  @$pb.TagNumber(2)
  $core.bool hasData() => $_has(1);
  @$pb.TagNumber(2)
  void clearData() => $_clearField(2);
}

class Resize extends $pb.GeneratedMessage {
  factory Resize({
    $fixnum.Int64? cmdId,
    $core.String? sessionId,
    $core.int? rows,
    $core.int? cols,
  }) {
    final result = Resize._();
    if (cmdId != null) result.cmdId = cmdId;
    if (sessionId != null) result.sessionId = sessionId;
    if (rows != null) result.rows = rows;
    if (cols != null) result.cols = cols;
    return result;
  }

  Resize._();

  factory Resize.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Resize()..mergeFromBuffer(data, registry);
  factory Resize.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Resize()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Resize',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'bluesteer.v1'),
      createEmptyInstance: Resize.$_createMessage)
    ..a<$fixnum.Int64>(1, _omitFieldNames ? '' : 'cmdId', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aOS(2, _omitFieldNames ? '' : 'sessionId')
    ..aI(3, _omitFieldNames ? '' : 'rows', fieldType: $pb.PbFieldType.OU3)
    ..aI(4, _omitFieldNames ? '' : 'cols', fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Resize clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Resize copyWith(void Function(Resize) updates) =>
      super.copyWith((message) => updates(message as Resize)) as Resize;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Resize() / Resize.new instead')
  static Resize create() => Resize._();
  static $pb.GeneratedMessage $_createMessage() => Resize._();
  @$core.override
  Resize createEmptyInstance() => Resize._();
  @$core.pragma('dart2js:noInline')
  static Resize getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Resize>(Resize.$_createMessage);
  static Resize? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get cmdId => $_getI64(0);
  @$pb.TagNumber(1)
  set cmdId($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasCmdId() => $_has(0);
  @$pb.TagNumber(1)
  void clearCmdId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get sessionId => $_getSZ(1);
  @$pb.TagNumber(2)
  set sessionId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSessionId() => $_has(1);
  @$pb.TagNumber(2)
  void clearSessionId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get rows => $_getIZ(2);
  @$pb.TagNumber(3)
  set rows($core.int value) => $_setUnsignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasRows() => $_has(2);
  @$pb.TagNumber(3)
  void clearRows() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get cols => $_getIZ(3);
  @$pb.TagNumber(4)
  set cols($core.int value) => $_setUnsignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasCols() => $_has(3);
  @$pb.TagNumber(4)
  void clearCols() => $_clearField(4);
}

class FetchScrollback extends $pb.GeneratedMessage {
  factory FetchScrollback({
    $fixnum.Int64? cmdId,
    $core.String? sessionId,
    $core.int? fromLine,
    $core.int? count,
  }) {
    final result = FetchScrollback._();
    if (cmdId != null) result.cmdId = cmdId;
    if (sessionId != null) result.sessionId = sessionId;
    if (fromLine != null) result.fromLine = fromLine;
    if (count != null) result.count = count;
    return result;
  }

  FetchScrollback._();

  factory FetchScrollback.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      FetchScrollback()..mergeFromBuffer(data, registry);
  factory FetchScrollback.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      FetchScrollback()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'FetchScrollback',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'bluesteer.v1'),
      createEmptyInstance: FetchScrollback.$_createMessage)
    ..a<$fixnum.Int64>(1, _omitFieldNames ? '' : 'cmdId', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aOS(2, _omitFieldNames ? '' : 'sessionId')
    ..aI(3, _omitFieldNames ? '' : 'fromLine', fieldType: $pb.PbFieldType.OU3)
    ..aI(4, _omitFieldNames ? '' : 'count', fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FetchScrollback clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FetchScrollback copyWith(void Function(FetchScrollback) updates) =>
      super.copyWith((message) => updates(message as FetchScrollback))
          as FetchScrollback;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use FetchScrollback() / FetchScrollback.new instead')
  static FetchScrollback create() => FetchScrollback._();
  static $pb.GeneratedMessage $_createMessage() => FetchScrollback._();
  @$core.override
  FetchScrollback createEmptyInstance() => FetchScrollback._();
  @$core.pragma('dart2js:noInline')
  static FetchScrollback getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<FetchScrollback>(
          FetchScrollback.$_createMessage);
  static FetchScrollback? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get cmdId => $_getI64(0);
  @$pb.TagNumber(1)
  set cmdId($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasCmdId() => $_has(0);
  @$pb.TagNumber(1)
  void clearCmdId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get sessionId => $_getSZ(1);
  @$pb.TagNumber(2)
  set sessionId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSessionId() => $_has(1);
  @$pb.TagNumber(2)
  void clearSessionId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get fromLine => $_getIZ(2);
  @$pb.TagNumber(3)
  set fromLine($core.int value) => $_setUnsignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasFromLine() => $_has(2);
  @$pb.TagNumber(3)
  void clearFromLine() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get count => $_getIZ(3);
  @$pb.TagNumber(4)
  set count($core.int value) => $_setUnsignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasCount() => $_has(3);
  @$pb.TagNumber(4)
  void clearCount() => $_clearField(4);
}

class StopSession extends $pb.GeneratedMessage {
  factory StopSession({
    $fixnum.Int64? cmdId,
    $core.String? sessionId,
    $core.int? signal,
  }) {
    final result = StopSession._();
    if (cmdId != null) result.cmdId = cmdId;
    if (sessionId != null) result.sessionId = sessionId;
    if (signal != null) result.signal = signal;
    return result;
  }

  StopSession._();

  factory StopSession.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      StopSession()..mergeFromBuffer(data, registry);
  factory StopSession.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      StopSession()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'StopSession',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'bluesteer.v1'),
      createEmptyInstance: StopSession.$_createMessage)
    ..a<$fixnum.Int64>(1, _omitFieldNames ? '' : 'cmdId', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aOS(2, _omitFieldNames ? '' : 'sessionId')
    ..aI(3, _omitFieldNames ? '' : 'signal')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StopSession clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StopSession copyWith(void Function(StopSession) updates) =>
      super.copyWith((message) => updates(message as StopSession))
          as StopSession;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use StopSession() / StopSession.new instead')
  static StopSession create() => StopSession._();
  static $pb.GeneratedMessage $_createMessage() => StopSession._();
  @$core.override
  StopSession createEmptyInstance() => StopSession._();
  @$core.pragma('dart2js:noInline')
  static StopSession getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<StopSession>(
          StopSession.$_createMessage);
  static StopSession? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get cmdId => $_getI64(0);
  @$pb.TagNumber(1)
  set cmdId($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasCmdId() => $_has(0);
  @$pb.TagNumber(1)
  void clearCmdId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get sessionId => $_getSZ(1);
  @$pb.TagNumber(2)
  set sessionId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSessionId() => $_has(1);
  @$pb.TagNumber(2)
  void clearSessionId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get signal => $_getIZ(2);
  @$pb.TagNumber(3)
  set signal($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasSignal() => $_has(2);
  @$pb.TagNumber(3)
  void clearSignal() => $_clearField(3);
}

class Ping extends $pb.GeneratedMessage {
  factory Ping({
    $fixnum.Int64? nonce,
  }) {
    final result = Ping._();
    if (nonce != null) result.nonce = nonce;
    return result;
  }

  Ping._();

  factory Ping.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Ping()..mergeFromBuffer(data, registry);
  factory Ping.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Ping()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Ping',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'bluesteer.v1'),
      createEmptyInstance: Ping.$_createMessage)
    ..a<$fixnum.Int64>(1, _omitFieldNames ? '' : 'nonce', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Ping clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Ping copyWith(void Function(Ping) updates) =>
      super.copyWith((message) => updates(message as Ping)) as Ping;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Ping() / Ping.new instead')
  static Ping create() => Ping._();
  static $pb.GeneratedMessage $_createMessage() => Ping._();
  @$core.override
  Ping createEmptyInstance() => Ping._();
  @$core.pragma('dart2js:noInline')
  static Ping getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Ping>(Ping.$_createMessage);
  static Ping? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get nonce => $_getI64(0);
  @$pb.TagNumber(1)
  set nonce($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasNonce() => $_has(0);
  @$pb.TagNumber(1)
  void clearNonce() => $_clearField(1);
}

class Pong extends $pb.GeneratedMessage {
  factory Pong({
    $fixnum.Int64? nonce,
  }) {
    final result = Pong._();
    if (nonce != null) result.nonce = nonce;
    return result;
  }

  Pong._();

  factory Pong.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Pong()..mergeFromBuffer(data, registry);
  factory Pong.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Pong()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Pong',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'bluesteer.v1'),
      createEmptyInstance: Pong.$_createMessage)
    ..a<$fixnum.Int64>(1, _omitFieldNames ? '' : 'nonce', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Pong clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Pong copyWith(void Function(Pong) updates) =>
      super.copyWith((message) => updates(message as Pong)) as Pong;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Pong() / Pong.new instead')
  static Pong create() => Pong._();
  static $pb.GeneratedMessage $_createMessage() => Pong._();
  @$core.override
  Pong createEmptyInstance() => Pong._();
  @$core.pragma('dart2js:noInline')
  static Pong getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Pong>(Pong.$_createMessage);
  static Pong? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get nonce => $_getI64(0);
  @$pb.TagNumber(1)
  set nonce($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasNonce() => $_has(0);
  @$pb.TagNumber(1)
  void clearNonce() => $_clearField(1);
}

/// The remote's first message after the handshake, in every pairing mode.
class RemoteHello extends $pb.GeneratedMessage {
  factory RemoteHello({
    $core.int? protocolVersion,
    $core.String? deviceName,
    $core.String? appVersion,
  }) {
    final result = RemoteHello._();
    if (protocolVersion != null) result.protocolVersion = protocolVersion;
    if (deviceName != null) result.deviceName = deviceName;
    if (appVersion != null) result.appVersion = appVersion;
    return result;
  }

  RemoteHello._();

  factory RemoteHello.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RemoteHello()..mergeFromBuffer(data, registry);
  factory RemoteHello.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RemoteHello()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RemoteHello',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'bluesteer.v1'),
      createEmptyInstance: RemoteHello.$_createMessage)
    ..aI(1, _omitFieldNames ? '' : 'protocolVersion',
        fieldType: $pb.PbFieldType.OU3)
    ..aOS(2, _omitFieldNames ? '' : 'deviceName')
    ..aOS(3, _omitFieldNames ? '' : 'appVersion')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RemoteHello clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RemoteHello copyWith(void Function(RemoteHello) updates) =>
      super.copyWith((message) => updates(message as RemoteHello))
          as RemoteHello;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use RemoteHello() / RemoteHello.new instead')
  static RemoteHello create() => RemoteHello._();
  static $pb.GeneratedMessage $_createMessage() => RemoteHello._();
  @$core.override
  RemoteHello createEmptyInstance() => RemoteHello._();
  @$core.pragma('dart2js:noInline')
  static RemoteHello getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<RemoteHello>(
          RemoteHello.$_createMessage);
  static RemoteHello? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get protocolVersion => $_getIZ(0);
  @$pb.TagNumber(1)
  set protocolVersion($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasProtocolVersion() => $_has(0);
  @$pb.TagNumber(1)
  void clearProtocolVersion() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get deviceName => $_getSZ(1);
  @$pb.TagNumber(2)
  set deviceName($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasDeviceName() => $_has(1);
  @$pb.TagNumber(2)
  void clearDeviceName() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get appVersion => $_getSZ(2);
  @$pb.TagNumber(3)
  set appVersion($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasAppVersion() => $_has(2);
  @$pb.TagNumber(3)
  void clearAppVersion() => $_clearField(3);
}

/// Pairing by code (SPEC.md §2.1): the user confirmed on the remote that both
/// screens show the same code. The host answers with HostHello (paired) or
/// Ack{ok:false} (rejected on the Mac).
class PairConfirm extends $pb.GeneratedMessage {
  factory PairConfirm({
    $fixnum.Int64? cmdId,
  }) {
    final result = PairConfirm._();
    if (cmdId != null) result.cmdId = cmdId;
    return result;
  }

  PairConfirm._();

  factory PairConfirm.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PairConfirm()..mergeFromBuffer(data, registry);
  factory PairConfirm.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PairConfirm()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PairConfirm',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'bluesteer.v1'),
      createEmptyInstance: PairConfirm.$_createMessage)
    ..a<$fixnum.Int64>(1, _omitFieldNames ? '' : 'cmdId', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PairConfirm clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PairConfirm copyWith(void Function(PairConfirm) updates) =>
      super.copyWith((message) => updates(message as PairConfirm))
          as PairConfirm;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use PairConfirm() / PairConfirm.new instead')
  static PairConfirm create() => PairConfirm._();
  static $pb.GeneratedMessage $_createMessage() => PairConfirm._();
  @$core.override
  PairConfirm createEmptyInstance() => PairConfirm._();
  @$core.pragma('dart2js:noInline')
  static PairConfirm getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<PairConfirm>(
          PairConfirm.$_createMessage);
  static PairConfirm? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get cmdId => $_getI64(0);
  @$pb.TagNumber(1)
  set cmdId($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasCmdId() => $_has(0);
  @$pb.TagNumber(1)
  void clearCmdId() => $_clearField(1);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
