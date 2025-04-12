import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:photo_view/photo_view.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:html' as html; // Add this import for web
import 'package:flutter/services.dart'; // Add this import for LogicalKeyboardKey
import 'package:uuid/uuid.dart';
import 'qr_scanner.dart'; // Agregada la importación para Qr Scanner

// New: Global cache service for images and customers
class ImageCacheService {
  static List<ImageData> cachedImages = [];
  static List<Customer> cachedCustomers = [];
}

class TextCacheService {
  static String cachedText = "";
}

class BoldIntent extends Intent {
  const BoldIntent();
}

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
  final TextEditingController _textController = TextEditingController();
  final List<Customer> customers = [
    Customer(name: '1st Pick', items: [], color: Colors.purple),
    Customer(name: '2nd Pick', items: [], color: Colors.yellow),
    Customer(name: '3rd Pick', items: [], color: Colors.green),
    Customer(name: 'Ojito', items: [], color: Colors.blue),
    Customer(name: '-', items: [], color: Colors.red),
    Customer(name: 'Defense Pick', items: [], color: Colors.orange),
  ];

  @override
  void initState() {
    super.initState();
    // Restore cached text and images if available
    _textController.text = TextCacheService.cachedText;
    if (ImageCacheService.cachedImages.isNotEmpty) {
      images = ImageCacheService.cachedImages;
    }
    if (ImageCacheService.cachedCustomers.isNotEmpty) {
      for (var cust in customers) {
        // Find matching customers without using firstWhere with null
        final matchingCustomers = ImageCacheService.cachedCustomers.where((c) => c.name == cust.name);
        if (matchingCustomers.isNotEmpty) {
          final cachedCust = matchingCustomers.first;
          cust.items.clear();
          cust.items.addAll(cachedCust.items);
        }
      }
    }
  }

  void _viewImage(ImageData image) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PhotoViewPage(
          image: image,
          imageList: image.imageList,
        ),
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

  void _deleteImage(ImageData image) {
    setState(() {
      for (var customer in customers) {
        customer.items.remove(image);
      }
      images.remove(image);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('OVERTURE PRESENTS ROBOTOS TIER LIST'),
        backgroundColor: const Color.fromARGB(255, 0, 0, 0),
        actions: [
          TextButton(
            onPressed: () {
              // Save current text and cache images and customer data before navigation
              TextCacheService.cachedText = _textController.text;
              ImageCacheService.cachedImages = images;
              ImageCacheService.cachedCustomers = customers;
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => OverScoutingApp()),
              );
            },
            child: const Text(
              'Qr Scanner',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
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

// Modified buildPickRows for uniform customer header size and alignment:
Widget buildPickRows() {
  return Container(
    height: MediaQuery.of(context).size.height * 0.6, // Fixed overall row height
    child: Column(
      children: customers.map((customer) {
        return Expanded(
          child: Row(
            children: [
              Container(
                width: 120,               // Fixed width so names align
                height: 50,               // Fixed height for uniformity
                alignment: Alignment.center,
                color: customer.color,
                child: Text(
                  customer.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: CustomerCart(
                  customer: customer,
                  highlighted: false,
                  crossOutMode: crossOutMode,
                  editMode: editMode,
                  onImageDropped: (item) {
                    if (!crossOutMode && !editMode) {
                      setState(() {
                        // Remove the image from its current location and add to new customer
                        for (var c in customers) {
                          c.items.remove(item);
                        }
                        if (images.contains(item)) {
                          images.remove(item);
                        }
                        customer.items.add(item);
                      });
                    }
                  },
                  onEditImageText: _editImageText,
                  onDeleteImage: _deleteImage,
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
            Positioned(
              top: 4,
              right: 4,
              child: IconButton(
                icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                onPressed: () {
                  _deleteImage(imageData);
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
          onPressed: uploadTierList, // Ensure this method is correctly referenced
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
          final bytes = file.bytes ?? Uint8List(0);
          final uniqueId = Uuid().v4(); // Generate unique ID
          final imageData = ImageData(
            uniqueId,
            file.name,
            bytes: bytes,
            crossedOut: false,
            isBase64: false,
          );
          imageData.imageList.add(imageData); // Initialize imageList with the main image
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
      buffer.writeln('    Text: ${jsonEncode(item.text)}'); // Save raw text
      buffer.writeln('    DriverSkills: ${item.driverSkills}'); // Add this
      buffer.writeln('    ImageList:');
      for (final subItem in item.imageList) {
        buffer.writeln('      SubImage: ${base64Encode(subItem.bytes)}');
        buffer.writeln('        Title: ${subItem.title}');
        buffer.writeln('        Text: ${jsonEncode(subItem.text)}'); // Save raw text
        buffer.writeln('        DriverSkills: ${subItem.driverSkills}'); // Add this
      }
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
  ImageData? currentImage;
  images.clear();
  customers.forEach((customer) => customer.items.clear());

  for (int i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (line.startsWith('Tier: ')) {
      final tierName = line.substring(6);
      currentCustomer = customers.firstWhere(
        (c) => c.name == tierName,
        orElse: () => Customer(name: tierName, items: [], color: Colors.grey),
      );
    } else if (line.trimLeft().startsWith('Image: ') && currentCustomer != null) {
      final imageBase64 = line.trimLeft().substring(7).trim();
      final imageBytes = base64Decode(imageBase64);
      final titleLine = lines[i + 1];
      final textLine = lines[i + 2];
      final driverSkillsLine = lines[i + 3]; // Add this
      final title = titleLine.trimLeft().startsWith('Title: ') ? titleLine.trimLeft().substring(6) : '';
      final text = textLine.trimLeft().startsWith('Text: ') ? jsonDecode(textLine.trimLeft().substring(5)) as String : '';
      final parsedSkills = driverSkillsLine.trimLeft().startsWith('DriverSkills: ')
          ? double.tryParse(driverSkillsLine.trimLeft().substring(14)) ?? 0.0
          : 0.0;

      final imageData = ImageData(
        DateTime.now().millisecondsSinceEpoch.toString(),
        '',
        bytes: imageBytes,
        crossedOut: false,
        isBase64: true,
        title: title,
        text: text,
      )..driverSkills = parsedSkills; // Add this

      currentCustomer.items.add(imageData);
      currentImage = imageData;
      i += 3; // Skip the next three lines as they have been processed
    } else if (line.trimLeft().startsWith('SubImage: ') && currentImage != null) {
      final subImageBase64 = line.trimLeft().substring(9).trim();
      final subImageBytes = base64Decode(subImageBase64);
      final subTitleLine = lines[i + 1];
      final subTextLine = lines[i + 2];
      final subDriverSkillsLine = lines[i + 3]; // Add this
      final subTitle = subTitleLine.trimLeft().startsWith('Title: ') ? subTitleLine.trimLeft().substring(6) : '';
      final subText = subTextLine.trimLeft().startsWith('Text: ') ? jsonDecode(subTextLine.trimLeft().substring(5)) as String : '';
      final subParsedSkills = subDriverSkillsLine.trimLeft().startsWith('DriverSkills: ')
          ? double.tryParse(subDriverSkillsLine.trimLeft().substring(14)) ?? 0.0
          : 0.0;

      final subImageData = ImageData(
        DateTime.now().millisecondsSinceEpoch.toString(),
        '',
        bytes: subImageBytes,
        crossedOut: false,
        isBase64: true,
        title: subTitle,
        text: subText,
      )..driverSkills = subParsedSkills; // Add this

      currentImage.imageList.add(subImageData);
      i += 3; // Skip the next three lines as they have been processed
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
  List<ImageData> imageList; // Add this line
  double driverSkills = 0.0; // Add this

  ImageData(
    this.id,
    this.src, {
    required this.crossedOut,
    required this.isBase64,
    required this.bytes,
    this.text = '',
    this.title = '',
    List<ImageData>? imageList,
  }) : imageList = imageList ?? []; // Initialize imageList

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

class CustomerCart extends StatefulWidget {  // Change to StatefulWidget
  const CustomerCart({
    super.key,
    required this.customer,
    this.highlighted = false,
    required this.crossOutMode,
    required this.editMode,
    required this.onImageDropped,
    required this.onEditImageText,
    required this.onDeleteImage,
  });

  final Customer customer;
  final bool highlighted;
  final bool crossOutMode;
  final bool editMode;
  final Function(ImageData) onImageDropped;
  final Function(ImageData) onEditImageText;
  final Function(ImageData) onDeleteImage;

  @override
  State<CustomerCart> createState() => _CustomerCartState();
}

class _CustomerCartState extends State<CustomerCart> {
  // Add a scroll controller
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();  // Dispose the controller
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: widget.customer.color.withOpacity(0.3),
        border: Border.all(color: widget.customer.color, width: 2),
      ),
      height: 150, // Adjust height as needed
      child: DragTarget<ImageData>(
        builder: (context, candidateData, rejectedData) {
          return Scrollbar(
            controller: _scrollController,  // Assign controller to Scrollbar
            thumbVisibility: true,
            child: ListView.builder(
              controller: _scrollController,  // Also assign to ListView
              scrollDirection: Axis.horizontal,
              itemCount: widget.customer.items.length + 1,
              itemBuilder: (context, index) {
                if (index == widget.customer.items.length) {
                  return const SizedBox(width: 100);
                }
                return buildDraggableImage(widget.customer.items[index], context, index);
              },
            ),
          );
        },
        onWillAccept: (data) => !widget.crossOutMode && !widget.editMode,
        onAccept: (imageData) {
          if (!widget.crossOutMode && !widget.editMode) {
            widget.onImageDropped(imageData);
          }
        },
      ),
    );
  }

  // Modify the method to use widget. prefix
  Widget buildDraggableImage(ImageData imageData, BuildContext context, int index) {
    return DragTarget<ImageData>(
      builder: (context, candidateData, rejectedData) {
        return widget.crossOutMode || widget.editMode
            ? buildImage(imageData, context)
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
                childWhenDragging: Container(),
                child: buildImage(imageData, context),
                onDraggableCanceled: (velocity, offset) {
                  if (widget.crossOutMode || widget.editMode) {
                    return;
                  }
                },
                ignoringFeedbackSemantics: widget.crossOutMode || widget.editMode,
              );
      },
      onWillAccept: (data) => !widget.crossOutMode && !widget.editMode,
      onAccept: (imageData) {
        if (!widget.crossOutMode && !widget.editMode) {
          widget.customer.items.remove(imageData);
          widget.customer.items.insert(index, imageData);
          (context as Element).markNeedsBuild();
        }
      },
    );
  }

  Widget buildImage(ImageData imageData, BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (widget.crossOutMode) {
          imageData.crossedOut = !imageData.crossedOut;
          (context as Element).markNeedsBuild();
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
                  widget.onEditImageText(imageData);
                },
              ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: IconButton(
                icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                onPressed: () {
                  widget.onDeleteImage(imageData);
                  (context as Element).markNeedsBuild();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PhotoViewPage extends StatefulWidget {
  final ImageData image;
  final List<ImageData> imageList;

  const PhotoViewPage({super.key, required this.image, required this.imageList});

  @override
  _PhotoViewPageState createState() => _PhotoViewPageState();
}

class _PhotoViewPageState extends State<PhotoViewPage> {
  int currentIndex = 0;

  @override
  void initState() {
    super.initState();
    currentIndex = widget.imageList.indexWhere((img) => img.id == widget.image.id);
    if (currentIndex < 0) currentIndex = 0;
  }

  void _addImages() async {
    final pickedFiles = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
    );

    if (pickedFiles != null) {
      setState(() {
        for (final file in pickedFiles.files) {
          final bytes = file.bytes ?? Uint8List(0);
          final uniqueId = Uuid().v4();
          final imageData = ImageData(
            uniqueId,
            file.name,
            bytes: bytes,
            crossedOut: false,
            isBase64: false,
          );
          widget.imageList.add(imageData); // Add to the image's own list
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentImage = widget.imageList[currentIndex];

    return Scaffold(
      appBar: AppBar(
        title: Text(currentImage.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _addImages,
          ),
        ],
      ),
      body: Stack(
        children: [
          PhotoView(
            imageProvider: MemoryImage(currentImage.bytes),
          ),
          Positioned(
            left: 0,
            top: MediaQuery.of(context).size.height / 2 - 24,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, size: 48),
              onPressed: () {
                setState(() {
                  currentIndex = (currentIndex - 1 + widget.imageList.length) % widget.imageList.length;
                });
              },
            ),
          ),
          Positioned(
            right: 0,
            top: MediaQuery.of(context).size.height / 2 - 24,
            child: IconButton(
              icon: const Icon(Icons.arrow_forward, size: 48),
              onPressed: () {
                setState(() {
                  currentIndex = (currentIndex + 1) % widget.imageList.length;
                });
              },
            ),
          ),
        ],
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

// ======================================================================
// Modified _TextEditorPageState to auto-scroll the text cursor as user types
class _TextEditorPageState extends State<TextEditorPage> {
  bool _isBold = false;
  late TextEditingController _titleController;
  late TextEditingController _textController; // Simplified
  late final TextEditingController _driverSkillsController; // Add this
  late final ScrollController _textScrollController; // Scroll controller for text field auto-scroll

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.image.title);
    _textController = TextEditingController(text: widget.image.text);
    _textScrollController = ScrollController(); // Initialize the scroll controller
    // Listener updates the image text and auto-scrolls to show the latest text
    _textController.addListener(() {
      widget.image.text = _textController.text;
      if (_textScrollController.hasClients) {
        _textScrollController.jumpTo(_textScrollController.position.maxScrollExtent);
      }
    });
    _driverSkillsController = TextEditingController(
      text: widget.image.driverSkills.toString(),
    );
    _driverSkillsController.addListener(() {
      final parsed = double.tryParse(_driverSkillsController.text) ?? 0.0;
      if (parsed < 0) {
        widget.image.driverSkills = 0.0;
      } else if (parsed > 10) {
        widget.image.driverSkills = 10.0;
      } else {
        widget.image.driverSkills = parsed;
      }
    });
  }

  @override
  void dispose() {
    // Ensure full text is saved before disposing controllers.
    widget.image.text = _textController.text;
    _titleController.dispose();
    _textController.dispose();
    _driverSkillsController.dispose();
    _textScrollController.dispose(); // Dispose scroll controller to free resources
    super.dispose();
  }

  // New helper method: builds a TextSpan with bold styling for text between '**'
  TextSpan _buildStyledText(String text) {
    final List<TextSpan> spans = [];
    final pattern = RegExp(r'(\*\*)(.*?)\1');
    int lastIndex = 0;
    for (final m in pattern.allMatches(text)) {
      if (m.start > lastIndex) {
        spans.add(TextSpan(text: text.substring(lastIndex, m.start)));
      }
      // Add opening markers
      spans.add(const TextSpan(text: '**'));
      // Add bold text
      spans.add(TextSpan(text: m.group(2), style: const TextStyle(fontWeight: FontWeight.bold)));
      // Add closing markers
      spans.add(const TextSpan(text: '**'));
      lastIndex = m.end;
    }
    if (lastIndex < text.length) {
      spans.add(TextSpan(text: text.substring(lastIndex)));
    }
    return TextSpan(style: const TextStyle(color: Colors.white, fontSize: 16), children: spans);
  }
  
  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      // ...existing code...
      shortcuts: {
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyB): const BoldIntent(),
      },
      child: Actions(
        // ...existing code...
        actions: {
          BoldIntent: CallbackAction<BoldIntent>(
            onInvoke: (BoldIntent intent) {
                            setState(() {
                              _isBold = !_isBold;
                            });
                            return null;
                          },
          ),
        },
        child: Focus(
          autofocus: true,
          child: WillPopScope(
            onWillPop: () async {
              widget.image.title = _titleController.text;
              widget.image.text = _textController.text;
              return true;
            },
            child: Scaffold(
              appBar: AppBar(
                // ...existing code...
                title: Row(
                  children: [
                    Text('Edit Text for ${widget.image.src}'),
                    const SizedBox(width: 8),
                    const Text('Driver Skills'), // New label
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 60,
                      child: TextField(
                        controller: _driverSkillsController, // Use the controller
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'^\d{0,2}(\.\d{0,2})?$')),
                        ],
                        decoration: const InputDecoration(
                          hintText: '0-10',
                        ),
                      ),
                    ),
                  ],
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.photo),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PhotoViewPage(
                            image: widget.image,
                            imageList: widget.image.imageList,
                          ),
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
                      style: TextStyle(
                        fontWeight: _isBold ? FontWeight.bold : FontWeight.normal,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Enter title here...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Replace plain text field with a Stack that overlays styled text
                    Stack(
                      children: [
                        // RichText displays styled text (with markers) in the background
                        Positioned.fill(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(12),
                            child: RichText(
                              text: _buildStyledText(_textController.text),
                            ),
                          ),
                        ),
                        // Editable text field with transparent text so input is preserved
                        TextField(
                          controller: _textController,
                          scrollController: _textScrollController, // Enables auto-scroll based on text length
                          maxLines: null,
                          style: const TextStyle(
                            color: Colors.transparent,
                            // Ensures caret and selection remain visible
                            backgroundColor: Colors.transparent,
                          ),
                          cursorColor: Colors.white,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            hintText: 'Enter text here... use **bold** for bold',
                          ),
                          // Update UI on changes to refresh styling
                          onChanged: (value) {
                            setState(() {});
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}