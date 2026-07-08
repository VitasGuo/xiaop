import 'package:dio/dio.dart';
import 'package:xiao_p/utils/logger.dart';

class WebSearchService {
  static final WebSearchService _instance = WebSearchService._();
  factory WebSearchService() => _instance;
  WebSearchService._();

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
    followRedirects: true,
    validateStatus: (s) => s != null && s < 400,
  ));

  /// 搜索并返回摘要文本
  Future<String> search(String query, {int maxResults = 5}) async {
    try {
      return await _searchBing(query, maxResults);
    } catch (e) {
      Log.w('必应搜索失败: $e');
      return '';
    }
  }

  /// 必应中国搜索（国内可访问，无需 API key）
  Future<String> _searchBing(String query, int maxResults) async {
    final url = 'https://cn.bing.com/search?q=${Uri.encodeComponent(query)}&count=$maxResults&setlang=zh-CN';

    final response = await _dio.get(
      url,
      options: Options(
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
          'Accept-Language': 'zh-CN,zh;q=0.9',
        },
        responseType: ResponseType.plain,
      ),
    );

    if (response.statusCode != 200) {
      Log.w('必应搜索返回 ${response.statusCode}');
      return '';
    }

    final body = response.data.toString();
    final results = _parseBingResults(body, maxResults);

    if (results.isEmpty) return '';

    final buffer = StringBuffer();
    buffer.writeln('搜索"$query"的结果：');
    for (final r in results) {
      buffer.writeln('- ${r.title}');
      if (r.snippet.isNotEmpty) {
        buffer.writeln('  ${r.snippet}');
      }
      if (r.url.isNotEmpty) {
        buffer.writeln('  来源: ${r.url}');
      }
    }
    return buffer.toString().trim();
  }

  /// 解析必应搜索结果 HTML
  List<_SearchResult> _parseBingResults(String html, int maxResults) {
    final results = <_SearchResult>[];

    // 必应每个结果在 <li class="b_algo">...</li> 中
    final liRegex = RegExp(
      r'<li[^>]*class="b_algo"[^>]*>([\s\S]*?)</li>',
    );
    final matches = liRegex.allMatches(html);

    for (final match in matches) {
      if (results.length >= maxResults) break;
      final block = match.group(1) ?? '';

      // 提取标题（在 <h2><a>...</a></h2> 中）
      String title = '';
      final titleRegex = RegExp(r'<h2[^>]*>[\s\S]*?<a[^>]*>([\s\S]*?)</a>', caseSensitive: false);
      final titleMatch = titleRegex.firstMatch(block);
      if (titleMatch != null) {
        title = _stripHtml(titleMatch.group(1) ?? '');
      }

      // 提取链接
      String url = '';
      final hrefRegex = RegExp(r'<a[^>]*href="([^"]+)"', caseSensitive: false);
      final hrefMatch = hrefRegex.firstMatch(block);
      if (hrefMatch != null) {
        url = hrefMatch.group(1) ?? '';
      }

      // 提取摘要（在 <p> 或 class含caption的div中）
      String snippet = '';
      final pRegex = RegExp(r'<p[^>]*>([\s\S]*?)</p>', caseSensitive: false);
      final pMatch = pRegex.firstMatch(block);
      if (pMatch != null) {
        snippet = _stripHtml(pMatch.group(1) ?? '');
      }
      // 如果 p 没有内容，尝试 caption div
      if (snippet.isEmpty) {
        final capRegex = RegExp(
          r'<div[^>]*class="[^"]*b_caption[^"]*"[^>]*>([\s\S]*?)</div>',
          caseSensitive: false,
        );
        final capMatch = capRegex.firstMatch(block);
        if (capMatch != null) {
          snippet = _stripHtml(capMatch.group(1) ?? '');
        }
      }

      if (title.isNotEmpty || snippet.isNotEmpty) {
        results.add(_SearchResult(title: title, snippet: snippet, url: url));
      }
    }

    return results;
  }

  /// 去除 HTML 标签和多余空白
  String _stripHtml(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}

class _SearchResult {
  final String title;
  final String snippet;
  final String url;
  _SearchResult({required this.title, required this.snippet, required this.url});
}
