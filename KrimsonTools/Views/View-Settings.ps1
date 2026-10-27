function Get-ViewConfig {
    return [PSCustomObject]@{
        MainMenu     = "Inställningar"
        MainMenuPrio = 99
        SubMenu      = "Konfiguration"
        SubMenuPrio  = 99
        Enabled      = $false # Sätt till $false så den inte ritas som en vanlig knapp i sidomenyn! (Den ska ju bara nås via dubbelklick på loggan)
        StatusText   = "Globala inställningar och miljöprofiler"
    }
}

function Global:Show-SettingsView-Inställningar_Konfiguration {
    # 1. Eftersom logga-klicket skapar $scrollPanel, kontrollerar vi att den finns
    # Om den inte finns, använder vi panelChildForm direkt
    $Container = $Global:panelChildForm
    if ($Global:scrollPanel) {
        $Container = $Global:scrollPanel
    }

    # 2. Skapa den interna rubriken inuti inställningscontainern
    $lblSettingsTitle = New-Object System.Windows.Forms.Label
    $lblSettingsTitle.Text = "Systeminställningar & Profilhantering"
    $lblSettingsTitle.Font = New-Object System.Drawing.Font("Verdana", 14, [System.Drawing.FontStyle]::Bold)
    $lblSettingsTitle.ForeColor = $Global:colorTextWhite
    $lblSettingsTitle.Location = New-Object System.Drawing.Point(20, 20)
    $lblSettingsTitle.AutoSize = $true
    $Container.Controls.Add($lblSettingsTitle)

    # 3. Här lägger vi till dropdowns för teman, servrar och sparmotorn (Del 1, 2 och 3 som vi byggde tidigare)
    # Alla kontroller läggs till via: $Container.Controls.Add($dinKontroll)
    
    # Tvinga fram grafiklagret
    $lblSettingsTitle.BringToFront()
}
