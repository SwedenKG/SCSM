# --- 1. METADATA & MENYPOSITION ---
function Get-ViewConfig {
    return [PSCustomObject]@{
        MainMenu        = "Daily"
        MainMenuPrio    = 100        # Visas högst upp
        SubMenu         = "Ärenden"
        SubMenuPrio     = 100        # Första valet under Daily
        Enabled         = $true      # Sätt till $false för att dölja
        StatusText      = "Daglig hantering av SCSM-ärenden"
    }
}

# --- 2. INSTÄLLNINGAR (Visas när man trycker på kugghjulet) ---
function Show-SettingsView {
    param([System.Windows.Forms.Panel]$TargetPanel)
    $TargetPanel.Controls.Clear()
    
    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = "Inställningar för Ärendehantering (Hämtat från extern fil)"
    $lbl.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
    $lbl.ForeColor = [System.Drawing.Color]::Orange
    $lbl.AutoSize = $true
    $lbl.Location = New-Object System.Drawing.Point(20, 20)
    
    $TargetPanel.Controls.Add($lbl)
}

# --- 3. HUVUDVY (Visas när man klickar på "Ärenden" i menyn) ---
function Show-MainView {
    param([System.Windows.Forms.Panel]$TargetPanel)
    $TargetPanel.Controls.Clear()
    
    # Skapa din ärendevy här (Knappar, rutnät, textfält)
    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = "Välkommen till Ärendehanteringen!"
    $lbl.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
    $lbl.ForeColor = [System.Drawing.Color]::White
    $lbl.AutoSize = $true
    $lbl.Location = New-Object System.Drawing.Point(20, 20)
    
    $TargetPanel.Controls.Add($lbl)
}
