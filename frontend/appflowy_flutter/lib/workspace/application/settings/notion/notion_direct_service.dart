import 'dart:convert';
import 'package:appflowy/core/config/kv.dart';
import 'package:appflowy/core/config/kv_keys.dart';
import 'package:appflowy/plugins/document/application/document_data_pb_extension.dart';
import 'package:appflowy/shared/markdown_to_document.dart';
import 'package:appflowy/startup/startup.dart';
import 'package:appflowy/workspace/application/tabs/tabs_bloc.dart';
import 'package:appflowy/workspace/application/view/view_service.dart';
import 'package:appflowy_backend/dispatch/dispatch.dart';
import 'package:appflowy_backend/protobuf/flowy-folder/protobuf.dart';
import 'package:appflowy_backend/protobuf/flowy-folder/view.pb.dart';
import 'package:appflowy/features/resume/models/resume_context_source.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;

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

class NotionDirectStatus {
  final bool isAvailable;
  final String displayName;
  final String errorMessage;

  const NotionDirectStatus({
    required this.isAvailable,
    this.displayName = '',
    this.errorMessage = '',
  });
}

/// Native, standalone Notion Service implemented directly inside Notalis.
/// Uses Notion API version 2026-03-11 with native Markdown endpoints.
/// Completely independent of OpenConnector or any external background processes.
class NotionDirectService {
  static const String apiBase = 'https://api.notion.com/v1';
  static const String apiVersion = '2026-03-11';
  static const String defaultToken = '';

  /// Get active Notion API token from KV storage or fallback to pre-authenticated token
  static Future<String> getActiveToken() async {
    try {
      final kv = getIt<KeyValueStorage>();
      final saved = await kv.get(KVKeys.kNotionApiKey);
      if (saved != null && saved.trim().length > 30 && !saved.contains('...')) {
        return saved.trim();
      }
    } catch (_) {}
    return defaultToken;
  }

  /// Check connection and get profile name directly from Notion API
  static Future<NotionDirectStatus> checkStatus() async {
    final token = await getActiveToken();
    if (token.isEmpty) {
      return const NotionDirectStatus(
        isAvailable: false,
        errorMessage: 'Token Notion belum dikonfigurasi.',
      );
    }

    try {
      final resp = await http.get(
        Uri.parse('$apiBase/users/me'),
        headers: {
          'Authorization': 'Bearer $token',
          'Notion-Version': apiVersion,
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 6));

      if (resp.statusCode == 200) {
        final Map<String, dynamic> jsonBody = jsonDecode(resp.body);
        final name = jsonBody['name'] as String? ?? 'Notion Workspace';
        return NotionDirectStatus(
          isAvailable: true,
          displayName: name,
        );
      } else {
        return NotionDirectStatus(
          isAvailable: false,
          errorMessage: 'Notion API returned status ${resp.statusCode}: ${resp.body}',
        );
      }
    } catch (e) {
      return NotionDirectStatus(
        isAvailable: false,
        errorMessage: 'Koneksi ke Notion API gagal: $e',
      );
    }
  }

  /// Search all Notion pages and databases directly
  static Future<List<NotionPageItem>> listPages() async {
    final token = await getActiveToken();
    if (token.isEmpty) return [];

    try {
      final resp = await http.post(
        Uri.parse('$apiBase/search'),
        headers: {
          'Authorization': 'Bearer $token',
          'Notion-Version': apiVersion,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'query': '',
          'page_size': 100,
        }),
      ).timeout(const Duration(seconds: 10));

      if (resp.statusCode == 200) {
        final Map<String, dynamic> jsonBody = jsonDecode(resp.body);
        final results = jsonBody['results'] as List<dynamic>? ?? [];
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
    } catch (_) {}
    return [];
  }

  /// Format a Notion database as an interactive Gallery View block with cards
  static Future<String> formatGalleryDatabase(
    String token,
    String dbId,
    String dbTitle,
    String dbUrl,
  ) async {
    try {
      final resp = await http.post(
        Uri.parse('$apiBase/databases/$dbId/query'),
        headers: {
          'Authorization': 'Bearer $token',
          'Notion-Version': '2022-06-28',
          'Content-Type': 'application/json',
        },
        body: '{}',
      ).timeout(const Duration(seconds: 8));

      if (resp.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(resp.body);
        final results = data['results'] as List? ?? [];
        if (results.isNotEmpty) {
          final cards = <Map<String, dynamic>>[];

          for (final r in results) {
            final props = r['properties'] as Map<String, dynamic>? ?? {};
            String title = 'Untitled';
            for (final p in props.values) {
              if (p['type'] == 'title' && p['title'] is List && (p['title'] as List).isNotEmpty) {
                title = (p['title'] as List)[0]['plain_text'] as String? ?? 'Untitled';
                break;
              }
            }
            final pid = (r['id'] as String? ?? '').replaceAll('-', '');
            final url = 'https://app.notion.com/p/$pid';

            String icon = '📄';
            final iconData = r['icon'] as Map<String, dynamic>?;
            if (iconData != null && iconData['type'] == 'emoji') {
              icon = iconData['emoji'] as String? ?? '📄';
            } else if (title.contains('🇮🇩')) {
              icon = '🇮🇩';
            }

            String preview = '';
            try {
              final pResp = await http.get(
                Uri.parse('$apiBase/pages/$pid/markdown'),
                headers: {
                  'Authorization': 'Bearer $token',
                  'Notion-Version': apiVersion,
                },
              ).timeout(const Duration(seconds: 4));
              if (pResp.statusCode == 200) {
                final pData = jsonDecode(pResp.body);
                final pmd = pData['markdown'] as String? ?? '';
                final lines = pmd.split('\n')
                    .map((l) => l.trim().replaceAll(RegExp(r'^#+\s*'), '').trim())
                    .where((l) => l.isNotEmpty)
                    .toList();
                if (lines.isNotEmpty) {
                  preview = lines.take(3).join('\n');
                }
              }
            } catch (_) {}

            cards.add({
              'title': title,
              'preview': preview,
              'icon': icon,
              'url': url,
            });
          }

          final cleanTitle = dbTitle.replaceAll(RegExp(r'^[^\w\s]+'), '').trim();
          final galleryData = {
            'title': cleanTitle,
            'cards': cards,
          };
          return '\n```notion:gallery\n${jsonEncode(galleryData)}\n```\n';
        }
      }
    } catch (_) {}
    return '\n### $dbTitle\n\n📄 [$dbTitle]($dbUrl)\n';
  }

  /// Open a Notion page directly in Notalis editor as an editable workspace tab
  static Future<bool> openNotionPageInWorkspace(
    BuildContext context,
    String rawPageId, {
    String? targetTitle,
  }) async {
    final pageId = rawPageId.replaceAll('-', '').toLowerCase();
    try {
      final token = await getActiveToken();
      if (token.isEmpty) return false;

      // 1. Fetch markdown with subpages expanded
      final md = await retrievePageMarkdown(pageId, expandSubpages: true);
      if (md.trim().isEmpty) return false;

      // 2. Determine title
      String title = targetTitle ?? '';
      if (title.isEmpty) {
        for (final line in md.split('\n')) {
          final t = line.trim();
          if (t.startsWith(RegExp(r'^#+\s*'))) {
            title = t.replaceAll(RegExp(r'^#+\s*'), '').trim();
            break;
          } else if (t.isNotEmpty && !t.startsWith('<') && !t.startsWith('>')) {
            title = t;
            break;
          }
        }
      }

      if (title.isEmpty) title = 'Notion Note';
      final cleanTitle = title.replaceFirst(RegExp(r'^[^\w\s]+'), '').trim();

      // 3. Check existing views
      final allViewsRes = await ViewBackendService.getAllViews();
      final existingViews = allViewsRes.toNullable()?.items ?? [];
      final matched = existingViews.where((v) =>
        v.name.trim().toLowerCase() == cleanTitle.toLowerCase() ||
        v.name.trim().toLowerCase() == title.toLowerCase()
      ).toList();

      if (matched.isNotEmpty && context.mounted) {
        getIt<TabsBloc>().openPlugin(matched.first);
        return true;
      }

      // 4. Create new view and open it
      final workspace = await FolderEventReadCurrentWorkspace().send();
      final currentWorkspace = workspace.toNullable();
      if (currentWorkspace == null) return false;

      final document = customMarkdownToDocument(md);
      final bytes = DocumentDataPBFromTo.fromDocument(document)?.writeToBuffer();

      final payload = CreateViewPayloadPB.create()
        ..parentViewId = currentWorkspace.id
        ..name = title.isNotEmpty ? title : (cleanTitle.isNotEmpty ? cleanTitle : 'Notion Note')
        ..layout = ViewLayoutPB.Document
        ..section = ViewSectionPB.Public
        ..setAsCurrent = true;

      if (bytes != null) {
        payload.initialData = bytes;
      }

      final res = await FolderEventCreateView(payload).send();
      final createdView = res.toNullable();
      if (createdView != null && context.mounted) {
        final kv = getIt<KeyValueStorage>();
        await kv.set('notion_page_id_${createdView.id}', pageId);
        getIt<TabsBloc>().openPlugin(createdView);
        return true;
      }
    } catch (_) {}
    return false;
  }

  /// Retrieve markdown content of a Notion page, with automatic deep inlining of subpages
  static Future<String> retrievePageMarkdown(String pageId, {bool expandSubpages = false}) async {
    final token = await getActiveToken();
    if (token.isEmpty) return '';

    try {
      final resp = await http.get(
        Uri.parse('$apiBase/pages/$pageId/markdown'),
        headers: {
          'Authorization': 'Bearer $token',
          'Notion-Version': apiVersion,
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 12));

      if (resp.statusCode == 200) {
        final Map<String, dynamic> jsonBody = jsonDecode(resp.body);
        var raw = jsonBody['markdown'] as String? ?? '';

        // 1. Expand <database ...> into visual Gallery Cards
        final dbMatches = RegExp(r'<database\s+url="([^"]+)"[^>]*>([^<]+)</database>', caseSensitive: false)
            .allMatches(raw);
        for (final m in dbMatches) {
          final dbUrl = m.group(1) ?? '';
          final dbTitle = m.group(2) ?? '';
          final idMatch = RegExp(r'([a-f0-9]{32})').firstMatch(dbUrl);
          if (idMatch != null) {
            final dbId = idMatch.group(1)!;
            final galleryMd = await formatGalleryDatabase(token, dbId, dbTitle, dbUrl);
            raw = raw.replaceAll(m.group(0)!, galleryMd);
          }
        }

        final cleanedParent = cleanNotionMarkdown(raw);

        if (!expandSubpages) {
          return cleanedParent;
        }

        // Detect linked subpage IDs: e.g. 📄 **[TITLE](https://app.notion.com/p/3bc49c1195b3801998beff0d64fd72e8)**
        final childMatches = RegExp(r'📄\s*(?:\*\*)?\[(.*?)\]\(.*?([a-f0-9]{32}).*?\)(?:\*\*)?')
            .allMatches(cleanedParent);

        if (childMatches.isEmpty) {
          return cleanedParent;
        }

        final inlined = StringBuffer(cleanedParent);
        final seenChildIds = <String>{pageId.replaceAll('-', '').toLowerCase()};
        for (final m in childMatches) {
          final title = m.group(1) ?? '';
          final childId = (m.group(2) ?? '').toLowerCase();
          if (childId.isNotEmpty && !seenChildIds.contains(childId)) {
            seenChildIds.add(childId);
            try {
              final cResp = await http.get(
                Uri.parse('$apiBase/pages/$childId/markdown'),
                headers: {
                  'Authorization': 'Bearer $token',
                  'Notion-Version': apiVersion,
                  'Content-Type': 'application/json',
                },
              ).timeout(const Duration(seconds: 8));

              if (cResp.statusCode == 200) {
                final Map<String, dynamic> cJson = jsonDecode(cResp.body);
                final cRaw = cJson['markdown'] as String? ?? '';
                final cClean = cleanNotionMarkdown(cRaw);
                if (cClean.trim().isNotEmpty) {
                  inlined.write('\n\n---\n## 📄 $title\n\n$cClean');
                }
              }
            } catch (_) {}
          }
        }
        return inlined.toString();
      }
    } catch (_) {}
    return '';
  }

  /// Directly update/modify a Notion page's content via Notion API v2026-03-11
  static Future<bool> updatePageMarkdown({
    required String pageId,
    required String markdown,
  }) async {
    final token = await getActiveToken();
    if (token.isEmpty) return false;

    try {
      final resp = await http.patch(
        Uri.parse('$apiBase/pages/$pageId/markdown'),
        headers: {
          'Authorization': 'Bearer $token',
          'Notion-Version': apiVersion,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'type': 'replace_content',
          'replace_content': {'new_str': markdown},
        }),
      ).timeout(const Duration(seconds: 15));

      return resp.statusCode == 200 || resp.statusCode == 201;
    } catch (_) {}
    return false;
  }

  /// Create a page in Notion directly under a parent page or database
  static Future<bool> createPage({
    required String parentId,
    required String title,
    required String markdown,
  }) async {
    final token = await getActiveToken();
    if (token.isEmpty) return false;

    try {
      final cleanTitle = title.trim().isEmpty ? 'Untitled' : title.trim();
      final body = jsonEncode({
        'parent': {'page_id': parentId},
        'properties': {
          'title': [
            {
              'type': 'text',
              'text': {'content': cleanTitle}
            }
          ]
        },
        'markdown': markdown,
      });

      var resp = await http.post(
        Uri.parse('$apiBase/pages'),
        headers: {
          'Authorization': 'Bearer $token',
          'Notion-Version': apiVersion,
          'Content-Type': 'application/json',
        },
        body: body,
      ).timeout(const Duration(seconds: 15));

      if (resp.statusCode == 200 || resp.statusCode == 201) {
        return true;
      }

      // Fallback: try as database_id if page_id failed
      final dbBody = jsonEncode({
        'parent': {'database_id': parentId},
        'properties': {
          'title': [
            {
              'type': 'text',
              'text': {'content': cleanTitle}
            }
          ]
        },
        'markdown': markdown,
      });

      resp = await http.post(
        Uri.parse('$apiBase/pages'),
        headers: {
          'Authorization': 'Bearer $token',
          'Notion-Version': apiVersion,
          'Content-Type': 'application/json',
        },
        body: dbBody,
      ).timeout(const Duration(seconds: 15));

      return resp.statusCode == 200 || resp.statusCode == 201;
    } catch (_) {}
    return false;
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

    // 2. Convert remaining Notion <database ...>TITLE</database> to clean section
    md = md.replaceAllMapped(
      RegExp(r'<database\s+url="([^"]+)"[^>]*>([^<]+)</database>', caseSensitive: false),
      (m) => '\n### ${m.group(2)}\n\n📄 [${m.group(2)}](${m.group(1)})\n',
    );

    // 3. Convert Notion <page ...>TITLE</page> to clean Notion Page Block
    md = md.replaceAllMapped(
      RegExp(r'<page\s+url="([^"]+)"[^>]*>([^<]+)</page>', caseSensitive: false),
      (m) => '📄 [${m.group(2)}](${m.group(1)})\n',
    );

    // 4. Deduplicate repeated page links
    final lines = md.split('\n');
    final deduped = <String>[];
    final seenTitles = <String>{};
    for (final l in lines) {
      final s = l.trim();
      final match = RegExp(r'📄\s*(?:\*\*)?\[(.*?)\]').firstMatch(s);
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

  /// Automatically fetches all projects and database records across the entire Notion workspace
  static Future<String> fetchAllWorkspaceProjectsMarkdown({
    void Function(String status)? onProgress,
  }) async {
    final token = await getActiveToken();
    if (token.isEmpty) return '';

    final buffer = StringBuffer();
    try {
      onProgress?.call('Memindai seluruh database dan halaman di Notion...');
      final resp = await http.post(
        Uri.parse('$apiBase/search'),
        headers: {
          'Authorization': 'Bearer $token',
          'Notion-Version': apiVersion,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'query': '',
          'page_size': 100,
        }),
      ).timeout(const Duration(seconds: 12));

      if (resp.statusCode != 200) return '';
      final Map<String, dynamic> data = jsonDecode(resp.body);
      final results = data['results'] as List? ?? [];

      final databases = results.where((r) => r['object'] == 'database').toList();
      final pages = results.where((r) => r['object'] == 'page').toList();

      // 1. Process all databases (Projects, Tasks, Experience logs)
      for (final db in databases) {
        final dbId = db['id'] as String? ?? '';
        String dbTitle = 'Database Proyek';
        if (db['title'] is List && (db['title'] as List).isNotEmpty) {
          dbTitle = (db['title'] as List)[0]['plain_text'] as String? ?? dbTitle;
        }

        onProgress?.call('Membaca database Notion: $dbTitle...');
        buffer.writeln('### NOTION DATABASE: $dbTitle');

        try {
          final queryResp = await http.post(
            Uri.parse('$apiBase/databases/$dbId/query'),
            headers: {
              'Authorization': 'Bearer $token',
              'Notion-Version': '2022-06-28',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'page_size': 100}),
          ).timeout(const Duration(seconds: 10));

          if (queryResp.statusCode == 200) {
            final qData = jsonDecode(queryResp.body);
            final rows = qData['results'] as List? ?? [];
            for (final r in rows) {
              final props = r['properties'] as Map<String, dynamic>? ?? {};
              String itemTitle = '';
              final propDetails = <String>[];

              for (final entry in props.entries) {
                final p = entry.value as Map<String, dynamic>;
                final type = p['type'] as String? ?? '';
                if (type == 'title' && p['title'] is List && (p['title'] as List).isNotEmpty) {
                  itemTitle = (p['title'] as List)[0]['plain_text'] as String? ?? '';
                } else if (type == 'rich_text' && p['rich_text'] is List && (p['rich_text'] as List).isNotEmpty) {
                  final text = (p['rich_text'] as List)[0]['plain_text'] as String? ?? '';
                  if (text.isNotEmpty) propDetails.add('${entry.key}: $text');
                } else if (type == 'select' && p['select'] != null) {
                  propDetails.add('${entry.key}: ${p['select']['name']}');
                } else if (type == 'status' && p['status'] != null) {
                  propDetails.add('${entry.key}: ${p['status']['name']}');
                } else if (type == 'multi_select' && p['multi_select'] is List) {
                  final tags = (p['multi_select'] as List).map((t) => t['name'].toString()).join(', ');
                  if (tags.isNotEmpty) propDetails.add('${entry.key}: $tags');
                } else if (type == 'date' && p['date'] != null) {
                  propDetails.add('${entry.key}: ${p['date']['start']}');
                }
              }

              if (itemTitle.isNotEmpty) {
                buffer.writeln('- **$itemTitle** (${propDetails.join(' | ')})');
              }
            }
          }
        } catch (_) {}
        buffer.writeln();
      }

      // 2. Process standalone pages (Portfolio, CV notes, Project Docs)
      final relevantPages = pages.where((p) {
        final props = p['properties'] as Map<String, dynamic>? ?? {};
        for (final val in props.values) {
          if (val['type'] == 'title' && val['title'] is List && (val['title'] as List).isNotEmpty) {
            final t = (val['title'] as List)[0]['plain_text'] as String? ?? '';
            if (t.isNotEmpty && t != 'Untitled') return true;
          }
        }
        return false;
      }).toList();

      for (final p in relevantPages.take(25)) {
        final pId = p['id'] as String? ?? '';
        String pTitle = 'Halaman Notion';
        final props = p['properties'] as Map<String, dynamic>? ?? {};
        for (final val in props.values) {
          if (val['type'] == 'title' && val['title'] is List && (val['title'] as List).isNotEmpty) {
            pTitle = (val['title'] as List)[0]['plain_text'] as String? ?? pTitle;
            break;
          }
        }

        try {
          final pResp = await http.get(
            Uri.parse('$apiBase/pages/$pId/markdown'),
            headers: {
              'Authorization': 'Bearer $token',
              'Notion-Version': apiVersion,
            },
          ).timeout(const Duration(seconds: 5));

          if (pResp.statusCode == 200) {
            final pData = jsonDecode(pResp.body);
            final md = pData['markdown'] as String? ?? '';
            if (md.trim().isNotEmpty) {
              buffer.writeln('### HALAMAN NOTION: $pTitle');
              final truncated = md.length > 800 ? '${md.substring(0, 800)}...' : md;
              buffer.writeln(truncated);
              buffer.writeln();
            }
          }
        } catch (_) {}
      }
    } catch (_) {}

    return buffer.toString();
  }

  /// Extract a clean 32-character hex Notion ID
  static String extractNotionId(String input) {
    final raw = input.trim();
    if (raw.isEmpty) return '';
    final regHex32 = RegExp(r'([a-f0-9]{32})', caseSensitive: false);
    final matchHex = regHex32.firstMatch(raw.replaceAll('-', ''));
    if (matchHex != null) return matchHex.group(1)!;
    final regUuid = RegExp(
      r'([a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12})',
      caseSensitive: false,
    );
    final matchUuid = regUuid.firstMatch(raw);
    if (matchUuid != null) return matchUuid.group(1)!.replaceAll('-', '');
    return raw.replaceAll('-', '');
  }

  /// Formats a 32-hex Notion ID into standard dashed UUID string
  static String toNotionUuid(String input) {
    final clean = extractNotionId(input);
    if (clean.length == 32) {
      return '${clean.substring(0, 8)}-${clean.substring(8, 12)}-${clean.substring(12, 16)}-${clean.substring(16, 20)}-${clean.substring(20)}';
    }
    return input.trim();
  }

  /// Discovers all Notion databases and pages as selectable context sources
  static Future<List<ResumeContextSource>> discoverNotionSources({
    void Function(String status)? onProgress,
  }) async {
    final token = await getActiveToken();
    if (token.isEmpty) return [];

    final sources = <ResumeContextSource>[];
    try {
      onProgress?.call('Memindai database & halaman Notion...');
      final resp = await http.post(
        Uri.parse('$apiBase/search'),
        headers: {
          'Authorization': 'Bearer $token',
          'Notion-Version': apiVersion,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'query': '',
          'page_size': 100,
        }),
      ).timeout(const Duration(seconds: 10));

      if (resp.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(resp.body);
        final results = data['results'] as List? ?? [];

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

          if (id.isNotEmpty && title != 'Untitled') {
            sources.add(
              ResumeContextSource(
                id: id,
                title: title,
                sourceType: obj == 'database' ? 'notion_db' : 'notion_page',
                detail: obj == 'database' ? 'Notion Database' : 'Notion Page',
                isSelected: true,
              ),
            );
          }
        }
      }
    } catch (_) {}

    return sources;
  }

  /// Deeply scans any Notion page URL or ID, discovering the root page, its subpages, and all embedded database collections
  static Future<List<ResumeContextSource>> fetchNotionUrlDeepSources(
    String urlOrId, {
    void Function(String status)? onProgress,
  }) async {
    final cleanId = extractNotionId(urlOrId);
    if (cleanId.isEmpty) return [];
    final rootUuid = toNotionUuid(cleanId);

    final discovered = <ResumeContextSource>[];
    final seenPages = <String>{};
    final seenColls = <String>{};

    onProgress?.call('Memindai struktur tautan Notion...');

    Future<Map<String, dynamic>?> loadChunk(String pageId) async {
      final pid = toNotionUuid(pageId);
      try {
        final resp = await http.post(
          Uri.parse('https://www.notion.so/api/v3/loadPageChunk'),
          headers: {
            'Content-Type': 'application/json',
            'User-Agent': 'Mozilla/5.0',
          },
          body: jsonEncode({
            'pageId': pid,
            'limit': 100,
            'cursor': {'stack': []},
            'chunkNumber': 0,
            'verticalColumns': false,
          }),
        ).timeout(const Duration(seconds: 10));

        if (resp.statusCode == 200) {
          final decoded = utf8.decode(resp.bodyBytes, allowMalformed: true);
          return jsonDecode(decoded) as Map<String, dynamic>;
        }
      } catch (_) {}
      return null;
    }

    final rootRes = await loadChunk(rootUuid);
    if (rootRes == null) return discovered;

    final rm = rootRes['recordMap'] as Map<String, dynamic>? ?? {};
    final blocks = rm['block'] as Map<String, dynamic>? ?? {};
    final collections = rm['collection'] as Map<String, dynamic>? ?? {};
    final collectionViews = rm['collection_view'] as Map<String, dynamic>? ?? {};

    // 1. Root page
    String rootTitle = 'Halaman Utama Notion';
    final rootBuffer = StringBuffer();
    for (final b in blocks.values) {
      final val = (b as Map<String, dynamic>)['value']?['value'] as Map<String, dynamic>? ?? {};
      final props = val['properties'] as Map<String, dynamic>? ?? {};
      final titleList = props['title'] as List? ?? [];
      if (titleList.isNotEmpty) {
        final t = titleList.map((x) => x is List && x.isNotEmpty ? x[0].toString() : '').join().trim();
        if (t.isNotEmpty) {
          if (rootTitle == 'Halaman Utama Notion' && val['type'] == 'page') {
            rootTitle = t;
          }
          rootBuffer.writeln('- $t');
        }
      }
    }

    discovered.add(
      ResumeContextSource(
        id: rootUuid,
        title: rootTitle,
        sourceType: 'custom_page',
        detail: 'Halaman Utama',
        isSelected: true,
        content: rootBuffer.toString(),
      ),
    );
    seenPages.add(rootUuid);

    // 2. Discover subpages & collections in root
    final childPageIds = <String>[];
    for (final entry in blocks.entries) {
      final bId = entry.key;
      final val = (entry.value as Map<String, dynamic>)['value']?['value'] as Map<String, dynamic>? ?? {};
      if (val['type'] == 'page' && !seenPages.contains(bId)) {
        final props = val['properties'] as Map<String, dynamic>? ?? {};
        final titleList = props['title'] as List? ?? [];
        final tStr = titleList.map((x) => x is List && x.isNotEmpty ? x[0].toString() : '').join().trim();
        if (tStr.isNotEmpty && !tStr.toLowerCase().contains('untitled')) {
          childPageIds.add(bId);
          seenPages.add(bId);
        }
      }
    }

    Future<void> addCollectionSource(String cId, Map<String, dynamic> cMap, String spaceId) async {
      final cVal = (cMap)['value']?['value'] as Map<String, dynamic>? ?? {};
      final nameList = cVal['name'] as List? ?? [];
      final cName = nameList.isNotEmpty && nameList[0] is List && (nameList[0] as List).isNotEmpty
          ? (nameList[0] as List)[0].toString()
          : 'Koleksi Database';

      final cvId = collectionViews.isNotEmpty ? collectionViews.keys.first : '';
      final spId = spaceId.isNotEmpty ? spaceId : (cVal['space_id'] as String? ?? '');

      try {
        final qReq = await http.post(
          Uri.parse('https://www.notion.so/api/v3/queryCollection'),
          headers: {'Content-Type': 'application/json', 'User-Agent': 'Mozilla/5.0'},
          body: jsonEncode({
            'collection': {'id': cId, if (spId.isNotEmpty) 'spaceId': spId},
            'collectionView': {'id': cvId, if (spId.isNotEmpty) 'spaceId': spId},
            'loader': {
              'type': 'reducer',
              'reducers': {
                'collection_group_results': {'type': 'results', 'limit': 60}
              },
              'userTimeZone': 'Asia/Jakarta'
            }
          }),
        ).timeout(const Duration(seconds: 10));

        if (qReq.statusCode == 200) {
          final qRes = jsonDecode(utf8.decode(qReq.bodyBytes, allowMalformed: true)) as Map<String, dynamic>;
          final qBlocks = (qRes['recordMap'] as Map<String, dynamic>?)?['block'] as Map<String, dynamic>? ?? {};
          final cBuffer = StringBuffer();
          int itemCount = 0;

          for (final qb in qBlocks.values) {
            final bVal = (qb as Map<String, dynamic>)['value']?['value'] as Map<String, dynamic>? ?? {};
            final bProps = bVal['properties'] as Map<String, dynamic>? ?? {};
            final bTitleList = bProps['title'] as List? ?? [];
            if (bTitleList.isNotEmpty) {
              final title = bTitleList.map((x) => x is List && x.isNotEmpty ? x[0].toString() : '').join().trim();
              if (title.isNotEmpty) {
                itemCount++;
                final details = <String>[];
                for (final pEntry in bProps.entries) {
                  if (pEntry.key != 'title') {
                    final pList = pEntry.value as List? ?? [];
                    final pStr = pList.map((x) => x is List && x.isNotEmpty ? x[0].toString() : '').join().trim();
                    if (pStr.isNotEmpty && pStr != '‣' && !pStr.endsWith('.png') && !pStr.endsWith('.jpg')) {
                      details.add(pStr);
                    }
                  }
                }
                final detailStr = details.isNotEmpty ? ' (${details.join(' | ')})' : '';
                cBuffer.writeln('- **$title**$detailStr');
              }
            }
          }

          discovered.add(
            ResumeContextSource(
              id: cId,
              title: cName,
              sourceType: 'custom_db',
              detail: '$itemCount entri proyek/data',
              isSelected: true,
              content: cBuffer.toString(),
            ),
          );
        }
      } catch (_) {}
    }

    for (final cEntry in collections.entries) {
      if (!seenColls.contains(cEntry.key)) {
        seenColls.add(cEntry.key);
        await addCollectionSource(cEntry.key, cEntry.value as Map<String, dynamic>, '');
      }
    }

    // 3. Scan child pages for deeper collections and content
    for (final cpid in childPageIds.take(4)) {
      final childRes = await loadChunk(cpid);
      if (childRes != null) {
        final cRm = childRes['recordMap'] as Map<String, dynamic>? ?? {};
        final cBlocks = cRm['block'] as Map<String, dynamic>? ?? {};
        final cColls = cRm['collection'] as Map<String, dynamic>? ?? {};

        String pageTitle = 'Sub-halaman';
        final pageBuffer = StringBuffer();
        for (final b in cBlocks.values) {
          final val = (b as Map<String, dynamic>)['value']?['value'] as Map<String, dynamic>? ?? {};
          final props = val['properties'] as Map<String, dynamic>? ?? {};
          final titleList = props['title'] as List? ?? [];
          if (titleList.isNotEmpty) {
            final t = titleList.map((x) => x is List && x.isNotEmpty ? x[0].toString() : '').join().trim();
            if (t.isNotEmpty) {
              if (pageTitle == 'Sub-halaman' && val['type'] == 'page') {
                pageTitle = t;
              }
              pageBuffer.writeln('- $t');
            }
          }
        }

        discovered.add(
          ResumeContextSource(
            id: cpid,
            title: pageTitle,
            sourceType: 'custom_page',
            detail: 'Sub-halaman Notion',
            isSelected: true,
            content: pageBuffer.toString(),
          ),
        );

        for (final cEntry in cColls.entries) {
          if (!seenColls.contains(cEntry.key)) {
            seenColls.add(cEntry.key);
            await addCollectionSource(cEntry.key, cEntry.value as Map<String, dynamic>, '');
          }
        }
      }
    }

    return discovered;
  }

  /// Fetches content for any Notion page or database ID/URL, using official API with public fallback
  static Future<Map<String, String>> fetchNotionItemDetails(
    String urlOrId, {
    void Function(String status)? onProgress,
  }) async {
    final cleanId = extractNotionId(urlOrId);
    if (cleanId.isEmpty) return {'title': 'Invalid ID', 'content': ''};

    final token = await getActiveToken();

    // 1. Try official Notion database query first
    if (token.isNotEmpty) {
      try {
        final qResp = await http.post(
          Uri.parse('$apiBase/databases/$cleanId/query'),
          headers: {
            'Authorization': 'Bearer $token',
            'Notion-Version': '2022-06-28',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'page_size': 100}),
        ).timeout(const Duration(seconds: 8));

        if (qResp.statusCode == 200) {
          final qData = jsonDecode(qResp.body);
          final rows = qData['results'] as List? ?? [];
          final buffer = StringBuffer();
          for (final r in rows) {
            final props = r['properties'] as Map<String, dynamic>? ?? {};
            String itemTitle = '';
            final propDetails = <String>[];
            for (final entry in props.entries) {
              final p = entry.value as Map<String, dynamic>;
              final type = p['type'] as String? ?? '';
              if (type == 'title' && p['title'] is List && (p['title'] as List).isNotEmpty) {
                itemTitle = (p['title'] as List)[0]['plain_text'] as String? ?? '';
              } else if (type == 'rich_text' && p['rich_text'] is List && (p['rich_text'] as List).isNotEmpty) {
                final text = (p['rich_text'] as List)[0]['plain_text'] as String? ?? '';
                if (text.isNotEmpty) propDetails.add('${entry.key}: $text');
              } else if (type == 'select' && p['select'] != null) {
                propDetails.add('${entry.key}: ${p['select']['name']}');
              } else if (type == 'status' && p['status'] != null) {
                propDetails.add('${entry.key}: ${p['status']['name']}');
              } else if (type == 'multi_select' && p['multi_select'] is List) {
                final tags = (p['multi_select'] as List).map((t) => t['name'].toString()).join(', ');
                if (tags.isNotEmpty) propDetails.add('${entry.key}: $tags');
              }
            }
            if (itemTitle.isNotEmpty) {
              buffer.writeln('- **$itemTitle** (${propDetails.join(' | ')})');
            }
          }
          if (buffer.isNotEmpty) {
            return {'title': 'Database $cleanId', 'content': buffer.toString()};
          }
        }
      } catch (_) {}

      // 2. Try official Notion page markdown
      try {
        final pResp = await http.get(
          Uri.parse('$apiBase/pages/$cleanId/markdown'),
          headers: {
            'Authorization': 'Bearer $token',
            'Notion-Version': apiVersion,
          },
        ).timeout(const Duration(seconds: 8));

        if (pResp.statusCode == 200) {
          final pData = jsonDecode(pResp.body);
          final md = pData['markdown'] as String? ?? '';
          if (md.trim().isNotEmpty) {
            String title = 'Halaman Notion';
            for (final l in md.split('\n')) {
              if (l.trim().startsWith(RegExp(r'^#+\s*'))) {
                title = l.trim().replaceAll(RegExp(r'^#+\s*'), '').trim();
                break;
              }
            }
            return {'title': title, 'content': md};
          }
        }
      } catch (_) {}
    }

    return {'title': 'Notion Item', 'content': ''};
  }
}
