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

function Global:Show-SettingsViewInstallningarKonfiguration {
    # Hitta rätt behållare (Använder scrollPanel om loggan klickats, annars childForm)
    $Container = $Global:panelChildForm
    if ($Global:scrollPanel) { $Container = $Global:scrollPanel }
    $Container.Controls.Clear()
    $Container.AutoScroll = $true

    # --- 2. SEKTION FÖR MILJÖPROFILER ---
    $profileSection = New-Object System.Windows.Forms.Panel
    $profileSection.Size = New-Object System.Drawing.Size(($Container.ClientSize.Width - 40), 320)
    $profileSection.Location = New-Object System.Drawing.Point(20, 20)
    $profileSection.Anchor = ([System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right)
    $profileSection.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $profileSection.BackColor = $Global:colorBgMain
    $Container.Controls.Add($profileSection)

    $lblProfTitle = New-Object System.Windows.Forms.Label
    $lblProfTitle.Text = "Systeminställningar & Profilhantering:"
    $lblProfTitle.Font = New-Object System.Drawing.Font($Global:ThemeConfig.Typography.FontFamily, 11, [System.Drawing.FontStyle]::Bold)
    $lblProfTitle.ForeColor = $Global:colorTextWhite
    $lblProfTitle.Location = New-Object System.Drawing.Point(20, 15)
    $lblProfTitle.AutoSize = $true
    $profileSection.Controls.Add($lblProfTitle)

    # Dropdown för Profiler (Miljöer)
    $lblEnv = New-Object System.Windows.Forms.Label
    $lblEnv.Text = "Välj miljöprofil:"
    $lblEnv.ForeColor = $Global:colorTextWhite
    $lblEnv.Location = New-Object System.Drawing.Point(20, 55)
    $lblEnv.AutoSize = $true
    $profileSection.Controls.Add($lblEnv)

    $comboProfiles = New-Object System.Windows.Forms.ComboBox
    $comboProfiles.Location = New-Object System.Drawing.Point(160, 52)
    $comboProfiles.Size = New-Object System.Drawing.Size(220, 25)
    $comboProfiles.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
    $profileSection.Controls.Add($comboProfiles)

    # Textruta 1: SCSM Server
    $lblServer = New-Object System.Windows.Forms.Label
    $lblServer.Text = "SCSM Server:"
    $lblServer.ForeColor = $Global:colorTextWhite
    $lblServer.Location = New-Object System.Drawing.Point(20, 95)
    $lblServer.AutoSize = $true
    $profileSection.Controls.Add($lblServer)

    $Global:txtScsmServer = New-Object System.Windows.Forms.TextBox
    $Global:txtScsmServer.Location = New-Object System.Drawing.Point(160, 92)
    $Global:txtScsmServer.Size = New-Object System.Drawing.Size(220, 25)
    $profileSection.Controls.Add($Global:txtScsmServer)

    # Textruta 2: SCSM SQL Server
    $lblSql = New-Object System.Windows.Forms.Label
    $lblSql.Text = "SCSM SQL Server:"
    $lblSql.ForeColor = $Global:colorTextWhite
    $lblSql.Location = New-Object System.Drawing.Point(20, 135)
    $lblSql.AutoSize = $true
    $profileSection.Controls.Add($lblSql)

    $Global:txtScsmSql = New-Object System.Windows.Forms.TextBox
    $Global:txtScsmSql.Location = New-Object System.Drawing.Point(160, 132)
    $Global:txtScsmSql.Size = New-Object System.Drawing.Size(220, 25)
    $profileSection.Controls.Add($Global:txtScsmSql)

    # Textruta 3: SCSM Databas
    $lblDb = New-Object System.Windows.Forms.Label
    $lblDb.Text = "SCSM Databas:"
    $lblDb.ForeColor = $Global:colorTextWhite
    $lblDb.Location = New-Object System.Drawing.Point(20, 175)
    $lblDb.AutoSize = $true
    $profileSection.Controls.Add($lblDb)

    $Global:txtScsmDb = New-Object System.Windows.Forms.TextBox
    $Global:txtScsmDb.Location = New-Object System.Drawing.Point(160, 172)
    $Global:txtScsmDb.Size = New-Object System.Drawing.Size(220, 25)
    $profileSection.Controls.Add($Global:txtScsmDb)

    # --- 3. KNAPPAR ---
    # Spara-knapp
    $btnSaveProfile = New-Object System.Windows.Forms.Button
    $btnSaveProfile.Text = "Spara Profil"
    $btnSaveProfile.Location = New-Object System.Drawing.Point(160, 225)
    $btnSaveProfile.Size = New-Object System.Drawing.Size(100, 30)
    $btnSaveProfile.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnSaveProfile.ForeColor = $Global:colorTextWhite
    $btnSaveProfile.BackColor = $Global:colorBgSideMenu
    $profileSection.Controls.Add($btnSaveProfile)

    # Radera-knapp
    $btnDeleteProfile = New-Object System.Windows.Forms.Button
    $btnDeleteProfile.Text = "Ta bort Profil"
    $btnDeleteProfile.Location = New-Object System.Drawing.Point(280, 225)
    $btnDeleteProfile.Size = New-Object System.Drawing.Size(100, 30)
    $btnDeleteProfile.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnDeleteProfile.ForeColor = $Global:colorTextWhite
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

    $profileSection.BringToFront()
        # --- 3. SEKTION FÖR GUI & TEMA ---
    $guiSection = New-Object System.Windows.Forms.Panel
    $guiSection.Size = New-Object System.Drawing.Size(($Container.ClientSize.Width - 40), 270)
    $guiSection.Location = New-Object System.Drawing.Point(20, 360)
    $guiSection.Anchor = ([System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right)
    $guiSection.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $guiSection.BackColor = $Global:colorBgMain
    $Container.Controls.Add($guiSection)

    $lblGuiTitle = New-Object System.Windows.Forms.Label
    $lblGuiTitle.Text = "Gränssnitt & Visningsalternativ:"
    $lblGuiTitle.Font = New-Object System.Drawing.Font("Verdana", 10, [System.Drawing.FontStyle]::Bold)
    $lblGuiTitle.ForeColor = $Global:colorTextWhite
    $lblGuiTitle.Location = New-Object System.Drawing.Point(20, 15)
    $lblGuiTitle.AutoSize = $true
    $guiSection.Controls.Add($lblGuiTitle)

    # Temaväljare Dropdown
    $lblTheme = New-Object System.Windows.Forms.Label
    $lblTheme.Text = "Aktivt Färgtema:"
    $lblTheme.ForeColor = $Global:colorTextWhite
    $lblTheme.AutoSize = $true
    $lblTheme.Location = New-Object System.Drawing.Point(20, 55)
    $guiSection.Controls.Add($lblTheme)

    $comboThemes = New-Object System.Windows.Forms.ComboBox
    $comboThemes.Location = New-Object System.Drawing.Point(160, 52)
    $comboThemes.Size = New-Object System.Drawing.Size(220, 25)
    $comboThemes.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDown
    if ($Global:ThemeConfig.Themes) {
        $Global:ThemeConfig.Themes.PSObject.Properties.Name | ForEach-Object { [void]$comboThemes.Items.Add($_) }
    }
    $guiSection.Controls.Add($comboThemes)

    # Färgväljare i högerkolumnen
    $script:SelBgChild = $Global:colorBgChildForm
    $script:SelBgMenu  = $Global:colorBgSideMenu
    $script:SelAccent  = $Global:colorAccent

    function New-ColorPickerRow($LabelText, $YPos, $InitColor) {
        $lbl = New-Object System.Windows.Forms.Label
        $lbl.Text = $LabelText; $lbl.ForeColor = $Global:colorTextWhite; $lbl.AutoSize = $true
        $lbl.Location = New-Object System.Drawing.Point(430, ($YPos + 3))
        $guiSection.Controls.Add($lbl)

        $btn = New-Object System.Windows.Forms.Button
        $btn.Location = New-Object System.Drawing.Point(560, $YPos)
        $btn.Size = New-Object System.Drawing.Size(140, 25)
        $btn.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
        $btn.BackColor = $InitColor
        $btn.Text = ""
        $guiSection.Controls.Add($btn)
        return $btn
    }

    $btnColBg     = New-ColorPickerRow "Bakgrundsfärg:" 52  $script:SelBgChild
    $btnColMenu   = New-ColorPickerRow "Menyfärg:"      92  $script:SelBgMenu
    $btnColAccent = New-ColorPickerRow "Accentfärg:"    132 $script:SelAccent

    # Typsnittsväljare Dropdown
    $lblFontFamily = New-Object System.Windows.Forms.Label
    $lblFontFamily.Text = "Typsnitt (Font):"
    $lblFontFamily.AutoSize = $true
    $lblFontFamily.ForeColor = $Global:colorTextWhite
    $lblFontFamily.Location = New-Object System.Drawing.Point(20, 95)
    $guiSection.Controls.Add($lblFontFamily)

    $btnPickFont = New-Object System.Windows.Forms.Button
    $btnPickFont.Location = New-Object System.Drawing.Point(160, 92)
    $btnPickFont.Size = New-Object System.Drawing.Size(220, 25)
    $btnPickFont.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnPickFont.ForeColor = $Global:colorTextWhite
    $btnPickFont.Text = "$($Global:ThemeConfig.Typography.FontFamily) (Ändra...)"
    $guiSection.Controls.Add($btnPickFont)

    # Rubrikstorlek Dropdown
    $lblHeaderSize = New-Object System.Windows.Forms.Label
    $lblHeaderSize.AutoSize = $true
    $lblHeaderSize.Text = "Rubrikstorlek:"
    $lblHeaderSize.ForeColor = $Global:colorTextWhite
    $lblHeaderSize.Location = New-Object System.Drawing.Point(20, 135)
    $guiSection.Controls.Add($lblHeaderSize)

    $comboHeaderSize = New-Object System.Windows.Forms.ComboBox
    $comboHeaderSize.Location = New-Object System.Drawing.Point(160, 132)
    $comboHeaderSize.Size = New-Object System.Drawing.Size(220, 25)
    $comboHeaderSize.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
    $comboHeaderSize.Items.AddRange(@("12", "14", "16", "18", "20"))
    $guiSection.Controls.Add($comboHeaderSize)

    # Statusbar-storlek Dropdown
    $lblStatusSize = New-Object System.Windows.Forms.Label
    $lblStatusSize.Text = "Statusbar-storlek:"
    $lblStatusSize.AutoSize = $true
    $lblStatusSize.ForeColor = $Global:colorTextWhite
    $lblStatusSize.Location = New-Object System.Drawing.Point(20, 175)
    $guiSection.Controls.Add($lblStatusSize)

    $comboStatusSize = New-Object System.Windows.Forms.ComboBox
    $comboStatusSize.Location = New-Object System.Drawing.Point(160, 172)
    $comboStatusSize.Size = New-Object System.Drawing.Size(220, 25)
    $comboStatusSize.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
    $comboStatusSize.Items.AddRange(@("8", "9", "10", "11", "12"))
    $guiSection.Controls.Add($comboStatusSize)

    # --- DEL 3: FÄRGVÄLJARE, SPARA & TA BORT TEMAPROFIL ---
    function Set-ColorPickerClick($Btn, [string]$VarName) {
        $Btn.Add_Click({
            $cd = New-Object System.Windows.Forms.ColorDialog
            $cd.Color = $Btn.BackColor
            if ($cd.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
                $Btn.BackColor = $cd.Color
                Set-Variable -Name $VarName -Value $cd.Color -Scope Script
            }
        }.GetNewClosure())
    }
    Set-ColorPickerClick $btnColBg     "SelBgChild"
    Set-ColorPickerClick $btnColMenu   "SelBgMenu"
    Set-ColorPickerClick $btnColAccent "SelAccent"

    # Knappar för Spara och Ta bort Temaprofil (samma stil som övre rutan)
    $btnSaveTheme = New-Object System.Windows.Forms.Button
    $btnSaveTheme.Text = "Spara Temaprofil"
    $btnSaveTheme.Location = New-Object System.Drawing.Point(160, 220)
    $btnSaveTheme.Size = New-Object System.Drawing.Size(140, 32)
    $btnSaveTheme.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnSaveTheme.BackColor = $Global:colorBgSideMenu
    $btnSaveTheme.ForeColor = $Global:colorTextWhite
    $guiSection.Controls.Add($btnSaveTheme)

    $btnDelTheme = New-Object System.Windows.Forms.Button
    $btnDelTheme.Text = "Ta bort Tema"
    $btnDelTheme.Location = New-Object System.Drawing.Point(310, 220)
    $btnDelTheme.Size = New-Object System.Drawing.Size(120, 32)
    $btnDelTheme.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnDelTheme.BackColor = [System.Drawing.Color]::FromArgb(180, 40, 40)
    $btnDelTheme.ForeColor = $Global:colorTextWhite
    $guiSection.Controls.Add($btnDelTheme)

    $script:CurrentFontFamily = if ($Global:ThemeConfig.Themes.($Global:ThemeConfig.ActiveTheme).FontFamily) { $Global:ThemeConfig.Themes.($Global:ThemeConfig.ActiveTheme).FontFamily } else { "Verdana" }
    $btnPickFont.Text = "$($script:CurrentFontFamily) (Ändra...)"

    $btnPickFont.Add_Click({
        $fd = New-Object System.Windows.Forms.FontDialog
        $fd.Font = New-Object System.Drawing.Font($script:CurrentFontFamily, 12)
        if ($fd.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $script:CurrentFontFamily = $fd.Font.Name
            $btnPickFont.Text = "$($script:CurrentFontFamily) (Ändra...)"
        }
    })

    # Förifyll aktuellt tema och storlekar
    if ($Global:ThemeConfig.ActiveTheme) { $comboThemes.Text = $Global:ThemeConfig.ActiveTheme.Trim() }
    $actT = $Global:ThemeConfig.Themes.($comboThemes.Text)
    if ($actT) {
        $comboHeaderSize.SelectedItem = if ($actT.FontSizeTitle)  { "$($actT.FontSizeTitle)" }  else { "14" }
        $comboStatusSize.SelectedItem = if ($actT.FontSizeStatus) { "$($actT.FontSizeStatus)" } else { "9" }
    }

    # Byt tema direkt vid val i listan
    $comboThemes.Add_SelectedIndexChanged({
        $sel = $comboThemes.SelectedItem
        if ($sel -and (Test-Path $Global:ThemeJsonPath)) {
            $json = Get-Content -Path $Global:ThemeJsonPath -Raw -Encoding UTF8 | ConvertFrom-Json
            $json.ActiveTheme = $sel
            $json | ConvertTo-Json -Depth 5 | Set-Content -Path $Global:ThemeJsonPath -Encoding UTF8 -Force
            Load-KrimsonTheme -ThemePath $Global:ThemeJsonPath
            Update-KrimsonUITheme
            $tObj = $json.Themes.$sel
            if ($tObj) {
                $script:SelBgChild = $Global:colorBgChildForm; $btnColBg.BackColor     = $Global:colorBgChildForm
                $script:SelBgMenu  = $Global:colorBgSideMenu;  $btnColMenu.BackColor   = $Global:colorBgSideMenu
                $script:SelAccent  = $Global:colorAccent;      $btnColAccent.BackColor = $Global:colorAccent
                $script:CurrentFontFamily = $tObj.FontFamily
                $btnPickFont.Text = "$($script:CurrentFontFamily) (Ändra...)"
                $comboHeaderSize.SelectedItem = "$($tObj.FontSizeTitle)"
                $comboStatusSize.SelectedItem = "$($tObj.FontSizeStatus)"
            }
            $Global:statusLabel.Text = "Tema '$sel' aktiverat!"
        }
    }.GetNewClosure())

    # Spara ny eller uppdatera befintlig temaprofil
    $btnSaveTheme.Add_Click({
        try {
            $name = $comboThemes.Text.Trim()
            if (-not $name) { return }
            if ($name -eq "Kriminalvården (Default)") {
                [System.Windows.Forms.MessageBox]::Show("Standardtemat 'Kriminalvården (Default)' är skrivskyddat.`nSkriv ett eget namn i listan för att spara en ny temaprofil!", "Skrivskyddat tema")
                return
            }

            $tPath = if ($Global:ThemeJsonPath) { $Global:ThemeJsonPath } else { Join-Path $PSScriptRoot "..\Config\Theme.json" }
            $json = Get-Content -Path $tPath -Raw -Encoding UTF8 | ConvertFrom-Json

            $newTheme = [PSCustomObject]@{
                BgMain         = "31,31,43"
                BgSideMenu     = "$($btnColMenu.BackColor.R),$($btnColMenu.BackColor.G),$($btnColMenu.BackColor.B)"
                BgChildForm    = "$($btnColBg.BackColor.R),$($btnColBg.BackColor.G),$($btnColBg.BackColor.B)"
                AccentColor    = "$($btnColAccent.BackColor.R),$($btnColAccent.BackColor.G),$($btnColAccent.BackColor.B)"
                BtnHover       = "45,45,60"
                TextWhite      = "255,255,255"
                TextGray       = "180,180,190"
                FontFamily     = $script:CurrentFontFamily
                FontSizeTitle  = [int]$comboHeaderSize.SelectedItem
                FontSizeMenu   = 14
                FontSizeStatus = [int]$comboStatusSize.SelectedItem
            }
            $json.Themes | Add-Member -NotePropertyName $name -NotePropertyValue $newTheme -Force
            $json.ActiveTheme = $name
            $json | ConvertTo-Json -Depth 5 | Set-Content -Path $tPath -Encoding UTF8 -Force

            if (-not $comboThemes.Items.Contains($name)) { [void]$comboThemes.Items.Add($name) }
            Load-KrimsonTheme -ThemePath $tPath
            Update-KrimsonUITheme

            if ($Global:statusLabel) { $Global:statusLabel.Text = "Temaprofil '$name' sparad och aktiverad!" }
            elseif ($statusLabel)    { $statusLabel.Text = "Temaprofil '$name' sparad och aktiverad!" }
        } catch {
            [System.Windows.Forms.MessageBox]::Show("Kunde inte spara tema: $_", "Fel vid sparning")
        }
    }.GetNewClosure())

    # Ta bort temaprofil
    $btnDelTheme.Add_Click({
        $name = $comboThemes.Text.Trim()
        if ($name -eq "Kriminalvården (Default)") {
        if ($Global:statusLabel) { $Global:statusLabel.Text = "Standardtemat 'Kriminalvården (Default)' kan inte tas bort!" }
            return
        }
        $json = Get-Content -Path $Global:ThemeJsonPath -Raw -Encoding UTF8 | ConvertFrom-Json
        $allNames = @($json.Themes.PSObject.Properties.Name)
        if ($allNames.Count -le 1) {
            $Global:statusLabel.Text = "Kan inte ta bort det sista temat!"
            return
        }
        if ($json.Themes.PSObject.Properties[$name]) {
            $json.Themes.PSObject.Properties.Remove($name)
            $comboThemes.Items.Remove($name)
            $fallback = @($json.Themes.PSObject.Properties.Name)[0]
            $json.ActiveTheme = $fallback
            $json | ConvertTo-Json -Depth 5 | Set-Content -Path $Global:ThemeJsonPath -Encoding UTF8 -Force
            $comboThemes.SelectedItem = $fallback
            $Global:statusLabel.Text = "Temaprofil '$name' borttagen."
        }
    }.GetNewClosure())

    $guiSection.BringToFront()

    # --- 4. SEKTION FÖR LOGGNING ---
    $logSection = New-Object System.Windows.Forms.Panel
    $logSection.Size = New-Object System.Drawing.Size(($Container.ClientSize.Width - 40), 120)
    $logSection.Location = New-Object System.Drawing.Point(20, 650)
    $logSection.Anchor = ([System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right)
    $logSection.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $logSection.BackColor = $Global:colorBgMain
    $Container.Controls.Add($logSection)

    $lblLogTitle = New-Object System.Windows.Forms.Label
    $lblLogTitle.Text = "Loggningsinställningar:"
    $lblLogTitle.Font = New-Object System.Drawing.Font($Global:ThemeConfig.Typography.FontFamily, 11, [System.Drawing.FontStyle]::Bold)
    $lblLogTitle.ForeColor = $Global:colorTextWhite
    $lblLogTitle.Location = New-Object System.Drawing.Point(20, 15)
    $lblLogTitle.AutoSize = $true
    $logSection.Controls.Add($lblLogTitle)

    $regGlobalPath = "HKCU:\Software\KrimsonTools\Settings\Global"
    if (-not (Test-Path $regGlobalPath)) { New-Item -Path $regGlobalPath -Force | Out-Null }
    $globalCfg = Get-ItemProperty -Path $regGlobalPath -ErrorAction SilentlyContinue

    $chkLogEnabled = New-Object System.Windows.Forms.CheckBox
    $chkLogEnabled.Text = "Aktivera loggning till fil"
    $chkLogEnabled.ForeColor = $Global:colorTextWhite
    $chkLogEnabled.Location = New-Object System.Drawing.Point(20, 50)
    $chkLogEnabled.AutoSize = $true
    $chkLogEnabled.Checked = ($globalCfg.LogEnabled -eq "True")
    $logSection.Controls.Add($chkLogEnabled)

    $lblLogFile = New-Object System.Windows.Forms.Label
    $lblLogFile.Text = "Loggfil (Sökväg):"
    $lblLogFile.ForeColor = $Global:colorTextWhite
    $lblLogFile.Location = New-Object System.Drawing.Point(20, 82)
    $lblLogFile.AutoSize = $true
    $logSection.Controls.Add($lblLogFile)

    $txtLogFilePath = New-Object System.Windows.Forms.TextBox
    $txtLogFilePath.Location = New-Object System.Drawing.Point(240, 79)
    $txtLogFilePath.Size = New-Object System.Drawing.Size(($Container.ClientSize.Width - 400), 23)
    $txtLogFilePath.Anchor = ([System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right)
    $txtLogFilePath.Text = if ($globalCfg.LogFilePath) { $globalCfg.LogFilePath } else { (Join-Path $env:TEMP "KrimsonTool.log") }
    $logSection.Controls.Add($txtLogFilePath)

    $btnBrowseLog = New-Object System.Windows.Forms.Button
    $btnBrowseLog.Text = "Bläddra..."
    $btnBrowseLog.Location = New-Object System.Drawing.Point(($Container.ClientSize.Width - 150), 78)
    $btnBrowseLog.Size = New-Object System.Drawing.Size(80, 25)
    $btnBrowseLog.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnBrowseLog.BackColor = $Global:colorBgSideMenu
    $btnBrowseLog.ForeColor = $Global:colorTextWhite
    $btnBrowseLog.Anchor = ([System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Right)
    $logSection.Controls.Add($btnBrowseLog)

    $SaveLogSettings = {
        Set-ItemProperty -Path $regGlobalPath -Name "LogEnabled"  -Value $chkLogEnabled.Checked.ToString() -Force
        Set-ItemProperty -Path $regGlobalPath -Name "LogFilePath" -Value $txtLogFilePath.Text.Trim() -Force
        if (Get-Command "Write-KrimsonLog" -ErrorAction SilentlyContinue) {
            $st = if ($chkLogEnabled.Checked) { "aktiverad" } else { "inaktiverad" }
            Write-KrimsonLog "Fil-loggning $st -> $($txtLogFilePath.Text.Trim())" -UpdateStatus
        }
    }.GetNewClosure()

    $chkLogEnabled.Add_CheckedChanged($SaveLogSettings)
    $txtLogFilePath.Add_Leave($SaveLogSettings)
    $btnBrowseLog.Add_Click({
        $sfd = New-Object System.Windows.Forms.SaveFileDialog
        $sfd.Filter = "Loggfiler (*.log;*.txt)|*.log;*.txt|Alla filer (*.*)|*.*"
        $sfd.FileName = [System.IO.Path]::GetFileName($txtLogFilePath.Text)
        if ($sfd.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $txtLogFilePath.Text = $sfd.FileName
            & $SaveLogSettings
        }
    }.GetNewClosure())

    # --- 5. DYNAMISKA INSTÄLLNINGAR FRÅN AKTIVA VYER (PLUGINS) ---
    $nextY = 790

    $pluginFuncs = Get-Command -Name "Register-ViewSettings-*" -ErrorAction SilentlyContinue
    foreach ($fn in $pluginFuncs) {
        $addedPanel = & $fn.Name -Container $Container -StartY $nextY
        if ($addedPanel -is [System.Windows.Forms.Control]) {
            $nextY += $addedPanel.Height + 20
        }
    }

}
