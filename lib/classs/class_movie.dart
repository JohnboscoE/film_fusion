class MovieModel {
  final String title;
  final String year;
  final String imdbID;
  final String type;
  final String poster;

  MovieModel({
    required this.title,
    required this.year,
    required this.imdbID,
    required this.type,
    required this.poster,
  });

  /// Factory constructor to parse the data returned by the OMDb search endpoint.
  factory MovieModel.fromJsonSearch(Map<String, dynamic> json) {
    return MovieModel(
      title: json['Title'] ?? 'N/A',
      year: json['Year'] ?? 'N/A',
      imdbID: json['imdbID'] ?? '',
      type: json['Type'] ?? 'N/A',
      poster: json['Poster'] ?? 'N/A',
    );
  }
}
