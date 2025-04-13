# Overture FRC Scouting Suite (Tierlist, QR Scanner, Ranking)

This Flutter application provides a suite of tools designed for FIRST Robotics Competition (FRC) scouting, developed by Team 7421 Overture. It combines data collection via QR codes, data analysis and ranking, and a visual tier list for strategic decision-making.

## Core Features

1.  **QR Scanner (`qr_scanner.dart`):**
    *   Scans QR codes containing scouting data (likely tab-separated).
    *   Supports both mobile camera (`qr_code_scanner`) and web camera (using `dart:html`, `dart:js`, and the `jsQR` library).
    *   Appends scanned data to a text area.
    *   Includes features like undo, save to CSV/TXT, autosave (desktop/mobile), and a button to send data to ChatGPT (via clipboard).
    *   Plays a beep sound on successful scan (`audioplayers`).
    *   Navigates to the Ranking Table and Tier List pages.
    *   Caches text data (`TextCacheService`) when switching pages.

2.  **Ranking Table / Excel Generator (`excel_generator.dart`):**
    *   Receives data from the QR Scanner page.
    *   Parses CSV-like data (comma or tab-separated).
    *   Allows uploading additional CSV data (`file_picker`).
    *   Displays raw data in a sortable table.
    *   Calculates and displays detailed team statistics (average, standard deviation) for various metrics (e.g., Auto Coral, TeleOp Algae, Defense Rating).
    *   Allows users to select which numeric columns contribute to an "Overall Average" score.
    *   Provides a ranked list of teams based on the calculated overall average.
    *   Provides a separate ranked list for defensive robots.
    *   Supports custom header definitions.

3.  **Robot Tier List (`main.dart`):**
    *   Visual drag-and-drop interface for organizing robot images into predefined tiers (e.g., "1st Pick", "Defense Pick").
    *   Loads robot images from local files (`file_picker`).
    *   Displays images in an unassigned area and within customer/tier rows.
    *   Allows editing image details:
        *   **Title:** Short identifier shown on the image.
        *   **Text Notes:** Longer description supporting basic Markdown (`**bold**`).
        *   **Driver Skills:** A numerical rating (0-10).
    *   **Image Gallery (`PhotoViewPage`):**
        *   View multiple sub-images associated with a main robot image (`photo_view`).
        *   Add new sub-images from local files.
        *   Delete sub-images.
    *   **Cross-Out Mode:** Toggle a visual cross-out overlay on images.
    *   Saves the entire tier list state (tiers, image data including Base64 encoded bytes, titles, text, skills, sub-images) to a text file.
    *   Loads a previously saved tier list from a text file.
    *   Supports both web and desktop/mobile file saving/loading (`kIsWeb`, `dart:html`, `path_provider`).
    *   Caches image and tier data (`ImageCacheService`) when switching pages.

## Technologies Used

*   **Framework:** Flutter
*   **Language:** Dart
*   **Key Packages:**
    *   `flutter/material.dart`: UI components.
    *   `file_picker`: Selecting files (images, CSV, tier lists).
    *   `photo_view`: Zoomable image gallery view.
    *   `uuid`: Generating unique IDs for images.
    *   `path_provider`: Accessing file system directories (desktop/mobile).
    *   `qr_code_scanner`: Mobile QR code scanning.
    *   `audioplayers`: Playing sound effects.
    *   `excel_generator.dart` likely uses a CSV or data manipulation package (e.g., `excel` though not directly imported in `main.dart`).
*   **Web Specific:**
    *   `dart:html`: Interacting with browser features (file download, camera access).
    *   `dart:js`: Interop with JavaScript (`jsQR` library required in `index.html`).
    *   `jsQR`: JavaScript library for QR code decoding in the browser.

## Project Structure

*   `lib/main.dart`: Contains the main Tier List UI, image handling, saving/loading logic, and navigation.
*   `lib/qr_scanner.dart`: Implements the QR code scanning functionality for both web and mobile.
*   `lib/excel_generator.dart`: Handles data parsing, statistical calculations, and displays the ranking tables.
*   `pubspec.yaml`: Project dependencies and configuration.
*   `web/index.html`: (Assumed) Needs to include the `jsQR.js` library for web scanning to function.
*   `assets/`: Contains sound files (e.g., beep sound).

## How to Use (General Flow)

1.  **Collect Data:** Use the "QR Scanner" page (`qr_scanner.dart`) to scan QR codes generated during matches. Data accumulates in the text area.
2.  **Analyze Data:** Navigate to the "Make Ranking Table" page (`excel_generator.dart`). The data from the scanner is automatically passed. Analyze raw data, view calculated statistics, and see team rankings based on overall performance or defense. Customize columns used for the overall average if needed. Upload additional CSVs if necessary.
3.  **Build Tier List:** Navigate to the "Tier List" page (`main.dart`).
    *   Click the "Pick Images" button to load robot pictures.
    *   Drag images from the bottom "Unassigned" grid into the desired tier rows.
    *   Click the pencil icon on an image to edit its title, add text notes (use `**bold text**` for emphasis), and set a driver skills rating.
    *   Click an image (when not in Cross-Out mode) to view its gallery, add sub-images, or delete sub-images.
    *   Use the "Cross Out" button to toggle a mode where clicking an image marks/unmarks it.
    *   Use the "Save" button to save the current state to a `.txt` file.
    *   Use the "Upload" button to load a previously saved `.txt` file.