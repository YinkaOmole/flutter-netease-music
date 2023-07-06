import 'package:async/async.dart';
import 'package:flutter/material.dart';

import '../../component/netease/netease_loader.dart';
import '../../material/tiles.dart';

class CollectionAlbums extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CachedLoader<Map>(
      cacheKey: 'album_sublist',
      loadTask: () => Future.value(Result.error('unimplemented')),
      builder: (context, result) {
        final data = result['data'] as List;
        return ListView(
          children: data
              .cast<Map>()
              .map((album) =>
                  AlbumTile(album: album, subtitle: _getAlbumSubtitle))
              .toList(),
        );
      },
    );
  }

  String _getAlbumSubtitle(Map album) {
    final String artists = (album['artists'] as List)
        .cast<Map>()
        .map((artist) => artist['name'])
        .join('/');
    return '$artists ${album['size']}首';
  }
}
