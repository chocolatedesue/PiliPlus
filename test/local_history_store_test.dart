import 'dart:io';

import 'package:PiliPlus/models/common/video/video_type.dart';
import 'package:PiliPlus/models_new/history/history.dart';
import 'package:PiliPlus/models_new/history/list.dart';
import 'package:PiliPlus/utils/local_history.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('piliplus_local_history_');
    Hive.init(tempDir.path);
    GStorage.localHistory = await Hive.openBox<dynamic>('localHistory');
  });

  setUp(() async {
    await GStorage.localHistory.clear();
  });

  tearDownAll(() async {
    await GStorage.localHistory.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  HistoryItemModel item({
    required int oid,
    int? cid,
    int? kid,
    String? title,
    String? authorName,
    int? authorMid,
    String business = 'archive',
    String? bvid,
    int? viewAt,
    int progress = 10,
  }) {
    return HistoryItemModel(
      title: title,
      authorName: authorName,
      authorMid: authorMid,
      viewAt: viewAt,
      progress: progress,
      kid: kid ?? oid,
      history: History(
        oid: oid,
        cid: cid ?? 1,
        bvid: bvid,
        business: business,
      ),
    );
  }

  test('upsert inserts and dedupes by kid', () {
    LocalHistory.upsert(
      item(oid: 100, title: 'A', viewAt: 1000, progress: 5),
    );
    LocalHistory.upsert(
      item(oid: 100, title: 'A2', viewAt: 2000, progress: 30),
    );

    final list = LocalHistory.list();
    expect(list, hasLength(1));
    expect(list.single.title, 'A2');
    expect(list.single.progress, 30);
    expect(list.single.viewAt, 2000);
  });

  test('dedupe falls back to business+oid+cid when kid missing', () {
    LocalHistory.upsert(
      HistoryItemModel(
        title: 'NoKid',
        viewAt: 1,
        progress: 1,
        history: History(oid: 7, cid: 8, business: 'archive', bvid: 'BV1xx'),
      ),
    );
    LocalHistory.upsert(
      HistoryItemModel(
        title: 'NoKid2',
        viewAt: 2,
        progress: 9,
        history: History(oid: 7, cid: 8, business: 'archive', bvid: 'BV1xx'),
      ),
    );
    expect(LocalHistory.list(), hasLength(1));
    expect(LocalHistory.list().single.title, 'NoKid2');
  });

  test('remove and removeMany', () {
    final a = item(oid: 1, title: 'a', viewAt: 10);
    final b = item(oid: 2, title: 'b', viewAt: 20);
    final c = item(oid: 3, title: 'c', viewAt: 30);
    LocalHistory.upsert(a);
    LocalHistory.upsert(b);
    LocalHistory.upsert(c);

    LocalHistory.remove(b);
    expect(LocalHistory.list().map((e) => e.history.oid), [3, 1]);

    LocalHistory.removeMany([a, c]);
    expect(LocalHistory.list(), isEmpty);
  });

  test('clear empties box', () async {
    LocalHistory.upsert(item(oid: 1, viewAt: 1));
    LocalHistory.upsert(item(oid: 2, viewAt: 2));
    await LocalHistory.clear();
    expect(LocalHistory.list(), isEmpty);
    expect(LocalHistory.length, 0);
  });

  test('keyword filter matches title and authorName', () {
    LocalHistory.upsert(
      item(oid: 1, title: 'Flutter Tips', authorName: 'Alice', viewAt: 3),
    );
    LocalHistory.upsert(
      item(oid: 2, title: 'Dart Intro', authorName: 'Bob', viewAt: 2),
    );
    LocalHistory.upsert(
      item(oid: 3, title: 'Other', authorName: 'flutter-fan', viewAt: 1),
    );

    final byTitle = LocalHistory.list(query: 'flutter');
    expect(byTitle.map((e) => e.history.oid), [1, 3]);

    final byAuthor = LocalHistory.list(query: 'bob');
    expect(byAuthor, hasLength(1));
    expect(byAuthor.single.history.oid, 2);
  });

  test('business and author structured filters', () {
    LocalHistory.upsert(
      item(oid: 1, business: 'archive', authorName: 'UpA', authorMid: 11, viewAt: 5),
    );
    LocalHistory.upsert(
      item(oid: 2, business: 'pgc', authorName: 'UpB', authorMid: 22, viewAt: 4),
    );
    LocalHistory.upsert(
      item(oid: 3, business: 'archive', authorName: 'UpA', authorMid: 11, viewAt: 3),
    );

    expect(
      LocalHistory.list(business: 'pgc').map((e) => e.history.oid),
      [2],
    );
    expect(
      LocalHistory.list(authorMid: 11).map((e) => e.history.oid),
      [1, 3],
    );
    expect(
      LocalHistory.list(author: 'upb').map((e) => e.history.oid),
      [2],
    );
  });

  test('default sort is viewAt descending', () {
    LocalHistory.upsert(item(oid: 1, title: 'old', viewAt: 100));
    LocalHistory.upsert(item(oid: 2, title: 'mid', viewAt: 200));
    LocalHistory.upsert(item(oid: 3, title: 'new', viewAt: 300));

    expect(
      LocalHistory.list().map((e) => e.history.oid).toList(),
      [3, 2, 1],
    );
    expect(
      LocalHistory.list(desc: false).map((e) => e.history.oid).toList(),
      [1, 2, 3],
    );
  });

  test('upsertFromPlayback maps video type and writes without login', () {
    LocalHistory.upsertFromPlayback(
      aid: 42,
      bvid: 'BV1test',
      cid: 99,
      progress: 15,
      videoType: VideoType.ugc,
      title: 'Played',
      authorName: 'UP',
      authorMid: 7,
      duration: 600,
    );

    final list = LocalHistory.list();
    expect(list, hasLength(1));
    final it = list.single;
    expect(it.title, 'Played');
    expect(it.history.business, 'archive');
    expect(it.history.oid, 42);
    expect(it.history.cid, 99);
    expect(it.progress, 15);
    expect(it.duration, 600);
    expect(it.authorMid, 7);

    LocalHistory.upsertFromPlayback(
      aid: 42,
      bvid: 'BV1test',
      cid: 99,
      progress: -1,
      videoType: VideoType.ugc,
      title: 'Played',
    );
    expect(LocalHistory.list().single.progress, -1);
  });

  test('storageKey prefers kid', () {
    expect(
      LocalHistory.storageKey(kid: 5, business: 'archive', oid: 1, cid: 2),
      'k:5',
    );
    expect(
      LocalHistory.storageKey(business: 'pgc', oid: 9, cid: 3),
      'b:pgc:9:3',
    );
  });

  group('R1-F01 write policy (no login / enableHeart gate)', () {
    test('playing tick records when not live and progress > 0', () {
      expect(
        LocalHistory.shouldRecordPlaybackTick(
          isLive: false,
          progress: 12,
          isCompletedType: false,
          isPaused: false,
          isManual: false,
        ),
        isTrue,
      );
    });

    test('manual leave-page records even when paused', () {
      expect(
        LocalHistory.shouldRecordPlaybackTick(
          isLive: false,
          progress: 40,
          isCompletedType: false,
          isPaused: true,
          isManual: true,
        ),
        isTrue,
      );
    });

    test('completed type records at progress -1', () {
      expect(
        LocalHistory.shouldRecordPlaybackTick(
          isLive: false,
          progress: -1,
          isCompletedType: true,
          isPaused: false,
          isManual: false,
        ),
        isTrue,
      );
    });

    test('live and zero progress playing are skipped', () {
      expect(
        LocalHistory.shouldRecordPlaybackTick(
          isLive: true,
          progress: 10,
          isCompletedType: false,
          isPaused: false,
          isManual: false,
        ),
        isFalse,
      );
      expect(
        LocalHistory.shouldRecordPlaybackTick(
          isLive: false,
          progress: 0,
          isCompletedType: false,
          isPaused: false,
          isManual: false,
        ),
        isFalse,
      );
    });

    test(
      'simulates unlogged enableHeart=false path: playing + manual upsert',
      () {
        // Store itself never consults Accounts / enableHeart / historyPause.
        // This is the call site contract when player dual-write runs with
        // enableHeart == false (unlogged or Pref.historyPause).
        expect(
          LocalHistory.shouldRecordPlaybackTick(
            isLive: false,
            progress: 8,
            isCompletedType: false,
            isPaused: false,
            isManual: false,
          ),
          isTrue,
        );

        LocalHistory.upsertFromPlayback(
          aid: 9001,
          bvid: 'BV1unlogged',
          cid: 1,
          progress: 8,
          videoType: VideoType.ugc,
          title: 'Unlogged partial watch',
        );
        expect(LocalHistory.list(), hasLength(1));
        expect(LocalHistory.list().single.progress, 8);
        expect(LocalHistory.list().single.title, 'Unlogged partial watch');

        // Manual leave-page flush (isManual path).
        expect(
          LocalHistory.shouldRecordPlaybackTick(
            isLive: false,
            progress: 55,
            isCompletedType: true,
            isPaused: true,
            isManual: true,
          ),
          isTrue,
        );
        LocalHistory.upsertFromPlayback(
          aid: 9001,
          bvid: 'BV1unlogged',
          cid: 1,
          progress: 55,
          videoType: VideoType.ugc,
          title: 'Unlogged partial watch',
        );
        expect(LocalHistory.list(), hasLength(1));
        expect(LocalHistory.list().single.progress, 55);
      },
    );
  });
}
