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
}

class SplitGroup extends HiveObject {
  final String id;
  String name;
  List<Participant> participants;
  final DateTime createdAt;

  /// Optional id of the participant treated as "me" for balance purposes.
  ///
  /// Null (the default, and the state of every group written before this
  /// field existed) means "first participant", exactly the old heuristic.
  /// Stored as an OPTIONAL trailing Hive field (id 4) so old payloads that
  /// only contain fields 0-3 read back with null — no typeId change, no
  /// field renumber, no migration. Conversely, old app versions opening
  /// new data ignore the unknown field 4 (the generated-style read loop
  /// below collects fields generically), so no corruption either way.
  String? myParticipantId;

  SplitGroup({
    required this.id,
    required this.name,
    required this.participants,
    required this.createdAt,
    this.myParticipantId,
  });

  /// Resolved "me": the stored id when it still names a member, otherwise
  /// the first participant (legacy behavior). Null when the group is empty.
  String? get meParticipantId {
    if (participants.isEmpty) return null;
    if (myParticipantId != null &&
        participants.any((p) => p.id == myParticipantId)) {
      return myParticipantId;
    }
    return participants.first.id;
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
      // Null-tolerant: payloads written before field 4 existed have no
      // entry here, so legacy groups load as myParticipantId == null
      // (first-participant behavior). Never renumber 0-3.
      myParticipantId: fields[4] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, SplitGroup obj) {
    writer.writeByte(5);
    writer.writeByte(0); writer.write(obj.id);
    writer.writeByte(1); writer.write(obj.name);
    writer.writeByte(2); writer.write(obj.participants.map((p) => p.toMap()).toList());
    writer.writeByte(3); writer.write(obj.createdAt);
    writer.writeByte(4); writer.write(obj.myParticipantId);
  }
}
