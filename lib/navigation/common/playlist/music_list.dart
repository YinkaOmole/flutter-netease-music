import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:overlay_support/overlay_support.dart';
import 'package:quiet/extension.dart';
import 'package:quiet/media/tracks/track_list.dart';
import 'package:quiet/media/tracks/tracks_player.dart';
import 'package:quiet/pages/comments/page_comment.dart';
import 'package:quiet/providers/player_provider.dart';
import 'package:quiet/repository.dart';

import '../../mobile/playlists/dialog_selector.dart';

enum PlayResult {
  success,
  alreadyPlaying,
  fail,
}

class TrackTileContainer extends StatelessWidget {
  factory TrackTileContainer.playlist({
    required PlaylistDetail playlist,
    required Widget child,
    required TracksPlayer player,
  }) {
    final id = 'playlist_${playlist.id}';
    return TrackTileContainer._private(
      (track) {
        if (player.trackList.id == id &&
            player.isPlaying &&
            player.current == track) {
          return PlayResult.alreadyPlaying;
        } else {
          player
            ..setTrackList(TrackList(
              id: id,
              tracks: playlist.tracks
                  .whereNot((e) => e.type == TrackType.noCopyright)
                  .toList(),
            ))
            ..playFromMediaId(track.id);
          return PlayResult.success;
        }
      },
      (track) {
        // TODO: remove track
      },
      tracks: playlist.tracks,
      id: id,
      child: child,
    );
  }

  const TrackTileContainer._private(
    this._playbackMusic,
    this._deleteMusic, {
    Key? key,
    required this.tracks,
    required this.id,
    required this.child,
  }) : super(key: key);

  static PlayResult playTrack(
    BuildContext context,
    Track track,
  ) {
    final container =
        context.findAncestorWidgetOfExactType<TrackTileContainer>();
    assert(container != null, 'container is null');
    if (container == null) {
      return PlayResult.fail;
    }
    return container._playbackMusic(track);
  }

  static String getPlaylistId(BuildContext context) {
    final container =
        context.findAncestorWidgetOfExactType<TrackTileContainer>();
    assert(container != null, 'container is null');
    if (container == null) {
      return '';
    }
    return container.id;
  }

  static void deleteTrack(BuildContext context, Track track) {
    final container =
        context.findAncestorWidgetOfExactType<TrackTileContainer>();
    assert(container != null, 'container is null');
    if (container == null) {
      return;
    }
    container._deleteMusic(track);
  }

  final List<Track> tracks;

  final String id;

  final Widget child;

  final PlayResult Function(Track) _playbackMusic;

  final void Function(Track) _deleteMusic;

  @override
  Widget build(BuildContext context) => child;
}

class MusicTileConfiguration extends StatelessWidget {
  const MusicTileConfiguration({
    Key? key,
    this.token,
    required this.musics,
    this.onMusicTap = MusicTileConfiguration.defaultOnTap,
    this.child,
    this.leadingBuilder = MusicTileConfiguration.indexedLeadingBuilder,
    this.trailingBuilder = MusicTileConfiguration.defaultTrailingBuilder,
    this.supportAlbumMenu = true,
    this.remove,
  }) : super(key: key);

  static MusicTileConfiguration of(BuildContext context) {
    final list =
        context.findAncestorWidgetOfExactType<MusicTileConfiguration>();
    assert(list != null, 'you can only use [MusicTile] inside MusicList scope');
    return list!;
  }

  static Widget defaultTrailingBuilder(BuildContext context, Music music) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[IconMV(music), _IconMore(music)],
    );
  }

  static Widget indexedLeadingBuilder(BuildContext context, Music music) {
    final int index =
        MusicTileConfiguration.of(context).musics.indexOf(music) + 1;
    return _buildPlayingLeading(context, music) ??
        Container(
          margin: const EdgeInsets.only(left: 8, right: 8),
          width: 40,
          height: 40,
          child: Center(
            child: Text(
              index.toString(),
              style: Theme.of(context).textTheme.bodyText1,
            ),
          ),
        );
  }

  static Widget coverLeadingBuilder(BuildContext context, Music music) {
    return _buildPlayingLeading(context, music) ??
        Container(
          margin: const EdgeInsets.only(left: 8, right: 8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: FadeInImage(
              width: 40,
              height: 40,
              fit: BoxFit.cover,
              image: CachedImage(music.imageUrl?.toString() ?? ""),
              placeholder: const AssetImage("assets/playlist_playlist.9.png"),
            ),
          ),
        );
  }

  //return null if current music is not be playing
  static Widget? _buildPlayingLeading(BuildContext context, Music music) {
    // TODO remove this.
    return null;
  }

  static void defaultOnTap(BuildContext context, Music music) {
    // TODO remove this.
  }

  final String? token;

  final List<Music> musics;

  final void Function(BuildContext context, Music muisc) onMusicTap;

  final Widget Function(BuildContext context, Music music) leadingBuilder;

  final Widget Function(BuildContext context, Music music) trailingBuilder;

  final bool supportAlbumMenu;

  final void Function(Music music)? remove;

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return child!;
  }
}

/// music item widget
class MusicTile extends StatelessWidget {
  const MusicTile(this.music, {Key? key}) : super(key: key);
  final Music music;

  @override
  Widget build(BuildContext context) {
    final list = MusicTileConfiguration.of(context);
    return SizedBox(
      height: 56,
      child: InkWell(
        onTap: () {
          list.onMusicTap.call(context, music);
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            (list.leadingBuilder)(context, music),
            Expanded(
              child: _SimpleMusicTile(music),
            ),
            (list.trailingBuilder)(context, music),
          ],
        ),
      ),
    );
  }
}

class _SimpleMusicTile extends StatelessWidget {
  const _SimpleMusicTile(this.music, {Key? key}) : super(key: key);
  final Music music;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Row(
        children: <Widget>[
          Expanded(
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: <Widget>[
              const Spacer(),
              Text(
                music.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyText2,
              ),
              const Padding(padding: EdgeInsets.only(top: 3)),
              Text(
                music.displaySubtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.caption,
              ),
              const Spacer(),
            ],
          )),
        ],
      ),
    );
  }
}

/// The header view of MusicList
class MusicListHeader extends ConsumerWidget implements PreferredSizeWidget {
  const MusicListHeader(this.count, {this.tail});

  final int count;

  final Widget? tail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: context.colorScheme.background,
      child: InkWell(
        onTap: () {
          final player = ref.read(playerProvider);
          final state = ref.read(playerStateProvider);
          final list = MusicTileConfiguration.of(context);
          if (state.playingList.id == list.token && state.isPlaying) {
            //open playing page
            Navigator.pushNamed(context, pagePlaying);
          } else {
            player
              ..setTrackList(TrackList(id: list.token!, tracks: list.musics))
              ..play();
          }
        },
        child: SizedBox.fromSize(
          size: preferredSize,
          child: Row(
            children: [
              const SizedBox(width: 16),
              Icon(
                Icons.play_circle_rounded,
                color: context.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                context.strings.playAll,
                style: context.textTheme.titleSmall,
              ),
              const SizedBox(width: 6),
              Text(
                '(${context.strings.musicCountFormat(count)})',
                style: Theme.of(context).textTheme.caption,
              ),
              const Spacer(),
              if (tail != null) tail!,
            ],
          ),
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(50);
}

class IconMV extends StatelessWidget {
  const IconMV(this.music, {Key? key}) : super(key: key);
  final Music music;

  @override
  Widget build(BuildContext context) {
    // TODO add MV.
    return Container();
  }
}

enum _MusicAction {
  addToNext,
  comment,
  delete,

  ///添加到歌单
  addToPlaylist,

  ///导航到专辑
  album,

  ///导航到歌手
  artists,
}

class _IconMore extends ConsumerWidget {
  const _IconMore(this.music, {Key? key}) : super(key: key);
  final Music music;

  List<PopupMenuItem> _buildMenu(BuildContext context) {
    final items = [
      const PopupMenuItem(
        value: _MusicAction.addToNext,
        child: Text("下一首播放"),
      ),
      const PopupMenuItem(
        value: _MusicAction.addToPlaylist,
        child: Text("收藏到歌单"),
      ),
      const PopupMenuItem(
        value: _MusicAction.comment,
        child: Text("评论"),
      ),
    ];

    items.add(PopupMenuItem(
        enabled: music.artists.fold(0, (dynamic c, ar) => c + ar.id) != 0,
        value: _MusicAction.artists,
        child: Text("歌手: ${music.artists.map((a) => a.name).join('/')}",
            maxLines: 1)));

    if (MusicTileConfiguration.of(context).supportAlbumMenu) {
      items.add(const PopupMenuItem(
        value: _MusicAction.album,
        child: Text("专辑"),
      ));
    }
    if (MusicTileConfiguration.of(context).remove != null) {
      items.add(const PopupMenuItem(
        value: _MusicAction.delete,
        child: Text("删除"),
      ));
    }
    return items;
  }

  Future<void> _handleMusicAction(
    BuildContext context,
    _MusicAction type,
    WidgetRef ref,
  ) async {
    switch (type) {
      case _MusicAction.addToNext:
        ref.read(playerProvider).insertToNext(music);
        break;
      case _MusicAction.comment:
        Navigator.push(context, MaterialPageRoute(builder: (context) {
          return CommentPage(
            threadId: CommentThreadId(music.id, CommentType.song),
            payload: CommentThreadPayload.music(music),
          );
        }));
        break;
      case _MusicAction.delete:
        MusicTileConfiguration.of(context).remove!(music);
        break;
      case _MusicAction.addToPlaylist:
        final id = await showDialog(
            context: context,
            builder: (context) {
              return const PlaylistSelectorDialog();
            });
        if (id != null) {
          final bool succeed = await neteaseRepository!
              .playlistTracksEdit(PlaylistOperation.add, id, [music.id]);
          final scaffold = Scaffold.maybeOf(context);
          if (scaffold == null) {
            //not notify when scaffold is empty
            return;
          }
          if (succeed) {
            showSimpleNotification(const Text("已添加到收藏"));
          } else {
            showSimpleNotification(const Text("收藏歌曲失败!"),
                leading: const Icon(Icons.error),
                background: Theme.of(context).errorColor);
          }
        }
        break;
      case _MusicAction.album:
        // Navigator.of(context).push(MaterialPageRoute(builder: (context) {
        //   return AlbumDetailPage(albumId: music.album!.id.parseToInt());
        // }));
        break;
      case _MusicAction.artists:
        // launchArtistDetailPage(context, music.artists);
        break;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton(
      icon: const Icon(Icons.more_vert),
      itemBuilder: _buildMenu,
      onSelected: (dynamic type) => _handleMusicAction(context, type, ref),
    );
  }
}
