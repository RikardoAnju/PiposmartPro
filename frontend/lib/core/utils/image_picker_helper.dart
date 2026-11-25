import 'package:ayocucinew/core/theme/app_font.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ayocucinew/shared/widgets/custom_toast.dart';

class ImagePickerHelper {
  static final ImagePicker _imagePicker = ImagePicker();
  static const String _sourceGallery = 'gallery';
  static const String _sourceCamera = 'camera';

  static Future<bool> _requestPhotoPermission() async {
    if (Platform.isAndroid) {
      // FilePicker di Android memakai system document picker, jadi
      // tidak perlu memaksa runtime permission galeri lebih dulu.
      return true;
    } else if (Platform.isIOS) {
      final status = await Permission.photos.request();
      return status.isGranted || status.isLimited;
    }
    return true;
  }

  /// Check and request camera permission
  static Future<bool> _requestCameraPermission() async {
    final status = await Permission.camera.request();
    return status.isGranted;
  }

  /// Show permission denied dialog
  static void _showPermissionDeniedDialog(
    BuildContext context,
    String permissionType,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Izin Diperlukan'),
        content: Text(
          'Aplikasi memerlukan izin $permissionType untuk melanjutkan. '
          'Silakan aktifkan di pengaturan aplikasi.',
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF5350),
            ),
            child: const Text('Buka Pengaturan'),
          ),
        ],
      ),
    );
  }

  /// Pick image from gallery using file_picker (More reliable)
  static Future<File?> pickImageFromGallery(BuildContext context) async {
    try {
      // Request permission first
      final hasPermission = await _requestPhotoPermission();

      if (!hasPermission) {
        if (context.mounted) {
          _showPermissionDeniedDialog(context, 'akses galeri');
        }
        return null;
      }

      if (Platform.isIOS) {
        final XFile? image = await _imagePicker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 80,
          maxWidth: 1280,
          maxHeight: 1280,
        );

        if (image == null) return null;

        final file = File(image.path);

        // Validate file size (max 5MB)
        final fileSize = await file.length();
        if (fileSize > 5 * 1024 * 1024) {
          if (context.mounted) {
            CustomToast.show(
              context,
              message: 'Ukuran gambar terlalu besar (maksimal 5MB)',
              isError: true,
            );
          }
          return null;
        }

        return file;
      }

      final result = await FilePicker.pickFiles(type: FileType.image);

      if (result.isNotEmpty && result.single.path != null) {
        final file = File(result.single.path!);

        final fileSize = await file.length();
        if (fileSize > 5 * 1024 * 1024) {
          if (context.mounted) {
            CustomToast.show(
              context,
              message: 'Ukuran gambar terlalu besar (maksimal 5MB)',
              isError: true,
            );
          }
          return null;
        }

        return file;
      }

      return null;
    } catch (e) {
      debugPrint('Error picking image from gallery: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memilih gambar: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return null;
    }
  }

  /// Pick image from camera using image_picker (fallback to file if fails)
  static Future<File?> pickImageFromCamera(BuildContext context) async {
    try {
      // Request permission first
      final hasPermission = await _requestCameraPermission();

      if (!hasPermission) {
        if (context.mounted) {
          _showPermissionDeniedDialog(context, 'kamera');
        }
        return null;
      }

      // Try using image_picker first for camera
      try {
        final XFile? image = await _imagePicker.pickImage(
          source: ImageSource.camera,
          imageQuality: 80,
          maxWidth: 1024,
          maxHeight: 1024,
        );

        if (image != null) {
          return File(image.path);
        }
      } catch (e) {
        debugPrint('Image picker failed, trying alternative: $e');

        if (Platform.isIOS) {
          rethrow;
        }

        final result = await FilePicker.pickFiles(type: FileType.image);

        if (result.isNotEmpty && result.single.path != null) {
          return File(result.single.path!);
        }
      }

      return null;
    } catch (e) {
      debugPrint('Error picking image from camera: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengambil foto: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return null;
    }
  }

  /// Show dialog to choose image source with better UI
  static Future<File?> showImageSourceDialog(BuildContext context) async {
    final source = await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        final navigator = Navigator.of(context);
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 20),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Title
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'Pilih Sumber Gambar',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: AppFont.w700,
                      color: Colors.black87,
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Gallery option
                InkWell(
                  onTap: () => navigator.pop(_sourceGallery),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF5350).withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.photo_library,
                            color: Color(0xFFEF5350),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Galeri',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: AppFont.w600,
                                  color: Colors.black87,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Pilih dari galeri foto',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: Colors.grey),
                      ],
                    ),
                  ),
                ),

                const Divider(height: 1),

                // Camera option
                InkWell(
                  onTap: () => navigator.pop(_sourceCamera),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF5350).withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            color: Color(0xFFEF5350),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Kamera',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: AppFont.w600,
                                  color: Colors.black87,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Ambil foto baru',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: Colors.grey),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );

    if (source == _sourceGallery) {
      if (!context.mounted) return null;
      return pickImageFromGallery(context);
    }

    if (source == _sourceCamera) {
      if (!context.mounted) return null;
      return pickImageFromCamera(context);
    }

    return null;
  }
}
