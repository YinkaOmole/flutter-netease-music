import 'package:quiet/repository.dart';
import 'package:riverpod/riverpod.dart';

final homePlaylistProvider = FutureProvider((ref) async {
  final list = await neteaseRepository!.personalizedPlaylist(limit: 6);
  return list.asFuture;
});
