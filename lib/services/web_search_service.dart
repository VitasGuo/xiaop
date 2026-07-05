import 'dart:convert';
import 'package:http/http.dart' as http;

class WebSearchService {
  static final WebSearchService _instance = WebSearchService._();
  factory WebSearchService() => _instance;
  WebSearchService._();

  /// 搜索并返回摘要文本
  Future<String> search(String query, {int maxResults = 5}) async {
    try {
      return await _searchDuckDuckGo(query, maxResults);
    } catch (_) {
      try {
        return await _searchLite(query, maxResults);
      } catch (e) {
        return '';
      }
    }
  }

  /// DuckDuckGo instant answer API
  Future<String> _searchDuckDuckGo(String query, int maxResults) async {
    final url = Uri.parse(
      'https://api.duckduckgo.com/?q=${Uri.encodeComponent(query)}&format=json&no_html=1&skip_disambig=1',
    );

    final response = await http.get(url).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) return '';

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final buffer = StringBuffer();

    final abstract = data['AbstractText'] as String? ?? '';
    if (abstract.isNotEmpty) {
      buffer.writeln(abstract);
    }

    final relatedTopics = data['RelatedTopics'] as List? ?? [];
    for (final topic in relatedTopics.take(maxResults)) {
      if (topic is Map<String, dynamic>) {
        final text = topic['Text'] as String? ?? '';
        final firstUrl = topic['FirstURL'] as String? ?? '';
        if (text.isNotEmpty) {
          buffer.writeln('- $text');
          if (firstUrl.isNotEmpty) buffer.writeln('  来源: $firstUrl');
        }
      }
    }

    return buffer.toString().trim();
  }

  /// 简单的 HTML 搜索（备用）
  Future<String> _searchLite(String query, int maxResults) async {
    final url = Uri.parse(
      'https://lite.duckduckgo.com/lite/?q=${Uri.encodeComponent(query)}',
    );

    final response = await http.get(
      url,
      headers: {'User-Agent': 'Mozilla/5.0'},
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) return '';

    // 简单提取纯文本
    String html = response.body;
    html = html.replaceAll(RegExp(r'<[^>]+>'), ' ');
    html = html.replaceAll(RegExp(r'\s+'), ' ').trim();

    // 截取前2000字符作为摘要
    if (html.length > 2000) {
      html = '${html.substring(0, 2000)}...';
    }
    return html;
  }

  /// 获取网页内容摘要
  Future<String> fetchPage(String url, {int maxChars = 3000}) async {
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': 'Mozilla/5.0'},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) return '';

      String html = response.body;
      // 移除脚本和样式
      html = html.replaceAll(RegExp(r'<script[^>]*>[\s\S]*?</script>', caseSensitive: false), '');
      html = html.replaceAll(RegExp(r'<style[^>]*>[\s\S]*?</style>', caseSensitive: false), '');
      html = html.replaceAll(RegExp(r'<[^>]+>'), ' ');
      html = html.replaceAll(RegExp(r'\s+'), ' ').trim();

      if (html.length > maxChars) {
        html = '${html.substring(0, maxChars)}...';
      }
      return html;
    } catch (_) {
      return '';
    }
  }
}
