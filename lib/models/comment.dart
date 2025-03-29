class Comment {
  final String id;
  final String text;
  final String? timestamp;
  final String userId;
  final String userName;

  Comment({
    required this.id,
    required this.text,
    this.timestamp,
    required this.userId,
    required this.userName,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['id'] ?? '',
      text: json['text'] ?? '',
      timestamp: json['timestamp'],
      userId: json['user_id'] ?? '',
      userName: json['user_name'] ?? 'Anonymous',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'username': userName,
      'createdAt': timestamp,
      // Add any other properties your Comment class has
    };
  }
}
