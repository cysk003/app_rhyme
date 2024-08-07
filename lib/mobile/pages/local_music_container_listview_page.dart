import 'package:app_rhyme/mobile/comps/chores/button.dart';
import 'package:app_rhyme/mobile/pages/muti_select_pages/muti_select_music_container_listview_page.dart';
import 'package:app_rhyme/mobile/pages/reorder_pages/reorder_local_music_list_page.dart';
import 'package:app_rhyme/utils/log_toast.dart';
import 'package:chinese_font_library/chinese_font_library.dart';
import 'package:app_rhyme/mobile/comps/music_container_comp/music_container_list_item.dart';
import 'package:app_rhyme/mobile/comps/musiclist_comp/musiclist_image_card.dart';
import 'package:app_rhyme/pulldown_menus/musiclist_pulldown_menu.dart';
import 'package:app_rhyme/src/rust/api/bind/factory_bind.dart';
import 'package:app_rhyme/src/rust/api/bind/mirrors.dart';
import 'package:app_rhyme/src/rust/api/bind/type_bind.dart';
import 'package:app_rhyme/types/music_container.dart';
import 'package:app_rhyme/utils/cache_helper.dart';
import 'package:app_rhyme/utils/chore.dart';
import 'package:app_rhyme/utils/colors.dart';
import 'package:app_rhyme/utils/global_vars.dart';
import 'package:app_rhyme/utils/music_api_helper.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:pull_down_button/pull_down_button.dart';

// 用于执行更改本地歌单内的操作后直接刷新整个歌单页面，由于使用了 ValueKey，过渡自然
Future<void> Function() globalMobileMusicContainerListPageRefreshFunction =
    () async {};
void Function() globalMusicContainerListPagePopFunction = () {};

class LocalMusicContainerListPage extends StatefulWidget {
  final MusicListW musicList;

  const LocalMusicContainerListPage({
    super.key,
    required this.musicList,
  });

  @override
  LocalMusicContainerListPageState createState() =>
      LocalMusicContainerListPageState();
}

class LocalMusicContainerListPageState
    extends State<LocalMusicContainerListPage> with WidgetsBindingObserver {
  List<MusicContainer> musicContainers = [];
  late MusicListW musicListW;
  late MusicListInfo musicListInfo;

  @override
  void initState() {
    WidgetsBinding.instance.addObserver(this);
    musicListW = widget.musicList;
    musicListInfo = musicListW.getMusiclistInfo();
    // 设置全局的更新函数
    globalMobileMusicContainerListPageRefreshFunction = () async {
      var musicLists = await SqlFactoryW.getAllMusiclists();
      setState(() {
        musicListW = musicLists
            .singleWhere((ml) => ml.getMusiclistInfo().id == musicListInfo.id);
        musicListInfo = musicListW.getMusiclistInfo();
      });
      await loadMusicContainers();
    };
    globalMusicContainerListPagePopFunction = () {
      Navigator.pop(context);
    };
    // 加载歌单内音乐
    loadMusicContainers();
    super.initState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // 清空全局的更新函数
    globalMobileMusicContainerListPageRefreshFunction = () async {};
    globalMusicContainerListPagePopFunction = () {};
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    setState(() {
      // 重建界面以响应亮暗模式变化
    });
  }

  Future<void> loadMusicContainers() async {
    try {
      var aggs = await SqlFactoryW.getAllMusics(musiclistInfo: musicListInfo);
      setState(() {
        musicContainers = aggs.map((a) => MusicContainer(a)).toList();
      });
    } catch (e) {
      LogToast.error("加载歌曲列表", "加载歌曲列表失败!:$e",
          "[loadMusicContainers] Failed to load music list: $e");

      setState(() {
        musicContainers = [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = MediaQuery.of(context).platformBrightness;
    final bool isDarkMode = brightness == Brightness.dark;
    final Color backgroundColor =
        isDarkMode ? CupertinoColors.black : CupertinoColors.white;
    final Color dividerColor = isDarkMode
        ? const Color.fromARGB(255, 41, 41, 43)
        : const Color.fromARGB(255, 245, 245, 246);
    double screenWidth = MediaQuery.of(context).size.width;

    return CupertinoPageScaffold(
      backgroundColor: backgroundColor,
      navigationBar: CupertinoNavigationBar(
          padding: const EdgeInsetsDirectional.only(end: 16),
          backgroundColor: backgroundColor,
          leading: CupertinoButton(
            padding: const EdgeInsets.all(0),
            child: Icon(CupertinoIcons.back, color: activeIconRed),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
          trailing: LocalMusicListChoicMenu(
            builder: (context, showMenu) => CupertinoButton(
                padding: const EdgeInsets.all(0),
                onPressed: showMenu,
                child: Text(
                  '选项',
                  style: TextStyle(color: activeIconRed).useSystemChineseFont(),
                )),
            musicListW: musicListW,
            musicContainers: musicContainers,
          )),
      child: CustomScrollView(
        slivers: <Widget>[
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(
                  top: 10, left: screenWidth * 0.15, right: screenWidth * 0.15),
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: screenWidth * 0.7,
                ),
                child: MusicListImageCard(
                  musicListW: musicListW,
                  online: false,
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  buildButton(
                    context,
                    icon: CupertinoIcons.play_fill,
                    label: '播放',
                    onPressed: () {
                      globalAudioHandler.clearReplaceMusicAll(musicContainers);
                    },
                  ),
                  buildButton(
                    context,
                    icon: Icons.shuffle,
                    label: '随机播放',
                    onPressed: () {
                      globalAudioHandler
                          .clearReplaceMusicAll(shuffleList(musicContainers));
                    },
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Center(
              child: SizedBox(
                width: screenWidth * 0.85,
                child: Divider(
                  color: dividerColor,
                  height: 0.5,
                ),
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                bool isFirst = index == 0;
                bool isLastItem = index == musicContainers.length - 1;

                final musicContainer = musicContainers[index];
                return Column(
                  children: [
                    if (isFirst)
                      const Padding(padding: EdgeInsets.only(top: 5)),
                    Padding(
                      padding: const EdgeInsets.only(top: 5, bottom: 5),
                      child: MusicContainerListItem(
                        key: ValueKey(
                            '${musicContainer.hasCache()}_${musicContainer.hashCode}'),
                        musicContainer: musicContainer,
                        musicListW: widget.musicList,
                        cachePic: globalConfig.savePicWhenAddMusicList,
                      ),
                    ),
                    if (!isLastItem)
                      Center(
                        child: SizedBox(
                          width: screenWidth * 0.85,
                          child: Divider(
                            color: dividerColor,
                            height: 0.5,
                          ),
                        ),
                      )
                  ],
                );
              },
              childCount: musicContainers.length,
            ),
          ),
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(top: 200),
            ),
          ),
        ],
      ),
    );
  }
}

@immutable
class LocalMusicListChoicMenu extends StatelessWidget {
  const LocalMusicListChoicMenu({
    super.key,
    required this.builder,
    required this.musicListW,
    required this.musicContainers,
  });

  final PullDownMenuButtonBuilder builder;
  final MusicListW musicListW;
  final List<MusicContainer> musicContainers;

  @override
  Widget build(BuildContext context) {
    MusicListInfo musicListInfo = musicListW.getMusiclistInfo();

    return PullDownButton(
      itemBuilder: (context) => [
        PullDownMenuHeader(
          itemTheme: PullDownMenuItemTheme(
              textStyle: const TextStyle().useSystemChineseFont()),
          leading: imageCacheHelper(musicListInfo.artPic),
          title: musicListInfo.name,
          subtitle: musicListInfo.desc,
        ),
        const PullDownMenuDivider.large(),
        ...localMusiclistItems(context, musicListW),
        PullDownMenuItem(
          itemTheme: PullDownMenuItemTheme(
              textStyle: const TextStyle().useSystemChineseFont()),
          onTap: () async {
            for (var musicContainer in musicContainers) {
              await cacheMusic(musicContainer);
            }
          },
          title: '缓存歌单所有音乐',
          icon: CupertinoIcons.cloud_download,
        ),
        PullDownMenuItem(
          itemTheme: PullDownMenuItemTheme(
              textStyle: const TextStyle().useSystemChineseFont()),
          onTap: () async {
            for (var musicContainer in musicContainers) {
              await delMusicCache(musicContainer, showToast: false);
            }
            LogToast.success("删除所有音乐缓存", "删除所有音乐缓存成功",
                "[LocalMusicListChoicMenu] Successfully deleted all music caches");
          },
          title: '删除所有音乐缓存',
          icon: CupertinoIcons.delete,
        ),
        PullDownMenuItem(
          itemTheme: PullDownMenuItemTheme(
              textStyle: const TextStyle().useSystemChineseFont()),
          onTap: () {
            Navigator.push(
              context,
              CupertinoPageRoute(
                builder: (context) => ReorderLocalMusicListPage(
                  musicContainers: musicContainers,
                  musicList: musicListW,
                ),
              ),
            );
          },
          title: "手动排序",
          icon: CupertinoIcons.sort_up_circle,
        ),
        PullDownMenuItem(
          itemTheme: PullDownMenuItemTheme(
              textStyle: const TextStyle().useSystemChineseFont()),
          onTap: () {
            Navigator.push(
              context,
              CupertinoPageRoute(
                builder: (context) => MutiSelectMusicContainerListPage(
                  musicList: musicListW,
                  musicContainers: musicContainers,
                ),
              ),
            );
          },
          title: "多选操作",
          icon: CupertinoIcons.selection_pin_in_out,
        )
      ],
      animationBuilder: null,
      position: PullDownMenuPosition.automatic,
      buttonBuilder: builder,
    );
  }
}
