import 'dart:convert';
import 'dart:io';
import 'package:appflowy/core/config/kv.dart';
import 'package:appflowy/core/config/kv_keys.dart';
import 'package:appflowy/startup/startup.dart';
import 'package:appflowy/workspace/application/settings/notion/notion_direct_service.dart';
import 'package:appflowy_backend/dispatch/dispatch.dart';
import 'package:http/http.dart' as http;

import '../models/resume_context_source.dart';
import '../models/resume_data.dart';

class ResumeAiGeneratorService {
  /// Discovers all available context sources across Notalis workspace views, local docs, and Notion databases/pages
  static Future<List<ResumeContextSource>> discoverContextSources({
    bool includeNotalis = true,
    bool includeNotion = true,
    void Function(String status)? onProgress,
  }) async {
    final sources = <ResumeContextSource>[];

    // 1. Discover Notalis views
    if (includeNotalis) {
      onProgress?.call('Memindai dokumen Notalis...');
      try {
        final res = await FolderEventGetAllViews().send();
        final views = res.toNullable()?.items ?? [];
        for (final v in views) {
          if (v.name.trim().isNotEmpty) {
            sources.add(
              ResumeContextSource(
                id: v.id,
                title: v.name,
                sourceType: 'notalis_doc',
                detail: 'Halaman Notalis',
                isSelected: true,
              ),
            );
          }
        }

        final kv = getIt<KeyValueStorage>();
        final customFolder = await kv.get(KVKeys.kCustomLocalFolderPath);
        if (customFolder != null && customFolder.isNotEmpty) {
          final dir = Directory(customFolder);
          if (dir.existsSync()) {
            final files = dir.listSync().whereType<File>().take(10);
            for (final f in files) {
              if (f.path.endsWith('.md') || f.path.endsWith('.txt')) {
                sources.add(
                  ResumeContextSource(
                    id: f.path,
                    title: f.uri.pathSegments.last,
                    sourceType: 'notalis_file',
                    detail: 'File Dokumen Lokal',
                    isSelected: true,
                  ),
                );
              }
            }
          }
        }
      } catch (_) {}
    }

    // 2. Discover Notion sources (Databases & Pages)
    if (includeNotion) {
      onProgress?.call('Memindai database & halaman Notion...');
      try {
        final notionSources = await NotionDirectService.discoverNotionSources(onProgress: onProgress);
        sources.addAll(notionSources);
      } catch (_) {}
    }

    return sources;
  }

  /// Deeply scans any Notion page or database URL/ID and returns ALL pages & sub-collections found
  static Future<List<ResumeContextSource>> resolveCustomNotionSources(
    String urlOrId, {
    void Function(String status)? onProgress,
  }) async {
    onProgress?.call('Memindai seluruh halaman & database dari tautan...');
    final sources = await NotionDirectService.fetchNotionUrlDeepSources(urlOrId, onProgress: onProgress);
    return sources;
  }

  /// Generates a ResumeData object using ONLY user-selected context sources and optional custom prompt
  static Future<ResumeData> generateResumeFromSources({
    required String targetRole,
    required List<ResumeContextSource> selectedSources,
    String? customPrompt,
    String language = 'id',
    bool isMoa = false,
    String moaPreset = 'balanced',
    String? selectedModel,
    void Function(String status)? onProgress,
  }) async {
    final buffer = StringBuffer();
    final active = selectedSources.where((s) => s.isSelected).toList();

    for (int i = 0; i < active.length; i++) {
      final s = active[i];
      onProgress?.call('Membaca [${i + 1}/${active.length}]: ${s.title}...');
      if (s.content.isNotEmpty) {
        buffer.writeln('=== [${s.typeLabel.toUpperCase()}] ${s.title} ===');
        buffer.writeln(s.content);
        buffer.writeln();
      } else if (s.sourceType == 'notalis_file') {
        try {
          final f = File(s.id);
          if (f.existsSync()) {
            final text = f.readAsStringSync();
            final snippet = text.length > 800 ? text.substring(0, 800) : text;
            buffer.writeln('=== [FILE] ${s.title} ===');
            buffer.writeln(snippet);
            buffer.writeln();
          }
        } catch (_) {}
      } else if (s.sourceType == 'notion_db' || s.sourceType == 'notion_page') {
        try {
          final details = await NotionDirectService.fetchNotionItemDetails(s.id, onProgress: onProgress);
          final content = details['content'] ?? '';
          if (content.isNotEmpty) {
            buffer.writeln('=== [${s.typeLabel.toUpperCase()}] ${s.title} ===');
            buffer.writeln(content);
            buffer.writeln();
          }
        } catch (_) {}
      } else if (s.sourceType == 'notalis_doc') {
        buffer.writeln('• Catatan Notalis: ${s.title}');
      }
    }

    return _executeAiRequest(
      contextData: buffer.toString(),
      targetRole: targetRole,
      customPrompt: customPrompt,
      language: language,
      isMoa: isMoa,
      moaPreset: moaPreset,
      selectedModel: selectedModel,
      onProgress: onProgress,
    );
  }

  /// Scans Notalis workspace views and Notion pages/databases, then uses AI to compose ResumeData.
  static Future<ResumeData> generateResumeFromContext({
    required String targetRole,
    String? customPrompt,
    String language = 'id',
    bool readNotalis = true,
    bool readNotion = true,
    bool isMoa = false,
    String moaPreset = 'balanced',
    String? selectedModel,
    void Function(String status)? onProgress,
  }) async {
    final sources = await discoverContextSources(
      includeNotalis: readNotalis,
      includeNotion: readNotion,
      onProgress: onProgress,
    );
    return generateResumeFromSources(
      targetRole: targetRole,
      selectedSources: sources,
      customPrompt: customPrompt,
      language: language,
      isMoa: isMoa,
      moaPreset: moaPreset,
      selectedModel: selectedModel,
      onProgress: onProgress,
    );
  }

  static Future<ResumeData> _executeAiRequest({
    required String contextData,
    required String targetRole,
    String? customPrompt,
    String language = 'id',
    bool isMoa = false,
    String moaPreset = 'balanced',
    String? selectedModel,
    void Function(String status)? onProgress,
  }) async {
    final buffer = StringBuffer(contextData);

    // Prepare AI Request & Endpoint
    final kv = getIt<KeyValueStorage>();
    final customEndpoint = await kv.get(KVKeys.kCustomAiEndpoint) ?? 'http://localhost:20128/v1';
    final apiKey = await kv.get(KVKeys.kCustomAiApiKey) ?? '';
    final defaultModel = await kv.get(KVKeys.kCustomAiModel) ?? 'gpt-4o';
    final targetModel = selectedModel?.isNotEmpty == true ? selectedModel! : defaultModel;

    var targetUrl = customEndpoint.trim();
    if (targetUrl.endsWith('/')) targetUrl = targetUrl.substring(0, targetUrl.length - 1);
    if (!targetUrl.endsWith('/chat/completions')) {
      if (targetUrl.endsWith('/v1')) {
        targetUrl = '$targetUrl/chat/completions';
      } else {
        targetUrl = '$targetUrl/v1/chat/completions';
      }
    }

    final isIndonesian = language.toLowerCase() == 'id';
    final languageDirective = isIndonesian
        ? '''
STRICT LANGUAGE REQUIREMENT:
- All generated text (summary, headline, job titles, roles, company summaries, achievement highlights, project descriptions, skills categories, education) MUST be written in professional, formal BAHASA INDONESIA (PUEBI standard).
- Use active Indonesian verbs for highlights (e.g. "Merancang", "Mengembangkan", "Memimpin", "Mengoptimasi", "Mengeksekusi", "Menganalisis").
- Do NOT mix with English except for universally recognized technical terms, tool names, or software (e.g. "Unreal Engine", "C++", "DevOps", "CI/CD").
'''
        : '''
STRICT LANGUAGE REQUIREMENT:
- All generated text MUST be written in professional, fluent, ATS-optimized ENGLISH.
- Use strong action verbs for highlights (e.g. "Spearheaded", "Engineered", "Architected", "Accelerated", "Optimized", "Delivered").
''';

    final userCustomBlock = (customPrompt != null && customPrompt.trim().isNotEmpty)
        ? '''
USER CUSTOM INSTRUCTIONS & SPECIAL EMPHASIS:
${customPrompt.trim()}
- MANDATORY: You MUST strictly prioritize and obey the user's custom instructions above.
'''
        : '';

    final schemaInstruction = '''
You are an expert ATS Resume Specialist and Career Architect.
$languageDirective

CRITICAL DYNAMIC CONTEXT INSTRUCTION:
- Analyze the user's selected workspace and Notion context documents dynamically without bias.
- Extract the candidate's real identity (name, email, phone, location, education, major) directly from the context.
- Extract all authentic work experiences, professional internships, capstone projects, coursework, leadership/teaching roles, and industry certifications found in the provided context.
- Prioritize real accomplishments, metrics, software tools, and deliverables explicitly stated in the context.
- Map professional internships and employment to "work".
- Map capstone, academic, and creative/software projects to "projects".
- Map certifications, organizational roles, and technologies to "skills".
- Map educational background (institutions, degrees, GPAs, study areas) to "education".
- If context is empty, construct a high-impact profile tailored specifically to the user's target role: "$targetRole".
- Formulate achievements with strong action verbs and quantifiable metrics.
$userCustomBlock

Generate a comprehensive, ATS-optimized Resume matching the JSON schema below.
Return ONLY valid JSON without markdown wrapping or commentary.

JSON Schema:
{
  "basics": {
    "name": "Full Name from Context or Target",
    "label": "Professional Headline / Target Role",
    "email": "email@example.com",
    "phone": "+62 812-xxxx-xxxx",
    "url": "linkedin.com/in/username",
    "location": "City, Country",
    "picture": "",
    "summary": "2-3 concise sentences with quantifiable technical and architectural impact.",
    "profiles": [{"network": "LinkedIn", "username": "...", "url": "..."}, {"network": "GitHub", "username": "...", "url": "..."}]
  },
  "work": [
    {
      "id": "1",
      "company": "Company or Studio Name from Context",
      "position": "Job Title",
      "website": "https://...",
      "startDate": "Mon YYYY",
      "endDate": "Present",
      "current": true,
      "summary": "Scope of role and core systems",
      "highlights": ["Action verb + metric achievement 1", "Action verb + metric achievement 2", "Action verb + metric achievement 3"]
    }
  ],
  "education": [
    {
      "id": "1",
      "institution": "University Name",
      "area": "Major / Field of Study",
      "studyType": "Degree",
      "startDate": "YYYY",
      "endDate": "YYYY",
      "score": "3.85 / 4.00",
      "courses": ["Course 1", "Course 2"]
    }
  ],
  "skills": [
    {
      "id": "1",
      "name": "Technical Domain or Category",
      "level": "5",
      "keywords": ["Tool1", "Tool2", "Framework"]
    }
  ],
  "projects": [
    {
      "id": "1",
      "name": "Project Name",
      "description": "Concise architectural and business impact description",
      "url": "https://...",
      "startDate": "YYYY",
      "endDate": "YYYY",
      "highlights": ["Key achievement or deliverable"],
      "keywords": ["Tool1", "Tool2"]
    }
  ],
  "metadata": {
    "template": "indonesia_pro",
    "primaryColor": "#1E3A8A",
    "fontFamily": "Inter",
    "photoShape": "circle",
    "photoSize": 80.0,
    "showPhoto": true
  }
}
''';

    if (isMoa) {
      // --- Mixture of Agents (MOA) Engine ---
      onProgress?.call('Menjalankan Layer 1 Multi-Agent ($moaPreset)...');

      final agent1Prompt = '''
You are the ATS Optimization & Keyword Specialist Agent.
Analyze the user context and draft optimal work highlights, action verbs, and quantifiable metrics for target role: "$targetRole".
$languageDirective
$userCustomBlock
Context:
${buffer.toString()}
''';

      final agent2Prompt = '''
You are the Systems Architect & Technical Precision Agent.
Focus on identifying concrete technical competencies, frameworks, tools, architectures, and real projects from the context.
$languageDirective
$userCustomBlock
Context:
${buffer.toString()}
''';

      final agentResults = await Future.wait([
        http.post(
          Uri.parse(targetUrl),
          headers: {'Content-Type': 'application/json', if (apiKey.isNotEmpty) 'Authorization': 'Bearer $apiKey'},
          body: jsonEncode({
            'model': targetModel,
            'messages': [{'role': 'user', 'content': agent1Prompt}],
            'temperature': 0.4,
          }),
        ).timeout(const Duration(seconds: 40)).then((r) => r.statusCode == 200 ? r.body : ''),
        http.post(
          Uri.parse(targetUrl),
          headers: {'Content-Type': 'application/json', if (apiKey.isNotEmpty) 'Authorization': 'Bearer $apiKey'},
          body: jsonEncode({
            'model': targetModel,
            'messages': [{'role': 'user', 'content': agent2Prompt}],
            'temperature': 0.4,
          }),
        ).timeout(const Duration(seconds: 40)).then((r) => r.statusCode == 200 ? r.body : ''),
      ]);

      onProgress?.call('Agregator MOA sedang menyusun hasil akhir CV...');

      final aggregatorSystem = '''
You are the Master Aggregator Agent. Synthesize insights from the specialized agents and user context into a single, polished ATS Resume matching the exact JSON schema.
$schemaInstruction
''';

      final aggregatorUser = '''
Target Role: $targetRole
Agent 1 Insights (ATS & Impact):
${agentResults[0]}

Agent 2 Insights (Technical & Architectures):
${agentResults[1]}

Original Context:
${buffer.toString()}
''';

      final finalResp = await http.post(
        Uri.parse(targetUrl),
        headers: {'Content-Type': 'application/json', if (apiKey.isNotEmpty) 'Authorization': 'Bearer $apiKey'},
        body: jsonEncode({
          'model': targetModel,
          'messages': [
            {'role': 'system', 'content': aggregatorSystem},
            {'role': 'user', 'content': aggregatorUser},
          ],
          'temperature': 0.2,
        }),
      ).timeout(const Duration(seconds: 45));

      if (finalResp.statusCode == 200) {
        return _parseJsonResponse(utf8.decode(finalResp.bodyBytes, allowMalformed: true));
      } else {
        throw Exception('MOA API error (${finalResp.statusCode}): ${finalResp.body}');
      }
    } else {
      // --- Single Model Engine ---
      onProgress?.call('Menyusun draf CV dengan $targetModel...');

      final systemPrompt = '''
You are an expert Executive Career Coach and Resume Specialist following Reactive Resume standards.
$schemaInstruction
''';

      final userMessage = '''
Target Role: $targetRole

Workspace & Notion Context:
${buffer.toString().isEmpty ? '(Gunakan profil profesional yang relevan dengan target role)' : buffer.toString()}
''';

      final resp = await http.post(
        Uri.parse(targetUrl),
        headers: {'Content-Type': 'application/json', if (apiKey.isNotEmpty) 'Authorization': 'Bearer $apiKey'},
        body: jsonEncode({
          'model': targetModel,
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            {'role': 'user', 'content': userMessage},
          ],
          'temperature': 0.3,
        }),
      ).timeout(const Duration(seconds: 40));

      if (resp.statusCode == 200) {
        return _parseJsonResponse(utf8.decode(resp.bodyBytes, allowMalformed: true));
      } else {
        throw Exception('Inference API error (${resp.statusCode}): ${resp.body}');
      }
    }
  }

  static ResumeData _parseJsonResponse(String body) {
    final Map<String, dynamic> jsonResp = jsonDecode(body);
    final rawContent = jsonResp['choices']?[0]?['message']?['content'] as String? ?? '';

    var cleaned = rawContent.trim();
    if (cleaned.startsWith('```json')) {
      cleaned = cleaned.substring(7);
    } else if (cleaned.startsWith('```')) {
      cleaned = cleaned.substring(3);
    }
    if (cleaned.endsWith('```')) {
      cleaned = cleaned.substring(0, cleaned.length - 3);
    }
    cleaned = cleaned.trim();

    final firstBrace = cleaned.indexOf('{');
    final lastBrace = cleaned.lastIndexOf('}');
    if (firstBrace != -1 && lastBrace != -1 && lastBrace > firstBrace) {
      cleaned = cleaned.substring(firstBrace, lastBrace + 1);
    }

    final parsedMap = jsonDecode(cleaned) as Map<String, dynamic>;
    return ResumeData.fromJson(parsedMap);
  }

  /// Fetches live available model list from active local or remote AI endpoint
  static Future<List<String>> getAvailableModels() async {
    try {
      final kv = getIt<KeyValueStorage>();
      final savedJson = await kv.get(KVKeys.kFetchedModelsList);
      if (savedJson != null && savedJson.trim().isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(savedJson);
        final list = decoded.map((e) => e.toString()).where((m) => m.isNotEmpty).toList();
        if (list.isNotEmpty) return list;
      }

      final customEndpoint = await kv.get(KVKeys.kCustomAiEndpoint) ?? 'http://localhost:20128/v1';
      final apiKey = await kv.get(KVKeys.kCustomAiApiKey) ?? '';
      var baseUrl = customEndpoint.trim();
      if (baseUrl.endsWith('/')) baseUrl = baseUrl.substring(0, baseUrl.length - 1);
      final modelsUrl = baseUrl.endsWith('/v1') ? '$baseUrl/models' : '$baseUrl/v1/models';

      final resp = await http.get(
        Uri.parse(modelsUrl),
        headers: {'Content-Type': 'application/json', if (apiKey.isNotEmpty) 'Authorization': 'Bearer $apiKey'},
      ).timeout(const Duration(seconds: 4));

      if (resp.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(utf8.decode(resp.bodyBytes, allowMalformed: true));
        final list = (data['data'] as List<dynamic>?)?.map((e) => (e['id'] ?? '').toString()).where((id) => id.isNotEmpty).toList() ?? [];
        if (list.isNotEmpty) {
          await kv.set(KVKeys.kFetchedModelsList, jsonEncode(list));
          return list;
        }
      }
    } catch (_) {}

    return ['gpt-4o', 'gpt-4o-mini', 'claude-3-5-sonnet', 'deepseek-chat', 'llama-3.3-70b'];
  }
}
