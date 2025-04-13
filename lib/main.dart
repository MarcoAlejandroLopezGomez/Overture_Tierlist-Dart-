import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
// Correct import for PhotoViewGallery
import 'package:photo_view/photo_view_gallery.dart';
// Import for base PhotoView if needed elsewhere, but Gallery is key here
import 'package:photo_view/photo_view.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart'; // Import foundation for listEquals and kIsWeb
import 'dart:html' as html; // Add this import for web
import 'package:flutter/services.dart'; // Add this import for LogicalKeyboardKey
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as p; // Import the path package
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

// New: Class to hold results from PhotoViewPage
class PhotoViewResult {
  final String? deletedSubImageId;
  // MODIFIED: Use a boolean flag instead of the list
  final bool imagesAdded;

  PhotoViewResult({this.deletedSubImageId, this.imagesAdded = false});

  @override
  String toString() {
    // MODIFIED: Update toString
    return 'PhotoViewResult(deletedSubImageId: $deletedSubImageId, imagesAdded: $imagesAdded)';
  }
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
  // REMOVED: bool editMode = false;
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
     // Ensure all imageList are initialized
    for (var img in images) {
      img.imageList ??= [img];
    }
    for (var cust in customers) {
      for (var img in cust.items) {
        img.imageList ??= [img];
      }
    }
  }

  // --- MODIFIED: Use async/await and handle PhotoViewResult ---
  void _viewImage(ImageData image) async {
    // Ensure the list is initialized before navigating
    image.imageList ??= [image];

    print("Preparing to navigate to PhotoViewPage for image ID: ${image.id}");

    // Pass the actual list reference from the image data
    final List<ImageData> listToSend = image.imageList!;

    final result = await Navigator.push<PhotoViewResult?>( // Expect PhotoViewResult
      context,
      MaterialPageRoute(
        builder: (context) => PhotoViewPage(
          image: image,
          imageList: listToSend,
        ),
      ),
    );

    print("Returned from PhotoViewPage. Result: $result");
    if (result != null && mounted) {
      if (result.deletedSubImageId != null) {
        // Handle deletion
        _handleSubImageDeletionById(image, result.deletedSubImageId!);
      // MODIFIED: Check imagesAdded flag
      } else if (result.imagesAdded) {
         // Just refresh state, PhotoViewPage modified the list directly
        setState(() {
           print("Refreshing TierListPage state after PhotoViewPage reported image additions.");
           // Optional: Verify list length change here if needed for debugging
           // print("Main image ${image.id} list length is now: ${image.imageList?.length}");
        });
      } else {
        // Refresh state even if nothing changed explicitly (e.g., internal state change)
        setState(() {
           print("Refreshing TierListPage state after PhotoViewPage closed (no explicit add/delete returned).");
        });
      }
    } else if (mounted) {
      // Refresh state if result was null (e.g., system back button without changes)
      setState(() {
         print("Refreshing TierListPage state after PhotoViewPage closed (null result).");
      });
    }
  }

  // REMOVED: _handleSubImageAddition method


  // --- REFINED: Handler using ID, more robust search ---
  void _handleSubImageDeletionById(ImageData mainImage, String deletedSubImageId) {
    print("_handleSubImageDeletionById CALLED with main: ${mainImage.id}, deleted ID: $deletedSubImageId");
    if (!mounted) {
      print("_handleSubImageDeletionById: Exiting because widget is not mounted.");
      return;
    }

    bool foundAndRemoved = false;
    bool triedToRemove = false; // Track if we found the sub-image
    String? listSource; // Track where the image was found

    // Function to perform the removal and update state
    void performRemoval(List<ImageData> sourceList, int mainIndex, String sourceName) {
        // Access the actual image data object from the state list
        ImageData targetMainImage = sourceList[mainIndex];
        targetMainImage.imageList ??= [targetMainImage]; // Ensure list exists

        List<ImageData> targetImageList = targetMainImage.imageList!;

        int subImageIndex = targetImageList.indexWhere((sub) => sub.id == deletedSubImageId);

        if (subImageIndex != -1) {
            triedToRemove = true; // We found the sub-image
            print("Found sub-image by ID in '$sourceName[${mainIndex}].imageList' at index $subImageIndex.");
            if (targetImageList.length > 1) {
                print("Attempting removal from '$sourceName' list...");
                setState(() {
                    targetImageList.removeAt(subImageIndex);
                    print("Removed sub-image. New list length: ${targetImageList.length}");
                    foundAndRemoved = true;
                    listSource = sourceName;
                });
            } else {
                print("Cannot delete last sub-image from '$sourceName' list.");
                if (mounted) {
                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Cannot delete the only remaining image.")));
                }
                // Mark as found but not removed to prevent further searching
                listSource = '$sourceName (last image)';
            }
        } else {
            print("Sub-image ID ${deletedSubImageId} NOT found in '$sourceName[${mainIndex}].imageList'.");
        }
    }

    // Check Unassigned Images
    int mainImageIndexUnassigned = images.indexWhere((img) => img.id == mainImage.id);
    if (mainImageIndexUnassigned != -1) {
        performRemoval(images, mainImageIndexUnassigned, 'images');
    }

    // Check Customer Lists (only if not found/processed yet)
    if (listSource == null) { // listSource is set if found (even if not removed)
        for (var customer in customers) {
            int mainImageIndexCustomer = customer.items.indexWhere((img) => img.id == mainImage.id);
            if (mainImageIndexCustomer != -1) {
                performRemoval(customer.items, mainImageIndexCustomer, 'customer ${customer.name}');
                if (listSource != null) break; // Exit loop if found/processed
            }
        }
    }

    // Final Status
    if (listSource != null) {
       print("Sub-image deletion process completed. Source: $listSource. Removed: $foundAndRemoved");
    } else if (mounted) {
       print("Warning: Main image ${mainImage.id} not found in any list for sub-image deletion.");
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Could not find the main image to modify.")));
    } else if (!triedToRemove && mounted) {
        // This case should ideally not happen if the main image was found, but indicates the sub-image ID wasn't in the list
        print("Warning: Sub-image with ID $deletedSubImageId was NOT found in the expected list(s).");
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Could not find the sub-image to delete.")));
    }
  }


  void _editImageText(ImageData image) {
    // Ensure imageList is initialized before editing
    image.imageList ??= [image];
    // REMOVED: setState(() { editMode = true; });
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TextEditorPage(image: image),
      ),
    ).then((_) {
      // Refresh state after editing text/title/skills
      setState(() {
         // REMOVED: editMode = false;
         print("Returned from TextEditorPage, refreshing state.");
      });
    });
  }

  void _deleteImage(ImageData image) {
    setState(() {
      // Remove from customer lists
      for (var customer in customers) {
        customer.items.removeWhere((item) => item.id == image.id);
        // Also check sub-image lists within this customer if necessary, though less likely
      }
      // Remove from unassigned list
      images.removeWhere((item) => item.id == image.id);
    });
     print("Deleted main image ${image.id}");
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
    // Consider using LayoutBuilder or Flexible/Expanded for better height management
    height: MediaQuery.of(context).size.height * 0.6, // Fixed overall row height
    child: Column(
      children: customers.map((customer) {
        return Expanded(
          child: Row(
            children: [
              Container(
                width: 120,               // Fixed width so names align
                // Consider removing fixed height or making it smaller if rows overflow
                // height: 50,
                alignment: Alignment.center,
                color: customer.color,
                padding: const EdgeInsets.symmetric(horizontal: 4.0), // Add padding
                child: Text(
                  customer.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center, // Center text
                  overflow: TextOverflow.ellipsis, // Handle long names
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: CustomerCart(
                  customer: customer,
                  highlighted: false, // This seems unused, consider removing
                  crossOutMode: crossOutMode,
                  // MODIFIED: Change callback to onImageDroppedAt
                  onImageDroppedAt: (item, index) {
                    if (!crossOutMode) { // Check only crossOutMode
                      setState(() {
                        // Remove the image from its current location
                        bool removed = images.remove(item);
                        if (!removed) {
                          for (var c in customers) {
                            if (c.items.remove(item)) {
                               removed = true;
                               break;
                            }
                          }
                        }
                        // Add to new customer at the specified index if removed
                        if (removed) {
                           // Clamp index to be safe
                           final insertIndex = index.clamp(0, customer.items.length);
                           print("Inserting item ${item.id} into ${customer.name} at index $insertIndex (original index: $index)");
                           customer.items.insert(insertIndex, item);
                        } else {
                           print("Warning: Dropped item ${item.id} not found in any list.");
                        }
                      });
                    }
                  },
                  onEditImageText: _editImageText,
                  onDeleteImage: _deleteImage, // Pass the main delete function
                  onViewImage: _viewImage,
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
    // Ensure imageList is initialized
    imageData.imageList ??= [imageData];

    return GestureDetector(
      onTap: () {
        if (crossOutMode) {
          setState(() {
            imageData.crossedOut = !imageData.crossedOut;
          });
        // REMOVED: } else if (!editMode) { // Only allow viewing if not in edit mode
        } else { // Allow viewing if not in crossOutMode
          _viewImage(imageData);
        }
      },
      child: SizedBox(
        width: 100,
        height: 100,
        child: Stack(
          fit: StackFit.expand, // Make stack fill SizedBox
          children: [
            // Background Image
            Image.memory(
              imageData.bytes,
              fit: BoxFit.cover,
              // Add semantic label for accessibility
              semanticLabel: imageData.title.isNotEmpty ? imageData.title : 'Tier list image',
            ),
            // Title Overlay (optional, consider if it obscures image too much)
            if (imageData.title.isNotEmpty)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  color: Colors.black.withOpacity(0.5),
                  padding: const EdgeInsets.symmetric(horizontal: 2.0, vertical: 1.0),
                  child: Text(
                    imageData.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10, // Smaller font size for title overlay
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            // Cross-out Overlay
            if (imageData.crossedOut)
              Container(
                 color: Colors.black.withOpacity(0.4), // Dim background slightly
                 child: const Center(
                   child: Icon(
                     Icons.clear,
                     color: Colors.red,
                     size: 80, // Adjust size
                   ),
                 ),
              ),
            // Edit Button
            Positioned(
              bottom: 0,
              right: 0,
              child: Container( // Add background for better visibility
                 color: Colors.black.withOpacity(0.5),
                 child: IconButton(
                   icon: const Icon(Icons.edit, color: Colors.white, size: 20),
                   tooltip: "Edit Text/Skills",
                   onPressed: () {
                     _editImageText(imageData);
                   },
                   padding: EdgeInsets.zero, // Reduce padding
                   constraints: const BoxConstraints(), // Reduce constraints
                 ),
              ),
            ),
            // Delete Button (for main image list only, handled differently in CustomerCart)
            if (!isInRow) // Only show delete on main list images
              Positioned(
                top: 0,
                right: 0,
                child: Container( // Add background for better visibility
                   color: Colors.black.withOpacity(0.5),
                   child: IconButton(
                     icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                     tooltip: "Delete Image",
                     onPressed: () {
                       _deleteImage(imageData); // Call main delete function
                     },
                     padding: EdgeInsets.zero, // Reduce padding
                     constraints: const BoxConstraints(), // Reduce constraints
                   ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget buildDraggableImage(ImageData imageData, {bool isInRow = false}) {
    // Ensure imageList is initialized
    imageData.imageList ??= [imageData];

    Widget imageWidget = buildImage(imageData, isInRow: isInRow);

    // Only allow dragging if not in crossOut mode
    // REMOVED: if (crossOutMode || editMode) {
    if (crossOutMode) {
      return imageWidget;
    } else {
      return Draggable<ImageData>(
        data: imageData,
        feedback: Material( // Wrap feedback in Material for text style consistency
          color: Colors.transparent, // Make Material transparent
          child: SizedBox(
            width: 100,
            height: 100,
            child: Opacity( // Make feedback slightly transparent
               opacity: 0.7,
               child: buildImage(imageData, isInRow: isInRow), // Reuse buildImage for feedback
            ),
          ),
        ),
        childWhenDragging: SizedBox( // Show a placeholder when dragging
           width: 100,
           height: 100,
           child: Container(
              color: Colors.grey.withOpacity(0.3),
              margin: const EdgeInsets.all(4), // Match margin if buildImage has it
           ),
        ),
        child: imageWidget, // The actual widget displayed
      );
    }
  }

  Widget buildImageButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly, // Better spacing
      children: [
        IconButton(
          icon: const Icon(Icons.add_photo_alternate),
          iconSize: 40, // Slightly smaller icons
          tooltip: "Add Images",
          onPressed: pickImages,
        ),
        IconButton(
          icon: Icon(Icons.clear, color: crossOutMode ? Colors.red : Colors.white),
          iconSize: 40,
          tooltip: crossOutMode ? "Disable Cross-out Mode" : "Enable Cross-out Mode",
          onPressed: () {
            setState(() {
              crossOutMode = !crossOutMode;
              // REMOVED: if (crossOutMode) editMode = false; // Turn off edit mode if cross-out is enabled
            });
          },
        ),
         // REMOVED: IconButton for Edit Mode Toggle
        IconButton(
          icon: const Icon(Icons.save),
          iconSize: 40,
          tooltip: "Save Tier List",
          onPressed: saveTierList,
        ),
        IconButton(
          icon: const Icon(Icons.upload_file),
          iconSize: 40,
          tooltip: "Load Tier List",
          onPressed: uploadTierList,
        ),
      ],
    );
  }

  Widget buildImageContainer() {
    // Use LayoutBuilder to determine crossAxisCount dynamically or ensure enough space
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate crossAxisCount based on width, ensuring minimum size
        int crossAxisCount = (constraints.maxWidth / 110).floor(); // Approx 100 width + spacing
        if (crossAxisCount < 1) crossAxisCount = 1; // Ensure at least 1 column

        return GridView.builder(
          padding: const EdgeInsets.all(8.0), // Add padding around the grid
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 8, // Increased spacing
            mainAxisSpacing: 8,  // Increased spacing
            childAspectRatio: 1.0, // Ensure items are square
          ),
          itemCount: images.length,
          itemBuilder: (context, index) {
            // Pass isInRow: false for images in the main container
            return buildDraggableImage(images[index], isInRow: false);
          },
        );
      }
    );
  }

  Future<void> pickImages() async {
    final pickedFiles = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
      withData: true,
      withReadStream: false,
    );

    if (pickedFiles != null && pickedFiles.files.isNotEmpty) {
      setState(() {
        for (final file in pickedFiles.files) {
          if (file.bytes == null) {
            print("Warning: Could not read bytes for file ${file.name}");
            continue;
          }
          final bytes = file.bytes!;
          final uniqueId = const Uuid().v4();
          String imageTitle = file.name.split('.').first; // Default title

          if (!kIsWeb && file.path != null && file.path!.isNotEmpty) {
            try {
              String directoryPath = p.dirname(file.path!);
              imageTitle = p.basename(directoryPath);
            } catch (e) {
              print("Error extracting folder name from path '${file.path}': $e");
            }
          }

          final imageData = ImageData(
            uniqueId,
            file.name,
            bytes: bytes,
            crossedOut: false,
            isBase64: false,
            title: imageTitle,
            imageList: [], // Initialize with empty list
          );
          imageData.imageList = [imageData]; // Add self to the list
          images.add(imageData);
        }
      });
    } else {
      print("No images selected.");
    }
  }

  Future<void> saveTierList() async {
    final buffer = StringBuffer();

    // Save Tiers
    for (final customer in customers) {
      buffer.writeln('Tier: ${customer.name}');
      for (final item in customer.items) {
        item.imageList ??= [item]; // Ensure list exists
        String base64Image;
        try { base64Image = base64Encode(item.bytes); } catch (e) { base64Image = ""; print("Error encoding image ${item.id}: $e"); }
        buffer.writeln('  Image: $base64Image');
        buffer.writeln('    Title: ${item.title}');
        buffer.writeln('    Text: ${jsonEncode(item.text)}');
        buffer.writeln('    DriverSkills: ${item.driverSkills}');
        buffer.writeln('    ImageList:');
        for (final subItem in item.imageList ?? []) { // Iterate over empty list if null
           String base64SubImage;
           try { base64SubImage = base64Encode(subItem.bytes); } catch (e) { base64SubImage = ""; print("Error encoding sub-image ${subItem.id}: $e"); }
           buffer.writeln('      SubImage: $base64SubImage');
           buffer.writeln('        Title: ${subItem.title}');
           buffer.writeln('        Text: ${jsonEncode(subItem.text)}');
           buffer.writeln('        DriverSkills: ${subItem.driverSkills}');
        }
      }
      buffer.writeln();
    }

    // Save Unassigned Images
    buffer.writeln('Tier: Unassigned');
    for (final item in images) {
       item.imageList ??= [item]; // Ensure list exists
       String base64Image;
       try { base64Image = base64Encode(item.bytes); } catch (e) { base64Image = ""; print("Error encoding unassigned image ${item.id}: $e"); }
       buffer.writeln('  Image: $base64Image');
       buffer.writeln('    Title: ${item.title}');
        buffer.writeln('    Text: ${jsonEncode(item.text)}');
        buffer.writeln('    DriverSkills: ${item.driverSkills}');
        buffer.writeln('    ImageList:');
       for (final subItem in item.imageList ?? []) { // Iterate over empty list if null
          String base64SubImage;
          try { base64SubImage = base64Encode(subItem.bytes); } catch (e) { base64SubImage = ""; print("Error encoding unassigned sub-image ${subItem.id}: $e"); }
          buffer.writeln('      SubImage: $base64SubImage');
          buffer.writeln('        Title: ${subItem.title}');
          buffer.writeln('        Text: ${jsonEncode(subItem.text)}');
          buffer.writeln('        DriverSkills: ${subItem.driverSkills}');
       }
    }
    buffer.writeln();

    // File Saving Logic (Web and Desktop/Mobile)
    if (kIsWeb) {
      try {
        final bytes = utf8.encode(buffer.toString());
        final blob = html.Blob([bytes], 'text/plain;charset=utf-8');
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..setAttribute("download", "tier_list.txt")
          ..click();
        html.Url.revokeObjectUrl(url);
        print("Tier list saved (web download initiated).");
      } catch (e) { print("Error saving tier list on web: $e"); }
    } else {
      try {
        final directory = await getApplicationDocumentsDirectory();
        final String? path = await FilePicker.platform.saveFile(
          dialogTitle: 'Save Tier List As:',
          fileName: 'tier_list.txt',
          initialDirectory: directory.path,
          lockParentWindow: true,
        );
        if (path != null) {
          final file = File(path);
          await file.writeAsString(buffer.toString());
          print("Tier list saved to: $path");
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Tier list saved to $path')));
        } else { print("Tier list save cancelled by user."); }
      } catch (e) {
        print("Error saving tier list on desktop/mobile: $e");
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving tier list: $e')));
      }
    }
  }

  Future<void> uploadTierList() async {
    FilePickerResult? result;
    try {
       result = await FilePicker.platform.pickFiles(
        type: FileType.custom, allowedExtensions: ['txt'], withData: true,
      );
    } catch (e) { print("Error picking file: $e"); if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error picking file: $e'))); return; }

    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;
      if (file.bytes != null) {
        try {
          final content = utf8.decode(file.bytes!);
          parseTierList(content);
          print("Tier list uploaded and parsed successfully.");
           if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tier list loaded successfully!')));
        } catch (e) { print("Error decoding or parsing tier list file: $e"); if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error reading file: $e'))); }
      } else { print("Error: Could not read bytes from the selected file."); if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error: Could not read the selected file.'))); }
    } else { print("No file selected for upload."); }
  }

  void parseTierList(String content) {
    final lines = content.split('\n');
    Customer? currentCustomer;
    ImageData? currentImage;
    // Clear existing state before parsing
    List<ImageData> newUnassignedImages = [];
    Map<String, List<ImageData>> newCustomerItems = { for (var c in customers) c.name : [] };

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      if (line.startsWith('Tier: ')) {
        final tierName = line.substring(6).trim();
        currentCustomer = customers.firstWhere((c) => c.name == tierName, orElse: () => Customer(name: 'Unknown', items: [], color: Colors.grey)); // Handle unknown tiers gracefully
        if (tierName == 'Unassigned') {
           currentCustomer = null; // Signal to add to unassigned list
        }
        currentImage = null;
      } else if (line.startsWith('Image: ')) {
        final imageBase64 = line.substring(7).trim();
        if (imageBase64.isEmpty) { /* Skip empty image data */ i+=4; continue; } // Assume 4 lines: Image, Title, Text, DriverSkills, ImageList start
        Uint8List imageBytes;
        try { imageBytes = base64Decode(imageBase64); } catch (e) { print("Error decoding base64 image: $e"); i+=4; continue; }

        String title = ''; String text = ''; double driverSkills = 0.0; List<ImageData> subImageList = [];
        int linesConsumed = 0;

        // Safely read subsequent lines
        if (i + 1 < lines.length && lines[i + 1].trim().startsWith('Title: ')) { title = lines[i + 1].trim().substring(7); linesConsumed++; }
        if (i + 1 + linesConsumed < lines.length && lines[i + 1 + linesConsumed].trim().startsWith('Text: ')) {
           try { text = jsonDecode(lines[i + 1 + linesConsumed].trim().substring(6)) as String; } catch (e) { text = lines[i + 1 + linesConsumed].trim().substring(6); } // Fallback
           linesConsumed++;
        }
        if (i + 1 + linesConsumed < lines.length && lines[i + 1 + linesConsumed].trim().startsWith('DriverSkills: ')) { driverSkills = double.tryParse(lines[i + 1 + linesConsumed].trim().substring(14)) ?? 0.0; linesConsumed++; }
        if (i + 1 + linesConsumed < lines.length && lines[i + 1 + linesConsumed].trim().startsWith('ImageList:')) {
          linesConsumed++;
          int subImageIndex = i + 1 + linesConsumed;
          while (subImageIndex < lines.length && lines[subImageIndex].trim().startsWith('SubImage: ')) {
             final subImageBase64 = lines[subImageIndex].trim().substring(9).trim();
             if (subImageBase64.isEmpty) { subImageIndex += 4; continue; } // Assume 4 lines per sub-image
             Uint8List subImageBytes;
             try { subImageBytes = base64Decode(subImageBase64); } catch (e) { print("Error decoding base64 sub-image: $e"); subImageIndex += 4; continue; }

             String subTitle = ''; String subText = ''; double subDriverSkills = 0.0; int subLinesConsumed = 0;
             if (subImageIndex + 1 < lines.length && lines[subImageIndex + 1].trim().startsWith('Title: ')) { subTitle = lines[subImageIndex + 1].trim().substring(7); subLinesConsumed++; }
             if (subImageIndex + 1 + subLinesConsumed < lines.length && lines[subImageIndex + 1 + subLinesConsumed].trim().startsWith('Text: ')) {
                try { subText = jsonDecode(lines[subImageIndex + 1 + subLinesConsumed].trim().substring(6)) as String; } catch (e) { subText = lines[subImageIndex + 1 + subLinesConsumed].trim().substring(6); } // Fallback
                subLinesConsumed++;
             }
             if (subImageIndex + 1 + subLinesConsumed < lines.length && lines[subImageIndex + 1 + subLinesConsumed].trim().startsWith('DriverSkills: ')) { subDriverSkills = double.tryParse(lines[subImageIndex + 1 + subLinesConsumed].trim().substring(14)) ?? 0.0; subLinesConsumed++; }

             final subImageData = ImageData( const Uuid().v4(), '', bytes: subImageBytes, crossedOut: false, isBase64: true, title: subTitle, text: subText, imageList: [] )..driverSkills = subDriverSkills;
             subImageList.add(subImageData);
             subImageIndex += (1 + subLinesConsumed);
             linesConsumed = (subImageIndex - (i + 1));
          }
        }

        final imageData = ImageData( const Uuid().v4(), '', bytes: imageBytes, crossedOut: false, isBase64: true, title: title, text: text, imageList: subImageList.isEmpty ? null : subImageList )..driverSkills = driverSkills;
        imageData.imageList ??= [imageData]; // Ensure list has self if empty

        if (currentCustomer != null && newCustomerItems.containsKey(currentCustomer.name)) {
          newCustomerItems[currentCustomer.name]!.add(imageData);
        } else {
          newUnassignedImages.add(imageData); // Add to temporary unassigned list
        }
        currentImage = imageData;
        i += linesConsumed; // Skip processed lines
      }
    }

    // Update the state once after parsing everything
    setState(() {
      images = newUnassignedImages;
      for (var customer in customers) {
        customer.items.clear();
        if (newCustomerItems.containsKey(customer.name)) {
           customer.items.addAll(newCustomerItems[customer.name]!);
        }
      }
       // Ensure all loaded images have initialized imageList
      for (var img in images) { img.imageList ??= [img]; }
      for (var cust in customers) { for (var img in cust.items) { img.imageList ??= [img]; } }
    });
  }
} // End of TierListPageState

class Customer {
  final String name;
  final List<ImageData> items;
  final Color color;

  Customer({required this.name, required this.items, required this.color});

  // Removed toJson as it wasn't fully used and might be complex with full state saving
}

class ImageData {
  final String id;
  final String src; // Original source filename/identifier (can be empty if loaded)
  final Uint8List bytes;
  bool crossedOut;
  bool isBase64; // Indicates if bytes are from a base64 source (loaded)
  String text;
  String title;
  List<ImageData>? imageList; // Allow null initially
  double driverSkills;

  ImageData(
    this.id,
    this.src, {
    required this.bytes,
    this.crossedOut = false,
    this.isBase64 = false,
    this.text = '',
    this.title = '',
    this.imageList, // Accept null
    this.driverSkills = 0.0,
  }) {
     // Ensure imageList contains at least itself if initialized non-null but empty
     // Or initialize it here if null was passed.
     if (imageList == null) {
       imageList = [this];
     } else if (imageList!.isEmpty) {
       imageList!.add(this); // Add self if list was passed but empty
     }
  }

  // Removed toJson as it wasn't fully used
}

// Removed DraggableImage class as logic is integrated into CustomerCart and buildDraggableImage

class CustomerCart extends StatefulWidget {
  const CustomerCart({
    super.key,
    required this.customer,
    required this.highlighted, // Keep or remove based on usage
    required this.crossOutMode,
    // MODIFIED: Change callback signature
    required this.onImageDroppedAt,
    required this.onEditImageText,
    required this.onDeleteImage,
    required this.onViewImage, // Add this callback
  });

  final Customer customer;
  final bool highlighted;
  final bool crossOutMode;
  // MODIFIED: Callback includes index
  final Function(ImageData, int) onImageDroppedAt;
  final Function(ImageData) onEditImageText;
  final Function(ImageData) onDeleteImage; // For deleting from the cart
  final Function(ImageData) onViewImage;   // For viewing image details

  @override
  State<CustomerCart> createState() => _CustomerCartState();
}

class _CustomerCartState extends State<CustomerCart> {
  final ScrollController _scrollController = ScrollController();
  // Define approximate item width including padding
  static const double itemWidth = 100.0;
  static const double itemPaddingHorizontal = 4.0;
  static const double itemWidthWithPadding = itemWidth + (itemPaddingHorizontal * 2); // 100 width + 4 padding on each side
  static const double indicatorWidth = 10.0; // Width of the drop indicator

  // State variable to track highlight index
  int? _dropIndexHighlight;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // Helper to calculate drop index from local offset
  int _calculateDropIndex(Offset localPosition) {
    final scrollOffset = _scrollController.offset;
    // Adjust for the initial padding of the ListView and the indicator width
    final relativeDx = localPosition.dx + scrollOffset - itemPaddingHorizontal;

    // Calculate index based on slots (before, between, after items)
    // Each slot effectively starts slightly before the item center
    int index = ((relativeDx + (itemWidthWithPadding / 2)) / itemWidthWithPadding).floor();

    // Clamp the index to be within the valid range for insertion slots [0, items.length]
    index = index.clamp(0, widget.customer.items.length);
    return index;
  }


  @override
  Widget build(BuildContext context) {
    // Outer container remains without decoration
    return Container(
      child: DragTarget<ImageData>(
        builder: (context, candidateData, rejectedData) {
          bool canAccept = candidateData.isNotEmpty && !widget.crossOutMode;
          // Modify this inner container's decoration
          return Container(
             decoration: BoxDecoration(
                // Always apply customer color, adjust opacity based on canAccept
                color: widget.customer.color.withOpacity(canAccept ? 0.5 : 0.3),
                // Add border back for visual structure
                border: Border.all(
                  color: widget.customer.color,
                  width: 2, // Consistent border width
                ),
             ),
             child: Scrollbar(
controller: _scrollController,
               thumbVisibility: true,                // Make scrollbar always visible
               child: ListView.builder(
                 controller: _scrollController,
                 scrollDirection: Axis.horizontal,
                 // Add padding (only vertical needed now as items have horizontal)
                 padding: const EdgeInsets.symmetric(vertical: 8.0),
                 // Item count includes items + indicators (one indicator before first, one between each, one after last)
                 itemCount: widget.customer.items.length * 2 + 1,
                 itemBuilder: (context, listViewIndex) {
                   // Calculate the potential item index this slot corresponds to
                   final itemIndex = listViewIndex ~/ 2;

                   // Even indices are indicators/spacers
                   if (listViewIndex % 2 == 0) {
                     bool isHighlighted = _dropIndexHighlight == itemIndex;
                     return Container(
                       width: isHighlighted ? itemWidthWithPadding / 2 : indicatorWidth, // Wider when highlighted
                       margin: EdgeInsets.symmetric(vertical: isHighlighted ? 0 : 10), // Add margin to non-highlighted indicators
                       decoration: BoxDecoration(
                         color: isHighlighted ? Colors.white.withOpacity(0.7) : Colors.transparent, // Highlight color
                         borderRadius: isHighlighted ? BorderRadius.circular(4) : null,
                       ),
                     );
                   }
                   // Odd indices are the actual items
                   else {
                     // Get the actual item index
                     final actualItemIndex = (listViewIndex - 1) ~/ 2;
                     if (actualItemIndex < widget.customer.items.length) {
                       return buildCartItem(widget.customer.items[actualItemIndex], context, actualItemIndex);
                     } else {
                       return const SizedBox.shrink(); // Should not happen with correct itemCount
                     }
                   }
                 },
               ),
             ),
          );
        },
        onWillAccept: (data) => data != null && !widget.crossOutMode,
        onAcceptWithDetails: (details) {
          final imageData = details.data;
          // Get drop position relative to the DragTarget container
          final RenderBox renderBox = context.findRenderObject() as RenderBox;
          final localPosition = renderBox.globalToLocal(details.offset);

          final index = _calculateDropIndex(localPosition);

          print("Drop accepted at local offset ${localPosition.dx}, calculated index: $index");

          // Call the updated callback with the index
          widget.onImageDroppedAt(imageData, index);

          // Reset highlight after drop
          if (mounted) {
            setState(() { _dropIndexHighlight = null; });
          }
        },
        onMove: (details) {
          if (!widget.crossOutMode) {
            // Get position relative to the DragTarget container
            final RenderBox renderBox = context.findRenderObject() as RenderBox;
            final localPosition = renderBox.globalToLocal(details.offset);
            final index = _calculateDropIndex(localPosition);

            // Update highlight state only if it changes
            if (_dropIndexHighlight != index) {
              if (mounted) {
                 setState(() { _dropIndexHighlight = index; });
              }
              print("Drag move detected at local offset ${localPosition.dx}, potential index: $index");
            }
          }
        },
        onLeave: (data) {
          // Reset highlight when drag leaves the target
          if (mounted) {
            setState(() { _dropIndexHighlight = null; });
          }
          print("Drag left target area.");
        },
      ),
    );
  }

  // Local representation of an item within the cart
  Widget buildCartItem(ImageData imageData, BuildContext context, int index) {
     imageData.imageList ??= [imageData]; // Ensure list is initialized

     Widget imageWidget = GestureDetector(
       onTap: () {
         if (widget.crossOutMode) {
           // Need setState in parent (TierListPageState) to update UI
           // This structure makes direct state update difficult.
           // Consider calling a callback like widget.onToggleCrossout(imageData);
           // For now, just update local state visually, parent handles actual data on view/save
           setState(() { // This setState only affects CustomerCart visually
              imageData.crossedOut = !imageData.crossedOut;
           });
           // TODO: Consider calling a callback to TierListPageState to update the actual data immediately
           // widget.onToggleCrossout(imageData); // Example callback
         // REMOVED: } else if (!widget.editMode) {
         } else { // Allow viewing if not in crossOutMode
           widget.onViewImage(imageData); // Use the view callback
         }
       },
       child: SizedBox(
         width: itemWidth, // Use constant
         height: 100, // Ensure height is constrained
         child: Stack(
           // ... existing Stack children ...
           fit: StackFit.expand,
           children: [
             Image.memory(imageData.bytes, fit: BoxFit.cover),
             if (imageData.title.isNotEmpty) // Title Overlay
                Positioned( top: 0, left: 0, right: 0, child: Container( color: Colors.black.withOpacity(0.5), padding: const EdgeInsets.all(2), child: Text( imageData.title, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold), textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, ), ), ),
             if (imageData.crossedOut) // Cross-out Overlay
                Container( color: Colors.black.withOpacity(0.4), child: const Center( child: Icon( Icons.clear, color: Colors.red, size: 80, ), ), ),
             // Edit Button
             Positioned( bottom: 0, right: 0, child: Container( color: Colors.black.withOpacity(0.5), child: IconButton( icon: const Icon(Icons.edit, color: Colors.white, size: 20), tooltip: "Edit Text/Skills", onPressed: () => widget.onEditImageText(imageData), padding: EdgeInsets.zero, constraints: const BoxConstraints(), ), ), ),
             // Delete Button (Specific to cart)
             Positioned( top: 0, right: 0, child: Container( color: Colors.black.withOpacity(0.5), child: IconButton( icon: const Icon(Icons.delete, color: Colors.orange, size: 20),
               tooltip: "Remove from Tier", onPressed: () { widget.onDeleteImage(imageData); }, padding: EdgeInsets.zero, constraints: const BoxConstraints(), ), ), ),
           ],
         ),
       ),
     );

     // Only allow dragging if not in crossOut mode
     // REMOVED: if (widget.crossOutMode || widget.editMode) {
     if (widget.crossOutMode) {
       return Padding( // Add padding around non-draggable items
          padding: const EdgeInsets.symmetric(horizontal: itemPaddingHorizontal), // Use constant
          child: imageWidget,
       );
     } else {
       return Padding( // Add padding around draggable items
         padding: const EdgeInsets.symmetric(horizontal: itemPaddingHorizontal), // Use constant
         child: Draggable<ImageData>(
           data: imageData,
           feedback: Material( color: Colors.transparent, child: SizedBox( width: itemWidth, height: 100, child: Opacity( opacity: 0.7, child: imageWidget, ), ), ),
           childWhenDragging: Container( width: itemWidth, height: 100, margin: const EdgeInsets.symmetric(horizontal: itemPaddingHorizontal), color: Colors.grey.withOpacity(0.3), ),
           child: imageWidget,
           // ... existing drag callbacks ...
         ),
       );
     }
  }
}


// --- PhotoViewPage StatefulWidget ---
class PhotoViewPage extends StatefulWidget {
  final ImageData image; // The main image whose list we are viewing/editing
  final List<ImageData> imageList; // The list containing the main image and its sub-images

  const PhotoViewPage({
    super.key,
    required this.image,
    required this.imageList, // This list will be modified directly by add/delete actions
  });

  @override
  _PhotoViewPageState createState() => _PhotoViewPageState();
}

// --- _PhotoViewPageState State ---
class _PhotoViewPageState extends State<PhotoViewPage> {
  late int currentIndex;
  late PageController _pageController;
  // REMOVED: final List<ImageData> _addedImages = [];
  bool _didAddImages = false; // Track if images were added in this session
  String? _deletedImageId; // Track the ID of an image deleted in this session

  @override
  void initState() {
    super.initState();
    // Ensure the list passed in widget.imageList is the direct reference
    // CRITICAL: Calculate currentIndex *before* initializing PageController
    currentIndex = widget.imageList.indexWhere((img) => img.id == widget.image.id);
    if (currentIndex == -1) {
      // Fallback
      currentIndex = widget.imageList.indexWhere((img) => listEquals(img.bytes, widget.image.bytes));
      if (currentIndex == -1) {
         print("Warning: Main image ID ${widget.image.id} not found in provided imageList. Defaulting to index 0.");
         currentIndex = 0;
         if (widget.imageList.isEmpty) {
            print("Error: imageList is empty in PhotoViewPage initState.");
            // If list is empty, we can't show anything, maybe pop immediately?
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                Navigator.pop(context, PhotoViewResult()); // Pop with no changes
              }
            });
         }
      }
    }
    // Initialize controller with the determined index
    _pageController = PageController(initialPage: currentIndex);
    print("PhotoViewPage initState: imageList length = ${widget.imageList.length}, initial index = $currentIndex");
  }

   @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // --- Modified Add Images ---
  void _addImages() async {
    final pickedFiles = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
      withData: true,
    );

    if (pickedFiles != null && pickedFiles.files.isNotEmpty) {
      final initialLength = widget.imageList.length;
      int countAdded = 0;

      setState(() { // Update the UI immediately
        for (final file in pickedFiles.files) {
          if (file.bytes != null) {
            String imageTitle = file.name.split('.').first;
            if (!kIsWeb && file.path != null && file.path!.isNotEmpty) {
              try { String directoryPath = p.dirname(file.path!); imageTitle = p.basename(directoryPath); } catch (e) { /* Handle error */ }
            }
            final newImageData = ImageData( const Uuid().v4(), file.name, bytes: file.bytes!, crossedOut: false, isBase64: false, title: imageTitle, imageList: [] );
            // The constructor now correctly initializes imageList = [newImageData]

            // Add to the list passed via widget (modifies the original list in TierListPageState)
            widget.imageList.add(newImageData);
            countAdded++;
            _didAddImages = true; // Set flag
          }
        }
      });

      print("Added $countAdded images. New list length: ${widget.imageList.length}");

      // Animate to the first newly added image
      WidgetsBinding.instance.addPostFrameCallback((_) {
         if (mounted && widget.imageList.length > initialLength) {
            // Animate page controller to the index of the first added image
            _pageController.animateToPage( initialLength, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut, );
         }
      });
       ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text('$countAdded sub-image(s) added.')) );
    }
  }

  // --- Modified Delete Function ---
  void _deleteCurrentImage() async {
    if (widget.imageList.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar( const SnackBar(content: Text("Cannot delete the only image.")) );
      return;
    }

    // Ensure currentIndex is valid before accessing
    if (currentIndex < 0 || currentIndex >= widget.imageList.length) {
       print("Error: Invalid currentIndex ($currentIndex) for deletion.");
       return;
    }

    final imageToDelete = widget.imageList[currentIndex];

    final bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Confirm Deletion"),
          content: Text("Are you sure you want to delete this sub-image titled '${imageToDelete.title}'?"),
          actions: <Widget>[
            TextButton(child: const Text("Cancel"), onPressed: () => Navigator.of(context).pop(false)),
            TextButton(style: TextButton.styleFrom(foregroundColor: Colors.red), child: const Text("Delete"), onPressed: () => Navigator.of(context).pop(true)),
          ],
        );
      },
    );

    if (confirmDelete == true && mounted) {
      _deletedImageId = imageToDelete.id;
      print("Popping PhotoViewPage, returning deleted image ID: $_deletedImageId");
      // Pop with result containing the deleted ID
      Navigator.pop(context, PhotoViewResult(deletedSubImageId: _deletedImageId));
    }
  }

  // --- Function to handle popping with results ---
  Future<bool> _onWillPop() async {
    if (_deletedImageId != null) {
      // If an image was deleted, that result takes precedence
      Navigator.pop(context, PhotoViewResult(deletedSubImageId: _deletedImageId));
    } else {
      // Otherwise, return whether images were added or not
      print("Popping PhotoViewPage via WillPopScope, returning imagesAdded: $_didAddImages");
      Navigator.pop(context, PhotoViewResult(imagesAdded: _didAddImages));
    }
    // Prevent default pop because we are handling it manually
    return false;
  }


  @override
  Widget build(BuildContext context) {
    // Use WillPopScope to intercept back navigation and return results
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          // ... app bar title and actions ...
          title: Text(widget.imageList.isNotEmpty && currentIndex >= 0 && currentIndex < widget.imageList.length // Add index check >= 0
              ? (widget.imageList[currentIndex].title.isNotEmpty ? widget.imageList[currentIndex].title : "Image Viewer")
              : "Image Viewer"), // Handle potential empty list/invalid index
          // ... actions ...
          actions: [
            IconButton(icon: const Icon(Icons.add_photo_alternate), tooltip: "Add Sub-Images", onPressed: _addImages),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              tooltip: "Delete Current Sub-Image",
              // Enable delete only if there's more than one image
              onPressed: widget.imageList.length > 1 ? _deleteCurrentImage : null,
            ),
          ],
        ),
        body: Stack(
          alignment: Alignment.center,
          children: [
            // Gallery Column
            if (widget.imageList.isNotEmpty) // Only build gallery if list is not empty
              Column(
                children: [
                  Expanded(
                    child: PhotoViewGallery.builder(
                      // SIMPLIFIED KEY: Based on main image ID and list length
                      key: ValueKey('${widget.image.id}_${widget.imageList.length}'),
                      itemCount: widget.imageList.length,
                      pageController: _pageController, // Use the initialized controller
                      builder: (context, index) {
                         // Check index validity again just in case
                         if (index < 0 || index >= widget.imageList.length) {
                            print("Error: Invalid index $index in PhotoViewGallery builder.");
                            return PhotoViewGalleryPageOptions.customChild(
                              child: Container(color: Colors.red, child: const Center(child: Text("Error: Invalid Image Index"))),
                              initialScale: PhotoViewComputedScale.contained,
                              minScale: PhotoViewComputedScale.contained * 0.8,
                              maxScale: PhotoViewComputedScale.covered * 2.0,
                            );
                         }
                         // Get image data for the CURRENT build index
                         final imgData = widget.imageList[index];
                         return PhotoViewGalleryPageOptions(
                          imageProvider: MemoryImage(imgData.bytes),
                          initialScale: PhotoViewComputedScale.contained,
                          minScale: PhotoViewComputedScale.contained * 0.8,
                          maxScale: PhotoViewComputedScale.covered * 2.0,
                          heroAttributes: PhotoViewHeroAttributes(tag: imgData.id), // Use unique ID for hero tag
                        );
                      },
                      onPageChanged: (index) {
                        // Update the state variable when page changes
                        if (mounted) {
                           setState(() { currentIndex = index; });
                        }
                      },
                      loadingBuilder: (context, event) => const Center(child: CircularProgressIndicator()),
                      backgroundDecoration: const BoxDecoration(color: Colors.black),
                    ),
                  ),
                  // Index indicator
                  if (widget.imageList.length > 1)
                    Padding( padding: const EdgeInsets.all(8.0), child: Text( "${currentIndex + 1} / ${widget.imageList.length}", style: const TextStyle(color: Colors.white, fontSize: 16.0, backgroundColor: Colors.black54), ), ),
                ],
              )
            else // Show message if list is empty
              const Center(child: Text("No images to display.")),

            // Navigation Arrows (only if list is not empty and has multiple items)
            if (widget.imageList.length > 1) ...[
               // Use currentIndex state variable for enabling/disabling arrows
               if (currentIndex > 0) Align( alignment: Alignment.centerLeft, child: Container( margin: const EdgeInsets.only(left: 8.0), decoration: BoxDecoration( color: Colors.black.withOpacity(0.4), shape: BoxShape.circle, ), child: IconButton( icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white), tooltip: "Previous Image", onPressed: () => _pageController.previousPage( duration: const Duration(milliseconds: 300), curve: Curves.easeInOut, ), ), ), ),
               if (currentIndex < widget.imageList.length - 1) Align( alignment: Alignment.centerRight, child: Container( margin: const EdgeInsets.only(right: 8.0), decoration: BoxDecoration( color: Colors.black.withOpacity(0.4), shape: BoxShape.circle, ), child: IconButton( icon: const Icon(Icons.arrow_forward_ios, color: Colors.white), tooltip: "Next Image", onPressed: () => _pageController.nextPage( duration: const Duration(milliseconds: 300), curve: Curves.easeInOut, ), ), ), ),
            ]
          ],
        ),
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
  late TextEditingController _driverSkillsController;
  final ScrollController _textScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Ensure imageList is initialized before accessing properties
    widget.image.imageList ??= [widget.image];

    _titleController = TextEditingController(text: widget.image.title);
    _textController = TextEditingController(text: widget.image.text);
    _driverSkillsController = TextEditingController(text: widget.image.driverSkills.toStringAsFixed(1)); // Format initial value

    _titleController.addListener(() { widget.image.title = _titleController.text; });
    _textController.addListener(() {
      widget.image.text = _textController.text;
      // Auto-scroll
      WidgetsBinding.instance.addPostFrameCallback((_) {
         if (_textScrollController.hasClients) {
           _textScrollController.jumpTo(_textScrollController.position.maxScrollExtent);
         }
      });
      // Trigger rebuild for RichText update
      setState(() {});
    });
    _driverSkillsController.addListener(() {
      final parsed = double.tryParse(_driverSkillsController.text) ?? 0.0;
      // Clamp value between 0 and 10
      widget.image.driverSkills = parsed.clamp(0.0, 10.0);
      // Optional: Update text field if clamping occurred, requires careful handling to avoid loops
      // if (widget.image.driverSkills != parsed && _driverSkillsController.text != widget.image.driverSkills.toStringAsFixed(1)) {
      //    final currentSelection = _driverSkillsController.selection;
      //    _driverSkillsController.text = widget.image.driverSkills.toStringAsFixed(1);
      //    _driverSkillsController.selection = currentSelection; // Restore cursor position
      // }
    });
  }

  @override
  void dispose() {
    // Save final values just in case listeners didn't catch the very last change
    widget.image.title = _titleController.text;
    widget.image.text = _textController.text;
    // No need to parse driver skills again, it's updated via listener
    _titleController.dispose();
    _textController.dispose();
    _driverSkillsController.dispose();
    _textScrollController.dispose();
    super.dispose();
  }

  // Helper method for RichText styling
  TextSpan _buildStyledText(String text) {
    final List<TextSpan> spans = [];
    final pattern = RegExp(r'(\*\*)([^*]+?)\1'); // Non-greedy match inside **
    int lastIndex = 0;

    for (final Match match in pattern.allMatches(text)) {
      if (match.start > lastIndex) {
        spans.add(TextSpan(text: text.substring(lastIndex, match.start)));
      }
      // Add bold text without the markers
      spans.add(TextSpan(text: match.group(2), style: const TextStyle(fontWeight: FontWeight.bold)));
      lastIndex = match.end;
    }

    if (lastIndex < text.length) {
      spans.add(TextSpan(text: text.substring(lastIndex)));
    }

    // Base style for the entire RichText
    return TextSpan(style: const TextStyle(color: Colors.white, fontSize: 16), children: spans);
  }

  // Toggles bold markdown around selection or at cursor position
  void _toggleBold() {
    final String currentText = _textController.text;
    final TextSelection selection = _textController.selection;
    String newText;

    if (selection.isCollapsed) {
      // Insert '**' at cursor
      newText = currentText.substring(0, selection.start) +
                '****' +
                currentText.substring(selection.end);
      // Move cursor between the markers
      _textController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: selection.start + 2),
      );
    } else {
      // Wrap selection with '**'
      final String selectedText = selection.textInside(currentText);
      newText = currentText.substring(0, selection.start) +
                '**' + selectedText + '**' +
                currentText.substring(selection.end);
      // Keep selection around the original text + markers
      _textController.value = TextEditingValue(
        text: newText,
        selection: TextSelection(
          baseOffset: selection.start + 2,
          extentOffset: selection.end + 2,
        ),
      );
    }
     // Manually update image text as controller listener might lag
     widget.image.text = _textController.text;
     setState(() {}); // Trigger rebuild for RichText
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: <LogicalKeySet, Intent>{
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyB): const BoldIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          BoldIntent: CallbackAction<BoldIntent>(
            onInvoke: (BoldIntent intent) => _toggleBold(),
          ),
        },
        child: Focus(
          autofocus: true, // Focus the main content area
          child: WillPopScope( // Use WillPopScope for saving on back button
            onWillPop: () async {
              // Final save before popping
              widget.image.title = _titleController.text;
              widget.image.text = _textController.text;
              // Driver skills are updated via listener
              print("Popping TextEditorPage, saved data.");
              return true; // Allow pop
            },
            child: Scaffold(
              appBar: AppBar(
                title: Row(
                  children: [
                    Expanded( // Allow title to take space
                       child: Text(
                          'Edit: ${widget.image.title.isNotEmpty ? widget.image.title : widget.image.src}',
                          overflow: TextOverflow.ellipsis,
                       )
                    ),
                    const Text(' Skills:'),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 60, // Keep fixed width for skills input
                      child: TextField(
                        controller: _driverSkillsController,
                        textAlign: TextAlign.center, // Center skills value
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        // Allow digits, one decimal point
                        inputFormatters: [ FilteringTextInputFormatter.allow(RegExp(r'^\d{0,2}\.?\d{0,1}')), ],
                        decoration: const InputDecoration(
                          hintText: '0-10',
                          isDense: true, // Reduce padding
                          contentPadding: EdgeInsets.symmetric(vertical: 8.0), // Adjust vertical padding
                        ),
                        style: const TextStyle(fontSize: 14), // Adjust font size
                      ),
                    ),
                  ],
                ),
                actions: [
                  IconButton( // Add Bold toggle button
                     icon: const Icon(Icons.format_bold),
                     tooltip: "Toggle Bold (Ctrl+B)",
                     onPressed: _toggleBold,
                  ),
                  IconButton(
                    icon: const Icon(Icons.photo),
                    tooltip: "View Image(s)",
                    // MODIFIED: Make onPressed async and handle potential result
                    onPressed: () async {
                      widget.image.imageList ??= [widget.image];
                      // Await result from PhotoViewPage
                      final result = await Navigator.push<PhotoViewResult?>(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PhotoViewPage(
                            image: widget.image,
                            imageList: widget.image.imageList!,
                          ),
                        ),
                      );
                      // Refresh TextEditorPage state if PhotoViewPage indicated changes
                      if (result != null && (result.imagesAdded || result.deletedSubImageId != null) && mounted) {
                         print("Returned to TextEditorPage from PhotoViewPage with result: $result. Refreshing state.");
                         setState(() {});
                      }
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
                        labelText: 'Title', // Use labelText
                        hintText: 'Enter title here...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded( // Allow text area to take remaining space
                      child: Stack(
                        children: [
                          // Background RichText for styling
                          Container( // Add border matching TextField
                             decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey),
                                borderRadius: BorderRadius.circular(4.0),
                             ),
                             width: double.infinity, // Ensure it fills width
                             child: SingleChildScrollView( // Allow scrolling for styled text too
                               controller: _textScrollController, // Link scroll controllers
                               padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0), // Match TextField padding
                               child: RichText(
                                 text: _buildStyledText(_textController.text),
                               ),
                             ),
                          ),
                          // Foreground TextField for editing (transparent text)
                          TextField(
                            controller: _textController,
                            scrollController: _textScrollController, // Use the same controller
                            maxLines: null, // Allow multiple lines
                            expands: true, // Expand to fill Expanded widget
                            keyboardType: TextInputType.multiline,
                            style: const TextStyle(
                              color: Colors.transparent, // Hide the actual text
                              fontSize: 16, // Match RichText font size
                            ),
                            cursorColor: Colors.white, // Make cursor visible
                            decoration: const InputDecoration(
                              hintText: 'Enter text... use **bold** or Ctrl+B',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0), // Match RichText padding
                            ),
                            // onChanged handled by listener now
                          ),
                        ],
                      ),
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