#Requires -Version 5.1

<#
.SYNOPSIS
    Compiles one or more C# source files into a .NET Framework library (.dll) or executable (.exe).
    Provides a command-line interface and an optional graphical user interface (GUI) with a professional dark theme.

.DESCRIPTION
    This script discovers the latest .NET Framework C# compiler (csc.exe) on the system to compile C# source files.
    
    The script's GUI mode, activated with the -ShowGui switch, launches a clean, modern dark-themed Windows Form application.
    It allows for interactive file selection, output configuration, and provides a detailed, real-time build log.
#>
function Build-CSharpLibrary {
    [CmdletBinding(DefaultParameterSetName = 'CLI')]
    [OutputType([System.IO.FileInfo])]
    param(
        # ... (Parameters are unchanged)
        [Parameter(ParameterSetName = 'CLI', Mandatory = $true, Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateScript({
            foreach ($file in $_) {
                if (-not (Test-Path $file -PathType Leaf)) { throw "File not found: $file" }
                if ([System.IO.Path]::GetExtension($file) -ne '.cs') { throw "File must be a .cs file: $file" }
            }
            return $true
        })]
        [string[]]$SourceFiles,

        [Parameter(ParameterSetName = 'CLI')]
        [string]$OutputPath,

        [Parameter()]
        [string[]]$References = @(
            "System.dll", "System.Core.dll", "System.Data.dll", "System.Xml.dll",
            "System.Net.Http.dll"
        ),

        [Parameter(ParameterSetName = 'CLI')]
        [ValidateSet('library', 'exe')]
        [string]$TargetType = 'library',
        
        [Parameter(ParameterSetName = 'GUI')]
        [switch]$ShowGui
    )

    # --- INTERNAL HELPER: Console UI Panel (Unchanged) ---
    function Show-BuildReportConsole {
        param([PSCustomObject]$BuildInfo)
        $width = 74
        function Get-TruncatedString { param($String, $MaxLength = 55); if ([string]::IsNullOrEmpty($String) -or $String.Length -le $MaxLength) { return $String }; $start = [math]::Floor($MaxLength / 2) - 3; $end = $String.Length - ([math]::Ceiling($MaxLength / 2) - 3); return $String.Substring(0, $start) + '...' + $String.Substring($end) }
        function Write-FormattedLine { param($Label, $Value, $ValueColor = 'White'); $labelSegment = " $($Label.PadRight(12)): "; $maxValueLength = $width - 4 - $labelSegment.Length; $truncatedValue = Get-TruncatedString -String $Value -MaxLength $maxValueLength; Write-Host "║" -NoNewline -ForegroundColor Gray; Write-Host $labelSegment -NoNewline -ForegroundColor Cyan; Write-Host $truncatedValue -NoNewline -ForegroundColor $ValueColor; $currentLength = 1 + $labelSegment.Length + $truncatedValue.Length; $padding = $width - $currentLength - 1; Write-Host (' ' * $padding) -NoNewline; Write-Host "║" -ForegroundColor Gray }
        function Write-SectionDivider { Write-Host "╟$('─' * ($width - 2))╢" -ForegroundColor Gray }
        $statusColor = if ($BuildInfo.Status -eq 'SUCCESS') { 'Green' } else { 'Red' };Write-Host "╔$('═' * ($width - 2))╗" -ForegroundColor Gray;Write-FormattedLine "Status" $BuildInfo.Status $statusColor;Write-SectionDivider;Write-FormattedLine "OS" $BuildInfo.Environment.OS;Write-FormattedLine "PowerShell" $BuildInfo.Environment.PSVersion.ToString();Write-SectionDivider;Write-FormattedLine "Sources" "$($BuildInfo.SourceFiles.Count) included";foreach ($file in $BuildInfo.SourceFiles) {$fileInfo = "{0} ({1:N2} KB)" -f $file.Name, ($file.Length / 1KB);Write-FormattedLine "   " "- $fileInfo" 'DarkGray'};Write-SectionDivider;if ($BuildInfo.Status -eq 'SUCCESS') { Write-FormattedLine "Output File" $BuildInfo.OutputFile.Name; Write-FormattedLine "   Size" ("{0:N2} KB" -f ($BuildInfo.OutputFile.Length / 1KB)); Write-FormattedLine "   Full Path" $BuildInfo.OutputFile.FullName; Write-SectionDivider };Write-FormattedLine "Compiler" $BuildInfo.Compiler.Name;Write-FormattedLine "References" "$($BuildInfo.References.Count) included";foreach ($ref in $BuildInfo.References) {Write-FormattedLine "   " "- $ref" 'DarkGray'};if ($BuildInfo.ErrorMessage) {Write-SectionDivider;$BuildInfo.ErrorMessage.Split("`n") | ForEach-Object { $line = $_.Trim();if ($line) { Write-FormattedLine "   Error" $line 'Red' } }} else {Write-FormattedLine "Duration" ("{0:N3} seconds" -f $BuildInfo.Duration.TotalSeconds) 'Yellow'};Write-Host "╚$('═' * ($width - 2))╝" -ForegroundColor Gray
    }


    # --- INTERNAL HELPER: Core Compilation Logic (Unchanged) ---
    function Start-Compilation {
        param(
            [string[]]$CompileSourceFiles,
            [string]$CompileOutputPath,
            [string]$CompileTargetType,
            [string[]]$CompileReferences,
            [scriptblock]$LogAction
        )
        function Invoke-Log { param($Message) if ($LogAction) { & $LogAction $Message } }
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        $envData = [PSCustomObject]@{ OS = (Get-CimInstance Win32_OperatingSystem).Caption.Trim(); PSVersion = $PSVersionTable.PSVersion }
        $buildData = [PSCustomObject]@{ Status = 'PENDING'; SourceFiles = Get-Item -Path $CompileSourceFiles; References = $CompileReferences; Compiler = $null; OutputFile = $null; Duration = $null; ErrorMessage = $null; Environment = $envData }
        try {
            Invoke-Log "Searching for C# compiler (csc.exe)..."
            $cscPath = Get-ChildItem -Path "C:\Windows\Microsoft.NET\Framework64" -Filter "csc.exe" -Recurse -ErrorAction SilentlyContinue | Sort-Object -Property LastWriteTime -Descending | Select-Object -First 1 -ExpandProperty FullName
            if (-not $cscPath) { throw "C# compiler (csc.exe) not found in C:\Windows\Microsoft.NET\Framework64." }
            $buildData.Compiler = Get-Item -Path $cscPath
            Invoke-Log "SUCCESS: Compiler found at $($buildData.Compiler.FullName)"
            Invoke-Log "Resolving output file path..."
            if ([string]::IsNullOrEmpty($CompileOutputPath)) {
                $baseName = [System.IO.Path]::GetFileNameWithoutExtension($buildData.SourceFiles[0].FullName)
                $directory = [System.IO.Path]::GetDirectoryName($buildData.SourceFiles[0].FullName)
                $extension = if ($CompileTargetType -eq 'exe') { '.exe' } else { '.dll' }
                $resolvedOutputPath = Join-Path -Path $directory -ChildPath "$baseName$extension"
            } else { $resolvedOutputPath = [System.IO.Path]::GetFullPath($CompileOutputPath) }
            Invoke-Log "Output path set to: $resolvedOutputPath"
            Invoke-Log "Constructing compiler arguments..."
            $resolvedSourceFiles = ($buildData.SourceFiles.FullName | ForEach-Object { "`"$_`"" }) -join ' '
            $command = "& `"$cscPath`" /nologo /target:$CompileTargetType /out:`"$resolvedOutputPath`" /reference:$($CompileReferences -join ',') $resolvedSourceFiles"
            Invoke-Log "COMMAND: $command"
            Invoke-Log "Executing compiler... (This may take a moment)"
            $compilerOutput = Invoke-Expression -Command $command 2>&1
            Invoke-Log "Compiler finished. Exit Code: $LASTEXITCODE"
            if ($LASTEXITCODE -ne 0) { throw "Compilation failed.`n$($compilerOutput | Out-String)" }
            $stopwatch.Stop()
            $buildData.Status = 'SUCCESS'
            $buildData.Duration = $stopwatch.Elapsed
            $buildData.OutputFile = Get-Item -Path $resolvedOutputPath
            Invoke-Log "SUCCESS: Build completed in $($buildData.Duration.TotalSeconds.ToString("F3")) seconds."
        } catch {
            $stopwatch.Stop()
            $buildData.Status = 'FAILURE'
            $buildData.Duration = $stopwatch.Elapsed
            $buildData.ErrorMessage = $_.Exception.Message
            Invoke-Log "ERROR: Build failed. See details below."
        }
        return $buildData
    }

    # --- INTERNAL HELPER: Windows Form GUI (PROFESSIONAL DARK THEME) ---
    function Show-BuildGui {
        Add-Type -AssemblyName System.Windows.Forms
        Add-Type -AssemblyName System.Drawing

        # --- Theme Definition ---
        $theme = @{
            BgColor      = [System.Drawing.Color]::FromArgb(45, 45, 48)
            FgColor      = [System.Drawing.Color]::FromArgb(241, 241, 241)
            AccentColor  = [System.Drawing.Color]::FromArgb(0, 122, 204)
            ControlBg    = [System.Drawing.Color]::FromArgb(60, 60, 63)
            Font         = New-Object System.Drawing.Font('Segoe UI', 9)
        }

        # --- Form Setup ---
        $form = New-Object System.Windows.Forms.Form
        $form.Text = 'C# Compiler'
        $form.Size = '600, 680'
        $form.MinimumSize = $form.Size
        $form.StartPosition = 'CenterScreen'
        $form.FormBorderStyle = 'FixedSingle'
        $form.MaximizeBox = $false
        $form.BackColor = $theme.BgColor

        # --- UI Elements ---
        $lblSources = New-Object System.Windows.Forms.Label; $lblSources.Text = 'Source Files'; $lblSources.Location = '15, 15'; $lblSources.AutoSize = $true
        $lstSources = New-Object System.Windows.Forms.ListBox; $lstSources.Location = '15, 35'; $lstSources.Size = '430, 120'; $lstSources.SelectionMode = 'MultiExtended'; $lstSources.Anchor = 'Top, Left, Right'; $lstSources.BackColor = $theme.ControlBg; $lstSources.ForeColor = $theme.FgColor; $lstSources.Font = $theme.Font; $lstSources.BorderStyle = 'None'

        $btnAdd = New-Object System.Windows.Forms.Button; $btnAdd.Text = 'Add...'; $btnAdd.Location = '460, 35'; $btnAdd.Size = '110, 25'
        $btnRemove = New-Object System.Windows.Forms.Button; $btnRemove.Text = 'Remove'; $btnRemove.Location = '460, 65'; $btnRemove.Size = '110, 25'
        $btnClear = New-Object System.Windows.Forms.Button; $btnClear.Text = 'Clear'; $btnClear.Location = '460, 95'; $btnClear.Size = '110, 25'

        $lblOutput = New-Object System.Windows.Forms.Label; $lblOutput.Text = 'Output File Path'; $lblOutput.Location = '15, 170'; $lblOutput.AutoSize = $true
        $txtOutput = New-Object System.Windows.Forms.TextBox; $txtOutput.Location = '15, 190'; $txtOutput.Size = '430, 23'; $txtOutput.Anchor = 'Top, Left, Right'; $txtOutput.BackColor = $theme.ControlBg; $txtOutput.ForeColor = $theme.FgColor; $txtOutput.Font = $theme.Font; $txtOutput.BorderStyle = 'None'
        $btnBrowse = New-Object System.Windows.Forms.Button; $btnBrowse.Text = 'Browse...'; $btnBrowse.Location = '460, 189'; $btnBrowse.Size = '110, 25'

        $grpTarget = New-Object System.Windows.Forms.GroupBox; $grpTarget.Text = 'Target Type'; $grpTarget.Location = '15, 230'; $grpTarget.Size = '555, 55'; $grpTarget.Anchor = 'Top, Left, Right'
        $radDll = New-Object System.Windows.Forms.RadioButton; $radDll.Text = 'DLL (Library)'; $radDll.Location = '20, 20'; $radDll.Checked = $true; $radDll.AutoSize = $true
        $radExe = New-Object System.Windows.Forms.RadioButton; $radExe.Text = 'EXE (Executable)'; $radExe.Location = '150, 20'; $radExe.AutoSize = $true
        $grpTarget.Controls.AddRange(@($radDll, $radExe))

        $btnBuild = New-Object System.Windows.Forms.Button; $btnBuild.Text = 'Build'; $btnBuild.Location = '15, 300'; $btnBuild.Size = '555, 40'; $btnBuild.Font = New-Object System.Drawing.Font('Segoe UI', 12, [System.Drawing.FontStyle]::Bold); $btnBuild.BackColor = $theme.AccentColor; $btnBuild.ForeColor = $theme.FgColor; $btnBuild.FlatStyle = 'Flat'; $btnBuild.FlatAppearance.BorderSize = 0; $btnBuild.Anchor = 'Top, Left, Right'
        
        $lblLog = New-Object System.Windows.Forms.Label; $lblLog.Text = 'Build Log'; $lblLog.Location = '15, 355'; $lblLog.AutoSize = $true
        $txtLog = New-Object System.Windows.Forms.TextBox; $txtLog.Location = '15, 375'; $txtLog.Size = '555, 250'; $txtLog.Multiline = $true; $txtLog.ScrollBars = 'Vertical'; $txtLog.ReadOnly = $true; $txtLog.BackColor = $theme.ControlBg; $txtLog.ForeColor = $theme.FgColor; $txtLog.Font = New-Object System.Drawing.Font('Consolas', 9); $txtLog.BorderStyle = 'None'; $txtLog.Anchor = 'Top, Bottom, Left, Right'
        
        # Apply styles to all relevant controls
        @($lblSources, $lblOutput, $lblLog, $grpTarget, $radDll, $radExe) | ForEach-Object { $_.Font = $theme.Font; $_.ForeColor = $theme.FgColor }
        @($btnAdd, $btnRemove, $btnClear, $btnBrowse) | ForEach-Object { $_.Font = $theme.Font; $_.ForeColor = $theme.FgColor; $_.BackColor = $theme.ControlBg; $_.FlatStyle = 'Flat'; $_.FlatAppearance.BorderSize = 0 }
        
        $form.Controls.AddRange(@($lblSources, $lstSources, $btnAdd, $btnRemove, $btnClear, $lblOutput, $txtOutput, $btnBrowse, $grpTarget, $btnBuild, $lblLog, $txtLog))
        
        # --- Logger Function for GUI ---
        function Add-LogEntry {
            param($Message)
            $timestamp = Get-Date -Format "HH:mm:ss"
            $txtLog.AppendText("[$timestamp] $Message`r`n")
        }

        # --- Event Handlers ---
        $btnAdd.Add_Click({
            $fileDialog = New-Object System.Windows.Forms.OpenFileDialog
            $fileDialog.Filter = 'C# Source Files (*.cs)|*.cs|All Files (*.*)|*.*'
            $fileDialog.Multiselect = $true
            if ($fileDialog.ShowDialog() -eq 'OK') {
                $fileDialog.FileNames | ForEach-Object { if (-not $lstSources.Items.Contains($_)) { $lstSources.Items.Add($_) } }
            }
        })
        $btnRemove.Add_Click({ @($lstSources.SelectedItems) | ForEach-Object { $lstSources.Items.Remove($_) } })
        $btnClear.Add_Click({ $lstSources.Items.Clear() })
        $btnBrowse.Add_Click({
            $saveDialog = New-Object System.Windows.Forms.SaveFileDialog
            $targetExt = if ($radExe.Checked) { 'exe' } else { 'dll' }
            $saveDialog.Filter = "Output File (*.$targetExt)|*.$targetExt|All Files (*.*)|*.*"
            if ($saveDialog.ShowDialog() -eq 'OK') { $txtOutput.Text = $saveDialog.FileName }
        })

        $btnBuild.Add_Click({
            if ($lstSources.Items.Count -eq 0) {
                [void][System.Windows.Forms.MessageBox]::Show('Please add at least one source file.', 'Error', 'OK', 'Error')
                return
            }
            
            $btnBuild.Enabled = $false
            $btnBuild.Text = 'Building...'
            $txtLog.Clear(); $form.Update()

            $logCallback = { param($logMessage) Add-LogEntry -Message $logMessage }
            $buildResult = Start-Compilation -CompileSourceFiles @($lstSources.Items) -CompileOutputPath $txtOutput.Text -CompileTargetType $(if ($radDll.Checked) { 'library' } else { 'exe' }) -CompileReferences $References -LogAction $logCallback
            
            # --- Append Final Summary to Log ---
            $summary = New-Object System.Text.StringBuilder
            $summary.AppendLine("`r`n---------------- BUILD SUMMARY ----------------") | Out-Null
            $summary.AppendLine("Final Status: $($buildResult.Status)") | Out-Null

            if ($buildResult.Status -eq 'SUCCESS') {
                $summary.AppendLine("Output File:  $($buildResult.OutputFile.Name)") | Out-Null
                $summary.AppendLine("File Size:    $('{0:N2} KB' -f ($buildResult.OutputFile.Length / 1KB))") | Out-Null
            } else {
                $summary.AppendLine("ERROR DETAILS:") | Out-Null
                if ($buildResult.ErrorMessage) {
                    $buildResult.ErrorMessage.Split("`n") | ForEach-Object { $summary.AppendLine("   $_".TrimEnd()) | Out-Null }
                }
            }
            $txtLog.AppendText($summary.ToString())
            
            $btnBuild.Enabled = $true
            $btnBuild.Text = 'Build'
        })

        # --- Show Form ---
        $form.ShowDialog() | Out-Null
    }


    # --- MAIN SCRIPT LOGIC (Unchanged) ---
    if ($ShowGui) {
        Show-BuildGui
    } else {
        Write-Host "[ ] Compiling $($SourceFiles.Count) source file(s) via CLI..." -NoNewline -ForegroundColor Yellow
        $buildResult = Start-Compilation -CompileSourceFiles $SourceFiles -CompileOutputPath $OutputPath -CompileTargetType $TargetType -CompileReferences $References
        if ($buildResult.Status -eq 'SUCCESS') {
            Write-Host "`r[✅] Compiling $($SourceFiles.Count) source file(s) via CLI... Done." -ForegroundColor Green
            Write-Host "`n"; Show-BuildReportConsole -BuildInfo $buildResult; return $buildResult.OutputFile
        } else {
            Write-Host "`r[❌] Compiling $($SourceFiles.Count) source file(s) via CLI... Failed." -ForegroundColor Red
            Write-Host "`n"; Show-BuildReportConsole -BuildInfo $buildResult
        }
    }
}
