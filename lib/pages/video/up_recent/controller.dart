import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/http/member.dart';
import 'package:PiliPlus/models/common/member/archive_order_type_app.dart';
import 'package:PiliPlus/models/common/member/contribute_type.dart';
import 'package:PiliPlus/models_new/space/space_archive/data.dart';
import 'package:PiliPlus/models_new/space/space_archive/item.dart';
import 'package:PiliPlus/pages/common/common_list_controller.dart';

/// Same-UP recent archives for Focus Mode related-slot (play-page MVP).
/// Reuses [MemberHttp.spaceArchive] path used by [HorizontalMemberPageController].
class UpRecentController
    extends CommonListController<SpaceArchiveData, SpaceArchiveItem> {
  UpRecentController({required this.mid, required this.currAid});

  final dynamic mid;
  String? currAid;
  String? firstAid;
  String? lastAid;
  /// Newest-publish first (API `order=pubdate`); no client re-sort (YQH-74).
  ArchiveOrderTypeApp order = .pubdate;
  int? count;
  bool isLoadPrevious = false;
  bool hasPrev = true;
  bool hasNext = true;

  @override
  void onInit() {
    super.onInit();
    queryData();
  }

  @override
  bool customHandleResponse(bool isRefresh, Success response) {
    SpaceArchiveData data = response.response;
    count = data.count;
    if (isRefresh) {
      if (isLoadPrevious) {
        hasPrev = data.hasPrev ?? false;
      } else {
        hasNext = data.hasNext ?? false;
      }
    }
    if (isLoadPrevious) {
      if (loadingState.value case Success(:final response)) {
        (data.item ??= <SpaceArchiveItem>[]).addAll(response!);
      }
    } else if (!isRefresh) {
      if (loadingState.value case Success(:final response)) {
        (data.item ??= <SpaceArchiveItem>[]).insertAll(0, response!);
      }
    }
    firstAid = data.item?.firstOrNull?.param;
    lastAid = data.item?.lastOrNull?.param;
    loadingState.value = Success(data.item);
    isLoadPrevious = false;
    page++;
    return true;
  }

  @override
  Future<LoadingState<SpaceArchiveData>> customGetData() =>
      MemberHttp.spaceArchive(
        type: ContributeType.video,
        mid: mid,
        aid: page == 1
            ? currAid
            : isLoadPrevious
            ? firstAid
            : lastAid,
        order: order,
        sort: page != 1 && isLoadPrevious ? .asc : null,
        pn: null,
        next: null,
        seasonId: null,
        seriesId: null,
        includeCursor: page == 1 ? true : null,
      );

  @override
  Future<void> onRefresh() {
    if (!hasPrev) {
      return Future.value();
    }
    isLoadPrevious = true;
    return queryData();
  }

  @override
  Future<void> onReload() {
    firstAid = null;
    lastAid = null;
    hasNext = true;
    hasPrev = true;
    isEnd = false;
    page = 1;
    return super.onReload();
  }
}
