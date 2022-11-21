import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:isolate/ports.dart';
import 'package:path_provider/path_provider.dart';

import 'ffi.dart' as native;

class CalendarNative {
  static final _setup = CalendarNative.setup();

  static setup() async {
    native.store_dart_post_cobject(NativeApi.postCObject);

    final dataDir = await _localPath;

    await _init(dataDir);
  }

  static ensureSetup() async => _setup;

  static Future<void> _init(String dataDir) {
    final completer = Completer<bool>();
    final sendPort = singleCompletePort(completer);

    native.init(sendPort.nativePort, dataDir.toNativeUtf8());

    return completer.future;
  }

  static Future<String> get _localPath async {
    final directory = await getApplicationSupportDirectory();

    return directory.path;
  }

  static Future<Map<String, dynamic>> queryCalendarDb(
      String ops, String? variables) async {
    await ensureSetup();

    final completer = Completer<String>();
    final sendPort = singleCompletePort(completer);

    final Pointer<Never> nullptr = Pointer.fromAddress(0);

    final vars = variables?.toNativeUtf8() ?? nullptr;

    native.calendar_db_graphql(sendPort.nativePort, ops.toNativeUtf8(), vars);

    final content = await completer.future;

    return jsonDecode(content);
  }
}
