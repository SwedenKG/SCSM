function Get-ViewConfig {
    return [PSCustomObject]@{
        MainMenu     = "Daily"
        MainMenuPrio = 10
        SubMenu      = "Tickets"
        SubMenuPrio  = 10
        Enabled      = $true
        StatusText  = "Displays Daily Active Tickets"
        MainFunc    = "Show-DailyTickets"
    }
}

function Global:Show-DailyTickets {

    if ($Global:panelChildForm) {
        $Global:panelChildForm.Controls.Clear()
    }

    $regPath = "HKCU:\Software\KrimsonTools\Settings\DailyTickets"
    $cfg = Get-ItemProperty -Path $regPath -ErrorAction SilentlyContinue
    $defaultGroup = if ($cfg.DefaultSupportGroup) { $cfg.DefaultSupportGroup } else { "IT Förvaltning Krimson" }
    $currentMode  = if ($cfg.DataSourceMode -in @("SQL", "SMLets")) { $cfg.DataSourceMode } else { "SQL" }
    $warnYellow   = if ($cfg.WarnDaysYellow) { [int]$cfg.WarnDaysYellow } else { 3 }
    $warnRed      = if ($cfg.WarnDaysRed)    { [int]$cfg.WarnDaysRed }    else { 7 }

    $panelWidth   = $Global:panelChildForm.ClientSize.Width - 40
    $panelHeight  = $Global:panelChildForm.ClientSize.Height - 85
    $anchorTopLR  = ([System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right)
    $anchorTopR   = ([System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Right)
    $anchorAll    = ([System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right)

    # --- FILTERRAD ---
    $lblGroup = New-Object System.Windows.Forms.Label
    $lblGroup.Text = "Supportgrupp:"
    $lblGroup.ForeColor = $Global:colorTextWhite
    $lblGroup.Location = New-Object System.Drawing.Point(20, 15)
    $lblGroup.AutoSize = $true
    $Global:panelChildForm.Controls.Add($lblGroup)

    $cmbSupportGroup = New-Object System.Windows.Forms.ComboBox
    $cmbSupportGroup.Location = New-Object System.Drawing.Point(20, 35)
    $cmbSupportGroup.Size = New-Object System.Drawing.Size(340, 24)
    $cmbSupportGroup.DropDownStyle = "DropDownList"
    $Global:panelChildForm.Controls.Add($cmbSupportGroup)
    [void]$cmbSupportGroup.Items.Add("Alla supportgrupper")
    if ($defaultGroup) { [void]$cmbSupportGroup.Items.Add($defaultGroup); $cmbSupportGroup.SelectedItem = $defaultGroup } else { $cmbSupportGroup.SelectedIndex = 0 }

    $lblAnalyst = New-Object System.Windows.Forms.Label
    $lblAnalyst.Text = "Handläggare:"
    $lblAnalyst.ForeColor = $Global:colorTextWhite
    $lblAnalyst.Location = New-Object System.Drawing.Point(375, 15)
    $lblAnalyst.AutoSize = $true
    $Global:panelChildForm.Controls.Add($lblAnalyst)

    $cmbAnalyst = New-Object System.Windows.Forms.ComboBox
    $cmbAnalyst.Location = New-Object System.Drawing.Point(375, 35)
    $cmbAnalyst.Size = New-Object System.Drawing.Size(240, 24)
    $cmbAnalyst.DropDownStyle = "DropDownList"
    [void]$cmbAnalyst.Items.Add("Alla handläggare")
    $cmbAnalyst.SelectedIndex = 0
    $Global:panelChildForm.Controls.Add($cmbAnalyst)

    # Knappar förankrade till höger
    $btnFetch = New-Object System.Windows.Forms.Button
    $btnFetch.Text = "Hämta Incidenter"
    $btnFetch.Location = New-Object System.Drawing.Point(($panelWidth - 255), 33)
    $btnFetch.Size = New-Object System.Drawing.Size(145, 28)
    $btnFetch.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnFetch.BackColor = $Global:colorBgSideMenu
    $btnFetch.ForeColor = $Global:colorTextWhite
    $btnFetch.Anchor = $anchorTopR
    $Global:panelChildForm.Controls.Add($btnFetch)

    $btnModeSwitch = New-Object System.Windows.Forms.Button
    $btnModeSwitch.Text = "Källa: $currentMode"
    $btnModeSwitch.Tag  = $currentMode
    $btnModeSwitch.Location = New-Object System.Drawing.Point(($panelWidth - 100), 33)
    $btnModeSwitch.Size = New-Object System.Drawing.Size(120, 28)
    $btnModeSwitch.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnModeSwitch.BackColor = $Global:colorBgMain
    $btnModeSwitch.ForeColor = $Global:colorAccent
    $btnModeSwitch.Anchor = $anchorTopR
    $Global:panelChildForm.Controls.Add($btnModeSwitch)

    # --- TABELL (DATAGRIDVIEW + DATATABLE) ---
    $dtTickets = New-Object System.Data.DataTable
    [void]$dtTickets.Columns.Add("ID", [string])
    [void]$dtTickets.Columns.Add("Rubrik", [string])
    [void]$dtTickets.Columns.Add("Status", [string])
    [void]$dtTickets.Columns.Add("Prio", [string])
    [void]$dtTickets.Columns.Add("Handläggare", [string])
    [void]$dtTickets.Columns.Add("Supportgrupp", [string])
    [void]$dtTickets.Columns.Add("Skapad", [datetime])
    [void]$dtTickets.Columns.Add("Sist Ändrad", [datetime])

    $dgvTickets = New-Object System.Windows.Forms.DataGridView
    $dgvTickets.Location = New-Object System.Drawing.Point(20, 72)
    $dgvTickets.Size = New-Object System.Drawing.Size($panelWidth, $panelHeight)
    $dgvTickets.Anchor = $anchorAll
    $dgvTickets.SelectionMode = "FullRowSelect"
    $dgvTickets.AllowUserToAddRows = $false
    $dgvTickets.RowHeadersVisible = $false
    $dgvTickets.ReadOnly = $true
    $dgvTickets.AutoGenerateColumns = $false
    $dgvTickets.BackgroundColor = $Global:colorBgMain
    $dgvTickets.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $dgvTickets.EnableHeadersVisualStyles = $false
    $dgvTickets.ColumnHeadersDefaultCellStyle.BackColor = $Global:colorBgSideMenu
    $dgvTickets.ColumnHeadersDefaultCellStyle.ForeColor = $Global:colorTextWhite
    $dgvTickets.DataSource = $dtTickets
    $Global:panelChildForm.Controls.Add($dgvTickets)

    foreach ($colDef in @(
        @{ Prop="ID";           Header="ID";           Mode="AllCells"; Fmt="" },
        @{ Prop="Rubrik";       Header="Rubrik";       Mode="Fill";     Fmt="" },
        @{ Prop="Status";       Header="Status";       Mode="AllCells"; Fmt="" },
        @{ Prop="Prio";         Header="Prio";         Mode="AllCells"; Fmt="" },
        @{ Prop="Handläggare";  Header="Handläggare";  Mode="AllCells"; Fmt="" },
        @{ Prop="Supportgrupp"; Header="Supportgrupp"; Mode="AllCells"; Fmt="" },
        @{ Prop="Skapad";       Header="Skapad";       Mode="AllCells"; Fmt="yyyy-MM-dd HH:mm" },
        @{ Prop="Sist Ändrad";  Header="Sist Ändrad";  Mode="AllCells"; Fmt="yyyy-MM-dd HH:mm" }
    )) {
        $col = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
        $col.DataPropertyName = $colDef.Prop
        $col.HeaderText = $colDef.Header
        $col.AutoSizeMode = $colDef.Mode
        if ($colDef.Fmt) { $col.DefaultCellStyle.Format = $colDef.Fmt }
        [void]$dgvTickets.Columns.Add($col)
    }

    # --- FÄRGKODNING BASERAD PÅ ÄRENDETS ÅLDER ---
    $dgvTickets.Add_CellFormatting({
        param($sender, $e)
        if ($e.RowIndex -lt 0 -or -not $dgvTickets.Rows[$e.RowIndex].DataBoundItem) { return }
        $dr = $dgvTickets.Rows[$e.RowIndex].DataBoundItem.Row
        if ($dr["Skapad"] -is [datetime]) {
            $ageDays = ((Get-Date) - [datetime]$dr["Skapad"]).TotalDays
            if ($ageDays -ge $warnRed) {
                $e.CellStyle.BackColor = [System.Drawing.Color]::Crimson
                $e.CellStyle.ForeColor = [System.Drawing.Color]::White
            } elseif ($ageDays -ge $warnYellow) {
                $e.CellStyle.BackColor = [System.Drawing.Color]::Gold
                $e.CellStyle.ForeColor = [System.Drawing.Color]::Black
            } else {
                $e.CellStyle.BackColor = [System.Drawing.Color]::LightGreen
                $e.CellStyle.ForeColor = [System.Drawing.Color]::Black
            }
        }
    }.GetNewClosure())

        $btnModeSwitch.Add_Click({
        $btnModeSwitch.Tag  = if ($btnModeSwitch.Tag -eq "SQL") { "SMLets" } else { "SQL" }
        $btnModeSwitch.Text = "Källa: $($btnModeSwitch.Tag)"
        Write-KrimsonLog "Daily Tickets: Växlade datakälla till $($btnModeSwitch.Tag)" -UpdateStatus
    }.GetNewClosure())

    $btnFetch.Add_Click({
        $mode = $btnModeSwitch.Tag
        $selGrp = [string]$cmbSupportGroup.SelectedItem
        $selAna = [string]$cmbAnalyst.SelectedItem
        $btnFetch.Enabled = $false
        $dtTickets.Clear()
        Write-KrimsonLog "Daily Tickets: Hämtar supportgrupper & incidenter via $mode (Grupp: $selGrp, Handläggare: $selAna)..." -UpdateStatus
        [System.Windows.Forms.Application]::DoEvents()

        try {
            if ($mode -eq "SQL") {
                if ($cmbSupportGroup.Items.Count -le 2) {
                    $dtGrp = Invoke-KrimsonSql -Query "SELECT DISTINCT ds.DisplayName FROM EnumType et WITH (NOLOCK) INNER JOIN DisplayStringView ds WITH (NOLOCK) ON et.EnumTypeId = ds.LTStringId WHERE et.ParentEnumTypeId = (SELECT EnumTypeId FROM EnumType WITH (NOLOCK) WHERE EnumTypeName = 'IncidentTierQueuesEnum') AND ds.LanguageCode = 'ENU' AND ds.DisplayName IS NOT NULL ORDER BY ds.DisplayName"
                    $cmbSupportGroup.Items.Clear(); [void]$cmbSupportGroup.Items.Add("Alla supportgrupper")
                    foreach ($r in $dtGrp.Rows) { [void]$cmbSupportGroup.Items.Add($r["DisplayName"]) }
                    if ($selGrp -and $cmbSupportGroup.Items.Contains($selGrp)) { $cmbSupportGroup.SelectedItem = $selGrp } else { $cmbSupportGroup.SelectedIndex = 0 }
                    $selGrp = [string]$cmbSupportGroup.SelectedItem
                }

                $grpWhere = if ($selGrp -and $selGrp -ne "Alla supportgrupper") { "AND dsTier.DisplayName = N'$($selGrp.Replace("'","''"))'" } else { "" }
                $sqlInc = "SELECT i.Id_9A505725_E2F2_447F_271B_9B9F4F0D190C AS ID, i.Title_9691DD10_7211_C835_E3E7_6B38AF8B8104 AS Rubrik, ISNULL(dsStat.DisplayName, '') AS Status, ISNULL(CAST(i.Priority_B930B964_A1C4_0B5A_B2D1_BFBE9ECDC794 AS NVARCHAR(20)), '') AS Prio, ISNULL(u.DisplayName, '') AS Handlaggare, ISNULL(dsTier.DisplayName, '') AS Supportgrupp, bme.TimeAdded AS Skapad, bme.LastModified AS SistAndrad FROM MT_System`$WorkItem`$Incident i WITH (NOLOCK) INNER JOIN BaseManagedEntity bme WITH (NOLOCK) ON i.BaseManagedEntityId = bme.BaseManagedEntityId AND bme.IsDeleted = 0 LEFT JOIN DisplayStringView dsStat WITH (NOLOCK) ON i.Status_785407A9_729D_3A74_A383_575DB0CD50ED = dsStat.LTStringId AND dsStat.LanguageCode = 'ENU' LEFT JOIN DisplayStringView dsTier WITH (NOLOCK) ON i.TierQueue_1E9615C2_3386_2452_BA83_05B2169DF38C = dsTier.LTStringId AND dsTier.LanguageCode = 'ENU' LEFT JOIN Relationship rAss WITH (NOLOCK) ON rAss.SourceEntityId = bme.BaseManagedEntityId AND rAss.RelationshipTypeId = '15E577A3-6BF9-6713-4EAC-BA5A5B7C4722' AND rAss.IsDeleted = 0 LEFT JOIN BaseManagedEntity u WITH (NOLOCK) ON rAss.TargetEntityId = u.BaseManagedEntityId WHERE ISNULL(dsStat.DisplayName, '') NOT IN ('Closed', 'Resolved') $grpWhere ORDER BY bme.TimeAdded ASC"
                $dtRes = Invoke-KrimsonSql -Query $sqlInc
                $analysts = New-Object System.Collections.Generic.HashSet[string]
                foreach ($row in $dtRes.Rows) {
                    $ana = [string]$row["Handlaggare"]
                    if ($ana) { [void]$analysts.Add($ana) }
                    if ($selAna -eq "Alla handläggare" -or $ana -eq $selAna) {
                        [void]$dtTickets.Rows.Add($row["ID"], $row["Rubrik"], $row["Status"], $row["Prio"], $ana, $row["Supportgrupp"], [datetime]$row["Skapad"], [datetime]$row["SistAndrad"])
                    }
                }
                $cmbAnalyst.Items.Clear(); [void]$cmbAnalyst.Items.Add("Alla handläggare")
                foreach ($a in ($analysts | Sort-Object)) { [void]$cmbAnalyst.Items.Add($a) }
                if ($selAna -and $cmbAnalyst.Items.Contains($selAna)) { $cmbAnalyst.SelectedItem = $selAna } else { $cmbAnalyst.SelectedIndex = 0 }
            } else {
                $regBase = "HKCU:\Software\KrimsonTools\Settings"
                $actProf = (Get-ItemProperty "HKCU:\Software\KrimsonTools" -ErrorAction SilentlyContinue).LastActiveEnvironment
                $scsmSrv = ((Get-ItemProperty "$regBase\MiljoProfiler\$actProf" -ErrorAction SilentlyContinue).SCSM_Server -split ',').Trim()
                Write-KrimsonLog "Daily Tickets: Kör SMLets mot $scsmSrv..."
                $incClass = Get-SCClass -Name "System.WorkItem.Incident$" -ComputerName $scsmSrv
                $relAss   = Get-SCRelationshipClass -Name "System.WorkItemAssignedToUser$" -ComputerName $scsmSrv
                $incs = Get-SCClassInstance -Class $incClass -ComputerName $scsmSrv | Where-Object { $_.Status.DisplayName -notin @("Closed", "Resolved") }
                foreach ($inc in $incs) {
                    $tier = $inc.TierQueue.DisplayName
                    if ($selGrp -ne "Alla supportgrupper" -and $tier -ne $selGrp) { continue }
                    $anaObj = Get-SCRelationshipInstance -BySource $inc -ComputerName $scsmSrv | Where-Object { $_.RelationshipId -eq $relAss.Id -and -not $_.IsDeleted } | Select-Object -First 1
                    $ana = if ($anaObj) { $anaObj.TargetObject.DisplayName } else { "" }
                    if ($selAna -ne "Alla handläggare" -and $ana -ne $selAna) { continue }
                    [void]$dtTickets.Rows.Add($inc.Id, $inc.Title, $inc.Status.DisplayName, $inc.Priority, $ana, $tier, $inc.TimeAdded, $inc.LastModified)
                }
            }
            Write-KrimsonLog "Daily Tickets: Hämtade $($dtTickets.Rows.Count) aktiva incidenter via $mode." -UpdateStatus
        } catch {
            Write-KrimsonLog "Daily Tickets FEL ($mode): $($_.Exception.Message)" -UpdateStatus
        } finally {
            $btnFetch.Enabled = $true
        }
    }.GetNewClosure())
}


