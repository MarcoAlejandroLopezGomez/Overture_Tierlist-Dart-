import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:collection/collection.dart'; // Import for mode calculation
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
  // UPDATED: Replaced with new column headers provided by the user
  final List<String> defaultColumnNames = [
    "Lead Scouter","Highlights Scouter Name", "Scouter Name", "Match Number",
    "Future Alliance in Qualy?", "Team Number",
    "Did something?", "Did Foul?", "Did auton worked?",
    "Coral L1 Scored", "Coral L2 Scored", "Coral L3 Scored", "Coral L4 Scored",
    "Played Algae?(Disloged NO COUNT)", "Algae Scored in Barge",
    "Crossed Feild/Played Defense?", "Tipped/Fell Over?",
    "Died?", "Was the robot Defended by someone?", "Yellow/Red Card", "Climbed?"
  ];

  // Header names are entered as comma-separated text.
  late TextEditingController _headerController;
  // Ensure sheetData always starts with a header row.
  List<List<String>> sheetData = [];
  // Maps to track column indices for easier reference
  Map<String, int> _columnIndices = {};
  // New: State variable to hold the names of columns selected for overall average calculation
  List<String> _selectedNumericColumnsForOverall = [];
  // New: State variable to hold the names of columns selected for the statistics table
  List<String> _selectedStatsColumns = [];
  // New: State variable to hold the names of boolean columns selected for mode calculation
  List<String> _modeBooleanColumns = [];
  
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
    _updateColumnIndices(); // This will also call _initializeSelectedColumns
    // Note: _initializeSelectedNumericColumns is called within _updateColumnIndices
    // Note: _initializeSelectedStatsColumns is called within _updateColumnIndices
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

  // Helper: compute mode from a list of strings.
  String calculateMode(List<String> values) {
    if (values.isEmpty) return 'N/A';
    // Filter out empty strings before calculating mode
    final non_empty_values = values.where((v) => v.trim().isNotEmpty).toList();
    if (non_empty_values.isEmpty) return 'N/A';

    final frequencyMap = non_empty_values.groupListsBy((element) => element);
    final sortedByFrequency = frequencyMap.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));
    return sortedByFrequency.first.key;
  }
  
  // Helper to find column indices by their names and initialize selections
  void _updateColumnIndices() {
    _columnIndices.clear();
    if (sheetData.isEmpty) return;
    
    List<String> header = sheetData.first;
    for (int i = 0; i < header.length; i++) {
      _columnIndices[header[i]] = i;
    }
    // Re-initialize selected columns if header changes
    _initializeSelectedNumericColumns();
    _initializeSelectedStatsColumns(); // Initialize stats columns
    // Mode columns are typically user-selected, maybe don't auto-reset? Or reset to empty?
    // Let's reset to empty for simplicity when header changes.
    _modeBooleanColumns = [];
  }

  // New: Initialize or update the list of columns used for overall average
  void _initializeSelectedNumericColumns() {
    // Default to coral and algae columns if not already set or if header changed
    // REMOVED: All 'Auto...' columns and 'Processor Algae Scored'
    // NOTE: 'Algae Scored in Barge' is NOT included in OVERALL average by default, only in specific stats
    List<String> defaultOverallColumns = [
      // Removed: 'Auto Coral L1 Scored', 'Auto Coral L2 Scored', 'Auto Coral L3 Scored', 'Auto Coral L4 Scored',
      // Removed: 'Auto Barge Algae Scored', 'Auto Processor Algae Scored',
      'Coral L1 Scored', 'Coral L2 Scored', 'Coral L3 Scored', 'Coral L4 Scored'
      // Removed: 'Processor Algae Scored'
      // Removed: 'Barge Algae Scored' (Old name)
    ];
    // Filter defaults to only include columns actually present in the current header
    List<String> currentHeader = sheetData.isNotEmpty ? sheetData.first : [];
    _selectedNumericColumnsForOverall = defaultOverallColumns
        .where((colName) => currentHeader.contains(colName))
        .toList();
    // If the filtered list is empty (e.g., custom header), try to find potential numeric columns
    if (_selectedNumericColumnsForOverall.isEmpty && sheetData.length > 1) {
       _selectedNumericColumnsForOverall = _findPotentialNumericColumns();
       // Ensure the specific teleop algae and auto columns are not accidentally included
       _selectedNumericColumnsForOverall.remove('Barge Algae Scored'); // Old name
       _selectedNumericColumnsForOverall.remove('Algae Scored in Barge'); // New name
       _selectedNumericColumnsForOverall.remove('Processor Algae Scored');
       _selectedNumericColumnsForOverall.remove('DidSomething?');
       _selectedNumericColumnsForOverall.remove('DidFoul?');
       _selectedNumericColumnsForOverall.remove('DidAutonWorked?');
       // Also remove old auto columns just in case they appear in a custom header
       _selectedNumericColumnsForOverall.remove('Auto Coral L1 Scored');
       _selectedNumericColumnsForOverall.remove('Auto Coral L2 Scored');
       _selectedNumericColumnsForOverall.remove('Auto Coral L3 Scored');
       _selectedNumericColumnsForOverall.remove('Auto Coral L4 Scored');
       _selectedNumericColumnsForOverall.remove('Auto Barge Algae Scored');
       _selectedNumericColumnsForOverall.remove('Auto Processor Algae Scored');
    }
  }

  // New: Initialize or update the list of columns shown in the statistics table
  void _initializeSelectedStatsColumns() {
      List<String> currentHeader = sheetData.isNotEmpty ? sheetData.first : [];
      // Default to all columns except scouter names initially
      List<String> defaultStatsCols = currentHeader
          .where((col) => col != "Lead Scouter" && col != "Scouter Name")
          .toList();

      // If _selectedStatsColumns is empty or header changed significantly, reset
      // For simplicity, let's just reset to default every time indices are updated.
      _selectedStatsColumns = defaultStatsCols;
  }

  // New: Helper to guess potential numeric columns based on data
  List<String> _findPotentialNumericColumns() {
      List<String> potentialColumns = [];
      if (sheetData.length < 2) return potentialColumns; // Need at least one data row

      List<String> header = sheetData.first;
      List<String> firstDataRow = sheetData[1];

      for (int j = 0; j < header.length; j++) {
          // Skip specific columns we don't want in overall average by default
          // ADDED: New auto boolean columns and old auto numeric columns to exclusion list
          // REMOVED: 'Barge Algae Scored' from exclusion
          if (header[j] == 'Team Number' ||
              // header[j] == 'Barge Algae Scored' || // Allow this (old name)
              // header[j] == 'Algae Scored in Barge' || // Allow this (new name) - Handled below by not being in this list
              header[j] == 'Processor Algae Scored' || // Exclude explicitly (if it exists)
              header[j] == 'End Position' || // Exclude explicitly
              header[j] == 'DidSomething?' || // Exclude explicitly
              header[j] == 'DidFoul?' || // Exclude explicitly
              header[j] == 'DidAutonWorked?' || // Exclude explicitly
              header[j] == 'Auto Coral L1 Scored' || // Exclude old auto explicitly
              header[j] == 'Auto Coral L2 Scored' || // Exclude old auto explicitly
              header[j] == 'Auto Coral L3 Scored' || // Exclude old auto explicitly
              header[j] == 'Auto Coral L4 Scored' || // Exclude old auto explicitly
              header[j] == 'Auto Barge Algae Scored' || // Exclude old auto explicitly
              header[j] == 'Auto Processor Algae Scored') continue; // Exclude old auto explicitly

          // Check if the value in the first data row looks numeric
          if (j < firstDataRow.length && double.tryParse(firstDataRow[j]) != null) {
              potentialColumns.add(header[j]);
          }
      }
      return potentialColumns;
  }

  // New: Helper to guess potential boolean columns based on data/name
  List<String> _findPotentialBooleanColumns() {
      List<String> potentialColumns = [];
      if (sheetData.isEmpty) return potentialColumns;

      List<String> header = sheetData.first;
      List<String> numericColumns = _findPotentialNumericColumns(); // Find numeric ones first

      for (int j = 0; j < header.length; j++) {
          String colName = header[j];
          // Skip identifying info and known numeric columns
          // ADDED: 'Algae Scored in Barge' to exclusion list for booleans
          if (colName == 'Team Number' ||
              colName == 'Match Number' ||
              colName == 'Lead Scouter' ||
              colName == 'Scouter Name' ||
              colName == 'Algae Scored in Barge' || // Treat as numeric
              numericColumns.contains(colName) ||
              _selectedNumericColumnsForOverall.contains(colName)) { // Also skip those selected for overall avg
              continue;
          }

          // Heuristic: Include columns with '?' or specific keywords, or generally non-numeric ones
          if (colName.contains('?') ||
              colName.toLowerCase().contains('did') ||
              colName.toLowerCase().contains('was') ||
              colName.toLowerCase().contains('played') ||
              colName.toLowerCase().contains('climbed') ||
              colName.toLowerCase().contains('card'))
          {
              potentialColumns.add(colName);
          }
          // Add other non-numeric columns as potential candidates (optional, might add noise)
          // else if (sheetData.length > 1 && j < sheetData[1].length && double.tryParse(sheetData[1][j]) == null) {
          //    potentialColumns.add(colName);
          // }
      }
      // Ensure uniqueness
      return potentialColumns.toSet().toList();
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
      // REMOVED: 'auto_coral' and 'auto_algae' groups
      // UPDATED: Added 'Algae Scored in Barge' back to teleop_algae
      Map<String, List<String>> coralAlgaeGroups = {
        // Removed: 'auto_coral': [
        // Removed: 'auto_algae': [
        'teleop_coral': [
          'Coral L1 Scored', 'Coral L2 Scored', 
          'Coral L3 Scored', 'Coral L4 Scored'
        ],
        'teleop_algae': [
          'Algae Scored in Barge' // Added back
          // Removed: 'Processor Algae Scored'
        ]
      };
      
      // Calculate separate statistics for each group (now includes teleop_algae)
      coralAlgaeGroups.forEach((groupName, columns) {
        // REMOVED: Skip condition for teleop_algae
        // if (groupName == 'teleop_algae') return;

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
        
        // Use _generateStatKey for group stats as well
        String avgKey = _generateStatKey(groupName, 'avg'); // e.g., teleop_algae_avg
        String stdKey = _generateStatKey(groupName, 'std'); // e.g., teleop_algae_std

        if (groupValues.isNotEmpty) {
          teamStats[avgKey] = average(groupValues);
          teamStats[stdKey] = standardDeviation(groupValues);
        } else {
          teamStats[avgKey] = 0.0;
          teamStats[stdKey] = 0.0;
        }
      });
      
      // Calculate statistics for individual coral/algae columns too
      // REMOVED: All 'Auto...' columns
      List<String> individualNumericColumns = [];
      coralAlgaeGroups.values.forEach((columns) => individualNumericColumns.addAll(columns));
      // Manually add back auto algae if needed, but exclude teleop algae
      // No longer needed to add auto algae here
      // individualNumericColumns.addAll([
      //     'Auto Barge Algae Scored', 'Auto Processor Algae Scored'
      // ]);
      // Ensure uniqueness and remove teleop algae again just in case
      individualNumericColumns = individualNumericColumns.toSet().toList();
      // REMOVED: Explicit removal of Barge/Processor Algae Scored
      // individualNumericColumns.remove('Barge Algae Scored');
      // individualNumericColumns.remove('Processor Algae Scored');
      // Remove auto columns explicitly in case they were added somehow
      individualNumericColumns.removeWhere((col) => col.startsWith('Auto'));


      for (String colName in individualNumericColumns) {
        int colIndex = _columnIndices[colName] ?? -1;
        if (colIndex == -1) continue;
        
        List<double> values = [];
        for (var row in rows) {
          if (row.length > colIndex) {
            double? val = double.tryParse(row[colIndex]);
            if (val != null) values.add(val);
          }
        }
        
        // Use _generateStatKey to create the keys consistent with formatStat
        String avgKey = _generateStatKey(colName, 'avg');
        String stdKey = _generateStatKey(colName, 'std');

        if (values.isNotEmpty) {
          teamStats[avgKey] = average(values);
          teamStats[stdKey] = standardDeviation(values);
        } else {
          // Ensure keys exist even if empty
          teamStats[avgKey] = 0.0;
          teamStats[stdKey] = 0.0;
        }
      }
      
      // Calculate defense rating specifically
      // UPDATED: Check for the new defense column name
      int defenseIndex = _columnIndices['Crossed Feild/Played Defense?'] ?? -1; // Changed from 'Defense?'
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
        
        // Use generated key for consistency
        String defenseRatingKey = _generateStatKey('Crossed Feild/Played Defense?', 'rate'); // Use rate for consistency
        if (defenseValues.isNotEmpty) {
          teamStats[defenseRatingKey] = average(defenseValues);
        } else {
          teamStats[defenseRatingKey] = 0.0;
        }
      } else {
         // Ensure key exists even if column is missing
         String defenseRatingKey = _generateStatKey('Crossed Feild/Played Defense?', 'rate');
         teamStats[defenseRatingKey] = 0.0;
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

      // Add boolean stats - Calculate BOTH rate and mode
      // Use the new helper to find potential boolean columns
      List<String> potentialBooleanColumns = _findPotentialBooleanColumns();
      // Also include columns previously identified as boolean even if helper misses them
      // REMOVED: 'Barge Algae Scored', 'Processor Algae Scored', 'End Position' from this list
      List<String> allBooleanColsToCheck = [
          ...potentialBooleanColumns,
          // Add back specific columns if needed, ensuring they are in the header
          'Moved?', // This might correspond to 'Did something?' now
          'Died?', 'No Show', 'Tipped/Fell Over?',
          // 'Barge Algae Scored', // Now numeric
          // 'Processor Algae Scored', // Removed
          // 'End Position', // Now 'Climbed?'
          'Did something?', 'Did Foul?', 'Did auton worked?',
          'Played Algae?(Disloged NO COUNT)', 'Crossed Feild/Played Defense?',
          'Was the robot Defended by someone?', 'Yellow/Red Card', 'Climbed?'
      ].toSet().where((col) => _columnIndices.containsKey(col)).toList(); // Ensure they exist in current header


      for (String colName in allBooleanColsToCheck) {
          int colIndex = _columnIndices[colName]!; // We know it exists from the check above

          List<double> boolValuesForRate = [];
          List<String> stringValuesForMode = []; // Store original strings for mode

          for (var row in rows) {
              if (row.length > colIndex) {
                  String value = row[colIndex].trim();
                  stringValuesForMode.add(value); // Add raw value for mode calculation

                  String lowerValue = value.toLowerCase();
                  // Rate calculation logic (same as before)
                  if (lowerValue.isNotEmpty && lowerValue != '0' && lowerValue != 'false' && lowerValue != 'no' && lowerValue != 'n') {
                      boolValuesForRate.add(1.0);
                  } else if (lowerValue == '0' || lowerValue == 'false' || lowerValue == 'no' || lowerValue == 'n' || lowerValue.isEmpty) {
                      boolValuesForRate.add(0.0);
                  }
              } else {
                 stringValuesForMode.add(''); // Add empty string if cell is missing
                 boolValuesForRate.add(0.0); // Assume false/0 for rate if missing
              }
          }

          // Always calculate rate
          String rateKey = _generateStatKey(colName, 'rate');
          teamStats[rateKey] = average(boolValuesForRate);

          // Calculate mode IF this column is selected for mode
          if (_modeBooleanColumns.contains(colName)) {
              String modeKey = _generateStatKey(colName, 'mode');
              teamStats[modeKey] = calculateMode(stringValuesForMode);
          }
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

  // Helper to generate consistent keys for stats map
  String _generateStatKey(String colName, String type) {
      // Handle group names first
      if (colName == 'teleop_coral' || colName == 'teleop_algae') {
          return '${colName}_$type';
      }

      String base = colName
          .replaceAll('?', '')
          .replaceAll('(Disloged NO COUNT)', '') // Old algae name part
          .replaceAll('(Disloged DOES NOT COUNT)', '') // New algae name part
          .replaceAll('/', '_')
          .replaceAll(' ', '_')
          .toLowerCase();
      // Handle specific renames if needed
      if (colName == 'End Position') base = 'climb'; // Old climb name
      if (colName == 'Climbed?') base = 'climb'; // New climb name
      if (colName == 'Did something?') base = 'auto_did_something';
      if (colName == 'Did Foul?') base = 'auto_did_foul';
      if (colName == 'Did auton worked?') base = 'auto_worked';
      if (colName == 'Barge Algae Scored') base = 'teleop_barge_algae'; // Old name
      if (colName == 'Algae Scored in Barge') base = 'teleop_barge_algae'; // New name
      if (colName == 'Processor Algae Scored') base = 'teleop_processor_algae'; // If it ever comes back
      if (colName == 'Played Algae?(Disloged NO COUNT)') base = 'teleop_played_algae'; // Old name
      if (colName == 'Played Algae?(Disloged DOES NOT COUNT)') base = 'teleop_played_algae'; // New name
      if (colName == 'Crossed Feild/Played Defense?') base = 'teleop_crossed_played_defense';
      if (colName == 'Was the robot Defended by someone?') base = 'defended_by_other';


      return '${base}_$type';
  }

  // New method to get defensive robot ranking
  List<Map<String, dynamic>> getDefensiveRobotRanking() {
    List<Map<String, dynamic>> allStats = getDetailedTeamStats();

    // Determine the correct key for defense rating
    String defenseRatingKey = _generateStatKey('Was the robot Defended by someone?', 'rate');
    // Fallback to old key if necessary? For now, assume new key.
    // String defenseRatingKey = _columnIndices.containsKey('Was the robot Defended by someone?')
    //     ? _generateStatKey('Was the robot Defended by someone?', 'rate')
    //     : 'defense_rating'; // Fallback, might be incorrect

    // Determine key for Moved Rate (assuming it corresponds to 'Did something?')
    String movedRateKey = _generateStatKey('Did something?', 'rate');
    // Fallback
    // String movedRateKey = _columnIndices.containsKey('Did something?')
    //     ? _generateStatKey('Did something?', 'rate')
    //     : 'Moved?_rate'; // Fallback

    // Determine key for Died Rate
    String diedRateKey = _generateStatKey('Died?', 'rate');


    // Filter for robots with defense_rating > 0 (not exactly 0)
    List<Map<String, dynamic>> defenseRobots = allStats
      .where((stats) => (stats[defenseRatingKey] ?? 0) > 0.0)
      .toList();

    // Sort by defense rating (descending)
    defenseRobots.sort((a, b) {
      double aDefense = a[defenseRatingKey] ?? 0.0;
      double bDefense = b[defenseRatingKey] ?? 0.0;
      return bDefense.compareTo(aDefense);
    });

    // Add the specific keys needed for the defensive table to the stats map if missing
    // This ensures the DataCells later don't crash
     defenseRobots = defenseRobots.map((stats) {
        stats['defense_rating_display'] = stats[defenseRatingKey] ?? 0.0;
        stats['moved_rate_display'] = stats[movedRateKey] ?? 0.0;
        stats['died_rate_display'] = stats[diedRateKey] ?? 0.0;
        return stats;
     }).toList();


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

  // New: Method to show a dialog for selecting columns for the statistics table
  Future<void> _showStatsColumnSelectionDialog() async {
    if (sheetData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please upload data first.")),
      );
      return;
    }

    List<String> availableColumns = List<String>.from(sheetData.first); // All columns
    List<String> currentlySelected = List<String>.from(_selectedStatsColumns);

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text("Select Columns for Statistics Table"),
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
                        setDialogState(() {
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
                    setState(() {
                      _selectedStatsColumns = currentlySelected;
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

   // New: Method to show a dialog for selecting boolean columns for mode calculation
  Future<void> _showModeColumnSelectionDialog() async {
    if (sheetData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please upload data first.")),
      );
      return;
    }

    List<String> availableColumns = _findPotentialBooleanColumns(); // Use helper
    if (availableColumns.isEmpty) {
       ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("No potential boolean columns found to select for mode.")),
      );
      return;
    }
    List<String> currentlySelected = List<String>.from(_modeBooleanColumns);

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text("Select Boolean Columns for Mode"),
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
                        setDialogState(() {
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
                    setState(() {
                      _modeBooleanColumns = currentlySelected;
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
    // Recalculate stats every build - might be inefficient for large data
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
            Wrap( // Use Wrap for better responsiveness
              spacing: 8.0, // Horizontal space between buttons
              runSpacing: 4.0, // Vertical space between button rows
              children: [
                ElevatedButton(
                  onPressed: uploadCSV,
                  child: const Text("Upload CSV"),
                ),
                ElevatedButton(
                  onPressed: _showColumnSelectionDialog,
                  child: const Text("Select Overall Columns"),
                ),
                // New Button to select stats columns
                ElevatedButton(
                  onPressed: _showStatsColumnSelectionDialog,
                  child: const Text("Select Stats Columns"),
                ),
                 // New Button to select mode columns
                ElevatedButton(
                  onPressed: _showModeColumnSelectionDialog,
                  child: const Text("Select Mode Columns"),
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
                 maxLines: 1,
               ),
             ),
             // Display selected stats columns
             Padding(
               padding: const EdgeInsets.only(top: 4.0),
               child: Text(
                 "Stats Table Columns: ${_selectedStatsColumns.join(', ')}",
                 style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: Colors.blue),
                 overflow: TextOverflow.ellipsis,
                 maxLines: 1,
               ),
             ),
             // Display selected mode columns
             Padding(
               padding: const EdgeInsets.only(top: 4.0),
               child: Text(
                 "Mode Columns: ${_modeBooleanColumns.join(', ')}",
                 style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: Colors.green),
                 overflow: TextOverflow.ellipsis,
                 maxLines: 1,
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
            // Second table - Team statistics
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
                                columnSpacing: 8,
                                // Use selected stats columns
                                columns: _buildStatsColumns(detailedStats.first),
                                rows: detailedStats.map((stats) {
                                  // Text formatting helper for avg±std
                                  String formatStat(String colName) {
                                     // Find the corresponding keys for avg and std
                                     String avgKey = _generateStatKey(colName, 'avg');
                                     String stdKey = _generateStatKey(colName, 'std');
                                     // Check if keys exist before accessing
                                     double avg = stats.containsKey(avgKey) ? (stats[avgKey] ?? 0.0) : 0.0;
                                     double std = stats.containsKey(stdKey) ? (stats[stdKey] ?? 0.0) : 0.0;
                                     return "${avg.toStringAsFixed(1)}±${std.toStringAsFixed(1)}";
                                  }
                                   // Helper for rates
                                   String formatRate(String colName) {
                                     String rateKey = _generateStatKey(colName, 'rate');
                                     // Check if key exists before accessing
                                     double rate = stats.containsKey(rateKey) ? (stats[rateKey] ?? 0.0) : 0.0;
                                     return rate.toStringAsFixed(2);
                                   }
                                   // Helper for mode
                                   String formatMode(String colName) {
                                     String modeKey = _generateStatKey(colName, 'mode');
                                     // Check if key exists before accessing
                                     return stats.containsKey(modeKey) ? (stats[modeKey]?.toString() ?? 'N/A') : 'N/A';
                                   }

                                  // Build cells based on _selectedStatsColumns
                                  List<DataCell> cells = _selectedStatsColumns.map((colName) {
                                      // Determine how to display based on column type and mode selection
                                      if (colName == 'Team Number' || colName == 'Team') {
                                          return DataCell(Text(stats['team'] ?? ''));
                                      } else if (_selectedNumericColumnsForOverall.contains(colName) ||
                                                 colName.startsWith('Coral L') || // Assume Coral L are numeric avg/std
                                                 colName == 'Algae Scored in Barge') { // Treat Algae Scored as numeric avg/std
                                          return DataCell(Text(formatStat(colName)));
                                      } else if (_modeBooleanColumns.contains(colName)) {
                                          // Display mode if selected
                                          return DataCell(Text(formatMode(colName)));
                                      } else if (_findPotentialBooleanColumns().contains(colName) ||
                                                 // Add other known booleans just in case helper missed them
                                                 // REMOVED: 'Barge Algae Scored', 'Processor Algae Scored', 'End Position'
                                                 ['Moved?', 'Died?', 'No Show', 'Tipped/Fell Over?',
                                                  // 'Barge Algae Scored',
                                                  // 'Processor Algae Scored',
                                                  // 'End Position',
                                                  'Did something?', 'Did Foul?', 'Did auton worked?',
                                                  'Played Algae?(Disloged NO COUNT)', // Old name
                                                  'Played Algae?(Disloged DOES NOT COUNT)', // New name
                                                  'Crossed Feild/Played Defense?',
                                                  'Was the robot Defended by someone?', 'Yellow/Red Card', 'Climbed?'].contains(colName)
                                                ) {
                                          // Display rate for booleans not selected for mode
                                          return DataCell(Text(formatRate(colName)));
                                      } else {
                                          // Fallback for unknown column types (display raw or empty)
                                          // Or try to display rate as a default?
                                          // Let's try formatStat as a fallback for potentially numeric columns missed earlier
                                          // Check if avg/std keys exist for this column
                                          String avgKey = _generateStatKey(colName, 'avg');
                                          if (stats.containsKey(avgKey)) {
                                              return DataCell(Text(formatStat(colName)));
                                          } else {
                                              // If no avg/std, maybe it's a rate?
                                              String rateKey = _generateStatKey(colName, 'rate');
                                              if (stats.containsKey(rateKey)) {
                                                  return DataCell(Text(formatRate(colName)));
                                              } else {
                                                  // Final fallback
                                                  return DataCell(Text(stats[colName]?.toString() ?? ''));
                                              }
                                          }
                                      }
                                  }).toList();

                                  return DataRow(cells: cells);
                                }).toList(),
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  : Container(
                      alignment: Alignment.center,
                      child: Text("No statistics available (requires data rows)."),
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
                      child: SingleChildScrollView( // Added outer vertical scroll
                        child: SingleChildScrollView( // Added inner horizontal scroll
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columns: const [ // Keep these columns fixed for defensive ranking
                              DataColumn(label: Text("Team")),
                              DataColumn(label: Text("Defense Rating")), // Uses 'Was the robot Defended by someone?' rate
                              DataColumn(label: Text("Overall Avg")),
                              DataColumn(label: Text("Died Rate")), // Uses 'Died?' rate
                              DataColumn(label: Text("Moved Rate")), // Uses 'Did something?' rate
                            ],
                            rows: defenseRobots.map((stats) {
                              return DataRow(
                                cells: [
                                  DataCell(Text(stats['team'] ?? '', 
                                    style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataCell(Text((stats['defense_rating_display'] ?? 0).toStringAsFixed(2), // Use the pre-calculated display key
                                    style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataCell(Text((stats['overall_avg'] ?? 0).toStringAsFixed(2))),
                                  DataCell(Text((stats['died_rate_display'] ?? 0).toStringAsFixed(2))), // Use the pre-calculated display key
                                  DataCell(Text((stats['moved_rate_display'] ?? 0).toStringAsFixed(2))), // Use the pre-calculated display key
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
  // Now uses _selectedStatsColumns
  List<DataColumn> _buildStatsColumns(Map<String, dynamic> sampleStats) {
    // Build columns based on the selected list
    return _selectedStatsColumns.map((colName) {
        // Simplify labels slightly for better fit (optional)
        String shortLabel = colName
            .replaceAll('Scored', '')
            .replaceAll('?(Disloged NO COUNT)', '?') // Old name
            .replaceAll('?(Disloged DOES NOT COUNT)', '?') // New name
            .replaceAll('Crossed Feild/Played Defense?', 'Cross/Def?')
            .replaceAll('Was the robot Defended by someone?', 'Defended By?')
            .replaceAll('Did something?', 'Auto Smth?')
            .replaceAll('Did Foul?', 'Auto Foul?')
            .replaceAll('Did auton worked?', 'Auto Wrk?')
            .replaceAll('Tipped/Fell Over?', 'Tipped?')
            .replaceAll('Yellow/Red Card', 'Card')
            .replaceAll('Algae Scored in Barge', 'Barge Algae') // Shorten
            .trim();
         // Add indication if it's a mode column
         if (_modeBooleanColumns.contains(colName)) {
             shortLabel += " (Mode)";
         }

        return DataColumn(label: Text(shortLabel, style: TextStyle(fontSize: 11)));
    }).toList();
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