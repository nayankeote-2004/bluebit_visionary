class Post {
  final String image;
  final String description;
  final String source;
  bool isLiked;
  bool isBookmarked;

  Post({
    required this.image,
    required this.description,
    required this.source,
    this.isLiked = false,
    this.isBookmarked = false,
  });
}