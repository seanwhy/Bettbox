import 'dart:io';

import 'package:why_box/common/common.dart';
import 'package:why_box/enum/enum.dart';
import 'package:why_box/models/models.dart';
import 'package:why_box/providers/providers.dart';
import 'package:why_box/state.dart';
import 'package:why_box/widgets/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

class NodeImportResult {
  final List<ProxyNode> nodes;
  final bool directSave;

  const NodeImportResult({required this.nodes, this.directSave = false});
}

Future<NodeImportResult?> showNodePickerSheet(
  BuildContext context,
  List<Map<String, dynamic>> proxies, {
  String? title,
}) {
  return showSheet<NodeImportResult>(
    context: context,
    props: const SheetProps(
      isScrollControlled: true,
      initialFraction: 0.82,
      maxFraction: 0.94,
      maxWidth: 520,
    ),
    builder: (_, type) => AdaptiveSheetScaffold(
      type: type,
      title: title ?? appLocalizations.selectNodes,
      body: NodePickerView(proxies: proxies),
    ),
  );
}

Future<String?> showProfileYamlPicker(BuildContext context) {
  return showSheet<String>(
    context: context,
    props: const SheetProps(
      isScrollControlled: true,
      initialFraction: 0.62,
      maxFraction: 0.88,
      maxWidth: 460,
    ),
    builder: (_, type) => AdaptiveSheetScaffold(
      type: type,
      title: appLocalizations.nodeFromProfile,
      body: const _ProfileYamlPickerBody(),
    ),
  );
}

class _ProfileYamlPickerBody extends ConsumerWidget {
  const _ProfileYamlPickerBody();

  Future<void> _selectProfile(BuildContext context, Profile profile) async {
    final content = await globalState.appController.safeRun<String>(
      () async {
        final path = await appPath.getProfilePath(profile.id);
        final file = File(path);
        if (!await file.exists()) {
          throw appLocalizations.fileNotFound;
        }
        return file.readAsString();
      },
      needLoading: true,
      silence: false,
      title: profile.label ?? profile.id,
    );
    if (content == null || !context.mounted) return;
    Navigator.of(context).pop(content);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profiles = ref.watch(profilesProvider);
    if (profiles.isEmpty) {
      return NullStatus(
        label: appLocalizations.noData,
        icon: Icons.description_outlined,
      );
    }
    final scheme = context.colorScheme;
    final divider = Divider(
      height: 1,
      thickness: 1,
      color: scheme.outlineVariant.withValues(
        alpha: scheme.brightness == Brightness.light ? 0.6 : 0.45,
      ),
      indent: 16,
      endIndent: 16,
    );
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      children: [
        CommonCard(
          type: CommonCardType.filled,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < profiles.length; i++) ...[
                if (i > 0) divider,
                ListItem(
                  leading: AppIcon(
                    profiles[i].type == ProfileType.file
                        ? Icons.description_outlined
                        : Icons.cloud_outlined,
                  ),
                  title: EmojiText(
                    profiles[i].label ?? profiles[i].id,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    profiles[i].type == ProfileType.file ||
                            profiles[i].url.isEmpty
                        ? appLocalizations.localFile
                        : profiles[i].url,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const AppIcon(Icons.chevron_right),
                  onTap: () => _selectProfile(context, profiles[i]),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class NodePickerView extends ConsumerStatefulWidget {
  final List<Map<String, dynamic>> proxies;

  const NodePickerView({super.key, required this.proxies});

  @override
  ConsumerState<NodePickerView> createState() => _NodePickerViewState();
}

class _NodePickerViewState extends ConsumerState<NodePickerView> {
  final TextEditingController _searchController = TextEditingController();
  final Set<int> _selectedIndices = {};
  late final Map<String, int> _protocolCounts;
  late final List<String> _protocols;
  String? _selectedProtocol;
  String _query = '';

  @override
  void initState() {
    super.initState();
    final counts = <String, int>{};
    for (final proxy in widget.proxies) {
      final type = _proxyType(proxy);
      if (type.isNotEmpty) {
        counts[type] = (counts[type] ?? 0) + 1;
      }
    }
    _protocolCounts = counts;
    final sorted = counts.keys.toList()
      ..sort((a, b) {
        if (a == 'ss' && b != 'ss') return -1;
        if (b == 'ss' && a != 'ss') return 1;
        return a.compareTo(b);
      });
    _protocols = sorted;
    // Default to SS filter when SS nodes are present.
    _selectedProtocol = counts.containsKey('ss') ? 'ss' : null;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _proxyName(Map<String, dynamic> proxy) =>
      proxy['name']?.toString() ?? '';

  String _proxyType(Map<String, dynamic> proxy) =>
      proxy['type']?.toString().trim().toLowerCase() ?? '';

  String _proxyEndpoint(Map<String, dynamic> proxy) {
    final server = proxy['server']?.toString() ?? '';
    final port = proxy['port']?.toString() ?? '';
    if (server.isEmpty) return '';
    return port.isEmpty ? server : '$server:$port';
  }

  bool _proxyUdp(Map<String, dynamic> proxy) {
    final udp = proxy['udp'];
    if (udp is bool) return udp;
    return udp?.toString().toLowerCase() == 'true';
  }

  List<int> _filteredIndices() {
    final q = _query.trim().toLowerCase();
    final result = <int>[];
    for (var i = 0; i < widget.proxies.length; i++) {
      final proxy = widget.proxies[i];
      if (_selectedProtocol != null && _proxyType(proxy) != _selectedProtocol) {
        continue;
      }
      if (q.isNotEmpty) {
        final name = _proxyName(proxy).toLowerCase();
        final server = proxy['server']?.toString().toLowerCase() ?? '';
        final port = proxy['port']?.toString().toLowerCase() ?? '';
        final cipher = proxy['cipher']?.toString().toLowerCase() ?? '';
        if (!name.contains(q) &&
            !server.contains(q) &&
            !port.contains(q) &&
            !cipher.contains(q)) {
          continue;
        }
      }
      result.add(i);
    }
    return result;
  }

  void _toggleIndex(int index) {
    setState(() {
      if (!_selectedIndices.remove(index)) {
        _selectedIndices.add(index);
      }
    });
  }

  void _toggleSelectVisible(List<int> visible, Set<String> existingNames) {
    final preferred = [
      for (final i in visible)
        if (!existingNames.contains(_proxyName(widget.proxies[i]))) i,
    ];
    final targets = preferred.isNotEmpty ? preferred : visible;
    final allSelected =
        targets.isNotEmpty && targets.every(_selectedIndices.contains);
    setState(() {
      if (allSelected) {
        _selectedIndices.removeAll(visible);
      } else {
        _selectedIndices.addAll(targets);
      }
    });
  }

  void _confirm({required bool directSave}) {
    if (_selectedIndices.isEmpty) return;
    final ordered = _selectedIndices.toList()..sort();
    final chosen = [for (final idx in ordered) widget.proxies[idx]];
    final built = globalState.appController.buildNodesFromProxies(chosen);
    Navigator.of(
      context,
    ).pop(NodeImportResult(nodes: built, directSave: directSave));
  }

  Widget _buildFilterChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final scheme = context.colorScheme;
    return Material(
      color: selected
          ? scheme.primary.withValues(alpha: 0.14)
          : scheme.surfaceContainerHigh,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Text(
            label,
            style: context.textTheme.labelMedium?.copyWith(
              color: selected ? scheme.primary : scheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSmallBadge(
    String label, {
    Color? backgroundColor,
    Color? foregroundColor,
  }) {
    final scheme = context.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color:
            backgroundColor ?? scheme.onSurfaceVariant.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: context.textTheme.labelSmall?.copyWith(
          color: foregroundColor ?? scheme.onSurfaceVariant,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final existingNames = ref.watch(
      nodesProvider.select((nodes) => {for (final item in nodes) item.name}),
    );
    final visible = _filteredIndices();
    final scheme = context.colorScheme;
    final selectedCount = _selectedIndices.length;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
          child: TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _query = value),
            decoration: InputDecoration(
              isDense: true,
              hintText: appLocalizations.nodeSearchHint,
              prefixIcon: const AppIcon(Icons.search),
              suffixIcon: _query.isNotEmpty
                  ? IconButton(
                      icon: const AppIcon(Icons.close),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _query = '');
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _buildFilterChip(
                label: '${appLocalizations.allProtocols} (${widget.proxies.length})',
                selected: _selectedProtocol == null,
                onTap: () => setState(() => _selectedProtocol = null),
              ),
              for (final proto in _protocols) ...[
                const SizedBox(width: 8),
                _buildFilterChip(
                  label: '${proto.toUpperCase()} (${_protocolCounts[proto] ?? 0})',
                  selected: _selectedProtocol == proto,
                  onTap: () => setState(() => _selectedProtocol = proto),
                ),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 12, 4),
          child: Row(
            children: [
              Text(
                '${appLocalizations.selected}: $selectedCount / ${widget.proxies.length}',
                style: context.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: visible.isEmpty
                    ? null
                    : () => _toggleSelectVisible(visible, existingNames),
                child: Text(appLocalizations.selectAll),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: visible.isEmpty
              ? Center(
                  child: Text(
                    appLocalizations.noMatchingNodes,
                    style: context.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                  itemCount: visible.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, idx) {
                    final index = visible[idx];
                    final proxy = widget.proxies[index];
                    final name = _proxyName(proxy);
                    final type = _proxyType(proxy).toUpperCase();
                    final endpoint = _proxyEndpoint(proxy);
                    final cipher = proxy['cipher']?.toString() ?? '';
                    final hasUdp = _proxyUdp(proxy);
                    final exists = existingNames.contains(name);
                    final isSelected = _selectedIndices.contains(index);

                    return CommonCard(
                      type: CommonCardType.filled,
                      isSelected: isSelected,
                      onPressed: () => _toggleIndex(index),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(8, 10, 12, 10),
                        child: Row(
                          children: [
                            Checkbox(
                              value: isSelected,
                              onChanged: (_) => _toggleIndex(index),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: EmojiText(
                                          name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: context.textTheme.titleSmall,
                                        ),
                                      ),
                                      if (exists) ...[
                                        const SizedBox(width: 6),
                                        _buildSmallBadge(
                                          appLocalizations.nodeExistsTag,
                                          backgroundColor: scheme.tertiary
                                              .withValues(alpha: 0.14),
                                          foregroundColor: scheme.tertiary,
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 4,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      _buildSmallBadge(
                                        type,
                                        backgroundColor: scheme.primary
                                            .withValues(alpha: 0.12),
                                        foregroundColor: scheme.primary,
                                      ),
                                      if (hasUdp) _buildSmallBadge('UDP'),
                                      if (endpoint.isNotEmpty)
                                        Text(
                                          endpoint,
                                          style: context.textTheme.bodySmall
                                              ?.copyWith(
                                                color: scheme.onSurfaceVariant,
                                              ),
                                        ),
                                      if (cipher.isNotEmpty)
                                        Text(
                                          cipher,
                                          style: context.textTheme.bodySmall
                                              ?.copyWith(
                                                color: scheme.onSurfaceVariant,
                                              ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: selectedCount <= 1
                ? SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: selectedCount == 0
                          ? null
                          : () => _confirm(directSave: false),
                      child: Text(appLocalizations.selectAndConfigure),
                    ),
                  )
                : Row(
                    children: [
                      Expanded(
                        child: FilledButton.tonal(
                          onPressed: () => _confirm(directSave: true),
                          child: Text(
                            '${appLocalizations.directBatchImport} ($selectedCount)',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => _confirm(directSave: false),
                          child: Text(
                            '${appLocalizations.configureAndImport} ($selectedCount)',
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}
