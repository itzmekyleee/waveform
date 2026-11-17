import 'package:hive/hive.dart';

class Playlist extends HiveObject {
  String id;
  String name;
  List<int> songIds;
  DateTime dateCreated;
  DateTime dateModified;

  Playlist({
    required this.id,
    required this.name,
    List<int>? songIds,
    DateTime? dateCreated,
    DateTime? dateModified,
  })  : songIds = songIds ?? [],
        dateCreated = dateCreated ?? DateTime.now(),
        dateModified = dateModified ?? DateTime.now();

  int get songCount => songIds.length;

  Playlist copyWith({
    String? id,
    String? name,
    List<int>? songIds,
    DateTime? dateCreated,
    DateTime? dateModified,
  }) {
    return Playlist(
      id: id ?? this.id,
      name: name ?? this.name,
      songIds: songIds ?? List.from(this.songIds),
      dateCreated: dateCreated ?? this.dateCreated,
      dateModified: dateModified ?? this.dateModified,
    );
  }
}

class PlaylistAdapter extends TypeAdapter<Playlist> {
  @override
  final int typeId = 1;

  @override
  Playlist read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (int i = 0; i < numOfFields; i++) {
      fields[reader.readByte()] = reader.read();
    }
    return Playlist(
      id: fields[0] as String,
      name: fields[1] as String,
      songIds: (fields[2] as List?)?.cast<int>() ?? [],
      dateCreated: fields[3] as DateTime,
      dateModified: fields[4] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, Playlist obj) {
    writer.writeByte(5);
    writer.writeByte(0);
    writer.write(obj.id);
    writer.writeByte(1);
    writer.write(obj.name);
    writer.writeByte(2);
    writer.write(obj.songIds);
    writer.writeByte(3);
    writer.write(obj.dateCreated);
    writer.writeByte(4);
    writer.write(obj.dateModified);
  }
}
