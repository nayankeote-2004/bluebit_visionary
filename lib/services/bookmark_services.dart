import 'package:flutter/foundation.dart';
import 'package:tik_tok_wikipidiea/models/post_content.dart';

class BookmarkService extends ChangeNotifier {
  // Singleton pattern
  static final BookmarkService _instance = BookmarkService._internal();

  factory BookmarkService() {
    return _instance;
  }

  BookmarkService._internal();

  // List of bookmarked posts
  final List<Post> _bookmarkedPosts = [];

  // Get bookmarked posts
  List<Post> get bookmarkedPosts => _bookmarkedPosts;

  // Check if a post is bookmarked
  bool isBookmarked(Post post) {
    return _bookmarkedPosts.any(
      (p) => p.imageUrl == post.imageUrl && p.summary == post.summary,
    );
  }

  // Add a bookmark
  void addBookmark(Post post) {
    if (!isBookmarked(post)) {
      _bookmarkedPosts.add(post);
      notifyListeners();
    }
  }

  // Remove a bookmark
  void removeBookmark(Post post) {
    _bookmarkedPosts.removeWhere(
      (p) => p.imageUrl == post.imageUrl && p.summary == post.summary,
    );
    notifyListeners();
  }

  // Toggle bookmark status
  void toggleBookmark(Post post) {
    if (isBookmarked(post)) {
      removeBookmark(post);
    } else {
      addBookmark(post);
    }
  }
}
