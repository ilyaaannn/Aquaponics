import 'package:flutter/material.dart';
import '../helper/app_theme.dart';
import '../helper/header.dart';
import '../model/model_ekosistem.dart';

class EkosistemPage extends StatefulWidget {
  const EkosistemPage({Key? key}) : super(key: key);

  @override
  State<EkosistemPage> createState() => _EkosistemPageState();
}

class _EkosistemPageState extends State<EkosistemPage>
    with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _presetDropdownKey = GlobalKey();
  bool _isPresetMenuOpen = false;

  @override
  void initState() {
    super.initState();
    activePresetIndex.addListener(_onPresetChanged);
  }

  void _onPresetChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    activePresetIndex.removeListener(_onPresetChanged);
    _scrollController.dispose();
    super.dispose();
  }

  void _selectPreset(int index) {
    if (activePresetIndex.value == index) return;
    activePresetIndex.value = index;
    activeEcosystem.value = presetEcosystems[index];
  }

  @override
  Widget build(BuildContext context) {
    final eco = activeEcosystem.value;
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg(context),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: _buildHeader(),
            ),
            Expanded(
              child: RefreshIndicator(
                color: AppTheme.primaryGreen,
                backgroundColor: AppTheme.containerBg(context),
                strokeWidth: 2.5,
                onRefresh: () async {
                  await Future.delayed(const Duration(milliseconds: 500));
                  if (mounted) setState(() {});
                },
                child: CustomScrollView(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: ClampingScrollPhysics(),
                  ),
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                        child: _buildEkosistemCard(eco),
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

  Widget _buildHeader() {
    return CustomAppHeader(title: 'PRESET EKOSISTEM', showStatus: false);
  }

  Widget _buildPresetSelectorRow() {
    final activeEco = presetEcosystems[activePresetIndex.value];
    return Row(
      children: [
        Expanded(
          child: Text(
            'Pilih Preset Ekosistem',
            style: AppTheme.display(
              fontSize: 16,
              color: AppTheme.textPrimary(context),
            ),
          ),
        ),
        const SizedBox(width: 10),
        _buildPresetDropdownTrigger(activeEco),
      ],
    );
  }

  Widget _buildPresetDropdownTrigger(AquaponicEcosystem activeEco) {
    return Material(
      key: _presetDropdownKey,
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: _openPresetMenu,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: AppTheme.scaffoldBg(context),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: AppTheme.textSecondary(context).withOpacity(0.2),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  '${activeEco.fishName} + ${activeEco.plantName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.body(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary(context),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              AnimatedRotation(
                turns: _isPresetMenuOpen ? 0.5 : 0,
                duration: const Duration(milliseconds: 150),
                child: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: AppTheme.textSecondary(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openPresetMenu() async {
    final renderBox =
        _presetDropdownKey.currentContext?.findRenderObject() as RenderBox?;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (renderBox == null || overlay == null) return;

    final topLeft = renderBox.localToGlobal(Offset.zero, ancestor: overlay);
    final position = RelativeRect.fromLTRB(
      topLeft.dx,
      topLeft.dy + renderBox.size.height + 6,
      overlay.size.width - (topLeft.dx + renderBox.size.width),
      0,
    );

    setState(() => _isPresetMenuOpen = true);

    final selected = await showMenu<int>(
      context: context,
      position: position,
      color: AppTheme.containerBg(context),
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: AppTheme.textSecondary(context).withOpacity(0.12),
        ),
      ),
      constraints: const BoxConstraints(minWidth: 230, maxWidth: 260),
      items: List.generate(presetEcosystems.length, (index) {
        final eco = presetEcosystems[index];
        final isActive = activePresetIndex.value == index;

        return PopupMenuItem<int>(
          value: index,
          padding: EdgeInsets.zero,
          height: 44,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            color: isActive
                ? AppTheme.textSecondary(context).withOpacity(0.08)
                : Colors.transparent,
            child: Row(
              children: [
                Icon(
                  Icons.eco_rounded,
                  size: 16,
                  color: AppTheme.textSecondary(context),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${eco.fishName} + ${eco.plantName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.body(
                      fontSize: 13,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                      color: AppTheme.textPrimary(context),
                    ),
                  ),
                ),
                if (isActive)
                  Icon(
                    Icons.check_rounded,
                    size: 18,
                    color: AppTheme.textSecondary(context),
                  ),
              ],
            ),
          ),
        );
      }),
    );
    if (mounted) setState(() => _isPresetMenuOpen = false);
    if (selected != null) _selectPreset(selected);
  }

  Widget _buildEkosistemCard(AquaponicEcosystem eco) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.containerBg(context),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [AppTheme.cardShadow],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPresetSelectorRow(),
          const SizedBox(height: 20),
          Divider(
            height: 1,
            color: AppTheme.textSecondary(context).withOpacity(0.12),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Batas Parameter Ideal',
                      style: AppTheme.display(
                        fontSize: 18,
                        color: AppTheme.textPrimary(context),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.set_meal_rounded,
                            size: 12,
                            color: AppTheme.textSecondary(
                              context,
                            ).withOpacity(0.7),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            'Ikan',
                            style: AppTheme.data(
                              fontSize: 10.5,
                              color: AppTheme.textSecondary(context),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Icon(
                            Icons.eco_rounded,
                            size: 12,
                            color: AppTheme.textSecondary(
                              context,
                            ).withOpacity(0.7),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            'Tanaman',
                            style: AppTheme.data(
                              fontSize: 10.5,
                              color: AppTheme.textSecondary(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildParamRow(
            eco: eco,
            icon: Icons.water_drop,
            label: 'pH Air',
            fishRange: eco.fish.phRange,
            plantRange: eco.plant.phRange,
            idealRange: eco.phRange,
            color: AppTheme.phColor,
          ),
          _buildDivider(),
          _buildParamRow(
            eco: eco,
            icon: Icons.thermostat,
            label: 'Suhu',
            fishRange: eco.fish.tempRange,
            plantRange: eco.plant.tempRange,
            idealRange: eco.tempRange,
            color: AppTheme.tempColor,
          ),
          _buildDivider(),
          _buildParamRow(
            eco: eco,
            icon: Icons.wb_sunny_outlined,
            label: 'TDS / Nutrisi',
            fishRange: eco.fish.tdsRange,
            plantRange: eco.plant.tdsRange,
            idealRange: eco.tdsRange,
            color: AppTheme.tdsColor,
          ),
          _buildDivider(),
          _buildParamRow(
            eco: eco,
            icon: Icons.bubble_chart,
            label: 'DO / Oksigen',
            fishRange: eco.fish.doRange,
            plantRange: eco.plant.doRange,
            idealRange: eco.doRange,
            color: AppTheme.doColor,
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Divider(
        height: 1,
        color: AppTheme.textSecondary(context).withOpacity(0.12),
      ),
    );
  }

  Widget _buildParamRow({
    required AquaponicEcosystem eco,
    required IconData icon,
    required String label,
    required ParameterRange fishRange,
    required ParameterRange plantRange,
    required ParameterRange idealRange,
    required Color color,
  }) {
    final hasConflict = ParameterRange.intersect(fishRange, plantRange) == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: AppTheme.body(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary(context),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: (hasConflict ? AppTheme.statusWarning : color)
                    .withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                idealRange.rangeText,
                style: AppTheme.data(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: hasConflict ? AppTheme.statusWarning : color,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.only(left: 48),
          child: Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _buildRangeChip(
                icon: Icons.set_meal_rounded,
                rangeText: fishRange.rangeText,
                color: color,
              ),
              Icon(
                Icons.merge_type_rounded,
                size: 14,
                color: AppTheme.textSecondary(context).withOpacity(0.5),
              ),
              _buildRangeChip(
                icon: Icons.eco_rounded,
                rangeText: plantRange.rangeText,
                color: color,
              ),
              if (hasConflict) ...[
                const SizedBox(width: 2),
                const Icon(
                  Icons.warning_amber_rounded,
                  size: 13,
                  color: AppTheme.statusWarning,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRangeChip({
    required IconData icon,
    required String rangeText,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.25), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color.withOpacity(0.85)),
          const SizedBox(width: 3),
          Text(
            rangeText,
            style: AppTheme.data(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
