class Post {
  final String image;
  final String description;
  final String source;
  bool isLiked;

  Post({
    required this.image,
    required this.description,
    required this.source,
    this.isLiked = false,
  });
}
