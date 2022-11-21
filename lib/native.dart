import 'dart:async';
import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:isolate/ports.dart';
import 'package:path_provider/path_provider.dart';

import 'ffi.dart' as native;

class CalendarNative {
  static setup() async {
    native.store_dart_post_cobject(NativeApi.postCObject);

    final dataDir = await _localPath;

    await _init(dataDir);
  }

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

  static Future<String> fetchEvent(String startTime, String endTime) {
    final completer = Completer<String>();
    final sendPort = singleCompletePort(completer);

    native.fetch_event(
        sendPort.nativePort, startTime.toNativeUtf8(), endTime.toNativeUtf8());

    return completer.future;
  }

  static Future<void> addEvent(String event) {
    final completer = Completer<bool>();
    final sendPort = singleCompletePort(completer);

    native.add_event(sendPort.nativePort, event.toNativeUtf8());

    return completer.future;
  }

  static Future<void> deleteEvent(String eventId) {
    final completer = Completer<bool>();
    final sendPort = singleCompletePort(completer);

    native.delete_event(sendPort.nativePort, eventId.toNativeUtf8());

    return completer.future;
  }
}
