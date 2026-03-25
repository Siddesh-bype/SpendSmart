import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/split_group.dart';
import '../providers/group_provider.dart';
import '../utils/constants.dart';

const groupAvatarColors = [
  Color(0xFFE07B6A),
  Color(0xFF29B6F6),
  Color(0xFF26C6DA),
  Color(0xFF4CAF7D),
  Color(0xFFF4A639),
  Color(0xFFAB7FE8),
  Color(0xFF90A4AE),
  Color(0xFFFF7043),
];

class AddGroupSheet extends ConsumerStatefulWidget {
  final SplitGroup? existingGroup;

  const AddGroupSheet({super.key, this.existingGroup});

  @override
  ConsumerState<AddGroupSheet> createState() => _AddGroupSheetState();
}

class _AddGroupSheetState extends ConsumerState<AddGroupSheet> {
  final _nameCtrl = TextEditingController();
  late List<_ParticipantEntry> _participants;
  final _uuid = const Uuid();

  @override
  void initState() {
    super.initState();
    if (widget.existingGroup != null) {
      _nameCtrl.text = widget.existingGroup!.name;
      _participants = widget.existingGroup!.participants
          .map((p) => _ParticipantEntry(
                id: p.id,
                nameCtrl: TextEditingController(text: p.name),
                colorIndex: groupAvatarColors
                    .indexWhere((c) => c.toARGB32() == p.avatarColorValue)
                    .clamp(0, groupAvatarColors.length - 1),
              ))
          .toList();
    } else {
      _participants = [
        _ParticipantEntry(
          id: _uuid.v4(),
          nameCtrl: TextEditingController(),
          colorIndex: 0,
        ),
        _ParticipantEntry(
          id: _uuid.v4(),
          nameCtrl: TextEditingController(),
          colorIndex: 1,
        ),
      ];
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    for (final p in _participants) {
      p.nameCtrl.dispose();
    }
    super.dispose();
  }

  void _addParticipant() {
    setState(() {
      _participants.add(_ParticipantEntry(
        id: _uuid.v4(),
        nameCtrl: TextEditingController(),
        colorIndex: _participants.length % groupAvatarColors.length,
      ));
    });
  }

  void _removeParticipant(int index) {
    if (_participants.length <= 2) return;
    setState(() {
      _participants[index].nameCtrl.dispose();
      _participants.removeAt(index);
    });
  }

  void _save() {
    final name = _nameCtrl.text.trim();
    final validParticipants = _participants
        .where((p) => p.nameCtrl.text.trim().isNotEmpty)
        .map((p) => Participant(
              id: p.id,
              name: p.nameCtrl.text.trim(),
              avatarColorValue: groupAvatarColors[p.colorIndex].toARGB32(),
            ))
        .toList();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a group name')),
      );
      return;
    }
    if (validParticipants.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least 2 participants')),
      );
      return;
    }

    final group = SplitGroup(
      id: widget.existingGroup?.id ?? _uuid.v4(),
      name: name,
      participants: validParticipants,
      createdAt: widget.existingGroup?.createdAt ?? DateTime.now(),
    );

    if (widget.existingGroup != null) {
      ref.read(splitGroupProvider.notifier).updateGroup(group);
    } else {
      ref.read(splitGroupProvider.notifier).addGroup(group);
    }

    Navigator.pop(context);
    HapticFeedback.mediumImpact();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditing = widget.existingGroup != null;

    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isEditing ? 'Edit Group' : 'New Group',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Group Name',
                hintText: 'e.g., Trip to Goa, Room Rent',
                prefixIcon: const Icon(Icons.group_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Participants', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                TextButton.icon(
                  onPressed: _addParticipant,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...List.generate(_participants.length, (i) {
              final p = _participants[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          p.colorIndex = (p.colorIndex + 1) % groupAvatarColors.length;
                        });
                      },
                      child: CircleAvatar(
                        radius: 16,
                        backgroundColor: groupAvatarColors[p.colorIndex],
                        child: Text(
                          p.nameCtrl.text.isEmpty ? '?' : p.nameCtrl.text[0].toUpperCase(),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: p.nameCtrl,
                        textCapitalization: TextCapitalization.words,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: 'Name',
                          isDense: true,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                    ),
                    if (_participants.length > 2)
                      IconButton(
                        onPressed: () => _removeParticipant(i),
                        icon: Icon(Icons.close, size: 18, color: Colors.grey.shade400),
                      ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  isEditing ? 'Save Changes' : 'Create Group',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ParticipantEntry {
  final String id;
  final TextEditingController nameCtrl;
  int colorIndex;

  _ParticipantEntry({
    required this.id,
    required this.nameCtrl,
    required this.colorIndex,
  });
}
