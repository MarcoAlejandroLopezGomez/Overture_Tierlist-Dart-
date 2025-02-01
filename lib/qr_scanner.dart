import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' as ex; // Paquete para generar archivos Excel
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:html' as html; // Only used on web
import 'dart:typed_data';
import 'main.dart'; // Agrega esta línea para navegar a TierListPage

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
  final String asciiArt = """
        
    .___                 ____                  _   _                ___       
  ../ _ \__   _____ _ __/ ___|  ___ __ _ _   _| |_(_)_ __   __ _   / _ \ _ __ 
  .| | | \ \ / / _ \ '__\___ \ / __/ _` | | | | __| | '_ \ / _` | | | | | '__|
  .| |_| |\ V /  __/ |   ___) | (_| (_| | |_| | |_| | | | | (_| | | |_| | |   
    \___/  \_/ \___|_|  |____/ \___\__,_|\__,_|\__|_|_| |_|\__, |  \__\_\_|   
                                                          |___/              
        by FIRST FRC Team Overture - 7421        

        Bienvenido a OverScouting Qr, la herramienta de compilación de datos por QR.
        Agradecemos la aplicación de QRScout de Red Hawk Robotics 2713.
  """;

  // Controlador para el área de texto principal
  final TextEditingController _textController = TextEditingController();

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

    // Utiliza file_picker para pedirle al usuario la ubicación y nombre del archivo CSV
    String? selectedPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Save CSV',
      fileName: 'data.csv',
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );

    if (selectedPath == null) {
      updateStatus("Save operation cancelled.", displayInMainTextArea: true);
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

      // Guarda el archivo TXT (reemplazando tabulaciones por comas)
      File txtFile = File(exportFilenameTxt);
      String txtContent = content.replaceAll('\t', ',');
      await txtFile.writeAsString(txtContent);

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
      updateStatus("Data saved to CSV and TXT successfully.", displayInMainTextArea: true);
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
      updateStatus("Failed to save files: $e", displayInMainTextArea: true);
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
        updateStatus("Excel file saved successfully.", displayInMainTextArea: true);
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
    updateStatus("Failed to save Excel file: $e", displayInMainTextArea: true);
  }
}


  @override
  void dispose() {
    autosaveTimer?.cancel();
    _textController.dispose();
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
            // Área para mostrar el ASCII art en un contenedor scrollable
            Container(
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
            // Área principal de texto con scroll para ingresar datos
            Expanded(
              child: TextField(
                controller: _textController,
                maxLines: null,
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: "Ingrese los datos aquí...",
                ),
              ),
            ),
            SizedBox(height: 10),
            // Fila de botones para las acciones: Add Entry, Undo, Save CSV y Save In Excel
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
