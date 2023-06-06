// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'track.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Track _$TrackFromJson(Map json) => Track(
      id: json['id'] as int,
      uri: json['uri'] as String?,
      name: json['name'] as String,
      artists: (json['artists'] as List<dynamic>)
          .map((e) => ArtistMini.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      album: json['album'] == null
          ? null
          : AlbumMini.fromJson(Map<String, dynamic>.from(json['album'] as Map)),
      imageUrl: json['imageUrl'] as String?,
    );

Map<String, dynamic> _$TrackToJson(Track instance) => <String, dynamic>{
      'id': instance.id,
      'uri': instance.uri,
      'name': instance.name,
      'artists': instance.artists.map((e) => e.toJson()).toList(),
      'album': instance.album?.toJson(),
      'imageUrl': instance.imageUrl,
    };

ArtistMini _$ArtistMiniFromJson(Map json) => ArtistMini(
      id: json['id'] as String,
      name: json['name'] as String,
      imageUrl: json['imageUrl'] as String?,
    );

Map<String, dynamic> _$ArtistMiniToJson(ArtistMini instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'imageUrl': instance.imageUrl,
    };

AlbumMini _$AlbumMiniFromJson(Map json) => AlbumMini(
      id: json['id'] as String,
      picUri: json['picUrl'] as String?,
      name: json['name'] as String,
    );

Map<String, dynamic> _$AlbumMiniToJson(AlbumMini instance) => <String, dynamic>{
      'id': instance.id,
      'picUrl': instance.picUri,
      'name': instance.name,
    };
