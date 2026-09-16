import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class OpenConnectorStatus {
  final bool isAvailable;
  final String displayName;
  final String token;
  final String errorMessage;

  const OpenConnectorStatus({
    required this.isAvailable,
    this.displayName = '',
    this.token = '',
    this.errorMessage = '',
  });
}

class NotionPageItem {
  final String id;
  final String title;
  final String objectType; // 'page' or 'data_source'

  const NotionPageItem({
    required this.id,
    required this.title,
    required this.objectType,
  });
}

class OpenConnectorNotionService {
  static const String mcpUrl = 'http://localhost:3000/mcp';
  static const String openConnectorEnvPath = r'C:\Kerjaan\OpenConnector\.env';

  static String? _cachedToken;

  /// Read OOMOL_CONNECT_RUNTIME_TOKEN from C:\Kerjaan\OpenConnector\.env
  static String getRuntimeToken() {
    if (_cachedToken != null && _cachedToken!.isNotEmpty) {
      return _cachedToken!;
    }
    try {
      final file = File(openConnectorEnvPath);
      if (file.existsSync()) {
        final lines = file.readAsLinesSync();
        for (final line in lines) {
          final trimmed = line.trim();
          if (trimmed.startsWith('OOMOL_CONNECT_RUNTIME_TOKEN=')) {
            var val = trimmed.substring(28).trim();
            if ((val.startsWith('"') && val.endsWith('"')) ||
                (val.startsWith("'") && val.endsWith("'"))) {
              val = val.substring(1, val.length - 1);
            }
            _cachedToken = val;
            return val;
          }
        }
      }
    } catch (_) {}
    return '';
  }

  /// Check connection status with OpenConnector Notion MCP
  static Future<OpenConnectorStatus> checkStatus() async {
    final token = getRuntimeToken();
    if (token.isEmpty) {
      return const OpenConnectorStatus(
        isAvailable: false,
        errorMessage: 'Token OOMOL_CONNECT_RUNTIME_TOKEN tidak ditemukan di C:\\Kerjaan\\OpenConnector\\.env',
      );
    }

    try {
      final resp = await http.post(
        Uri.parse(mcpUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json, text/event-stream',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'jsonrpc': '2.0',
          'method': 'tools/call',
          'params': {
            'name': 'list_apps',
            'arguments': {'query': 'notion'}
          },
          'id': 1,
        }),
      ).timeout(const Duration(seconds: 4));

      if (resp.statusCode == 200) {
        final Map<String, dynamic> jsonBody = jsonDecode(resp.body);
        final result = jsonBody['result'];
        if (result != null && result['content'] != null) {
          final text = result['content'][0]['text'] as String;
          final Map<String, dynamic> inner = jsonDecode(text);
          final data = inner['data'] as List<dynamic>?;
          if (data != null && data.isNotEmpty) {
            final app = data.first;
            final conn = app['connection'];
            final profile = conn != null ? conn['profile'] : null;
            final name = profile != null ? profile['displayName'] as String? : 'Notion Connected';
            return OpenConnectorStatus(
              isAvailable: true,
              displayName: name ?? 'Notion Connected',
              token: token,
            );
          }
        }
      }
      return const OpenConnectorStatus(
        isAvailable: false,
        errorMessage: 'OpenConnector aktif namun aplikasi Notion belum terkonfigurasi.',
      );
    } catch (e) {
      return OpenConnectorStatus(
        isAvailable: false,
        errorMessage: 'Tidak dapat menghubungi OpenConnector di http://localhost:3000 ($e)',
      );
    }
  }

  /// List Notion pages & databases via OpenConnector notion.search
  static Future<List<NotionPageItem>> listPages() async {
    final token = getRuntimeToken();
    if (token.isEmpty) return [];

    try {
      final resp = await http.post(
        Uri.parse(mcpUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json, text/event-stream',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'jsonrpc': '2.0',
          'method': 'tools/call',
          'params': {
            'name': 'execute_action',
            'arguments': {
              'actionId': 'notion.search',
              'input': {'query': ''}
            }
          },
          'id': 2,
        }),
      ).timeout(const Duration(seconds: 10));

      if (resp.statusCode == 200) {
        final Map<String, dynamic> jsonBody = jsonDecode(resp.body);
        final content = jsonBody['result']?['content']?[0]?['text'] as String?;
        if (content != null) {
          final Map<String, dynamic> parsed = jsonDecode(content);
          final results = parsed['data']?['results'] as List<dynamic>? ?? [];
          final items = <NotionPageItem>[];
          for (final r in results) {
            final id = r['id'] as String? ?? '';
            final obj = r['object'] as String? ?? 'page';
            String title = 'Untitled';
            if (r['title'] is List && (r['title'] as List).isNotEmpty) {
              title = (r['title'] as List)[0]['plain_text'] as String? ?? 'Untitled';
            } else if (r['properties'] != null) {
              final props = r['properties'] as Map<String, dynamic>;
              for (final p in props.values) {
                if (p['type'] == 'title' && p['title'] is List && (p['title'] as List).isNotEmpty) {
                  title = (p['title'] as List)[0]['plain_text'] as String? ?? 'Untitled';
                  break;
                }
              }
            }
            if (id.isNotEmpty) {
              items.add(NotionPageItem(id: id, title: title, objectType: obj));
            }
          }
          return items;
        }
      }
    } catch (_) {}
    return [];
  }

  /// Create a page in Notion under a parent page or database
  static Future<bool> createPage({
    required String parentId,
    required String title,
    required String markdown,
  }) async {
    final token = getRuntimeToken();
    if (token.isEmpty) return false;

    try {
      final resp = await http.post(
        Uri.parse(mcpUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json, text/event-stream',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'jsonrpc': '2.0',
          'method': 'tools/call',
          'params': {
            'name': 'execute_action',
            'arguments': {
              'actionId': 'notion.create_page',
              'input': {
                'parentId': parentId,
                'title': title,
                'markdown': markdown,
              }
            }
          },
          'id': 3,
        }),
      ).timeout(const Duration(seconds: 15));

      if (resp.statusCode == 200) {
        final Map<String, dynamic> jsonBody = jsonDecode(resp.body);
        final content = jsonBody['result']?['content']?[0]?['text'] as String?;
        if (content != null) {
          final Map<String, dynamic> parsed = jsonDecode(content);
          return parsed['ok'] == true;
        }
      }
    } catch (_) {}
    return false;
  }

  /// Retrieve markdown content of a Notion page
  static Future<String> retrievePageMarkdown(String pageId) async {
    final token = getRuntimeToken();
    if (token.isEmpty) return '';

    try {
      final resp = await http.post(
        Uri.parse(mcpUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json, text/event-stream',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'jsonrpc': '2.0',
          'method': 'tools/call',
          'params': {
            'name': 'execute_action',
            'arguments': {
              'actionId': 'notion.retrieve_page_markdown',
              'input': {'pageId': pageId}
            }
          },
          'id': 4,
        }),
      ).timeout(const Duration(seconds: 12));

      if (resp.statusCode == 200) {
        final Map<String, dynamic> jsonBody = jsonDecode(resp.body);
        final content = jsonBody['result']?['content']?[0]?['text'] as String?;
        if (content != null) {
          final Map<String, dynamic> parsed = jsonDecode(content);
          final data = parsed['data'];
          if (data is Map<String, dynamic>) {
            final raw = data['markdown'] as String? ?? '';
            return cleanNotionMarkdown(raw);
          }
        }
      }
    } catch (_) {}
    return '';
  }

  /// Cleans Notion raw pseudo-XML tags and mojibake into standard, beautiful Markdown
  static String cleanNotionMarkdown(String raw) {
    if (raw.isEmpty) return '';
    var md = raw;

    // 1. Fix common mojibake characters
    md = md
        .replaceAll('â–¡â–¡', '—')
        .replaceAll('â–¡', '—')
        .replaceAll('â\x80\x93', '–')
        .replaceAll('â\x80\x94', '—')
        .replaceAll('â\x80\x99', "'")
        .replaceAll('â\x80\x9c', '"')
        .replaceAll('â\x80\x9d', '"')
        .replaceAll('âs', "'s");

    // 2. Convert Notion <database ...>TITLE</database> to ### 🗃️ [TITLE](URL)
    md = md.replaceAllMapped(
      RegExp(r'<database\s+url="([^"]+)"[^>]*>([^<]+)</database>', caseSensitive: false),
      (m) => '### 🗃️ [${m.group(2)}](${m.group(1)})',
    );

    // 3. Convert Notion <page ...>TITLE</page> to - 📄 [TITLE](URL)
    md = md.replaceAllMapped(
      RegExp(r'<page\s+url="([^"]+)"[^>]*>([^<]+)</page>', caseSensitive: false),
      (m) => '- 📄 [${m.group(2)}](${m.group(1)})',
    );

    // 4. Deduplicate repeated page links
    final lines = md.split('\n');
    final deduped = <String>[];
    final seenTitles = <String>{};
    for (final l in lines) {
      final s = l.trim();
      final match = RegExp(r'^[-\*]\s*📄\s*\[(.*?)\]').firstMatch(s);
      if (match != null) {
        final title = match.group(1)!.trim().toLowerCase();
        if (seenTitles.contains(title)) {
          continue;
        }
        seenTitles.add(title);
      }
      deduped.add(l);
    }
    md = deduped.join('\n');

    // 5. Remove dangling bare '#' headings
    md = md.replaceAll(RegExp(r'\n#\s*\n'), '\n\n');

    return md.trim();
  }
}
