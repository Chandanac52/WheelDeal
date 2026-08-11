import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/gallery_provider.dart';
import '../../../widgets/app_image.dart';
import 'image_thumbnail.dart';

class ImageGallery extends ConsumerWidget {
  final String vehicleId;
  final List<String> images;

  const ImageGallery({
    super.key,
    required this.vehicleId,
    required this.images,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = ref.watch(selectedImageProvider(vehicleId));
    final safeIndex = selectedIndex < images.length ? selectedIndex : 0;

    return SizedBox(
      height: 300,
      child: Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: AppImage(
                source: images[safeIndex],
                fit: BoxFit.cover,
                height: double.infinity,
                width: double.infinity,
              ),
            ),
          ),
          if (images.length > 1) ...[
            const SizedBox(width: 12),
            SizedBox(
              width: 75,
              child: ListView.builder(
                itemCount: images.length,
                itemBuilder: (context, index) {
                  return ImageThumbnail(
                    image: images[index],
                    isSelected: safeIndex == index,
                    onTap: () {
                      ref.read(selectedImageProvider(vehicleId).notifier).state = index;
                    },
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}
