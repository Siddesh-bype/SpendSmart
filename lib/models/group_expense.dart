import 'package:hive/hive.dart';

class ParticipantShare {
  final String participantId;
  double amount;

  ParticipantShare({
    required this.participantId,
    required this.amount,
  });

  static ParticipantShare fromMap(Map<dynamic, dynamic> map) {
    return ParticipantShare(
      participantId: map['participantId'] as String,
      amount: (map['amount'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toMap() => {
    'participantId': participantId,
    'amount': amount,
  };
}

class GroupExpense extends HiveObject {
  final String id;
  final String groupId;
  String description;
  double totalAmount;
  String paidBy; // participant id
  List<ParticipantShare> shares;
  DateTime date;
  String note;
  bool isSettled;

  GroupExpense({
    required this.id,
    required this.groupId,
    required this.description,
    required this.totalAmount,
    required this.paidBy,
    required this.shares,
    required this.date,
    this.note = '',
    this.isSettled = false,
  });

  GroupExpense copyWith({
    String? id,
    String? groupId,
    String? description,
    double? totalAmount,
    String? paidBy,
    List<ParticipantShare>? shares,
    DateTime? date,
    String? note,
    bool? isSettled,
  }) {
    return GroupExpense(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      description: description ?? this.description,
      totalAmount: totalAmount ?? this.totalAmount,
      paidBy: paidBy ?? this.paidBy,
      shares: shares ?? List.from(this.shares),
      date: date ?? this.date,
      note: note ?? this.note,
      isSettled: isSettled ?? this.isSettled,
    );
  }
}

class GroupExpenseAdapter extends TypeAdapter<GroupExpense> {
  @override
  final int typeId = 8;

  @override
  GroupExpense read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    final sharesList = (fields[5] as List)
        .map((e) => ParticipantShare.fromMap(e as Map<dynamic, dynamic>))
        .toList();
    return GroupExpense(
      id: fields[0] as String,
      groupId: fields[1] as String,
      description: fields[2] as String,
      totalAmount: (fields[3] as num).toDouble(),
      paidBy: fields[4] as String,
      shares: sharesList,
      date: fields[6] as DateTime,
      note: fields[7] as String? ?? '',
      isSettled: fields[8] as bool? ?? false,
    );
  }

  @override
  void write(BinaryWriter writer, GroupExpense obj) {
    writer.writeByte(9);
    writer.writeByte(0); writer.write(obj.id);
    writer.writeByte(1); writer.write(obj.groupId);
    writer.writeByte(2); writer.write(obj.description);
    writer.writeByte(3); writer.write(obj.totalAmount);
    writer.writeByte(4); writer.write(obj.paidBy);
    writer.writeByte(5); writer.write(obj.shares.map((s) => s.toMap()).toList());
    writer.writeByte(6); writer.write(obj.date);
    writer.writeByte(7); writer.write(obj.note);
    writer.writeByte(8); writer.write(obj.isSettled);
  }
}
