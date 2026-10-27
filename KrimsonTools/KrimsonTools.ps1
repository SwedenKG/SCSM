Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ============================================================================
# DYNAMISKA SÖKVÄGAR - Låser basen till C:\KrimsonTools\ (eller där den körs)
# ============================================================================
$ScriptRoot = $PSScriptRoot
if (-not $ScriptRoot) {
    $ScriptRoot = Split-Path -Path $MyInvocation.MyCommand.Path -Parent
}

$ConfigFolder = Join-Path $ScriptRoot "Config"
$ViewsFolder  = Join-Path $ScriptRoot "Views"
$LogoJsonPath = Join-Path $ConfigFolder "Logo.json"

# Global lista för aktiva moduler
$Global:LoadedViews = [System.Collections.Generic.List[Object]]::new()

# ============================================================================
# SKANNA OCH IMPORTERA VYER
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
                    
                    # Döp om funktionerna live i minnet för att undvika krockar
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

# ============================================================================
# GRAFISKT GRÄNSSNITT
# ============================================================================
$KrimsonForm = New-Object System.Windows.Forms.Form
$KrimsonForm.Text = "KrimsonTools"
$KrimsonForm.Size = New-Object System.Drawing.Size(1200, 800)
$KrimsonForm.StartPosition = "CenterScreen"
$KrimsonForm.BackColor = [System.Drawing.Color]::FromArgb(45, 45, 48)

$panelSideMenu = New-Object System.Windows.Forms.Panel
$panelSideMenu.Width = 220
$panelSideMenu.Dock = [System.Windows.Forms.DockStyle]::Left
$panelSideMenu.BackColor = [System.Drawing.Color]::FromArgb(28, 28, 28)
$KrimsonForm.Controls.Add($panelSideMenu)

$Global:panelChildForm = New-Object System.Windows.Forms.Panel
$Global:panelChildForm.Dock = [System.Windows.Forms.DockStyle]::Fill
$Global:panelChildForm.BackColor = [System.Drawing.Color]::FromArgb(16, 16, 16)
$KrimsonForm.Controls.Add($Global:panelChildForm)

# Läs in logga
$logoImage = $null; $ms = $null
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
        
            # NYTT: Ändra muspekaren till en hand när man håller över loggan
            $pictureBoxLogo.Cursor = [System.Windows.Forms.Cursors]::Hand
        
            # NYTT: Säg åt loggan att köra inställnings-knappens klick-funktion vid dubbelklick
        $pictureBoxLogo.Add_DoubleClick({
            # 1. Töm arbetspanelen helt
            $Global:panelChildForm.Controls.Clear()
            
            # 2. Skapa en scrollbar container-panel för att stapla modulernas inställningar i
            $scrollPanel = New-Object System.Windows.Forms.Panel
            $scrollPanel.Dock = [System.Windows.Forms.DockStyle]::Fill
            $scrollPanel.AutoScroll = $true
            $Global:panelChildForm.Controls.Add($scrollPanel)
            
            # 3. Loopa igenom alla aktiva vyer och hämta deras specifika inställningsvyer
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
        
        $panelSideMenu.Controls.Add($pictureBoxLogo)

        }
    } catch {}
}

$statusStrip = New-Object System.Windows.Forms.StatusStrip
$statusLabel = New-Object System.Windows.Forms.ToolStripStatusLabel
$statusLabel.Text = "Redo"
$statusLabel.ForeColor = [System.Drawing.Color]::White
$statusStrip.Items.Add($statusLabel) | Out-Null
$statusStrip.BackColor = [System.Drawing.Color]::FromArgb(28, 28, 28)
$KrimsonForm.Controls.Add($statusStrip)

# ============================================================================
# BYGG MENYKNAPPAR UTIFRÅN SKANNADE FILER
# ============================================================================
$ButtonY = 110
$LastMainMenu = ""

foreach ($View in $Global:SortedViews) {
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
    
    $btnMenu.Add_Click({
        param($sender, $e)
        $statusLabel.Text = $View.StatusText
        if (Get-Command $View.MainFunc -ErrorAction SilentlyContinue) {
            Invoke-Expression $View.MainFunc -ArgumentList $Global:panelChildForm
        }
    })
    
    $panelSideMenu.Controls.Add($btnMenu)
    $ButtonY += 35
}

# Inställningsknapp
$btnSettings = New-Object System.Windows.Forms.Button
$btnSettings.Text = "⚙ Inställningar"
$btnSettings.Size = New-Object System.Drawing.Size(200, 35)
$btnSettings.Location = New-Object System.Drawing.Point(10, 680)
$btnSettings.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$btnSettings.ForeColor = [System.Drawing.Color]::LightGray
$btnSettings.BackColor = [System.Drawing.Color]::FromArgb(50, 50, 50)

$btnSettings.Add_Click({
    $Global:panelChildForm.Controls.Clear()
    $scrollPanel = New-Object System.Windows.Forms.Panel
    $scrollPanel.Dock = [System.Windows.Forms.DockStyle]::Fill
    $scrollPanel.AutoScroll = $true
    $Global:panelChildForm.Controls.Add($scrollPanel)
    
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

# Avstängning
$KrimsonForm.Add_FormClosing({
    param($sender, $e)
    if ($logoImage -ne $null) { $logoImage.Dispose() }
    if ($ms -ne $null) { $ms.Dispose() }
    $KrimsonForm.Dispose()
    [System.GC]::Collect()
    [System.GC]::WaitForPendingFinalizers()
})

[System.Windows.Forms.Application]::Run($KrimsonForm)
