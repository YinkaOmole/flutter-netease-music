import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:async/async.dart' show Result, ErrorResult;
import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter/cupertino.dart';
import 'package:netease_music_api/netease_cloud_music.dart' as api;

import '../netease_api.dart';

///enum for NeteaseRepository.search param type
class SearchType {
  const SearchType._(this.type);

  final int type;

  static const SearchType song = SearchType._(1);
  static const SearchType album = SearchType._(10);
  static const SearchType artist = SearchType._(100);
  static const SearchType playlist = SearchType._(1000);
  static const SearchType user = SearchType._(1002);
  static const SearchType mv = SearchType._(1004);
  static const SearchType lyric = SearchType._(1006);
  static const SearchType dj = SearchType._(1009);
  static const SearchType video = SearchType._(1014);
}

enum PlaylistOperation { add, remove }

enum PlayRecordType {
  allData,
  weekData,
}

const _kCodeSuccess = 200;

const kCodeNeedLogin = 301;

///map a result to any other
Result<R> _map<R>(
  Result<Map<String, dynamic>> source,
  R Function(Map<String, dynamic> t) f,
) {
  if (source.isError) return source.asError!;
  try {
    return Result.value(f(source.asValue!.value));
  } catch (e, s) {
    return Result.error(e, s);
  }
}

extension _ResultMapExtension<T> on Result<T> {
  Result<R> map<R>(R Function(T value) transform) {
    if (isError) return asError!;
    try {
      return Result.value(transform(asValue!.value));
    } catch (e, s) {
      debugPrint('error to transform: ${asValue!.value}');
      return Result.error(e, s);
    }
  }
}

extension _FutureMapExtension<T> on Future<Result<T>> {
  Future<Result<R>> map<R>(R Function(T value) transform) {
    return then((value) => value.map(transform));
  }
}

typedef OnRequestError = void Function(ErrorResult error);

class Repository {
  Repository(String cookiePath, {this.onError}) {
    api.debugPrint = debugPrint;
    scheduleMicrotask(() async {
      PersistCookieJar? cookieJar;
      try {
        cookieJar = PersistCookieJar(storage: FileStorage(cookiePath));
      } catch (e) {
        debugPrint('error: can not create persist cookie jar');
      }
      _cookieJar.complete(cookieJar);
    });
  }

  final Completer<PersistCookieJar> _cookieJar = Completer();

  final OnRequestError? onError;

  Future<List<Cookie>> _loadCookies() async {
    final jar = await _cookieJar.future;
    final uri = Uri.parse('http://music.163.com');
    return jar.loadForRequest(uri);
  }

  Future<void> _saveCookies(List<Cookie> cookies) async {
    final jar = await _cookieJar.future;
    await jar.saveFromResponse(Uri.parse('http://music.163.com'), cookies);
  }

  ///????????????????????????
  Future<Result<Map>> login(String? phone, String password) async {
    return doRequest(
      '/login/cellphone',
      {'phone': phone, 'password': password},
    );
  }

  Future<Result<Map>> loginQrKey() {
    return doRequest('/login/qr/key');
  }

  /// 800: qrcode is expired
  /// 801: wait for qrcode to be scanned
  /// 802: qrcode is waiting for approval
  /// 803: qrcode is approved
  Future<int> loginQrCheck(String key) async {
    try {
      final ret =
          await (await doRequest('/login/qr/check', {'key': key})).asFuture;
      debugPrint('login qr check: $ret');
    } on RequestError catch (error) {
      if (error.code == 803) {
        await _saveCookies(error.answer.cookie);
      }
      return error.code;
    }
    throw Exception('unknown error');
  }

  ///??????????????????
  ///???????????????true ??????????????????
  ///         false ??????????????????
  Future<bool> refreshLogin() async {
    final result = await doRequest('/login/refresh');
    return result.isValue;
  }

  Future<Map> loginStatus() async {
    final result = await doRequest('/login/status');
    return result.asFuture;
  }

  ///??????,????????????cookie??????
  Future<void> logout() async {
    //??????cookie
    await _cookieJar.future.then((v) => v.deleteAll());
  }

  ///PlayListDetail ?????? tracks ???????????????
  Future<Result<UserPlayList>> userPlaylist(
    int? userId, {
    int offset = 0,
    int limit = 1000,
  }) async {
    final response = await doRequest(
      '/user/playlist',
      {'offset': offset, 'uid': userId, 'limit': limit},
    );
    return _map(response, (result) => UserPlayList.fromJson(result));
  }

  ///create new playlist by [name]
  Future<Result<PlayListDetail>?> createPlaylist(
    String? name, {
    bool privacy = false,
  }) async {
    final response = await doRequest(
      '/playlist/create',
      {'name': name, 'privacy': privacy ? 10 : null},
    );
    return _map(
      response,
      (result) => PlayListDetail.fromJson(result['playlist']),
    );
  }

  ///????????????id?????????????????????????????????
  ///
  /// [s] ??????????????? s ????????????
  Future<Result<PlayListDetail>> playlistDetail(int id, {int s = 5}) async {
    final response = await doRequest('/playlist/detail', {'id': '$id', 's': s});
    return _map(response, (t) => PlayListDetail.fromJson(t));
  }

  ///id ??????id
  ///return true if action success
  Future<bool> playlistSubscribe(int? id, {required bool subscribe}) async {
    final response = await doRequest(
      '/playlist/subscribe',
      {'id': id, 't': subscribe ? 1 : 2},
    );
    return response.isValue;
  }

  ///????????????????????????
  Future<Result<AlbumDetail>> albumDetail(int id) async {
    final response = await doRequest('/album', {'id': id});
    return _map(response, (t) => AlbumDetail.fromJson(t));
  }

  ///????????????
  Future<Result<Personalized>> personalizedPlaylist({
    int limit = 30,
    int offset = 0,
  }) async {
    final response = await doRequest(
      '/personalized',
      {'limit': limit, 'offset': offset, 'total': true, 'n': 1000},
    );
    return _map(response, (t) => Personalized.fromJson(t));
  }

  /// ??????????????????10??????
  Future<Result<PersonalizedNewSong>> personalizedNewSong() async {
    final response = await doRequest('/personalized/newsong');
    return _map(response, (t) => PersonalizedNewSong.fromJson(t));
  }

  /// ????????????
  Future<Result<Map>> topListDetail() async {
    return doRequest('/toplist/detail');
  }

  ///???????????????????????????
  Future<Result<DailyRecommendSongs>> recommendSongs() async {
    final response = await doRequest('/recommend/songs');
    return _map(response, (t) => DailyRecommendSongs.fromJson(t['data']));
  }

  ///????????????id????????????
  Future<String?> lyric(int id) async {
    final result = await doRequest('/lyric', {'id': id});
    if (result.isError) {
      return Future.error(result.asError!.error);
    }
    final Map? lyc = result.asValue!.value['lrc'];
    if (lyc == null) {
      return null;
    }
    return lyc['lyric'];
  }

  ///??????????????????
  Future<Result<List<String>>> searchHotWords() async {
    final result = await doRequest('/search/hot', {'type': 1111});
    return _map(result, (t) {
      final List hots = (t['result'] as Map)['hots'];
      return hots.cast<Map<String, dynamic>>().map((map) {
        return map['first'] as String;
      }).toList();
    });
  }

  ///search by keyword
  Future<Result<Map>> search(
    String? keyword,
    SearchType type, {
    int limit = 20,
    int offset = 0,
  }) {
    return doRequest('/search/cloud', {
      'keywords': keyword,
      'type': type.type,
      'limit': limit,
      'offset': offset
    });
  }

  Future<Result<SearchResultSongs>> searchSongs(
    String keyword, {
    int limit = 20,
    int offset = 0,
  }) async {
    final result =
        await search(keyword, SearchType.song, limit: limit, offset: offset);
    return result.map((t) => SearchResultSongs.fromJson(t['result']));
  }

  ///????????????
  ///????????????????????????????????????????????????null
  Future<Result<List<String>>> searchSuggest(String? keyword) async {
    if (keyword == null || keyword.isEmpty || keyword.trim().isEmpty) {
      return Result.value(const []);
    }
    final response = await doRequest(
      'https://music.163.com/weapi/search/suggest/keyword',
      {'s': keyword.trim()},
    );
    if (response.isError) {
      return Result.value(const []);
    }
    return _map(response, (dynamic t) {
      final match =
          (response.asValue!.value['result']['allMatch'] as List?)?.cast();
      if (match == null) {
        return [];
      }
      return match.map((m) => m['keyword']).cast<String>().toList();
    });
  }

  ///check music is available
  Future<bool> checkMusic(int id) async {
    final result = await doRequest(
      'https://music.163.com/weapi/song/enhance/player/url',
      {'ids': '[$id]', 'br': 999000},
    );
    return result.isValue && result.asValue!.value['data'][0]['code'] == 200;
  }

  Future<Result<String>> getPlayUrl(int id, [int br = 320000]) async {
    final result = await doRequest('/song/url', {'id': id, 'br': br});
    return _map(result, (dynamic result) {
      final data = result['data'] as List;
      if (data.isEmpty) {
        throw Exception('we can not get realtime play url: data is empty');
      }
      final url = data.first['url'] as String;
      if (url.isEmpty) {
        throw Exception('we can not get realtime play url: URL is null');
      }
      return url;
    });
  }

  Future<Result<SongDetail>> songDetails(List<int> ids) async {
    final result = await doRequest('/song/detail', {'ids': ids.join(',')});
    return _map(result, (result) => SongDetail.fromJson(result));
  }

  ///edit playlist tracks
  ///true : succeed
  Future<bool> playlistTracksEdit(
    PlaylistOperation operation,
    int playlistId,
    List<int?> musicIds,
  ) async {
    assert(musicIds.isNotEmpty);

    final result = await doRequest('/playlist/tracks', {
      'op': operation == PlaylistOperation.add ? 'add' : 'del',
      'pid': playlistId,
      'tracks': musicIds.join(',')
    });
    return result.isValue;
  }

  ///update playlist name and description
  Future<bool> updatePlaylist({
    required int id,
    required String name,
    required String description,
  }) async {
    final response = await doRequest('/playlist/update', {
      'id': id,
      'name': name,
      'desc': description,
    });
    return _map(response, (dynamic t) {
      return true;
    }).isValue;
  }

  ///???????????????????????????
  Future<Result<ArtistDetail>> artist(int artistId) async {
    final result = await doRequest('/artists', {'id': artistId});
    return _map(result, (t) => ArtistDetail.fromJson(t));
  }

  ///???????????????????????????
  Future<Result<List<Album>>> artistAlbums(
    int artistId, {
    int limit = 10,
    int offset = 0,
  }) async {
    final result = await doRequest('/artist/album', {
      'id': artistId,
      'limit': limit,
      'offset': offset,
      'total': true,
    });
    return _map(result, (t) {
      final hotAlbums = t['hotAlbums'] as List;
      return hotAlbums
          .cast<Map<String, dynamic>>()
          .map((e) => Album.fromJson(e))
          .toList();
    });
  }

  ///???????????????MV??????
  Future<Result<Map>> artistMvs(
    int artistId, {
    int limit = 20,
    int offset = 0,
  }) async {
    return doRequest('/artist/mv', {'id': artistId});
  }

  ///??????????????????
  Future<Result<Map>> artistDesc(int artistId) async {
    return doRequest('/artist/desc', {'id': artistId});
  }

  ///get comments
  Future<Result<Map>> getComments(
    CommentThreadId commentThread, {
    int limit = 20,
    int offset = 0,
  }) async {
    return doRequest(
      '/comment/${commentThread.typePath}',
      {'id': commentThread.id, 'limit': limit, 'offset': offset},
    );
  }

  ///??????????????????
  Future<bool> like(int? musicId, {required bool like}) async {
    final response = await doRequest('/like', {'id': musicId, 'like': like});
    return response.isValue;
  }

  ///????????????????????????id??????
  Future<Result<List<int>>> likedList(int? userId) async {
    final response = await doRequest('/likelist', {'uid': userId});
    return _map(response, (dynamic t) {
      return (t['ids'] as List).cast();
    });
  }

  ///?????????????????? , ??????????????????mv, dj ??????
  Future<Result<MusicCount>> subCount() {
    return doRequest('/user/subcount')
        .map((value) => MusicCount.fromJson(value));
  }

  ///???????????????????????????
  Future<Result<List<Map>>?> userDj(int? userId) async {
    final response =
        await doRequest('/user/dj', {'uid': userId, 'limit': 30, 'offset': 0});
    return _map(response, (dynamic t) {
      return (t['programs'] as List).cast();
    });
  }

  ///???????????????????????? , ??????????????????????????????
  Future<Result<List<Map>>> djSubList() async {
    return _map(await doRequest('/dj/sublist'), (dynamic t) {
      return (t['djRadios'] as List).cast();
    });
  }

  ///???????????? MV ?????? , ???????????? mv ?????? , ?????? , ???????????? , mv ?????????????????????
  Future<Result<MusicVideoDetailResult>> mvDetail(int mvId) {
    return doRequest('/mv/detail', {'mvid': mvId})
        .map((json) => MusicVideoDetailResult.fromJson(json));
  }

  ///???????????????,????????? MV
  Future<bool> mvSubscribe(int? mvId, {required bool subscribe}) async {
    final result =
        await doRequest('/mv/sub', {'id': mvId, 't': subscribe ? '1' : '0'});
    return result.isValue;
  }

  /// ????????????????????????
  Future<Result<List<PlayRecord>>> getRecord(
    int? uid,
    PlayRecordType type,
  ) async {
    final result =
        await doRequest('/user/record', {'uid': uid, 'type': type.index});
    return result.map((value) {
      final records = (value[type.name] as List).cast<Map<String, dynamic>>();
      return records.map((json) => PlayRecord.fromJson(json)).toList();
    });
  }

  ///??????????????????
  Future<Result<UserDetail>> getUserDetail(int uid) async {
    final result = await doRequest('/user/detail', {'uid': uid});
    return _map(result, (t) => UserDetail.fromJson(t));
  }

  ///
  /// ???????????? FM ????????????????????????????????????
  ///
  Future<Result<PersonalFm>> getPersonalFmMusics() async {
    final result = await doRequest('/personal_fm');
    return _map(result, (t) => PersonalFm.fromJson(t));
  }

  Future<Result<CloudMusicDetail>> getUserCloudMusic() async {
    final result = await doRequest(
      '/user/cloud',
      {'limit': 200},
    );
    return result.map((value) => CloudMusicDetail.fromJson(value));
  }

  Future<Result<CellphoneExistenceCheck>> checkPhoneExist(
    String phone,
    String countryCode,
  ) async {
    final result = await doRequest(
      '/cellphone/existence/check',
      {'phone': phone, 'countrycode': countryCode},
    );
    if (result.isError) return result.asError!;
    final value = CellphoneExistenceCheck.fromJson(result.asValue!.value);
    return Result.value(value);
  }

  ///[path] request path
  ///[param] parameter
  Future<Result<Map<String, dynamic>>> doRequest(
    String path, [
    Map param = const {},
  ]) async {
    api.Answer result;
    try {
      // convert all params to string
      final convertedParams =
          param.map((k, v) => MapEntry(k.toString(), v.toString()));
      result = await api.cloudMusicApi(
        path,
        parameter: convertedParams,
        cookie: await _loadCookies(),
      );
    } catch (e, stacktrace) {
      debugPrint('request error : $e \n $stacktrace');
      final result = ErrorResult(e, stacktrace);
      onError?.call(result);
      return result;
    }
    final map = result.body;

    if (result.status == 200) {
      await _saveCookies(result.cookie);
    }
    assert(
      () {
        debugPrint('api request: $path $param');
        debugPrint('api response: ${result.status} ${jsonEncode(result.body)}');
        return true;
      }(),
    );
    if (map['code'] == kCodeNeedLogin) {
      final error = ErrorResult(
        RequestError(
          code: kCodeNeedLogin,
          message: '???????????????????????????~',
          answer: result,
        ),
      );
      onError?.call(error);
      return error;
    } else if (map['code'] != _kCodeSuccess) {
      final error = ErrorResult(
        RequestError(
          code: map['code'],
          message: map['msg'] ?? map['message'] ?? '???????????????~',
          answer: result,
        ),
      );
      onError?.call(error);
      return error;
    }
    return Result.value(map as Map<String, dynamic>);
  }
}
