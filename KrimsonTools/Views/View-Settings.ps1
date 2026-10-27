function Get-ViewConfig {
    return [PSCustomObject]@{
        MainMenu     = "Inställningar"
        MainMenuPrio = 99
        SubMenu      = "Konfiguration"
        SubMenuPrio  = 99
        Enabled      = $false
        StatusText   = "Globala inställningar och miljöprofiler"
    }
}

function Global:Show-SettingsView-Inställningar_Konfiguration {
    # Hitta rätt behållare (Använder scrollPanel om loggan klickats, annars childForm)
    $Container = $Global:panelChildForm
    if ($Global:scrollPanel) { $Container = $Global:scrollPanel }
    $Container.Controls.Clear()

    # --- 1. RUBRIK ---
    $lblTitle = New-Object System.Windows.Forms.Label
    $lblTitle.Text = "Systeminställningar & Profilhantering"
    $lblTitle.Font = New-Object System.Drawing.Font("Verdana", 14, [System.Drawing.FontStyle]::Bold)
    $lblTitle.ForeColor = $Global:colorTextWhite
    $lblTitle.Location = New-Object System.Drawing.Point(20, 20)
    $lblTitle.AutoSize = $true
    $Container.Controls.Add($lblTitle)

    # --- 2. SEKTION FÖR MILJÖPROFILER ---
    $profileSection = New-Object System.Windows.Forms.Panel
    $profileSection.Size = New-Object System.Drawing.Size(840, 320)
    $profileSection.Location = New-Object System.Drawing.Point(20, 70)
    $profileSection.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $profileSection.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 35)
    $Container.Controls.Add($profileSection)

    # Dropdown för Profiler (Miljöer)
    $lblEnv = New-Object System.Windows.Forms.Label
    $lblEnv.Text = "Välj miljöprofil:"
    $lblEnv.ForeColor = $Global:colorTextWhite
    $lblEnv.Location = New-Object System.Drawing.Point(20, 25)
    $lblEnv.AutoSize = $true
    $profileSection.Controls.Add($lblEnv)

    $comboProfiles = New-Object System.Windows.Forms.ComboBox
    $comboProfiles.Location = New-Object System.Drawing.Point(160, 22)
    $comboProfiles.Size = New-Object System.Drawing.Size(220, 25)
    $comboProfiles.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
    $profileSection.Controls.Add($comboProfiles)

    # Textruta 1: SCSM Server
    $lblServer = New-Object System.Windows.Forms.Label
    $lblServer.Text = "SCSM Server:"
    $lblServer.ForeColor = $Global:colorTextWhite
    $lblServer.Location = New-Object System.Drawing.Point(20, 75)
    $lblServer.AutoSize = $true
    $profileSection.Controls.Add($lblServer)

    $Global:txtScsmServer = New-Object System.Windows.Forms.TextBox
    $Global:txtScsmServer.Location = New-Object System.Drawing.Point(160, 72)
    $Global:txtScsmServer.Size = New-Object System.Drawing.Size(220, 25)
    $profileSection.Controls.Add($Global:txtScsmServer)

    # Textruta 2: SCSM SQL Server
    $lblSql = New-Object System.Windows.Forms.Label
    $lblSql.Text = "SCSM SQL Server:"
    $lblSql.ForeColor = $Global:colorTextWhite
    $lblSql.Location = New-Object System.Drawing.Point(20, 115)
    $lblSql.AutoSize = $true
    $profileSection.Controls.Add($lblSql)

    $Global:txtScsmSql = New-Object System.Windows.Forms.TextBox
    $Global:txtScsmSql.Location = New-Object System.Drawing.Point(160, 112)
    $Global:txtScsmSql.Size = New-Object System.Drawing.Size(220, 25)
    $profileSection.Controls.Add($Global:txtScsmSql)

    # Textruta 3: SCSM Databas
    $lblDb = New-Object System.Windows.Forms.Label
    $lblDb.Text = "SCSM Databas:"
    $lblDb.ForeColor = $Global:colorTextWhite
    $lblDb.Location = New-Object System.Drawing.Point(20, 155)
    $lblDb.AutoSize = $true
    $profileSection.Controls.Add($lblDb)

    $Global:txtScsmDb = New-Object System.Windows.Forms.TextBox
    $Global:txtScsmDb.Location = New-Object System.Drawing.Point(160, 152)
    $Global:txtScsmDb.Size = New-Object System.Drawing.Size(220, 25)
    $profileSection.Controls.Add($Global:txtScsmDb)

    # --- 3. KNAPPAR ---
    # Spara-knapp
    $btnSaveProfile = New-Object System.Windows.Forms.Button
    $btnSaveProfile.Text = "Spara Profil"
    $btnSaveProfile.Location = New-Object System.Drawing.Point(160, 205)
    $btnSaveProfile.Size = New-Object System.Drawing.Size(100, 30)
    $btnSaveProfile.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnSaveProfile.ForeColor = [System.Drawing.Color]::White
    $btnSaveProfile.BackColor = [System.Drawing.Color]::FromArgb(20, 30, 105)
    $profileSection.Controls.Add($btnSaveProfile)

    # Radera-knapp
    $btnDeleteProfile = New-Object System.Windows.Forms.Button
    $btnDeleteProfile.Text = "Ta bort Profil"
    $btnDeleteProfile.Location = New-Object System.Drawing.Point(280, 205)
    $btnDeleteProfile.Size = New-Object System.Drawing.Size(100, 30)
    $btnDeleteProfile.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnDeleteProfile.ForeColor = [System.Drawing.Color]::White
    $btnDeleteProfile.BackColor = [System.Drawing.Color]::FromArgb(165, 30, 30)
    $profileSection.Controls.Add($btnDeleteProfile)

    # --- INTERNAL LOGIC ---
    $RefreshProfiles = {
        $comboProfiles.Items.Clear()
        $regPath = "HKCU:\Software\KrimsonTools\Settings\MiljoProfiler"
        if (Test-Path $regPath) {
            foreach ($key in (Get-ChildItem -Path $regPath | Select-Object -ExpandProperty PSChildName)) {
                [void]$comboProfiles.Items.Add($key)
            }
        }
        if ($comboProfiles.Items.Count -gt 0) { $comboProfiles.SelectedIndex = 0 }
        else { [void]$comboProfiles.Items.Add("IT"); $comboProfiles.SelectedIndex = 0 }
    }

    $comboProfiles.Add_SelectedIndexChanged({
        if ($comboProfiles.SelectedItem) {
            $selectedEnv = $comboProfiles.SelectedItem.ToString()
            $Global:statusLabel.Text = "Läser in variabler för profil: $selectedEnv..."
            $regPath = "HKCU:\Software\KrimsonTools\Settings\MiljoProfiler\$selectedEnv"
            
            if (Test-Path $regPath) {
                $data = Get-ItemProperty -Path $regPath -ErrorAction SilentlyContinue
                $Global:txtScsmServer.Text = if ($data.SCSM_Server) { $data.SCSM_Server } else { "" }
                $Global:txtScsmSql.Text    = if ($data.SCSM_SQL)    { $data.SCSM_SQL }    else { "" }
                $Global:txtScsmDb.Text     = if ($data.SCSM_DB)     { $data.SCSM_DB }     else { "" }
                $Global:statusLabel.Text = "Profil '$selectedEnv' inläst."
            } else {
                $Global:txtScsmServer.Text = ""
                $Global:txtScsmSql.Text    = ""
                $Global:txtScsmDb.Text     = ""
                $Global:statusLabel.Text = "Ny profil: '$selectedEnv'."
            }
        }
    })

    $btnSaveProfile.Add_Click({
        if ($comboProfiles.SelectedItem) {
            $env = $comboProfiles.SelectedItem.ToString()
            $regPath = "HKCU:\Software\KrimsonTools\Settings\MiljoProfiler\$env"
            if (-not (Test-Path $regPath)) { New-Item -Path $regPath -Force | Out-Null }
            
            Set-ItemProperty -Path $regPath -Name "SCSM_Server" -Value $Global:txtScsmServer.Text -Force
            Set-ItemProperty -Path $regPath -Name "SCSM_SQL" -Value $Global:txtScsmSql.Text -Force
            Set-ItemProperty -Path $regPath -Name "SCSM_DB" -Value $Global:txtScsmDb.Text -Force
            $Global:statusLabel.Text = "Inställningarna sparade för profilen '$env'!"
        }
    })

    $btnDeleteProfile.Add_Click({
        if ($comboProfiles.SelectedItem) {
            $env = $comboProfiles.SelectedItem.ToString()
            $msgBox = [System.Windows.Forms.MessageBox]::Show("Vill du verkligen ta bort profilen '$env'?", "Bekräfta radering", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Warning)
            if ($msgBox -eq [System.Windows.Forms.DialogResult]::Yes) {
                $regPath = "HKCU:\Software\KrimsonTools\Settings\MiljoProfiler\$env"
                if (Test-Path $regPath) { Remove-Item -Path $regPath -Recurse -Force | Out-Null }
                
                $Global:statusLabel.Text = "Profil '$env' raderad."
                $Global:txtScsmServer.Text = ""
                $Global:txtScsmSql.Text    = ""
                $Global:txtScsmDb.Text     = ""
                &$RefreshProfiles
            }
        }
    })

    # Initiera data live
    &$RefreshProfiles
    $lblTitle.BringToFront()
    $profileSection.BringToFront()
}
