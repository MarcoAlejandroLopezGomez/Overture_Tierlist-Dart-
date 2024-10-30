import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:photo_view/photo_view.dart';

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
                    onImageDropped: (item) {
                      if (!crossOutMode) {
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
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget buildImage(ImageData imageData) {
    return GestureDetector(
      onTap: () {
        if (crossOutMode) {
          setState(() {
            imageData.crossedOut = !imageData.crossedOut;
          });
        } else {
          _viewImage(imageData);
        }
      },
      child: LongPressDraggable<ImageData>(
        data: imageData,
        feedback: Material(
          child: SizedBox(
            width: 100,
            height: 100,
            child: Stack(
              children: [
                Image.memory(
                  imageData.bytes,
                  fit: BoxFit.cover,
                ),
                if (imageData.crossedOut)
                  const Center(
                    child: Icon(
                      Icons.clear,
                      color: Colors.red,
                      size: 50,
                    ),
                  ),
              ],
            ),
          ),
        ),
        childWhenDragging: Container(), // Display an empty container when dragging
        child: SizedBox(
          width: 100,
          height: 100,
          child: Stack(
            children: [
              Image.memory(
                imageData.bytes,
                fit: BoxFit.cover,
              ),
              if (imageData.crossedOut)
                const Center(
                  child: Icon(
                    Icons.clear,
                    color: Colors.red,
                    size: 50,
                  ),
                ),
            ],
          ),
        ),
        onDraggableCanceled: (velocity, offset) {
          if (crossOutMode) {
            return;
          }
        },
        ignoringFeedbackSemantics: crossOutMode,
      ),
    );
  }

  Widget buildImageButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.upload_file, size: 50),
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
        return buildImage(images[index]);
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
    final jsonImages = images.map((image) => image.toJson()).toList();
    final jsonCustomers = customers.map((customer) => customer.toJson()).toList();

    final tierListJson = {
      'images': jsonImages,
      'customers': jsonCustomers,
    };

    final jsonEncoded = jsonEncode(tierListJson);

    await File('tier_list.json').writeAsString(jsonEncoded);
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

  ImageData(
    this.id,
    this.src, {
    required this.crossedOut,
    required this.isBase64,
    required this.bytes,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'src': src,
      'crossedOut': crossedOut,
      'isBase64': isBase64,
    };
  }
}

class DraggableImage extends StatelessWidget {
  final ImageData imageData;
  final Function(ImageData) onDragComplete;

  const DraggableImage({
    super.key,
    required this.imageData,
    required this.onDragComplete,
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
    required this.onImageDropped,
  });

  final Customer customer;
  final bool highlighted;
  final bool crossOutMode;
  final Function(ImageData) onImageDropped;

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
          return Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                ...customer.items.map((item) => DraggableImage(
                      imageData: item,
                      onDragComplete: (imageData) {
                        // Handle drag completion if needed
                      },
                    )),
              ],
            ),
          );
        },
        onWillAccept: (data) => !crossOutMode,
        onAccept: (imageData) {
          onImageDropped(imageData);
        },
      ),
    );
  }

  Widget buildImage(ImageData imageData) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Image.memory(
        imageData.bytes, // Use the bytes property from ImageData
        fit: BoxFit.cover,
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