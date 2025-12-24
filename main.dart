import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/home_screen.dart';

/// Entry point của MHZ App - Ứng dụng detect món ăn cho người cao tuổi
void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Khóa orientation ở chế độ portrait
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Ẩn status bar và navigation bar để có trải nghiệm fullscreen
  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.edgeToEdge,
    overlays: [SystemUiOverlay.top],
  );

  runApp(const MHZApp());
}

/// Widget gốc của ứng dụng
class MHZApp extends StatelessWidget {
  const MHZApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MHZ Food Detection',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        // Theme cho page transitions mượt mà
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: CupertinoPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
