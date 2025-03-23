class SearchResult {
  final int id;
  final String imageUrl;
  final double relevanceScore;
  final String searchQuery;
  final String summary;
  final String title;
  final String url;

  SearchResult({
    required this.id,
    required this.imageUrl,
    required this.relevanceScore,
    required this.searchQuery,
    required this.summary,
    required this.title,
    required this.url,
  });

  factory SearchResult.fromJson(Map<String, dynamic> json) {
    return SearchResult(
      id: json['id'],
      imageUrl: json['image_url'],
      relevanceScore: json['relevance_score'].toDouble(),
      searchQuery: json['search_query'],
      summary: json['summary'],
      title: json['title'],
      url: json['url'],
    );
  }
}

class SearchResponse {
  final int count;
  final String query;
  final List<SearchResult> results;

  SearchResponse({
    required this.count,
    required this.query,
    required this.results,
  });

  factory SearchResponse.fromJson(Map<String, dynamic> json) {
    return SearchResponse(
      count: json['count'],
      query: json['query'],
      results:
          (json['results'] as List)
              .map((result) => SearchResult.fromJson(result))
              .toList(),
    );
  }
}
