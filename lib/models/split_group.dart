import 'package:hive/hive.dart';

class Participant {
  final String id;
  final String name;
  final int avatarColorValue;

  Participant({
    required this.id,
    required this.name,
    required this.avatarColorValue,
  });

  static Participant fromMap(Map<dynamic, dynamic> map) {
    return Participant(
      id: map['id'] as String,
      name: map['name'] as String,
      avatarColorValue: map['avatarColorValue'] as int,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'avatarColorValue': avatarColorValue,
  };

  Participant copyWith({String? id, String? name, int? avatarColorValue}) {
    return Participant(
      id: id ?? this.id,
      name: name ?? this.name,
      avatarColorValue: avatarColorValue ?? this.avatarColorValue,
    );
  }
}

class SplitGroup extends HiveObject {
  final String id;
  String name;
  List<Participant> participants;
  final DateTime createdAt;

  SplitGroup({
    required this.id,
    required this.name,
    required this.participants,
    required this.createdAt,
  });

  SplitGroup copyWith({
    String? id,
    String? name,
    List<Participant>? participants,
    DateTime? createdAt,
  }) {
    return SplitGroup(
      id: id ?? this.id,
      name: name ?? this.name,
      participants: participants ?? List.from(this.participants),
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class SplitGroupAdapter extends TypeAdapter<SplitGroup> {
  @override
  final int typeId = 7;

  @override
  SplitGroup read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    final participantsList = (fields[2] as List)
        .map((e) => Participant.fromMap(e as Map<dynamic, dynamic>))
        .toList();
    return SplitGroup(
      id: fields[0] as String,
      name: fields[1] as String,
      participants: participantsList,
      createdAt: fields[3] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, SplitGroup obj) {
    writer.writeByte(4);
    writer.writeByte(0); writer.write(obj.id);
    writer.writeByte(1); writer.write(obj.name);
    writer.writeByte(2); writer.write(obj.participants.map((p) => p.toMap()).toList());
    writer.writeByte(3); writer.write(obj.createdAt);
  }
}
