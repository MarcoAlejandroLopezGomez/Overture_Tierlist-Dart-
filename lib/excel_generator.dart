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
  const ExcelGeneratorPage({Key? key}) : super(key: key);
  
  @override
  _ExcelGeneratorPageState createState() => _ExcelGeneratorPageState();
}

class _ExcelGeneratorPageState extends State<ExcelGeneratorPage> {
  // Pre-defined column names for this specific application
  final List<String> defaultColumnNames = [
    "Scouter Initials", "Match Number", "Starting Position", "Future Alliance in Qualy?",
    "Team Number", "No Show", "Moved?", "Auto Coral L1 Scored", "Auto Coral L2 Scored", 
    "Auto Coral L3 Scored", "Auto Coral L4 Scored", "Auto Barge Algae Scored", 
    "Auto Processor Algae Scored", "Dislodged Algae?", "Auto Foul", "Dislodged Algae?", 
    "Pickup Location", "Coral L1 Scored", "Coral L2 Scored", "Coral L3 Scored", "Coral L4 Scored", 
    "Barge Algae Scored", "Processor Algae Scored", "Crossed Feild/Played", "Defense?", 
    "Tipped/Fell Over?", "Touched Opposing Cage?", "Died?", "End Position", "Defended?", "Yellow/Red Card"
  ];

  // Header names are entered as comma-separated text.
  late TextEditingController _headerController;
  // The sheet data: first row is header; subsequent rows are data.
  List<List<String>> sheetData = [];
  // Maps to track column indices for easier reference
  Map<String, int> _columnIndices = {};
  
  @override
  void initState() {
    super.initState();
    // Initialize _headerController with default column names
    _headerController = TextEditingController(text: defaultColumnNames.join(','));
    
    // Set the initial header in sheetData if it's empty
    if (sheetData.isEmpty) {
      sheetData.add(defaultColumnNames);
    }
    
    // After setting initial header, map column indices
    _updateColumnIndices();
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
      List<List<String>> rows = [];
      for (var line in LineSplitter().convert(content)) {
        if (line.trim().isNotEmpty) {
          // Split on commas
          rows.add(line.split(','));
        }
      }
      setState(() {
        // If we already have data, append; otherwise, use uploaded header if available.
        if (sheetData.isEmpty && rows.isNotEmpty) {
          sheetData = rows;
          _headerController.text = rows.first.join(',');
        } else {
          // Append rows (skip header row if present)
          if (rows.isNotEmpty && rows.first.join(',') == _headerController.text) {
            rows.removeAt(0);
          }
          sheetData.addAll(rows);
        }
        _updateColumnIndices();
      });
    }
  }
  
  // Update header names manually.
  void updateHeader() {
    List<String> newHeader = _headerController.text.split(',');
    setState(() {
      if (sheetData.isEmpty) {
        sheetData.add(newHeader);
      } else {
        sheetData[0] = newHeader;
      }
      _updateColumnIndices();
    });
  }
  
  // Get detailed statistics for each team
  List<Map<String, dynamic>> getDetailedTeamStats() {
    if (sheetData.isEmpty || sheetData.length < 2) return [];
    
    // Get team numbers (assumed to be in column 3)
    int teamNumberColumn = _columnIndices['Team Number'] ?? 3;
    
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
        }
      }
      
      // Calculate defense rating specifically
      int defenseIndex = _columnIndices['Defense?'] ?? -1;
      if (defenseIndex != -1) {
        List<double> defenseValues = [];
        for (var row in rows) {
          if (row.length > defenseIndex) {
            double? val = double.tryParse(row[defenseIndex]);
            if (val != null) defenseValues.add(val);
          }
        }
        
        if (defenseValues.isNotEmpty) {
          teamStats['defense_rating'] = average(defenseValues);
        } else {
          teamStats['defense_rating'] = 0.0;
        }
      }
      
      // Calculate overall performance metrics for all coral/algae
      List<double> allValues = [];
      allCoralAlgaeColumns.forEach((colName) {
        int colIndex = _columnIndices[colName] ?? -1;
        if (colIndex == -1) return;
        
        for (var row in rows) {
          if (row.length > colIndex) {
            double? val = double.tryParse(row[colIndex]);
            if (val != null) allValues.add(val);
          }
        }
      });
      
      if (allValues.isNotEmpty) {
        teamStats['overall_avg'] = average(allValues);
        teamStats['overall_std'] = standardDeviation(allValues);
      } else {
        teamStats['overall_avg'] = 0.0;
        teamStats['overall_std'] = 0.0;
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
            Row(
              children: [
                ElevatedButton(
                  onPressed: uploadCSV,
                  child: const Text("Upload CSV"),
                ),
              ],
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
                        child: sheetData.isNotEmpty
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
                            : const Text("No data available."),
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
                                columns: const [
                                  DataColumn(label: Text("Team")),
                                  DataColumn(label: Text("Overall")),
                                  // Auto Coral columns (separate for each level)
                                  DataColumn(label: Text("Auto L1")),
                                  DataColumn(label: Text("Auto L2")),
                                  DataColumn(label: Text("Auto L3")),
                                  DataColumn(label: Text("Auto L4")),
                                  // Auto Algae columns
                                  DataColumn(label: Text("Auto Barge")),
                                  DataColumn(label: Text("Auto Processor")),
                                  // TeleOp Coral columns (separate for each level)
                                  DataColumn(label: Text("TeleOp L1")),
                                  DataColumn(label: Text("TeleOp L2")),
                                  DataColumn(label: Text("TeleOp L3")),
                                  DataColumn(label: Text("TeleOp L4")),
                                  // TeleOp Algae columns
                                  DataColumn(label: Text("TeleOp Barge")),
                                  DataColumn(label: Text("TeleOp Processor")),
                                  // Other metrics
                                  DataColumn(label: Text("Moved?")),
                                  DataColumn(label: Text("Defense")),
                                  DataColumn(label: Text("Died?")),
                                  DataColumn(label: Text("End Pos")),
                                ],
                                rows: detailedStats.map((stats) {
                                  // Text formatting helper for avg±std
                                  String formatStat(String prefix) {
                                    double avg = stats['${prefix}_avg'] ?? 0.0;
                                    double std = stats['${prefix}_std'] ?? 0.0;
                                    return "${avg.toStringAsFixed(1)}±${std.toStringAsFixed(1)}";
                                  }
                                  
                                  return DataRow(
                                    cells: [
                                      DataCell(Text(stats['team'] ?? '')),
                                      DataCell(Text("${(stats['overall_avg'] ?? 0).toStringAsFixed(1)}±${(stats['overall_std'] ?? 0).toStringAsFixed(1)}")),
                                      // Auto Coral levels (individual)
                                      DataCell(Text(formatStat('auto_coral_l1'))),
                                      DataCell(Text(formatStat('auto_coral_l2'))),
                                      DataCell(Text(formatStat('auto_coral_l3'))),
                                      DataCell(Text(formatStat('auto_coral_l4'))),
                                      // Auto Algae types
                                      DataCell(Text(formatStat('auto_barge_algae'))),
                                      DataCell(Text(formatStat('auto_processor_algae'))),
                                      // TeleOp Coral levels (individual)
                                      DataCell(Text(formatStat('coral_l1'))),
                                      DataCell(Text(formatStat('coral_l2'))),
                                      DataCell(Text(formatStat('coral_l3'))),
                                      DataCell(Text(formatStat('coral_l4'))),
                                      // TeleOp Algae types
                                      DataCell(Text(formatStat('barge_algae'))),
                                      DataCell(Text(formatStat('processor_algae'))),
                                      // Other metrics
                                      DataCell(Text((stats['Moved?_rate'] ?? 0).toStringAsFixed(2))),
                                      DataCell(Text((stats['defense_rating'] ?? 0).toStringAsFixed(2))),
                                      DataCell(Text((stats['Died?_rate'] ?? 0).toStringAsFixed(2))),
                                      DataCell(Text("${stats['end_position_mode'] ?? 'N/A'}")),
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
                      child: Text("No statistics available"),
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
}