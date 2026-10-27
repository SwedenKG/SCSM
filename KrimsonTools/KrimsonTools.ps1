Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ============================================================================
# 1. MILJÖ OCH SÖKVÄGAR
# ============================================================================
$ScriptRoot = Split-Path -Path $MyInvocation.MyCommand.Path -Parent
$LogoJsonPath = Join-Path $ScriptRoot "Config\Logo.json"
$ViewsFolder = Join-Path $ScriptRoot "Views"

# Skapa mappen Views om den inte redan finns
if (-not (Test-Path $ViewsFolder)) {
    New-Item -ItemType Directory -Path $ViewsFolder | Out-Null
}

# Global lista för att hålla ordning på alla godkända vyer i minnet
$Global:LoadedViews = [System.Collections.Generic.List[Object]]::new()

# ============================================================================
# 2. AUTOMATISK SKANNING & IMPORT AV VYER (Views)
# ============================================================================
if (Test-Path $ViewsFolder) {
    # Hämta alla .ps1-skript i mappen Views
    $ViewFiles = Get-ChildItem -Path (Join-Path $ViewsFolder "*.ps1")
    
    foreach ($File in $ViewFiles) {
        try {
            # Läs in filen live (Dot-source)
            . $File.FullName
            
            # Kontrollera att filen har den obligatoriska konfigurationsfunktionen
            if (Get-Command "Get-ViewConfig" -ErrorAction SilentlyContinue) {
                $Config = Get-ViewConfig
                
                # Filter: Läs ENDAST in moduler som är aktiva (Enabled = $true)
                if ($Config.Enabled -eq $true) {
                    # Skapa ett helt unikt suffix baserat på menyvalen (tar bort mellanslag)
                    $UniqueSuffix = "$($Config.MainMenu)_$($Config.SubMenu)" -replace '\s+',''
                    
                    # Döp om funktionerna i minnet direkt så att nästa fil inte skriver över dem
                    Rename-Item Function:\Show-SettingsView -NewName "Show-SettingsView-$UniqueSuffix" -Force
                    Rename-Item Function:\Show-MainView -NewName "Show-MainView-$UniqueSuffix" -Force
                    
                    # Spara all metadata och peka ut de nya unika funktionsnamnen
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
                
                # Städa bort den temporära funktionen inför nästa loop-varv
                Remove-Item Function:\Get-ViewConfig -ErrorAction SilentlyContinue
            }
        } catch {
            Write-Warning "Kunde inte läsa in modulfilen: $($File.Name). Fel: $_"
        }
    }
}

# MATEMATISK SORTERING: Sortera först på Huvudmeny-Prio, sedan på Undermeny-Prio
$Global:SortedViews = $Global:LoadedViews | Sort-Object MainMenuPrio, SubMenuPrio

# ============================================================================
# 3. GRAFISKT GRÄNSSNITT (WinForms Grundskal)
# ============================================================================
$KrimsonForm = New-Object System.Windows.Forms.Form
$KrimsonForm.Text = "KrimsonTools"
$KrimsonForm.Size = New-Object System.Drawing.Size(1200, 800)
$KrimsonForm.StartPosition = "CenterScreen"
$KrimsonForm.BackColor = [System.Drawing.Color]::FromArgb(45, 45, 48)

# --- SIDOMENY (Vänsterpanel) ---
$panelSideMenu = New-Object System.Windows.Forms.Panel
$panelSideMenu.Width = 220
$panelSideMenu.Dock = [System.Windows.Forms.DockStyle]::Left
$panelSideMenu.BackColor = [System.Drawing.Color]::FromArgb(28, 28, 28)
$KrimsonForm.Controls.Add($panelSideMenu)

# --- LOGOTYP (Överst i sidomenyn från Logo.json) ---
$logoImage = $null
$ms = $null
if (Test-Path $LogoJsonPath) {
    try {
        $LogoData = Get-Content -Path $LogoJsonPath -Raw | ConvertFrom-Json
        if ($LogoData.LogoBase64) {
            $imageBytes = [System.Convert]::FromBase64String($LogoData.LogoBase64)
            $ms = New-Object System.IO.MemoryStream($imageBytes, 0, $imageBytes.Length)
            $logoImage = [System.Drawing.Image]::FromStream($ms)
            
            $pictureBoxLogo = New-Object System.Windows.Forms.PictureBox
            $pictureBoxLogo.Size = New-Object System.Drawing.Size(200, 80)
            $pictureBoxLogo.Location = New-Object System.Drawing.Point(10, 10)
            $pictureBoxLogo.SizeMode = [System.Windows.Forms.PictureBoxSizeMode]::Zoom
            $pictureBoxLogo.Image = $logoImage
            $panelSideMenu.Controls.Add($pictureBoxLogo)
        }
    } catch {
        Write-Warning "Kunde inte ladda logotypen från JSON: $_"
    }
}

# --- ARBETSYTA / CHILD FORM (Det svarta fönstret i mitten) ---
$Global:panelChildForm = New-Object System.Windows.Forms.Panel
$Global:panelChildForm.Dock = [System.Windows.Forms.DockStyle]::Fill
$Global:panelChildForm.BackColor = [System.Drawing.Color]::FromArgb(16, 16, 16)
$KrimsonForm.Controls.Add($Global:panelChildForm)

# --- STATUSRAD (Längst ner) ---
$statusStrip = New-Object System.Windows.Forms.StatusStrip
$statusLabel = New-Object System.Windows.Forms.ToolStripStatusLabel
$statusLabel.Text = "Programmet startat. Redo."
$statusLabel.ForeColor = [System.Drawing.Color]::White
$statusStrip.Items.Add($statusLabel) | Out-Null
$statusStrip.BackColor = [System.Drawing.Color]::FromArgb(28, 28, 28)
$KrimsonForm.Controls.Add($statusStrip)

# ============================================================================
# 4. DYNAMISK MENYGENERERING
# ============================================================================
$ButtonY = 110 # Startposition på höjden under logotypen
$LastMainMenu = ""

foreach ($View in $Global:SortedViews) {
    
    # Skapa en kategori-rubrik om vi har bytt Huvudmeny (t.ex. DAILY, RELEASE)
    if ($View.MainMenu -ne $LastMainMenu) {
        $lblHeader = New-Object System.Windows.Forms.Label
        $lblHeader.Text = $View.MainMenu.ToUpper()
        $lblHeader.ForeColor = [System.Drawing.Color]::FromArgb(120, 120, 120)
        $lblHeader.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
        $lblHeader.Location = New-Object System.Drawing.Point(15, $ButtonY)
        $lblHeader.AutoSize = $true
        $panelSideMenu.Controls.Add($lblHeader)
        
        $ButtonY += 22
        $LastMainMenu = $View.MainMenu
    }
    
    # Skapa undermeny-knappen för det specifika verktyget
    $btnMenu = New-Object System.Windows.Forms.Button
    $btnMenu.Text = "  " + $View.SubMenu
    $btnMenu.Size = New-Object System.Drawing.Size(200, 30)
    $btnMenu.Location = New-Object System.Drawing.Point(10, $ButtonY)
    $btnMenu.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnMenu.FlatAppearance.BorderSize = 0
    $btnMenu.ForeColor = [System.Drawing.Color]::White
    $btnMenu.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
    $btnMenu.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $btnMenu.BackColor = [System.Drawing.Color]::FromArgb(38, 38, 38)
    
    # KLICK-HÄNDELSE: Tömmer mittenfönstret och kör igång View-filens huvudvy
    $btnMenu.Add_Click({
        param($sender, $e)
        $statusLabel.Text = $View.StatusText
        
        if (Get-Command $View.MainFunc -ErrorAction SilentlyContinue) {
            # Anropa funktionen (t.ex. Show-MainView-Daily_Ärenden) och skicka med mittpanelen
            Invoke-Expression $View.MainFunc -ArgumentList $Global:panelChildForm
        }
    })
    
    $panelSideMenu.Controls.Add($btnMenu)
    $ButtonY += 35
}

# --- FAST INSTÄLLNINGSKNAPP (Längst ner till vänster) ---
$btnSettings = New-Object System.Windows.Forms.Button
$btnSettings.Text = "⚙ Inställningar"
$btnSettings.Size = New-Object System.Drawing.Size(200, 35)
$btnSettings.Location = New-Object System.Drawing.Point(10, 680)
$btnSettings.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$btnSettings.ForeColor = [System.Drawing.Color]::LightGray
$btnSettings.BackColor = [System.Drawing.Color]::FromArgb(50, 50, 50)

$btnSettings.Add_Click({
    # Töm arbetspanelen helt
    $Global:panelChildForm.Controls.Clear()
    $statusLabel.Text = "Hämtar inställningar för alla aktiva moduler..."
    
    # Skapa en scrollbar container-panel för att stapla modulernas inställningar i
    $scrollPanel = New-Object System.Windows.Forms.Panel
    $scrollPanel.Dock = [System.Windows.Forms.DockStyle]::Fill
    $scrollPanel.AutoScroll = $true
    $Global:panelChildForm.Controls.Add($scrollPanel)
    
    # Loopa igenom alla aktiva vyer och hämta deras specifika inställningsvyer
    foreach ($View in $Global:SortedViews) {
        if (Get-Command $View.SettingsFunc -ErrorAction SilentlyContinue) {
            # Skapa en avgränsad sektionsruta för denna moduls inställningar
            $sectionPanel = New-Object System.Windows.Forms.Panel
            $sectionPanel.Size = New-Object System.Drawing.Size(920, 160)
            $sectionPanel.Dock = [System.Windows.Forms.DockStyle]::Top
            $sectionPanel.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
            
            $scrollPanel.Controls.Add($sectionPanel)
            
            # Kör inställningsfunktionen från den aktuella filen
            Invoke-Expression $View.SettingsFunc -ArgumentList $sectionPanel
        }
    }
})
$panelSideMenu.Controls.Add($btnSettings)

# ============================================================================
# 5. SÄKER AVSTÄNGNING OCH RESURSSTÄDNING (Förhindrar krasch i PowerShell/ISE)
# ============================================================================
$KrimsonForm.Add_FormClosing({
    param($sender, $e)
    # Stäng och frigör bildströmmar i RAM-minnet ordentligt
    if ($logoImage -ne $null) { $logoImage.Dispose() }
    if ($ms -ne $null) { $ms.Dispose() }
    # Kassera själva huvudformuläret och dess kontroller
    $KrimsonForm.Dispose()
    # Tvinga .NET skräpsamlare (Garbage Collector) att omedelbart rensa minnesblocken
    [System.GC]::Collect()
    [System.GC]::WaitForPendingFinalizers()
})
