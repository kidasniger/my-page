import 'package:flutter/material.dart';

import '../core/palette.dart';

/// Icône de la Page : photo publique de Facebook (sans jeton),
/// sinon initiale du nom.
class PageAvatar extends StatelessWidget {
  final String pageId;
  final String name;
  final double size;
  const PageAvatar(this.pageId, this.name, {super.key, this.size = 44});

  @override
  Widget build(BuildContext context) {
    final c = context.p;
    final px = (size * 3).round();
    final n = name.trim();
    final initiale =
        n.isEmpty ? '?' : String.fromCharCodes(n.runes.take(1)).toUpperCase();
    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      color: c.ink,
      child: Text(
        initiale,
        style: TextStyle(
          fontSize: size * 0.42,
          fontWeight: FontWeight.w900,
          color: c.bg,
        ),
      ),
    );
    final id = pageId.trim();
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.3),
      child: SizedBox(
        width: size,
        height: size,
        child: RegExp(r'^\d+$').hasMatch(id)
            ? Image.network(
                'https://graph.facebook.com/$id/picture?width=$px&height=$px',
                fit: BoxFit.cover,
                cacheWidth: px,
                gaplessPlayback: true,
                excludeFromSemantics: true,
                errorBuilder: (_, _, _) => fallback,
                loadingBuilder: (_, child, p) => p == null ? child : fallback,
              )
            : fallback,
      ),
    );
  }
}
