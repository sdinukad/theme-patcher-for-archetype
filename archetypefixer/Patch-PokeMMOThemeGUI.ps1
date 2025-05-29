
<#
.USAGE
Provides a GUI to patch PokeMMO theme folders (including the default theme) found within a user-selected PokeMMO installation path for Archetype Counter compatibility.
.DESCRIPTION
Version 3.3: Folder browser dialog now attempts to default to common PokeMMO installation path (%LOCALAPPDATA%\Programs\PokeMMO) or previously selected path.
User can select their main PokeMMO installation folder.
Launches a window allowing the user to:
1. Select their main PokeMMO installation folder.
2. Scan the selected PokeMMO's 'data\mods' directory AND its 'data\themes\default' directory for potential theme folders.
3. Select a theme FOLDER from the list (NOTE: .zip/.mod mods/themes must be extracted).
4. Click a button to:
   a. Search for 'theme.xml' within the selected folder and its subdirectories.
   b. If found uniquely, patch the theme in the directory containing 'theme.xml' (copies AC folder from 'archetype-counter-main', modifies theme.xml).
Displays status messages and specific errors.
#>

# --- Load Necessary Assemblies ---
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# --- Global Path Variables (to be set by user via GUI) ---
$Global:PokeMMORoot = $null
$Global:PokeMMODataPath = $null
$Global:FixedModsBasePath = $null
$Global:DefaultThemePath = $null
$Global:FullACTempRootPath = $null
$Global:FullSourceACPath = $null

# --- Define Fixed Constants ---
$ArchetypeCounterRootFolderName = "archetype-counter-main" # Expected name of the AC mod folder
$SourceACRelativePath = "src\lib\AC"

# --- Core Patching Logic (as a function) ---
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
    try { Copy-Item -Path $FullSourceACPathInternal -Destination $TargetDirectoryPath -Recurse -Force -ErrorAction Stop; & $LogStatus "AC folder copy successful." -Color Green }
    catch { & $LogStatus "ERROR copying AC folder: $($_.Exception.Message)" -Color Red; [System.Windows.Forms.MessageBox]::Show("Failed to copy the AC folder to '$TargetDirectoryPath'.`n`nError: $($_.Exception.Message)`n`nThis might be a permissions issue. Try running this script 'As Administrator'.", "Copy Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null; return $false }

    # --- Step 2: Edit theme.xml ---
    & $LogStatus "Checking/Modifying '$FullThemeXmlPath'..."
    try {
        try { $xmlLines = Get-Content -Path $FullThemeXmlPath -Encoding UTF8 -ErrorAction Stop } catch { & $LogStatus "ERROR reading '$FullThemeXmlPath': $($_.Exception.Message)" -Color Red; [System.Windows.Forms.MessageBox]::Show("Failed to read the theme XML file '$FullThemeXmlPath'.`n`nError: $($_.Exception.Message)`n`nCheck file permissions.", "File Read Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null; return $false }
        $trimmedLineToInsert = $LineToInsert.Trim(); $lineExists = $false; foreach ($line in $xmlLines) { if ($line.Trim() -eq $trimmedLineToInsert) { $lineExists = $true; break }};

        if ($lineExists) {
            & $LogStatus "AC folder copied/updated. Required include line already exists in '$TargetXmlFileName' (no XML changes needed)." -Color Orange
            [System.Windows.Forms.MessageBox]::Show("The AC folder was copied/updated successfully.`n`nThe required include line was already present in '$TargetXmlFileName', so no changes were made to that file.", "Patch Complete (XML Unchanged)", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
            return $true
        }

        & $LogStatus "Required line not found in XML. Attempting to insert..."
        $closingTagLineIndex = -1; for ($i = $xmlLines.Count - 1; $i -ge 0; $i--) { if ($xmlLines[$i].Trim() -eq $ClosingTag) { $closingTagLineIndex = $i; break }}; if ($closingTagLineIndex -eq -1) { & $LogStatus "ERROR: Could not find closing tag '$ClosingTag' in '$FullThemeXmlPath'." -Color Red; [System.Windows.Forms.MessageBox]::Show("Could not find the '$ClosingTag' line in '$FullThemeXmlPath'. Cannot automatically patch.", "XML Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null; return $false }
        $newXmlLines = $null; try { $tempList = [System.Collections.Generic.List[string]]::new(); foreach ($line in $xmlLines) { $tempList.Add($line) }; $tempList.Insert($closingTagLineIndex, $LineToInsert); $newXmlLines = $tempList } catch { & $LogStatus "ERROR creating/inserting into XML line list: $($_.Exception.Message)" -Color Red; [System.Windows.Forms.MessageBox]::Show("Failed during XML line manipulation.`n`nError: $($_.Exception.Message)", "XML Processing Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null; return $false }; if ($newXmlLines -eq $null) { & $LogStatus "ERROR: Failed to prepare new XML content (list was null)." -Color Red; return $false }
        Set-Content -Path $FullThemeXmlPath -Value $newXmlLines -Encoding UTF8 -Force -ErrorAction Stop; & $LogStatus "Successfully inserted include line into '$FullThemeXmlPath'." -Color Green; return $true
    } catch { & $LogStatus "ERROR modifying '$FullThemeXmlPath' (outer catch): $($_.Exception.Message)" -Color Red; [System.Windows.Forms.MessageBox]::Show("Failed to modify '$FullThemeXmlPath'.`n`nError: $($_.Exception.Message)`n`nThis might be a permissions issue or file access problem.", "XML Write Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null; return $false }
} # End of function Patch-ThemeFolder

# --- Build Form ---
$form = New-Object System.Windows.Forms.Form
$form.Text = "PokeMMO Theme Patcher V3.3 (for Archetype Counter)"
$form.Size = [System.Drawing.Size]::new(600, 540) 
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

# PokeMMO Folder Selection
$labelPokeMMOPath = New-Label -Text "PokeMMO Folder:" -X $xMargin -Y $yPos -Width 100
$textboxPokeMMOPath = New-TextBox -Name "PokeMMOPath" -X ($xMargin + 105) -Y $yPos -Width ($form.ClientSize.Width - (2*$xMargin) - 105 - 90 - 10) 
$textboxPokeMMOPath.ReadOnly = $true
$buttonBrowsePokeMMO = New-Button -Name "BrowsePokeMMO" -Text "Browse..." -X ($textboxPokeMMOPath.Right + 5) -Y ($yPos - 2) -Width 90 -Height 25

$yPos += $textboxPokeMMOPath.Height + 15 

# Scan Button
$xScanButton = ($form.ClientSize.Width / 2) - 70
$buttonScan = New-Button -Name "ScanThemes" -Text "Scan for Themes" -X $xScanButton -Y $yPos -Width 140 -Height 30
$buttonScan.Enabled = $false 

$yPos += $buttonScan.Height + 15 

# Themes List Box Label
$labelThemesList = New-Label -Text "Found Folders (Themes/Mods):`n(Note: .zip/.mod files must be extracted to appear)" -X $xMargin -Y $yPos -Width ($form.ClientSize.Width - (2*$xMargin)) -Height 30
$labelThemesList.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft

$yPos += $labelThemesList.Height + 5

# Themes List Box
$listboxThemes = New-Object System.Windows.Forms.ListBox
$listboxThemes.Location = [System.Drawing.Point]::new($xMargin, $yPos)
$listBoxHeight = 130
$listboxThemes.Size = [System.Drawing.Size]::new(($form.ClientSize.Width - (2 * $xMargin)), $listBoxHeight)
$listboxThemes.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
$listboxThemes.DisplayMember = 'Display'
$listboxThemes.ValueMember = 'ItemObject'

$yPos += $listboxThemes.Height + 15 

# Patch Button
$xPatchButton = ($form.ClientSize.Width / 2) - 90
$buttonPatch = New-Button -Name "PatchTheme" -Text "Patch Selected Theme" -X $xPatchButton -Y $yPos -Width 180 -Height 30
$buttonPatch.Enabled = $false

$yPos += $buttonPatch.Height + 15 

# Status Text Box Label
$labelStatus = New-Label -Text "Status Log:" -X $xMargin -Y $yPos -Width 100

$yPos += $labelStatus.Height + 5 

# Status Text Box
$textboxStatus = New-Object System.Windows.Forms.TextBox
$textboxStatus.Name = "Status"
$textboxStatus.Location = [System.Drawing.Point]::new($xMargin, $yPos)
$statusBoxHeight = $form.ClientSize.Height - $yPos - $xMargin
$textboxStatus.Size = [System.Drawing.Size]::new(($form.ClientSize.Width - (2 * $xMargin)), $statusBoxHeight)
$textboxStatus.Multiline = $true
$textboxStatus.ScrollBars = [System.Windows.Forms.ScrollBars]::Vertical
$textboxStatus.ReadOnly = $true
$textboxStatus.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right -bor [System.Windows.Forms.AnchorStyles]::Bottom
$textboxStatus.Font = [System.Drawing.Font]::new("Consolas", 8)

# Add Controls to Form
$form.Controls.AddRange(@(
    $labelPokeMMOPath, $textboxPokeMMOPath, $buttonBrowsePokeMMO,
    $buttonScan,
    $labelThemesList, $listboxThemes,
    $buttonPatch,
    $labelStatus, $textboxStatus
))

# --- Define LogStatus Function ---
$LogStatus = { param($Message, $Color = 'Black'); if ($textboxStatus -ne $null) { if ($textboxStatus.InvokeRequired) { $textboxStatus.Invoke([Action[string]] { $textboxStatus.AppendText("$(Get-Date -Format 'HH:mm:ss') - $Message`r`n") }, $Message) } else { $textboxStatus.AppendText("$(Get-Date -Format 'HH:mm:ss') - $Message`r`n") } } else { Write-Host "$(Get-Date -Format 'HH:mm:ss') - $Message" } }

# --- Event Handlers ---

# Browse for PokeMMO Folder Button Click Event
$buttonBrowsePokeMMO.Add_Click({
    $folderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
    $folderBrowser.Description = "Select your main PokeMMO installation folder"
    $folderBrowser.ShowNewFolderButton = $false

    # Attempt to set a smart default path for the browser
    $commonDefaultPokeMMOPath = Join-Path -Path $env:LOCALAPPDATA -ChildPath "Programs\PokeMMO"

    if ($Global:PokeMMORoot -ne $null -and (Test-Path -Path $Global:PokeMMORoot -PathType Container)) {
        $folderBrowser.SelectedPath = $Global:PokeMMORoot
        & $LogStatus "Setting browse dialog to previously selected path: $($Global:PokeMMORoot)"
    } elseif (Test-Path -Path $commonDefaultPokeMMOPath -PathType Container) {
        $folderBrowser.SelectedPath = $commonDefaultPokeMMOPath
        & $LogStatus "Setting browse dialog to common default path: $commonDefaultPokeMMOPath"
    } # Else, it will use the system default if neither path exists or is valid

    if ($folderBrowser.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $selectedPath = $folderBrowser.SelectedPath
        $textboxPokeMMOPath.Text = $selectedPath
        & $LogStatus "PokeMMO folder selected: $selectedPath"

        $tempDataPath = Join-Path -Path $selectedPath -ChildPath "data"
        if (Test-Path -Path $tempDataPath -PathType Container) {
            $Global:PokeMMORoot = $selectedPath
            $Global:PokeMMODataPath = $tempDataPath
            $Global:FixedModsBasePath = Join-Path -Path $Global:PokeMMODataPath -ChildPath "mods"
            $Global:DefaultThemePath = Join-Path -Path $Global:PokeMMODataPath -ChildPath "themes\default" 
            
            $Global:FullACTempRootPath = Join-Path -Path $Global:FixedModsBasePath -ChildPath $ArchetypeCounterRootFolderName
            $Global:FullSourceACPath = Join-Path -Path $Global:FullACTempRootPath -ChildPath $SourceACRelativePath

            & $LogStatus "Derived paths: Data=' $($Global:PokeMMODataPath)', Mods=' $($Global:FixedModsBasePath)'"
            $buttonScan.Enabled = $true
            $listboxThemes.Items.Clear() 
            $buttonPatch.Enabled = $false   
            & $LogStatus "PokeMMO folder set. Click 'Scan for Themes' to find themes in this location." -Color Blue
        } else {
            & $LogStatus "ERROR: Selected folder '$selectedPath' does not appear to be a valid PokeMMO root folder (missing 'data' subfolder)." -Color Red
            [System.Windows.Forms.MessageBox]::Show("The selected folder '$selectedPath' does not contain a 'data' subfolder. Please select the correct PokeMMO installation directory.", "Invalid PokeMMO Folder", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
            $textboxPokeMMOPath.Text = ""
            $Global:PokeMMORoot = $null; $Global:PokeMMODataPath = $null; $Global:FixedModsBasePath = $null; $Global:DefaultThemePath = $null; $Global:FullACTempRootPath = $null; $Global:FullSourceACPath = $null
            $buttonScan.Enabled = $false
            $listboxThemes.Items.Clear()
            $buttonPatch.Enabled = $false
        }
    }
    $folderBrowser.Dispose()
})

# Scan Themes Button Click Event
$buttonScan.Add_Click({
    $listboxThemes.Items.Clear(); $buttonPatch.Enabled = $false
    & $LogStatus "Scanning for themes..."
    if ($Global:PokeMMORoot -eq $null -or -not (Test-Path -Path $Global:FixedModsBasePath -PathType Container)) {
        & $LogStatus "ERROR: PokeMMO Mods directory not found at '$($Global:FixedModsBasePath)'. Please select a valid PokeMMO folder." -Color Red
        [System.Windows.Forms.MessageBox]::Show("The PokeMMO mods directory was not found for the selected folder:`n$($Global:FixedModsBasePath)`n`nPlease ensure the selected folder is your main PokeMMO installation and try again.", "Mods Directory Not Found", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
        return
    }
    if (-not (Test-Path -Path $Global:FullACTempRootPath -PathType Container)) { & $LogStatus "WARNING: Archetype Counter folder '$ArchetypeCounterRootFolderName' not found in '$($Global:FixedModsBasePath)'. Patching will fail." -Color Orange; [System.Windows.Forms.MessageBox]::Show("Could not find the folder '$ArchetypeCounterRootFolderName' inside:`n$($Global:FixedModsBasePath)`n`nPlease ensure the Archetype Counter mod is installed correctly in the selected PokeMMO's mods directory. Patching will not work.", "Archetype Counter Not Found", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null; }
    elseif (-not (Test-Path -Path $Global:FullSourceACPath -PathType Container)) { & $LogStatus "ERROR: Source folder '$SourceACRelativePath' not found inside '$($Global:FullACTempRootPath)'. Patching will fail." -Color Red; [System.Windows.Forms.MessageBox]::Show("Could not find the required source folder '$SourceACRelativePath' inside:`n$($Global:FullACTempRootPath)`n`nThe Archetype Counter mod might be incomplete or structured differently. Patching will not work.", "AC Source Folder Missing", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null; }
    
    $foundItems = @()
    & $LogStatus "Scanning Mods folder: '$($Global:FixedModsBasePath)'..."
    try {
        $modFolders = Get-ChildItem -Path $Global:FixedModsBasePath -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne $ArchetypeCounterRootFolderName }
        if ($modFolders) {
            & $LogStatus "Found $($modFolders.Count) potential theme/mod folders in mods directory."
            $foundItems += $modFolders | ForEach-Object { [PSCustomObject]@{ Display = "$($_.Name)"; Name = $_.Name; Path = $_.FullName; Type = 'Folder'; ItemObject = $_ }}
        }
    } catch {
        & $LogStatus "ERROR reading mods directory '$($Global:FixedModsBasePath)': $($_.Exception.Message)" -Color Red
        [System.Windows.Forms.MessageBox]::Show("Could not fully read the mods directory.`n`nError: $($_.Exception.Message)`n`nCheck permissions for '$($Global:FixedModsBasePath)'.", "Directory Read Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null
    }
    
    & $LogStatus "Checking for Default theme at '$($Global:DefaultThemePath)'..."
    if (Test-Path -Path $Global:DefaultThemePath -PathType Container) {
        & $LogStatus "Found Default theme folder."
        $defaultThemeObject = [PSCustomObject]@{ Display = "default (Default Theme)"; Name = "default"; Path = $Global:DefaultThemePath; Type = 'Folder'; ItemObject = Get-Item -Path $Global:DefaultThemePath }
        $foundItems += $defaultThemeObject
    } else {
        & $LogStatus "Default theme folder not found (this is normal if not used)." -Color Orange
    }
    
    if ($foundItems.Count -eq 0) {
        & $LogStatus "No theme/mod folders found in '$($Global:FixedModsBasePath)' and default theme not found." -Color Orange
    } else {
        & $LogStatus "Total items to list: $($foundItems.Count)." -Color Green
        $sortedItems = $foundItems | Sort-Object Name
        foreach ($item in $sortedItems) { $listboxThemes.Items.Add($item) | Out-Null }
    }
})

# ListBox Selection Change Event
$listboxThemes.Add_SelectedIndexChanged({ $buttonPatch.Enabled = ($listboxThemes.SelectedItem -ne $null) })

# Patch Button Click Event
$buttonPatch.Add_Click({
    $selectedItem = $listboxThemes.SelectedItem; if ($selectedItem -eq $null) { return }
    $themeRootPath = $selectedItem.Path; & $LogStatus "Patch button clicked for: $($selectedItem.Display)"
    & $LogStatus "Searching for theme.xml within '$themeRootPath'..."
    try { $foundXmlFiles = Get-ChildItem -Path $themeRootPath -Filter "theme.xml" -Recurse -File -ErrorAction Stop } catch { & $LogStatus "ERROR searching for theme.xml: $($_.Exception.Message)" -Color Red; [System.Windows.Forms.MessageBox]::Show("An error occurred while searching for theme.xml.`n`nError: $($_.Exception.Message)`n`nCheck permissions for '$themeRootPath' and its subfolders.", "Search Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null; return }
    
    $targetDirectoryPath = $null
    if ($foundXmlFiles.Count -eq 0) { & $LogStatus "ERROR: 'theme.xml' not found within '$($selectedItem.Display)' or its subfolders." -Color Red; [System.Windows.Forms.MessageBox]::Show("'theme.xml' could not be found within the selected folder '$($selectedItem.Display)'.`n`nPlease ensure this is a theme folder and not a different type of mod.", "File Not Found / Not a Theme?", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null; return }
    elseif ($foundXmlFiles.Count -gt 1) { $foundPaths = ($foundXmlFiles | ForEach-Object { $_.FullName }) -join "`n - "; & $LogStatus "ERROR: Found multiple 'theme.xml' files within '$($selectedItem.Display)':`n - $foundPaths" -Color Red; [System.Windows.Forms.MessageBox]::Show("Found multiple 'theme.xml' files within the selected folder '$($selectedItem.Display)':`n - $foundPaths`n`nCannot determine which one to patch. Please correct the theme structure.", "Ambiguous Theme Structure", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null; return }
    else { $targetDirectoryPath = $foundXmlFiles[0].DirectoryName; & $LogStatus "'theme.xml' found in directory: '$targetDirectoryPath'." -Color Green }
    
    if (-not (Test-Path -Path $Global:FullSourceACPath -PathType Container)) { & $LogStatus "ERROR: Source AC folder '$($Global:FullSourceACPath)' not found or invalid. Cannot patch." -Color Red; [System.Windows.Forms.MessageBox]::Show("Cannot find the required source folder for patching:`n$($Global:FullSourceACPath)`n`nPlease ensure the Archetype Counter mod ('$ArchetypeCounterRootFolderName') is correctly installed in the mods directory of your selected PokeMMO folder.", "AC Source Missing", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null; return }
    
    $buttonPatch.Enabled = $false; $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor; $listboxThemes.Enabled = $false
    $patchSuccess = Patch-ThemeFolder -TargetDirectoryPath $targetDirectoryPath -FullSourceACPathInternal $Global:FullSourceACPath -StatusTextBox $textboxStatus
    $listboxThemes.Enabled = $true; $form.Cursor = [System.Windows.Forms.Cursors]::Default; if ($listboxThemes.SelectedItem -ne $null) { $buttonPatch.Enabled = $true } else { $buttonPatch.Enabled = $false }
    
    if ($patchSuccess) { & $LogStatus "Patch process completed for '$($selectedItem.Display)'." -Color Green; [System.Windows.Forms.MessageBox]::Show("Patching process finished for '$($selectedItem.Display)'. Check the status log for details.", "Patch Complete", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null; }
    else { & $LogStatus "Patch process failed for '$($selectedItem.Display)'. See logs above." -Color Red; }
})

# --- Show Form ---
& $LogStatus "GUI Loaded. Please select your PokeMMO folder using the 'Browse...' button."
$form.ShowDialog() | Out-Null

# --- Cleanup ---
& $LogStatus "GUI Closed."
$form.Dispose()
