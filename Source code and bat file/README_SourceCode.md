# PokeMMO Archetype Counter Theme Patcher - Source Code

This folder contains the source files for the PokeMMO Archetype Counter Theme Patcher GUI application.

*   `Patch-PokeMMOThemeGUI.ps1`: The main PowerShell script that defines the GUI and patching logic.
*   `icon.ico`: (If present) The icon file used when compiling the script into an `.exe`.

## Building the .exe from Source

If you wish to compile the PowerShell script into an executable (`.exe`) yourself, follow these steps. This is useful if you've made modifications to the script or prefer not to download the pre-built executable from the main repository's Releases page.

### Prerequisites

*   **Windows PowerShell:** The script is designed to run on Windows with PowerShell (typically version 5.1 or later, which is standard on Windows 10/11).
*   **PS2EXE PowerShell Module:** This module is used to convert PowerShell scripts into standalone executables.

### Steps

1.  **Open PowerShell:**
    Launch a PowerShell console.

2.  **Install PS2EXE Module (One-time setup):**
    If you haven't installed `ps2exe` before, run the following command in PowerShell:
    ```powershell
    Install-Module -Name ps2exe -Scope CurrentUser
    ```
    *   If prompted about an untrusted repository (PSGallery), it's generally safe to type `Y` and press Enter if installing from the official PowerShell Gallery.
    *   You only need to do this once per machine (for your user profile).

3.  **Navigate to this Source Code Directory:**
    In your PowerShell console, change directory to where you have these source files. For example:
    ```powershell
    cd "C:\path\to\your\repository\Source Code"
    ```

4.  **Import the PS2EXE Module (for the current session):**
    Sometimes PowerShell requires an explicit import in the current session:
    ```powershell
    Import-Module ps2exe
    ```
    If you get an error that the module can't be loaded, you might need to adjust your PowerShell execution policy (e.g., `Set-ExecutionPolicy RemoteSigned -Scope CurrentUser` and then try importing again).

5.  **Compile the Script:**
    Run the following `ps2exe` command. This will create `PokeMMOThemePatcher.exe` in this same directory.
    ```powershell
    ps2exe -inputFile "Patch-PokeMMOThemeGUI.ps1" -outputFile "PokeMMOThemePatcher.exe" -noConsole -iconFile "icon.ico" -title "Archetype Counter Patcher" -description "Patches PokeMMO themes for Archetype Counter compatibility" -version "3.3.0.0"
    ```
    *   **`-inputFile "Patch-PokeMMOThemeGUI.ps1"`:** Specifies the source script.
    *   **`-outputFile "PokeMMOThemePatcher.exe"`:** Specifies the name of the executable to create.
    *   **`-noConsole`:** Prevents a console window from appearing when the GUI runs.
    *   **`-iconFile "icon.ico"`:** (Optional) If `icon.ico` is present in this folder, it will be embedded as the application's icon. If you don't have an `icon.ico` or don't want one, remove this parameter.
    *   The other parameters (`-title`, `-description`, `-version`) embed metadata into the `.exe` file properties. You can customize these as needed.

6.  **Run Your Compiled Executable:**
    After the command completes, you should find `PokeMMOThemePatcher.exe` in this directory. You can run it directly.

## Modifying the Script

You can edit `Patch-PokeMMOThemeGUI.ps1` with any text editor (like Notepad, VS Code, PowerShell ISE, etc.) to make changes or improvements. If you do, you'll need to re-run the compilation steps above to create an updated `.exe`.
