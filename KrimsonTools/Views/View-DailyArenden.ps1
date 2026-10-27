function Get-ViewConfig {
    return [PSCustomObject]@{
        MainMenu     = "Daily"
        MainMenuPrio = 10
        SubMenu      = "Ärenden"
        SubMenuPrio  = 10
        Enabled      = $true
        StatusText   = "Visar dagens SCSM-incidenter"
    }
}

function Global:Show-MainView-Daily_Arenden {
    # 1. Rensa arbetsytan helt från gamla komponenter
    if ($Global:panelChildForm) {
        $Global:panelChildForm.Controls.Clear()
    }

    # 2. Skapa rubriken (Följer ditt globala texttema live)
    $lblViewTitle = New-Object System.Windows.Forms.Label
    $lblViewTitle.Text = "Dagligen: Aktiva Incidenter"
    $lblViewTitle.Font = New-Object System.Drawing.Font("Verdana", 14, [System.Drawing.FontStyle]::Bold)
    $lblViewTitle.ForeColor = $Global:colorTextWhite
    $lblViewTitle.Location = New-Object System.Drawing.Point(20, 20)
    $lblViewTitle.AutoSize = $true
    $Global:panelChildForm.Controls.Add($lblViewTitle)

    # 3. Skapa Uppdatera-knappen (Följer ditt globala knapptema live)
    $btnRefresh = New-Object System.Windows.Forms.Button
    $btnRefresh.Text = "Hämta Incidenter"
    $btnRefresh.Location = New-Object System.Drawing.Point(20, 65)
    $btnRefresh.Size = New-Object System.Drawing.Size(130, 30)
    $btnRefresh.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnRefresh.ForeColor = $Global:colorTextWhite
    $btnRefresh.BackColor = $Global:colorBgSideMenu
    $Global:panelChildForm.Controls.Add($btnRefresh)

    # 4. Skapa en tom tabell (DataGridView) med fasta kolumnrubriker
    $dgvIncidents = New-Object System.Windows.Forms.DataGridView
    $dgvIncidents.Location = New-Object System.Drawing.Point(20, 115)
    $dgvIncidents.Size = New-Object System.Drawing.Size(880, 450)
    $dgvIncidents.Anchor = ([System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right -bor [System.Windows.Forms.AnchorStyles]::Bottom)
    $dgvIncidents.BackgroundColor = [System.Drawing.Color]::FromArgb(40, 40, 45)
    $dgvIncidents.ForeColor = [System.Drawing.Color]::Black
    $dgvIncidents.AutoSizeColumnsMode = [System.Windows.Forms.DataGridViewAutoSizeColumnsMode]::Fill
    $dgvIncidents.AllowUserToAddRows = $false
    $dgvIncidents.RowHeadersVisible = $false
    $dgvIncidents.ReadOnly = $true

    # Lägg till fasta kolumner för SCSM-incidenter direkt i gränssnittet
    [void]$dgvIncidents.Columns.Add("Id", "Incident ID")
    [void]$dgvIncidents.Columns.Add("Rubrik", "Titel / Beskrivning")
    [void]$dgvIncidents.Columns.Add("Prioritet", "Prio")

    $Global:panelChildForm.Controls.Add($dgvIncidents)

    # Tvinga fram kontrollerna överst i grafiklagret
    $lblViewTitle.BringToFront()
    $btnRefresh.BringToFront()
    $dgvIncidents.BringToFront()
}
