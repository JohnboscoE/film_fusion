import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

// --- Genre Mapping---
const Map<int, String> genreMap = {
  28: 'Action',
  12: 'Adventure',
  16: 'Animation',
  35: 'Comedy',
  80: 'Crime',
  99: 'Documentary',
  18: 'Drama',
  10751: 'Family',
  14: 'Fantasy',
  36: 'History',
  27: 'Horror',
  10402: 'Music',
  9648: 'Mystery',
  10749: 'Romance',
  878: 'Sci-Fi',
  10770: 'TV Movie',
  53: 'Thriller',
  10752: 'War',
  37: 'Western',
};

//  Model for Trending Results
class TrendingMovieModel {
  final int id;
  final String title;
  final String posterPath;
  final String releaseYear;
  final List<int> genreIds;
  final double popularity;

  TrendingMovieModel({
    required this.id,
    required this.title,
    required this.posterPath,
    required this.releaseYear,
    required this.genreIds,
    required this.popularity,
  });

  factory TrendingMovieModel.fromJson(Map<String, dynamic> json) {
    String releaseDate = json['release_date'] ?? json['first_air_date'] ?? '';
    String year = releaseDate.isNotEmpty && releaseDate.length >= 4
        ? releaseDate.substring(0, 4)
        : '';

    return TrendingMovieModel(
      id: json['id'] ?? 0,
      title: json['title'] ?? json['name'] ?? 'Unknown Title',
      posterPath: json['poster_path'] ?? '',
      releaseYear: year,
      genreIds: List<int>.from(json['genre_ids'] ?? []),
      popularity: (json['vote_average'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

// Movie Model (for search results)

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

  factory MovieModel.fromJsonSearch(Map<String, dynamic> json) {
    return MovieModel(
      title: json['Title'] ?? 'Unknown Title',
      year: json['Year'] ?? 'N/A',
      imdbID: json['imdbID'] ?? '',
      type: json['Type'] ?? 'N/A',
      poster: json['Poster'] ?? 'N/A',
    );
  }
}

class MovieSearchApp extends StatelessWidget {
  const MovieSearchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Movie Trailer Hub',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0D0D19),
        cardColor: const Color(0xFF1B1B2A),
        primaryColor: const Color(0xFF673AB7),
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFF673AB7),
          secondary: const Color(0xFFFF4081),
          surface: const Color(0xFF1B1B2A),
          background: const Color(0xFF0D0D19),
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.white70),
          bodyMedium: TextStyle(color: Colors.white70),
          titleLarge: TextStyle(color: Colors.white),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle.light,
        ),
      ),
      home: const MovieScreen(),
    );
  }
}

// Movie Screen
class MovieScreen extends StatefulWidget {
  const MovieScreen({super.key});

  @override
  State<MovieScreen> createState() => _MovieScreenState();
}

class _MovieScreenState extends State<MovieScreen> {
  // API KEYS (for OMDb and TMDB)
  static const String _omdbApiKey = 'e9b38b47';
  static const String _tmdbApiKey = '2f06b8d02df9a16b16175f0b66ee944f';

  final TextEditingController _searchController = TextEditingController();

  // New state variables for pagination and grid display
  final ScrollController _scrollController = ScrollController();
  List<MovieModel> _searchResults = [];
  String _currentSearchQuery = '';
  int _currentPage = 0;
  bool _isPaginating = false;
  bool _hasMorePages = true;
  int _totalResults = 0;

  late Future<List<TrendingMovieModel>> _trendingFuture;

  @override
  void initState() {
    super.initState();
    _trendingFuture = _fetchTrendingMovies();
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Scroll Listener for Lazy Loading
  void _scrollListener() {
    if (_scrollController.hasClients &&
        _scrollController.offset >=
            _scrollController.position.maxScrollExtent - 200) {
      if (_currentSearchQuery.isNotEmpty && !_isPaginating && _hasMorePages) {
        _loadNextPage();
      }
    }
  }

  String _mapGenreIdsToNames(List<int> ids) {
    return ids
        .map((id) => genreMap[id])
        .where((name) => name != null)
        .cast<String>()
        .join(', ');
  }

  String _buildPosterUrl(String path) {
    return 'https://image.tmdb.org/t/p/w200$path';
  }

  /// Fetch Today's Top Trending Movies from TMDB
  Future<List<TrendingMovieModel>> _fetchTrendingMovies() async {
    final trendingUrl =
        'https://api.themoviedb.org/3/trending/movie/day?api_key=$_tmdbApiKey';
    final response = await http.get(Uri.parse(trendingUrl));

    if (response.statusCode == 200) {
      final jsonResponse = jsonDecode(response.body);
      if (jsonResponse['results'] != null) {
        return (jsonResponse['results'] as List)
            .map((json) => TrendingMovieModel.fromJson(json))
            .where((movie) => movie.posterPath.isNotEmpty)
            .take(15) // Fetch a few more for the 3-column grid aesthetic
            .toList();
      }
    }
    return [];
  }

  /// Data Fetching Logic (OMDb Search)
  Future<List<MovieModel>> searchMovies(String query, int page) async {
    if (query.isEmpty) return [];

    final encodedQuery = Uri.encodeComponent(query);
    final String apiUrl =
        'http://www.omdbapi.com/?s=$encodedQuery&apikey=$_omdbApiKey&page=$page';

    final response = await http.get(Uri.parse(apiUrl));

    if (response.statusCode == 200) {
      final jsonResponse = jsonDecode(response.body);
      if (jsonResponse['Response'] == 'True' &&
          jsonResponse['Search'] != null) {
        // Update total results count only on the first page load
        if (page == 1) {
          _totalResults =
              int.tryParse(jsonResponse['totalResults'] ?? '0') ?? 0;
        }

        List<dynamic> jsonList = jsonResponse['Search'];
        return jsonList.map((json) => MovieModel.fromJsonSearch(json)).toList();
      } else {
        // Handle no more results for subsequent pages
        if (page > 1) {
          _hasMorePages = false;
          return [];
        } else {
          // Handle error on the initial search
          throw Exception(
            'OMDb Error: ${jsonResponse['Error'] ?? 'No results found for "$query"'}',
          );
        }
      }
    } else {
      throw Exception(
        'Failed to load OMDb data (Status: ${response.statusCode})',
      );
    }
  }

  /// Function to load the next page of search results
  Future<void> _loadNextPage() async {
    if (_isPaginating || !_hasMorePages) return;

    setState(() {
      _isPaginating = true;
      _currentPage++; // Move to the next page
    });

    try {
      final newMovies = await searchMovies(_currentSearchQuery, _currentPage);

      setState(() {
        _searchResults.addAll(newMovies);
        _hasMorePages = _searchResults.length < _totalResults;
        _isPaginating = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load more results: ${e.toString()}'),
          ),
        );
      }
      setState(() {
        _isPaginating = false;
      });
    }
  }

  /// Initial search trigger
  void _triggerSearch() {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    FocusScope.of(context).unfocus();

    // Reset pagination state for a new search query
    setState(() {
      _searchResults = [];
      _currentSearchQuery = query;
      _currentPage = 0;
      _isPaginating = false;
      _hasMorePages = true;
      _totalResults = 0;
    });

    // Start the first page load
    _loadNextPage();
  }

  /// Navigate to the player screen after fetching the key AND ID
  void _navigateToTrailer(String title, String year, {String? tmdbId}) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Searching for video and related data for $title...'),
      ),
    );

    final movieData = await _fetchMovieData(title, year);

    if (!mounted) return;

    if (movieData != null && movieData['videoId']!.isNotEmpty) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => TrailerPlayerScreen(
            title: title,
            youtubeVideoId: movieData['videoId']!,
            tmdbId: movieData['tmdbId']!,
            omdbApiKey: _omdbApiKey,
            tmdbApiKey: _tmdbApiKey,
            fetchMovieData: _fetchMovieData,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not find any video for $title.')),
      );
    }
  }

  /// TMDB API Logic to find YouTube Trailer Key and Movie ID (Unchanged)
  Future<Map<String, String>?> _fetchMovieData(
    String title,
    String year,
  ) async {
    final searchUrl =
        'https://api.themoviedb.org/3/search/movie?api_key=$_tmdbApiKey&query=${Uri.encodeComponent(title)}&year=$year';
    final searchResponse = await http.get(Uri.parse(searchUrl));

    if (searchResponse.statusCode != 200) return null;

    final searchJson = jsonDecode(searchResponse.body);
    if (searchJson['results'] == null || searchJson['results'].isEmpty)
      return null;

    final tmdbResult = searchJson['results'][0];
    final tmdbId = tmdbResult['id'];

    final videosUrl =
        'https://api.themoviedb.org/3/movie/$tmdbId/videos?api_key=$_tmdbApiKey';
    final videosResponse = await http.get(Uri.parse(videosUrl));

    if (videosResponse.statusCode != 200) return null;

    final videosJson = jsonDecode(videosResponse.body);
    if (videosJson['results'] == null) return null;

    String? bestKey;
    String? fallbackKey;

    for (var video in videosJson['results']) {
      if (video['site'] == 'YouTube' && video['key'] != null) {
        final type = video['type'];

        if (fallbackKey == null) {
          fallbackKey = video['key'];
        }

        if (type == 'Trailer') {
          bestKey = video['key'];
          break;
        }

        if (type == 'Teaser' && bestKey == null) {
          bestKey = video['key'];
        }
      }
    }

    if (bestKey == null && fallbackKey == null) return null;

    return {'videoId': bestKey ?? fallbackKey!, 'tmdbId': tmdbId.toString()};
  }

  /// --- Handle Pull-to-Refresh to return to trending page ---
  Future<void> _handleRefreshToTrending() async {
    if (_currentSearchQuery.isNotEmpty) {
      setState(() {
        _currentSearchQuery = '';
        _searchResults = [];
        _searchController.clear();
      });
    }
    setState(() {
      _trendingFuture = _fetchTrendingMovies();
    });
    await _trendingFuture;
  }

  AppBar _buildGradientAppBar(String title) {
    return AppBar(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      centerTitle: true,
      elevation: 0,
      backgroundColor: Colors.transparent,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.deepPurple.shade700.withOpacity(0.8), // Dark Purple
              Colors.pinkAccent.shade200.withOpacity(0.4), // Pink Accent
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
    );
  }

  Widget _buildMovieCard({
    required String title,
    required String poster,
    required String year,
    String? genres, // Used by Trending
    required VoidCallback onTap,
  }) {
    final imageUrl = poster.startsWith('/') ? _buildPosterUrl(poster) : poster;

    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Expanded(
              flex: 4,
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                width: double.infinity,
                errorBuilder: (context, error, stackTrace) => const Center(
                  child: Icon(Icons.movie_filter, size: 40, color: Colors.grey),
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (genres != null)
                      Flexible(
                        child: Text(
                          genres.isEmpty ? 'Movie' : genres,
                          style: TextStyle(
                            fontSize: 10,
                            color: Theme.of(
                              context,
                            ).colorScheme.secondary.withOpacity(0.8),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      )
                    else
                      Flexible(
                        child: Text(
                          'Year: $year',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.white70,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendingSection(List<TrendingMovieModel> movies) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Text(
            '🔥 Today\'s Top Trending',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.secondary,
            ),
          ),
        ),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            // Handled by parent ListView
            itemCount: movies.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.55,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemBuilder: (context, index) {
              final movie = movies[index];
              final genres = _mapGenreIdsToNames(movie.genreIds);

              return _buildMovieCard(
                title: movie.title,
                poster: movie.posterPath,
                // path, not full URL
                year: movie.releaseYear,
                genres: genres,
                onTap: () => _navigateToTrailer(
                  movie.title,
                  movie.releaseYear,
                  tmdbId: movie.id.toString(),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  //  Initial View (Showing Trending Movies)
  Widget _buildInitialTrendingView() {
    return FutureBuilder<List<TrendingMovieModel>>(
      future: _trendingFuture,
      builder: (context, trendingSnapshot) {
        if (trendingSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFFFF4081)),
          );
        }

        if (trendingSnapshot.hasData && trendingSnapshot.data!.isNotEmpty) {
          return ListView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              _buildTrendingSection(trendingSnapshot.data!),
              const SizedBox(height: 20),
            ],
          );
        }
        return const Center(
          child: Text(
            'Search for a movie title above.',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        );
      },
    );
  }

  Widget _buildSearchResultsView() {
    if (_currentPage == 0 && _isPaginating) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFFF4081)),
      );
    }

    if (_searchResults.isEmpty && !_isPaginating) {
      return Center(
        child: Text(
          'No results found for "$_currentSearchQuery".',
          style: const TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    // Calculate item count: add 3 placeholder spots at the end if we are currently loading
    final itemCount = _searchResults.length + (_isPaginating ? 3 : 0);

    return GridView.builder(
      controller: _scrollController,
      // Scroll controller enables pagination listener
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(12.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3, // Three cards per row
        childAspectRatio: 0.55,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (index >= _searchResults.length) {
          return Center(
            child: LinearProgressIndicator(
              color: Theme.of(context).colorScheme.secondary,
            ),
          );
        }

        final movie = _searchResults[index];

        // Use OMDb poster and OMDb year
        return _buildMovieCard(
          title: movie.title,
          poster: movie.poster,
          year: movie.year,
          onTap: () => _navigateToTrailer(movie.title, movie.year),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildGradientAppBar('Film Fusion'),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12.0),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w500,
                ),
                cursorColor: Theme.of(context).colorScheme.secondary,
                keyboardAppearance: Brightness.dark,
                decoration: InputDecoration(
                  labelText: 'Search for any movie or series title...',
                  labelStyle: const TextStyle(color: Colors.white70),
                  fillColor: Theme.of(context).cardColor,
                  filled: true,
                  suffixIcon: IconButton(
                    icon: Icon(
                      Icons.search,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                    onPressed: _triggerSearch,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.secondary,
                      width: 2.0,
                    ),
                  ),
                ),
                onSubmitted: (_) => _triggerSearch(),
              ),
            ),
          ),

          Expanded(
            child: RefreshIndicator(
              color: Theme.of(context).colorScheme.secondary,
              onRefresh: _handleRefreshToTrending,
              child: _currentSearchQuery.isEmpty
                  ? _buildInitialTrendingView()
                  : _buildSearchResultsView(),
            ),
          ),
        ],
      ),
    );
  }
}

class ProviderDetailModel {
  final int providerId;
  final String providerName;
  final String logoPath;

  ProviderDetailModel({
    required this.providerId,
    required this.providerName,
    required this.logoPath,
  });

  factory ProviderDetailModel.fromJson(Map<String, dynamic> json) {
    return ProviderDetailModel(
      providerId: json['provider_id'],
      providerName: json['provider_name'],
      logoPath: json['logo_path'] ?? '',
    );
  }
}

class WatchProviderModel {
  final String link;
  final List<ProviderDetailModel> flatrate;
  final List<ProviderDetailModel> rent;
  final List<ProviderDetailModel> buy;

  WatchProviderModel({
    required this.link,
    required this.flatrate,
    required this.rent,
    required this.buy,
  });

  factory WatchProviderModel.fromJson(Map<String, dynamic> json) {
    return WatchProviderModel(
      link: json['link'] ?? '',
      flatrate:
          (json['flatrate'] as List?)
              ?.map((e) => ProviderDetailModel.fromJson(e))
              .toList() ??
          [],
      rent:
          (json['rent'] as List?)
              ?.map((e) => ProviderDetailModel.fromJson(e))
              .toList() ??
          [],
      buy:
          (json['buy'] as List?)
              ?.map((e) => ProviderDetailModel.fromJson(e))
              .toList() ??
          [],
    );
  }

  bool get hasProviders =>
      flatrate.isNotEmpty || rent.isNotEmpty || buy.isNotEmpty;
}

class RelatedMovieModel {
  final int id;
  final String title;
  final String posterPath;
  final String releaseYear;
  final List<int> genreIds; // Added genre IDs

  RelatedMovieModel({
    required this.id,
    required this.title,
    required this.posterPath,
    required this.releaseYear,
    required this.genreIds,
  });

  factory RelatedMovieModel.fromJson(Map<String, dynamic> json) {
    String releaseDate = json['release_date'] ?? '';
    String year = releaseDate.isNotEmpty && releaseDate.length >= 4
        ? releaseDate.substring(0, 4)
        : '';

    return RelatedMovieModel(
      id: json['id'],
      title: json['title'] ?? 'Unknown Title',
      posterPath: json['poster_path'] ?? '',
      releaseYear: year,
      genreIds: List<int>.from(json['genre_ids'] ?? []),
    );
  }
}

/// Screen for playing the YouTube Trailer and showing related videos
class TrailerPlayerScreen extends StatefulWidget {
  final String title;
  final String youtubeVideoId;
  final String tmdbId;
  final String omdbApiKey;
  final String tmdbApiKey;

  final Future<Map<String, String>?> Function(String title, String year)
  fetchMovieData;

  const TrailerPlayerScreen({
    super.key,
    required this.title,
    required this.youtubeVideoId,
    required this.tmdbId,
    required this.omdbApiKey,
    required this.tmdbApiKey,
    required this.fetchMovieData,
  });

  @override
  State<TrailerPlayerScreen> createState() => _TrailerPlayerScreenState();
}

class _TrailerPlayerScreenState extends State<TrailerPlayerScreen> {
  late YoutubePlayerController _controller;
  late Future<List<RelatedMovieModel>> _relatedMoviesFuture;
  late Future<String> _plotSummaryFuture;
  late Future<WatchProviderModel?> _watchProvidersFuture;

  //  AI Integration State
  static const String _sentientApiKey = 'fw_3ZXjk2VZLvfQgW16VnHJy9V7';
  static const String _sentientApiUrl =
      'https://api.fireworks.ai/inference/v1/chat/completions';

  bool _isSentientLoading = false;
  String? _sentientSummary;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

    _controller = YoutubePlayerController(
      initialVideoId: widget.youtubeVideoId,
      flags: const YoutubePlayerFlags(
        autoPlay: true,
        mute: false,
        loop: false,
        isLive: false,
        forceHD: false,
        enableCaption: true,
      ),
    );
    _relatedMoviesFuture = _fetchRelatedMovies();
    _plotSummaryFuture = _fetchPlotSummary();
    _watchProvidersFuture = _fetchWatchProviders();

    _generateGeminiReview();
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeRight,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _generateGeminiReview() async {
    if (_isSentientLoading ||
        (_sentientSummary != null && _isSentientLoading == false))
      return;

    setState(() {
      _isSentientLoading = true;
      _sentientSummary = null;
    });

    const systemPrompt =
        "You are a movie critic. Write a concise,"
        " approximately 100-word review of the movie based on the latest information, focusing on the movie summary and actors of the movie. Respond only with the review text.";
    final userQuery =
        "Write a professional review for the movie: ${widget.title}";

    final payload = {
      "contents": [
        {
          "parts": [
            {"text": userQuery},
          ],
        },
      ],
      "tools": [
        {"google_search": {}},
      ],
      "systemInstruction": {
        "parts": [
          {"text": systemPrompt},
        ],
      },
    };

    try {
      final response = await http.post(
        Uri.parse('$_sentientApiUrl?key=$_sentientApiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        final generatedText =
            jsonResponse['candidates']?[0]?['content']?['parts']?[0]?['text'];

        if (generatedText != null && generatedText.isNotEmpty) {
          setState(() {
            _sentientSummary = generatedText;
          });
        } else {
          _showSnackBar('AI generation failed or returned empty content.');
        }
      } else {
        _showSnackBar('AI API call failed with status: ${response.statusCode}');
      }
    } catch (e) {
      _showSnackBar('Network error while fetching AI review: $e');
    } finally {
      setState(() {
        _isSentientLoading = false;
      });
    }
  }

  // Simple helper for showing SnackBar
  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  /// Build section for the AI-generated review
  Widget _buildAIReviewSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: Theme.of(context).colorScheme.secondary.withOpacity(0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '🤖 AI Critic\'s Review',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ),
              // Button to regenerate or show loading indicator
              _isSentientLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : IconButton(
                      icon: const Icon(Icons.refresh, size: 20),
                      color: Colors.white70,
                      onPressed: _generateGeminiReview,
                      tooltip: 'Regenerate Review',
                    ),
            ],
          ),
          const SizedBox(height: 10),
          // Content display area
          if (_isSentientLoading)
            const Center(
              child: Text(
                'Analyzing movie and generating critique...',
                style: TextStyle(color: Colors.grey),
              ),
            )
          else if (_sentientSummary != null)
            Text(
              _sentientSummary!,
              style: const TextStyle(fontSize: 14, height: 1.4),
              textAlign: TextAlign.justify,
            )
          else
            // Fallback message if no review is loaded (and not loading)
            TextButton.icon(
              icon: Icon(
                Icons.psychology_outlined,
                color: Theme.of(context).colorScheme.secondary,
              ),
              label: Text(
                'Click to generate the AI review',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ),
              onPressed: _generateGeminiReview,
            ),
        ],
      ),
    );
  }

  /// Builds the section for watch providers (streaming, rental, buy)
  Widget _buildWatchProvidersSection(WatchProviderModel providers) {
    Widget buildProviderRow(String title, List<ProviderDetailModel> list) {
      if (list.isEmpty) return const SizedBox.shrink();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 10.0, bottom: 5.0),
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: list.length,
              itemBuilder: (context, index) {
                final provider = list[index];
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Tooltip(
                    message: provider.providerName,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8.0),
                      child: Image.network(
                        _buildLogoUrl(provider.logoPath),
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: 40,
                          height: 40,
                          color: Colors.grey,
                          child: const Icon(Icons.tv, size: 20),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Where to Watch (US)',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.secondary,
            ),
          ),
          buildProviderRow('Streaming', providers.flatrate),
          buildProviderRow('Rent', providers.rent),
          buildProviderRow('Buy', providers.buy),
          if (providers.link.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10.0),
              child: TextButton.icon(
                onPressed: () => launchUrl(Uri.parse(providers.link)),
                icon: const Icon(Icons.launch, size: 16),
                label: const Text('View full list on JustWatch'),
              ),
            ),
        ],
      ),
    );
  }

  /// Build section for related content recommendations
  Widget _buildRelatedMoviesSection(List<RelatedMovieModel> related) {
    if (related.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Text(
            'More Like This',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.secondary,
            ),
          ),
        ),
        SizedBox(
          height: 220,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            itemCount: related.length,
            itemBuilder: (context, index) {
              final movie = related[index];
              final genres = _mapGenreIdsToNames(movie.genreIds);

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: SizedBox(
                  width: 120,
                  child: _buildMovieCard(
                    title: movie.title,
                    poster: movie.posterPath,
                    year: movie.releaseYear,
                    genres: genres,
                    onTap: () => _handleRelatedMovieTap(movie),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  /// Helper to map TMDB genre IDs to names
  String _mapGenreIdsToNames(List<int> ids) {
    return ids
        .map((id) => genreMap[id])
        .where((name) => name != null)
        .cast<String>()
        .join(', ');
  }

  String _buildPosterUrl(String path) {
    return 'https://image.tmdb.org/t/p/w200$path';
  }

  String _buildLogoUrl(String path) {
    return 'https://image.tmdb.org/t/p/w92$path';
  }

  AppBar _buildGradientAppBar(String title) {
    return AppBar(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      centerTitle: true,
      elevation: 0,
      backgroundColor: Colors.transparent,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.deepPurple.shade700.withOpacity(0.8), // Dark Purple
              Colors.pinkAccent.shade200.withOpacity(0.4), // Pink Accent
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
    );
  }

  /// Fetches legal watch providers from TMDB
  Future<WatchProviderModel?> _fetchWatchProviders() async {
    final providersUrl =
        'https://api.themoviedb.org/3/movie/${widget.tmdbId}/watch/providers?api_key=${widget.tmdbApiKey}';
    final response = await http.get(Uri.parse(providersUrl));

    if (response.statusCode == 200) {
      final jsonResponse = jsonDecode(response.body);

      if (jsonResponse['results'] != null &&
          jsonResponse['results']['US'] != null) {
        return WatchProviderModel.fromJson(jsonResponse['results']['US']);
      }
    }
    return null;
  }

  /// Fetches plot summary (overview) from TMDB
  Future<String> _fetchPlotSummary() async {
    final detailUrl =
        'https://api.themoviedb.org/3/movie/${widget.tmdbId}?api_key=${widget.tmdbApiKey}';
    final response = await http.get(Uri.parse(detailUrl));

    if (response.statusCode == 200) {
      final jsonResponse = jsonDecode(response.body);
      return jsonResponse['overview'] ?? 'No plot summary available.';
    }
    return 'Failed to load plot summary.';
  }

  /// Fetches related movie recommendations from TMDB
  Future<List<RelatedMovieModel>> _fetchRelatedMovies() async {
    final relatedUrl =
        'https://api.themoviedb.org/3/movie/${widget.tmdbId}/recommendations?api_key=${widget.tmdbApiKey}';
    final response = await http.get(Uri.parse(relatedUrl));

    if (response.statusCode == 200) {
      final jsonResponse = jsonDecode(response.body);
      if (jsonResponse['results'] != null) {
        return (jsonResponse['results'] as List)
            .map((json) => RelatedMovieModel.fromJson(json))
            .where((movie) => movie.posterPath.isNotEmpty)
            .take(10)
            .toList();
      }
    }
    return [];
  }

  /// Handles the tap on a related movie card
  void _handleRelatedMovieTap(RelatedMovieModel movie) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Loading ${movie.title} trailer...')),
    );

    final movieData = await widget.fetchMovieData(
      movie.title,
      movie.releaseYear,
    );

    if (!mounted) return;

    if (movieData != null && movieData['videoId']!.isNotEmpty) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => TrailerPlayerScreen(
            title: movie.title,
            youtubeVideoId: movieData['videoId']!,
            tmdbId: movieData['tmdbId']!,
            omdbApiKey: widget.omdbApiKey,
            tmdbApiKey: widget.tmdbApiKey,
            fetchMovieData: widget.fetchMovieData,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not find any video for ${movie.title}.')),
      );
    }
  }

  Widget _buildMovieCard({
    required String title,
    required String poster,
    required String year,
    String? genres,
    required VoidCallback onTap,
  }) {
    final imageUrl = poster.startsWith('/') ? _buildPosterUrl(poster) : poster;

    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Expanded(
              flex: 4,
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                width: double.infinity,
                errorBuilder: (context, error, stackTrace) => const Center(
                  child: Icon(Icons.movie_filter, size: 40, color: Colors.grey),
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (genres != null)
                      Flexible(
                        child: Text(
                          genres.isEmpty ? 'Movie' : genres,
                          style: TextStyle(
                            fontSize: 10,
                            color: Theme.of(
                              context,
                            ).colorScheme.secondary.withOpacity(0.8),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      )
                    else
                      Flexible(
                        child: Text(
                          'Year: $year',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.white70,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildGradientAppBar(widget.title),
      body: ListView(
        children: <Widget>[
          //YouTube Player
          YoutubePlayer(
            controller: _controller,
            showVideoProgressIndicator: true,
            progressIndicatorColor: Theme.of(context).colorScheme.secondary,
            progressColors: ProgressBarColors(
              playedColor: Theme.of(context).colorScheme.secondary,
              handleColor: Theme.of(context).colorScheme.secondary,
            ),
            onReady: () {
              // Optionally play on ready
            },
          ),

          const SizedBox(height: 10),

          //AI Review Section (NEW)
          _buildAIReviewSection(),

          // Plot Summary
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 10.0,
            ),
            child: FutureBuilder<String>(
              future: _plotSummaryFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const LinearProgressIndicator();
                }
                return Text(
                  snapshot.data ?? 'No plot summary available.',
                  style: const TextStyle(fontSize: 14, height: 1.4),
                  textAlign: TextAlign.justify,
                );
              },
            ),
          ),

          // Watch Providers
          FutureBuilder<WatchProviderModel?>(
            future: _watchProvidersFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: LinearProgressIndicator(),
                  ),
                );
              }
              if (snapshot.hasData && snapshot.data!.hasProviders) {
                return _buildWatchProvidersSection(snapshot.data!);
              }
              return const SizedBox.shrink(); // Hide if no providers found
            },
          ),

          // Related Movies
          FutureBuilder<List<RelatedMovieModel>>(
            future: _relatedMoviesFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: CircularProgressIndicator(),
                  ),
                );
              }
              if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                return _buildRelatedMoviesSection(snapshot.data!);
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
    );
  }
}
