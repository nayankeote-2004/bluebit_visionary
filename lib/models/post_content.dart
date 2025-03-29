import 'package:tik_tok_wikipidiea/models/comment.dart';

class Section {
  final String title;
  final String content;

  Section({required this.title, required this.content});

  factory Section.fromJson(Map<String, dynamic> json) {
    return Section(
      title: json['title'] != null ? json['title'].toString() : '',
      content: json['content'] != null ? json['content'].toString() : '',
    );
  }

  // Add this method to serialize Section objects
  Map<String, dynamic> toJson() {
    return {'title': title, 'content': content};
  }
}

class Post {
  final int id;
  final String title;
  final String imageUrl;
  final String summary;
  final String domain;
  final String createdAt;
  final String funFact;
  final int readingTime;
  final List<String> relatedTopics;
  final List<Section> sections;
  bool isLiked;
  List<Comment> comments;
  bool isBookmarked;

  Post({
    required this.id,
    required this.title,
    required this.imageUrl,
    required this.summary,
    required this.domain,
    required this.createdAt,
    required this.funFact,
    required this.readingTime,
    required this.relatedTopics,
    required this.sections,
    this.isLiked = false,
    this.comments = const [],
    this.isBookmarked = false,
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    print('------- id : ${json['id']}');
    return Post(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      imageUrl: json['image_url'] ?? '',
      summary: json['summary'] ?? '',
      domain: json['domain'] ?? '',
      createdAt: json['created_at'] ?? '',
      funFact: json['fun_fact'] ?? '',
      readingTime: json['reading_time'] ?? 0,
      relatedTopics: List<String>.from(json['related_topics'] ?? []),
      sections:
          (json['sections'] as List<dynamic>? ?? []).map((section) {
            return Section.fromJson(section);
          }).toList(),
      comments:
          (json['comments'] as List<dynamic>? ?? [])
              .map((comment) => Comment.fromJson(comment))
              .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'image_url': imageUrl,
      'summary': summary,
      'domain': domain,
      'created_at': createdAt,
      'fun_fact': funFact,
      'reading_time': readingTime,
      'related_topics': relatedTopics,
      'sections': sections.map((section) => section.toJson()).toList(),
      'comments': comments.map((comment) => comment.toJson()).toList(),
      'isLiked': isLiked,
      'isBookmarked': isBookmarked,
    };
  }
}
