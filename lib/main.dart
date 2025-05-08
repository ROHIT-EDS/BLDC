import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/home_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isDarkMode = false;

  void _toggleTheme() {
    setState(() {
      _isDarkMode = !_isDarkMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'BLDC Fan',
      theme: ThemeData(
        colorScheme: ColorScheme.light(
          primary: Colors.blue,
          secondary: Colors.purple,
          surface: Colors.white,
          onSurface: Colors.black,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.dark(
          primary: Colors.orange,
          secondary: Colors.orange.shade300,
          surface: Colors.black,
          onSurface: Colors.white,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      home: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle(
          systemNavigationBarColor: _isDarkMode ? Colors.black : Colors.white,
          systemNavigationBarIconBrightness:
              _isDarkMode ? Brightness.light : Brightness.dark,
        ),
        child: MyHomePage(
          title: 'BLDC Fan',
          toggleTheme: _toggleTheme,
          isDarkMode: _isDarkMode,
        ),
      ),
    );
  }
}
