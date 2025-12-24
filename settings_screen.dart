import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

/// Màn hình Settings - Cài đặt app
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Settings values
  String _selectedResolution = 'high'; // low, medium, high, veryHigh
  String _flashMode = 'auto'; // auto, on, off
  String _cacheSize = 'Đang tính...';

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _calculateCacheSize();
  }

  /// Load settings từ SharedPreferences
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedResolution = prefs.getString('camera_resolution') ?? 'high';
      _flashMode = prefs.getString('flash_mode') ?? 'auto';
    });
  }

  /// Lưu settings vào SharedPreferences
  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('camera_resolution', _selectedResolution);
    await prefs.setString('flash_mode', _flashMode);
  }

  /// Tính dung lượng cache
  Future<void> _calculateCacheSize() async {
    try {
      final tempDir = Directory.systemTemp;
      int totalSize = 0;

      if (await tempDir.exists()) {
        await for (var entity in tempDir.list(recursive: true)) {
          if (entity is File) {
            totalSize += await entity.length();
          }
        }
      }

      // Convert bytes sang MB
      final sizeMB = (totalSize / (1024 * 1024)).toStringAsFixed(2);
      setState(() {
        _cacheSize = '$sizeMB MB';
      });
    } catch (e) {
      setState(() {
        _cacheSize = 'Không xác định';
      });
    }
  }

  /// Xóa cache
  Future<void> _clearCache() async {
    // Hiển thị dialog confirm
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa cache'),
        content: const Text(
          'Bạn có chắc muốn xóa tất cả dữ liệu tạm?\n\nĐiều này sẽ xóa:\n• Ảnh chụp tạm thời\n• Kết quả detection cũ\n• File tải về tạm',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // Show loading
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    try {
      // Xóa cache directory
      final tempDir = Directory.systemTemp;
      if (await tempDir.exists()) {
        await for (var entity in tempDir.list()) {
          if (entity is File) {
            await entity.delete();
          } else if (entity is Directory) {
            await entity.delete(recursive: true);
          }
        }
      }

      // Đóng loading dialog
      if (mounted) Navigator.pop(context);

      // Tính lại cache size
      await _calculateCacheSize();

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Đã xóa cache thành công'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      // Đóng loading dialog
      if (mounted) Navigator.pop(context);

      // Show error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Lỗi khi xóa cache: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cài đặt'),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF667eea), Color(0xFF764ba2)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        children: [
          // Camera Settings Section
          _buildSectionHeader('Camera'),

          // Resolution
          _buildResolutionTile(),

          // Flash Mode
          _buildFlashTile(),

          const Divider(height: 32),

          // Storage Section
          _buildSectionHeader('Bộ nhớ'),

          // Cache Size
          _buildCacheTile(),

          const Divider(height: 32),

          // About Section
          _buildSectionHeader('Thông tin'),

          // Version
          _buildInfoTile(
            icon: Icons.info_outline,
            title: 'Phiên bản',
            subtitle: '1.0.0',
          ),

          // About
          _buildInfoTile(
            icon: Icons.description_outlined,
            title: 'Về ứng dụng',
            subtitle: 'MHZ Food Detection',
            onTap: () => _showAboutDialog(),
          ),
        ],
      ),
    );
  }

  /// Section header
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.grey.shade600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  /// Resolution setting tile
  Widget _buildResolutionTile() {
    final resolutionMap = {
      'low': '480p (Nhanh)',
      'medium': '720p (Cân bằng)',
      'high': '1080p (Chất lượng)',
      'veryHigh': '4K (Cao nhất)',
    };

    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(Icons.video_settings, color: Colors.blue.shade700),
      ),
      title: const Text('Độ phân giải'),
      subtitle: Text(resolutionMap[_selectedResolution] ?? 'High'),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: () => _showResolutionDialog(),
    );
  }

  /// Flash mode setting tile
  Widget _buildFlashTile() {
    final flashMap = {
      'auto': 'Tự động',
      'on': 'Luôn bật',
      'off': 'Tắt',
    };

    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.amber.shade50,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          _flashMode == 'on' ? Icons.flash_on :
          _flashMode == 'off' ? Icons.flash_off : Icons.flash_auto,
          color: Colors.amber.shade700,
        ),
      ),
      title: const Text('Đèn flash'),
      subtitle: Text(flashMap[_flashMode] ?? 'Auto'),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: () => _showFlashDialog(),
    );
  }

  /// Cache tile
  Widget _buildCacheTile() {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(Icons.delete_outline, color: Colors.red.shade700),
      ),
      title: const Text('Xóa cache'),
      subtitle: Text('Dung lượng: $_cacheSize'),
      trailing: ElevatedButton(
        onPressed: _clearCache,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red.shade50,
          foregroundColor: Colors.red.shade700,
          elevation: 0,
        ),
        child: const Text('Xóa'),
      ),
    );
  }

  /// Info tile (không thay đổi được)
  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Colors.grey.shade700),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: onTap != null ? const Icon(Icons.arrow_forward_ios, size: 16) : null,
      onTap: onTap,
    );
  }

  /// Dialog chọn resolution
  Future<void> _showResolutionDialog() async {
    final resolutions = {
      'low': '480p - Nhanh, ít lag',
      'medium': '720p - Cân bằng',
      'high': '1080p - Chất lượng tốt',
      'veryHigh': '4K - Cao nhất',
    };

    final selected = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Chọn độ phân giải'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: resolutions.entries.map((entry) {
            return RadioListTile<String>(
              value: entry.key,
              groupValue: _selectedResolution,
              title: Text(entry.value),
              onChanged: (value) => Navigator.pop(context, value),
            );
          }).toList(),
        ),
      ),
    );

    if (selected != null) {
      setState(() {
        _selectedResolution = selected;
      });
      await _saveSettings();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Đã lưu cài đặt'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    }
  }

  /// Dialog chọn flash mode
  Future<void> _showFlashDialog() async {
    final flashModes = {
      'auto': 'Tự động - Bật khi tối',
      'on': 'Luôn bật',
      'off': 'Tắt',
    };

    final selected = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Chế độ đèn flash'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: flashModes.entries.map((entry) {
            return RadioListTile<String>(
              value: entry.key,
              groupValue: _flashMode,
              title: Text(entry.value),
              onChanged: (value) => Navigator.pop(context, value),
            );
          }).toList(),
        ),
      ),
    );

    if (selected != null) {
      setState(() {
        _flashMode = selected;
      });
      await _saveSettings();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Đã lưu cài đặt'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    }
  }

  /// Dialog về ứng dụng
  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.restaurant, color: Color(0xFF667eea)),
            SizedBox(width: 8),
            Text('MHZ Food Detection'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Phiên bản 1.0.0',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Text(
              'Ứng dụng phát hiện món ăn và tính toán khẩu phần dinh dưỡng cho người cao tuổi trong viện dưỡng lão.',
            ),
            SizedBox(height: 16),
            Text(
              'Công nghệ: Flutter + YOLO TFLite',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }
}
