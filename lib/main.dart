import 'dart:io' as io;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

late List<CameraDescription> _cameras;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  _cameras = await availableCameras();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late CameraController controller;

  CameraImage? _cameraImage;

  @override
  void initState() {
    super.initState();

    controller = CameraController(_cameras[0], ResolutionPreset.max);
    controller.initialize().then((_) {
      if (!mounted) {
        return;
      }

      controller.startImageStream((image) => _cameraImage = image);

      setState(() {});
    }).catchError((Object e) {
      if (e is CameraException) {
        switch (e.code) {
          case 'CameraAccessDenied':
            print('User denied camera access.');
            break;
          default:
            print('Handle other errors.');
            break;
        }
      }
    });
  }

  @override
  void dispose() {
    controller.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: controller.value.isInitialized
          ? Builder(builder: (context) {
              return Stack(
                children: [
                  Positioned.fill(
                    child: CameraPreview(controller),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: EdgeInsets.all(40),
                        color: Colors.black.withOpacity(0.5),
                        child: Text(
                          "Point your camera at your product to see how to recycle it",
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 25, color: Colors.white),
                        ),
                      ),
                      Spacer(),
                      Container(
                        padding: EdgeInsets.all(40),
                        color: Colors.black.withOpacity(0.5),
                        child: CircleAvatar(
                          backgroundColor: Colors.white,
                          child: IconButton(
                            onPressed: () {
                              _processImage(context);
                            },
                            icon: Icon(
                              Icons.camera_alt,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            })
          : const SizedBox.shrink(),
      // bottomNavigationBar: BottomNavigationBar(
      //   type: BottomNavigationBarType.fixed,
      //   // currentIndex: _currentIndex,
      //   // onTap: _updateIndex,
      //   selectedItemColor: Colors.blue[700],
      //   //selectedFontSize: 13,
      //   //unselectedFontSize: 13,
      //   iconSize: 40,

      //   items: [
      //     BottomNavigationBarItem(
      //       label: "",
      //       icon: Icon(Icons.home),
      //     ),
      //     BottomNavigationBarItem(
      //       label: "",
      //       icon: Icon(Icons.camera_alt),
      //     ),
      //     BottomNavigationBarItem(
      //       label: "",
      //       icon: Icon(Icons.person),
      //     ),
      //   ],
      // ),
    );
  }

  Future<String> _getModel(String assetPath) async {
    if (io.Platform.isAndroid) {
      return 'flutter_assets/$assetPath';
    }
    final path = '${(await getApplicationSupportDirectory()).path}/$assetPath';
    await io.Directory(p.dirname(path)).create(recursive: true);
    final file = io.File(path);
    if (!await file.exists()) {
      final byteData = await rootBundle.load(assetPath);
      await file.writeAsBytes(byteData.buffer
          .asUint8List(byteData.offsetInBytes, byteData.lengthInBytes));
    }
    return file.path;
  }

  void _processImage(BuildContext context) async {
    final WriteBuffer allBytes = WriteBuffer();
    for (final Plane plane in _cameraImage!.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    final Size imageSize =
        Size(_cameraImage!.width.toDouble(), _cameraImage!.height.toDouble());

    final InputImageRotation imageRotation =
        InputImageRotationValue.fromRawValue(
            controller.description.sensorOrientation)!;

    final InputImageFormat inputImageFormat =
        InputImageFormatValue.fromRawValue(_cameraImage!.format.raw)!;

    final planeData = _cameraImage!.planes.map(
      (Plane plane) {
        return InputImagePlaneMetadata(
          bytesPerRow: plane.bytesPerRow,
          height: plane.height,
          width: plane.width,
        );
      },
    ).toList();

    final inputImageData = InputImageData(
      size: imageSize,
      imageRotation: imageRotation,
      inputImageFormat: inputImageFormat,
      planeData: planeData,
    );

    final inputImage =
        InputImage.fromBytes(bytes: bytes, inputImageData: inputImageData);

    final modelPath = await _getModel('assets/ml/model.tflite');
    final options = LocalLabelerOptions(modelPath: modelPath);
    final imageLabeler = ImageLabeler(options: options);
    final List<ImageLabel> labels = await imageLabeler.processImage(inputImage);

    for (ImageLabel label in labels) {
      final String text = label.label;
      final int index = label.index;
      final double confidence = label.confidence;

      print('$text $index $confidence');

      _recognizedProduct(context, text);
    }

    await imageLabeler.close();
  }

  void _recognizedProduct(BuildContext context, String product) async {
    if (product == "retros_sweet_box") {
      _itemRecycalable(context);
    }
    if (product == "quality_street_box") {
      _itemRecycalable(context);
    }
    if (product == "plastic_water_bottle") {
      _itemRecycalable(context);
    }
    if (product == "flipchart_markers_box") {
      _itemRecycalable(context);
    }
    if (product == "cadbury_chocolate_fingers") {
      _itemNotRecycalable(context);
    }
  }

  void _itemRecycalable(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40)),
      builder: (BuildContext context) {
        return const InfoBottomSheetRecyclable();
      },
    );
  }

  void _itemNotRecycalable(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40)),
      builder: (BuildContext context) {
        return const InfoBottomSheetNotRecyclable();
      },
    );
  }
}

class InfoBottomSheetRecyclable extends StatelessWidget {
  const InfoBottomSheetRecyclable({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SizedBox(height: 20),
          Image.asset(
            "assets/check.png",
            width: 80.0,
          ),
          Text(
            'This item is recyclable!',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 25),
          ),
          SizedBox(height: 100),
          Text(
            'Where to recycle?',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(
            'Recycling Center',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 25),
          ),
          SizedBox(height: 50),
          Text(
            'Nearest recycling center:',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(
            'Morse Road, Horsham St Faith, Norwich NR10 3JX',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          SizedBox(height: 100),
        ],
      ),
    );
  }
}

class InfoBottomSheetNotRecyclable extends StatelessWidget {
  const InfoBottomSheetNotRecyclable({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SizedBox(height: 20),
          Icon(
            Icons.close_outlined,
            size: 80,
            color: Colors.red,
          ),
          Text(
            'This item isn\'t recyclable!',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 25),
          ),
          SizedBox(height: 20),
          Text(
            'Please put this item in the general waste to avoid contaminating a recycling batch',
            style: const TextStyle(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 20),
        ],
      ),
    );
  }
}
