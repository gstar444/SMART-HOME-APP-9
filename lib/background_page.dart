import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'strings.dart';

const String kBgPresetKey = 'home_bg_preset';
const String kBgPhotoKey = 'home_bg_photo';
const String kBgDimKey = 'home_bg_dim';

const Color _base = Color(0xFF0B1020);
const Color _accent = Color(0xFF7C5CF0);

enum BgPreset { aurora, ocean, ember, forest, grid }

/// सेव की हुई होम स्क्रीन की पृष्ठभूमि। डैशबोर्ड इसे बाद में पढ़ेगा।
class HomeBackground {
  const HomeBackground({
    required this.preset,
    required this.photoPath,
    required this.dim,
  });

  final BgPreset preset;
  final String? photoPath;
  final double dim;

  static Future<HomeBackground> load() async {
    final p = await SharedPreferences.getInstance();
    final name = p.getString(kBgPresetKey) ?? BgPreset.aurora.name;
    final preset = BgPreset.values.firstWhere(
      (e) => e.name == name,
      orElse: () => BgPreset.aurora,
    );
    final photo = p.getString(kBgPhotoKey);
    final exists = photo != null && File(photo).existsSync();
    return HomeBackground(
      preset: preset,
      photoPath: exists ? photo : null,
      dim: p.getDouble(kBgDimKey) ?? 0.45,
    );
  }
}

class BackgroundPage extends StatefulWidget {
  const BackgroundPage({super.key, required this.tr});

  final Tr tr;

  @override
  State<BackgroundPage> createState() => _BackgroundPageState();
}

class _BackgroundPageState extends State<BackgroundPage> {
  BgPreset _preset = BgPreset.aurora;
  String? _photo;
  double _dim = 0.45;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    HomeBackground.load().then((bg) {
      if (!mounted) return;
      setState(() {
        _preset = bg.preset;
        _photo = bg.photoPath;
        _dim = bg.dim;
      });
    });
  }

  Future<void> _pickPhoto() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (picked == null) return;
    final dir = await getApplicationDocumentsDirectory();
    final copied = await File(
      picked.path,
    ).copy('${dir.path}/home_bg_${DateTime.now().millisecondsSinceEpoch}.jpg');
    if (!mounted) return;
    setState(() => _photo = copied.path);
  }

  void _pickPreset(BgPreset p) => setState(() {
    _preset = p;
    _photo = null;
  });

  void _reset() => setState(() {
    _preset = BgPreset.aurora;
    _photo = null;
    _dim = 0.45;
  });

  Future<void> _save() async {
    setState(() => _saving = true);
    final p = await SharedPreferences.getInstance();
    await p.setString(kBgPresetKey, _preset.name);
    await p.setDouble(kBgDimKey, _dim);
    if (_photo != null) {
      await p.setString(kBgPhotoKey, _photo!);
    } else {
      await p.remove(kBgPhotoKey);
    }
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurface
        .withValues(alpha: 0.62);
    final tr = widget.tr;
    final photoMode = _photo != null;
    return Scaffold(
      appBar: AppBar(title: Text(tr.backgroundTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _preview(),
          const SizedBox(height: 20),
          Text(tr.presetsTitle, style: TextStyle(color: muted, fontSize: 12)),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.78,
            children: [
              _presetTile('Aurora', BgPreset.aurora),
              _presetTile('Ocean', BgPreset.ocean),
              _presetTile('Ember', BgPreset.ember),
              _presetTile('Forest', BgPreset.forest),
              _presetTile('Grid', BgPreset.grid),
              _galleryTile(),
            ],
          ),
          const SizedBox(height: 22),
          Text(tr.photoTitle, style: TextStyle(color: muted, fontSize: 12)),
          const SizedBox(height: 6),
          if (photoMode) ...[
            Text(tr.dimTitle, style: TextStyle(color: muted, fontSize: 13)),
            Slider(
              value: _dim,
              min: 0,
              max: 0.8,
              activeColor: _accent,
              onChanged: (v) => setState(() => _dim = v),
            ),
          ] else
            Text(
              tr.pickPhotoFirst,
              style: TextStyle(color: muted, fontSize: 13),
            ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _reset,
                  child: Text(tr.resetDefault),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(tr.save),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _preview() {
    final photo = _photo;
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        height: 170,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (photo != null)
              Image.file(File(photo), fit: BoxFit.cover)
            else
              _PresetBg(preset: _preset),
            Container(
              color: Colors.black.withValues(alpha: photo != null ? _dim : 0),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Container(
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF0F1624).withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _presetTile(String label, BgPreset p) {
    return _tileFrame(
      selected: _photo == null && _preset == p,
      label: label,
      onTap: () => _pickPreset(p),
      child: _PresetBg(preset: p),
    );
  }

  Widget _galleryTile() {
    final photo = _photo;
    return _tileFrame(
      selected: photo != null,
      label: widget.tr.galleryTile,
      onTap: _pickPhoto,
      child: photo != null
          ? Image.file(File(photo), fit: BoxFit.cover)
          : const Center(
              child: Text('+', style: TextStyle(fontSize: 28, color: _accent)),
            ),
    );
  }

  Widget _tileFrame({
    required bool selected,
    required String label,
    required VoidCallback onTap,
    required Widget child,
  }) {
    final muted = Theme.of(context).colorScheme.onSurface
        .withValues(alpha: 0.7);
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selected
                      ? _accent
                      : Colors.white.withValues(alpha: 0.08),
                  width: selected ? 2 : 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: child,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              color: selected ? Colors.white : muted,
            ),
          ),
        ],
      ),
    );
  }
}

Color _glow(BgPreset p) => switch (p) {
  BgPreset.aurora => const Color(0x8C7C5CF0),
  BgPreset.ocean => const Color(0x802DD4BF),
  BgPreset.ember => const Color(0x73F97316),
  BgPreset.forest => const Color(0x6622C55E),
  BgPreset.grid => const Color(0x00000000),
};

Alignment _center(BgPreset p) => switch (p) {
  BgPreset.aurora => const Alignment(0.5, -0.6),
  BgPreset.ocean => const Alignment(-0.6, 0.6),
  BgPreset.ember => const Alignment(0.4, 0.9),
  BgPreset.forest => const Alignment(-0.4, -0.5),
  BgPreset.grid => Alignment.center,
};

class _PresetBg extends StatelessWidget {
  const _PresetBg({required this.preset});
  final BgPreset preset;

  @override
  Widget build(BuildContext context) {
    if (preset == BgPreset.grid) {
      return Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: _base),
          CustomPaint(painter: _DotsPainter()),
        ],
      );
    }
    final glow = _glow(preset);
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: _base),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: _center(preset),
              radius: 0.9,
              colors: [glow, glow.withValues(alpha: 0)],
            ),
          ),
        ),
      ],
    );
  }
}

class _DotsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0x598FA0BD);
    for (double x = 10; x < size.width; x += 16) {
      for (double y = 10; y < size.height; y += 16) {
        canvas.drawCircle(Offset(x, y), 1.1, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
