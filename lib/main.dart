import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quick_video_encoder/flutter_quick_video_encoder.dart';
import 'package:gal/gal.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

import 'api_service.dart';

List<CameraDescription> cameras = [];

// Função global para processar a imagem em Isolate (evitar travar a UI)
Future<Uint8List?> _processImageInIsolate(Map<String, dynamic> params) async {
  final String path = params['path'];
  final int targetWidth = params['targetWidth'];
  final int targetHeight = params['targetHeight'];

  final bytes = await File(path).readAsBytes();
  img.Image? decoded = img.decodeImage(bytes);
  if (decoded != null) {
    if (decoded.width != targetWidth || decoded.height != targetHeight) {
      decoded = img.copyResize(
        decoded,
        width: targetWidth,
        height: targetHeight,
      );
    }
    return decoded.getBytes(order: img.ChannelOrder.rgba);
  }
  return null;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    cameras = await availableCameras();
  } catch (e) {
    debugPrint('Erro ao inicializar câmeras: $e');
  }
  runApp(const InkuboTurnApp());
}

class InkuboTurnApp extends StatelessWidget {
  const InkuboTurnApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Inkubo Turn',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF1E1E1E),
        primaryColor: Colors.cyanAccent,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF121212),
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.cyanAccent,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            textStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
      ),
      home: const HomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late ApiService _apiService;
  bool _isBaseOnline = false;
  Timer? _statusTimer;

  int _selectedPhotos = 24;
  final List<int> _photoOptions = [24, 36, 48];

  double _currentSpeed = 5;
  double _currentAngle = 90;

  @override
  void initState() {
    super.initState();
    _apiService = ApiService(baseUrl: 'http://inkuboturn.local');
    _checkStatus();
    _statusTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _checkStatus(),
    );
  }

  Future<void> _checkStatus() async {
    final status = await _apiService.getStatus();
    final isOnline = status != 'error';
    if (_isBaseOnline != isOnline && mounted) {
      setState(() {
        _isBaseOnline = isOnline;
      });
    }
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    super.dispose();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  void _startSequence() {
    if (!_isBaseOnline) {
      _showError("A base não está online.");
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CameraSequenceScreen(
          apiService: _apiService,
          totalPhotos: _selectedPhotos,
          currentSpeed: _currentSpeed.round(),
        ),
      ),
    );
  }

  void _rotateToAngle() {
    int steps = ((_currentAngle * 2048) / 360).round();
    _apiService.move(steps, speed: _currentSpeed.round());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.threed_rotation, color: Colors.cyanAccent),
            const SizedBox(width: 8),
            const Text(
              "Inkubo Turn",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Indicador de Status
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              decoration: BoxDecoration(
                color: const Color(0xFF252525),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isBaseOnline
                          ? Colors.greenAccent
                          : Colors.redAccent,
                      boxShadow: [
                        BoxShadow(
                          color:
                              (_isBaseOnline
                                      ? Colors.greenAccent
                                      : Colors.redAccent)
                                  .withOpacity(0.5),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    "Base Inkubo Turn: ${_isBaseOnline ? 'Online' : 'Offline'}",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _isBaseOnline
                          ? Colors.greenAccent
                          : Colors.redAccent,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Controle Manual
            Card(
              color: const Color(0xFF252525),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Controle Manual",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isBaseOnline
                                ? () => _apiService.startContinuousSpin(
                                    speed: _currentSpeed.round(),
                                  )
                                : null,
                            icon: const Icon(Icons.rotate_right),
                            label: const Text("Giro Contínuo"),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.cyanAccent,
                              side: const BorderSide(color: Colors.cyanAccent),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isBaseOnline
                                ? () => _apiService.stopSpin()
                                : null,
                            icon: const Icon(Icons.stop),
                            label: const Text("Parar"),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.redAccent,
                              side: const BorderSide(color: Colors.redAccent),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      "Velocidade do Motor",
                      style: TextStyle(color: Colors.white70),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.speed, color: Colors.cyanAccent),
                        Expanded(
                          child: Slider(
                            value: _currentSpeed,
                            min: 1,
                            max: 10,
                            divisions: 9,
                            label: _currentSpeed.round().toString(),
                            activeColor: Colors.cyanAccent,
                            inactiveColor: Colors.white24,
                            onChanged: (val) {
                              setState(() {
                                _currentSpeed = val;
                              });
                            },
                            onChangeEnd: (val) {
                              _apiService.setSpeed(val.round());
                            },
                          ),
                        ),
                        Text(
                          _currentSpeed.round().toString(),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Giro Livre por Ângulo
            Card(
              color: const Color(0xFF252525),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Giro por Ângulo",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Slider(
                            value: _currentAngle,
                            min: 0,
                            max: 360,
                            divisions: 360,
                            activeColor: Colors.purpleAccent,
                            inactiveColor: Colors.white24,
                            onChanged: (val) {
                              setState(() {
                                _currentAngle = val;
                              });
                            },
                          ),
                        ),
                        Text(
                          "${_currentAngle.round()}°",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Colors.purpleAccent,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _isBaseOnline ? _rotateToAngle : null,
                        icon: const Icon(Icons.sync),
                        label: const Text("Girar para este Ângulo"),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.purpleAccent,
                          side: const BorderSide(color: Colors.purpleAccent),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Modo Foto Automatizado
            Card(
              color: const Color(0xFF252525),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Modo Foto Automatizado",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int>(
                      value: _selectedPhotos,
                      decoration: InputDecoration(
                        labelText: 'Quantidade de Fotos (Loop 360°)',
                        labelStyle: const TextStyle(color: Colors.cyanAccent),
                        filled: true,
                        fillColor: const Color(0xFF1E1E1E),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      dropdownColor: const Color(0xFF1E1E1E),
                      items: _photoOptions.map((int val) {
                        return DropdownMenuItem<int>(
                          value: val,
                          child: Text(
                            '$val fotos',
                            style: const TextStyle(color: Colors.white),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() {
                          _selectedPhotos = val!;
                        });
                      },
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isBaseOnline ? _startSequence : null,
                        icon: const Icon(Icons.play_circle_fill),
                        label: const Text("Iniciar Sequência de Captura"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.cyanAccent,
                          foregroundColor: Colors.black,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CameraSequenceScreen extends StatefulWidget {
  final ApiService apiService;
  final int totalPhotos;
  final int currentSpeed;

  const CameraSequenceScreen({
    super.key,
    required this.apiService,
    required this.totalPhotos,
    required this.currentSpeed,
  });

  @override
  State<CameraSequenceScreen> createState() => _CameraSequenceScreenState();
}

class _CameraSequenceScreenState extends State<CameraSequenceScreen> {
  CameraController? _cameraController;
  bool _isInit = false;
  bool _isProcessingVideo = false;
  bool _sequenceCompleted = false;
  int _currentPhoto = 0;
  bool _isCancelled = false;

  final List<String> _imagePaths = [];

  @override
  void initState() {
    super.initState();
    _initCameraAndStart();
  }

  Future<void> _initCameraAndStart() async {
    if (cameras.isNotEmpty) {
      final backCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      _cameraController = CameraController(
        backCamera,
        ResolutionPreset.max,
        enableAudio: false,
      );
      try {
        await _cameraController!.initialize();
        if (mounted) {
          setState(() {
            _isInit = true;
          });
          _startLoop();
        }
      } catch (e) {
        debugPrint('Erro no init camera: $e');
        _cancelSequence();
      }
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  void _cancelSequence() {
    _isCancelled = true;
    widget.apiService.stopSpin();
    if (mounted && Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  Future<void> _startLoop() async {
    int stepsPerPhoto = (2048 / widget.totalPhotos).round();

    // Obter diretório temporário para salvar frames
    final directory = await getTemporaryDirectory();
    final String sessionDir =
        '${directory.path}/inkubo_session_${DateTime.now().millisecondsSinceEpoch}';
    await Directory(sessionDir).create(recursive: true);

    for (int i = 1; i <= widget.totalPhotos; i++) {
      if (_isCancelled) return;

      setState(() {
        _currentPhoto = i;
      });

      bool moveSuccess = await widget.apiService.move(
        stepsPerPhoto,
        speed: widget.currentSpeed,
      );
      if (!moveSuccess) {
        _showError("Erro de conexão durante a sequência.");
        _cancelSequence();
        return;
      }

      String status = "moving";
      while (status != "idle" && !_isCancelled) {
        await Future.delayed(const Duration(milliseconds: 200));
        status = await widget.apiService.getStatus();
      }

      if (_isCancelled) return;

      await Future.delayed(const Duration(milliseconds: 500));

      if (_cameraController != null && _cameraController!.value.isInitialized) {
        try {
          final XFile file = await _cameraController!.takePicture();
          // Move o arquivo para a nossa pasta com nome numérico sequencial (necessário pro FFmpeg)
          // Ex: img_001.jpg, img_002.jpg
          final String fileIndex = i.toString().padLeft(3, '0');
          final String newPath = '$sessionDir/img_$fileIndex.jpg';
          await File(file.path).copy(newPath);
          _imagePaths.add(newPath);
        } catch (e) {
          debugPrint("Erro ao capturar foto: $e");
        }
      }
    }

    if (!_isCancelled) {
      // Loop finalizado, agora gerar o vídeo
      setState(() {
        _isProcessingVideo = true;
      });
      await _generateAndSaveVideo(sessionDir);
    }
  }

  Future<void> _generateAndSaveVideo(String sessionDir) async {
    try {
      if (_imagePaths.isEmpty) {
        _showError("Nenhuma foto capturada para gerar o vídeo.");
        _cancelSequence();
        return;
      }

      final directory = await getTemporaryDirectory();
      final String outputPath =
          '${directory.path}/inkubo_turn_video_${DateTime.now().millisecondsSinceEpoch}.mp4';

      // Load first image to determine dimensions
      final firstImageBytes = await File(_imagePaths[0]).readAsBytes();
      final firstImage = img.decodeImage(firstImageBytes);
      if (firstImage == null) {
        _showError("Erro ao ler as imagens.");
        _cancelSequence();
        return;
      }

      // Reduce resolution to max 1080p to avoid OOM and heavy encoding
      int targetWidth = firstImage.width;
      int targetHeight = firstImage.height;
      if (targetWidth > 1920) {
        targetWidth = 1920;
        targetHeight = (firstImage.height * (1920 / firstImage.width)).toInt();
      }
      // Ensure dimensions are even (required by some encoders)
      if (targetWidth % 2 != 0) targetWidth--;
      if (targetHeight % 2 != 0) targetHeight--;

      // Setup encoder (10 FPS video)
      await FlutterQuickVideoEncoder.setup(
        width: targetWidth,
        height: targetHeight,
        fps: 10,
        videoBitrate: 3000000,
        profileLevel: ProfileLevel.any,
        audioChannels: 0,
        audioBitrate: 0,
        sampleRate: 0,
        filepath: outputPath,
      );

      // Process each frame
      for (String path in _imagePaths) {
        final rgbaBytes = await compute(_processImageInIsolate, {
          'path': path,
          'targetWidth': targetWidth,
          'targetHeight': targetHeight,
        });

        if (rgbaBytes != null) {
          await FlutterQuickVideoEncoder.appendVideoFrame(rgbaBytes);
        }
      }

      await FlutterQuickVideoEncoder.finish();

      // Salva na galeria
      await Gal.putVideo(outputPath, album: 'Inkubo Turn');

      setState(() {
        _isProcessingVideo = false;
        _sequenceCompleted = true;
      });
    } catch (e) {
      _showError("Exceção ao gerar vídeo: $e");
      _cancelSequence();
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_sequenceCompleted) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.check_circle,
                color: Colors.greenAccent,
                size: 80,
              ),
              const SizedBox(height: 24),
              const Text(
                "Sequência Concluída!",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "O vídeo 360 foi salvo na Galeria.",
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const SizedBox(height: 48),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text("Voltar para Home"),
              ),
            ],
          ),
        ),
      );
    }

    if (_isProcessingVideo) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              CircularProgressIndicator(color: Colors.cyanAccent),
              SizedBox(height: 24),
              Text(
                "Gerando Vídeo Timelapse...",
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
              SizedBox(height: 8),
              Text(
                "Por favor, aguarde.",
                style: TextStyle(color: Colors.white54),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Câmera Full Screen
            if (_isInit && _cameraController != null)
              SizedBox.expand(child: CameraPreview(_cameraController!))
            else
              const Center(
                child: CircularProgressIndicator(color: Colors.cyanAccent),
              ),
            Positioned(
              bottom: 40,
              left: 24,
              right: 24,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Text(
                      "Foto $_currentPhoto de ${widget.totalPhotos}",
                      style: const TextStyle(
                        color: Colors.cyanAccent,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    LinearProgressIndicator(
                      value: widget.totalPhotos == 0
                          ? 0
                          : _currentPhoto / widget.totalPhotos,
                      backgroundColor: Colors.white24,
                      color: Colors.cyanAccent,
                    ),
                    const SizedBox(height: 24),
                    OutlinedButton.icon(
                      onPressed: _cancelSequence,
                      icon: const Icon(Icons.cancel),
                      label: const Text("Cancelar Sequência"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        side: const BorderSide(color: Colors.redAccent),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
