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

  /// 搜索并返回摘要 + Top网页正文
  Future<String> search(String query, {int maxResults = 5}) async {
    try {
      final results = await _searchBing(query, maxResults);
      if (results.isEmpty) return '';

      // 构建搜索结果摘要
      final buffer = StringBuffer();
      buffer.writeln('搜索"$query"的结果：');
      for (var i = 0; i < results.length; i++) {
        final r = results[i];
        buffer.writeln('${i + 1}. ${r.title}');
        if (r.snippet.isNotEmpty) buffer.writeln('   摘要: ${r.snippet}');
        if (r.url.isNotEmpty) buffer.writeln('   来源: ${r.url}');
      }

      // 深度阅读：并行抓取 Top 3 网页正文
      final topUrls = results
          .take(3)
          .where((r) => r.url.isNotEmpty && r.url.startsWith('http'))
          .map((r) => r.url)
          .toList();

      if (topUrls.isNotEmpty) {
        buffer.writeln('\n=== 网页详细内容 ===');
        final futures = topUrls.map((url) => _fetchPageContent(url).catchError((_) => ''));
        final contents = await Future.wait(futures);
        for (var i = 0; i < contents.length; i++) {
          if (contents[i].isNotEmpty) {
            buffer.writeln('\n[网页${i + 1}] ${topUrls[i]}');
            buffer.writeln(contents[i]);
          }
        }
      }

      return buffer.toString().trim();
    } catch (e) {
      Log.w('搜索失败: $e');
      return '';
    }
  }

  /// 必应中国搜索（国内可访问，无需 API key）
  Future<List<_SearchResult>> _searchBing(String query, int maxResults) async {
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
      return [];
    }

    return _parseBingResults(response.data.toString(), maxResults);
  }

  /// 解析必应搜索结果 HTML
  List<_SearchResult> _parseBingResults(String html, int maxResults) {
    final results = <_SearchResult>[];

    final liRegex = RegExp(r'<li[^>]*class="b_algo"[^>]*>([\s\S]*?)</li>');
    final matches = liRegex.allMatches(html);

    for (final match in matches) {
      if (results.length >= maxResults) break;
      final block = match.group(1) ?? '';

      // 标题：在 <h2> 标签内（可能含 <strong>、<a> 等子标签）
      String title = '';
      final h2Regex = RegExp(r'<h2[^>]*>([\s\S]*?)</h2>', caseSensitive: false);
      final h2Match = h2Regex.firstMatch(block);
      if (h2Match != null) {
        title = _stripHtml(h2Match.group(1) ?? '');
      }

      // 链接：取第一个指向外部 http 的 href
      String url = '';
      final hrefRegex = RegExp(r'href="(https?://[^"]+)"', caseSensitive: false);
      final hrefMatches = hrefRegex.allMatches(block);
      for (final hm in hrefMatches) {
        final u = hm.group(1) ?? '';
        // 跳过 bing 内部链接
        if (!u.contains('bing.com') && !u.contains('msn.com')) {
          url = u;
          break;
        }
      }

      // 摘要：优先 <p>，其次 b_caption div
      String snippet = '';
      final pRegex = RegExp(r'<p[^>]*>([\s\S]*?)</p>', caseSensitive: false);
      final pMatch = pRegex.firstMatch(block);
      if (pMatch != null) {
        snippet = _stripHtml(pMatch.group(1) ?? '');
      }
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

  /// 抓取网页正文并清洗
  Future<String> _fetchPageContent(String url) async {
    try {
      final response = await _dio.get(
        url,
        options: Options(
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
            'Accept': 'text/html,application/xhtml+xml',
            'Accept-Language': 'zh-CN,zh;q=0.9',
          },
          responseType: ResponseType.plain,
        ),
      ).timeout(const Duration(seconds: 8), onTimeout: () => throw Exception('timeout'));

      if (response.statusCode != 200) return '';
      return _extractMainContent(response.data.toString());
    } catch (e) {
      Log.w('抓取网页失败 $url: $e');
      return '';
    }
  }

  /// 从 HTML 提取正文：去标签/脚本/样式，保留文本
  String _extractMainContent(String html) {
    var content = html;

    // 移除 script、style、nav、footer、header 等非正文标签
    content = content.replaceAll(
      RegExp(r'<(script|style|nav|footer|header|aside|noscript)[^>]*>[\s\S]*?</\1>',
          caseSensitive: false),
      '',
    );

    // 尝试提取 article 或 main 标签内容（语义化正文）
    final articleRegex = RegExp(r'<(article|main)[^>]*>([\s\S]*?)</\1>', caseSensitive: false);
    final articleMatch = articleRegex.firstMatch(content);
    if (articleMatch != null) {
      content = articleMatch.group(2) ?? content;
    }

    // 去所有 HTML 标签
    content = _stripHtml(content);

    // 清理多余空白和乱码字符
    content = content
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .replaceAll(RegExp(r' {2,}'), ' ')
        .trim();

    // 限制长度，避免 token 爆炸（约 1500 中文字符）
    if (content.length > 2000) {
      content = content.substring(0, 2000);
    }

    return content.isEmpty ? '' : content;
  }

  /// 去除 HTML 标签和实体
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
