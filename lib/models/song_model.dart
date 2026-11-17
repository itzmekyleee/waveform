import 'package:hive/hive.dart';

class Song extends HiveObject {
  int id;
  String title;
  String artist;
  String album;
  String genre;
  int durationMs;
  String filePath;
  String? contentUri;
  int? albumId;
  DateTime dateAdded;
  int fileSize;
  int playCount;
  DateTime? lastPlayed;

  Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.genre,
    required this.durationMs,
    required this.filePath,
    this.contentUri,
    this.albumId,
    required this.dateAdded,
    required this.fileSize,
    this.playCount = 0,
    this.lastPlayed,
  });

    Duration get duration => Duration(milliseconds: durationMs);

  Song copyWith({
    int? id,
    String? title,
    String? artist,
    String? album,
    String? genre,
    int? durationMs,
    String? filePath,
    String? contentUri,
    int? albumId,
    DateTime? dateAdded,
    int? fileSize,
    int? playCount,
    DateTime? lastPlayed,
  }) {
    return Song(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      genre: genre ?? this.genre,
      durationMs: durationMs ?? this.durationMs,
      filePath: filePath ?? this.filePath,
      contentUri: contentUri ?? this.contentUri,
      albumId: albumId ?? this.albumId,
      dateAdded: dateAdded ?? this.dateAdded,
      fileSize: fileSize ?? this.fileSize,
      playCount: playCount ?? this.playCount,
      lastPlayed: lastPlayed ?? this.lastPlayed,
    );
  }

  String get displayTitle => title.isEmpty ? 'Unknown Title' : title;
  String get displayArtist => artist.isEmpty ? 'Unknown Artist' : artist;
  String get displayAlbum => album.isEmpty ? 'Unknown Album' : album;

  @override
  String toString() => 'Song(id: $id, title: $displayTitle, artist: $displayArtist)';
}

class SongAdapter extends TypeAdapter<Song> {
  @override
  final int typeId = 0;

  @override
  Song read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (int i = 0; i < numOfFields; i++) {
      fields[reader.readByte()] = reader.read();
    }
    return Song(
      id: fields[0] as int,
      title: fields[1] as String,
      artist: fields[2] as String,
      album: fields[3] as String,
      genre: fields[4] as String,
      durationMs: fields[5] as int,
      filePath: fields[6] as String,
      contentUri: fields[12] as String?,
      albumId: fields[7] as int?,
      dateAdded: fields[8] as DateTime,
      fileSize: fields[9] as int,
      playCount: fields[10] as int? ?? 0,
      lastPlayed: fields[11] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, Song obj) {
    writer.writeByte(13);
    writer.writeByte(0);
    writer.write(obj.id);
    writer.writeByte(1);
    writer.write(obj.title);
    writer.writeByte(2);
    writer.write(obj.artist);
    writer.writeByte(3);
    writer.write(obj.album);
    writer.writeByte(4);
    writer.write(obj.genre);
    writer.writeByte(5);
    writer.write(obj.durationMs);
    writer.writeByte(6);
    writer.write(obj.filePath);
    writer.writeByte(7);
    writer.write(obj.albumId);
    writer.writeByte(8);
    writer.write(obj.dateAdded);
    writer.writeByte(9);
    writer.write(obj.fileSize);
    writer.writeByte(10);
    writer.write(obj.playCount);
    writer.writeByte(11);
    writer.write(obj.lastPlayed);
    writer.writeByte(12);
    writer.write(obj.contentUri);
  }
}
