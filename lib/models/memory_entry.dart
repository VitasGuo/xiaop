/// 记忆层级
/// L0: 核心身份（companion config）- 每次必加载
/// L1: 长期记忆（沉淀后的认知）- 每次必加载
/// L2: 热记忆（最近2天的对话摘要）- 每次加载
/// L3: 温记忆（3-7天前的记忆）- 按需检索
/// L4: 冷记忆（7天以上）- 仅归档，不主动加载
enum MemoryLevel { l0, l1, l2, l3, l4 }

class MemoryEntry {
  final int? id;
  final String category;
  final String key;
  final String value;
  final int importance;
  final MemoryLevel level;
  final int recallCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  const MemoryEntry({
    this.id,
    required this.category,
    required this.key,
    required this.value,
    this.importance = 1,
    this.level = MemoryLevel.l2,
    this.recallCount = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'category': category,
        'key': key,
        'value': value,
        'importance': importance,
        'level': level.index,
        'recall_count': recallCount,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory MemoryEntry.fromMap(Map<String, dynamic> map) => MemoryEntry(
        id: map['id'] as int?,
        category: map['category'] as String,
        key: map['key'] as String,
        value: map['value'] as String,
        importance: map['importance'] as int? ?? 1,
        level: MemoryLevel.values[map['level'] as int? ?? 2],
        recallCount: map['recall_count'] as int? ?? 0,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );

  MemoryEntry copyWith({
    int? id,
    String? category,
    String? key,
    String? value,
    int? importance,
    MemoryLevel? level,
    int? recallCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      MemoryEntry(
        id: id ?? this.id,
        category: category ?? this.category,
        key: key ?? this.key,
        value: value ?? this.value,
        importance: importance ?? this.importance,
        level: level ?? this.level,
        recallCount: recallCount ?? this.recallCount,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}
