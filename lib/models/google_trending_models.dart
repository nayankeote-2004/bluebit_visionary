class GoogleTrendingTopic {
  final int rank;
  final String title;
  final int views;

  GoogleTrendingTopic({
    required this.rank,
    required this.title,
    required this.views,
  });

  factory GoogleTrendingTopic.fromJson(Map<String, dynamic> json) {
    return GoogleTrendingTopic(
      rank: json['rank'],
      title: json['title'],
      views: json['views'],
    );
  }
}

class GoogleTrendingResponse {
  final String date;
  final int indiaRelatedCount;
  final String method;
  final int totalCount;
  final List<GoogleTrendingTopic> trendingTopics;

  GoogleTrendingResponse({
    required this.date,
    required this.indiaRelatedCount,
    required this.method,
    required this.totalCount,
    required this.trendingTopics,
  });

  factory GoogleTrendingResponse.fromJson(Map<String, dynamic> json) {
    return GoogleTrendingResponse(
      date: json['date'],
      indiaRelatedCount: json['india_related_count'],
      method: json['method'],
      totalCount: json['total_count'],
      trendingTopics:
          (json['trendingTopics'] as List)
              .map((topic) => GoogleTrendingTopic.fromJson(topic))
              .toList(),
    );
  }
}
