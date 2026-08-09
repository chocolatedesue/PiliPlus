import 'package:PiliPlus/common/skeleton/video_card_h.dart';
import 'package:PiliPlus/common/style.dart';
import 'package:PiliPlus/common/widgets/loading_widget/http_error.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/models_new/space/space_archive/item.dart';
import 'package:PiliPlus/models_new/video/video_detail/episode.dart';
import 'package:PiliPlus/pages/member_video/widgets/video_card_h_member_video.dart';
import 'package:PiliPlus/pages/video/controller.dart';
import 'package:PiliPlus/pages/video/introduction/ugc/controller.dart';
import 'package:PiliPlus/pages/video/up_recent/controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Focus Mode related-slot: same-UP recent list (replaces suppressed related).
class UpRecentPanel extends StatefulWidget {
  const UpRecentPanel({
    super.key,
    required this.heroTag,
    required this.mid,
    required this.videoDetailController,
    required this.ugcIntroController,
    this.showTitle = true,
  });

  final String heroTag;
  final dynamic mid;
  final VideoDetailController videoDetailController;
  final UgcIntroController ugcIntroController;
  final bool showTitle;

  @override
  State<UpRecentPanel> createState() => _UpRecentPanelState();
}

class _UpRecentPanelState extends State<UpRecentPanel> {
  late final UpRecentController _controller;
  late final String _tag;
  late final String _bvid;

  @override
  void initState() {
    super.initState();
    _tag = '${widget.heroTag}_upRecent';
    _bvid = widget.videoDetailController.bvid;
    _controller = Get.put(
      UpRecentController(
        mid: widget.mid,
        currAid: widget.videoDetailController.aid.toString(),
      ),
      tag: _tag,
    );
  }

  @override
  void dispose() {
    Get.delete<UpRecentController>(tag: _tag);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SliverMainAxisGroup(
      slivers: [
        if (widget.showTitle)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                Style.safeSpace,
                12,
                Style.safeSpace,
                4,
              ),
              child: Text(
                '同 UP 最近',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        SliverPadding(
          padding: const EdgeInsets.only(
            top: 7,
            bottom: 100,
          ),
          sliver: Obx(() => _buildBody(_controller.loadingState.value)),
        ),
      ],
    );
  }

  Widget _buildBody(LoadingState<List<SpaceArchiveItem>?> loadingState) {
    return switch (loadingState) {
      Loading() => SliverFixedExtentList.builder(
        itemCount: 6,
        itemBuilder: (_, _) => const VideoCardHSkeleton(),
        itemExtent: 112,
      ),
      Success(:final response) =>
        response != null && response.isNotEmpty
            ? SliverFixedExtentList.builder(
                itemBuilder: (context, index) {
                  if (index == response.length - 1 && _controller.hasNext) {
                    _controller.onLoadMore();
                  }
                  final videoItem = response[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: VideoCardHMemberVideo(
                      videoItem: videoItem,
                      bvid: _bvid,
                      onTap: () {
                        widget.ugcIntroController.onChangeEpisode(
                          BaseEpisodeItem(
                            bvid: videoItem.bvid,
                            cid: videoItem.cid,
                            cover: videoItem.cover,
                          ),
                        );
                      },
                    ),
                  );
                },
                itemCount: response.length,
                itemExtent: 112,
              )
            : HttpError(onReload: _controller.onReload),
      Error(:final errMsg) => HttpError(
        errMsg: errMsg,
        onReload: _controller.onReload,
      ),
    };
  }
}
