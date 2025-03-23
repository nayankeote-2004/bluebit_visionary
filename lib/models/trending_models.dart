class TrendingArticle {
  final int id;
  final String title;
  final String domain;
  final int commentCount;
  final int likes;
  final int engagementScore;

  TrendingArticle({
    required this.id,
    required this.title,
    required this.domain,
    required this.commentCount,
    required this.likes,
    required this.engagementScore,
  });

  factory TrendingArticle.fromJson(Map<String, dynamic> json) {
    return TrendingArticle(
      id: json['id'],
      title: json['title'],
      domain: json['domain'],
      commentCount: json['comment_count'],
      likes: json['likes'],
      engagementScore: json['engagement_score'],
    );
  }
}

class TrendingResponse {
  final int count;
  final List<TrendingArticle> trendingArticles;

  TrendingResponse({required this.count, required this.trendingArticles});

  factory TrendingResponse.fromJson(Map<String, dynamic> json) {
    return TrendingResponse(
      count: json['count'],
      trendingArticles:
          (json['trending_articles'] as List)
              .map((article) => TrendingArticle.fromJson(article))
              .toList(),
    );
  }
}
