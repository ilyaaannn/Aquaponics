import 'package:flutter/material.dart';
import '../helper/app_theme.dart';
import '../model/model_ekosistem.dart';

class EkosistemPage extends StatefulWidget {
  const EkosistemPage({Key? key}) : super(key: key);

  @override
  State<EkosistemPage> createState() => _EkosistemPageState();
}

class _EkosistemPageState extends State<EkosistemPage>
    with SingleTickerProviderStateMixin {
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
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                child: _buildEkosistemCard(eco),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetSelectorRow() {
    final activeEco = presetEcosystems[activePresetIndex.value];
    return Row(
      children: [
        Expanded(
          child: Text(
            'Pilih Preset Ekosistem',
            style: AppTheme.display(
              fontSize: 15,
              color: AppTheme.textPrimary(context),
            ),
          ),
        ),
        const SizedBox(width: 8),
        _buildPresetDropdownTrigger(activeEco),
      ],
    );
  }

  Widget _buildPresetDropdownTrigger(AquaponicEcosystem activeEco) {
    return Material(
      key: _presetDropdownKey,
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: _openPresetMenu,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 180),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: AppTheme.scaffoldBg(context),
            borderRadius: BorderRadius.circular(8),
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
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary(context),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              AnimatedRotation(
                turns: _isPresetMenuOpen ? 0.5 : 0,
                duration: const Duration(milliseconds: 150),
                child: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 16,
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
      topLeft.dy + renderBox.size.height + 4,
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
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: AppTheme.textSecondary(context).withOpacity(0.12),
        ),
      ),
      constraints: const BoxConstraints(minWidth: 200, maxWidth: 240),
      items: List.generate(presetEcosystems.length, (index) {
        final eco = presetEcosystems[index];
        final isActive = activePresetIndex.value == index;

        return PopupMenuItem<int>(
          value: index,
          padding: EdgeInsets.zero,
          height: 40,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            color: isActive
                ? AppTheme.textSecondary(context).withOpacity(0.08)
                : Colors.transparent,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${eco.fishName} + ${eco.plantName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.body(
                      fontSize: 12,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                      color: AppTheme.textPrimary(context),
                    ),
                  ),
                ),
                if (isActive)
                  Icon(
                    Icons.check_rounded,
                    size: 16,
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
        borderRadius: BorderRadius.circular(22),
        boxShadow: [AppTheme.cardShadow],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPresetSelectorRow(),
          const SizedBox(height: 16),
          Divider(
            height: 1,
            color: AppTheme.textSecondary(context).withOpacity(0.12),
          ),
          const SizedBox(height: 16),
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
                        fontSize: 16,
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
                          const SizedBox(width: 2),
                          Text(
                            'Ikan',
                            style: AppTheme.data(
                              fontSize: 12,
                              color: AppTheme.textSecondary(context),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.eco_rounded,
                            size: 12,
                            color: AppTheme.textSecondary(
                              context,
                            ).withOpacity(0.7),
                          ),
                          const SizedBox(width: 2),
                          Text(
                            'Tanaman',
                            style: AppTheme.data(
                              fontSize: 12,
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
          const SizedBox(height: 14),
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
      padding: const EdgeInsets.symmetric(vertical: 8),
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
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: AppTheme.body(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary(context),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: (hasConflict ? AppTheme.statusWarning : color)
                    .withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
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
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(left: 42),
          child: Wrap(
            spacing: 4,
            runSpacing: 3,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _buildRangeChip(
                icon: Icons.set_meal_rounded,
                rangeText: fishRange.rangeText,
                color: color,
              ),
              Icon(
                Icons.merge_type_rounded,
                size: 12,
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
                  size: 12,
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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.25), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color.withOpacity(0.85)),
          const SizedBox(width: 2),
          Text(
            rangeText,
            style: AppTheme.data(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
