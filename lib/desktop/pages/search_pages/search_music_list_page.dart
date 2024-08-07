import 'package:app_rhyme/desktop/comps/delegate.dart';
import 'package:app_rhyme/desktop/comps/musiclist_comp/musiclist_image_card.dart';
import 'package:app_rhyme/desktop/comps/navigation_column.dart';
import 'package:app_rhyme/desktop/pages/muti_select_pages/muti_select_local_music_list_gridview_page.dart';
import 'package:app_rhyme/desktop/pages/online_music_container_listview_page.dart';
import 'package:app_rhyme/desktop/utils/colors.dart';
import 'package:app_rhyme/dialogs/input_musiclist_sharelink_dialog.dart';
import 'package:app_rhyme/src/rust/api/bind/factory_bind.dart';
import 'package:app_rhyme/src/rust/api/bind/type_bind.dart';
import 'package:app_rhyme/utils/colors.dart';
import 'package:app_rhyme/utils/const_vars.dart';
import 'package:app_rhyme/utils/log_toast.dart';
import 'package:chinese_font_library/chinese_font_library.dart';
import 'package:flutter/cupertino.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:pull_down_button/pull_down_button.dart';

final PagingController<int, MusicListW> _pagingController =
    PagingController(firstPageKey: 1);
final TextEditingController _inputContentController = TextEditingController();

class SearchMusicListPage extends StatefulWidget {
  const SearchMusicListPage({super.key});

  @override
  _SearchMusicListState createState() => _SearchMusicListState();
}

class _SearchMusicListState extends State<SearchMusicListPage>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pagingController.addPageRequestListener((pageKey) {
      _fetchMusicLists(pageKey);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    setState(() {});
  }

  Future<void> _fetchAllMusicLists() async {
    while (_pagingController.nextPageKey != null) {
      await _fetchMusicLists(_pagingController.nextPageKey!);
    }
  }

  Future<void> _fetchMusicLists(int pageKey) async {
    try {
      if (_inputContentController.value.text.isEmpty) {
        _pagingController.appendLastPage([]);
      }
      var musiclists = await OnlineFactoryW.searchMusiclist(
          sources: [sourceAll],
          content: _inputContentController.value.text,
          page: pageKey,
          limit: 30);
      if (musiclists.isEmpty) {
        _pagingController.appendLastPage([]);
      } else {
        _pagingController.appendPage(musiclists, pageKey + 1);
      }
    } catch (error) {
      _pagingController.error = error;
    }
  }

  @override
  Widget build(BuildContext context) {
    final double screenHeight = MediaQuery.of(context).size.height;
    final bool isDarkMode =
        MediaQuery.of(context).platformBrightness == Brightness.dark;

    return CupertinoPageScaffold(
        backgroundColor: getPrimaryBackgroundColor(isDarkMode),
        child: Column(
          children: [
            CupertinoNavigationBar(
                backgroundColor: getNavigatorBarColor(isDarkMode),
                leading: Padding(
                  padding: const EdgeInsets.only(left: 0.0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '搜索歌单',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
                        color: isDarkMode
                            ? CupertinoColors.white
                            : CupertinoColors.black,
                      ).useSystemChineseFont(),
                    ),
                  ),
                ),
                trailing: SearchMusicListChoiceMenu(
                  builder: (BuildContext context,
                          Future<void> Function() showMenu) =>
                      CupertinoButton(
                          padding: const EdgeInsets.all(0),
                          onPressed: showMenu,
                          child: Text(
                            '选项',
                            style: TextStyle(color: activeIconRed)
                                .useSystemChineseFont(),
                          )),
                  fetchAllMusicAggregators: _fetchAllMusicLists,
                  openShareMusicList: () async {
                    var url = await showInputPlaylistShareLinkDialog(context);
                    if (url != null) {
                      var result = await OnlineFactoryW.getMusiclistFromShare(
                          shareUrl: url);
                      var musicListW = result.$1;
                      var musicAggregators = result.$2;
                      if (context.mounted) {
                        globalSetNavItemSelected("");
                        globalNavigatorToPage(DesktopOnlineMusicListPage(
                            musicList: musicListW,
                            firstPageMusicAggregators: musicAggregators));
                      }
                    }
                  },
                  musicListController: _pagingController,
                )),
            Padding(
              padding: const EdgeInsets.only(left: 8.0, right: 8.0, top: 10.0),
              child: CupertinoSearchTextField(
                style: TextStyle(
                  color: isDarkMode
                      ? CupertinoColors.white
                      : CupertinoColors.black,
                ).useSystemChineseFont(),
                controller: _inputContentController,
                onSubmitted: (String value) {
                  if (value.isNotEmpty) {
                    _pagingController.refresh();
                  }
                },
              ),
            ),
            Expanded(
                child: PagedGridView(
              padding: EdgeInsets.only(bottom: screenHeight * 0.2),
              pagingController: _pagingController,
              builderDelegate: PagedChildBuilderDelegate<MusicListW>(
                  noItemsFoundIndicatorBuilder: (context) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '输入关键词以搜索歌单',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isDarkMode
                              ? CupertinoColors.systemGrey2
                              : CupertinoColors.black,
                        ).useSystemChineseFont(),
                      ),
                      Text(
                        '点击右上角图标切换搜索单曲',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                                color: isDarkMode
                                    ? CupertinoColors.systemGrey2
                                    : CupertinoColors.black)
                            .useSystemChineseFont(),
                      ),
                    ],
                  ),
                );
              }, itemBuilder: (context, musicListW, index) {
                return Container(
                    padding: const EdgeInsets.only(left: 10, right: 10),
                    child: MusicListImageCard(
                      showDesc: false,
                      musicListW: musicListW,
                      onTap: () {
                        globalSetNavItemSelected("");
                        globalNavigatorToPage(
                            DesktopOnlineMusicListPage(musicList: musicListW));
                      },
                      online: true,
                    ));
              }),
              gridDelegate: const SliverGridDelegateWithResponsiveColumnCount(
                minColumnWidth: 200.0,
                mainAxisSpacing: 10.0,
                crossAxisSpacing: 10.0,
                minColumnCount: 4,
                maxColumnCount: 8,
              ),
            )),
          ],
        ));
  }
}

@immutable
class SearchMusicListChoiceMenu extends StatelessWidget {
  const SearchMusicListChoiceMenu({
    super.key,
    required this.builder,
    required this.openShareMusicList,
    required this.fetchAllMusicAggregators,
    required this.musicListController,
  });

  final void Function() openShareMusicList;
  final Future<void> Function() fetchAllMusicAggregators;
  final PagingController<int, MusicListW> musicListController;
  final PullDownMenuButtonBuilder builder;

  @override
  Widget build(BuildContext context) {
    return PullDownButton(
      itemBuilder: (context) => [
        PullDownMenuItem(
          itemTheme: PullDownMenuItemTheme(
              textStyle: const TextStyle().useSystemChineseFont()),
          onTap: openShareMusicList,
          title: '打开歌单链接',
          icon: CupertinoIcons.link,
        ),
        PullDownMenuItem(
          itemTheme: PullDownMenuItemTheme(
              textStyle: const TextStyle().useSystemChineseFont()),
          onTap: () async {
            await fetchAllMusicAggregators();
            LogToast.success(
              "加载所有歌单",
              "已加载所有歌单",
              "[SearchMusicListPage] Succeed to fetch all music lists",
            );
          },
          title: "加载所有歌单",
          icon: CupertinoIcons.music_note_2,
        ),
        PullDownMenuItem(
          itemTheme: PullDownMenuItemTheme(
              textStyle: const TextStyle().useSystemChineseFont()),
          onTap: () async {
            LogToast.info(
              "多选操作",
              "多选操作,正在加载所有歌单",
              "[SearchMusicListPage] Multi select operation, wait to fetch all music lists",
            );
            await fetchAllMusicAggregators();

            if (musicListController.itemList == null) return;
            if (musicListController.itemList!.isEmpty) return;
            if (context.mounted) {
              globalSetNavItemSelected("");
              globalNavigatorToPage(
                DesktopMutiSelectLocalMusicListGridPage(
                  musicLists: musicListController.itemList!,
                ),
              );
            }
          },
          title: '多选操作',
          icon: CupertinoIcons.selection_pin_in_out,
        ),
      ],
      position: PullDownMenuPosition.automatic,
      buttonBuilder: builder,
    );
  }
}
