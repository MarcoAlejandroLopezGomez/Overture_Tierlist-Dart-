import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:photo_view/photo_view.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:html' as html; // Add this import for web

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Robot Tier List',
      theme: ThemeData.dark(),
      home: const TierListPage(),
    );
  }
}

class TierListPage extends StatefulWidget {
  const TierListPage({super.key});

  @override
  TierListPageState createState() => TierListPageState();
}

class TierListPageState extends State<TierListPage> {
  bool crossOutMode = false;
  bool editMode = false;
  List<ImageData> images = [];
  final List<Customer> customers = [
    Customer(name: '1st Pick', items: [], color: Colors.purple),
    Customer(name: '2nd Pick', items: [], color: Colors.yellow),
    Customer(name: '3rd Pick', items: [], color: Colors.green),
    Customer(name: 'Ojito', items: [], color: Colors.blue),
    Customer(name: 'NO', items: [], color: Colors.red),
  ];

  void _viewImage(ImageData image) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PhotoViewPage(image: image),
      ),
    );
  }

  void _editImageText(ImageData image) {
    setState(() {
      editMode = true;
    });
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TextEditorPage(image: image),
      ),
    ).then((_) {
      setState(() {
        editMode = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('OVERTURE PRESENTS ROBOTOS TIER LIST'),
        backgroundColor: const Color.fromARGB(255, 0, 0, 0),
      ),
      body: Column(
        children: [
          buildPickRows(),
          const SizedBox(height: 20),
          buildImageButtons(),
          const SizedBox(height: 20),
          Expanded(child: buildImageContainer()),
        ],
      ),
    );
  }

  Widget buildPickRows() {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6, // Adjust the height as needed
      child: Column(
        children: customers.map((customer) {
          return Expanded(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  color: customer.color,
                  child: Text(
                    customer.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: CustomerCart(
                    customer: customer,
                    highlighted: false,
                    crossOutMode: crossOutMode,
                    editMode: editMode,
                    onImageDropped: (item) {
                      if (!crossOutMode && !editMode) {
                        setState(() {
                          // Remove the image from its current location
                          for (var c in customers) {
                            c.items.remove(item);
                          }
                          if (images.contains(item)) {
                            images.remove(item);
                          }
                          
                          // Add to the new customer
                          customer.items.add(item);
                        });
                      }
                    },
                    onEditImageText: _editImageText,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget buildImage(ImageData imageData, {bool isInRow = false}) {
    return GestureDetector(
      onTap: () {
        setState(() {
          if (crossOutMode) {
            imageData.crossedOut = !imageData.crossedOut;
          } else {
            _viewImage(imageData);
          }
        });
      },
      child: SizedBox(
        width: 100,
        height: 100,
        child: Stack(
          children: [
            Column(
              children: [
                if (imageData.title.isNotEmpty)
                  Text(
                    imageData.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                Expanded(
                  child: Image.memory(
                    imageData.bytes,
                    fit: BoxFit.cover,
                  ),
                ),
              ],
            ),
            if (imageData.crossedOut)
              const Center(
                child: Icon(
                  Icons.clear,
                  color: Colors.red,
                  size: 100, // Make the cross bigger
                ),
              ),
            Positioned(
              bottom: 0,
              right: 0,
              child: IconButton(
                icon: const Icon(Icons.edit, color: Colors.white),
                onPressed: () {
                  _editImageText(imageData);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildDraggableImage(ImageData imageData, {bool isInRow = false}) {
    return (crossOutMode || editMode)
        ? buildImage(imageData, isInRow: isInRow)
        : Draggable<ImageData>(
            data: imageData,
            feedback: Material(
              child: SizedBox(
                width: 100,
                height: 100,
                child: Stack(
                  children: [
                    Column(
                      children: [
                        if (imageData.title.isNotEmpty)
                          Text(
                            imageData.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        Expanded(
                          child: Image.memory(
                            imageData.bytes,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ],
                    ),
                    if (imageData.crossedOut)
                      const Center(
                        child: Icon(
                          Icons.clear,
                          color: Colors.red,
                          size: 100, // Make the cross bigger
                        ),
                      ),
                  ],
                ),
              ),
            ),
            childWhenDragging: Container(), // Display an empty container when dragging
            child: buildImage(imageData, isInRow: isInRow),
            onDraggableCanceled: (velocity, offset) {
              if (crossOutMode || editMode) {
                return;
              }
            },
            ignoringFeedbackSemantics: crossOutMode || editMode,
          );
  }

  Widget buildImageButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.add_photo_alternate, size: 50),
          onPressed: pickImages,
        ),
        IconButton(
          icon: Icon(Icons.clear, size: 50, color: crossOutMode ? Colors.red : Colors.white),
          onPressed: () {
            setState(() {
              crossOutMode = !crossOutMode;
            });
          },
        ),
        IconButton(
          icon: const Icon(Icons.save, size: 50),
          onPressed: saveTierList,
        ),
        IconButton(
        icon: const Icon(Icons.upload_file, size: 50),
        onPressed: uploadTierList,
      ),
      ],
    );
  }

  Widget buildImageContainer() {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemCount: images.length,
      itemBuilder: (context, index) {
        return buildDraggableImage(images[index]);
      },
    );
  }

  Future<void> pickImages() async {
    final pickedFiles = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
    );

    if (pickedFiles != null) {
      setState(() {
        for (final file in pickedFiles.files) {
          final bytes = file.bytes ?? Uint8List(0); // Provide a default value if bytes is null
          final imageData = ImageData(
            DateTime.now().millisecondsSinceEpoch.toString(),
            file.name,
            bytes: bytes,
            crossedOut: false,
            isBase64: false,
          );
          images.add(imageData);
        }
      });
    }
  }

Future<void> saveTierList() async {
  final buffer = StringBuffer();

  for (final customer in customers) {
    buffer.writeln('Tier: ${customer.name}');
    for (final item in customer.items) {
      buffer.writeln('  Image: ${base64Encode(item.bytes)}');
      buffer.writeln('    Title: ${item.title}');
      buffer.writeln('    Text: ${item.text}');
    }
    buffer.writeln();
  }

  if (kIsWeb) {
    // Web-specific code to save the file
    final bytes = utf8.encode(buffer.toString());
    final blob = html.Blob([bytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute("download", "tier_list.txt")
      ..click();
    html.Url.revokeObjectUrl(url);
  } else {
    // Mobile/Desktop-specific code to save the file
    final directory = await getApplicationDocumentsDirectory();
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Please select an output file:',
      fileName: 'tier_list.txt',
      initialDirectory: directory.path,
    );

    if (path != null) {
      final file = File(path);
      await file.writeAsString(buffer.toString());
    }
  }
}

Future<void> uploadTierList() async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['txt'],
  );

  if (result != null && result.files.isNotEmpty) {
    final file = result.files.first;
    final content = utf8.decode(file.bytes!);
    parseTierList(content);
  }
}

void parseTierList(String content) {
  final lines = content.split('\n');
  Customer? currentCustomer;
  images.clear();
  customers.forEach((customer) => customer.items.clear());

  for (final line in lines) {
    if (line.startsWith('Tier: ')) {
      final tierName = line.substring(6);
      currentCustomer = customers.firstWhere((c) => c.name == tierName, orElse: () => Customer(name: tierName, items: [], color: Colors.grey));
    } else if (line.startsWith('  Image: ') && currentCustomer != null) {
      final imageBytes = base64Decode(line.substring(9));
      final titleLine = lines[lines.indexOf(line) + 1];
      final textLine = lines[lines.indexOf(line) + 2];
      final title = titleLine.startsWith('    Title: ') ? titleLine.substring(11) : '';
      final text = textLine.startsWith('    Text: ') ? textLine.substring(10) : '';

      final imageData = ImageData(
        DateTime.now().millisecondsSinceEpoch.toString(),
        '', // src is not needed as we are using bytes
        bytes: imageBytes,
        crossedOut: false,
        isBase64: true,
        title: title,
        text: text,
      );

      currentCustomer.items.add(imageData);
    }
  }

  setState(() {});
}
}

class Customer {
  final String name;
  final List<ImageData> items;
  final Color color;

  Customer({required this.name, required this.items, required this.color});

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'items': items.map((image) => image.id).toList(),
      'color': color.value,
    };
  }
}

class ImageData {
  final String id;
  final String src;
  final Uint8List bytes;
  bool crossedOut;
  bool isBase64;
  String text;
  String title;

  ImageData(
    this.id,
    this.src, {
    required this.crossedOut,
    required this.isBase64,
    required this.bytes,
    this.text = '',
    this.title = '',
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'src': src,
      'crossedOut': crossedOut,
      'isBase64': isBase64,
      'text': text,
      'title': title,
    };
  }
}

class DraggableImage extends StatelessWidget {
  final ImageData imageData;
  final Function(ImageData) onDragComplete;
  final Function(ImageData) onEditImageText;

  const DraggableImage({
    super.key,
    required this.imageData,
    required this.onDragComplete,
    required this.onEditImageText,
  });

  @override
  Widget build(BuildContext context) {
    return Draggable<ImageData>(
      data: imageData,
      feedback: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          image: DecorationImage(
            image: MemoryImage(imageData.bytes),
            fit: BoxFit.cover,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 5,
              spreadRadius: 1,
            ),
          ],
        ),
      ),
      childWhenDragging: Container(
        width: 100,
        height: 100,
        color: Colors.grey.withOpacity(0.5),
      ),
      child: Container(
        width: 100,
        height: 100,
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          image: DecorationImage(
            image: MemoryImage(imageData.bytes),
            fit: BoxFit.cover,
          ),
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: Stack(
          children: [
            Positioned(
              bottom: 0,
              right: 0,
              child: IconButton(
                icon: const Icon(Icons.edit, color: Colors.white),
                onPressed: () {
                  onEditImageText(imageData);
                },
              ),
            ),
          ],
        ),
      ),
      onDragCompleted: () => onDragComplete(imageData),
    );
  }
}

class CustomerCart extends StatelessWidget {
  const CustomerCart({
    super.key,
    required this.customer,
    this.highlighted = false,
    required this.crossOutMode,
    required this.editMode,
    required this.onImageDropped,
    required this.onEditImageText,
  });

  final Customer customer;
  final bool highlighted;
  final bool crossOutMode;
  final bool editMode;
  final Function(ImageData) onImageDropped;
  final Function(ImageData) onEditImageText;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: customer.color.withOpacity(0.3),
        border: Border.all(color: customer.color, width: 2),
      ),
      height: 150, // Adjust height as needed
      child: DragTarget<ImageData>(
        builder: (context, candidateData, rejectedData) {
          return ListView(
            scrollDirection: Axis.horizontal,
            children: [
              ...customer.items.map((item) => buildDraggableImage(item)),
            ],
          );
        },
        onWillAccept: (data) => !crossOutMode && !editMode,
        onAccept: (imageData) {
          if (!crossOutMode && !editMode) {
            onImageDropped(imageData);
          }
        },
      ),
    );
  }

  Widget buildDraggableImage(ImageData imageData) {
    return crossOutMode || editMode
        ? buildImage(imageData)
        : Draggable<ImageData>(
            data: imageData,
            feedback: Material(
              child: SizedBox(
                width: 100,
                height: 100,
                child: Stack(
                  children: [
                    Column(
                      children: [
                        if (imageData.title.isNotEmpty)
                          Text(
                            imageData.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        Expanded(
                          child: Image.memory(
                            imageData.bytes,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ],
                    ),
                    if (imageData.crossedOut)
                      const Center(
                        child: Icon(
                          Icons.clear,
                          color: Colors.red,
                          size: 100, // Make the cross bigger
                        ),
                      ),
                  ],
                ),
              ),
            ),
            childWhenDragging: Container(), // Display an empty container when dragging
            child: buildImage(imageData),
            onDraggableCanceled: (velocity, offset) {
              if (crossOutMode || editMode) {
                return;
              }
            },
            ignoringFeedbackSemantics: crossOutMode || editMode,
          );
  }

  Widget buildImage(ImageData imageData) {
    return GestureDetector(
      onTap: () {
        if (crossOutMode) {
          imageData.crossedOut = !imageData.crossedOut;
        }
      },
      child: SizedBox(
        width: 100,
        height: 100,
        child: Stack(
          children: [
            Column(
              children: [
                if (imageData.title.isNotEmpty)
                  Text(
                    imageData.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                Expanded(
                  child: Image.memory(
                    imageData.bytes,
                    fit: BoxFit.cover,
                  ),
                ),
              ],
            ),
            if (imageData.crossedOut)
              const Center(
                child: Icon(
                  Icons.clear,
                  color: Colors.red,
                  size: 100, // Make the cross bigger
                ),
              ),
            Positioned(
              bottom: 0,
              right: 0,
              child: IconButton(
                icon: const Icon(Icons.edit, color: Colors.white),
                onPressed: () {
                  onEditImageText(imageData);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PhotoViewPage extends StatelessWidget {
  final ImageData image;

  const PhotoViewPage({super.key, required this.image});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(image.src),
      ),
      body: PhotoView(
        imageProvider: MemoryImage(image.bytes),
      ),
    );
  }
}

class TextEditorPage extends StatefulWidget {
  final ImageData image;

  const TextEditorPage({super.key, required this.image});

  @override
  _TextEditorPageState createState() => _TextEditorPageState();
}

class _TextEditorPageState extends State<TextEditorPage> {
  late TextEditingController _titleController;
  late TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.image.title);
    _textController = TextEditingController(text: widget.image.text);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        widget.image.title = _titleController.text;
        widget.image.text = _textController.text;
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('Edit Text for ${widget.image.src}'),
          actions: [
            IconButton(
              icon: Image.memory(widget.image.bytes),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PhotoViewPage(image: widget.image),
                  ),
                );
              },
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  hintText: 'Enter title here...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: TextField(
                  controller: _textController,
                  maxLines: null,
                  decoration: const InputDecoration(
                    hintText: 'Enter text here...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}