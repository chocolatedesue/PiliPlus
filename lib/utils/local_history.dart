import 'package:PiliPlus/models/common/video/video_type.dart';
import 'package:PiliPlus/models_new/history/history.dart';
import 'package:PiliPlus/models_new/history/list.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:hive_ce/hive.dart';

/// Pure-local watch history (Hive). No login / cloud dependency.
///
/// Dedup key: [kid] preferred, else `business+oid+cid` (fallback bvid/oid).
abstract final class LocalHistory {
  static Box<dynamic> get _box => GStorage.localHistory;

  /// Whether a playback tick should upsert local history.
  ///
  /// Intentionally **ignores** login / cloud-heartbeat enable / historyPause —
  /// those gate only [VideoHttp.heartBeat]. Used by player dual-write and tests
  /// (R1-F01 / AC1).
  static bool shouldRecordPlaybackTick({
    required bool isLive,
    required int progress,
    required bool isCompletedType,
    required bool isPaused,
    required bool isManual,
  }) {
    if (isLive) return false;
    if (progress == 0 && !isCompletedType) return false;
    if (isPaused && !isManual && !isCompletedType) return false;
    return true;
  }

  /// Map bilibili player [VideoType] to history `business` strings.
  static String businessOf(VideoType? videoType) => switch (videoType) {
    VideoType.pgc => 'pgc',
    VideoType.pugv => 'cheese',
    _ => 'archive',
  };

  /// Stable storage key for upsert / remove.
  static String storageKey({
    int? kid,
    String? business,
    int? oid,
    int? cid,
    String? bvid,
  }) {
    if (kid != null) return 'k:$kid';
    final b = business ?? 'archive';
    if (oid != null && cid != null) return 'b:$b:$oid:$cid';
    if (oid != null) return 'b:$b:$oid';
    if (bvid != null && bvid.isNotEmpty) return 'v:$bvid${cid != null ? ':$cid' : ''}';
    if (cid != null) return 'c:$cid';
    return 'unknown:${DateTime.now().microsecondsSinceEpoch}';
  }

  static String keyOfItem(HistoryItemModel item) => storageKey(
    kid: item.kid,
    business: item.history.business,
    oid: item.history.oid,
    cid: item.history.cid,
    bvid: item.history.bvid,
  );

  static Map<String, dynamic> _toMap(HistoryItemModel item) => {
    'title': item.title,
    'cover': item.cover,
    'covers': item.covers,
    'uri': item.uri,
    'history': {
      'oid': item.history.oid,
      'epid': item.history.epid,
      'bvid': item.history.bvid,
      'page': item.history.page,
      'cid': item.history.cid,
      'business': item.history.business,
    },
    'videos': item.videos,
    'author_name': item.authorName,
    'author_mid': item.authorMid,
    'view_at': item.viewAt,
    'progress': item.progress,
    'badge': item.badge,
    'show_title': item.showTitle,
    'duration': item.duration,
    'is_fav': item.isFav,
    'kid': item.kid,
    'tag_name': item.tagName,
    'live_status': item.liveStatus,
  };

  static HistoryItemModel _fromMap(Map map) {
    final raw = Map<String, dynamic>.from(map);
    final hist = raw['history'];
    if (hist is Map) {
      raw['history'] = Map<String, dynamic>.from(hist);
    }
    return HistoryItemModel.fromJson(raw);
  }

  /// Insert or merge. Updates [viewAt] / [progress] and non-null meta fields.
  static void upsert(HistoryItemModel item) {
    final key = keyOfItem(item);
    final existing = _box.get(key);
    if (existing is Map) {
      final prev = _fromMap(existing);
      item
        ..title = item.title ?? prev.title
        ..cover = item.cover ?? prev.cover
        ..covers = item.covers ?? prev.covers
        ..uri = item.uri ?? prev.uri
        ..authorName = item.authorName ?? prev.authorName
        ..authorMid = item.authorMid ?? prev.authorMid
        ..badge = item.badge ?? prev.badge
        ..showTitle = item.showTitle ?? prev.showTitle
        ..duration = item.duration ?? prev.duration
        ..isFav = item.isFav ?? prev.isFav
        ..tagName = item.tagName ?? prev.tagName
        ..liveStatus = item.liveStatus ?? prev.liveStatus
        ..videos = item.videos ?? prev.videos
        ..kid = item.kid ?? prev.kid;
      // Prefer newer history identity fields when present.
      item.history
        ..oid = item.history.oid ?? prev.history.oid
        ..epid = item.history.epid ?? prev.history.epid
        ..bvid = item.history.bvid ?? prev.history.bvid
        ..page = item.history.page ?? prev.history.page
        ..cid = item.history.cid ?? prev.history.cid
        ..business = item.history.business ?? prev.history.business;
    }
    item.viewAt ??= DateTime.now().millisecondsSinceEpoch ~/ 1000;
    _box.put(key, _toMap(item));
  }

  /// Playback-side write. No login gate. Skips when ids are insufficient.
  static void upsertFromPlayback({
    Object? aid,
    Object? bvid,
    Object? cid,
    Object? epid,
    Object? seasonId,
    required int progress,
    VideoType? videoType,
    String? title,
    String? cover,
    String? authorName,
    int? authorMid,
    int? duration,
    String? showTitle,
  }) {
    final oid = _asInt(aid) ?? _oidFromBvid(bvid);
    final cidInt = _asInt(cid);
    final bvidStr = bvid?.toString();
    if (oid == null && (bvidStr == null || bvidStr.isEmpty) && cidInt == null) {
      return;
    }

    final business = businessOf(videoType);
    final kid = oid; // archive kid conventionally equals aid/oid
    final item = HistoryItemModel(
      title: title,
      cover: cover,
      authorName: authorName,
      authorMid: authorMid,
      viewAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      progress: progress,
      duration: duration,
      showTitle: showTitle,
      kid: kid,
      history: History(
        oid: oid,
        epid: _asInt(epid),
        bvid: bvidStr,
        cid: cidInt,
        business: business,
        page: 1,
      ),
    );
    upsert(item);
  }

  static void remove(HistoryItemModel item) {
    _box.delete(keyOfItem(item));
  }

  static void removeMany(Iterable<HistoryItemModel> items) {
    for (final item in items) {
      remove(item);
    }
  }

  static Future<int> clear() => _box.clear();

  /// Filter + sort. Default [viewAt] descending.
  static List<HistoryItemModel> list({
    String? query,
    String? business,
    String? author,
    int? authorMid,
    bool desc = true,
  }) {
    final q = query?.trim().toLowerCase();
    final authorQ = author?.trim().toLowerCase();
    final biz = business?.trim();

    final items = <HistoryItemModel>[];
    for (final value in _box.values) {
      if (value is! Map) continue;
      final item = _fromMap(value);

      if (biz != null && biz.isNotEmpty && biz != 'all') {
        if ((item.history.business ?? '') != biz) continue;
      }
      if (authorMid != null && item.authorMid != authorMid) continue;
      if (authorQ != null && authorQ.isNotEmpty) {
        final name = (item.authorName ?? '').toLowerCase();
        if (!name.contains(authorQ)) continue;
      }
      if (q != null && q.isNotEmpty) {
        final title = (item.title ?? '').toLowerCase();
        final name = (item.authorName ?? '').toLowerCase();
        final show = (item.showTitle ?? '').toLowerCase();
        if (!title.contains(q) && !name.contains(q) && !show.contains(q)) {
          continue;
        }
      }
      items.add(item);
    }

    items.sort((a, b) {
      final av = a.viewAt ?? 0;
      final bv = b.viewAt ?? 0;
      return desc ? bv.compareTo(av) : av.compareTo(bv);
    });
    return items;
  }

  static int get length => _box.length;

  static int? _asInt(Object? v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
  }

  static int? _oidFromBvid(Object? bvid) {
    // Prefer explicit aid; bvid alone is kept on the model for navigation.
    return null;
  }
}
