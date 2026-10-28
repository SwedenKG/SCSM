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
$ThemeJsonPath = Join-Path $ConfigFolder "Theme.json"

# ============================================================================
# 2. CENTRALt FÄRGTEMA (Läser teman live från Config\Theme.json)
# ============================================================================
function Load-KrimsonTheme {
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
            }
        } catch {
            Write-Warning "Kunde inte tolka Theme.json, använder standardfärgerna."
        }
    }
}

# Starta färgerna direkt
Load-KrimsonTheme -ThemePath $ThemeJsonPath

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
                    $cleanMain = $Config.MainMenu -replace '[åäåÅÄÖ]','a' -replace '\s+',''
                    $cleanSub  = $Config.SubMenu -replace '[åäåÅÄÖ]','a' -replace '\s+',''
                    $UniqueSuffix = "${cleanMain}_${cleanSub}"

                    if (Test-Path "Function:\Show-SettingsView") {
                        Rename-Item Function:\Show-SettingsView -NewName "Global:Show-SettingsView-$UniqueSuffix" -Force
                    }
                    if (Test-Path "Function:\Show-MainView") {
                        Rename-Item Function:\Show-MainView -NewName "Global:Show-MainView-$UniqueSuffix" -Force
                    }

                    $viewData = [PSCustomObject]@{
                        MainMenu       = $Config.MainMenu
                        MainMenuPrio   = [int]$Config.MainMenuPrio
                        SubMenu        = $Config.SubMenu
                        SubMenuPrio    = [int]$Config.SubMenuPrio
                        StatusText     = $Config.StatusText
                        SettingsFunc   = "Show-SettingsView-$UniqueSuffix"
                        MainFunc       = "Show-MainView-$UniqueSuffix"
                    }
                    $Global:LoadedViews.Add($ViewData)
                }
                Remove-Item Function:\Get-ViewConfig -ErrorAction SilentlyContinue
            }
        } catch {
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

# --- STEG 1: RUBRIKPANEL (Läggs till först, fyller toppen) ---
$panelHeader = New-Object System.Windows.Forms.Panel
$panelHeader.Height = 40
$panelHeader.Dock = [System.Windows.Forms.DockStyle]::Top
$panelHeader.BackColor = $Global:colorBgSideMenu

$lblTitle = New-Object System.Windows.Forms.Label
$lblTitle.Text = ""
$lblTitle.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
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
$panelSideMenu.Size = New-Object System.Drawing.Size(175, 800)
$panelSideMenu.AutoSize = $false
$KrimsonForm.Controls.Add($panelSideMenu)

# Logotyp överst i den nyskapade sidomenyn
if ($logoImage -ne $null) {
    $pictureBoxLogo = New-Object System.Windows.Forms.PictureBox
    $pictureBoxLogo.Size = New-Object System.Drawing.Size(175, 80)
    $pictureBoxLogo.Margin = New-Object System.Windows.Forms.Padding(5, 10, 10, 20)
    $pictureBoxLogo.SizeMode = [System.Windows.Forms.PictureBoxSizeMode]::Zoom
    $pictureBoxLogo.Image = $logoImage
    $pictureBoxLogo.Cursor = [System.Windows.Forms.Cursors]::Hand
    
    # HÄNDELSE: När man klickar på Loggan öppnas inställningarna i ChildFormuläret!
    $PictureBoxLogo.Add_DoubleClick({
        $RegKey = "HKCU:\Software\KrimsonTools"
        $CurrentActive = Get-ItemProperty -Path $RegKey -Name "LastActiveView" -ErrorAction SilentlyContinue

        # Hämta aktuell rubrik live från fönstret
        $CurrentTitle = ""
        if ($lblTitle -and $lblTitle.Text) { 
            $CurrentTitle = $lblTitle.Text 
        }

        # VÄXLINGSFUNKTION (TOGGLE): OM RUBRIKEN REDAN ÄR INSTÄLLNINGAR -> SKICKA TILLBAKA TEKNIKERN
        if ($CurrentTitle -eq "Inställningar") {
            if ($CurrentActive -and $CurrentActive.LastActiveView) {
                $TargetFunc = $CurrentActive.LastActiveView
                if (Get-Command $TargetFunc -ErrorAction SilentlyContinue) {
                    $statusLabel.Text = "Återgår till föregående vy..."
                    & $TargetFunc
                }
            } else {
                # Fallback om registret är tomt: Skicka till Ärenden
                if (Get-Command "Global:Show-MainView-Daily_Arenden" -ErrorAction SilentlyContinue) {
                    Global:Show-MainView-Daily_Arenden
                }
            }
        } 
        # VÄXLINGSFUNKTION (TOGGLE): OM VI STÅR I EN SCSM-VY -> SPARA VY-NAMNET OCH ÖPPNA INSTÄLLNINGARNA
        else {
            if ($Global:CurrentActiveViewFunctionName) {
            if (-not (Test-Path $RegKey)) { New-Item -Path $RegKey -Force | Out-Null }
                Set-ItemProperty -Path $RegKey -Name "LastActiveView" -Value $Global:CurrentActiveViewFunctionName -Force
        }
            
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
        $lblHeader.Font = New-Object System.Drawing.Font($Global:ThemeConfig.Typography.FontFamily, $Global:ThemeConfig.Typography.FontSizeTitle)
        $lblHeader.AutoSize = $true
        $panelSideMenu.Controls.Add($lblHeader)

        $LastMainMenu = $View.MainMenu

        $lblHeader.Add_Click({
            # Återställ alla andra rubriker till vit textfärg först
            foreach ($Control in $panelSideMenu.Controls) {
                if ($Control -is [System.Windows.Forms.Label]) { $Control.ForeColor = $Global:colorTextWhite }
            }
        
            # Tänd den klickade rubriken med sparad AccentColor från JSON
            $ActiveName = $Global:ThemeConfig.ActiveTheme
            if ($Global:ThemeConfig.Themes."$ActiveName".AccentColor) {
                $AccentRGB = $Global:ThemeConfig.Themes."$ActiveName".AccentColor.Split(',')
                $this.ForeColor = [System.Drawing.Color]::FromArgb($AccentRGB[0], $AccentRGB[1], $AccentRGB[2])
            }

            # Hitta alla knappar som tillhör just denna huvudmeny och växla deras synlighet
            $CurrentMenu = $View.MainMenu
            foreach ($Control in $panelSideMenu.Controls) {
                if ($Control -is [System.Windows.Forms.Button]) {
                    if ($Control.Tag -eq $CurrentMenu) { $Control.Visible = -not $Control.Visible }
                }
            }
            $panelSideMenu.PerformLayout()
        })
    }
    
    $btnMenu = New-Object System.Windows.Forms.Button
    $btnMenu.Text = "  " + $View.SubMenu
    $btnMenu.Size = New-Object System.Drawing.Size(155, 30)
    $btnMenu.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnMenu.FlatAppearance.BorderSize = 0
    $btnMenu.ForeColor = $Global:colorTextWhite
    $btnMenu.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
    $btnMenu.Font = New-Object System.Drawing.Font($Global:ThemeConfig.Typography.FontFamily, $Global:ThemeConfig.Typography.FontSizeTitle)
    $btnMenu.BackColor = $Global:ColorBgSideMenu
    $btnMenu.Visible = ($View.SubMenu -eq $View.MainMenu)
    $btnMenu.Tag = $View.MainMenu
    $panelSideMenu.Controls.Add($btnMenu)

    $btnMenu.Add_MouseEnter({
        $this.BackColor = $Global:ColorBtnHover
        $statusLabel.Text = $View.StatusText
    })
    $btnMenu.Add_MouseLeave({
        $this.BackColor = $Global:ColorBgSideMenu
        $statusLabel.Text = "Redo"
    })
    
    $btnMenu.Add_Click({
        param($sender, $e)
        $lblTitle.Text = "$($View.MainMenu) - $($View.SubMenu)"
        $lblTitle.Font = New-Object System.Drawing.Font($Global:ThemeConfig.Typography.FontFamily, $Global:ThemeConfig.Typography.FontSizeTitle)
        $Global:panelChildForm.Controls.Clear()

        # --- ÅTERSTÄLL MENYFÄRGER OCH KOLLAPSA (Från gamla Tools.ps1) ---
        # Återställ alla huvudmenyer till den sparade textfärgen från JSON
        foreach ($Control in $panelSideMenu.Controls) {
            if ($Control -is [System.Windows.Forms.Button]) {
                $Control.ForeColor = $Global:colorTextWhite
            }
        }

        # Sätt den klickade menyn till AccentColor (Orange/Vald färg) från JSON
        if ($Global:ThemeConfig.Themes."$($Global:ThemeConfig.ActiveTheme)".AccentColor) {
            $AccentRGB = $Global:ThemeConfig.Themes."$($Global:ThemeConfig.ActiveTheme)".AccentColor.Split(',')
            $sender.ForeColor = [System.Drawing.Color]::FromArgb($AccentRGB[0], $AccentRGB[1], $AccentRGB[2])
        }

        # Om vi klickar på själva undermenyvalet (t.ex. Ärenden), stäng undermenyn och återställ till textfärg
        if ($View.SubMenu -ne $View.MainMenu) {
            # Dölj panelen för undermenyn (Dynamiskt baserat på namnet från din gamla kod)
            Get-Variable -Name "panelSubMenu$($View.MainMenu)" -ValueOnly -ErrorAction SilentlyContinue | ForEach-Object { $_.Visible = $false }
        
        # Sätt färgen tillbaka till den sparade textfärgen eftersom vi har gjort vårt val
        $sender.ForeColor = $Global:colorTextWhite
        }

        # Kör den globala funktionen trådsäkert och modulärt
        if (Get-Command $View.MainFunc -ErrorAction SilentlyContinue) {
            & $View.MainFunc
        }
    })
    
    $panelSideMenu.Controls.Add($btnMenu)
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

# --- LÄS IN FÄRGER OCH STORLEKAR FRÅN JSON INNAN START ---
Load-KrimsonTheme

# --- STARTA GRÄNSSNITTET (Denna saknas längst ner i din fil!) ---
$KrimsonForm.ShowDialog() | Out-Null
