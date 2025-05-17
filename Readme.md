---------------------------------------------------------------------
 PokeMMO Theme Patcher for Archetype Counter (V3.1) - README
---------------------------------------------------------------------

**What This Tool Does:**

This tool automates the process of making PokeMMO themes compatible with the Archetype Counter mod. Specifically, it does two things:
1. Copies the necessary 'AC' folder from the 'archetype-counter-main' mod into the target theme's directory.
2. Edits the theme's 'theme.xml' file to include the required scaling line (`<include filename="AC/1.0_Scaling.xml"/>`) just before the closing `</themes>` tag.

It works with themes located in your PokeMMO `data/mods` folder and also with the standard `data/themes/default` theme.

**Requirements:**
*   The Archetype Counter mod installed and named `archetype-counter-main` inside your `data/mods` folder.
*   The theme you want to patch must be extracted as a FOLDER (not a .zip or .mod file).

**How to Use (Easy Method - Recommended):**

1.  **Extract:** Make sure you have extracted the contents of the .zip file you downloaded this tool in. You should have this `README.txt`, a `.ps1` file (the script), and a `.bat` file (the launcher). Keep them together in the same folder.
2.  **Copy to the Pokemmo installation folder** Paste the extracted folder into the pokemmo installation folder.
3.  Double-click the `RunThemePatcher.bat` file found inside the folder.
4.  **Use the GUI:**
    *   A window titled "PokeMMO Theme Patcher" will appear.
    *   Click the **"Scan for Themes"** button. It will automatically look in your standard PokeMMO mods and themes directories.
    *   The list box will show folders found, including the 'default' theme if available. (Remember: .zip/.mod files need to be extracted first to show up here!)
    *   Click on the **FOLDER** in the list that you want to patch.
    *   Click the **"Patch Selected Folder"** button.
    *   Watch the **Status Log** at the bottom for progress messages and check for any pop-up success or error messages.
<details>
 
**Why is there a `.bat` file? (Understanding PowerShell Execution Policy):**

*   PowerShell (`.ps1` files) is a powerful scripting tool for Windows. For security, Windows has a feature called "Execution Policy" that, by default, often prevents running scripts downloaded from the internet or scripts that aren't digitally signed (like this one). This helps protect you from accidentally running malicious code.
*   Double-clicking the `.ps1` file directly will usually just open it in Notepad or give you a security error.
*   The `RunThemePatcher.bat` file contains a simple command:
    `powershell.exe -ExecutionPolicy Bypass -File "%~dp0Patch-PokeMMOThemeGUI.ps1"`
*   The important part is `-ExecutionPolicy Bypass`. This tells PowerShell to *temporarily* ignore the Execution Policy *only for running this specific script, this one time*.
*   It **does not** permanently lower your system's security settings. It's a safe and common way to allow trusted, unsigned local scripts to run easily.

**Is This Script Safe?**

*   Yes, for its intended purpose. While using `-ExecutionPolicy Bypass` sounds scary, it's safe here because the script itself is designed only to perform specific, limited actions:
    *   **It COPIES:** It copies the `AC` folder from `archetype-counter-main` into your chosen theme folder (overwriting an existing `AC` folder if present).
    *   **It READS:** It reads the `theme.xml` file to check for an existing line and find the `</themes>` tag.
    *   **It WRITES:** It *only* modifies the `theme.xml` file by inserting *one specific line* if it's missing. It overwrites the `theme.xml` file with this modified content.
    *   **It DOES NOT:** Delete any files, connect to the internet, download anything, run other programs, or change unrelated system settings.

**Troubleshooting & Notes:**

*   **Theme Not Listed:** Make sure the theme is extracted into its own folder within `data/mods`. The script cannot see inside `.zip` or `.mod` files.
*   **Archetype Counter Not Found Error:** Ensure the Archetype Counter mod is installed in your `data/mods` folder and is named exactly `archetype-counter-main`. Also ensure its internal structure includes `src\lib\AC`.
*   **`theme.xml` Not Found Error:** The folder you selected might not be a proper theme mod, or its structure is unusual. Ensure `theme.xml` exists somewhere within the folder you selected.
*   **"Already Patched" Message:** This means the `theme.xml` file already had the necessary line. The script still copied/updated the `AC` folder before checking the XML.
*   **Status Log:** Pay attention to messages here for details on what the script is doing or where it failed.

**Disclaimer:**

This tool is provided as-is. While tested, use it at your own risk. Always consider backing up your `data/mods` and `data/themes` folders before making modifications, just in case something unexpected happens.

</details>
