import 'dart:io';

import 'package:PiliPlus/plugin/pl_player/models/play_repeat.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

/// YQH-150: Pref default seams for audio-only / bg continue / listCycle.
void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('piliplus_yqh150_');
    Hive.init(tempDir.path);
    GStorage.setting = await Hive.openBox<dynamic>('setting');
    GStorage.video = await Hive.openBox<dynamic>('video');
  });

  setUp(() async {
    await GStorage.setting.clear();
    await GStorage.video.clear();
  });

  tearDownAll(() async {
    await GStorage.setting.close();
    await GStorage.video.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('onlyPlayAudio defaults false and persists via SettingBoxKey', () {
    expect(Pref.onlyPlayAudio, isFalse);
    GStorage.setting.put(SettingBoxKey.onlyPlayAudio, true);
    expect(Pref.onlyPlayAudio, isTrue);
  });

  test('continuePlayInBackground defaults true (Focus Mode off path)', () {
    // Focus Mode forces true via enableFocusMode getter; force focus off if present.
    GStorage.setting.put(SettingBoxKey.enableFocusMode, false);
    expect(Pref.continuePlayInBackground, isTrue);
    GStorage.setting.put(SettingBoxKey.continuePlayInBackground, false);
    expect(Pref.continuePlayInBackground, isFalse);
  });

  test('enableBackgroundPlay still defaults true', () {
    GStorage.setting.put(SettingBoxKey.enableFocusMode, false);
    expect(Pref.enableBackgroundPlay, isTrue);
  });

  test('playRepeat defaults to listCycle without rewriting stored keys', () {
    expect(Pref.playRepeat, PlayRepeat.listCycle);
    GStorage.video.put(VideoBoxKey.playRepeat, PlayRepeat.pause.index);
    expect(Pref.playRepeat, PlayRepeat.pause);
  });

  test('autoUpdate still defaults false (D2 no-change)', () {
    expect(Pref.autoUpdate, isFalse);
  });
}
