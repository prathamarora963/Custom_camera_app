// ignore_for_file: file_names

import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:camera_demo_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:gallery_saver/gallery_saver.dart';
// import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:ui' as ui;
import 'package:video_player/video_player.dart';
import 'package:image_picker/image_picker.dart';
import 'package:open_file/open_file.dart';

class CameraPage extends StatefulWidget {
  const CameraPage({Key? key}) : super(key: key);

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> with WidgetsBindingObserver {
  GlobalKey _globalKey = GlobalKey();
  CameraController? controller;
  bool _isCameraInitialized = false;
  bool _isRecordingInProgress = false;
  bool changingflashtorch = false;
  double _minAvailableZoom = 1.0;
  double _maxAvailableZoom = 1.0;
  double _currentZoomLevel = 1.0;
  double _minAvailableExposureOffset = 0.0;
  double _maxAvailableExposureOffset = 0.0;
  double _currentExposureOffset = 0.0;
  FlashMode? _currentFlashMode;
  bool _isRearCameraSelected = true;
  bool _isVideoCameraSelected = false;
  bool pauseorplaybutton = false;
  bool changepictureandvideo = false;
  late File _videoFile;
  File? imageFile;

  VideoPlayerController? videoController;
  final resolutionPresets = ResolutionPreset.values;
  ResolutionPreset currentResolutionPreset = ResolutionPreset.high;
  void onNewCameraSelected(CameraDescription cameraDescription) async {
    final previousCameraController = controller;
    // Instantiating the camera controller
    final CameraController cameraController = CameraController(
      cameraDescription,
      currentResolutionPreset,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    // Dispose the previous controller
    await previousCameraController?.dispose();

    // Replace with the new controller
    if (mounted) {
      setState(() {
        controller = cameraController;
      });
    }

    // Update UI if controller updated
    cameraController.addListener(() {
      if (mounted) setState(() {});
    });

    // Initialize controller
    try {
      await cameraController.initialize();
    } on CameraException catch (e) {
      print('Error initializing camera: $e');
    }

    // Update the Boolean
    if (mounted) {
      setState(() {
        _isCameraInitialized = controller!.value.isInitialized;
      });
    }
    cameraController
        .getMaxZoomLevel()
        .then((value) => _maxAvailableZoom = value);

    cameraController
        .getMinZoomLevel()
        .then((value) => _minAvailableZoom = value);
    cameraController
        .getMinExposureOffset()
        .then((value) => _minAvailableExposureOffset = value);

    cameraController
        .getMaxExposureOffset()
        .then((value) => _maxAvailableExposureOffset = value);
    _currentFlashMode = controller!.value.flashMode;
  }

  @override
  void initState() {
     SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
      ]);  
    onNewCameraSelected(cameras[0]);
    super.initState();
  }

  @override
  void dispose() {
    controller?.dispose();
    videoController?.dispose();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeRight,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = controller;

    // App state changed before we got the chance to initialize.
    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      // Free up memory when camera not active
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      // Reinitialize the camera with same properties
      onNewCameraSelected(cameraController.description);
    }
  }

  Future<void> _startVideoPlayer() async {
    if (_videoFile != null) {
      videoController = VideoPlayerController.file(_videoFile);
      await videoController!.initialize().then((_) {
        // Ensure the first frame is shown after the video is initialized,
        // even before the play button has been pressed.
        setState(() {});
      });
      await videoController!.setLooping(true);
      await videoController!.play();
    }
  }

  Future<XFile?> takePicture() async {
    final CameraController? cameraController = controller;
    if (cameraController!.value.isTakingPicture) {
      // A capture is already pending, do nothing.
      return null;
    }
    try {
      XFile file = await cameraController.takePicture();
      return file;
    } on CameraException catch (e) {
      print('Error occured while taking picture: $e');
      return null;
    }
  }

  Future<void> startVideoRecording() async {
    final CameraController? cameraController = controller;
    if (controller!.value.isRecordingVideo) {
      // A recording has already started, do nothing.
      return;
    }
    try {
      await cameraController!.startVideoRecording();
      setState(() {
        _isRecordingInProgress = true;
        print(_isRecordingInProgress);
      });
    } on CameraException catch (e) {
      print('Error starting to record video: $e');
    }
  }

  Future<XFile?> stopVideoRecording() async {
    if (!controller!.value.isRecordingVideo) {
      // Recording is already is stopped state
      return null;
    }
    try {
      XFile file = await controller!.stopVideoRecording();
      setState(() {
        _isRecordingInProgress = false;
        print(_isRecordingInProgress);
      });
      return file;
    } on CameraException catch (e) {
      print('Error stopping video recording: $e');
      return null;
    }
  }

  Future<void> pauseVideoRecording() async {
    if (!controller!.value.isRecordingVideo) {
      // Video recording is not in progress
      return;
    }
    try {
      await controller!.pauseVideoRecording();
    } on CameraException catch (e) {
      print('Error pausing video recording: $e');
    }
  }

  Future<void> resumeVideoRecording() async {
    if (!controller!.value.isRecordingVideo) {
      // No video recording was in progress
      return;
    }
    try {
      await controller!.resumeVideoRecording();
    } on CameraException catch (e) {
      print('Error resuming video recording: $e');
    }
  }

  // _saveScreen(path) async {
  //   RenderRepaintBoundary boundary =
  //       _globalKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
  //   ui.Image image = path;
  //   ByteData? byteData =
  //       await (image.toByteData(format: ui.ImageByteFormat.png));
  //   if (byteData != null) {
  //     final result =
  //         await ImageGallerySaver.saveImage(byteData.buffer.asUint8List());
  //     print("result ===> $result");
  //     // _toastInfo(result.toString())
  //   }
  // }
  void onViewFinderTap(TapDownDetails details, BoxConstraints constraints) {
  if (controller == null) {
    return;
  }
  final offset = Offset(
    details.localPosition.dx / constraints.maxWidth,
    details.localPosition.dy / constraints.maxHeight,
  );
  controller!.setExposurePoint(offset);
  controller!.setFocusPoint(offset);
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Column(
              children: [
                _isCameraInitialized
                    ? Container(
                        height: MediaQuery.of(context).size.height * 0.6,
                        child: AspectRatio(
                          aspectRatio: 1 / controller!.value.aspectRatio,
                          child: controller!.buildPreview(),
                        ),
                      )
                    : Container(
                        height: MediaQuery.of(context).size.height * 0.6,
                      ),
                Zoomslider(),
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.01,
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    RotateCamera(),
                    Spacer(),
                    ClickPhotoButton(),
                    Spacer(),
                    ShowImage()
                  ],
                ),
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.02,
                ),
                ImageandVideoButton(),
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.01,
                ),
                FlashLightRow(),
              ],
            ),
            Column(
              children: [Setcameraclearity(), Setcamerbrightness()],
            ),
    
            // Zoomslider()
          ],
        ));
  }

  Widget ImageandVideoButton() {
    return Row(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(
              left: 8.0,
              right: 4.0,
            ),
            child: TextButton(
              onPressed: _isRecordingInProgress
                  ? null
                  : () {
                      if (_isVideoCameraSelected) {
                        setState(() {
                          changepictureandvideo = false;
                          _isVideoCameraSelected = false;
                        });
                      }
                    },
              style: TextButton.styleFrom(
                primary: _isVideoCameraSelected ? Colors.black54 : Colors.black,
                backgroundColor:
                    _isVideoCameraSelected ? Colors.white30 : Colors.white,
              ),
              child: Text('IMAGE'),
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(left: 4.0, right: 8.0),
            child: TextButton(
              onPressed: () {
                if (!_isVideoCameraSelected) {
                  setState(() {
                    changepictureandvideo = true;
                    _isVideoCameraSelected = true;
                  });
                }
              },
              style: TextButton.styleFrom(
                primary: _isVideoCameraSelected ? Colors.black : Colors.black54,
                backgroundColor:
                    _isVideoCameraSelected ? Colors.white : Colors.white30,
              ),
              child: Text('VIDEO'),
            ),
          ),
        ),
      ],
    );
  }

  Widget ClickPhotoButton() {
    return InkWell(
      onTap: _isVideoCameraSelected
          ? () async {
            setState(() {
              pauseorplaybutton = false;
            });
              if (_isRecordingInProgress) {
                XFile? rawVideo = await stopVideoRecording();
                File videoFile = File(rawVideo!.path);

                int currentUnix = DateTime.now().millisecondsSinceEpoch;

                final directory = await getApplicationDocumentsDirectory();
                String fileFormat = videoFile.path.split('.').last;

                _videoFile = await videoFile.copy(
                  '${directory.path}/$currentUnix.$fileFormat',
                );
                GallerySaver.saveVideo(rawVideo.path);

                _startVideoPlayer();
              } else {
                await startVideoRecording();
              }
              // XFile? rawImage = await takePicture();
              // File imageFile = File(rawImage!.path);
              // print("imagefile ====> $imageFile");

              // int currentUnix = DateTime.now().millisecondsSinceEpoch;
              // final directory = (await getApplicationDocumentsDirectory());
              // String fileFormat = imageFile.path.split('.').last;

              // await imageFile.copy(
              //   '${directory.path}/$currentUnix.$fileFormat',
              // );
              // await _saveScreen(imageFile);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Your video is sucessfully saved in Albums')));
            }
          : () async {
              XFile? rawImage = await takePicture();
              imageFile = File(rawImage!.path);
              print("imagefile ====> $imageFile");
              // GallerySaver.saveImage(imageFile.toString());
              int currentUnix = DateTime.now().millisecondsSinceEpoch;
              final directory = (await getApplicationDocumentsDirectory());
              String fileFormat = imageFile!.path.split('.').last;

              await imageFile!.copy(
                '${directory.path}/$currentUnix.$fileFormat',
              );
              GallerySaver.saveImage(rawImage.path);
              // await _saveScreen(imageFile);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Your Photo is sucessfully saved in Albums')));
            },
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(Icons.circle,
              color: _isVideoCameraSelected ? Colors.white : Colors.white38,
              size: 80),
          Icon(Icons.circle,
              color: _isVideoCameraSelected ? Colors.red : Colors.white,
              size: 65),
          _isVideoCameraSelected && _isRecordingInProgress
              ? const Icon(
                  Icons.stop_rounded,
                  color: Colors.white,
                  size: 32,
                )
              : Container(),
        ],
      ),
    );
  }

  Widget ShowImage() {
    //  imageFile;
    return GestureDetector(
      onTap: () {
        showDialog(
            context: context,
            builder: (BuildContext context) {
              return Dialog(
                shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(20.0)), //this right here
                child: Container(
                  width: 60,
                  height: 500,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(10.0),
                    border: Border.all(color: Colors.white, width: 2),
                    image: changepictureandvideo == false
                        ? imageFile != null
                            ? DecorationImage(
                                image: FileImage(imageFile!),
                                fit: BoxFit.cover,
                              )
                            : null
                        : null,
                  ),
                  child: changepictureandvideo == true
                      ? videoController != null &&
                              videoController!.value.isInitialized
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8.0),
                              child: AspectRatio(
                                aspectRatio: videoController!.value.aspectRatio,
                                child: VideoPlayer(videoController!),
                              ),
                            )
                          : Container()
                      : null,
                ),
              );
            });
      },
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(10.0),
          border: Border.all(color: Colors.white, width: 2),
          image: changepictureandvideo == false
              ? imageFile != null
                  ? DecorationImage(
                      image: FileImage(imageFile!),
                      fit: BoxFit.cover,
                    )
                  : null
              : null,
        ),
        child: changepictureandvideo == true
            ? videoController != null && videoController!.value.isInitialized
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8.0),
                    child: AspectRatio(
                      aspectRatio: videoController!.value.aspectRatio,
                      child: VideoPlayer(videoController!),
                    ),
                  )
                : Container()
            : null,
      ),
    );
  }

  void Dialougbox() {}
  Widget RotateCamera() {
    return InkWell(
      onTap: () {
        setState(() {
          _isVideoCameraSelected && _isRecordingInProgress
              ? _isCameraInitialized = true
              : _isCameraInitialized = false;
        });
        _isVideoCameraSelected && _isRecordingInProgress
            ? pauseorplaybutton
                ? resumeVideoRecording()
                : pauseVideoRecording()
            : onNewCameraSelected(
                cameras[_isRearCameraSelected ? 0 : 1],
              );
        setState(() {
          _isRearCameraSelected = !_isRearCameraSelected;
          pauseorplaybutton = !pauseorplaybutton;
        });
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Icon(
            Icons.circle,
            color: Colors.grey,
            size: 60,
          ),
          Icon(
            _isVideoCameraSelected && _isRecordingInProgress
                ? pauseorplaybutton
                    ? Icons.play_arrow
                    : Icons.pause
                : _isRearCameraSelected
                    ? Icons.camera_front
                    : Icons.camera_rear,
            color: Colors.white,
            size: 30,
          ),
        ],
      ),
    );
  }

  Widget FlashLightRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        InkWell(
          onTap: () async {
            setState(() {
              _currentFlashMode = FlashMode.off;
            });
            await controller!.setFlashMode(
              FlashMode.off,
            );
          },
          child: Icon(
            Icons.flash_off,
            color: _currentFlashMode == FlashMode.off
                ? Colors.amber
                : Colors.white,
          ),
        ),
        InkWell(
          onTap: () async {
            setState(() {
              _currentFlashMode = FlashMode.auto;
            });
            await controller!.setFlashMode(
              FlashMode.auto,
            );
          },
          child: Icon(
            Icons.flash_auto,
            color: _currentFlashMode == FlashMode.auto
                ? Colors.amber
                : Colors.white,
          ),
        ),
        // InkWell(
        //   onTap: () async {
        //     // setState(() {
        //     //   _isCameraInitialized = false;
        //     // });
        //     // onNewCameraSelected(
        //     //   cameras[_isRearCameraSelected ? 1 : 0],
        //     // );
        //     setState(() {
        //       _isRearCameraSelected = !_isRearCameraSelected;
        //     });
        //   },
        //   child: Icon(
        //     Icons.flash_on,
        //     color: _currentFlashMode == FlashMode.always
        //         ? Colors.amber
        //         : Colors.white,
        //   ),
        // ),
        InkWell(
          onTap: () async {
            setState(() {
              _currentFlashMode = FlashMode.torch;
              changingflashtorch = !changingflashtorch;
            });
            changingflashtorch == true
                ? await controller!.setFlashMode(
                    FlashMode.torch,
                  )
                : await controller!.setFlashMode(
                    FlashMode.off,
                  );
          },
          child: Icon(
            Icons.highlight,
            color: changingflashtorch == true ? Colors.amber : Colors.white,
          ),
        ),
      ],
    );
  }

  Widget Setcamerbrightness() {
    return Row(
      children: [
        Spacer(),
        Column(
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.01,
            ),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10.0),
              ),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  _currentExposureOffset.toStringAsFixed(1) + 'x',
                  style: TextStyle(color: Colors.black),
                ),
              ),
            ),
            Container(
              height: MediaQuery.of(context).size.height * 0.5,
              child: RotatedBox(
                quarterTurns: 3,
                child: Container(
                  child: Slider(
                    value: _currentExposureOffset,
                    min: _minAvailableExposureOffset,
                    max: _maxAvailableExposureOffset,
                    divisions: 18,
                    activeColor: Colors.white,
                    inactiveColor: Colors.white30,
                    onChanged: (value) async {
                      setState(() {
                        _currentExposureOffset = value;
                      });
                      await controller!.setExposureOffset(value);
                    },
                  ),
                ),
              ),
            )
          ],
        ),
        SizedBox(
          width: MediaQuery.of(context).size.height * 0.02,
        )
      ],
    );
  }

  Widget Zoomslider() {
    return Row(
      children: [
        Expanded(
          child: Slider(
            value: _currentZoomLevel,
            min: _minAvailableZoom,
            max: _maxAvailableZoom,
            activeColor: Colors.white,
            inactiveColor: Colors.white30,
            onChanged: (value) async {
              setState(() {
                _currentZoomLevel = value;
              });
              await controller!.setZoomLevel(value);
            },
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10.0),
          ),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              _currentZoomLevel.toStringAsFixed(1) + 'x',
              style: TextStyle(color: Colors.black),
            ),
          ),
        ),
      ],
    );
  }

  Widget Setcameraclearity() {
    return Column(
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.01,
        ),
        Row(
          children: [
            const Spacer(),

            // ignore: avoid_unnecessary_containers
            Container(
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10), color: Colors.green),
              child: DropdownButton<ResolutionPreset>(
                dropdownColor: Colors.green,
                underline: Container(),
                value: currentResolutionPreset,
                items: [
                  for (ResolutionPreset preset in resolutionPresets)
                    DropdownMenuItem(
                      child: Container(
                        padding: const EdgeInsets.only(left: 10),
                        child: Text(
                          preset.toString().split('.')[1].toUpperCase(),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      value: preset,
                    )
                ],
                onChanged: (value) {
                  setState(() {
                    currentResolutionPreset = value!;
                    _isCameraInitialized = false;
                  });
                  onNewCameraSelected(controller!.description);
                },
                hint: const Text("Select item"),
              ),
            ),
            SizedBox(
              width: MediaQuery.of(context).size.height * 0.02,
            ),
          ],
        ),
      ],
    );
  }
}
