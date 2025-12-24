import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Màn hình camera - Sẵn sàng tích hợp YOLO model
class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> with SingleTickerProviderStateMixin {
  // Camera
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  int _selectedCameraIndex = 0;
  bool _isLoading = true;
  String? _errorMessage;

  // Animation
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    // Animation slide in từ dưới lên
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _initializeCamera();
    _slideController.forward();
  }

  /// Khởi tạo camera và xin quyền
  Future<void> _initializeCamera() async {
    try {
      // Xin quyền camera
      final status = await Permission.camera.request();

      if (!status.isGranted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Cần cấp quyền camera để tiếp tục';
        });
        return;
      }

      // Lấy danh sách camera
      _cameras = await availableCameras();

      if (_cameras == null || _cameras!.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Không tìm thấy camera';
        });
        return;
      }

      // Setup camera đầu tiên (back camera)
      await _setupCamera(_selectedCameraIndex);

    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Lỗi: $e';
      });
    }
  }

  /// Setup camera với index
  Future<void> _setupCamera(int cameraIndex) async {
    if (_cameras == null || _cameras!.isEmpty) return;

    if (_cameraController != null) {
      await _cameraController!.dispose();
    }

    // Đọc settings từ SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final resolutionSetting = prefs.getString('camera_resolution') ?? 'high';
    final flashSetting = prefs.getString('flash_mode') ?? 'auto';

    // Convert resolution string to ResolutionPreset
    ResolutionPreset resolution;
    switch (resolutionSetting) {
      case 'low':
        resolution = ResolutionPreset.low;
        break;
      case 'medium':
        resolution = ResolutionPreset.medium;
        break;
      case 'veryHigh':
        resolution = ResolutionPreset.veryHigh;
        break;
      case 'high':
      default:
        resolution = ResolutionPreset.high;
        break;
    }

    final camera = _cameras![cameraIndex];
    _cameraController = CameraController(
      camera,
      resolution,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg, // Chuẩn bị cho YOLO
    );

    try {
      await _cameraController!.initialize();

      // Set flash mode
      FlashMode flashMode;
      switch (flashSetting) {
        case 'on':
          flashMode = FlashMode.torch;
          break;
        case 'off':
          flashMode = FlashMode.off;
          break;
        case 'auto':
        default:
          flashMode = FlashMode.auto;
          break;
      }
      await _cameraController!.setFlashMode(flashMode);

      // TODO: Sau khi có model, sẽ bật streaming ở đây
      // _cameraController!.startImageStream((image) {
      //   _runModelInference(image);
      // });

      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = null;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Lỗi setup camera: $e';
      });
    }
  }

  /// Toggle camera (front <-> back)
  Future<void> _toggleCamera() async {
    if (_cameras == null || _cameras!.length < 2) {
      _showSnackBar('Thiết bị chỉ có 1 camera');
      return;
    }

    setState(() => _isLoading = true);
    _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras!.length;
    await _setupCamera(_selectedCameraIndex);
  }

  /// Hiển thị thông báo
  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera preview hoặc loading/error
          _buildCameraView(),

          // Top bar với nút back
          SlideTransition(
            position: _slideAnimation,
            child: _buildTopBar(),
          ),

          // Bottom controls (sẽ thêm sau: chụp ảnh, xem kết quả...)
          SlideTransition(
            position: _slideAnimation,
            child: _buildBottomControls(),
          ),

          // Nút toggle camera góc dưới phải
          if (_cameraController != null && _cameraController!.value.isInitialized)
            Positioned(
              bottom: 100,
              right: 20,
              child: SlideTransition(
                position: _slideAnimation,
                child: _buildIconButton(
                  icon: Icons.flip_camera_ios_rounded,
                  onPressed: _toggleCamera,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Camera preview chính
  Widget _buildCameraView() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white.withValues(alpha: 0.8)),
            ),
            const SizedBox(height: 16),
            Text(
              'Đang khởi tạo camera...',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                    _errorMessage = null;
                  });
                  _initializeCamera();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                ),
                child: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      );
    }

    if (_cameraController != null && _cameraController!.value.isInitialized) {
      return SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: _cameraController!.value.previewSize!.height,
            height: _cameraController!.value.previewSize!.width,
            child: CameraPreview(_cameraController!),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  /// Top bar với nút back
  Widget _buildTopBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Nút back với animation
            _buildIconButton(
              icon: Icons.arrow_back_ios_new_rounded,
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  /// Icon button mượt mà
  Widget _buildIconButton({required IconData icon, required VoidCallback onPressed}) {
    return Material(
      color: Colors.black.withValues(alpha: 0.3),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
      ),
    );
  }

  /// Bottom controls (placeholder cho capture button sau này)
  Widget _buildBottomControls() {
    return const SizedBox.shrink();
  }

// ============================================================
// PHẦN NÀY SẼ DÙNG SAU KHI CÓ MODEL
// ============================================================

// /// Load YOLO TFLite model
// Future<void> _loadModel() async {
//   try {
//     // Load model từ assets/models/best.tflite
//     _interpreter = await Interpreter.fromAsset('assets/models/best.tflite');
//     print('✅ Model loaded successfully');
//   } catch (e) {
//     print('❌ Error loading model: $e');
//   }
// }

// /// Chạy inference trên mỗi frame
// Future<void> _runModelInference(CameraImage image) async {
//   if (_interpreter == null) return;
//
//   // TODO: Convert CameraImage -> Input tensor
//   // TODO: Run inference
//   // TODO: Parse output -> Bounding boxes
//   // TODO: Update UI với kết quả
// }
}
