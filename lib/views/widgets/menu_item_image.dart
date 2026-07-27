import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class MenuItemImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final double iconSize;

  const MenuItemImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.iconSize = 24,
  });

  @override
  Widget build(BuildContext context) {
    final trimmed = imageUrl.trim();

    if (trimmed.isEmpty) {
      return _buildPlaceholder();
    }

    // 1. Base64 Image
    if (trimmed.startsWith('data:image/') && trimmed.contains(';base64,')) {
      try {
        final base64Str = trimmed.split(',').last;
        final bytes = base64Decode(base64Str);
        return Image.memory(
          bytes,
          width: width,
          height: height,
          fit: fit,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => _buildPlaceholder(),
        );
      } catch (_) {
        return _buildPlaceholder();
      }
    }

    // 2. Network Image
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return Image.network(
        trimmed,
        width: width,
        height: height,
        fit: fit,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => _buildPlaceholder(),
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            width: width,
            height: height,
            color: AppTheme.cardSurface,
            child: const Center(
              child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryAmber),
            ),
          );
        },
      );
    }

    // 3. Local File Image
    if (!kIsWeb) {
      try {
        final file = File(trimmed);
        if (file.existsSync()) {
          return Image.file(
            file,
            width: width,
            height: height,
            fit: fit,
            gaplessPlayback: true,
            errorBuilder: (_, __, ___) => _buildPlaceholder(),
          );
        }
      } catch (_) {
        // Fall through
      }
    }

    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return Container(
      width: width,
      height: height,
      color: AppTheme.cardSurface,
      child: Center(
        child: Icon(
          Icons.restaurant_menu_rounded,
          size: iconSize,
          color: AppTheme.primaryAmber,
        ),
      ),
    );
  }
}
