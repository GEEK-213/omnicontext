import 'package:objectbox/objectbox.dart';

@Entity()
class CodeChunk {
  @Id()
  int id = 0;

  @Index()
  String filePath;

  String content;

  // Gemini text-embedding-004 uses 768 dimensions
  @HnswIndex(dimensions: 768)
  @Property(type: PropertyType.floatVector)
  List<double> embedding;

  CodeChunk({
    this.id = 0,
    required this.filePath,
    required this.content,
    required this.embedding,
  });
}
