Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ============================================================================
# 1. MILJÖ OCH SÖKVÄGAR
# ============================================================================
$ScriptRoot = $PSScriptRoot
if (-not $ScriptRoot) {
    $ScriptRoot = Split-Path -Path $MyInvocation.MyCommand.Path -Parent
}

$ConfigFolder = Join-Path $ScriptRoot "Config"
$ViewsFolder  = Join-Path $ScriptRoot "Views"
$LogoJsonPath = Join-Path $ConfigFolder "Logo.json"
$Global:ThemeJsonPath = Join-Path $ConfigFolder "Theme.json"

# --- LÅS IN LOKAL SMLETS-MODUL (INGEN SYSTEM-FALLBACK) ---
$localSMLetsPath = Join-Path $ScriptRoot "SMLets\SMLets.psd1"
if (-not (Test-Path $localSMLetsPath)) {
    $localSMLetsPath = Join-Path $ScriptRoot "SMLets\SMLets.psm1"
}

if (Test-Path $localSMLetsPath) {
    Get-Module -Name SMLets | Remove-Module -Force -ErrorAction SilentlyContinue
    Import-Module -Name $localSMLetsPath -Force -Global -ErrorAction Stop
    $Global:LocalSMLetsLoaded = $true
} else {
    $Global:LocalSMLetsLoaded = $false
    [System.Windows.Forms.MessageBox]::Show(
        "Kunde inte hitta lokal SMLets i:" + [Environment]::NewLine + "$ScriptRoot\SMLets\" + [Environment]::NewLine + [Environment]::NewLine + "Verktyget kräver den lokala SMLets-modulen.",
        "SMLets saknas",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Warning
    )
}

function Global:Invoke-KrimsonSql {
    param(
        [Parameter(Mandatory=$true)][string]$Query,
        [string]$ProfileName,
        [string]$SqlServer,
        [string]$Database
    )

    if (-not $SqlServer -or -not $Database) {
        $regBase = "HKCU:\Software\KrimsonTools\Settings"
                if (-not $ProfileName) {
            $ProfileName = (Get-ItemProperty -Path "HKCU:\Software\KrimsonTools" -ErrorAction SilentlyContinue).LastActiveEnvironment
            if (-not $ProfileName) { $ProfileName = (Get-ItemProperty -Path "$regBase\Global" -ErrorAction SilentlyContinue).AktivProfil }
        }
        if (-not $ProfileName) { throw "Ingen miljöprofil är vald." }

        $profData = Get-ItemProperty -Path "$regBase\MiljoProfiler\$ProfileName" -ErrorAction SilentlyContinue
        if (-not $SqlServer) { $SqlServer = $profData.SCSM_SQL }
        if (-not $Database)  { $Database  = $profData.SCSM_DB }
    }

    if (-not $SqlServer -or -not $Database) {
        throw "SQL Server eller Databas saknas för profilen '$ProfileName'."
    }

    Write-KrimsonLog "Kör SQL mot [$SqlServer].[$Database] (Profil: $ProfileName)..."
    $connStr = "Server=$SqlServer;Database=$Database;Integrated Security=True;TrustServerCertificate=True;Connection Timeout=3;"
    $conn = New-Object System.Data.SqlClient.SqlConnection($connStr)
    $cmd  = New-Object System.Data.SqlClient.SqlCommand($Query, $conn)
    $da   = New-Object System.Data.SqlClient.SqlDataAdapter($cmd)
    $dt   = New-Object System.Data.DataTable

    try {
        $conn.Open()
        [void]$da.Fill($dt)
        Write-KrimsonLog "SQL slutförd: $($dt.Rows.Count) rader hämtade."
        return $dt
    } catch {
        Write-KrimsonLog "SQL-fel mot [$SqlServer].[$Database]: $($_.Exception.Message)" -UpdateStatus
        throw
    } finally {
        $conn.Close()
        $cmd.Dispose()
        $conn.Dispose()
    }

}

$Global:LogBuffer = New-Object System.Text.StringBuilder

function Global:Write-KrimsonLog {
    param(
        [Parameter(Mandatory=$true)][string]$Message,
        [switch]$UpdateStatus
    )

    $ts = [DateTime]::Now.ToString("yyyy-MM-dd HH:mm:ss")
    $logLine = "[$ts] $Message"
    [void]$Global:LogBuffer.AppendLine($logLine)

    if ($Global:txtLogView -and -not $Global:txtLogView.IsDisposed) {
        $Global:txtLogView.AppendText($logLine + [Environment]::NewLine)
    }

    if ($UpdateStatus -and $Global:statusLabel) {
        $Global:statusLabel.Text = $Message
    }

    $regGlobal = "HKCU:\Software\KrimsonTools\Settings\Global"
    $gCfg = Get-ItemProperty -Path $regGlobal -ErrorAction SilentlyContinue
    if ($gCfg.LogEnabled -eq "True" -and $gCfg.LogFilePath) {
        try {
            $logDir = Split-Path -Path $gCfg.LogFilePath -Parent
            if ($logDir -and -not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
            Add-Content -Path $gCfg.LogFilePath -Value $logLine -Encoding UTF8 -ErrorAction SilentlyContinue
        } catch {}
    }
}

function Global:Show-KrimsonLogView {
    if (-not $Global:panelChildForm) { return }

    # Om loggpanelen redan finns -> ta bort den och visa underliggande vy (Inställningar, Prepare osv.) direkt!
    $existingLog = $Global:panelChildForm.Controls["pnlKrimsonLogOverlay"]
    if ($existingLog) {
        $Global:panelChildForm.Controls.Remove($existingLog)
        $existingLog.Dispose()
        if ($Script:SavedAutoScrollMinSize) { $Global:panelChildForm.AutoScrollMinSize = $Script:SavedAutoScrollMinSize }
        $Global:panelChildForm.AutoScroll = $true
        if ($lblTitle -and $Script:SavedLogPrevTitle) { $lblTitle.Text = $Script:SavedLogPrevTitle }
        return
    }

    $Script:SavedAutoScrollMinSize = $Global:panelChildForm.AutoScrollMinSize
    $Global:panelChildForm.AutoScroll = $false
    $Global:panelChildForm.AutoScrollMinSize = New-Object System.Drawing.Size(0, 0)

    $pnlLog = New-Object System.Windows.Forms.Panel
    $pnlLog.Name = "pnlKrimsonLogOverlay"
    $pnlLog.Dock = [System.Windows.Forms.DockStyle]::Fill
    $pnlLog.BackColor = $Global:colorBgMain
    $pnlLog.Padding = New-Object System.Windows.Forms.Padding(20, 55, 20, 35)
    $Global:panelChildForm.Controls.Add($pnlLog)
    $pnlLog.BringToFront()

    $pnlLogFrame = New-Object System.Windows.Forms.Panel
    $pnlLogFrame.Dock = [System.Windows.Forms.DockStyle]::Fill
    $pnlLogFrame.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $pnlLogFrame.BackColor = $Global:colorBgMain
    $pnlLog.Controls.Add($pnlLogFrame)

    $Global:txtLogView = New-Object System.Windows.Forms.TextBox
    $Global:txtLogView.Dock = [System.Windows.Forms.DockStyle]::Fill
    $Global:txtLogView.BorderStyle = [System.Windows.Forms.BorderStyle]::None
    $Global:txtLogView.Multiline = $true
    $Global:txtLogView.ReadOnly = $true
    $Global:txtLogView.ScrollBars = [System.Windows.Forms.ScrollBars]::Vertical
    $Global:txtLogView.WordWrap = $true
    $Global:txtLogView.BackColor = $Global:colorBgMain
    $Global:txtLogView.ForeColor = $Global:colorTextWhite
    $Global:txtLogView.Font = New-Object System.Drawing.Font("Consolas", 9.5)
    $pnlLogFrame.Controls.Add($Global:txtLogView)

    $btnCopyLog = New-Object System.Windows.Forms.Button
    $btnCopyLog.Text = "Kopiera logg"
    $btnCopyLog.Location = New-Object System.Drawing.Point(20, 15)
    $btnCopyLog.Size = New-Object System.Drawing.Size(130, 28)
    $btnCopyLog.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnCopyLog.BackColor = $Global:colorBgSideMenu
    $btnCopyLog.ForeColor = $Global:colorTextWhite
    $pnlLog.Controls.Add($btnCopyLog)

    $btnOpenLogFile = New-Object System.Windows.Forms.Button
    $btnOpenLogFile.Text = "Öppna loggfil"
    $btnOpenLogFile.Location = New-Object System.Drawing.Point(165, 15)
    $btnOpenLogFile.Size = New-Object System.Drawing.Size(130, 28)
    $btnOpenLogFile.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnOpenLogFile.BackColor = $Global:colorBgSideMenu
    $btnOpenLogFile.ForeColor = $Global:colorTextWhite
    $pnlLog.Controls.Add($btnOpenLogFile)

    $btnClearLog = New-Object System.Windows.Forms.Button
    $btnClearLog.Text = "Rensa vy"
    $btnClearLog.Location = New-Object System.Drawing.Point(310, 15)
    $btnClearLog.Size = New-Object System.Drawing.Size(110, 28)
    $btnClearLog.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnClearLog.BackColor = $Global:colorBgSideMenu
    $btnClearLog.ForeColor = $Global:colorTextWhite
    $pnlLog.Controls.Add($btnClearLog)

    $Global:txtLogView.Text = $Global:LogBuffer.ToString()

    $btnCopyLog.Add_Click({ if ($Global:txtLogView.Text) { [System.Windows.Forms.Clipboard]::SetText($Global:txtLogView.Text) } }.GetNewClosure())
    $btnClearLog.Add_Click({ [void]$Global:LogBuffer.Clear(); $Global:txtLogView.Clear() }.GetNewClosure())
    $btnOpenLogFile.Add_Click({
        $f = (Get-ItemProperty "HKCU:\Software\KrimsonTools\Settings\Global" -ErrorAction SilentlyContinue).LogFilePath
        if ($f -and (Test-Path $f)) { Start-Process notepad.exe "`"$f`"" } else { [System.Windows.Forms.MessageBox]::Show("Ingen loggfil hittades på: $f", "Loggfil") }
    }.GetNewClosure())
}


# ============================================================================
# 2. CENTRALt FÄRGTEMA (Läser teman live från Config\Theme.json)
# ============================================================================
function Global:Load-KrimsonTheme {
    param([string]$ThemePath)
    if (-not $ThemePath) { $ThemePath = Join-Path $PSScriptRoot "Config\Theme.json" }

    # 1. Standard-fallbacks om filen saknas (Så att inga variabler blir null!)
    $Global:ColorBgMain        = [System.Drawing.Color]::FromArgb(31, 31, 43)
    $Global:ColorBgSideMenu    = [System.Drawing.Color]::FromArgb(20, 30, 105)
    $Global:ColorBgChildForm   = [System.Drawing.Color]::FromArgb(16, 16, 16)
    $Global:ColorAccent        = [System.Drawing.Color]::FromArgb(255, 180, 0)
    $Global:ColorBtnHover      = [System.Drawing.Color]::FromArgb(45, 45, 60)
    $Global:ColorTextWhite     = [System.Drawing.Color]::White
    $Global:ColorTextGray      = [System.Drawing.Color]::FromArgb(180, 180, 190)

    # 2. Försök läsa den externa JSON-filen
    if (Test-Path $ThemePath) {
        try {
            $ThemeData = Get-Content -Path $ThemePath -Raw | ConvertFrom-Json
            $Global:ThemeConfig = $ThemeData
            $ActiveName = $ThemeData.ActiveTheme
            $SelectedTheme = $ThemeData.Themes.$ActiveName

            # Hjälpfunktion som plockar ut rött, grönt och blått på rätt sätt
            function Get-ColorObject ($RgbString) {
                $Rgb = $RgbString -split ','
                return [System.Drawing.Color]::FromArgb([int]$Rgb[0], [int]$Rgb[1], [int]$Rgb[2])
            }

            if ($SelectedTheme) {
                $Global:ColorBgMain        = Get-ColorObject $SelectedTheme.BgMain
                $Global:ColorBgSideMenu    = Get-ColorObject $SelectedTheme.BgSideMenu
                $Global:ColorBgChildForm   = Get-ColorObject $SelectedTheme.BgChildForm
                $Global:ColorAccent        = Get-ColorObject $SelectedTheme.AccentColor
                $Global:ColorBtnHover      = Get-ColorObject $SelectedTheme.BtnHover
                $Global:ColorTextWhite     = Get-ColorObject $SelectedTheme.TextWhite
                $Global:ColorTextGray      = Get-ColorObject $SelectedTheme.TextGray
                if (-not $Global:ThemeConfig.Typography) {
                    $Global:ThemeConfig | Add-Member -NotePropertyName "Typography" -NotePropertyValue ([PSCustomObject]@{
                        FontFamily     = if ($SelectedTheme.FontFamily)     { $SelectedTheme.FontFamily }     else { "Verdana" }
                        FontSizeTitle  = if ($SelectedTheme.FontSizeTitle)  { $SelectedTheme.FontSizeTitle }  else { 14 }
                        FontSizeMenu   = if ($SelectedTheme.FontSizeMenu)   { $SelectedTheme.FontSizeMenu }   else { 14 }
                        FontSizeStatus = if ($SelectedTheme.FontSizeStatus) { $SelectedTheme.FontSizeStatus } else { 9 }
                    }) -Force
                }
            }
        } catch {
            Write-Warning "Kunde inte tolka Theme.json, använder standardfärgerna."
        }
    }
}

function Global:Update-KrimsonUITheme {
    if ($Global:panelChildForm) { $Global:panelChildForm.BackColor = $Global:colorBgChildForm }
    if ($panelHeader)           { $panelHeader.BackColor           = $Global:colorBgSideMenu }
    if ($statusStrip)           { $statusStrip.BackColor           = $Global:colorAccent }
    if ($lblTitle)              { $lblTitle.Font = New-Object System.Drawing.Font($Global:ThemeConfig.Typography.FontFamily, [float]$Global:ThemeConfig.Typography.FontSizeTitle, [System.Drawing.FontStyle]::Bold) }
    if ($statusLabel)           { $statusLabel.Font = New-Object System.Drawing.Font($Global:ThemeConfig.Typography.FontFamily, [float]$Global:ThemeConfig.Typography.FontSizeStatus) }
    if ($panelSideMenu) {
        $panelSideMenu.BackColor = $Global:colorBgSideMenu
        foreach ($ctrl in $panelSideMenu.Controls) {
            if ($ctrl -is [System.Windows.Forms.Button]) {
                $ctrl.BackColor = $Global:colorBgSideMenu
                $ctrl.Font = New-Object System.Drawing.Font($Global:ThemeConfig.Typography.FontFamily, [float]$Global:ThemeConfig.Typography.FontSizeMenu)
            }
            elseif ($ctrl -is [System.Windows.Forms.Label]) {
                $ctrl.Font = New-Object System.Drawing.Font($Global:ThemeConfig.Typography.FontFamily, [float]$Global:ThemeConfig.Typography.FontSizeTitle)
            }
        }
    }
}

# Starta färgerna direkt
Load-KrimsonTheme -ThemePath $Global:ThemeJsonPath

# Global lista för aktiva moduler
$Global:LoadedViews = [System.Collections.Generic.List[Object]]::new()

# ============================================================================
# 3. SKANNA OCH IMPORTERA EXTERNA VYER
# ============================================================================
if (Test-Path $ViewsFolder) {
    $ViewFiles = Get-ChildItem -Path (Join-Path $ViewsFolder "*.ps1")
    foreach ($File in $ViewFiles) {
        try {
            . $File.FullName
            if (Get-Command "Get-ViewConfig" -ErrorAction SilentlyContinue) {
                $Config = Get-ViewConfig
                if ($Config.Enabled -eq $true) {
                    $viewData = [PSCustomObject]@{
                        MainMenu     = $Config.MainMenu
                        MainMenuPrio = [int]$Config.MainMenuPrio
                        SubMenu      = $Config.SubMenu
                        SubMenuPrio  = [int]$Config.SubMenuPrio
                        StatusText   = $Config.StatusText
                        SettingsFunc = $Config.SettingsFunc
                        MainFunc     = $Config.MainFunc
                    }
                    $Global:LoadedViews.Add($viewData)
                    Write-KrimsonLog "Laddade vy: $($Config.MainMenu) - $($Config.SubMenu) ($($File.Name))"
                } elseif ($File.Name -eq "View-Settings.ps1") {
                    Write-KrimsonLog "Laddade systemvy: $($File.Name)"
                } else {
                    if ($Config.MainFunc) { Remove-Item "Function:\$($Config.MainFunc)" -ErrorAction SilentlyContinue }
                    Write-KrimsonLog "Hoppade över inaktiv vy: $($File.Name) (Enabled = false)"
                }
                Remove-Item Function:\Get-ViewConfig -ErrorAction SilentlyContinue
            }
        } catch {
            Write-KrimsonLog "FEL vid inläsning av vy $($File.Name): $_"
            Write-Warning "Kunde inte ladda: $($File.Name). Fel: $_"
        }
    }
}
$Global:SortedViews = $Global:LoadedViews | Sort-Object MainMenuPrio, SubMenuPrio

# Läs in logg-grafik från Logo.json
$logoImage = $null; $ms = $null
if (Test-Path $LogoJsonPath) {
    try {
        $LogoData = Get-Content -Path $LogoJsonPath -Raw | ConvertFrom-Json
        if ($LogoData.LogoBase64) {
            $imageBytes = [System.Convert]::FromBase64String($LogoData.LogoBase64)
            $ms = New-Object System.IO.MemoryStream($imageBytes, 0, $imageBytes.Length)
            $logoImage = [System.Drawing.Image]::FromStream($ms)
        }
    } catch {}
}

# ============================================================================
# 4. GRAFISKT GRÄNSSNITT (Perfekt dockningsordning - Topp, Botten & Mitten först)
# ============================================================================
$KrimsonForm = New-Object System.Windows.Forms.Form
$KrimsonForm.Text = "KrimsonTool v0.1"
$KrimsonForm.Size = New-Object System.Drawing.Size(1200, 800)
$KrimsonForm.StartPosition = "CenterScreen"
$KrimsonForm.BackColor = $Global:ColorBgMain

$iconJsonPath = Join-Path $PSScriptRoot "Config\icon.json"
if (Test-Path $iconJsonPath) {
    try {
        $iconData = Get-Content -Path $iconJsonPath -Raw | ConvertFrom-Json
        if (-not [string]::IsNullOrWhiteSpace($iconData.AppIconBase64)) {
            $iconBytes = [System.Convert]::FromBase64String($iconData.AppIconBase64)
            $iconMs = New-Object System.IO.MemoryStream(,$iconBytes)
            $KrimsonForm.Icon = New-Object System.Drawing.Icon($iconMs)
            $KrimsonForm.ShowIcon = $true
        }
    } catch {
        Write-KrimsonLog "Kunde inte läsa in applikationsikon från Assets\icon.json: $_"
    }
}

# --- STEG 1: RUBRIKPANEL (Läggs till först, fyller toppen) ---
$panelHeader = New-Object System.Windows.Forms.Panel
$panelHeader.Height = 40
$panelHeader.Dock = [System.Windows.Forms.DockStyle]::Top
$panelHeader.BackColor = $Global:colorBgSideMenu

$lblTitle = New-Object System.Windows.Forms.Label
$lblTitle.Text = ""
$lblTitle.Font = New-Object System.Drawing.Font($Global:ThemeConfig.Typography.FontFamily, [float]$Global:ThemeConfig.Typography.FontSizeTitle, [System.Drawing.FontStyle]::Bold)
$lblTitle.ForeColor = $Global:ColorTextWhite
$lblTitle.Location = New-Object System.Drawing.Point(15, 8)
$lblTitle.AutoSize = $true
$panelHeader.Controls.Add($lblTitle)
$KrimsonForm.Controls.Add($panelHeader)

# --- STEG 2: STATUSRAD LÄNGST NER MED MILJÖDROPDOWN ---
$statusStrip = New-Object System.Windows.Forms.StatusStrip
$ActiveName = $Global:ThemeConfig.ActiveTheme
if ($Global:ThemeConfig.Themes."$ActiveName".AccentColor) {
    $AccentRGB = $Global:ThemeConfig.Themes."$ActiveName".AccentColor.Split(',')
    $statusStrip.BackColor = [System.Drawing.Color]::FromArgb($AccentRGB[0], $AccentRGB[1], $AccentRGB[2])
} else {
    $statusStrip.BackColor = $Global:colorBgSideMenu
}
$statusStrip.SizingGrip = $false 
$statusStrip.Dock = [System.Windows.Forms.DockStyle]::Bottom

# 1. Statusmeddelande till vänster
$statusLabel = New-Object System.Windows.Forms.ToolStripStatusLabel
$statusLabel.Text = "Redo"
$statusLabel.ForeColor = $Global:ColorTextWhite
$statusStrip.Items.Add($statusLabel) | Out-Null

# 2. Skapa ett osynligt fjäderelement som trycker miljövalet till absolut längst till höger
$springLabel = New-Object System.Windows.Forms.ToolStripStatusLabel
$springLabel.Spring = $true
$statusStrip.Items.Add($springLabel) | Out-Null

$Global:statusLabel = $statusLabel
$springLabel.DoubleClickEnabled = $true
$statusLabel.DoubleClickEnabled = $true
$springLabel.Add_MouseEnter({ $Script:prevStatus = $statusLabel.Text; $statusLabel.Text = "[Dubbelklicka för Händelselogg]" })
$springLabel.Add_MouseLeave({ if ($Script:prevStatus) { $statusLabel.Text = $Script:prevStatus } })
$springLabel.Add_DoubleClick({ Show-KrimsonLogView })
$statusLabel.Add_DoubleClick({ Show-KrimsonLogView })

# 3. Skapa själva dropdown-menyn för statusraden
$Global:comboStatusMiljo = New-Object System.Windows.Forms.ComboBox
$Global:comboStatusMiljo.Size = New-Object System.Drawing.Size(100, 22)
$Global:comboStatusMiljo.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
$Global:comboStatusMiljo.BackColor = [System.Drawing.Color]::FromArgb(45, 45, 48)
$Global:comboStatusMiljo.ForeColor = [System.Drawing.Color]::White

# Läs in dina registrerade profiler live från Registereditorn (IT, PreProd, Prod, Test)
$RegPathMiljo = "HKCU:\Software\KrimsonTools\Settings\MiljoProfiler"
if (Test-Path $RegPathMiljo) {
    $Profiler = (Get-ChildItem -Path $RegPathMiljo).PSChildName
    foreach ($Profil in $Profiler) {
        [void]$Global:comboStatusMiljo.Items.Add($Profil)
    }
}

# Hämta senast sparade miljö från registret och sätt den som vald i bottenraden
$RegPathBase = "HKCU:\Software\KrimsonTools"
$LastEnv = (Get-ItemProperty -Path $RegPathBase -Name "LastActiveEnvironment" -ErrorAction SilentlyContinue).LastActiveEnvironment
if ($LastEnv -and $Global:comboStatusMiljo.Items.Contains($LastEnv)) {
    $Global:comboStatusMiljo.SelectedItem = $LastEnv
} elseif ($Global:comboStatusMiljo.Items.Count -gt 0) {
    $Global:comboStatusMiljo.SelectedIndex = 0
}

# Kapsla in ComboBoxen så den tillåts bo inuti statusraden
$hostCombo = New-Object System.Windows.Forms.ToolStripControlHost($Global:comboStatusMiljo)
$statusStrip.Items.Add($hostCombo) | Out-Null
$statusStrip.Font = New-Object System.Drawing.Font($Global:ThemeConfig.Typography.FontFamily, $Global:ThemeConfig.Typography.FontSizeStatus)
$KrimsonForm.Controls.Add($statusStrip)

# HÄNDELSE: När en tekniker byter miljö nere i statusraden -> Spara och synka mittenvyn live!
$Global:comboStatusMiljo.Add_SelectedIndexChanged({
    $ValdMiljo = $Global:comboStatusMiljo.SelectedItem.ToString()
    Set-ItemProperty -Path "HKCU:\Software\KrimsonTools" -Name "LastActiveEnvironment" -Value $ValdMiljo -Force
    
    if ($Global:comboSettingsMiljo -and $Global:comboSettingsMiljo.Visible) {
        if ($Global:comboSettingsMiljo.SelectedItem.ToString() -ne $ValdMiljo) {
            $Global:comboSettingsMiljo.SelectedItem = $ValdMiljo
        }
    }
})

# --- STEG 3: ARBETSYTA / CHILD FORM (Fyller ut hela tomrummet) ---
$Global:panelChildForm = New-Object System.Windows.Forms.Panel
$Global:panelChildForm.Dock = [System.Windows.Forms.DockStyle]::Fill
$Global:panelChildForm.BackColor = $Global:ColorBgChildForm
$KrimsonForm.Controls.Add($Global:panelChildForm)
$Global:panelChildForm.BringToFront()

# --- STEG 4: SIDOMENY (Läggs till ALLRA SIST för att skära av hörnen från topp till botten) ---
$panelSideMenu = New-Object System.Windows.Forms.FlowLayoutPanel
$panelSideMenu.FlowDirection = [System.Windows.Forms.FlowDirection]::TopDown
$panelSideMenu.Width = 175
$panelSideMenu.Height = 800
$panelSideMenu.Dock = [System.Windows.Forms.DockStyle]::Left
$panelSideMenu.BackColor = $Global:colorBgSideMenu
$KrimsonForm.Controls.Add($panelSideMenu)

# Logotyp överst i den nyskapade sidomenyn
if ($logoImage -ne $null) {
    $pictureBoxLogo = New-Object System.Windows.Forms.PictureBox
    $pictureBoxLogo.Margin = New-Object System.Windows.Forms.Padding(15, 15, 0, 20)
    $pictureBoxLogo.SizeMode = [System.Windows.Forms.PictureBoxSizeMode]::AutoSize
    $pictureBoxLogo.Image = $logoImage
    $pictureBoxLogo.Cursor = [System.Windows.Forms.Cursors]::Hand
    
    # HÄNDELSE: När man klickar på Loggan öppnas inställningarna i ChildFormuläret!
    $Global:LastActiveView  = ""
    $Global:LastActiveTitle = ""
    $pictureBoxLogo.Add_DoubleClick({

        $CurrentTitle = ""
        if ($lblTitle -and $lblTitle.Text) {
            $CurrentTitle = $lblTitle.Text
        }

        # VÄXLINGSFUNKTION (TOGGLE): OM RUBRIKEN REDAN ÄR INSTÄLLNINGAR -> SKICKA TILLBAKA TEKNIKERN
        if ($CurrentTitle -eq "Inställningar") {
            if ($Global:LastActiveView -and (Get-Command $Global:LastActiveView -ErrorAction SilentlyContinue)) {
                $lblTitle.Text = $Global:LastActiveTitle
                $statusLabel.Text = "Återgår till föregående vy..."
                & $Global:LastActiveView
            } else {
                # Var på startläget (tomt fönster) -> rensa tillbaka till tomt startläge
                $lblTitle.Text = ""
                $statusLabel.Text = "Redo"
                if ($Global:panelChildForm) { $Global:panelChildForm.Controls.Clear() }
            }
        }
        else {
            # Sätt rätt topprubrik och status
            $lblTitle.Text = "Inställningar"
            $statusLabel.Text = "Öppnar konfiguration..."

            # Anropa den modulära inställningsvyn från View-Settings.ps1
            Show-SettingsViewInstallningarKonfiguration
        }
    })

    $panelSideMenu.Controls.Add($pictureBoxLogo)
}

# ============================================================================
# 5. GENERERA MENYUTBUD UTIFRÅN SKANNADE FILER
# ============================================================================
$LastMainMenu = ""

foreach ($View in $Global:SortedViews) {
    if ($View.MainMenu -ne $LastMainMenu) {
        $lblHeader = New-Object System.Windows.Forms.Label
        $lblHeader.Text = $View.MainMenu
        $lblHeader.ForeColor = $Global:colorTextWhite
        $lblHeader.Font = New-Object System.Drawing.Font($Global:ThemeConfig.Typography.FontFamily, [float]$Global:ThemeConfig.Typography.FontSizeTitle)
        $lblHeader.AutoSize = $true
        $panelSideMenu.Controls.Add($lblHeader)
        $lblHeader.Tag = $View.MainMenu
        $LastMainMenu = $View.MainMenu

    $ToggleMainMenu = {
        param($sender, $e)
        $CurrentMenu = $sender.Tag
        $IsNowExpanded = $false

        # Växla synlighet på den klickade menyns underknappar, och stäng alla andra menyer
        foreach ($Control in $panelSideMenu.Controls) {
            if ($Control -is [System.Windows.Forms.Button]) {
                if ($Control.Tag.MainMenu -eq $CurrentMenu) {
                    $Control.Visible = -not $Control.Visible
                    $IsNowExpanded = $Control.Visible
                } else {
                    $Control.Visible = $false
                }
            }
        }

        # Återställ alla rubriker till vit textfärg först
        foreach ($Control in $panelSideMenu.Controls) {
            if ($Control -is [System.Windows.Forms.Label]) {
                $Control.ForeColor = $Global:colorTextWhite
            }
        }

        # Tänd endast den klickade rubriken med AccentColor om undermenyn nu är utfälld
        if ($IsNowExpanded) {
            $ActiveName = $Global:ThemeConfig.ActiveTheme
            if ($Global:ThemeConfig.Themes."$ActiveName".AccentColor) {
                $AccentRGB = $Global:ThemeConfig.Themes."$ActiveName".AccentColor.Split(',')
                $sender.ForeColor = [System.Drawing.Color]::FromArgb($AccentRGB[0], $AccentRGB[1], $AccentRGB[2])
            }
        }

        $panelSideMenu.PerformLayout()
    }

    $lblHeader.Add_Click($ToggleMainMenu)
    $lblHeader.Add_DoubleClick($ToggleMainMenu)

    }
    
    $btnMenu = New-Object System.Windows.Forms.Button
    $btnMenu.Text = "  " + $View.SubMenu
    $btnMenu.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
    $btnMenu.Size = New-Object System.Drawing.Size(155, 30)
    $btnMenu.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnMenu.FlatAppearance.BorderSize = 0
    $btnMenu.ForeColor = $Global:colorTextWhite
    $btnMenu.Font = New-Object System.Drawing.Font($Global:ThemeConfig.Typography.FontFamily, [float]$Global:ThemeConfig.Typography.FontSizeTitle)
    $btnMenu.BackColor = $Global:ColorBgSideMenu
    $btnMenu.Visible = ($View.SubMenu -eq $View.MainMenu)
    $btnMenu.Tag = $View
    $panelSideMenu.Controls.Add($btnMenu)

    $btnMenu.Add_MouseEnter({
        $this.BackColor = $Global:ColorBtnHover
        $statusLabel.Text = $this.Tag.StatusText
    })
    $btnMenu.Add_MouseLeave({
        $this.BackColor = $Global:ColorBgSideMenu
        $statusLabel.Text = "Redo"
    })
    
    $btnMenu.Add_Click({
        param($sender, $e)
        $ClickedView = $sender.Tag
        $lblTitle.Text = "$($ClickedView.MainMenu) - $($ClickedView.SubMenu)"
        $lblTitle.Font = New-Object System.Drawing.Font($Global:ThemeConfig.Typography.FontFamily, [float]$Global:ThemeConfig.Typography.FontSizeTitle)
        $Global:panelChildForm.Controls.Clear()

        # --- ÅTERSTÄLL MENYFÄRGER OCH KOLLAPSA UNDERMENY ---
        # 1. Återställ alla huvudrubriker (Label) och knappar (Button) till vit textfärg
        foreach ($Control in $panelSideMenu.Controls) {
            if ($Control -is [System.Windows.Forms.Label] -or $Control -is [System.Windows.Forms.Button]) {
                $Control.ForeColor = $Global:colorTextWhite
            }
        }

        # 2. Om vi klickar på ett undermenyval (t.ex. Tickets), kollapsa alla underknappar under den huvudmenyn
        if ($ClickedView.SubMenu -ne $ClickedView.MainMenu) {
            foreach ($Control in $panelSideMenu.Controls) {
                if ($Control -is [System.Windows.Forms.Button] -and $Control.Tag.MainMenu -eq $ClickedView.MainMenu) {
                    $Control.Visible = $false
                }
            }
            $panelSideMenu.PerformLayout()
        }
        
        # Spara att vi inte är i Settings och kom ihåg senaste vy i minne + register
        $Global:IsSettingsOpen = $false
        $Global:LastActiveView = $ClickedView.MainFunc
        $Global:LastActiveTitle = "$($ClickedView.MainMenu) - $($ClickedView.SubMenu)"

        # Kör den globala funktionen trådsäkert och modulärt
        if (Get-Command $ClickedView.MainFunc -ErrorAction SilentlyContinue) {
            Write-KrimsonLog "Öppnade vy: $($ClickedView.MainMenu) - $($ClickedView.SubMenu)"
            & $ClickedView.MainFunc
        }
    })
    
    $ButtonY += 35
}

# --- SÄKER NEDSTÄNGNING OCH RESURSSTÄDNING ---

$KrimsonForm.Add_FormClosing({
    param($sender, $e)
    if ($logoImage -ne $null) { $logoImage.Dispose() }
    if ($ms -ne $null) { $ms.Dispose() }
    $KrimsonForm.Dispose()
    [System.GC]::Collect()
    [System.GC]::WaitForPendingFinalizers()
})

# --- STARTA GRÄNSSNITTET (Denna saknas längst ner i din fil!) ---
Write-KrimsonLog "$($KrimsonForm.Text) startat."
$KrimsonForm.ShowDialog() | Out-Null
