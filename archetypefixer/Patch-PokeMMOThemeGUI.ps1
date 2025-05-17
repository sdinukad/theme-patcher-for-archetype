#Requires -Version 5.1
<#
.SYNOPSIS
Provides a GUI to patch PokeMMO theme folders (including the default theme) found within the standard installation paths for Archetype Counter compatibility.
.DESCRIPTION
Version 3.1: Adjusted layout for better status log visibility.
Assumes standard PokeMMO installation path, includes default theme.
Launches a window allowing the user to:
1. Scan the '%LOCALAPPDATA%\Programs\PokeMMO\data\mods' directory AND the 'data\themes\default' directory for potential theme folders.
2. Select a theme FOLDER from the list (NOTE: .zip/.mod mods/themes must be extracted).
3. Click a button to:
   a. Search for 'theme.xml' within the selected folder and its subdirectories.
   b. If found uniquely, patch the theme in the directory containing 'theme.xml' (copies AC folder from 'archetype-counter-main', modifies theme.xml).
Displays status messages and specific errors.
#>

# --- Load Necessary Assemblies ---
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Get the directory where the script is located
$ScriptFolder = Split-Path -Parent $MyInvocation.MyCommand.Definition
$PokeMMORoot = Split-Path -Parent $ScriptFolder  # One level up from the script
$PokeMMODataPath = Join-Path -Path $PokeMMORoot -ChildPath "data"

# --- Define Fixed Paths ---
try {
    # Get the folder one level above the script (should be the PokeMMO root folder)
    $ScriptFolder = Split-Path -Parent $MyInvocation.MyCommand.Definition
    $PokeMMORoot = Split-Path -Parent $ScriptFolder
    $PokeMMODataPath = Join-Path -Path $PokeMMORoot -ChildPath "data" -ErrorAction Stop
    $FixedModsBasePath = Join-Path -Path $PokeMMODataPath -ChildPath "mods" -ErrorAction Stop
    $DefaultThemePath = Join-Path -Path $PokeMMODataPath -ChildPath "themes\default" -ErrorAction Stop
} catch {
    [System.Windows.Forms.MessageBox]::Show("Could not locate the PokeMMO data directory relative to this script location.`n`nMake sure this script is inside a folder within your main PokeMMO folder.`n`nError: $($_.Exception.Message)", "Path Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    exit 1
}

$ArchetypeCounterRootFolderName = "archetype-counter-main" # Expected name of the AC mod folder
$SourceACRelativePath = "src\lib\AC"
$FullACTempRootPath = Join-Path -Path $FixedModsBasePath -ChildPath $ArchetypeCounterRootFolderName
$FullSourceACPath = Join-Path -Path $FullACTempRootPath -ChildPath $SourceACRelativePath

# --- Core Patching Logic (as a function) ---
# Now expects the specific directory containing theme.xml
function Patch-ThemeFolder {
    param(
        [Parameter(Mandatory)]
        [string]$TargetDirectoryPath, # Path to the directory CONTAINING theme.xml
        [Parameter(Mandatory)]
        [string]$FullSourceACPathInternal,
        [Parameter(Mandatory)]
        [System.Windows.Forms.TextBox]$StatusTextBox
    )

    $SourceACFolderName = "AC"; $TargetXmlFileName = "theme.xml"; $LineToInsert = '    <include filename="AC/1.0_Scaling.xml"/>'; $ClosingTag = '</themes>'
    $FullDestACPath = Join-Path -Path $TargetDirectoryPath -ChildPath $SourceACFolderName; $FullThemeXmlPath = Join-Path -Path $TargetDirectoryPath -ChildPath $TargetXmlFileName
    & $LogStatus "Starting patch process inside directory '$TargetDirectoryPath'..."
    if (!(Test-Path -Path $FullThemeXmlPath -PathType Leaf)) { & $LogStatus "ERROR: Consistency check failed - '$TargetXmlFileName' not found in '$TargetDirectoryPath'." -Color Red; [System.Windows.Forms.MessageBox]::Show("Consistency check failed: Could not find '$TargetXmlFileName' in the expected directory '$TargetDirectoryPath'.", "Internal Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null; return $false }

    # --- Step 1: Copy AC Folder ---
    & $LogStatus "Copying '$SourceACFolderName' folder to '$TargetDirectoryPath'..."
    try { Copy-Item -Path $FullSourceACPathInternal -Destination $TargetDirectoryPath -Recurse -Force -ErrorAction Stop; & $LogStatus "AC folder copy successful." -Color Green } # Renamed log slightly
    catch { & $LogStatus "ERROR copying AC folder: $($_.Exception.Message)" -Color Red; [System.Windows.Forms.MessageBox]::Show("Failed to copy the AC folder to '$TargetDirectoryPath'.`n`nError: $($_.Exception.Message)`n`nThis might be a permissions issue. Try running this script 'As Administrator'.", "Copy Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null; return $false }

    # --- Step 2: Edit theme.xml ---
    & $LogStatus "Checking/Modifying '$FullThemeXmlPath'..." # Changed log text slightly
    try {
        try { $xmlLines = Get-Content -Path $FullThemeXmlPath -Encoding UTF8 -ErrorAction Stop } catch { & $LogStatus "ERROR reading '$FullThemeXmlPath': $($_.Exception.Message)" -Color Red; [System.Windows.Forms.MessageBox]::Show("Failed to read the theme XML file '$FullThemeXmlPath'.`n`nError: $($_.Exception.Message)`n`nCheck file permissions.", "File Read Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null; return $false }
        $trimmedLineToInsert = $LineToInsert.Trim(); $lineExists = $false; foreach ($line in $xmlLines) { if ($line.Trim() -eq $trimmedLineToInsert) { $lineExists = $true; break }};

        # --- Handle XML Already Patched Case ---
        if ($lineExists) {
            # FIX: Clarify message when XML is already patched but AC folder was copied
            & $LogStatus "AC folder copied/updated. Required include line already exists in '$TargetXmlFileName' (no XML changes needed)." -Color Orange
            [System.Windows.Forms.MessageBox]::Show("The AC folder was copied/updated successfully.`n`nThe required include line was already present in '$TargetXmlFileName', so no changes were made to that file.", "Patch Complete (XML Unchanged)", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
            return $true # This is still a successful outcome overall
        }
        # --- End Handle XML Already Patched Case ---

        & $LogStatus "Required line not found in XML. Attempting to insert..."
        $closingTagLineIndex = -1; for ($i = $xmlLines.Count - 1; $i -ge 0; $i--) { if ($xmlLines[$i].Trim() -eq $ClosingTag) { $closingTagLineIndex = $i; break }}; if ($closingTagLineIndex -eq -1) { & $LogStatus "ERROR: Could not find closing tag '$ClosingTag' in '$FullThemeXmlPath'." -Color Red; [System.Windows.Forms.MessageBox]::Show("Could not find the '$ClosingTag' line in '$FullThemeXmlPath'. Cannot automatically patch.", "XML Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null; return $false }
        $newXmlLines = $null; try { $tempList = [System.Collections.Generic.List[string]]::new(); foreach ($line in $xmlLines) { $tempList.Add($line) }; $tempList.Insert($closingTagLineIndex, $LineToInsert); $newXmlLines = $tempList } catch { & $LogStatus "ERROR creating/inserting into XML line list: $($_.Exception.Message)" -Color Red; [System.Windows.Forms.MessageBox]::Show("Failed during XML line manipulation.`n`nError: $($_.Exception.Message)", "XML Processing Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null; return $false }; if ($newXmlLines -eq $null) { & $LogStatus "ERROR: Failed to prepare new XML content (list was null)." -Color Red; return $false }
        Set-Content -Path $FullThemeXmlPath -Value $newXmlLines -Encoding UTF8 -Force -ErrorAction Stop; & $LogStatus "Successfully inserted include line into '$FullThemeXmlPath'." -Color Green; return $true
    } catch { & $LogStatus "ERROR modifying '$FullThemeXmlPath' (outer catch): $($_.Exception.Message)" -Color Red; [System.Windows.Forms.MessageBox]::Show("Failed to modify '$FullThemeXmlPath'.`n`nError: $($_.Exception.Message)`n`nThis might be a permissions issue or file access problem.", "XML Write Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null; return $false }
} # End of function Patch-ThemeFolder

# --- Build Form ---
$form = New-Object System.Windows.Forms.Form
$form.Text = "PokeMMO Theme Patcher V3.1 (for Archetype Counter)"
# FIX: Increased form height
$form.Size = [System.Drawing.Size]::new(600, 500) # Increased from 450 to 500
$form.StartPosition = 'CenterScreen'
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false
$form.MinimizeBox = $false

# --- Helper functions for creating controls ---
function New-Label { param($Text, $X, $Y, $Width=180, $Height=20); $label = New-Object System.Windows.Forms.Label; $label.Text = $Text; $label.Location = [System.Drawing.Point]::new($X, $Y+3); $label.Size = [System.Drawing.Size]::new($Width, $Height); return $label }
function New-TextBox { param($Name, $X, $Y, $Width=300, $Height=20); $textBox = New-Object System.Windows.Forms.TextBox; $textBox.Name = $Name; $textBox.Location = [System.Drawing.Point]::new($X, $Y); $textBox.Size = [System.Drawing.Size]::new($Width, $Height); $textBox.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right; return $textBox }
function New-Button { param($Name, $Text, $X, $Y, $Width=80, $Height=25); $button = New-Object System.Windows.Forms.Button; $button.Name = $Name; $button.Text = $Text; $button.Location = [System.Drawing.Point]::new($X, $Y); $button.Size = [System.Drawing.Size]::new($Width, $Height); return $button }

# --- Controls ---
$yPos = 15
$xMargin = 15
$xScanButton = ($form.ClientSize.Width / 2) - 70 # Adjusted slightly for wider button text

# Scan Button
$buttonScan = New-Button -Name "ScanThemes" -Text "Scan for Themes" -X $xScanButton -Y $yPos -Width 140 -Height 30

$yPos += $buttonScan.Height + 15 # Space below scan button

# Themes List Box Label
$labelThemesList = New-Label -Text "Found Folders (Themes/Mods):`n(Note: .zip/.mod files must be extracted to appear)" -X $xMargin -Y $yPos -Width ($form.ClientSize.Width - (2*$xMargin)) -Height 30
$labelThemesList.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft

$yPos += $labelThemesList.Height + 5 # Space below label

# Themes List Box
$listboxThemes = New-Object System.Windows.Forms.ListBox
$listboxThemes.Location = [System.Drawing.Point]::new($xMargin, $yPos)
# FIX: Slightly reduced height to ensure space below for status
$listBoxHeight = 130 # Reduced from 150
$listboxThemes.Size = [System.Drawing.Size]::new(($form.ClientSize.Width - (2 * $xMargin)), $listBoxHeight)
$listboxThemes.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
$listboxThemes.DisplayMember = 'Display'
$listboxThemes.ValueMember = 'ItemObject'

$yPos += $listboxThemes.Height + 15 # Space below listbox

# Patch Button
$xPatchButton = ($form.ClientSize.Width / 2) - 90
$buttonPatch = New-Button -Name "PatchTheme" -Text "Patch Selected Theme" -X $xPatchButton -Y $yPos -Width 180 -Height 30
$buttonPatch.Enabled = $false

$yPos += $buttonPatch.Height + 15 # Space below patch button

# Status Text Box Label
$labelStatus = New-Label -Text "Status Log:" -X $xMargin -Y $yPos -Width 100

$yPos += $labelStatus.Height + 5 # Space below status label

# Status Text Box
$textboxStatus = New-Object System.Windows.Forms.TextBox
$textboxStatus.Name = "Status"
$textboxStatus.Location = [System.Drawing.Point]::new($xMargin, $yPos)
# FIX: Correctly calculate remaining height
$statusBoxHeight = $form.ClientSize.Height - $yPos - $xMargin # Height is from current Y to bottom margin
$textboxStatus.Size = [System.Drawing.Size]::new(($form.ClientSize.Width - (2 * $xMargin)), $statusBoxHeight)
$textboxStatus.Multiline = $true
$textboxStatus.ScrollBars = [System.Windows.Forms.ScrollBars]::Vertical
$textboxStatus.ReadOnly = $true
# FIX: Anchor calculation needs bottom included
$textboxStatus.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right -bor [System.Windows.Forms.AnchorStyles]::Bottom
$textboxStatus.Font = [System.Drawing.Font]::new("Consolas", 8)


# Add Controls to Form
$form.Controls.AddRange(@(
    $buttonScan,
    $labelThemesList, $listboxThemes,
    $buttonPatch,
    $labelStatus, $textboxStatus
))

# --- Define LogStatus Function ---
$LogStatus = { param($Message, $Color = 'Black'); if ($textboxStatus -ne $null) { if ($textboxStatus.InvokeRequired) { $textboxStatus.Invoke([Action[string]] { $textboxStatus.AppendText("$(Get-Date -Format 'HH:mm:ss') - $Message`r`n") }, $Message) } else { $textboxStatus.AppendText("$(Get-Date -Format 'HH:mm:ss') - $Message`r`n") } } else { Write-Host "$(Get-Date -Format 'HH:mm:ss') - $Message" } }

# --- Event Handlers ---
# No changes needed in event handlers for this layout fix

# Scan Themes Button Click Event
$buttonScan.Add_Click({
    $listboxThemes.Items.Clear(); $buttonPatch.Enabled = $false
    & $LogStatus "Scanning for themes..."
    if (-not (Test-Path -Path $FixedModsBasePath -PathType Container)) { & $LogStatus "ERROR: PokeMMO Mods directory not found at '$FixedModsBasePath'." -Color Red; [System.Windows.Forms.MessageBox]::Show("The standard PokeMMO mods directory was not found:`n$FixedModsBasePath`n`nPlease ensure PokeMMO is installed correctly.", "Mods Directory Not Found", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null; }
    if (-not (Test-Path -Path $FullACTempRootPath -PathType Container)) { & $LogStatus "WARNING: Archetype Counter folder '$ArchetypeCounterRootFolderName' not found in mods directory. Patching will fail." -Color Orange; [System.Windows.Forms.MessageBox]::Show("Could not find the folder '$ArchetypeCounterRootFolderName' inside:`n$FixedModsBasePath`n`nPlease ensure the Archetype Counter mod is installed correctly. Patching will not work.", "Archetype Counter Not Found", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null; }
    elseif (-not (Test-Path -Path $FullSourceACPath -PathType Container)) { & $LogStatus "ERROR: Source folder '$SourceACRelativePath' not found inside '$ArchetypeCounterRootFolderName'. Patching will fail." -Color Red; [System.Windows.Forms.MessageBox]::Show("Could not find the required source folder '$SourceACRelativePath' inside:`n$FullACTempRootPath`n`nThe Archetype Counter mod might be incomplete or structured differently. Patching will not work.", "AC Source Folder Missing", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null; }
    $foundItems = @(); & $LogStatus "Scanning Mods folder: '$FixedModsBasePath'..."
    try { $modFolders = Get-ChildItem -Path $FixedModsBasePath -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne $ArchetypeCounterRootFolderName }; if ($modFolders) { & $LogStatus "Found $($modFolders.Count) potential theme/mod folders in mods directory."; $foundItems += $modFolders | ForEach-Object { [PSCustomObject]@{ Display = "$($_.Name)"; Name = $_.Name; Path = $_.FullName; Type = 'Folder'; ItemObject = $_ }}}} catch { & $LogStatus "ERROR reading mods directory '$FixedModsBasePath': $($_.Exception.Message)" -Color Red; [System.Windows.Forms.MessageBox]::Show("Could not fully read the mods directory.`n`nError: $($_.Exception.Message)`n`nCheck permissions for '$FixedModsBasePath'.", "Directory Read Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null; }
    & $LogStatus "Checking for Default theme at '$DefaultThemePath'..."; if (Test-Path -Path $DefaultThemePath -PathType Container) { & $LogStatus "Found Default theme folder."; $defaultThemeObject = [PSCustomObject]@{ Display = "default (Default Theme)"; Name = "default"; Path = $DefaultThemePath; Type = 'Folder'; ItemObject = Get-Item -Path $DefaultThemePath }; $foundItems += $defaultThemeObject } else { & $LogStatus "Default theme folder not found (this is normal if not used)." -Color Orange }
    if ($foundItems.Count -eq 0) { & $LogStatus "No theme/mod folders found in '$FixedModsBasePath' and default theme not found." -Color Orange } else { & $LogStatus "Total items to list: $($foundItems.Count)." -Color Green; $sortedItems = $foundItems | Sort-Object Name; foreach ($item in $sortedItems) { $listboxThemes.Items.Add($item) | Out-Null }}
})

# ListBox Selection Change Event
$listboxThemes.Add_SelectedIndexChanged({ $buttonPatch.Enabled = ($listboxThemes.SelectedItem -ne $null) })

# Patch Button Click Event
$buttonPatch.Add_Click({
    $selectedItem = $listboxThemes.SelectedItem; if ($selectedItem -eq $null) { return }
    $themeRootPath = $selectedItem.Path; & $LogStatus "Patch button clicked for: $($selectedItem.Display)"
    & $LogStatus "Searching for theme.xml within '$themeRootPath'..."
    try { $foundXmlFiles = Get-ChildItem -Path $themeRootPath -Filter "theme.xml" -Recurse -File -ErrorAction Stop } catch { & $LogStatus "ERROR searching for theme.xml: $($_.Exception.Message)" -Color Red; [System.Windows.Forms.MessageBox]::Show("An error occurred while searching for theme.xml.`n`nError: $($_.Exception.Message)`n`nCheck permissions for '$themeRootPath' and its subfolders.", "Search Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null; return }
    $targetDirectoryPath = $null; if ($foundXmlFiles.Count -eq 0) { & $LogStatus "ERROR: 'theme.xml' not found within '$($selectedItem.Display)' or its subfolders." -Color Red; [System.Windows.Forms.MessageBox]::Show("'theme.xml' could not be found within the selected folder '$($selectedItem.Display)'.`n`nPlease ensure this is a theme folder and not a different type of mod.", "File Not Found / Not a Theme?", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null; return } elseif ($foundXmlFiles.Count -gt 1) { $foundPaths = ($foundXmlFiles | ForEach-Object { $_.FullName }) -join "`n - "; & $LogStatus "ERROR: Found multiple 'theme.xml' files within '$($selectedItem.Display)':`n - $foundPaths" -Color Red; [System.Windows.Forms.MessageBox]::Show("Found multiple 'theme.xml' files within the selected folder '$($selectedItem.Display)':`n - $foundPaths`n`nCannot determine which one to patch. Please correct the theme structure.", "Ambiguous Theme Structure", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null; return } else { $targetDirectoryPath = $foundXmlFiles[0].DirectoryName; & $LogStatus "'theme.xml' found in directory: '$targetDirectoryPath'." -Color Green }
    if (-not (Test-Path -Path $FullSourceACPath -PathType Container)) { & $LogStatus "ERROR: Source AC folder '$FullSourceACPath' not found or invalid. Cannot patch." -Color Red; [System.Windows.Forms.MessageBox]::Show("Cannot find the required source folder for patching:`n$FullSourceACPath`n`nPlease ensure the Archetype Counter mod ('$ArchetypeCounterRootFolderName') is correctly installed in the mods directory.", "AC Source Missing", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null; return }
    $buttonPatch.Enabled = $false; $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor; $listboxThemes.Enabled = $false
    $patchSuccess = Patch-ThemeFolder -TargetDirectoryPath $targetDirectoryPath -FullSourceACPathInternal $FullSourceACPath -StatusTextBox $textboxStatus
    $listboxThemes.Enabled = $true; $form.Cursor = [System.Windows.Forms.Cursors]::Default; if ($listboxThemes.SelectedItem -ne $null) { $buttonPatch.Enabled = $true } else { $buttonPatch.Enabled = $false }
    if ($patchSuccess) { & $LogStatus "Patch process completed for '$($selectedItem.Display)'." -Color Green; [System.Windows.Forms.MessageBox]::Show("Patching process finished for '$($selectedItem.Display)'. Check the status log for details.", "Patch Complete", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null; } else { & $LogStatus "Patch process failed for '$($selectedItem.Display)'. See logs above." -Color Red; }
})

# --- Show Form ---
& $LogStatus "GUI Loaded. Click 'Scan for Themes' to find themes/mods."
$form.ShowDialog() | Out-Null

# --- Cleanup ---
& $LogStatus "GUI Closed."
$form.Dispose()
