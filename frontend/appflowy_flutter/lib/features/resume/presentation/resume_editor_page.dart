import 'package:appflowy/startup/startup.dart';
import 'package:flowy_infra/file_picker/file_picker_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:universal_platform/universal_platform.dart';
import 'package:window_manager/window_manager.dart';

import '../models/resume_context_source.dart';
import '../models/resume_data.dart';
import '../services/resume_ai_generator_service.dart';
import '../services/resume_pdf_service.dart';
import 'widgets/a4_paper_canvas.dart';

enum ResumeStudioViewMode { both, formOnly, previewOnly }

class NotalisResumeStudioPage extends StatefulWidget {
  const NotalisResumeStudioPage({
    super.key,
    this.initialData,
    this.presetId = 'reactive_resume_work',
  });

  final ResumeData? initialData;
  final String presetId;

  static void open(BuildContext context, {ResumeData? initialData, String presetId = 'reactive_resume_work'}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => NotalisResumeStudioPage(
          initialData: initialData,
          presetId: presetId,
        ),
      ),
    );
  }

  @override
  State<NotalisResumeStudioPage> createState() => _NotalisResumeStudioPageState();
}

class _WindowsButtonListener extends WindowListener {
  _WindowsButtonListener(this.onStateChanged);
  final VoidCallback onStateChanged;

  @override
  void onWindowMaximize() => onStateChanged();

  @override
  void onWindowUnmaximize() => onStateChanged();
}

class _NotalisResumeStudioPageState extends State<NotalisResumeStudioPage> {
  late ResumeData _data;
  double _zoomScale = 0.85;
  bool _isExporting = false;
  bool _isGeneratingAi = false;
  String _aiStatusMessage = '';
  ResumeStudioViewMode _viewMode = ResumeStudioViewMode.both;
  int _formKeySeed = 0;
  bool _isMaximized = false;
  _WindowsButtonListener? _windowsListener;

  // Preset accent colors
  static const List<String> _accentColors = [
    '#1E3A8A', // Classic Navy
    '#0F766E', // Emerald / Teal
    '#7C3AED', // Royal Violet
    '#1E293B', // Charcoal Slate
    '#BE123C', // Deep Crimson
    '#B45309', // Warm Amber
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      _data = widget.initialData!;
    } else {
      _loadPreset(widget.presetId);
    }

    if (UniversalPlatform.isWindows || UniversalPlatform.isLinux) {
      _windowsListener = _WindowsButtonListener(() {
        windowManager.isMaximized().then((v) {
          if (mounted) setState(() => _isMaximized = v);
        });
      });
      windowManager.addListener(_windowsListener!);
      windowManager.isMaximized().then((v) {
        if (mounted) setState(() => _isMaximized = v);
      });
    }
  }

  @override
  void dispose() {
    if (_windowsListener != null) {
      windowManager.removeListener(_windowsListener!);
    }
    super.dispose();
  }

  void _loadPreset(String presetId) {
    setState(() {
      if (presetId.contains('indonesia')) {
        _data = ResumeData.indonesiaPro();
      } else if (presetId.contains('gamedev')) {
        _data = ResumeData.gameDev();
      } else if (presetId.contains('art')) {
        _data = ResumeData.artist();
      } else if (presetId.contains('tech')) {
        _data = ResumeData.softwareEngineer();
      } else {
        _data = ResumeData.corporate();
      }
      _formKeySeed++;
    });
  }

  Future<void> _pickProfilePhoto() async {
    try {
      final res = await getIt<FilePickerService>().pickFiles(
        dialogTitle: 'Pilih Foto Profil (.png, .jpg, .jpeg, .webp)',
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg', 'webp'],
      );
      final path = res?.files.firstOrNull?.path;
      if (path != null && path.isNotEmpty) {
        setState(() {
          _data.basics.picture = path;
          _formKeySeed++;
        });
      }
    } catch (_) {}
  }

  Future<void> _exportPdf() async {
    setState(() => _isExporting = true);
    try {
      final savedPath = await ResumePdfService.savePdfToFile(_data);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PDF berhasil diekspor ke: $savedPath'),
          backgroundColor: Colors.green.shade800,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Salin Path',
            textColor: Colors.white,
            onPressed: () => Clipboard.setData(ClipboardData(text: savedPath)),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal ekspor PDF: $e'), backgroundColor: Colors.red.shade800),
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _openAiGeneratorDialog() async {
    final roleController = TextEditingController(text: _data.basics.label);
    final customPromptController = TextEditingController();
    final customUrlController = TextEditingController();
    bool isMoa = false;
    String moaPreset = 'balanced';
    String selectedLanguage = 'id';

    List<String> modelsList = await ResumeAiGeneratorService.getAvailableModels();
    String selectedModel = modelsList.isNotEmpty ? modelsList.first : 'gpt-4o';
    bool isFetchingModels = false;

    List<ResumeContextSource> contextSources = [];
    bool isScanningSources = false;
    bool isAddingCustom = false;
    bool hasInitialScanned = false;

    if (!mounted) return;

    showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          void triggerScan() async {
            setDialogState(() => isScanningSources = true);
            try {
              final res = await ResumeAiGeneratorService.discoverContextSources();
              if (mounted) {
                setDialogState(() {
                  contextSources = res;
                  isScanningSources = false;
                });
              }
            } catch (_) {
              if (mounted) {
                setDialogState(() => isScanningSources = false);
              }
            }
          }

          if (!hasInitialScanned) {
            hasInitialScanned = true;
            WidgetsBinding.instance.addPostFrameCallback((_) => triggerScan());
          }

          return AlertDialog(
            backgroundColor: const Color(0xFF1E2229),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            title: Row(
              children: const [
                Icon(Icons.auto_awesome, color: Colors.amber, size: 22),
                SizedBox(width: 8),
                Text('Buat CV dengan AI Assistant', style: TextStyle(color: Colors.white, fontSize: 16)),
              ],
            ),
            content: SizedBox(
              width: 540,
              child: _isGeneratingAi
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(color: Colors.amber),
                          const SizedBox(height: 16),
                          Text(
                            _aiStatusMessage,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Pilih dokumen & halaman Notion yang akan dianalisis, atau paste link Notion untuk memindai seluruh halamannya.',
                            style: TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                          const SizedBox(height: 16),

                          // Target Role
                          const Text('Target Posisi / Pekerjaan', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          TextField(
                            controller: roleController,
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            decoration: InputDecoration(
                              isDense: true,
                              hintText: 'Misal: Senior Gameplay Programmer (UE5) / Head of Product',
                              hintStyle: const TextStyle(color: Colors.white38),
                              filled: true,
                              fillColor: const Color(0xFF242932),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Custom Prompt (User Control)
                          const Text('Instruksi Khusus / Custom Prompt (Opsional)', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          TextField(
                            controller: customPromptController,
                            maxLines: 2,
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                            decoration: InputDecoration(
                              isDense: true,
                              hintText: 'Contoh: Tonjolkan pengalaman Unreal Engine C++, sertakan proyek MSIB & Game Dev, buat ringkasan lebih tajam...',
                              hintStyle: const TextStyle(color: Colors.white38, fontSize: 11),
                              filled: true,
                              fillColor: const Color(0xFF242932),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Output Language Selector
                          const Text('Bahasa Output CV', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              ChoiceChip(
                                label: const Text('🇮🇩 Bahasa Indonesia', style: TextStyle(fontSize: 11)),
                                selected: selectedLanguage == 'id',
                                selectedColor: Colors.blueAccent.shade700,
                                labelStyle: TextStyle(color: selectedLanguage == 'id' ? Colors.white : Colors.white70),
                                backgroundColor: const Color(0xFF242932),
                                onSelected: (_) => setDialogState(() => selectedLanguage = 'id'),
                              ),
                              const SizedBox(width: 8),
                              ChoiceChip(
                                label: const Text('🇬🇧 English', style: TextStyle(fontSize: 11)),
                                selected: selectedLanguage == 'en',
                                selectedColor: Colors.blueAccent.shade700,
                                labelStyle: TextStyle(color: selectedLanguage == 'en' ? Colors.white : Colors.white70),
                                backgroundColor: const Color(0xFF242932),
                                onSelected: (_) => setDialogState(() => selectedLanguage = 'en'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // AI Engine Mode Selection (Single Model vs MOA)
                          const Text('Mode Inferensi AI', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              ChoiceChip(
                                label: const Text('Single Model', style: TextStyle(fontSize: 11)),
                                selected: !isMoa,
                                selectedColor: Colors.blueAccent.shade700,
                                labelStyle: TextStyle(color: !isMoa ? Colors.white : Colors.white70),
                                backgroundColor: const Color(0xFF242932),
                                onSelected: (_) => setDialogState(() => isMoa = false),
                              ),
                              const SizedBox(width: 8),
                              ChoiceChip(
                                label: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Icon(Icons.hub_outlined, size: 13, color: Colors.amber),
                                    SizedBox(width: 4),
                                    Text('MOA (Mixture of Agents)', style: TextStyle(fontSize: 11)),
                                  ],
                                ),
                                selected: isMoa,
                                selectedColor: Colors.amber.shade800,
                                labelStyle: TextStyle(color: isMoa ? Colors.white : Colors.white70),
                                backgroundColor: const Color(0xFF242932),
                                onSelected: (_) => setDialogState(() => isMoa = true),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Model / Preset Pickers with Fetch Model Button
                          if (!isMoa) ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Pilih Model AI', style: TextStyle(color: Colors.white70, fontSize: 11)),
                                InkWell(
                                  onTap: isFetchingModels
                                      ? null
                                      : () async {
                                          setDialogState(() => isFetchingModels = true);
                                          final live = await ResumeAiGeneratorService.getAvailableModels();
                                          setDialogState(() {
                                            isFetchingModels = false;
                                            modelsList = live;
                                            if (live.isNotEmpty && !live.contains(selectedModel)) {
                                              selectedModel = live.first;
                                            }
                                          });
                                        },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (isFetchingModels)
                                          const SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.amber))
                                        else
                                          const Icon(Icons.refresh, size: 12, color: Colors.amber),
                                        const SizedBox(width: 4),
                                        const Text('Fetch Model', style: TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF242932),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFF38404E)),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: modelsList.contains(selectedModel) ? selectedModel : (modelsList.isNotEmpty ? modelsList.first : 'gpt-4o'),
                                  isExpanded: true,
                                  dropdownColor: const Color(0xFF242932),
                                  style: const TextStyle(color: Colors.white, fontSize: 12),
                                  items: modelsList
                                      .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                                      .toList(),
                                  onChanged: (v) {
                                    if (v != null) setDialogState(() => selectedModel = v);
                                  },
                                ),
                              ),
                            ),
                          ] else ...[
                            const Text('Preset MOA Reasoning', style: TextStyle(color: Colors.white70, fontSize: 11)),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF242932),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFF38404E)),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: moaPreset,
                                  isExpanded: true,
                                  dropdownColor: const Color(0xFF242932),
                                  style: const TextStyle(color: Colors.white, fontSize: 12),
                                  items: const [
                                    DropdownMenuItem(value: 'balanced', child: Text('Balanced (Seimbang & Cepat)')),
                                    DropdownMenuItem(value: 'deep_research', child: Text('Deep Research (Analisis Mendalam ATS)')),
                                    DropdownMenuItem(value: 'fast', child: Text('Fast Reasoning (Eksekusi Instan)')),
                                    DropdownMenuItem(value: 'creative', child: Text('Creative Executive (Gaya Bahasa Impactful)')),
                                  ],
                                  onChanged: (v) {
                                    if (v != null) setDialogState(() => moaPreset = v);
                                  },
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 14),

                          // --- PREVIEW SUMBER KONTEKS AI (CHECKLIST & RECHECK) ---
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Sumber Konteks (${contextSources.where((s) => s.isSelected).length}/${contextSources.length} dipilih)',
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                              TextButton.icon(
                                style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                                icon: const Icon(Icons.refresh, size: 14, color: Colors.amber),
                                label: const Text('Pindai Ulang', style: TextStyle(color: Colors.amber, fontSize: 11)),
                                onPressed: isScanningSources ? null : () => triggerScan(),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),

                          // Add custom page or Notion URL with Deep Fetch
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: customUrlController,
                                  style: const TextStyle(color: Colors.white, fontSize: 12),
                                  decoration: InputDecoration(
                                    isDense: true,
                                    hintText: 'Paste link Notion / ID Halaman untuk di-fetch...',
                                    hintStyle: const TextStyle(color: Colors.white38, fontSize: 11),
                                    filled: true,
                                    fillColor: const Color(0xFF242932),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF374151),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                                  visualDensity: VisualDensity.compact,
                                ),
                                onPressed: isAddingCustom
                                    ? null
                                    : () async {
                                        final text = customUrlController.text.trim();
                                        if (text.isEmpty) return;
                                        setDialogState(() => isAddingCustom = true);
                                        try {
                                          final newSources = await ResumeAiGeneratorService.resolveCustomNotionSources(text);
                                          if (newSources.isNotEmpty) {
                                            setDialogState(() {
                                              contextSources.insertAll(0, newSources);
                                              customUrlController.clear();
                                              isAddingCustom = false;
                                            });
                                            if (mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text('Berhasil mengambil ${newSources.length} halaman & database dari tautan Notion!'),
                                                  backgroundColor: Colors.green,
                                                ),
                                              );
                                            }
                                          } else {
                                            setDialogState(() => isAddingCustom = false);
                                            if (mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(content: Text('Tidak dapat menemukan halaman/koleksi pada link tersebut.')),
                                              );
                                            }
                                          }
                                        } catch (e) {
                                          setDialogState(() => isAddingCustom = false);
                                          if (mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text('Gagal memindai tautan: $e')),
                                            );
                                          }
                                        }
                                      },
                                child: isAddingCustom
                                    ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                    : const Text('+ Fetch Link', style: TextStyle(fontSize: 11)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // Scrollable Box of Discovered / Selected Sources
                          Container(
                            height: 160,
                            decoration: BoxDecoration(
                              color: const Color(0xFF181B20),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: isScanningSources
                                ? const Center(
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.amber)),
                                        SizedBox(width: 10),
                                        Text('Memindai seluruh sumber dokumen...', style: TextStyle(color: Colors.white60, fontSize: 11)),
                                      ],
                                    ),
                                  )
                                : contextSources.isEmpty
                                    ? const Center(
                                        child: Padding(
                                          padding: EdgeInsets.symmetric(horizontal: 16),
                                          child: Text(
                                            'Tidak ada sumber otomatis terdeteksi. Silakan klik "+ Fetch Link" dengan URL Notion Anda.',
                                            style: TextStyle(color: Colors.white38, fontSize: 11),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      )
                                    : ListView.separated(
                                        itemCount: contextSources.length,
                                        separatorBuilder: (_, __) => const Divider(height: 1, color: Colors.white10),
                                        itemBuilder: (_, i) {
                                          final item = contextSources[i];
                                          Color badgeColor;
                                          switch (item.sourceType) {
                                            case 'notion_db':
                                            case 'custom_db':
                                              badgeColor = Colors.purple.shade400;
                                              break;
                                            case 'notion_page':
                                            case 'custom_page':
                                              badgeColor = Colors.teal.shade400;
                                              break;
                                            case 'notalis_doc':
                                              badgeColor = Colors.blue.shade400;
                                              break;
                                            case 'notalis_file':
                                              badgeColor = Colors.indigo.shade400;
                                              break;
                                            default:
                                              badgeColor = Colors.amber.shade600;
                                          }

                                          return InkWell(
                                            onTap: () {
                                              setDialogState(() => item.isSelected = !item.isSelected);
                                            },
                                            child: Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              child: Row(
                                                children: [
                                                  Checkbox(
                                                    value: item.isSelected,
                                                    activeColor: Colors.amber,
                                                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                    visualDensity: VisualDensity.compact,
                                                    onChanged: (val) {
                                                      setDialogState(() => item.isSelected = val ?? false);
                                                    },
                                                  ),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                                    decoration: BoxDecoration(
                                                      color: badgeColor.withValues(alpha: 0.15),
                                                      borderRadius: BorderRadius.circular(4),
                                                      border: Border.all(color: badgeColor.withValues(alpha: 0.5), width: 0.8),
                                                    ),
                                                    child: Text(
                                                      item.typeLabel,
                                                      style: TextStyle(color: badgeColor, fontSize: 9.5, fontWeight: FontWeight.bold),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text(
                                                          item.title,
                                                          style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w600),
                                                          maxLines: 1,
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                        if (item.detail.isNotEmpty)
                                                          Text(
                                                            item.detail,
                                                            style: const TextStyle(color: Colors.white38, fontSize: 9.5),
                                                            maxLines: 1,
                                                            overflow: TextOverflow.ellipsis,
                                                          ),
                                                      ],
                                                    ),
                                                  ),
                                                  if (item.sourceType == 'custom_page' || item.sourceType == 'custom_db')
                                                    InkWell(
                                                      onTap: () {
                                                        setDialogState(() => contextSources.removeAt(i));
                                                      },
                                                      child: const Padding(
                                                        padding: EdgeInsets.all(4),
                                                        child: Icon(Icons.close, size: 14, color: Colors.white38),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                          ),
                        ],
                      ),
                    ),
            ),
            actions: _isGeneratingAi
                ? []
                : [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogCtx),
                      child: const Text('Batal', style: TextStyle(color: Colors.white60)),
                    ),
                    FilledButton.icon(
                      icon: const Icon(Icons.auto_awesome, size: 16),
                      label: const Text('Mulai Susun CV'),
                      style: FilledButton.styleFrom(backgroundColor: Colors.amber.shade700),
                      onPressed: () async {
                        final selectedSources = contextSources.where((s) => s.isSelected).toList();
                        if (selectedSources.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Pilih minimal 1 sumber konteks untuk dianalisis oleh AI!'),
                              backgroundColor: Colors.orange,
                            ),
                          );
                          return;
                        }

                        setDialogState(() {
                          _isGeneratingAi = true;
                          _aiStatusMessage = 'Menginisialisasi AI Assistant...';
                        });

                        try {
                          final generated = await ResumeAiGeneratorService.generateResumeFromSources(
                            targetRole: roleController.text.trim().isEmpty ? _data.basics.label : roleController.text.trim(),
                            selectedSources: selectedSources,
                            customPrompt: customPromptController.text.trim(),
                            language: selectedLanguage,
                            isMoa: isMoa,
                            moaPreset: moaPreset,
                            selectedModel: selectedModel,
                            onProgress: (status) {
                              if (mounted) {
                                setDialogState(() => _aiStatusMessage = status);
                              }
                            },
                          );

                          if (mounted) {
                            setState(() {
                              final prevPhoto = _data.basics.picture;
                              final prevShowPhoto = _data.metadata.showPhoto;
                              final prevShape = _data.metadata.photoShape;
                              final prevSize = _data.metadata.photoSize;
                              final prevTemplate = _data.metadata.template;
                              final prevColor = _data.metadata.primaryColor;

                              _data = generated;

                              // Selalu pertahankan foto dan konfigurasi profil user agar tidak hilang
                              if (prevPhoto.isNotEmpty && _data.basics.picture.isEmpty) {
                                _data.basics.picture = prevPhoto;
                              }
                              _data.metadata.showPhoto = prevShowPhoto;
                              _data.metadata.photoShape = prevShape;
                              _data.metadata.photoSize = prevSize;
                              if (_data.metadata.template.isEmpty || _data.metadata.template == 'modern') {
                                _data.metadata.template = prevTemplate;
                              }
                              _data.metadata.primaryColor = prevColor;
                              _formKeySeed++;
                            });
                            Navigator.pop(dialogCtx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('CV berhasil disusun dari ${selectedSources.length} sumber dokumen pilihan!'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            setDialogState(() => _isGeneratingAi = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Gagal membuat CV via AI: $e'), backgroundColor: Colors.red),
                            );
                          }
                        }
                      },
                    ),
                  ],
          );
        },
      ),
    );
  }

  void _importJsonDialog() {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2229),
        title: const Text('Impor JSON Resume (Reactive Resume)', style: TextStyle(color: Colors.white, fontSize: 15)),
        content: SizedBox(
          width: 500,
          height: 300,
          child: TextField(
            controller: controller,
            maxLines: 20,
            style: const TextStyle(color: Colors.white, fontSize: 12),
            decoration: const InputDecoration(
              hintText: 'Tempelkan skema JSON dari Reactive Resume di sini...',
              hintStyle: TextStyle(color: Colors.white38),
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          FilledButton(
            onPressed: () {
              try {
                final parsed = ResumeData.fromJsonString(controller.text);
                setState(() {
                  _data = parsed;
                  _formKeySeed++;
                });
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Data resume berhasil diimpor!')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Format JSON tidak valid: $e')),
                );
              }
            },
            child: const Text('Impor'),
          ),
        ],
      ),
    );
  }

  void _exportJsonDialog() {
    final jsonStr = _data.toJsonString();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2229),
        title: const Text('Ekspor JSON Resume', style: TextStyle(color: Colors.white, fontSize: 15)),
        content: SizedBox(
          width: 500,
          height: 300,
          child: SelectableText(
            jsonStr,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.white),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tutup')),
          FilledButton.icon(
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('Salin JSON'),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: jsonStr));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('JSON disalin ke clipboard!')),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF181B20),
      body: Column(
        children: [
          _buildResponsiveHeader(),
          _buildSubToolbar(),
          Expanded(
            child: LayoutBuilder(
              builder: (ctx, constraints) {
                final isNarrow = constraints.maxWidth < 960;
                final activeMode = isNarrow && _viewMode == ResumeStudioViewMode.both
                    ? ResumeStudioViewMode.formOnly
                    : _viewMode;

                if (activeMode == ResumeStudioViewMode.formOnly) {
                  return Container(
                    color: const Color(0xFF1E2229),
                    child: _buildFormPanel(),
                  );
                }

                if (activeMode == ResumeStudioViewMode.previewOnly) {
                  return Container(
                    color: const Color(0xFF14171C),
                    child: _buildPreviewPanel(),
                  );
                }

                // Both (Split View)
                final formWidth = (constraints.maxWidth * 0.38).clamp(360.0, 480.0);
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: formWidth,
                      child: Container(
                        color: const Color(0xFF1E2229),
                        child: _buildFormPanel(),
                      ),
                    ),
                    const VerticalDivider(width: 1, thickness: 1, color: Color(0xFF2C323D)),
                    Expanded(
                      child: Container(
                        color: const Color(0xFF14171C),
                        child: _buildPreviewPanel(),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResponsiveHeader() {
    return Container(
      color: const Color(0xFF1E2229),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white70, size: 20),
              onPressed: () => Navigator.pop(context),
              tooltip: 'Kembali ke Workspace',
            ),
            const SizedBox(width: 6),
            const Icon(Icons.description_outlined, color: Colors.blueAccent, size: 20),
            const SizedBox(width: 8),
            const Text(
              'Notalis Resume Studio',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.blueAccent.withOpacity(0.18),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Reactive Resume Engine',
                style: TextStyle(fontSize: 10, color: Colors.lightBlueAccent, fontWeight: FontWeight.bold),
              ),
            ),
            
            // Drag Area for moving the native window
            Expanded(
              child: DragToMoveArea(
                child: Container(height: 36, color: Colors.transparent),
              ),
            ),

            // AI Assistant Button
            FilledButton.icon(
              icon: const Icon(Icons.auto_awesome, size: 15, color: Colors.black),
              label: const Text('Buat dengan AI', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black)),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.amber,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                visualDensity: VisualDensity.compact,
              ),
              onPressed: _openAiGeneratorDialog,
            ),
            const SizedBox(width: 10),

            // Export PDF
            FilledButton.icon(
              onPressed: _isExporting ? null : _exportPdf,
              icon: _isExporting
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.picture_as_pdf, size: 15),
              label: const Text('Ekspor PDF A4', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.blueAccent.shade700,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                visualDensity: VisualDensity.compact,
              ),
            ),

            // Native Windows Minimize, Maximize/Unmaximize, and Close Buttons
            if (UniversalPlatform.isWindows || UniversalPlatform.isLinux) ...[
              const SizedBox(width: 12),
              WindowCaptionButton.minimize(
                brightness: Brightness.dark,
                onPressed: () => windowManager.minimize(),
              ),
              if (_isMaximized)
                WindowCaptionButton.unmaximize(
                  brightness: Brightness.dark,
                  onPressed: () => windowManager.unmaximize(),
                )
              else
                WindowCaptionButton.maximize(
                  brightness: Brightness.dark,
                  onPressed: () => windowManager.maximize(),
                ),
              WindowCaptionButton.close(
                brightness: Brightness.dark,
                onPressed: () => windowManager.close(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSubToolbar() {
    return Container(
      color: const Color(0xFF242932),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          // Preset Selector Dropdown
          PopupMenuButton<String>(
            tooltip: 'Ganti Template Preset',
            initialValue: widget.presetId,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF1E2229),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFF38404E)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.style_outlined, size: 14, color: Colors.white70),
                  SizedBox(width: 6),
                  Text('Preset', style: TextStyle(fontSize: 11, color: Colors.white70, fontWeight: FontWeight.w600)),
                  Icon(Icons.arrow_drop_down, size: 16, color: Colors.white70),
                ],
              ),
            ),
            onSelected: (val) => _loadPreset(val),
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'reactive_resume_indonesia', child: Text('CV Standar Indonesia (Umum & MSIB)')),
              const PopupMenuItem(value: 'reactive_resume_work', child: Text('Eksekutif & Bisnis (Corporate)')),
              const PopupMenuItem(value: 'reactive_resume_gamedev', child: Text('Game Developer (UE5/Unity)')),
              const PopupMenuItem(value: 'reactive_resume_art', child: Text('3D Lookdev & Artist')),
              const PopupMenuItem(value: 'reactive_resume_tech', child: Text('Software Engineer & Systems')),
            ],
          ),
          const SizedBox(width: 10),

          // Template Style Toggle
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'indonesia_pro', label: Text('Standar Indonesia', style: TextStyle(fontSize: 11))),
              ButtonSegment(value: 'modern', label: Text('Modern 2-Kolom', style: TextStyle(fontSize: 11))),
              ButtonSegment(value: 'classic', label: Text('Classic ATS', style: TextStyle(fontSize: 11))),
            ],
            selected: {_data.metadata.template},
            onSelectionChanged: (val) {
              setState(() => _data.metadata.template = val.first);
            },
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) return Colors.blueAccent.shade700;
                return const Color(0xFF1E2229);
              }),
              foregroundColor: WidgetStateProperty.all(Colors.white),
            ),
          ),
          const SizedBox(width: 12),

          // Accent Color Dots
          Row(
            children: _accentColors.map((hex) {
              final isSelected = _data.metadata.primaryColor.toUpperCase() == hex.toUpperCase();
              final color = Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
              return GestureDetector(
                onTap: () => setState(() => _data.metadata.primaryColor = hex),
                child: Container(
                  width: 18,
                  height: 18,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? Colors.white : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const Spacer(),

          // View Mode Switcher
          SegmentedButton<ResumeStudioViewMode>(
            segments: const [
              ButtonSegment(value: ResumeStudioViewMode.formOnly, label: Icon(Icons.edit_note, size: 16)),
              ButtonSegment(value: ResumeStudioViewMode.both, label: Icon(Icons.vertical_split, size: 16)),
              ButtonSegment(value: ResumeStudioViewMode.previewOnly, label: Icon(Icons.visibility_outlined, size: 16)),
            ],
            selected: {_viewMode},
            onSelectionChanged: (val) => setState(() => _viewMode = val.first),
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) return Colors.blueAccent.shade700;
                return const Color(0xFF1E2229);
              }),
              foregroundColor: WidgetStateProperty.all(Colors.white),
            ),
          ),
          const SizedBox(width: 10),

          // Import & Export JSON
          IconButton(
            icon: const Icon(Icons.file_upload_outlined, size: 18, color: Colors.white70),
            tooltip: 'Impor JSON Resume',
            onPressed: _importJsonDialog,
          ),
          IconButton(
            icon: const Icon(Icons.file_download_outlined, size: 18, color: Colors.white70),
            tooltip: 'Ekspor JSON Resume',
            onPressed: _exportJsonDialog,
          ),
        ],
      ),
    );
  }

  Widget _buildFormPanel() {
    return ListView(
      key: ValueKey(_formKeySeed),
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionAccordion(
          title: '1. Identitas & Foto Profil',
          icon: Icons.person_outline,
          initiallyExpanded: true,
          children: [
            _textInput('Nama Lengkap', _data.basics.name, (v) => setState(() => _data.basics.name = v)),
            _textInput('Gelar / Jabatan Profesional', _data.basics.label, (v) => setState(() => _data.basics.label = v)),
            _textInput('Email', _data.basics.email, (v) => setState(() => _data.basics.email = v)),
            _textInput('Nomor Telepon', _data.basics.phone, (v) => setState(() => _data.basics.phone = v)),
            _textInput('Lokasi (Kota, Negara)', _data.basics.location, (v) => setState(() => _data.basics.location = v)),
            _textInput('Tautan Portofolio / Website', _data.basics.url, (v) => setState(() => _data.basics.url = v)),
            
            // Photo Picker & Path input
            Row(
              children: [
                Expanded(
                  child: _textInput('URL / Path File Foto', _data.basics.picture, (v) => setState(() => _data.basics.picture = v)),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.folder_open, size: 14),
                    label: const Text('Pilih File', style: TextStyle(fontSize: 11)),
                    onPressed: _pickProfilePhoto,
                  ),
                ),
              ],
            ),
            
            // Photo Shape & Size Controls
            const SizedBox(height: 6),
            Row(
              children: [
                const Text('Tampilkan Foto:', style: TextStyle(color: Colors.white70, fontSize: 11)),
                Switch(
                  value: _data.metadata.showPhoto,
                  activeColor: Colors.blueAccent,
                  onChanged: (val) => setState(() => _data.metadata.showPhoto = val),
                ),
                const Spacer(),
                if (_data.metadata.showPhoto) ...[
                  const Text('Bentuk:', style: TextStyle(color: Colors.white70, fontSize: 11)),
                  const SizedBox(width: 6),
                  DropdownButton<String>(
                    value: _data.metadata.photoShape,
                    dropdownColor: const Color(0xFF242932),
                    style: const TextStyle(color: Colors.white, fontSize: 11),
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(value: 'circle', child: Text('Bulat')),
                      DropdownMenuItem(value: 'rounded', child: Text('Kotak Bulat')),
                      DropdownMenuItem(value: 'square', child: Text('Persegi')),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _data.metadata.photoShape = v);
                    },
                  ),
                ],
              ],
            ),
            if (_data.metadata.showPhoto) ...[
              Row(
                children: [
                  Text('Ukuran Foto: ${_data.metadata.photoSize.toInt()}px', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                  Expanded(
                    child: Slider(
                      value: _data.metadata.photoSize,
                      min: 50.0,
                      max: 130.0,
                      divisions: 16,
                      activeColor: Colors.blueAccent,
                      onChanged: (val) => setState(() => _data.metadata.photoSize = val),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 8),
            _textInput(
              'Ringkasan Profil (Executive Summary)',
              _data.basics.summary,
              (v) => setState(() => _data.basics.summary = v),
              maxLines: 4,
            ),
          ],
        ),
        const SizedBox(height: 12),

        _buildSectionAccordion(
          title: '2. Pengalaman Kerja (${_data.work.length})',
          icon: Icons.work_outline,
          children: [
            for (int i = 0; i < _data.work.length; i++) ...[
              _buildWorkCard(i),
              const SizedBox(height: 8),
            ],
            OutlinedButton.icon(
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Tambah Pengalaman Kerja', style: TextStyle(fontSize: 11)),
              onPressed: () {
                setState(() {
                  _data.work.add(
                    ResumeWork(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      company: 'Perusahaan Baru',
                      position: 'Posisi / Role',
                      website: '',
                      startDate: '2022',
                      endDate: 'Sekarang',
                      current: true,
                      summary: '',
                      highlights: ['Deskripsi pencapaian metrik...'],
                    ),
                  );
                });
              },
            ),
          ],
        ),
        const SizedBox(height: 12),

        _buildSectionAccordion(
          title: '3. Keahlian & Tools (${_data.skills.length})',
          icon: Icons.bolt_outlined,
          children: [
            for (int i = 0; i < _data.skills.length; i++) ...[
              _buildSkillCard(i),
              const SizedBox(height: 8),
            ],
            OutlinedButton.icon(
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Tambah Kategori Keahlian', style: TextStyle(fontSize: 11)),
              onPressed: () {
                setState(() {
                  _data.skills.add(
                    ResumeSkill(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      name: 'Keahlian Baru',
                      level: '5',
                      keywords: ['Tag 1', 'Tag 2'],
                    ),
                  );
                });
              },
            ),
          ],
        ),
        const SizedBox(height: 12),

        _buildSectionAccordion(
          title: '4. Pendidikan (${_data.education.length})',
          icon: Icons.school_outlined,
          children: [
            for (int i = 0; i < _data.education.length; i++) ...[
              _buildEducationCard(i),
              const SizedBox(height: 8),
            ],
            OutlinedButton.icon(
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Tambah Riwayat Pendidikan', style: TextStyle(fontSize: 11)),
              onPressed: () {
                setState(() {
                  _data.education.add(
                    ResumeEducation(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      institution: 'Nama Universitas / Sekolah',
                      area: 'Jurusan / Bidang Studi',
                      studyType: 'Gelar (S.Kom / Sarjana)',
                      startDate: '2018',
                      endDate: '2022',
                      score: '3.80',
                      courses: [],
                    ),
                  );
                });
              },
            ),
          ],
        ),
        const SizedBox(height: 12),

        _buildSectionAccordion(
          title: '5. Proyek Unggulan (${_data.projects.length})',
          icon: Icons.rocket_launch_outlined,
          children: [
            for (int i = 0; i < _data.projects.length; i++) ...[
              _buildProjectCard(i),
              const SizedBox(height: 8),
            ],
            OutlinedButton.icon(
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Tambah Proyek', style: TextStyle(fontSize: 11)),
              onPressed: () {
                setState(() {
                  _data.projects.add(
                    ResumeProject(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      name: 'Judul Proyek Unggulan',
                      description: 'Ringkasan dampak dan hasil proyek.',
                      url: 'https://...',
                      keywords: ['Teknologi 1', 'Teknologi 2'],
                    ),
                  );
                });
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSectionAccordion({
    required String title,
    required IconData icon,
    required List<Widget> children,
    bool initiallyExpanded = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF242932),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF323946)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          leading: Icon(icon, color: Colors.blueAccent, size: 18),
          title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
          childrenPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          children: children,
        ),
      ),
    );
  }

  Widget _textInput(String label, String value, ValueChanged<String> onChanged, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.white70, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          TextFormField(
            initialValue: value,
            maxLines: maxLines,
            style: const TextStyle(color: Colors.white, fontSize: 12),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: const Color(0xFF1E2229),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: Color(0xFF3F4756))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: Color(0xFF3F4756))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: Colors.blueAccent)),
            ),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildWorkCard(int index) {
    final w = _data.work[index];
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2229),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFF3A4250)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Pekerjaan #${index + 1}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                onPressed: () => setState(() => _data.work.removeAt(index)),
                tooltip: 'Hapus Pekerjaan',
              ),
            ],
          ),
          _textInput('Jabatan / Posisi', w.position, (v) => setState(() => w.position = v)),
          _textInput('Nama Perusahaan', w.company, (v) => setState(() => w.company = v)),
          Row(
            children: [
              Expanded(child: _textInput('Mulai', w.startDate, (v) => setState(() => w.startDate = v))),
              const SizedBox(width: 8),
              Expanded(child: _textInput('Selesai', w.endDate, (v) => setState(() => w.endDate = v))),
            ],
          ),
          _textInput(
            'Highlights (Pisahkan dengan baris baru)',
            w.highlights.join('\n'),
            (v) => setState(() => w.highlights = v.split('\n').where((s) => s.trim().isNotEmpty).toList()),
            maxLines: 3,
          ),
        ],
      ),
    );
  }

  Widget _buildSkillCard(int index) {
    final s = _data.skills[index];
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2229),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFF3A4250)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Keahlian #${index + 1}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                onPressed: () => setState(() => _data.skills.removeAt(index)),
              ),
            ],
          ),
          _textInput('Nama Kategori', s.name, (v) => setState(() => s.name = v)),
          _textInput(
            'Keywords (Pisahkan dengan koma)',
            s.keywords.join(', '),
            (v) => setState(() => s.keywords = v.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList()),
          ),
        ],
      ),
    );
  }

  Widget _buildEducationCard(int index) {
    final e = _data.education[index];
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2229),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFF3A4250)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Pendidikan #${index + 1}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                onPressed: () => setState(() => _data.education.removeAt(index)),
              ),
            ],
          ),
          _textInput('Institusi / Kampus', e.institution, (v) => setState(() => e.institution = v)),
          _textInput('Gelar & Jurusan', '${e.studyType} - ${e.area}', (v) {
            final parts = v.split('-');
            setState(() {
              e.studyType = parts.first.trim();
              if (parts.length > 1) e.area = parts.sublist(1).join('-').trim();
            });
          }),
          Row(
            children: [
              Expanded(child: _textInput('Tahun', '${e.startDate} - ${e.endDate}', (v) {
                final parts = v.split('-');
                setState(() {
                  e.startDate = parts.first.trim();
                  if (parts.length > 1) e.endDate = parts.last.trim();
                });
              })),
              const SizedBox(width: 8),
              Expanded(child: _textInput('IPK / Score', e.score, (v) => setState(() => e.score = v))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProjectCard(int index) {
    final p = _data.projects[index];
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2229),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFF3A4250)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Proyek #${index + 1}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                onPressed: () => setState(() => _data.projects.removeAt(index)),
              ),
            ],
          ),
          _textInput('Nama Proyek', p.name, (v) => setState(() => p.name = v)),
          _textInput('Tautan / URL', p.url, (v) => setState(() => p.url = v)),
          _textInput('Deskripsi Singkat', p.description, (v) => setState(() => p.description = v)),
          _textInput(
            'Tech Stack (Pisahkan dengan koma)',
            p.keywords.join(', '),
            (v) => setState(() => p.keywords = v.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList()),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewPanel() {
    return Stack(
      children: [
        // Interactive Canvas Scroll Area
        Positioned.fill(
          child: InteractiveViewer(
            minScale: 0.4,
            maxScale: 2.0,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
              child: Center(
                child: A4PaperCanvas(
                  data: _data,
                  scale: _zoomScale,
                  onDataChanged: () => setState(() {}),
                  onPickPhoto: _pickProfilePhoto,
                  onPhotoUpdated: (path) {
                    setState(() {
                      _data.basics.picture = path;
                      _formKeySeed++;
                    });
                  },
                ),
              ),
            ),
          ),
        ),

        // Floating Zoom Controls (Docked cleanly bottom-right)
        Positioned(
          bottom: 20,
          right: 20,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF1E2229),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF3A4250)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove, size: 16, color: Colors.white70),
                  onPressed: () => setState(() => _zoomScale = (_zoomScale - 0.1).clamp(0.4, 1.5)),
                  tooltip: 'Perkecil',
                ),
                Text(
                  '${(_zoomScale * 100).toInt()}%',
                  style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.add, size: 16, color: Colors.white70),
                  onPressed: () => setState(() => _zoomScale = (_zoomScale + 0.1).clamp(0.4, 1.5)),
                  tooltip: 'Perbesar',
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.restart_alt, size: 16, color: Colors.white70),
                  onPressed: () => setState(() => _zoomScale = 0.85),
                  tooltip: 'Reset Zoom (85%)',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
