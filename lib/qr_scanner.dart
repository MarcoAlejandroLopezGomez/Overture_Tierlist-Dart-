import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' as ex; // Paquete para generar archivos Excel
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:html' as html; // Only used on web
import 'package:qr_code_scanner/qr_code_scanner.dart';  // Import for QR code scanning
import 'main.dart'; // Agrega esta línea para navegar a TierListPage
import 'dart:ui' as ui; // New import for web view registry
import 'dart:js' as js; // New import for calling jsQR

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

class _OverScoutingAppState extends State<OverScoutingApp> {
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

  // New function to toggle camera preview mode
  void toggleCameraMode() {
    setState(() {
      isCameraMode = !isCameraMode;
    });
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
  /// Se utiliza un diálogo para que el usuario elija la ubicación del archivo CSV.
  Future<void> saveCsvAndTxt() async {
    String content = _textController.text.trim();
    if (content.isEmpty) {
      // Muestra un diálogo de advertencia si no hay contenido
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
      // Web: generate CSV content and download
      List<String> lines = content.split('\n');
      List<List<String>> dataList = lines.where((line) => line.isNotEmpty)
          .map((line) => line.split('\t')).toList();
      String csvContent = dataList.map((row) => row.join(',')).join('\n');
      
      // Trigger CSV download
      final csvBlob = html.Blob([csvContent], 'text/csv');
      final csvUrl = html.Url.createObjectUrlFromBlob(csvBlob);
      final csvAnchor = html.AnchorElement(href: csvUrl)
        ..setAttribute("download", "data.csv")
        ..click();
      html.Url.revokeObjectUrl(csvUrl);
      
      // Web: generate TXT content by replacing tabs with commas and download
      String txtContent = content.replaceAll('\t', ',');
      final txtBlob = html.Blob([txtContent], 'text/plain');
      final txtUrl = html.Url.createObjectUrlFromBlob(txtBlob);
      final txtAnchor = html.AnchorElement(href: txtUrl)
        ..setAttribute("download", "data.txt")
        ..click();
      html.Url.revokeObjectUrl(txtUrl);
      
      updateStatus("Data saved to CSV and TXT successfully.");
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

/// Guarda el contenido actual en un archivo Excel.
/// Para cada tabulación se crea una columna. Se salta la primera fila y la primera columna,
/// escribiendo los datos a partir de la celda B2 (índices [1,1]).
Future<void> saveInExcel() async {
  String content = _textController.text.trim();
  if (content.isEmpty) {
    // Muestra un diálogo de advertencia si no hay contenido
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Warning"),
          content: Text("There is no content to save."),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text("OK"),
            )
          ],
        );
      },
    );
    return;
  }

  try {
    // Crea un nuevo objeto Excel y usa la hoja por defecto "Sheet1"
    var excel = ex.Excel.createExcel();
    var sheet = excel['Sheet1'];

    // Separa el contenido en líneas
    List<String> lines = content.split('\n');

    // Se recorre cada línea, pero se salta la primera (i = 0) para dejar la primera fila vacía
    for (int i = 1; i < lines.length; i++) {
      // Separa cada línea en columnas usando la tabulación.
      // Se salta la primera columna (j = 0) para dejarla vacía.
      List<String> rowData = lines[i].split('\t');
      for (int j = 1; j < rowData.length; j++) {
        // Escribe el dato en la celda con índices desplazados:
        // la primera fila (índice 0) y la primera columna (índice 0) quedarán vacías.
        sheet
            .cell(ex.CellIndex.indexByColumnRow(columnIndex: j, rowIndex: i))
            .value = rowData[j];
      }
    }

    // Codifica el archivo Excel a bytes
    final encodedBytes = excel.encode();
    if (encodedBytes == null) {
      throw "Error encoding Excel file.";
    }
    final fileBytes = Uint8List.fromList(encodedBytes);

    // Guarda el archivo según la plataforma
    if (kIsWeb) {
      final blob = html.Blob(fileBytes,
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)
        ..setAttribute("download", "data.xlsx")
        ..click();
      html.Url.revokeObjectUrl(url);
    } else {
      // Permite al usuario seleccionar la ruta de guardado para el archivo Excel
      String? selectedPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Excel',
        fileName: 'data.xlsx',
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );
      if (selectedPath != null) {
        File file = File(selectedPath);
        await file.writeAsBytes(fileBytes, flush: true); // Asegura que se escriban todos los bytes
        updateStatus("Excel file saved successfully.");
      }
    }
  } catch (e) {
    // En caso de error, muestra un diálogo y actualiza el mensaje de estado
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Error"),
          content: Text("Failed to save Excel file: $e"),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text("OK"),
            )
          ],
        );
      },
    );
    updateStatus("Failed to save Excel file: $e");
  }
}


  @override
  void dispose() {
    qrController?.dispose();
    autosaveTimer?.cancel();
    _textController.dispose();
    // Dispose the added FocusNode
    _textFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Barra de aplicación con título
      appBar: AppBar(
        title: const Text("OverScouting Qr"),
        actions: [
          TextButton(
            onPressed: () {
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
      body: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          children: [
            // Modified container: display either ASCII art or camera preview
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: toggleCameraMode,
                  child: Text(isCameraMode ? "Mostrar ASCII" : "Usar Cámara"),
                ),
              ],
            ),
            // Modified container: display either ASCII art, mobile QRView, or web camera preview via WebQRScanner
            isCameraMode
                ? Container(
                    height: 200,
                    color: Colors.black,
                    child: kIsWeb
                        ? WebQRScanner(
                            onScan: (code) {
                              onQRCodeScanned(code);
                            },
                          )
                        : QRView(
                            key: qrKey,
                            onQRViewCreated: _onQRViewCreated,
                          ),
                  )
                : Container(
                    height: 200,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.black),
                    ),
                    child: SingleChildScrollView(
                      child: Text(
                        asciiArt,
                        style: TextStyle(fontFamily: 'monospace'),
                      ),
                    ),
                  ),
            SizedBox(height: 10),
            // Wrap the MainTextArea with RawKeyboardListener to capture Tab key
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
            SizedBox(height: 10),
            // Fila de botones para las acciones: Undo, Save CSV y Save In Excel
            Row(
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
                ElevatedButton(
                  onPressed: saveInExcel,
                  child: Text("Save In Excel"),
                ),
              ],
            ),
            SizedBox(height: 10),
            // Área para mostrar mensajes de estado en un contenedor scrollable
            Container(
              height: 50,
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black),
              ),
              child: SingleChildScrollView(
                child: Text(statusMessage),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// New widget for web QR scanning
class WebQRScanner extends StatefulWidget {
  final Function(String) onScan;
  const WebQRScanner({Key? key, required this.onScan}) : super(key: key);

  @override
  _WebQRScannerState createState() => _WebQRScannerState();
}

class _WebQRScannerState extends State<WebQRScanner> {
  html.VideoElement? _videoElement;
  Timer? _scanTimer; // Timer for periodic scanning
  final html.CanvasElement _scanCanvas = html.CanvasElement(); // Offscreen canvas for scanning  
  String? _errorMessage; // New state variable for camera errors

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  // Modified camera initialization with error handling
  void _initializeCamera() async {
    try {
      final stream = await html.window.navigator.mediaDevices!
          .getUserMedia({'video': true});
      if (stream == null) {
        throw "No camera stream available.";
      }
      _videoElement = html.VideoElement()
        ..autoplay = true
        ..srcObject = stream;
      // Register the video element for HtmlElementView
      // ignore:undefined_prefixed_name
      ui.platformViewRegistry.registerViewFactory(
        'web-qr-camera',
        (int viewId) => _videoElement!,
      );
      setState(() {
        _errorMessage = null;
      });
      _startScanning(); // Begin scanning once camera is ready
    } catch (e) {
      print("Error accessing camera: $e");
      setState(() {
        _errorMessage = "Error accessing camera: $e";
        _videoElement = null;
      });
    }
  }

  // Modified _startScanning() with extra logs and faster scanning frequency.
  void _startScanning() {
    _scanTimer = Timer.periodic(Duration(milliseconds: 200), (timer) {
      if (_videoElement != null && _videoElement!.readyState == 4) {
        print("Video dimensions: ${_videoElement!.videoWidth} x ${_videoElement!.videoHeight}");
        _scanCanvas.width = _videoElement!.videoWidth;
        _scanCanvas.height = _videoElement!.videoHeight;
        final ctx = _scanCanvas.context2D;
        ctx.drawImage(_videoElement!, 0, 0);
        final imageData = ctx.getImageData(0, 0, _scanCanvas.width!, _scanCanvas.height!);
        print("Scanning frame with ${imageData.data.length} pixels");
        try {
          dynamic jsQR = js.context['jsQR'];
          if (jsQR == null) {
            print("jsQR not found. Include jsQR library in index.html.");
            timer.cancel();
            return;
          }
          final result = jsQR.apply([imageData.data, _scanCanvas.width, _scanCanvas.height]);
          if (result != null && result['data'] != null) {
            print("QR Detected: ${result['data']}");
            widget.onScan(result['data']);
            timer.cancel();
          } else {
            print("No QR detected in this frame.");
          }
        } catch (e) {
          print("Error in scanning: $e");
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

  @override
  void dispose() {
    _scanTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // If there was an error, display it.
    if (_errorMessage != null) {
      return Center(child: Text(_errorMessage!));
    }
    return _videoElement != null
        ? Stack(
            children: [
              HtmlElementView(viewType: 'web-qr-camera'),
              Positioned(
                bottom: 10,
                right: 10,
                child: ElevatedButton(
                  onPressed: () {
                    widget.onScan("Código QR Web");
                  },
                  child: Text("Simular escaneo QR"),
                ),
              ),
              // New button to scan the current frame on demand
              Positioned(
                bottom: 10,
                left: 10,
                child: ElevatedButton(
                  onPressed: scanFrame,
                  child: Text("Escanear frame"),
                ),
              ),
            ],
          )
        : Center(child: Text("Accediendo a la cámara..."));
  }
}
