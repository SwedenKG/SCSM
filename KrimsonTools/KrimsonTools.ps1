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
    # 1. Standard-fallbacks om filen saknas (Så att inga variabler blir null!)
    $Global:ColorBgMain        = [System.Drawing.Color]::FromArgb(31, 31, 43)
    $Global:ColorBgSideMenu    = [System.Drawing.Color]::FromArgb(20, 30, 105)
    $Global:ColorBgChildForm   = [System.Drawing.Color]::FromArgb(16, 16, 16)
    $Global:ColorAccent        = [System.Drawing.Color]::FromArgb(255, 180, 0)
    $Global:ColorBtnHover      = [System.Drawing.Color]::FromArgb(45, 45, 60)
    $Global:ColorTextWhite     = [System.Drawing.Color]::White
    $Global:ColorTextGray      = [System.Drawing.Color]::FromArgb(180, 180, 190)

    # 2. Försök läsa den externa JSON-filen
    if (Test-Path $ThemeJsonPath) {
        try {
            $ThemeData = Get-Content -Path $ThemeJsonPath -Raw | ConvertFrom-Json
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
Load-KrimsonTheme

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
                    $UniqueSuffix = "$($Config.MainMenu)_$($Config.SubMenu)" -replace '\s+',''
                    Rename-Item Function:\Show-SettingsView -NewName "Show-SettingsView-$UniqueSuffix" -Force
                    Rename-Item Function:\Show-MainView -NewName "Show-MainView-$UniqueSuffix" -Force
                    
                    $ViewData = [PSCustomObject]@{
                        MainMenu     = $Config.MainMenu
                        MainMenuPrio = [int]$Config.MainMenuPrio
                        SubMenu      = $Config.SubMenu
                        SubMenuPrio  = [int]$Config.SubMenuPrio
                        StatusText   = $Config.StatusText
                        SettingsFunc = "Show-SettingsView-$UniqueSuffix"
                        MainFunc     = "Show-MainView-$UniqueSuffix"
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
# 4. GRAFISKT GRÄNSSNITT (Huvudfönster & Layout)
# ============================================================================
$KrimsonForm = New-Object System.Windows.Forms.Form
$KrimsonForm.Text = "KrimsonTools"
$KrimsonForm.Size = New-Object System.Drawing.Size(1200, 800)
$KrimsonForm.StartPosition = "CenterScreen"
$KrimsonForm.BackColor = $Global:ColorBgMain

# --- SIDOMENY (Vänster) ---
$panelSideMenu = New-Object System.Windows.Forms.Panel
$panelSideMenu.Width = 220
$panelSideMenu.Dock = [System.Windows.Forms.DockStyle]::Left
$panelSideMenu.BackColor = $Global:ColorBgSideMenu
$panelSideMenu.AutoScroll = $true 
$KrimsonForm.Controls.Add($panelSideMenu)

# Logotyp överst i menyn
if ($logoImage -ne $null) {
    $pictureBoxLogo = New-Object System.Windows.Forms.PictureBox
    $pictureBoxLogo.Size = New-Object System.Drawing.Size(200, 80)
    $pictureBoxLogo.Location = New-Object System.Drawing.Point(10, 10)
    $pictureBoxLogo.SizeMode = [System.Windows.Forms.PictureBoxSizeMode]::Zoom
    $pictureBoxLogo.Image = $logoImage
    $pictureBoxLogo.Cursor = [System.Windows.Forms.Cursors]::Hand
    $pictureBoxLogo.Add_DoubleClick({ $btnSettings.PerformClick() })
    $panelSideMenu.Controls.Add($pictureBoxLogo)
}

# --- RUBRIKPANEL (Topp) ---
$panelHeader = New-Object System.Windows.Forms.Panel
$panelHeader.Height = 40
$panelHeader.Dock = [System.Windows.Forms.DockStyle]::Top
$panelHeader.BackColor = $Global:ColorBgMain

$lblTitle = New-Object System.Windows.Forms.Label
$lblTitle.Text = "KrimsonTools"
$lblTitle.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
$lblTitle.ForeColor = $Global:ColorTextWhite
$lblTitle.Location = New-Object System.Drawing.Point(15, 8)
$lblTitle.AutoSize = $true
$panelHeader.Controls.Add($lblTitle)
$KrimsonForm.Controls.Add($panelHeader)

# --- STATUSRAD (Botten) ---
$statusStrip = New-Object System.Windows.Forms.StatusStrip
$statusLabel = New-Object System.Windows.Forms.ToolStripStatusLabel
$statusLabel.Text = "Redo"
$statusLabel.ForeColor = $Global:ColorTextWhite
$statusStrip.Items.Add($statusLabel) | Out-Null
$statusStrip.BackColor = $Global:ColorBgSideMenu
$statusStrip.SizingGrip = $false 
$statusStrip.Dock = [System.Windows.Forms.DockStyle]::Bottom
$KrimsonForm.Controls.Add($statusStrip)

# --- ARBETSYTA / CHILD FORM (Mitten) ---
$Global:panelChildForm = New-Object System.Windows.Forms.Panel
$Global:panelChildForm.Dock = [System.Windows.Forms.DockStyle]::Fill
$Global:panelChildForm.BackColor = $Global:ColorBgChildForm
$KrimsonForm.Controls.Add($Global:panelChildForm)

# ============================================================================
# 5. GENERERA MENYUTBUD UTIFRÅN SKANNADE FILER
# ============================================================================
$ButtonY = 110
$LastMainMenu = ""

foreach ($View in $Global:SortedViews) {
    if ($View.MainMenu -ne $LastMainMenu) {
        $lblHeader = New-Object System.Windows.Forms.Label
        $lblHeader.Text = $View.MainMenu.ToUpper()
        $lblHeader.ForeColor = $Global:ColorAccent
        $lblHeader.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
        $lblHeader.Location = New-Object System.Drawing.Point(15, $ButtonY)
        $lblHeader.AutoSize = $true
        $panelSideMenu.Controls.Add($lblHeader)
        $ButtonY += 22
        $LastMainMenu = $View.MainMenu
    }
    
    $btnMenu = New-Object System.Windows.Forms.Button
    $btnMenu.Text = "  " + $View.SubMenu
    $btnMenu.Size = New-Object System.Drawing.Size(200, 30)
    $btnMenu.Location = New-Object System.Drawing.Point(10, $ButtonY)
    $btnMenu.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnMenu.FlatAppearance.BorderSize = 0
    $btnMenu.ForeColor = $Global:ColorTextWhite
    $btnMenu.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
    $btnMenu.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $btnMenu.BackColor = $Global:ColorBgSideMenu
    
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
        $Global:panelChildForm.Controls.Clear()
        if (Get-Command $View.MainFunc -ErrorAction SilentlyContinue) {
            Invoke-Expression $View.MainFunc -ArgumentList $Global:panelChildForm
        }
    })
    
    $panelSideMenu.Controls.Add($btnMenu)
    $ButtonY += 35
}

# --- FAST INSTÄLLNINGSKNAPP LÄNGST NER ---
$btnSettings = New-Object System.Windows.Forms.Button
$btnSettings.Text = "⚙ Inställningar"
$btnSettings.Size = New-Object System.Drawing.Size(200, 35)
$btnSettings.Location = New-Object System.Drawing.Point(10, 680)
$btnSettings.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$btnSettings.ForeColor = $Global:ColorTextWhite
$btnSettings.BackColor = $Global:ColorBgMain
$btnSettings.Add_Click({
    $lblTitle.Text = "Inställningar"
    $Global:panelChildForm.Controls.Clear()
    $scrollPanel = New-Object System.Windows.Forms.Panel
    $scrollPanel.Dock = [System.Windows.Forms.DockStyle]::Fill
    $scrollPanel.AutoScroll = $true
    $Global:panelChildForm.Controls.Add($scrollPanel)

    # SYSTEMETS TEMAVÄLJARE (Här bor din nya fina dropdown nu!)
    $systemSection = New-Object System.Windows.Forms.Panel
    $systemSection.Size = New-Object System.Drawing.Size(920, 100)
    $systemSection.Dock = [System.Windows.Forms.DockStyle]::Top
    $systemSection.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $scrollPanel.Controls.Add($systemSection)
    $lblThemeInfo = New-Object System.Windows.Forms.Label
    $lblThemeInfo.Text = "Välj gränssnittstema:"
    $lblThemeInfo.ForeColor = $Global:ColorTextWhite
    $lblThemeInfo.Location = New-Object System.Drawing.Point(20, 38)
    $lblThemeInfo.AutoSize = $true
    $systemSection.Controls.Add($lblThemeInfo)
    $comboThemes = New-Object System.Windows.Forms.ComboBox
    $comboThemes.Location = New-Object System.Drawing.Point(160, 35)
    $comboThemes.Size = New-Object System.Drawing.Size(220, 25)
    $comboThemes.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
    if (Test-Path $ThemeJsonPath) {
        $ThemeData = Get-Content -Path $ThemeJsonPath -Raw | ConvertFrom-Json
        foreach ($ThemeName in $ThemeData.Themes.psobject.Properties.Name) {
            [void]$comboThemes.Items.Add($ThemeName)
        }
        $comboThemes.SelectedItem = $ThemeData.ActiveTheme
    }

    $comboThemes.Add_SelectedIndexChanged({
        $NewTheme = $comboThemes.SelectedItem.ToString()
        $ThemeData.ActiveTheme = $NewTheme
        $ThemeData | ConvertTo-Json -Depth 5 | Set-Content -Path $ThemeJsonPath -Encoding Utf8
        Load-KrimsonTheme

        # Uppdatera färgerna på skärmen live
        $KrimsonForm.BackColor = $Global:ColorBgMain
        $panelSideMenu.BackColor = $Global:ColorBgSideMenu
        $Global:panelChildForm.BackColor = $Global:ColorBgChildForm
        $statusStrip.BackColor = $Global:ColorBgSideMenu
        $panelHeader.BackColor = $Global:ColorBgMain
        $lblHeader.ForeColor = $Global:ColorAccent
    })

    $systemSection.Controls.Add($comboThemes)

    # Hämta därefter inställningspaneler från dina externa vyer
    foreach ($View in $Global:SortedViews) {
        if (Get-Command $View.SettingsFunc -ErrorAction SilentlyContinue) {
            $sectionPanel = New-Object System.Windows.Forms.Panel
            $sectionPanel.Size = New-Object System.Drawing.Size(920, 160)
            $sectionPanel.Dock = [System.Windows.Forms.DockStyle]::Top
            $sectionPanel.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
            $scrollPanel.Controls.Add($sectionPanel)
            Invoke-Expression $View.SettingsFunc -ArgumentList $sectionPanel
        }
    }
})
$panelSideMenu.Controls.Add($btnSettings)

# --- SÄKER NEDSTÄNGNING OCH RESURSSTÄDNING ---

$KrimsonForm.Add_FormClosing({
    param($sender, $e)
    if ($logoImage -ne $null) { $logoImage.Dispose() }
    if ($ms -ne $null) { $ms.Dispose() }
    $KrimsonForm.Dispose()
    [System.GC]::Collect()
    [System.GC]::WaitForPendingFinalizers()
})
