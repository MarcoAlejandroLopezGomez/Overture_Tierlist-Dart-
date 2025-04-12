import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'main.dart';

void main() {
  runApp(MyApp());
}

class ExcelGeneratorPage extends StatefulWidget {
  final String? initialData; // Add optional parameter for initial data

  const ExcelGeneratorPage({Key? key, this.initialData}) : super(key: key);

  @override
  _ExcelGeneratorPageState createState() => _ExcelGeneratorPageState();
}

class _ExcelGeneratorPageState extends State<ExcelGeneratorPage> {
  // Pre-defined column names for this specific application
  final List<String> defaultColumnNames = [
    "Scouter Initials", "Match Number","Robot","Future Alliance in Qualy?","Team Number",
    "Starting Position","No Show", "Moved?", "Auto Coral L1 Scored", "Auto Coral L2 Scored", 
    "Auto Coral L3 Scored", "Auto Coral L4 Scored", "Auto Barge Algae Scored", 
    "Auto Processor Algae Scored", "Dislodged Algae?", "Auto Foul", "Dislodged Algae?", 
    "Pickup Location", "Coral L1 Scored", "Coral L2 Scored", "Coral L3 Scored", "Coral L4 Scored", 
    "Barge Algae Scored", "Processor Algae Scored", "Crossed Feild/Played Defense", "Tipped/Fell Over?",
    "Touched Opposing Cage?", "Died?", "End Position", "BROKE?","Defended?", "CoralHPMistake","Yellow/Red Card"
  ];

  // Header names are entered as comma-separated text.
  late TextEditingController _headerController;
  // Ensure sheetData always starts with a header row.
  List<List<String>> sheetData = [];
  // Maps to track column indices for easier reference
  Map<String, int> _columnIndices = {};
  // New: State variable to hold the names of columns selected for overall average calculation
  List<String> _selectedNumericColumnsForOverall = [];
  
  @override
  void initState() {
    super.initState();
    // Initialize _headerController with default column names
    _headerController = TextEditingController(text: defaultColumnNames.join(','));
    
    // Ensure sheetData starts with the header, even if empty initially
    if (sheetData.isEmpty) {
      sheetData.add(List<String>.from(defaultColumnNames)); // Use a copy
    }

    // New: Process initial data if provided
    if (widget.initialData != null && widget.initialData!.isNotEmpty) {
      _processInitialData(widget.initialData!);
    } else {
      // If no initial data, ensure the header controller matches sheetData[0]
      // (though it should already from initialization)
       _headerController.text = sheetData.first.join(',');
    }
    
    // After setting initial header, map column indices
    _updateColumnIndices();
    // Initialize selected columns for overall average (default to all coral/algae)
    _initializeSelectedNumericColumns();
  }

  @override
  void dispose() {
    _headerController.dispose();
    super.dispose();
  }
  
  // Helper: compute average from a list of doubles.
  double average(List<double> values) {
    if (values.isEmpty) return 0;
    return values.reduce((a, b) => a + b) / values.length;
  }

  // Helper: compute standard deviation from a list of doubles.
  double standardDeviation(List<double> values) {
    if (values.isEmpty) return 0;
    double avg = average(values);
    double sumSquaredDiffs = values.map((v) => pow(v - avg, 2) as double).reduce((a, b) => a + b);
    return sqrt(sumSquaredDiffs / values.length);
  }
  
  // Helper to find column indices by their names
  void _updateColumnIndices() {
    _columnIndices.clear();
    if (sheetData.isEmpty) return;
    
    List<String> header = sheetData.first;
    for (int i = 0; i < header.length; i++) {
      _columnIndices[header[i]] = i;
    }
    // Re-initialize selected columns if header changes
    _initializeSelectedNumericColumns();
  }

  // New: Initialize or update the list of columns used for overall average
  void _initializeSelectedNumericColumns() {
    // Default to coral and algae columns if not already set or if header changed
    List<String> defaultOverallColumns = [
      'Auto Coral L1 Scored', 'Auto Coral L2 Scored', 'Auto Coral L3 Scored', 'Auto Coral L4 Scored',
      'Auto Barge Algae Scored', 'Auto Processor Algae Scored',
      'Coral L1 Scored', 'Coral L2 Scored', 'Coral L3 Scored', 'Coral L4 Scored',
      'Barge Algae Scored', 'Processor Algae Scored'
    ];
    // Filter defaults to only include columns actually present in the current header
    List<String> currentHeader = sheetData.isNotEmpty ? sheetData.first : [];
    _selectedNumericColumnsForOverall = defaultOverallColumns
        .where((colName) => currentHeader.contains(colName))
        .toList();
    // If the filtered list is empty (e.g., custom header), try to find potential numeric columns
    if (_selectedNumericColumnsForOverall.isEmpty && sheetData.length > 1) {
       _selectedNumericColumnsForOverall = _findPotentialNumericColumns();
    }
  }

  // New: Helper to guess potential numeric columns based on data
  List<String> _findPotentialNumericColumns() {
      List<String> potentialColumns = [];
      if (sheetData.length < 2) return potentialColumns; // Need at least one data row

      List<String> header = sheetData.first;
      List<String> firstDataRow = sheetData[1];

      for (int j = 0; j < header.length; j++) {
          // Skip Team Number column
          if (header[j] == 'Team Number') continue;
          // Check if the value in the first data row looks numeric
          if (j < firstDataRow.length && double.tryParse(firstDataRow[j]) != null) {
              potentialColumns.add(header[j]);
          }
      }
      return potentialColumns;
  }
  
  // Upload and parse CSV file; append data to sheetData.
  Future<void> uploadCSV() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    if (result != null) {
      // Read file content
      String content;
      if (kIsWeb) {
        content = utf8.decode(result.files.first.bytes!);
      } else {
        content = await File(result.files.first.path!).readAsString();
      }
      List<List<String>> csvRows = [];
      for (var line in LineSplitter().convert(content)) {
        if (line.trim().isNotEmpty) {
          csvRows.add(line.split(','));
        }
      }

      if (csvRows.isEmpty) return; // Nothing to process

      setState(() {
        // Scenario 1: sheetData is empty or only has the initial default header.
        // Replace everything with the CSV content.
        if (sheetData.isEmpty || sheetData.length == 1) {
           sheetData = List<List<String>>.from(csvRows); // Use a copy
           // Update header controller to match the loaded CSV header
           _headerController.text = sheetData.first.join(',');
        }
        // Scenario 2: sheetData already has data (more than just the header row).
        // Append data from CSV, potentially skipping the CSV header.
        else {
          List<String> currentHeader = sheetData.first;
          List<String> csvHeader = csvRows.first;

          // Check if CSV header matches the current header in sheetData
          bool headersMatch = listEquals(currentHeader, csvHeader);

          if (headersMatch) {
            // Append only data rows (skip CSV header)
            sheetData.addAll(csvRows.sublist(1));
          } else {
            // Headers don't match. Append only data rows from CSV.
            // Keep the original header in sheetData[0].
            // Log a warning or notify user about potential mismatch?
            print("Warning: Uploaded CSV header does not match existing header. Appending data rows only.");
            sheetData.addAll(csvRows.sublist(1));
          }
        }
        _updateColumnIndices(); // Update indices after modifying data
      });
    }
  }

  // New: Method to process the initial data string passed from qr_scanner
  void _processInitialData(String data) {
     List<List<String>> qrRows = [];
     for (var line in LineSplitter().convert(data.trim())) {
       if (line.trim().isNotEmpty) {
         qrRows.add(line.split('\t'));
       }
     }

     if (qrRows.isEmpty) return; // No data from QR

     // Determine the header: Use default unless QR data strongly suggests a header.
     // For simplicity, we'll assume QR data does NOT contain a header row
     // and always use the default/current header.
     List<String> headerToUse = List<String>.from(defaultColumnNames); // Start with default
     // If sheetData wasn't empty and had a different header set before this, use that?
     // Let's stick to using defaultColumnNames when processing initial QR data for now.
     // Or better: use the header currently in the controller.
     headerToUse = _headerController.text.split(',');


     setState(() {
        // Clear existing data (keeping only the header or replacing it)
        sheetData.clear();
        sheetData.add(headerToUse); // Set the determined header
        sheetData.addAll(qrRows); // Add all QR rows as data

        // Ensure header controller matches
        _headerController.text = headerToUse.join(',');
     });
  }

  // Update header names manually.
  void updateHeader() {
    List<String> newHeader = _headerController.text.split(',').map((s) => s.trim()).toList();
    setState(() {
      if (sheetData.isEmpty) {
        // This case should ideally not happen due to initState logic
        sheetData.add(newHeader);
      } else {
        // Replace the first row (the header) with the new one
        sheetData[0] = newHeader;
      }
      _updateColumnIndices(); // Update indices based on the new header in sheetData[0]
    });
  }
  
  // Get detailed statistics for each team
  List<Map<String, dynamic>> getDetailedTeamStats() {
    if (sheetData.isEmpty || sheetData.length < 2) return [];
    
    // Get team numbers (assumed to be in column 3)
    int teamNumberColumn = _columnIndices['Team Number'] ?? -1;
    // Handle case where 'Team Number' column might be missing or named differently
    if (teamNumberColumn == -1) {
        print("Error: 'Team Number' column not found in header.");
        // Try finding a column named 'Team' as a fallback?
        teamNumberColumn = _columnIndices['Team'] ?? -1;
        if (teamNumberColumn == -1) return []; // Cannot proceed without team numbers
    }
    
    // Group all rows by team number
    Map<String, List<List<String>>> teamRows = {};
    for (int i = 1; i < sheetData.length; i++) {
      if (sheetData[i].length <= teamNumberColumn) continue;
      
      String teamNumber = sheetData[i][teamNumberColumn];
      teamRows.putIfAbsent(teamNumber, () => []).add(sheetData[i]);
    }
    
    // Calculate detailed stats for each team
    List<Map<String, dynamic>> detailedStats = [];
    teamRows.forEach((teamNumber, rows) {
      Map<String, dynamic> teamStats = {'team': teamNumber};
      
      // Define coral and algae column groups for more specific stats
      Map<String, List<String>> coralAlgaeGroups = {
        'auto_coral': [
          'Auto Coral L1 Scored', 'Auto Coral L2 Scored', 
          'Auto Coral L3 Scored', 'Auto Coral L4 Scored'
        ],
        'auto_algae': [
          'Auto Barge Algae Scored', 'Auto Processor Algae Scored'
        ],
        'teleop_coral': [
          'Coral L1 Scored', 'Coral L2 Scored', 
          'Coral L3 Scored', 'Coral L4 Scored'
        ],
        'teleop_algae': [
          'Barge Algae Scored', 'Processor Algae Scored'
        ]
      };
      
      // Calculate separate statistics for each group
      coralAlgaeGroups.forEach((groupName, columns) {
        List<double> groupValues = [];
        
        for (String colName in columns) {
          int colIndex = _columnIndices[colName] ?? -1;
          if (colIndex == -1) continue;
          
          for (var row in rows) {
            if (row.length > colIndex) {
              double? val = double.tryParse(row[colIndex]);
              if (val != null) groupValues.add(val);
            }
          }
        }
        
        if (groupValues.isNotEmpty) {
          teamStats[groupName + '_avg'] = average(groupValues);
          teamStats[groupName + '_std'] = standardDeviation(groupValues);
        } else {
          teamStats[groupName + '_avg'] = 0.0;
          teamStats[groupName + '_std'] = 0.0;
        }
      });
      
      // Calculate statistics for individual coral/algae columns too
      List<String> allCoralAlgaeColumns = [];
      coralAlgaeGroups.values.forEach((columns) => allCoralAlgaeColumns.addAll(columns));
      
      for (String colName in allCoralAlgaeColumns) {
        int colIndex = _columnIndices[colName] ?? -1;
        if (colIndex == -1) continue;
        
        List<double> values = [];
        for (var row in rows) {
          if (row.length > colIndex) {
            double? val = double.tryParse(row[colIndex]);
            if (val != null) values.add(val);
          }
        }
        
        if (values.isNotEmpty) {
          String simpleName = colName.replaceAll(' Scored', '').replaceAll(' ', '_').toLowerCase();
          teamStats[simpleName + '_avg'] = average(values);
          teamStats[simpleName + '_std'] = standardDeviation(values);
        } else {
          // Ensure keys exist even if empty
          String simpleName = colName.replaceAll(' Scored', '').replaceAll(' ', '_').toLowerCase();
          teamStats[simpleName + '_avg'] = 0.0;
          teamStats[simpleName + '_std'] = 0.0;
        }
      }
      
      // Calculate defense rating specifically
      int defenseIndex = _columnIndices['Defense?'] ?? -1;
      if (defenseIndex != -1) {
        List<double> defenseValues = [];
        for (var row in rows) {
          if (row.length > defenseIndex) {
            // Try parsing as double, fallback for boolean-like strings
            double? val = double.tryParse(row[defenseIndex]);
            if (val == null) {
               String lowerVal = row[defenseIndex].toLowerCase();
               if (lowerVal == 'true' || lowerVal == 'yes' || lowerVal == 'y') val = 1.0;
               else if (lowerVal == 'false' || lowerVal == 'no' || lowerVal == 'n') val = 0.0;
            }
            if (val != null) defenseValues.add(val);
          }
        }
        
        if (defenseValues.isNotEmpty) {
          teamStats['defense_rating'] = average(defenseValues);
        } else {
          teamStats['defense_rating'] = 0.0;
        }
      } else {
         teamStats['defense_rating'] = 0.0; // Ensure key exists
      }
      
      // Calculate overall performance metrics using SELECTED columns
      List<double> overallValues = [];
      // Use the state variable _selectedNumericColumnsForOverall
      _selectedNumericColumnsForOverall.forEach((colName) {
        int colIndex = _columnIndices[colName] ?? -1;
        if (colIndex == -1) return; // Skip if column not found

        for (var row in rows) {
          if (row.length > colIndex) {
            double? val = double.tryParse(row[colIndex]);
            if (val != null) overallValues.add(val);
          }
        }
      });

      if (overallValues.isNotEmpty) {
        teamStats['overall_avg'] = average(overallValues);
        teamStats['overall_std'] = standardDeviation(overallValues);
      } else {
        teamStats['overall_avg'] = 0.0;
        teamStats['overall_std'] = 0.0;
      }

      // Add boolean stats (Moved?, Died?, etc.) - Ensure these keys exist
      List<String> booleanColumns = ['Moved?', 'Died?', 'No Show', 'Tipped/Fell Over?'];
      for (String colName in booleanColumns) {
          int colIndex = _columnIndices[colName] ?? -1;
          if (colIndex != -1) {
              List<double> boolValues = [];
              for (var row in rows) {
                  if (row.length > colIndex) {
                      String value = row[colIndex].toLowerCase();
                      if (value == 'true' || value == 'yes' || value == '1' || value == 'y') {
                          boolValues.add(1.0);
                      } else if (value == 'false' || value == 'no' || value == '0' || value == 'n') {
                          boolValues.add(0.0);
                      }
                  }
              }
              teamStats[colName + '_rate'] = average(boolValues);
          } else {
              teamStats[colName + '_rate'] = 0.0; // Ensure key exists
          }
      }

      // Add End Position Mode - Ensure keys exist
      int posIndex = _columnIndices['End Position'] ?? -1;
      if (posIndex != -1) {
          Map<String, int> positions = {};
          for (var row in rows) {
              if (row.length > posIndex && row[posIndex].isNotEmpty) {
                  String pos = row[posIndex];
                  positions[pos] = (positions[pos] ?? 0) + 1;
              }
          }
          if (positions.isNotEmpty) {
              var sortedEntries = positions.entries.toList()
                  ..sort((a, b) => b.value.compareTo(a.value));
              teamStats['end_position_mode'] = sortedEntries.first.key;
              teamStats['end_position_count'] = sortedEntries.first.value;
          } else {
              teamStats['end_position_mode'] = 'N/A';
              teamStats['end_position_count'] = 0;
          }
      } else {
          teamStats['end_position_mode'] = 'N/A';
          teamStats['end_position_count'] = 0;
      }
      
      detailedStats.add(teamStats);
    });
    
    // Sort by overall average (descending)
    detailedStats.sort((a, b) {
      double aAvg = a['overall_avg'] ?? 0.0;
      double bAvg = b['overall_avg'] ?? 0.0;
      int cmp = bAvg.compareTo(aAvg);
      if (cmp == 0) {
        double aStd = a['overall_std'] ?? 999.0;
        double bStd = b['overall_std'] ?? 999.0;
        return aStd.compareTo(bStd); // Lower std is better
      }
      return cmp;
    });
    
    return detailedStats;
  }

  // New method to get defensive robot ranking
  List<Map<String, dynamic>> getDefensiveRobotRanking() {
    List<Map<String, dynamic>> allStats = getDetailedTeamStats();
    
    // Filter for robots with defense_rating > 0 (not exactly 0)
    List<Map<String, dynamic>> defenseRobots = allStats
      .where((stats) => (stats['defense_rating'] ?? 0) > 0.0)
      .toList();
    
    // Sort by defense rating (descending)
    defenseRobots.sort((a, b) {
      double aDefense = a['defense_rating'] ?? 0.0;
      double bDefense = b['defense_rating'] ?? 0.0;
      return bDefense.compareTo(aDefense);
    });
    
    return defenseRobots;
  }

  // New: Method to show a dialog for selecting numeric columns for overall average
  Future<void> _showColumnSelectionDialog() async {
    if (sheetData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please upload data first.")),
      );
      return;
    }

    List<String> availableColumns = sheetData.first
        .where((col) => col != 'Team Number') // Exclude Team Number
        .toList();
    // Try to pre-filter to likely numeric columns for a cleaner dialog
    List<String> potentialNumeric = _findPotentialNumericColumns();
    if (potentialNumeric.isNotEmpty) {
        availableColumns = potentialNumeric;
    }


    List<String> currentlySelected = List<String>.from(_selectedNumericColumnsForOverall);

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder( // Use StatefulBuilder to update dialog state
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text("Select Columns for Overall Average"),
              content: Container(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: availableColumns.length,
                  itemBuilder: (context, index) {
                    final colName = availableColumns[index];
                    final isSelected = currentlySelected.contains(colName);
                    return CheckboxListTile(
                      title: Text(colName),
                      value: isSelected,
                      onChanged: (bool? value) {
                        setDialogState(() { // Update dialog state
                          if (value == true) {
                            currentlySelected.add(colName);
                          } else {
                            currentlySelected.remove(colName);
                          }
                        });
                      },
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  child: Text("Cancel"),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                TextButton(
                  child: Text("OK"),
                  onPressed: () {
                    setState(() { // Update the main page state
                      _selectedNumericColumnsForOverall = currentlySelected;
                    });
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    List<String> header = sheetData.isNotEmpty ? sheetData.first : [];
    List<Map<String, dynamic>> detailedStats = getDetailedTeamStats();
    List<Map<String, dynamic>> defenseRobots = getDefensiveRobotRanking();
    
    return Scaffold(
      appBar: AppBar(
        title: const Text("Robot Ranking Table"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            // Header editing
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _headerController,
                    decoration: const InputDecoration(
                      labelText: "Column Names (comma separated; first column is Team)",
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: updateHeader,
                  child: const Text("Set Header"),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Buttons Row
            Row(
              children: [
                ElevatedButton(
                  onPressed: uploadCSV,
                  child: const Text("Upload CSV"),
                ),
                const SizedBox(width: 8), // Add spacing
                // New Button to select columns for overall average
                ElevatedButton(
                  onPressed: _showColumnSelectionDialog,
                  child: const Text("Select Overall Columns"),
                ),
              ],
            ),
             // Display selected columns (optional)
             Padding(
               padding: const EdgeInsets.only(top: 8.0),
               child: Text(
                 "Overall Avg Columns: ${_selectedNumericColumnsForOverall.join(', ')}",
                 style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic),
                 overflow: TextOverflow.ellipsis,
               ),
             ),
            const SizedBox(height: 12),
            // First table - Raw data with improved horizontal scrolling
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Raw Data", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: sheetData.length > 1 // Check if there's data beyond the header
                            ? SingleChildScrollView(
                                child: DataTable(
                                  columnSpacing: 8,
                                  dataRowMinHeight: 40,
                                  dataRowMaxHeight: 60,
                                  columns: header.map((name) => 
                                    DataColumn(
                                      label: Container(
                                        width: 100,
                                        child: Text(
                                          name,
                                          style: TextStyle(fontSize: 12),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      )
                                    )
                                  ).toList(),
                                  rows: List<DataRow>.generate(
                                    sheetData.length - 1,
                                    (i) {
                                      List<String> row = sheetData[i + 1];
                                      List<DataCell> cells = [];
                                      for (int j = 0; j < header.length; j++) {
                                        cells.add(
                                          DataCell(
                                            Container(
                                              width: 100,
                                              child: Text(
                                                j < row.length ? row[j] : '',
                                                style: TextStyle(fontSize: 12),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            onTap: () {
                                              if (j < row.length && row[j].isNotEmpty) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(
                                                    content: Text(row[j]),
                                                    duration: Duration(seconds: 2),
                                                  )
                                                );
                                              }
                                            },
                                          )
                                        );
                                      }
                                      return DataRow(cells: cells);
                                    },
                                  ),
                                ),
                              )
                            : const Center(child: Text("No data available (only header).")), // Updated message
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 12, thickness: 1),
            // Second table - Team statistics with horizontal scrolling - Modified to show each level separately
            Expanded(
              flex: 1,
              child: detailedStats.isNotEmpty
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Team Statistics", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: SingleChildScrollView(
                              child: DataTable(
                                columnSpacing: 8, // Smaller spacing to fit more columns
                                // Ensure columns are dynamically generated based on available stats
                                columns: _buildStatsColumns(detailedStats.first),
                                rows: detailedStats.map((stats) {
                                  // Text formatting helper for avg±std
                                  String formatStat(String prefix) {
                                    // Check if keys exist before accessing
                                    double avg = stats.containsKey('${prefix}_avg') ? (stats['${prefix}_avg'] ?? 0.0) : 0.0;
                                    double std = stats.containsKey('${prefix}_std') ? (stats['${prefix}_std'] ?? 0.0) : 0.0;
                                    return "${avg.toStringAsFixed(1)}±${std.toStringAsFixed(1)}";
                                  }
                                   // Helper for rates
                                   String formatRate(String key) {
                                     double rate = stats.containsKey(key) ? (stats[key] ?? 0.0) : 0.0;
                                     return rate.toStringAsFixed(2);
                                   }
                                   // Helper for end position
                                   String formatEndPos(Map<String, dynamic> stats) {
                                      String mode = stats.containsKey('end_position_mode') ? (stats['end_position_mode'] ?? 'N/A') : 'N/A';
                                      //int count = stats.containsKey('end_position_count') ? (stats['end_position_count'] ?? 0) : 0;
                                      // return "$mode ($count)"; // Optionally include count
                                      return mode;
                                   }

                                  return DataRow(
                                    cells: [
                                      DataCell(Text(stats['team'] ?? '')),
                                      DataCell(Text("${(stats['overall_avg'] ?? 0).toStringAsFixed(1)}±${(stats['overall_std'] ?? 0).toStringAsFixed(1)}")),
                                      // Auto Coral levels
                                      DataCell(Text(formatStat('auto_coral_l1'))),
                                      DataCell(Text(formatStat('auto_coral_l2'))),
                                      DataCell(Text(formatStat('auto_coral_l3'))),
                                      DataCell(Text(formatStat('auto_coral_l4'))),
                                      // Auto Algae types
                                      DataCell(Text(formatStat('auto_barge_algae'))),
                                      DataCell(Text(formatStat('auto_processor_algae'))),
                                      // TeleOp Coral levels
                                      DataCell(Text(formatStat('coral_l1'))),
                                      DataCell(Text(formatStat('coral_l2'))),
                                      DataCell(Text(formatStat('coral_l3'))),
                                      DataCell(Text(formatStat('coral_l4'))),
                                      // TeleOp Algae types
                                      DataCell(Text(formatStat('barge_algae'))),
                                      DataCell(Text(formatStat('processor_algae'))),
                                      // Other metrics - use helpers to ensure keys exist
                                      DataCell(Text(formatRate('Moved?_rate'))),
                                      DataCell(Text(formatRate('defense_rating'))),
                                      DataCell(Text(formatRate('Died?_rate'))),
                                      DataCell(Text(formatEndPos(stats))),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  : Container(
                      alignment: Alignment.center,
                      child: Text("No statistics available (requires data rows)."), // Updated message
                    ),
            ),
            
            // Defensive Robot Ranking
            if (defenseRobots.isNotEmpty) ...[
              const Divider(height: 12, thickness: 1),
              Expanded(
                flex: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Defensive Robot Ranking", 
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.orange)),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SingleChildScrollView(
                          child: DataTable(
                            columns: const [
                              DataColumn(label: Text("Team")),
                              DataColumn(label: Text("Defense Rating")),
                              DataColumn(label: Text("Overall Avg")),
                              DataColumn(label: Text("Died Rate")),
                              DataColumn(label: Text("Moved Rate")),
                            ],
                            rows: defenseRobots.map((stats) {
                              return DataRow(
                                cells: [
                                  DataCell(Text(stats['team'] ?? '', 
                                    style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataCell(Text((stats['defense_rating'] ?? 0).toStringAsFixed(2),
                                    style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataCell(Text((stats['overall_avg'] ?? 0).toStringAsFixed(2))),
                                  DataCell(Text((stats['Died?_rate'] ?? 0).toStringAsFixed(2))),
                                  DataCell(Text((stats['Moved?_rate'] ?? 0).toStringAsFixed(2))),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // New Helper function to build columns dynamically for the stats table
  List<DataColumn> _buildStatsColumns(Map<String, dynamic> sampleStats) {
    // Define the standard columns and their order
    List<String> columnOrder = [
      "Team", "Overall",
      "Auto L1", "Auto L2", "Auto L3", "Auto L4",
      "Auto Barge", "Auto Processor",
      "TeleOp L1", "TeleOp L2", "TeleOp L3", "TeleOp L4",
      "TeleOp Barge", "TeleOp Processor",
      "Moved?", "Defense", "Died?", "End Pos"
    ];

    return columnOrder.map((label) => DataColumn(label: Text(label))).toList();
  }

  // Helper function to check list equality
  bool listEquals<T>(List<T>? a, List<T>? b) {
    if (a == null) return b == null;
    if (b == null || a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) {
        return false;
      }
    }
    return true;
  }
}