# --- 1. METADATA (Dold från vanliga menyn) ---
function Get-ViewConfig {
    return [PSCustomObject]@{
        MainMenu        = "System"
        MainMenuPrio    = 999
        SubMenu         = "GlobalSettings"
        SubMenuPrio     = 999
        Enabled         = $false      # $false gör att den INTE visas i sidomenyn!
        StatusText      = "Globala systeminställningar för KrimsonTools"
    }
}

# --- 2. INSTÄLLNINGAR (Kan lämnas tom eller användas) ---
function Show-SettingsView {
    param([System.Windows.Forms.Panel]$TargetPanel)
}

# --- 3. DEN GLOBALA INSTÄLLNINGSVYN (Denna visas när man klickar på loggan) ---
function Show-MainView {
    param([System.Windows.Forms.Panel]$TargetPanel)
    $TargetPanel.Controls.Clear()
    
    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = "⚙ Globala Systeminställningar"
    $lbl.Font = New-Object System.Drawing.Font("Segoe UI", 16, [System.Drawing.FontStyle]::Bold)
    $lbl.ForeColor = [System.Drawing.Color]::White
    $lbl.AutoSize = $true
    $lbl.Location = New-Object System.Drawing.Point(20, 20)
    
    # Här kan du bygga knappar för att byta logga, hantera JSON-filer etc.
    $TargetPanel.Controls.Add($lbl)
}

