# --- 1. METADATA, SORTERING & ON/OFF ---
function Get-ViewConfig {
    return [PSCustomObject]@{
        MainMenu        = "Daily"
        MainMenuPrio    = 100        # Lägre nummer = Högre upp i menyn
        SubMenu         = "Ärenden"
        SubMenuPrio     = 100        # Sortering inuti huvudmenyn
        Enabled         = $true      # $true = On (Visa), $false = Off (Dölj i menyn)
        StatusText      = "Hantera dagliga SCSM-ärenden"
    }
}

# --- 2. INSTÄLLNINGSVYN (Settings-fliken) ---
function Show-SettingsView {
    param([System.Windows.Forms.Panel]$TargetPanel)
    $TargetPanel.Controls.Clear()
    
    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = "Inställningar för Ärendehantering"
    $lbl.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
    $lbl.ForeColor = [System.Drawing.Color]::White
    $lbl.AutoSize = $true
    $lbl.Location = New-Object System.Drawing.Point(20, 20)
    
    $TargetPanel.Controls.Add($lbl)
}

# --- 3. ARBETSYTAN (Det svarta fönstret i mitten) ---
function Show-MainView {
    param([System.Windows.Forms.Panel]$TargetPanel)
    $TargetPanel.Controls.Clear()
    
    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = "Detta är Ärendehanteringen (Huvudvy)"
    $lbl.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
    $lbl.ForeColor = [System.Drawing.Color]::White
    $lbl.AutoSize = $true
    $lbl.Location = New-Object System.Drawing.Point(20, 20)
    
    $TargetPanel.Controls.Add($lbl)
}
