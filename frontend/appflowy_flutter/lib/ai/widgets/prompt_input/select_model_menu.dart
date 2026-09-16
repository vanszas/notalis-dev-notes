import 'dart:convert';
import 'dart:io';

import 'package:appflowy/ai/ai.dart';
import 'package:appflowy/core/config/kv.dart';
import 'package:appflowy/core/config/kv_keys.dart';
import 'package:appflowy/generated/flowy_svgs.g.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/startup/startup.dart';
import 'package:appflowy_backend/protobuf/flowy-ai/protobuf.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flowy_infra_ui/style_widget/hover.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SelectModelMenu extends StatefulWidget {
  const SelectModelMenu({
    super.key,
    required this.aiModelStateNotifier,
  });

  final AIModelStateNotifier aiModelStateNotifier;

  @override
  State<SelectModelMenu> createState() => _SelectModelMenuState();
}

class _SelectModelMenuState extends State<SelectModelMenu> {
  final popoverController = PopoverController();

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => SelectModelBloc(
        aiModelStateNotifier: widget.aiModelStateNotifier,
      ),
      child: BlocBuilder<SelectModelBloc, SelectModelState>(
        builder: (context, state) {
          return AppFlowyPopover(
            offset: Offset(-12.0, 0.0),
            constraints: BoxConstraints(maxWidth: 250, maxHeight: 600),
            direction: PopoverDirection.topWithLeftAligned,
            margin: EdgeInsets.zero,
            controller: popoverController,
            popupBuilder: (popoverContext) {
              return BlocProvider.value(
                value: context.read<SelectModelBloc>(),
                child: SelectModelPopoverContent(
                  models: state.models,
                  selectedModel: state.selectedModel,
                  onSelectModel: (model) {
                    if (model != state.selectedModel) {
                      context
                          .read<SelectModelBloc>()
                          .add(SelectModelEvent.selectModel(model));
                    }
                    popoverController.close();
                  },
                ),
              );
            },
            child: _CurrentModelButton(
              model: state.selectedModel,
              onTap: () {
                popoverController.show();
              },
            ),
          );
        },
      ),
    );
  }
}

class SelectModelPopoverContent extends StatefulWidget {
  const SelectModelPopoverContent({
    super.key,
    required this.models,
    required this.selectedModel,
    this.onSelectModel,
  });

  final List<AIModelPB> models;
  final AIModelPB? selectedModel;
  final void Function(AIModelPB)? onSelectModel;

  @override
  State<SelectModelPopoverContent> createState() => _SelectModelPopoverContentState();
}

class _SelectModelPopoverContentState extends State<SelectModelPopoverContent> {
  late List<AIModelPB> _currentModels;
  AIModelPB? _currentSelected;
  bool _isFetching = false;

  @override
  void initState() {
    super.initState();
    _currentModels = List.from(widget.models);
    _currentSelected = widget.selectedModel;
    _loadModelsFromKV();
  }

  Future<void> _loadModelsFromKV() async {
    try {
      final kv = getIt<KeyValueStorage>();
      final savedJson = await kv.get(KVKeys.kFetchedModelsList) ?? '';
      if (savedJson.isNotEmpty) {
        final decoded = jsonDecode(savedJson);
        final List<String> names = [];
        if (decoded is List) {
          names.addAll(decoded.whereType<String>());
        } else if (decoded is Map && decoded['data'] is List) {
          for (final m in decoded['data']) {
            if (m is Map && m['id'] != null) names.add(m['id'].toString());
          }
        }
        if (names.isNotEmpty && mounted) {
          setState(() {
            _currentModels = names.map((n) => AIModelPB(name: n, isLocal: false)).toList();
            if (_currentSelected == null || !_currentModels.any((m) => m.name == _currentSelected?.name)) {
              _currentSelected = _currentModels.first;
            }
          });
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final effectiveModels = _currentModels.isNotEmpty
        ? _currentModels
        : (widget.models.isNotEmpty
            ? widget.models
            : [
                AIModelPB(name: 'gpt-4o', isLocal: false),
                AIModelPB(name: 'MOA (Balanced)', isLocal: false),
              ]);

    // separate models into local and cloud models
    final localModels = effectiveModels.where((model) => model.isLocal).toList();
    final cloudModels = effectiveModels.where((model) => !model.isLocal).toList();

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: SizedBox(
        height: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (localModels.isNotEmpty) ...[
                      _ModelSectionHeader(
                        title: LocaleKeys.chat_switchModel_localModel.tr(),
                      ),
                      const VSpace(4.0),
                      ...localModels.map(
                        (model) => _ModelItem(
                          model: model,
                          isSelected: model.name == _currentSelected?.name,
                          onTap: () {
                            setState(() => _currentSelected = model);
                            widget.onSelectModel?.call(model);
                          },
                        ),
                      ),
                    ],
                    if (cloudModels.isNotEmpty) ...[
                      const VSpace(6.0),
                      const _ModelSectionHeader(
                        title: 'OpenAI API & Custom Models',
                      ),
                      const VSpace(4.0),
                      ...cloudModels.map(
                        (model) => _ModelItem(
                          model: model,
                          isSelected: model.name == _currentSelected?.name,
                          onTap: () {
                            setState(() => _currentSelected = model);
                            widget.onSelectModel?.call(model);
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            const VSpace(4.0),
            // Fetch Models button directly inside the popover!
            InkWell(
              onTap: () async {
                setState(() => _isFetching = true);
                final scaffold = ScaffoldMessenger.of(context);
                try {
                  final kv = getIt<KeyValueStorage>();
                  final endpoint = await kv.get(KVKeys.kCustomAiEndpoint) ?? 'http://localhost:20128/v1';
                  final apiKey = await kv.get(KVKeys.kCustomAiApiKey) ?? '';

                  final uri = Uri.parse(endpoint.endsWith('/') ? '${endpoint}models' : '$endpoint/models');
                  final client = HttpClient()..badCertificateCallback = ((_, __, ___) => true);
                  final request = await client.getUrl(uri);
                  if (apiKey.isNotEmpty) {
                    request.headers.add('Authorization', 'Bearer $apiKey');
                  }
                  final response = await request.close().timeout(const Duration(seconds: 10));
                  if (response.statusCode == 200) {
                    final body = await response.transform(utf8.decoder).join();
                    await kv.set(KVKeys.kFetchedModelsList, body);
                    
                    final decoded = jsonDecode(body);
                    final List<String> modelNames = [];
                    if (decoded is List) {
                      modelNames.addAll(decoded.whereType<String>());
                    } else if (decoded is Map && decoded['data'] is List) {
                      for (final m in decoded['data']) {
                        if (m is Map && m['id'] != null) {
                          modelNames.add(m['id'].toString());
                        }
                      }
                    }

                    if (modelNames.isNotEmpty && mounted) {
                      final updatedList = modelNames.map((n) => AIModelPB(name: n, isLocal: false)).toList();
                      setState(() {
                        _currentModels = updatedList;
                        _currentSelected = updatedList.first;
                        _isFetching = false;
                      });
                      await kv.set(KVKeys.kCustomAiModel, updatedList.first.name);
                    }

                    scaffold.showSnackBar(
                      SnackBar(
                        content: Text('Berhasil fetch ${modelNames.length} model!'),
                        backgroundColor: const Color(0xFF00BCF8),
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  } else {
                    setState(() => _isFetching = false);
                    scaffold.showSnackBar(
                      SnackBar(content: Text('Failed to fetch: HTTP ${response.statusCode}'), backgroundColor: Colors.red),
                    );
                  }
                } catch (e) {
                  setState(() => _isFetching = false);
                  scaffold.showSnackBar(
                    SnackBar(content: Text('Error fetching models: $e'), backgroundColor: Colors.red),
                  );
                }
              },
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  children: [
                    Icon(_isFetching ? Icons.hourglass_top : Icons.refresh, size: 14, color: const Color(0xFF00BCF8)),
                    const SizedBox(width: 8),
                    Text(
                      _isFetching
                          ? 'Mengambil model...'
                          : (context.locale.languageCode == 'id' ? 'Fetch Models Terbaru' : 'Fetch / Refresh Models'),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF00BCF8)),
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
}

class _ModelSectionHeader extends StatelessWidget {
  const _ModelSectionHeader({
    required this.title,
  });

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 2),
      child: FlowyText(
        title,
        fontSize: 12,
        figmaLineHeight: 16,
        color: Theme.of(context).hintColor,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

class _ModelItem extends StatelessWidget {
  const _ModelItem({
    required this.model,
    required this.isSelected,
    required this.onTap,
  });

  final AIModelPB model;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 32),
      child: FlowyButton(
        onTap: onTap,
        margin: EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
        text: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FlowyText(
              model.i18n,
              figmaLineHeight: 20,
              overflow: TextOverflow.ellipsis,
            ),
            if (model.desc.isNotEmpty)
              FlowyText(
                model.desc,
                fontSize: 12,
                figmaLineHeight: 16,
                color: Theme.of(context).hintColor,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        rightIcon: isSelected
            ? FlowySvg(
                FlowySvgs.check_s,
                size: const Size.square(20),
                color: Theme.of(context).colorScheme.primary,
              )
            : null,
      ),
    );
  }
}

class _CurrentModelButton extends StatefulWidget {
  const _CurrentModelButton({
    required this.model,
    required this.onTap,
  });

  final AIModelPB? model;
  final VoidCallback onTap;

  @override
  State<_CurrentModelButton> createState() => _CurrentModelButtonState();
}

class _CurrentModelButtonState extends State<_CurrentModelButton> {
  String _displayText = 'AI Model';
  bool _isMoa = false;

  @override
  void initState() {
    super.initState();
    _loadModelInfo();
  }

  Future<void> _loadModelInfo() async {
    try {
      final kv = getIt<KeyValueStorage>();
      final moaEnabled = (await kv.get(KVKeys.kMoaEnabled)) == 'true';
      final moaPreset = await kv.get(KVKeys.kMoaPreset) ?? 'balanced';
      final customModel = await kv.get(KVKeys.kCustomAiModel) ?? 'gpt-4o';

      if (mounted) {
        setState(() {
          _isMoa = moaEnabled;
          if (moaEnabled) {
            _displayText = 'MOA: ${moaPreset[0].toUpperCase()}${moaPreset.substring(1)}';
          } else {
            _displayText = 'Single: $customModel';
          }
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return FlowyTooltip(
      message: 'Switch between MOA & Single Model / Ubah Model',
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 26,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: _isMoa ? const Color(0xFF00BCF8).withOpacity(0.18) : Theme.of(context).cardColor.withOpacity(0.6),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: _isMoa ? const Color(0xFF00BCF8).withOpacity(0.6) : Theme.of(context).dividerColor.withOpacity(0.4),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _isMoa ? Icons.hub_outlined : Icons.psychology_outlined,
                size: 14,
                color: _isMoa ? const Color(0xFF00BCF8) : Theme.of(context).hintColor,
              ),
              const SizedBox(width: 5),
              Text(
                _displayText,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _isMoa ? const Color(0xFF00BCF8) : Theme.of(context).textTheme.bodyMedium?.color,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.arrow_drop_down, size: 14, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
