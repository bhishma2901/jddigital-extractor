import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:easyocr/easyocr.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive_io.dart';
import 'package:expandable/expandable.dart';
import 'package:csv/csv.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'JD Digital Extractor',
      home: HomeScreen(),
    );
  }
}

enum ExtractionType {
  all,
  textOnly,
  numbersOnly,
  sevenPlusDigits,
}

class HomeScreen extends StatefulWidget {
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<File> images = [];
  File? croppedImage;
  Rect? cropRect;
  ExtractionType? extractionType = ExtractionType.all;
  List<List<String>> extractedData = [];
  String outputPath = '';
  String outputFileName = 'output.csv';

  Future<void> pickFiles() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'zip'],
    );
    if (result != null) {
      images.clear();
      for (var file in result.files) {
        if (file.extension == 'zip') {
          await _extractZip(file.path!);
        } else {
          images.add(File(file.path!));
        }
      }
      setState(() {});
    }
  }

  Future<void> _extractZip(String zipPath) async {
    final bytes = File(zipPath).readAsBytesSync();
    final archive = ZipDecoder().decodeBytes(bytes);
    final tempDir = await getTemporaryDirectory();
    for (final file in archive) {
      if (file.isFile && (file.name.endsWith('.jpg') || file.name.endsWith('.png'))) {
        final outFile = File('${tempDir.path}/${file.name}');
        await outFile.writeAsBytes(file.content as List<int>);
        images.add(outFile);
      }
    }
  }

  Future<void> cropFirstImage() async {
    if (images.isEmpty) return;
    CroppedFile? cropped = await ImageCropper().cropImage(
      sourcePath: images.first.path,
      aspectRatioPresets: [CropAspectRatioPreset.original],
      uiSettings: [AndroidUiSettings(lockAspectRatio: false)],
    );
    if (cropped != null) {
      croppedImage = File(cropped.path);
      // You may need to store cropRect if you want to apply the same crop to all images
      setState(() {});
    }
  }

  Future<void> applyCropToAll() async {
    // For simplicity, just use the cropped image for all, or implement custom logic to crop all images with same rect
    // This is a placeholder
    // In production, you would use a package like image/image.dart to crop all images with the same rect
  }

  Future<void> extractText() async {
    extractedData.clear();
    for (var img in images) {
      String text = '';
      if (extractionType == ExtractionType.all || extractionType == ExtractionType.textOnly) {
        // Use EasyOCR or Google ML Kit
        final inputImage = InputImage.fromFile(img);
        final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
        final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
        text = recognizedText.text;
      }
      // Filter text based on extractionType
      String filtered = _filterText(text, extractionType!);
      extractedData.add([img.path.split('/').last, filtered]);
    }
    // Sort by file name
    extractedData.sort((a, b) => a[0].compareTo(b[0]));
    setState(() {});
  }

  String _filterText(String text, ExtractionType type) {
    switch (type) {
      case ExtractionType.all:
        return text;
      case ExtractionType.textOnly:
        return text.replaceAll(RegExp(r'[0-9]'), '');
      case ExtractionType.numbersOnly:
        return RegExp(r'\\d+').allMatches(text).map((e) => e.group(0)).join(' ');
      case ExtractionType.sevenPlusDigits:
        return RegExp(r'\\d{7,}').allMatches(text).map((e) => e.group(0)).join(' ');
      default:
        return text;
    }
  }

  Future<void> saveOutput() async {
    String csv = const ListToCsvConverter().convert(extractedData);
    final dir = await getExternalStorageDirectory();
    final file = File('${dir!.path}/$outputFileName');
    await file.writeAsString(csv);
    setState(() {
      outputPath = file.path;
    });
  }

  Future<void> fixTxtFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['txt']);
    if (result != null) {
      final file = File(result.files.single.path!);
      final content = await file.readAsString();
      final matches = RegExp(r'\\d{7,}').allMatches(content).map((e) => e.group(0)).join('\n');
      final dir = await getExternalStorageDirectory();
      final outFile = File('${dir!.path}/fixed_numbers.txt');
      await outFile.writeAsString(matches);
      setState(() {
        outputPath = outFile.path;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('JD Digital Extractor')),
      body: SingleChildScrollView(
        child: Column(
          children: [
            ElevatedButton(onPressed: pickFiles, child: Text('Upload Images/Zip')),
            if (images.isNotEmpty)
              Column(
                children: [
                  Image.file(images.first, height: 200),
                  ElevatedButton(onPressed: cropFirstImage, child: Text('Crop First Image')),
                  ElevatedButton(onPressed: applyCropToAll, child: Text('Apply Crop to All Images')),
                ],
              ),
            ExpandablePanel(
              header: Text('Extraction Type'),
              collapsed: Text('Select extraction type'),
              expanded: Column(
                children: [
                  ListTile(
                    title: Text('Extract all text in images'),
                    leading: Radio(
                      value: ExtractionType.all,
                      groupValue: extractionType,
                      onChanged: (val) => setState(() => extractionType = val as ExtractionType),
                    ),
                  ),
                  ListTile(
                    title: Text('Only text extract'),
                    leading: Radio(
                      value: ExtractionType.textOnly,
                      groupValue: extractionType,
                      onChanged: (val) => setState(() => extractionType = val as ExtractionType),
                    ),
                  ),
                  ListTile(
                    title: Text('Only numbers'),
                    leading: Radio(
                      value: ExtractionType.numbersOnly,
                      groupValue: extractionType,
                      onChanged: (val) => setState(() => extractionType = val as ExtractionType),
                    ),
                  ),
                  ListTile(
                    title: Text('7+ digit numbers extract'),
                    leading: Radio(
                      value: ExtractionType.sevenPlusDigits,
                      groupValue: extractionType,
                      onChanged: (val) => setState(() => extractionType = val as ExtractionType),
                    ),
                  ),
                ],
              ),
            ),
            ElevatedButton(onPressed: extractText, child: Text('Extract Text')),
            ElevatedButton(onPressed: saveOutput, child: Text('Save Output')),
            if (outputPath.isNotEmpty) Text('Output saved at: $outputPath'),
            Divider(),
            Text('Fix TXT File:'),
            ElevatedButton(onPressed: fixTxtFile, child: Text('Upload TXT and Extract 7+ Digit Numbers')),
          ],
        ),
      ),
    );
  }
}
