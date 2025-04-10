import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
//import 'package:excel/excel.dart' as ex; // Paquete para generar archivos Excel
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:html' as html; // Only used on web
import 'package:qr_code_scanner/qr_code_scanner.dart';  // Import for QR code scanning
import 'main.dart'; // Agrega esta línea para navegar a TierListPage
import 'dart:ui_web' as ui; // New import for web view registry
import 'dart:js' as js; // New import for calling jsQR
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/widgets.dart'; // Add import for widgets binding observer
import 'excel_generator.dart'; // Agrega esta línea para navegar a Ranking Table

/// Función principal que arranca la aplicación.
void main() {
  runApp(MyApp());
}

/// Widget principal de la aplicación.
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OverScouting Qr',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: OverScoutingApp(),
    );
  }
}

/// Widget con estado que representa la aplicación OverScouting.
class OverScoutingApp extends StatefulWidget {
  @override
  _OverScoutingAppState createState() => _OverScoutingAppState();
}

class _OverScoutingAppState extends State<OverScoutingApp> with WidgetsBindingObserver {
  // ASCII art que se mostrará en la parte superior
  final String asciiArt = r"""
    .___                 ____                  _   _                ___       
  ../ _ \__   _____ _ __/ ___|  ___ __ _ _   _| |_(_)_ __   __ _   / _ \ _ __ 
  .| | | \ \ / / _ \ '__\___ \ / __/ _` | | | | __| | '_ \ / _` | | | | | '__|
  .| |_| |\ V /  __/ |   ___) | (_| (_| | |_| | |_| | | | | (_| | | |_| | |   
    \___/  \_/ \___|_|  |____/ \___\__,_|\__,_|\__|_|_| |_|\__, |  \__\_\_|   
                                                            |___/             
    by FIRST FRC Team Overture - 7421        
        
      Bienvenido a OverScouting Qr, la herramienta de compilación de datos por QR.
      Agradecemos la aplicación de QRScout de Red Hawk Robotics 2713.
      Ahora traucida a Dart.
  """;

  // Add the playBeepSound method:
  void playBeepSound() async {
    try {
      // Create a player and use AssetSource
      final player = AudioPlayer();
      await player.play(AssetSource('store-scanner-beep-90395.mp3'));
    } catch (e) {
      print("Asset beep failed, playing fallback beep: $e");
      // Fallback using a network source (stock beep sound)
      final fallbackPlayer = AudioPlayer();
      await fallbackPlayer.play(UrlSource('https://actions.google.com/sounds/v1/alarms/beep_short.ogg'));
    }
  }

  // Controlador para el área de texto principal
  final TextEditingController _textController = TextEditingController();
  // Add a FocusNode for the MainTextArea
  final FocusNode _textFocusNode = FocusNode();

  // Variable que almacena el mensaje de estado
  String statusMessage = "Status messages will appear here.";

  // Lista para guardar el historial de estados para la función de deshacer
  List<String> dataHistory = [];

  // Intervalo de autosave en segundos
  final int autosaveInterval = 30;
  Timer? autosaveTimer;

  // Nombres de archivo para los respaldos
  final String filename = "data_backup.csv";
  final String backupFilename = "data_backup_autosave.csv";
  final String backupFilename2 = "data_backup_autosave2.csv";

  // Directorio de documentos de la aplicación
  late Directory appDocDir;

  bool isCameraMode = false; // State flag
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR'); // Still used for mobile
  QRViewController? qrController; // Mobile QR controller
  UniqueKey _webScannerKey = UniqueKey();
  
  // New function to toggle camera preview mode
  void toggleCameraMode() {
    if (isCameraMode) {
      if (!kIsWeb) {
        qrController?.pauseCamera();
      } else {
        // When toggling from camera to ASCII, ensure complete camera cleanup
        // This happens at the WebQRScanner level via dispose()
      }
      setState(() {
        isCameraMode = false;
      });
    } else {
      if (kIsWeb) {
        _webScannerKey = UniqueKey(); // Force reinitialization with new key
        // Delay state change slightly to ensure proper cleanup
        Future.delayed(Duration(milliseconds: 300), () {
          if (!mounted) return; // Add mounted check
          setState(() {
            isCameraMode = true;
          });
        });
        return; // Exit early as we'll set state after delay
      }
      setState(() {
        isCameraMode = true;
      });
    }
  }

  // New function to handle QRView creation
  void _onQRViewCreated(QRViewController controller) {
    qrController = controller;
    controller.scannedDataStream.listen((scanData) {
      // Append scanned QR data
      if (scanData.code != null && scanData.code!.isNotEmpty) {
        onQRCodeScanned(scanData.code!);
      }
    });
  }

  // Modified function to handle scanned QR code results:
  void onQRCodeScanned(String code) {
    // Replace literal "\t" with actual tab characters if needed
    String processedCode = code.replaceAll(r'\t', "\t");
    setState(() {
      // Append complete QR info and add a newline for the next text.
      _textController.text += processedCode + "\n";
      dataHistory.add(_textController.text); // Update history with the new state
    });
    _textFocusNode.requestFocus();
    playBeepSound(); // Play a beep sound on successful scan
  }

  /// Inicializa la aplicación: obtiene el directorio de documentos,
  /// carga datos existentes y arranca el temporizador de autosave.
  Future<void> initApp() async {
    if (!kIsWeb) {
      appDocDir = await getApplicationDocumentsDirectory();
      await loadExistingData();
      autosaveTimer = Timer.periodic(Duration(seconds: autosaveInterval), (timer) {
        autosaveData();
      });
    } else {
      // En web, se omite cargar directorios locales.
      updateStatus("Running on Web: autosave and file load disabled.");
    }
  }

  /// Actualiza el mensaje de estado.
  /// Si [displayInMainTextArea] es verdadero, añade el mensaje al área de texto principal.
  void updateStatus(String message, {bool displayInMainTextArea = false}) {
    if (!mounted) return; // Add mounted check
    
    setState(() {
      if (displayInMainTextArea) {
        // Se agrega el mensaje al final del área de texto principal
        _textController.text += "\n" + message;
      } else {
        // Se actualiza el mensaje de estado que se muestra en la parte inferior
        statusMessage = message;
      }
    });
    // Después de 5 segundos se borra el mensaje de estado (si no se muestra en el área principal)
    if (!displayInMainTextArea) {
      Future.delayed(Duration(seconds: 5), () {
        if (!mounted) return; // Add mounted check
        setState(() {
          statusMessage = "";
        });
      });
    }
  }

  /// Initializes the application and sets up a listener for the text field to save its state.
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Restore cached text from previous page
    _textController.text = TextCacheService.cachedText;
    // Añade un listener para guardar automáticamente cada cambio en el historial
    _textController.addListener(() {
      // Solo agrega si es diferente del último estado para evitar duplicados
      if (dataHistory.isEmpty || dataHistory.last != _textController.text) {
        dataHistory.add(_textController.text);
      }
    });
    // Inicializamos el directorio de la app y cargamos datos existentes
    initApp();
  }

  @override
  void dispose() {
    print("OverScoutingApp dispose called");
    
    // Before disposing, update the cache with current text
    TextCacheService.cachedText = _textController.text;
    
    // Cancel all operations that might call setState()
    WidgetsBinding.instance.removeObserver(this);
    qrController?.dispose();
    qrController = null;
    
    autosaveTimer?.cancel();
    autosaveTimer = null;
    
    _textController.dispose();
    _textFocusNode.dispose();
    
    super.dispose();
  }

  // New lifecycle method to pause/resume camera (mobile only)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!kIsWeb) {
      if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
        qrController?.pauseCamera();
      } else if (state == AppLifecycleState.resumed && isCameraMode) {
        qrController?.resumeCamera();
      }
    }
  }

  /// Deshace la última acción restaurando el estado previo del área de texto.
  void undoChange() {
    if (dataHistory.isNotEmpty) {
      String lastState = dataHistory.removeLast();
      _textController.value = TextEditingValue(
        text: lastState,
        selection: TextSelection.collapsed(offset: lastState.length),
      );
      updateStatus("Last action undone successfully.");
    } else {
      updateStatus("No actions to undo.");
    }
  }

  /// Autosave: guarda periódicamente el contenido del área de texto en dos archivos de respaldo.
  Future<void> autosaveData() async {
    if (kIsWeb) return; // Omitir autosave en web
    String content = _textController.text.trim();
    List<String> lines = content.split('\n');
    // Se reemplazan las tabulaciones por comas para formato CSV
    List<String> csvFormattedLines = lines.map((line) => line.replaceAll('\t', ',')).toList();

    // Se guarda en ambos archivos de respaldo
    for (String backup in [backupFilename, backupFilename2]) {
      try {
        File file = File('${appDocDir.path}/$backup');
        await file.writeAsString(csvFormattedLines.join('\n') + '\n');
      } catch (e) {
        updateStatus("Error autosaving data: $e", displayInMainTextArea: true);
      }
    }
  }

  /// Carga datos existentes desde el archivo de respaldo, si existe.
  Future<void> loadExistingData() async {
    if (kIsWeb) return; // No aplica en web
    String? loadFilename;
    File backupFile = File('${appDocDir.path}/$backupFilename');
    File primaryFile = File('${appDocDir.path}/$filename');
    if (await backupFile.exists()) {
      loadFilename = backupFilename;
    } else if (await primaryFile.exists()) {
      loadFilename = filename;
    } else {
      return;
    }
    try {
      File file = File('${appDocDir.path}/$loadFilename');
      String data = await file.readAsString();
      setState(() {
        _textController.text = data;
      });
    } catch (e) {
      updateStatus("Error loading data: $e");
    }
  }

  /// Guarda el contenido actual en archivos CSV y TXT.
  Future<void> saveCsvAndTxt() async {
    String content = _textController.text.trim();
    if (content.isEmpty) {
      // Show warning dialog if no content
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text("Warning"),
            content: Text("There is no content to save."),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text("OK"),
              )
            ],
          );
        },
      );
      return;
    }
    
    if (kIsWeb) {
      // Web: generate CSV content for download
      List<String> lines = content.split('\n');
      List<List<String>> dataList = lines.where((line) => line.isNotEmpty)
          .map((line) => line.split('\t')).toList();
      String csvContent = dataList.map((row) => row.join(',')).join('\n');
      
      // Improved download for mobile browsers
      final isMobile = html.window.navigator.userAgent.contains('Mobile') || 
                       html.window.navigator.userAgent.contains('Android') ||
                       html.window.navigator.userAgent.contains('iPhone');
      
      try {
        // Create CSV blob and URL
        final csvBlob = html.Blob([csvContent], 'text/csv');
        final csvUrl = html.Url.createObjectUrlFromBlob(csvBlob);
        
        // Create TXT blob and URL
        String txtContent = content.replaceAll('\t', ',');
        final txtBlob = html.Blob([txtContent], 'text/plain');
        final txtUrl = html.Url.createObjectUrlFromBlob(txtBlob);
        
        // For mobile browsers, create visible download links
        if (isMobile) {
          showDialog(
            context: context,
            builder: (context) {
              return AlertDialog(
                title: Text('Download Files'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Tap links below to download:'),
                    SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: () {
                        html.window.open(csvUrl, '_blank');
                      },
                      child: Text('Download CSV'),
                    ),
                    SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: () {
                        html.window.open(txtUrl, '_blank');
                      },
                      child: Text('Download TXT'),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      html.Url.revokeObjectUrl(csvUrl);
                      html.Url.revokeObjectUrl(txtUrl);
                      Navigator.of(context).pop();
                    },
                    child: Text('Close'),
                  ),
                ],
              );
            },
          );
        } else {
          // Standard desktop browser download with anchors
          html.AnchorElement(href: csvUrl)
            ..setAttribute("download", "data.csv")
            ..click();
          
          html.AnchorElement(href: txtUrl)
            ..setAttribute("download", "data.txt")
            ..click();
            
          // Cleanup URLs after download starts
          Future.delayed(Duration(seconds: 1), () {
            html.Url.revokeObjectUrl(csvUrl);
            html.Url.revokeObjectUrl(txtUrl);
          });
        }
        
        updateStatus("Data saved to CSV and TXT successfully.");
      } catch (e) {
        print("Error saving files: $e");
        updateStatus("Error saving files: $e");
      }
      return;
    }
    
    // Existing mobile logic:
    // Utiliza file_picker para pedirle al usuario la ubicación y nombre del archivo CSV
    String? selectedPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Save CSV',
      fileName: 'data.csv',
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );

    if (selectedPath == null) {
      updateStatus("Save operation cancelled.");
      return;
    }
    String exportFilenameCsv = selectedPath;
    // Se genera el nombre del archivo TXT cambiando la extensión a .txt
    String exportFilenameTxt = exportFilenameCsv.replaceAll(RegExp(r'\.csv$'), '.txt');

    try {
      List<String> lines = content.split('\n');
      // Se genera una lista de listas separando cada línea por tabulaciones
      List<List<String>> dataList = lines.where((line) => line.isNotEmpty)
          .map((line) => line.split('\t')).toList();

      // Guarda el archivo CSV
      File csvFile = File(exportFilenameCsv);
      String csvContent = dataList.map((row) => row.join(',')).join('\n');
      await csvFile.writeAsString(csvContent);

      // Guarda el archivo TXT manteniendo las tabulaciones
      File txtFile = File(exportFilenameTxt);
      await txtFile.writeAsString(content);

      // Muestra un diálogo de éxito
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text("Success"),
            content: Text("Data saved to CSV and TXT successfully."),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text("OK"),
              )
            ],
          );
        },
      );
      updateStatus("Data saved to CSV and TXT successfully.");
    } catch (e) {
      // En caso de error, muestra un diálogo y actualiza el mensaje de estado
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text("Error"),
            content: Text("Failed to save files: $e"),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text("OK"),
              )
            ],
          );
        },
      );
      updateStatus("Failed to save files: $e");
    }
  }

  // New method to prepare and send the prompt to ChatGPT.
  void _sendToChatGPT() {
    final originalText = _textController.text;
    final processedText = originalText.replaceAll('\t', ',');
    final prompt = "Elige, basado en estos datos, al mejor equipo para mi estrategia [pon tu estrategia] de la competencia First Robotics Competition. Format:(ScouterInitials/MatchNumber/RobotTeamNumber/StartingPosition/NoShow/CagePosition/Moved?/CoralL1Autonomous/ScoredCoralL2Autonomous/CoralL3Autonomous/CoralL4Autonomous/BargeAlgaeScoredAutonomous/ProcessorAlgaeAutonomous/DislodgedAlgae?Autonomous/AutoFoul/DislodgedAlgae?TeleOp/PickupLocation/CoralL1TeleOp/CoralL2TeleOp/CoralL3TeleOp/CoralL4TeleOp/BargeAlgaeTeleOp/ProcessorAlgaeTeleOp/CrossedField?/PlayedDefense?/TippedOrFellOver?/TouchedOpposingCage?/Died?/EndPosition/Defended?)\nDatos: " + processedText;
    Clipboard.setData(ClipboardData(text: prompt));
    html.window.open("https://chat.openai.com/", "_blank");
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Prompt copiado y ChatGPT abierto."))
    );
  }

  // New method to completely stop camera resources before navigation
  void _ensureCameraResourcesFreed() {
    if (kIsWeb) {
      // Set camera inactive to prevent restart on visibility change
      if (isCameraMode) {
        setState(() {
          isCameraMode = false;
        });
      }
      // Force recreation on next use
      _webScannerKey = UniqueKey();
    } else {
      // Stop mobile camera if active
      qrController?.pauseCamera();
      qrController?.dispose();
      qrController = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final bool isSmallScreen = screenSize.width < 600;
    
    // Define fixed container height for both ASCII and camera modes
    final double containerHeight = isSmallScreen ? 
        screenSize.height * 0.5 :  // 50% of screen height on mobile
        400;                       // Fixed height on desktop
    
    return Scaffold(
      appBar: AppBar(
        title: const Text("OverScouting Qr"),
        actions: [
          IconButton(
            icon: Icon(Icons.chat),
            onPressed: _sendToChatGPT,
            tooltip: "Enviar a ChatGPT",
          ),
          // New: Ranking table button
          TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ExcelGeneratorPage()),
              );
            },
            child: const Text(
              "Make Ranking Table",
              style: TextStyle(color: Colors.white),
            ),
          ),
          TextButton(
            onPressed: () {
              // Save current text to cache before navigating to TierListPage
              TextCacheService.cachedText = _textController.text;
              _ensureCameraResourcesFreed();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => TierListPage()),
              );
            },
            child: const Text(
              'TierList',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Toggle camera button in minimal space
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              TextButton(
                onPressed: toggleCameraMode,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                  minimumSize: Size(0, 20),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  isCameraMode ? "Mostrar ASCII" : "Usar Cámara",
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          
          // Fixed height container for both camera and ASCII
          Container(
            width: double.infinity,
            height: containerHeight,
            decoration: BoxDecoration(
              color: Colors.black,
              border: Border.all(color: Colors.grey.shade800),
              borderRadius: BorderRadius.circular(4.0),
            ),
            clipBehavior: Clip.antiAlias, // Make sure content is clipped to the border radius
            child: isCameraMode
              ? kIsWeb
                ? WebQRScanner(
                    key: _webScannerKey,
                    onScan: onQRCodeScanned,
                    compact: false,
                    containerHeight: containerHeight, // Pass height to WebQRScanner
                  )
                : QRView(
                    key: qrKey,
                    onQRViewCreated: _onQRViewCreated,
                  )
              : // Improved ASCII art display with better contrast and padding
                Container(
                  color: Colors.black,
                  padding: EdgeInsets.all(16),
                                    alignment: Alignment.center,
                  child: SingleChildScrollView(
                    child: Text(
                      asciiArt,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        color: Colors.lightGreenAccent,
                        fontSize: 14,
                        height: 1.2,
                      ),
                    ),
                  ),
                ),
          ),
          
          // Small gap before text area
          SizedBox(height: 8),
          
          // Text area and buttons, now with less space
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: RawKeyboardListener(
                    focusNode: _textFocusNode,
                    onKey: (RawKeyEvent event) {
                      // Insert tab on key down if Tab is pressed
                      if (event is RawKeyDownEvent && event.logicalKey == LogicalKeyboardKey.tab) {
                        final text = _textController.text;
                        final selection = _textController.selection;
                        final newText = text.replaceRange(selection.start, selection.end, "\t");
                        final newPosition = selection.start + 1;
                        _textController.value = TextEditingValue(
                          text: newText,
                          selection: TextSelection.collapsed(offset: newPosition),
                        );
                        // Re-request focus so the text field remains active
                        _textFocusNode.requestFocus();
                      }
                    },
                    child: TextField(
                      controller: _textController,
                      maxLines: null,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: "Ingrese los datos aquí...",
                      ),
                    ),
                  ),
                ),
                
                // More compact buttons row
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        onPressed: undoChange,
                        child: Text("Undo"),
                      ),
                      ElevatedButton(
                        onPressed: saveCsvAndTxt,
                        child: Text("Save CSV"),
                      ),
                    ],
                  ),
                ),
                
                // Smaller status area
                Container(
                  height: 32,
                  padding: EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black),
                  ),
                  child: SingleChildScrollView(
                    child: Text(statusMessage, style: TextStyle(fontSize: 12)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// New widget for web QR scanning
class WebQRScanner extends StatefulWidget {
  final Function(String) onScan;
  final bool compact;
  final double containerHeight; // Add parameter for container height
  
  const WebQRScanner({
    Key? key, 
    required this.onScan,
    this.compact = false,
    this.containerHeight = 400, // Default height
  }) : super(key: key);

  @override
  _WebQRScannerState createState() => _WebQRScannerState();
}

class _WebQRScannerState extends State<WebQRScanner> {
  html.VideoElement? _videoElement;
  Timer? _scanTimer; // Timer for periodic scanning
  final html.CanvasElement _scanCanvas = html.CanvasElement(); // Offscreen canvas for scanning  
  String? _errorMessage; // New state variable for camera errors
  // New: listen to page visibility changes
  StreamSubscription<html.Event>? _visibilitySubscription;
  String? _selectedDeviceId; // New: store selected camera device id
  String _cameraLabel = "Default camera"; // New: store camera label
  bool _cameraActive = true; // New flag to track if camera should be active
  bool _isPortrait = true;
  
  // Generate unique viewType ID for this instance
  String _uniqueViewType = 'web-qr-camera-${DateTime.now().millisecondsSinceEpoch}';

  // Improved camera selection with better UI
  Future<void> _selectCamera() async {
    try {
      // First request permissions to enumerate devices
      await html.window.navigator.mediaDevices!.getUserMedia({'video': true});
      
      final devices = await html.window.navigator.mediaDevices!.enumerateDevices();
      final videoDevices = devices.where((d) => d.kind == 'videoinput').toList();
      
      if (videoDevices.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("No cameras found on this device"))
        );
        return;
      }
      
      // Create a dialog to select camera instead of using prompt
      await showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text("Select Camera"),
            content: Container(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: videoDevices.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    title: Text(videoDevices[index].label.isEmpty 
                      ? "Camera ${index + 1}" 
                      : videoDevices[index].label),
                    onTap: () {
                      _selectedDeviceId = videoDevices[index].deviceId;
                      _cameraLabel = videoDevices[index].label.isEmpty 
                        ? "Camera ${index + 1}" 
                        : videoDevices[index].label;
                      Navigator.of(context).pop();
                      
                      // Fully stop current camera and start new one
                      _cleanupResources();
                      _initializeCamera();
                      
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Switched to $_cameraLabel"))
                      );
                    },
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text("Cancel"),
              ),
            ],
          );
        }
      );
    } catch (e) {
      print("Error selecting camera: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error selecting camera: $e"))
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    // Listen for visibility changes in web
    _visibilitySubscription = html.document.onVisibilityChange.listen((event) {
      if (html.document.visibilityState == 'hidden') {
        // Always stop camera when page is hidden
        _cleanupResources();
        _cameraActive = true; // Remember we should restart on visible
        print("Camera stopped due to page hidden.");
      } else if (html.document.visibilityState == 'visible') {
        // Only restart if we were previously active
        if (_cameraActive) {
          print("Page visible; reinitialize camera.");
          _initializeCamera();
        }
      }
    });
    // Check orientation at start
    _checkOrientation();
    _listenForOrientationChanges();
    
    // Add event listeners for orientation change
    html.window.addEventListener('resize', (_) => _checkOrientation());
    html.window.addEventListener('orientationchange', (_) => _checkOrientation());
  }

  // New: override didUpdateWidget to reinitialize camera if missing
  @override
  void didUpdateWidget(covariant WebQRScanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_videoElement == null && _cameraActive) {
      print("Camera element missing, reinitializing");
      _initializeCamera();
    }
  }

  // First _initializeCamera implementation removed to avoid duplication

  // Add a helper method to clean up resources
  void _cleanupResources() {
    print("Cleaning up camera resources...");
    _scanTimer?.cancel();
    _scanTimer = null;
    
    if (_videoElement != null && _videoElement!.srcObject != null) {
      try {
        final stream = _videoElement!.srcObject as html.MediaStream;
        stream.getTracks().forEach((track) {
          print("Stopping track: ${track.kind}");
          track.stop();
        });
        _videoElement!.srcObject = null;
      } catch (e) {
        print("Error stopping camera tracks: $e");
      }
    }
    _videoElement = null;
    _cameraActive = false; // Mark camera as inactive
  }

  // New helper method to apply a B&W high contrast filter.
  Uint8ClampedList _applyFilter(Uint8ClampedList data) {
    for (int i = 0; i < data.length; i += 4) {
      final r = data[i];
      final g = data[i + 1];
      final b = data[i + 2];
      // Compute luminance using standard weights.
      final gray = (0.299 * r + 0.587 * g + 0.114 * b).round();
      // Set high contrast: threshold at 128.
      final highContrast = gray > 128 ? 255 : 0;
      data[i] = highContrast;
      data[i + 1] = highContrast;
      data[i + 2] = highContrast;
      // Alpha remains unchanged.
    }
    return data;
  }

  // Modified _startScanning() with extra logs and faster scanning frequency.
  void _startScanning() {
    _scanTimer?.cancel(); // Cancel any existing timer first
    
    _scanTimer = Timer.periodic(Duration(milliseconds: 1000), (timer) { // Changed to 1 second
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      if (_videoElement != null && _videoElement!.readyState == 4) {
        print("Video dimensions: ${_videoElement!.videoWidth} x ${_videoElement!.videoHeight}");
        _scanCanvas.width = _videoElement!.videoWidth;
        _scanCanvas.height = _videoElement!.videoHeight;
        final ctx = _scanCanvas.context2D;
        ctx.drawImage(_videoElement!, 0, 0);
        final imageData = ctx.getImageData(0, 0, _scanCanvas.width!, _scanCanvas.height!);
        print("Scanning frame with ${imageData.data.length} pixels");

        // Apply filter to convert to black & white with high contrast.
        final filteredData = _applyFilter(imageData.data);
        
        try {
          dynamic jsQR = js.context['jsQR'];
          if (jsQR == null) {
            print("jsQR not found. Include jsQR library in index.html.");
// Stop scanning if jsQR is unavailable.
            timer.cancel();
            return;
          }
          final result = jsQR.apply([filteredData, _scanCanvas.width, _scanCanvas.height]);
          if (result != null && result['data'] != null) {
            print("QR Detected: ${result['data']}");
            widget.onScan(result['data']);
            
            //timer.cancel(); // Stop scanning after detection.
          } else {
            print("No QR detected, continuing scanning.");
            // Do not cancel the timer; simply continue scanning.
          }
        } catch (e) {
          print("Error in scanning: $e");
          // Ignore error and keep scanning.
        }
      }
    });
  }

  // Modified function to scan the current frame on demand with notifications
  void scanFrame() {
    if (_videoElement != null && _videoElement!.readyState == 4) {
      _scanCanvas.width = _videoElement!.videoWidth;
      _scanCanvas.height = _videoElement!.videoHeight;
      final ctx = _scanCanvas.context2D;
      ctx.drawImage(_videoElement!, 0, 0);
      final imageData = ctx.getImageData(0, 0, _scanCanvas.width!, _scanCanvas.height!);
      print("Manual scan: Video dimensions: ${_videoElement!.videoWidth} x ${_videoElement!.videoHeight}");
      try {
        dynamic jsQR = js.context['jsQR'];
        if (jsQR == null) {
          print("jsQR not found. Make sure to include it.");
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("jsQR not found. Include it in index.html."))
          );
          return;
        }
        final result = jsQR.apply([imageData.data, _scanCanvas.width, _scanCanvas.height]);
        if (result != null && result['data'] != null) {
          print("QR Detected via manual scan: ${result['data']}");
          widget.onScan(result['data']);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("QR detected and scanned!"))
          );
        } else {
          print("No QR detected on manual scan.");
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("No QR detected in this frame."))
          );
        }
      } catch (e) {
        print("Error scanning manually: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error scanning frame: $e"))
        );
      }
    }
  }

  // Check and update orientation state
  void _checkOrientation() {
    // Update orientation flag based on window dimensions
    setState(() {
      _isPortrait = html.window.innerHeight! > html.window.innerWidth!;
    });
  }
  
  // Add listener for orientation changes
  void _listenForOrientationChanges() {
    html.window.matchMedia("(orientation: portrait)").addListener((_) {
      _checkOrientation();
    });
  }
  
  // Helper method to check if device is mobile
  bool _isMobile() {
    return html.window.navigator.userAgent.contains('Mobile') || 
           html.window.navigator.userAgent.contains('Android') ||
           html.window.navigator.userAgent.contains('iPhone');
  }

  // Improved camera initialization with better display styling
  void _initializeCamera() async {
    _cleanupResources();
    
    try {
      setState(() {
        _errorMessage = "Accessing camera...";
      });
      
      // Define constraints for camera access
      Map<String, dynamic> constraints = {
        'video': _selectedDeviceId != null
            ? {'deviceId': {'exact': _selectedDeviceId}}
            : {'facingMode': 'environment'}, // Use back camera by default
        'audio': false
      };
      
      final stream = await html.window.navigator.mediaDevices!.getUserMedia(constraints);
      if (stream == null) throw "No camera stream available.";
      
      // Create video element with improved styling for fitting container height
      _videoElement = html.VideoElement()
        ..autoplay = true
        ..muted = true
        ..setAttribute('playsinline', 'true'); // Required for iOS
      
      // Set srcObject after other attributes
      _videoElement!.srcObject = stream;
      
      // Configure styling to focus on height while maintaining aspect ratio
      _videoElement!.style
        ..position = 'absolute'
        ..top = '0'
        ..left = '0'
        ..width = '100%'
        ..height = '${widget.containerHeight}px' // Explicitly set height
        ..minHeight = '100%'
        ..objectFit = 'cover' // Fill the container
        ..objectPosition = 'center' // Center the video content
        ..backgroundColor = 'black'; // Ensure black background
      
      // Register new factory with unique ID
      ui.platformViewRegistry.registerViewFactory(
        _uniqueViewType,
        (int viewId) => _videoElement!,
      );
      
      if (!mounted) return;
      
      setState(() {
        _errorMessage = null;
      });
      
      // Start scanning when video is ready
      _videoElement!.onCanPlay.listen((_) {
        if (mounted) {
          setState(() {
            _cameraActive = true;
          });
          _startScanning();
        }
      });
    } catch (e) {
      // Handle errors as before
      // ...existing error handling...
    }
  }

  // Add button for switching between front and back camera on mobile
  void _switchCamera() async {
    final isMobile = html.window.navigator.userAgent.contains('Mobile');
    if (!isMobile) return;
    
    try {
      final stream = _videoElement?.srcObject as html.MediaStream?;
      if (stream != null) {
        // Get current facingMode
        final videoTrack = stream.getVideoTracks().first;
        final settings = videoTrack.getSettings();
        final facingMode = settings['facingMode'];
        
        // Toggle facingMode
        final newFacingMode = facingMode == 'environment' ? 'user' : 'environment';
        
        // Stop current stream
        _cleanupResources();
        
        // Request new stream with toggled facingMode
        final newConstraints = {
          'video': {'facingMode': newFacingMode}
        };
        
        setState(() {
          _errorMessage = "Switching camera...";
        });
        
        // Re-initialize with new constraints
        final newStream = await html.window.navigator.mediaDevices!.getUserMedia(newConstraints);
        
        _videoElement = html.VideoElement()
          ..autoplay = true
          ..muted = true
          ..setAttribute('playsinline', 'true')
          ..srcObject = newStream
          ..style.height = '100%'
          ..style.width = '100%'
          ..style.objectFit = 'cover';
          
        // Register with new factory
        ui.platformViewRegistry.registerViewFactory(
          _uniqueViewType + 'switched',
          (int viewId) => _videoElement!,
        );
        
        if (!mounted) return;
        
        setState(() {
          _errorMessage = null;
          _uniqueViewType = _uniqueViewType + 'switched';
        });
        
        _videoElement!.onCanPlay.listen((_) {
          if (mounted) {
            _startScanning();
          }
        });
      }
    } catch (e) {
      print("Error switching camera: $e");
      // Revert to previous state
      _initializeCamera();
    }
  }
  
  @override
  Widget build(BuildContext context) {
    // Create a responsive layout based on screen size
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600 || 
                     html.window.navigator.userAgent.contains('Mobile');
    
    if (_errorMessage != null) {
      // More compact error display
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min, // Take minimum space needed
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error, color: Colors.red, size: widget.compact ? 16 : 32),
            SizedBox(height: 4),
            Text(
              _errorMessage!, 
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: widget.compact ? 10 : 14),
            ),
            SizedBox(height: 8),
            ElevatedButton(
              onPressed: _initializeCamera,
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size(0, 24),
              ),
              child: Text("Retry", style: TextStyle(fontSize: 10)),
            ),
          ],
        ),
      );
    }
    
    return _videoElement != null
        ? Container(
            width: double.infinity,
            height: widget.containerHeight, // Use the container height
            child: Stack(
              fit: StackFit.expand, // Make stack fill the container
              children: [
                // Camera view container
                Container(
                  width: double.infinity,
                  height: widget.containerHeight,
                  color: Colors.black,
                  child: HtmlElementView(viewType: _uniqueViewType),
                ),
                
                // Control buttons overlay
                Positioned(
                  bottom: 10,
                  right: 10,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FloatingActionButton.small(
                        onPressed: scanFrame,
                        child: Icon(Icons.qr_code_scanner, size: 16),
                        tooltip: "Scan Frame",
                      ),
                      SizedBox(height: 8),
                      FloatingActionButton.small(
                        onPressed: _selectCamera,
                        child: Icon(Icons.camera_alt, size: 16),
                        tooltip: "Select Camera",
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
        : Center( // Loading indicator when video element is null
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 10),
                Text("Initializing camera...", style: TextStyle(color: Colors.white)),
              ],
            ),
          );
  }
  
  @override
  void dispose() {
    _cleanupResources();
    _visibilitySubscription?.cancel();
    super.dispose();
  }
}