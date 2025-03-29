import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:tik_tok_wikipidiea/models/post_content.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:file_picker/file_picker.dart';
import 'package:tik_tok_wikipidiea/services/notification_service.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:share_plus/share_plus.dart'; // Add this package
import 'package:path/path.dart' as p; // Add this package

class PdfService {
  /// Generates a PDF from article data and returns the file path
  /// If letUserChooseLocation is true, shows a file picker dialog
  static Future<String> generateArticlePdf(
    Post post,
    List<dynamic> sections, {
    required BuildContext context,
    bool openAfterGenerate = false,
    bool letUserChooseLocation = true,
  }) async {
    try {
      // First request storage permission with explanation
      bool hasPermission = await _requestStoragePermission(context);
      if (!hasPermission) {
        return "Cannot save PDF: Storage permission denied";
      }

      // Create a PDF document
      final pdf = pw.Document();

      // Add a title page
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Title
                pw.Center(
                  child: pw.Text(
                    post.title,
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
                pw.SizedBox(height: 20),

                // Domain and date
                pw.Center(
                  child: pw.Text(
                    "${post.domain.toUpperCase()} - ${post.createdAt}",
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontStyle: pw.FontStyle.italic,
                      color: PdfColors.grey700,
                    ),
                  ),
                ),
                pw.SizedBox(height: 40),

                // Fun fact
                if (post.funFact.isNotEmpty) ...[
                  pw.Container(
                    padding: pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.grey200,
                      borderRadius: pw.BorderRadius.circular(8),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          "Did you know?",
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        pw.SizedBox(height: 6),
                        pw.Text(
                          post.funFact,
                          style: pw.TextStyle(
                            fontSize: 14,
                            fontStyle: pw.FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 20),
                ],

                // Summary
                pw.Text(
                  "Summary",
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Text(post.summary, style: pw.TextStyle(fontSize: 12)),
              ],
            );
          },
        ),
      );

      // Add content pages
      for (var section in sections) {
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            build: (pw.Context context) {
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Section title
                  pw.Text(
                    section.title,
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 10),
                  // Section content
                  pw.Text(section.content, style: pw.TextStyle(fontSize: 12)),
                  pw.SizedBox(height: 20),
                ],
              );
            },
          ),
        );
      }

      // Add footer page with attribution
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text(
                  "Generated by WikiTok App",
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Text(
                  "Content derived from Wikipedia",
                  style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
                ),
                pw.SizedBox(height: 30),
                pw.Text("Get WikiTok App:", style: pw.TextStyle(fontSize: 12)),
                pw.SizedBox(height: 5),
                pw.Text(
                  "https://drive.google.com/drive/folders/19Haq7_FkI4E9L8QZbTTBMY3jIJ9xlQws?usp=drive_link",
                  style: pw.TextStyle(fontSize: 10, color: PdfColors.blue700),
                ),
              ],
            );
          },
        ),
      );

      // Generate PDF content bytes
      final pdfBytes = await pdf.save();

      // Create a sanitized filename
      final sanitizedTitle =
          post.title
              .replaceAll(RegExp(r'[^\w\s]+'), '')
              .replaceAll(' ', '_')
              .toLowerCase();
      final fileName = '${sanitizedTitle}_wikitok.pdf';

      try {
        String filePath;

        // Let user choose location if requested
        if (letUserChooseLocation) {
          filePath = await _getUserSelectedPath(fileName);
          if (filePath.isEmpty) {
            // User canceled the picker, use default path as fallback
            filePath = await _getSimpleFilePath(post.title);
          }
        } else {
          // Use default path
          filePath = await _getSimpleFilePath(post.title);
        }

        // Log the path for debugging
        print("Final path for saving PDF: $filePath");

        // Validate path before continuing
        if (filePath.isEmpty || filePath.startsWith('//')) {
          throw Exception("Invalid file path generated: $filePath");
        }

        // Ensure directory exists
        final file = File(filePath);
        final dir = file.parent;
        if (!await dir.exists()) {
          print("Creating directory: ${dir.path}");
          await dir.create(recursive: true);
        }

        // Save the PDF to a file
        await file.writeAsBytes(pdfBytes);

        print("PDF file size: ${pdfBytes.length} bytes");
        print("PDF successfully written to: ${file.path}");

        // Verify file exists after writing
        if (await file.exists()) {
          print("File verified to exist after writing");

          // Make file visible in gallery/file manager
          await _makeFileVisibleInGallery(file.path);

          // Show notification about the download
          await NotificationService.showPdfDownloadNotification(
            post.title,
            file.path,
          );
          print("************ saved to: ${file.path}");
          return "PDF saved successfully to: ${file.path}";
        } else {
          throw Exception("File was not created successfully");
        }
      } catch (e) {
        print("Error saving PDF file: $e");

        // Fallback to a guaranteed working location
        try {
          final tempDir = await getTemporaryDirectory();
          final backupPath =
              '${tempDir.path}${Platform.pathSeparator}$fileName';

          print("Attempting to save PDF to backup location: $backupPath");
          final backupFile = File(backupPath);
          await backupFile.writeAsBytes(pdfBytes);

          if (await backupFile.exists()) {
            return "PDF saved to alternate location: $backupPath";
          }
        } catch (backupError) {
          print("Backup save also failed: $backupError");
        }

        return "Error saving PDF: $e";
      }
    } catch (e) {
      print("*****************Error generating PDF: $e");
      return "Error generating PDF: $e";
    }
  }

  /// Show a dialog explaining why we need storage permission and request it
  static Future<bool> _requestStoragePermission(BuildContext context) async {
    // Determine the correct permissions to request based on Android version
    List<Permission> permissions = [];

    if (Platform.isAndroid) {
      // Check Android version
      final deviceInfoPlugin = DeviceInfoPlugin();
      final androidInfo = await deviceInfoPlugin.androidInfo;

      if (androidInfo.version.sdkInt >= 33) {
        // Android 13+ requires granular media permissions
        permissions = [
          Permission.photos,
          Permission.videos,
          Permission.audio,
          Permission.notification,
        ];
      } else if (androidInfo.version.sdkInt >= 30) {
        // Android 11-12 requires both storage and manage external storage
        permissions = [Permission.storage, Permission.manageExternalStorage];
      } else {
        // Android 10 and below
        permissions = [Permission.storage];
      }

      print(
        "Requesting permissions for Android ${androidInfo.version.sdkInt}: $permissions",
      );
    } else if (Platform.isIOS) {
      permissions = [Permission.photos];
    }

    if (permissions.isEmpty) {
      return false;
    }

    // Check if any permission is already granted
    bool allGranted = true;
    for (var permission in permissions) {
      PermissionStatus status = await permission.status;
      if (!status.isGranted) {
        allGranted = false;
        break;
      }
    }

    if (allGranted) {
      return true;
    }

    // Show explanation dialog
    final bool shouldRequest =
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text('Storage Access Needed'),
              content: Text(
                'WikiTok needs storage access to save article PDFs to your device. ' +
                    'This lets you access and share the PDFs later.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text('DENY'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text('ALLOW'),
                  style: TextButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!shouldRequest) {
      return false;
    }

    // Request each permission individually and check results
    Map<Permission, PermissionStatus> statuses = {};

    for (var permission in permissions) {
      // Request the permission
      PermissionStatus status = await permission.request();
      statuses[permission] = status;

      // If this permission is permanently denied, open settings
      if (status.isPermanentlyDenied) {
        final openSettings =
            await showDialog(
              context: context,
              builder:
                  (context) => AlertDialog(
                    title: Text('Permission Required'),
                    content: Text(
                      'Storage permission was denied. Please enable it in app settings to save PDFs.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text('CANCEL'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: Text('OPEN SETTINGS'),
                        style: TextButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
            ) ??
            false;

        if (openSettings) {
          await openAppSettings();

          // Check if permission was granted in settings
          status = await permission.status;
          statuses[permission] = status;
        }
      }
    }

    // Debug output of permission results
    statuses.forEach((permission, status) {
      print('Permission $permission: $status');
    });

    // Check if we have the permissions we need
    bool hasStorageAccess = false;

    if (Platform.isAndroid) {
      final deviceInfoPlugin = DeviceInfoPlugin();
      final androidInfo = await deviceInfoPlugin.androidInfo;

      if (androidInfo.version.sdkInt >= 33) {
        // For Android 13+, we need photos permission
        hasStorageAccess = statuses[Permission.photos]?.isGranted == true;
      } else if (androidInfo.version.sdkInt >= 30) {
        // For Android 11-12, prefer manage external storage, fall back to storage
        hasStorageAccess =
            statuses[Permission.manageExternalStorage]?.isGranted == true ||
            statuses[Permission.storage]?.isGranted == true;
      } else {
        // For older Android, just need storage
        hasStorageAccess = statuses[Permission.storage]?.isGranted == true;
      }
    } else {
      hasStorageAccess = statuses[Permission.photos]?.isGranted == true;
    }

    return hasStorageAccess;
  }

  /// Let user pick save location
  static Future<String> _getUserSelectedPath(String fileName) async {
    try {
      // Use FilePicker to pick directory
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Select where to save your PDF',
      );

      if (selectedDirectory == null || selectedDirectory.isEmpty) {
        print("User canceled directory selection");
        return '';
      }

      // Debug the selected path
      print("User selected directory: $selectedDirectory");

      // Fix path format issues
      if (selectedDirectory.endsWith('/') || selectedDirectory.endsWith('\\')) {
        // Remove trailing slashes
        selectedDirectory = selectedDirectory.replaceAll(RegExp(r'[/\\]$'), '');
      }

      // Ensure we have a valid path
      if (selectedDirectory.isEmpty || selectedDirectory == '/') {
        print("Invalid directory path selected");
        return '';
      }

      // Construct the proper file path with path separator
      final path = '$selectedDirectory${Platform.pathSeparator}$fileName';
      print("Constructed file path: $path");

      return path;
    } catch (e) {
      print("Error in file picker: $e");
      return '';
    }
  }

  /// Simplified file path getter - uses more visible locations
  static Future<String> _getSimpleFilePath(String title) async {
    // Create a sanitized filename
    final sanitizedTitle =
        title
            .replaceAll(RegExp(r'[^\w\s]+'), '')
            .replaceAll(' ', '_')
            .toLowerCase();
    final fileName = '${sanitizedTitle}_wikitok.pdf';

    try {
      if (Platform.isAndroid) {
        // Try to use the system Downloads folder (most visible)
        try {
          // Method 1: Try access to standard Downloads directory
          final externalDir = await getExternalStorageDirectory();
          if (externalDir != null) {
            // Navigate up from Android/data/... to the Downloads folder
            final downloadsDir = Directory(
              p.join(
                externalDir.path.split('Android').first,
                'Download',
                'WikiTok',
              ),
            );

            if (!await downloadsDir.exists()) {
              await downloadsDir.create(recursive: true);
            }

            final filePath = p.join(downloadsDir.path, fileName);
            print("Using system Downloads directory: $filePath");
            return filePath;
          }
        } catch (e) {
          print("Could not access system Downloads: $e");
        }

        // Method 2: Direct path if we have the required permissions
        try {
          if (await Permission.manageExternalStorage.isGranted) {
            final downloadDir = Directory(
              '/storage/emulated/0/Download/WikiTok',
            );
            if (!await downloadDir.exists()) {
              await downloadDir.create(recursive: true);
            }
            final filePath = p.join(downloadDir.path, fileName);
            print("Using direct Downloads path: $filePath");
            return filePath;
          }
        } catch (e) {
          print("Could not access direct path: $e");
        }

        // Fallback to app's external storage directory
        final appDirExternal = await getExternalStorageDirectory();
        if (appDirExternal != null) {
          final wikitokDir = Directory(
            p.join(appDirExternal.path, 'WikiTok_PDFs'),
          );
          if (!await wikitokDir.exists()) {
            await wikitokDir.create(recursive: true);
          }

          final filePath = p.join(wikitokDir.path, fileName);
          print("Using app's external directory: $filePath");
          return filePath;
        }
      } else if (Platform.isIOS) {
        // For iOS, use the documents directory which is visible in Files app
        final directory = await getApplicationDocumentsDirectory();
        final wikitokDir = Directory(p.join(directory.path, 'WikiTok_PDFs'));
        if (!await wikitokDir.exists()) {
          await wikitokDir.create(recursive: true);
        }

        final filePath = p.join(wikitokDir.path, fileName);
        print("Using iOS documents directory: $filePath");
        return filePath;
      }

      // Default fallback - use temporary directory
      final tempDir = await getTemporaryDirectory();
      final filePath = p.join(tempDir.path, fileName);
      print("Using temporary directory: $filePath");
      return filePath;
    } catch (e) {
      print("Error determining file path: $e");
      // Last resort - use temporary directory
      final output = await getTemporaryDirectory();
      return p.join(output.path, fileName);
    }
  }

  /// Update media store to make the file visible
  static Future<void> _makeFileVisibleInGallery(String filePath) async {
    if (Platform.isAndroid) {
      try {
        // Scan the file so it appears in downloads/files apps
        await _scanMediaFile(filePath);
      } catch (e) {
        print("Error making file visible: $e");
      }
    }
  }

  /// Scan file with MediaScanner so it appears in file managers
  static Future<void> _scanMediaFile(String filePath) async {
    // This would normally use platform channels to call the MediaScanner
    // For simplicity, we're adding a placeholder that would be implemented
    // with a plugin like media_scanner_scan_file

    print("File would be scanned for media store: $filePath");
    // In a real implementation, you'd use a plugin or platform channel
    // For now, the file will still be accessible but may not show up immediately
  }

  /// Add this method to offer sharing the PDF right after saving
  static Future<void> shareFile(String filePath, BuildContext context) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await Share.shareXFiles([
          XFile(filePath),
        ], text: 'Check out this article PDF from WikiTok');
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('File not found')));
      }
    } catch (e) {
      print("Error sharing file: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not share the file')));
    }
  }
}
