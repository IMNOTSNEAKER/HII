import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cameras = await availableCameras();
  runApp(MyApp(cameras: cameras));
}

class MyApp extends StatelessWidget {
  final List<CameraDescription> cameras;

  const MyApp({super.key, required this.cameras});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Camera Gallery',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: HomePage(cameras: cameras),
    );
  }
}

class HomePage extends StatefulWidget {
  final List<CameraDescription> cameras;

  const HomePage({super.key, required this.cameras});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  CameraController? _cameraController;
  List<AssetEntity> _mediaFiles = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _loadMediaFiles();
  }

  Future<void> _initializeCamera() async {
    if (widget.cameras.isEmpty) return;
    final camera = widget.cameras.first;
    final controller = CameraController(
      camera,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    await controller.initialize();
    if (!mounted) {
      await controller.dispose();
      return;
    }

    setState(() {
      _cameraController = controller;
    });
  }

  Future<void> _loadMediaFiles() async {
    final permission = await PhotoManager.requestPermissionExtend();
    if (!permission.isAuth && !permission.hasAccess) {
      setState(() => _loading = false);
      return;
    }

    final albums = await PhotoManager.getAssetPathList(
      type: RequestType.common,
      onlyAll: true,
    );

    if (albums.isEmpty) {
      setState(() => _loading = false);
      return;
    }

    final files = await albums.first.getAssetListPaged(page: 0, size: 100);
    if (!mounted) return;

    setState(() {
      _mediaFiles = files;
      _loading = false;
    });
  }

  Future<void> _takePicture() async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;
    if (controller.value.isTakingPicture) return;

    try {
      final file = await controller.takePicture();
      if (!mounted) return;

      // حفظ الصورة في معرض الهاتف مباشرة
      await PhotoManager.editor.saveImageWithPath(file.path);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم التقاط الصورة وحفظها بنجاح!')),
      );

      await _loadMediaFiles();
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ: $error')),
      );
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _cameraController;

    return Scaffold(
      appBar: AppBar(title: const Text('الكاميرا والملفات')),
      body: RefreshIndicator(
        onRefresh: _loadMediaFiles,
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            if (controller != null && controller.value.isInitialized)
              AspectRatio(
                aspectRatio: controller.value.aspectRatio,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: CameraPreview(controller),
                ),
              )
            else
              Container(
                height: 220,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text('جاري تشغيل الكاميرا...'),
              ),
            const SizedBox(height: 12),
            SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _takePicture,
                icon: const Icon(Icons.camera),
                label: const Text('التقاط صورة'),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'الصور في المعرض:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            _loading
                ? const Center(child: CircularProgressIndicator())
                : _mediaFiles.isEmpty
                    ? const Text('لا توجد صور')
                    : GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 4,
                          mainAxisSpacing: 4,
                        ),
                        itemCount: _mediaFiles.length,
                        itemBuilder: (context, index) {
                          return FutureBuilder(
                            future: _mediaFiles[index].thumbnailData,
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.done &&
                                  snapshot.data != null) {
                                return Image.memory(
                                  snapshot.data!,
                                  fit: BoxFit.cover,
                                );
                              }
                              return Container(color: Colors.grey[200]);
                            },
                          );
                        },
                      ),
          ],
        ),
      ),
    );
  }
}
