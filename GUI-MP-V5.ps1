Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Import-Module SMLets

# --- 1. Konfiguration ---
$global:DebugMode = $true 

$ServerPP  = "VNTAPP0560"
$ServerPRD = "VNTAPP0565"
$NppPath   = "C:\Program Files\Notepad++\notepad++.exe"
if (-not (Test-Path $NppPath)) { $NppPath = "C:\Program Files (x86)\Notepad++\notepad++.exe" }

# --- SharePoint Konfiguration ---
$global:SP_SiteUrl  = "https://samarbete-mk.kvv.se/Rollbaserad/Krimson_UppoKonfig/Krimson_UppoKonfig"
$global:SP_ListName = "Releaselista"

# --- 2. Funktioner ---

function Write-DebugLog {
    param([string]$Message, [string]$Color = "Gray")
    if ($global:DebugMode) { 
        $validColors = "Black","DarkBlue","DarkGreen","DarkCyan","DarkRed","DarkMagenta","DarkYellow","Gray","DarkGray","Blue","Green","Cyan","Red","Magenta","Yellow","White"
        $chosenColor = if ($validColors -contains $Color) { $Color } else { "Yellow" }
        Write-Host "DEBUG: $Message" -ForegroundColor $chosenColor 
    }
}

function Get-SharePointDeployList {
    param([DateTime]$DeployDate)
    $dateString = $DeployDate.ToString("yyyy-MM-dd")
    Write-DebugLog "--- START SHAREPOINT ANROP ---" "Cyan"
    Write-DebugLog "Söker efter datum: '$dateString'" "Yellow"
    
    $itemsUri = ($global:SP_SiteUrl.TrimEnd('/') + "/_api/web/lists/GetByTitle('$($global:SP_ListName)')/items?`$top=1000").Trim()
    
    try {
        $webResponse = Invoke-WebRequest -Uri $itemsUri -UseDefaultCredentials -Headers @{"Accept"="application/json;odata=verbose"} -TimeoutSec 30 -UseBasicParsing
        $cleanJson = $webResponse.Content -replace '"Id":\d+,', ''
        $data = $cleanJson | ConvertFrom-Json
        $items = $data.d.results
        
        if ($null -eq $items) { return @{} }

        $results = @() 
        foreach ($item in $items) {
            # Matcha datum
            if ([string]$item.Releasedatum -notlike "*$dateString*") { continue }
            # Blunda för färdiga
            if ($item.Done -eq $true -or $item.Done -eq "Ja") { continue }
            
            # Hämta driftsättnings-status (Ja/Nej eller True/False)
            $rawStatus = $item.Ska_x0020_drifts_x00e4_ttas
            if ($null -eq $rawStatus) { $rawStatus = $item.Ska_drifts_x00e4_ttas }
            $statusStr = if ($rawStatus -eq $true -or $rawStatus -eq "Ja") { "Ja" } else { "Nej" }

            $rawText = [string]$item.Management_x0020_pack
            if ($rawText) {
                # TVÄTTA BORT HTML OCH DECODE
                $cleanText = $rawText -replace '<[^>]+>', ' ' 
                $cleanText = [System.Net.WebUtility]::HtmlDecode($cleanText).Replace("`$nbsp;", " ")
                
                $results += New-Object PSObject -Property @{
                    Text   = $cleanText
                    Status = $statusStr
                }
                Write-DebugLog "HITTAD I SP: '$($cleanText.Substring(0, [math]::Min(40, $cleanText.Length)))...' (Status: $statusStr)" "Cyan"
            }
        }
        return $results 
    } catch {
        Write-DebugLog "REST-FEL: $($_.Exception.Message)" "Red"
        return @()
    }
}

function Update-Selection {
    # Tvinga fram markering och refresh
    foreach ($dgvRow in $dgv.Rows) {
        $spStat = [string]$dgvRow.DataBoundItem["SP_Status"]
        if ($global:ChkAutoSelectSP.Checked -and $spStat -eq "Ja") {
            $dgvRow.Selected = $true
        } else {
            $dgvRow.Selected = $false
        }
    }
    $dgv.Refresh()
}

function Load-Data {
    param([DateTime]$SyncDate, [DateTime]$DeployDate)
    $TxtSearch.Text = ""; $DataTable.Rows.Clear(); $BtnLoad.Enabled = $false; $ProgBar.Visible = $true; $ProgBar.Value = 0
    
    $LblStatusText.Text = "Hämtar SharePoint-lista..."; $Form.Refresh()
    $spItems = Get-SharePointDeployList -DeployDate $DeployDate
    
    $LblStatusText.Text = "Hämtar MP-listor från SCSM..."; $Form.Refresh()
    $MPs_PP = Get-SCSMManagementPack -ComputerName $ServerPP
    $MPs_PRD = Get-SCSMManagementPack -ComputerName $ServerPRD
    $PrdMap = @{}; foreach($m in $MPs_PRD) { $PrdMap[$m.Name] = $m }
    
    $targetMPs = $MPs_PP | Where-Object { $_.LastModified -ge $SyncDate.Date -or ($PrdMap[$_.Name] -and $PrdMap[$_.Name].LastModified -ge $SyncDate.Date) }
    $total = $targetMPs.Count; $ProgBar.Maximum = $total; $count = 0
    
    foreach ($pp in $targetMPs) {
        $count++; $ProgBar.Value = $count; $LblStatusText.Text = "Jämför ($count/$total): $($pp.DisplayName)"; [System.Windows.Forms.Application]::DoEvents()
        $row = $DataTable.NewRow()
        $row."Display Name" = $pp.DisplayName; $row."Name" = $pp.Name; $row."PreProd Modified" = $pp.LastModified; $row.PP_ID = $pp.Id
        
        # SMART MATCHNING: Kolla om MP-namnet finns omnämnt i någon av SharePoint-texterna
        $finalStatus = ""
        foreach ($sp in $spItems) {
            # Vi kollar både tekniskt namn och visningsnamn
            if ($sp.Text -match [regex]::Escape($pp.Name) -or $sp.Text -match [regex]::Escape($pp.DisplayName)) {
                $finalStatus = $sp.Status
                Write-DebugLog "MATCHAD: $($pp.Name) -> $finalStatus" "Green"
                break # Sluta leta om vi hittat en träff
            }
        }
        $row."SP_Status" = $finalStatus

        $prd = $PrdMap[$pp.Name]
        if ($null -eq $prd) { $row."Status" = "New" }
        else {
            $row."Prod Modified" = $prd.LastModified; $row.PRD_ID = $prd.Id
            $xmlPP = Get-MPXmlSafe -Server $ServerPP -MPId $pp.Id; $xmlPRD = Get-MPXmlSafe -Server $ServerPRD -MPId $prd.Id
            if ($xmlPP -eq $xmlPRD) { $row."Status" = "Equal" } 
            else { $row."Status" = if ($pp.LastModified -gt $prd.LastModified) { "PreProd" } else { "Warning" } }
        }
        $DataTable.Rows.Add($row)
    }
    $DataView.Sort = "[PreProd Modified] DESC"; Apply-Filters
    $ProgBar.Visible = $false; $BtnLoad.Enabled = $true; $LblStatusText.Text = "Klart!"
}

function Open-InNotepadPlusPlus {
    param($xmlProd, $xmlPre, $mpName)
    $tempBase = Join-Path $env:TEMP "SCSM_Compare"
    if (-not (Test-Path $tempBase)) { New-Item -ItemType Directory $tempBase -Force }
    $pathProd = Join-Path $tempBase "$($mpName)_PROD.xml"; $pathPre = Join-Path $tempBase "$($mpName)_PREPROD.xml"
    $xmlProd | Out-File $pathProd -Encoding utf8; $xmlPre | Out-File $pathPre -Encoding utf8
    if (Test-Path $NppPath) { Start-Process $NppPath -ArgumentList "`"$pathProd`" `"$pathPre`"" } else { Start-Process $pathProd; Start-Process $pathPre }
}

# --- 3. GUI-logik (Huvudfönster) ---
$Form = New-Object System.Windows.Forms.Form
$Form.Text = "SCSM MP Manager - Master Professional"
$Form.Size = "1650,850"; $Form.StartPosition = "CenterScreen"
$BottomPanel = New-Object System.Windows.Forms.Panel
$BottomPanel.Height = 110; $BottomPanel.Dock = "Bottom"

# Datum-filter
function Get-SCSMUpcomingReleaseDate {
    $today = Get-Date
    $d = Get-Date -Year $today.Year -Month $today.Month -Day 21
    while ($d.DayOfWeek -ne "Tuesday") { $d = $d.AddDays(1) }
    if ($d.Date -lt $today.Date) {
        $next = $today.AddMonths(1); $d = Get-Date -Year $next.Year -Month $next.Month -Day 21; while ($d.DayOfWeek -ne "Tuesday") { $d = $d.AddDays(1) }
    }
    return $d.Date
}

$LblFilter = New-Object System.Windows.Forms.Label
$LblFilter.Text = "Visa ändrade sedan:"; $LblFilter.Location = "10,15"; $LblFilter.AutoSize = $true
$DtpFilter = New-Object System.Windows.Forms.DateTimePicker
$DtpFilter.Location = "120,12"; $DtpFilter.Format = "Short"; $DtpFilter.Width = 100; $DtpFilter.Value = (Get-Date).AddMonths(-1)

$LblDeploy = New-Object System.Windows.Forms.Label
$LblDeploy.Text = "Driftsättningsdatum:"; $LblDeploy.Location = "230,15"; $LblDeploy.AutoSize = $true
$DtpDeploy = New-Object System.Windows.Forms.DateTimePicker
$DtpDeploy.Location = "340,12"; $DtpDeploy.Format = "Short"; $DtpDeploy.Width = 100; $DtpDeploy.Value = Get-SCSMUpcomingReleaseDate

$BtnLoad = New-Object System.Windows.Forms.Button
$BtnLoad.Text = "Ladda & Jämför"; $BtnLoad.Location = "450,10"; $BtnLoad.Width = 110
$ChkHideEqual = New-Object System.Windows.Forms.CheckBox
$ChkHideEqual.Text = "Dölj 'Equal'"; $ChkHideEqual.Location = "570,13"; $ChkHideEqual.AutoSize = $true
$global:ChkAutoSelectSP = New-Object System.Windows.Forms.CheckBox
$global:ChkAutoSelectSP.Text = "Auto-markera SP"; $global:ChkAutoSelectSP.Location = "670,13"; $global:ChkAutoSelectSP.AutoSize = $true; $global:ChkAutoSelectSP.Checked = $true
$LblSearch = New-Object System.Windows.Forms.Label
$LblSearch.Text = "Sök:"; $LblSearch.Location = "800,15"; $LblSearch.AutoSize = $true
$TxtSearch = New-Object System.Windows.Forms.TextBox
$TxtSearch.Location = "840,12"; $TxtSearch.Width = 180
$BtnExport = New-Object System.Windows.Forms.Button
$BtnExport.Text = "Exportera markerade"; $BtnExport.Width = 150; $BtnExport.Location = "1030,10"
$ProgBar = New-Object System.Windows.Forms.ProgressBar
$ProgBar.Location = "10,50"; $ProgBar.Width = 1010; $ProgBar.Height = 20; $ProgBar.Visible = $false
$LblStatusText = New-Object System.Windows.Forms.Label
$LblStatusText.Text = "Redo."; $LblStatusText.Location = "10,75"; $LblStatusText.Width = 800

$BottomPanel.Controls.AddRange(@($LblFilter, $DtpFilter, $LblDeploy, $DtpDeploy, $BtnLoad, $ChkHideEqual, $global:ChkAutoSelectSP, $LblSearch, $TxtSearch, $BtnExport, $ProgBar, $LblStatusText))
$dgv = New-Object System.Windows.Forms.DataGridView
$dgv.Dock = "Fill"; $dgv.SelectionMode = "FullRowSelect"; $dgv.AllowUserToAddRows = $false; $dgv.RowHeadersVisible = $false
$dgv.BackgroundColor = [System.Drawing.Color]::White; $dgv.AutoGenerateColumns = $false; $dgv.AllowUserToResizeRows = $false
$Form.Controls.Add($dgv); $Form.Controls.Add($BottomPanel)

# --- 4. Datahantering ---
$DataTable = New-Object System.Data.DataTable
$null = $DataTable.Columns.Add("Display Name"); $null = $DataTable.Columns.Add("Name")
$null = $DataTable.Columns.Add("Prod Modified", [DateTime]); $null = $DataTable.Columns.Add("Status")
$null = $DataTable.Columns.Add("PreProd Modified", [DateTime]); $null = $DataTable.Columns.Add("SP Datum"); $null = $DataTable.Columns.Add("SP_Status")
$null = $DataTable.Columns.Add("PP_ID"); $null = $DataTable.Columns.Add("PRD_ID")

$c1 = New-Object System.Windows.Forms.DataGridViewTextBoxColumn; $c1.DataPropertyName = "Display Name"; $c1.HeaderText = "Display Name"; $c1.AutoSizeMode = "Fill"; $dgv.Columns.Add($c1)
$c2 = New-Object System.Windows.Forms.DataGridViewTextBoxColumn; $c2.DataPropertyName = "Name"; $c2.HeaderText = "Name"; $c2.AutoSizeMode = "Fill"; $dgv.Columns.Add($c2)
$c3 = New-Object System.Windows.Forms.DataGridViewTextBoxColumn; $c3.DataPropertyName = "Prod Modified"; $c3.HeaderText = "Prod Modified"; $c3.AutoSizeMode = "AllCells"; $c3.DefaultCellStyle.Format = "yyyy-MM-dd HH:mm"; $dgv.Columns.Add($c3)
$c4 = New-Object System.Windows.Forms.DataGridViewTextBoxColumn; $c4.DataPropertyName = "Status"; $c4.HeaderText = "Status"; $c4.AutoSizeMode = "AllCells"; $dgv.Columns.Add($c4)
$c5 = New-Object System.Windows.Forms.DataGridViewTextBoxColumn; $c5.DataPropertyName = "PreProd Modified"; $c5.HeaderText = "PreProd Modified"; $c5.AutoSizeMode = "AllCells"; $c5.DefaultCellStyle.Format = "yyyy-MM-dd HH:mm"; $dgv.Columns.Add($c5)
$DataView = New-Object System.Data.DataView($DataTable); $dgv.DataSource = $DataView

$dgv.Add_CellFormatting({
    param($s, $e)
    if ($e.RowIndex -ge 0) {
        $row = $dgv.Rows[$e.RowIndex]; $status = [string]$row.DataBoundItem["Status"]; $spStatus = [string]$row.DataBoundItem["SP_Status"]
        if ($spStatus -eq "Nej") { $row.DefaultCellStyle.BackColor = [System.Drawing.Color]::Crimson; $row.DefaultCellStyle.ForeColor = [System.Drawing.Color]::White }
        elseif ($spStatus -eq "Ja") { $row.DefaultCellStyle.BackColor = [System.Drawing.Color]::Gold; $row.DefaultCellStyle.ForeColor = [System.Drawing.Color]::Black }
        else {
            $row.DefaultCellStyle.ForeColor = [System.Drawing.Color]::Black
            switch ($status) {
                "Warning" { $row.DefaultCellStyle.BackColor = [System.Drawing.Color]::MistyRose }
                "New" { $row.DefaultCellStyle.BackColor = [System.Drawing.Color]::LightCyan }
                "PreProd" { $row.DefaultCellStyle.BackColor = [System.Drawing.Color]::LightYellow }
                default { $row.DefaultCellStyle.BackColor = [System.Drawing.Color]::White }
            }
        }
    }
})

function Apply-Filters {
    $filter = if ($ChkHideEqual.Checked) { "Status <> 'Equal'" } else { "" }
    if ($TxtSearch.Text) { $s = "([Display Name] LIKE '*$($TxtSearch.Text)*' OR Name LIKE '*$($TxtSearch.Text)*')"; $filter = if ($filter) { "$filter AND $s" } else { $s } }
    $DataView.RowFilter = $filter; Update-Selection
}

$BtnLoad.Add_Click({ Load-Data -SyncDate $DtpFilter.Value -DeployDate $DtpDeploy.Value })
$ChkHideEqual.Add_CheckedChanged({ Apply-Filters }); $TxtSearch.Add_TextChanged({ Apply-Filters }); $global:ChkAutoSelectSP.Add_CheckedChanged({ Update-Selection })

$dgv.Add_CellDoubleClick({ param($s, $e) if ($e.RowIndex -ge 0) { $dataRow = $dgv.Rows[$e.RowIndex].DataBoundItem; $xmlPP = Get-MPXmlSafe -Server $ServerPP -MPId $dataRow["PP_ID"]; $xmlPRD = Get-MPXmlSafe -Server $ServerPRD -MPId $dataRow["PRD_ID"]; Open-InNotepadPlusPlus -xmlProd $xmlPRD -xmlPre $xmlPP -mpName $dataRow["Name"] } })

$BtnExport.Add_Click({
    $selectedRows = $dgv.SelectedRows; if ($selectedRows.Count -eq 0) { return }
    $fb = New-Object System.Windows.Forms.FolderBrowserDialog; if ($fb.ShowDialog() -eq "OK") {
        $BtnExport.Enabled = $false; $ProgBar.Visible = $true; $ProgBar.Value = 0; $ProgBar.Maximum = $selectedRows.Count
        foreach ($row in $selectedRows) { 
            $dataRow = $row.DataBoundItem; $ProgBar.Value++; $LblStatusText.Text = "Exporterar: $($dataRow['Display Name'])"; [System.Windows.Forms.Application]::DoEvents()
            Start-Sleep -Milliseconds 500
            Get-SCSMManagementPack -Id $dataRow["PP_ID"] -ComputerName $ServerPP | Export-SCSMManagementPack -TargetDirectory $fb.SelectedPath 
        }
        $ProgBar.Visible = $false; $BtnExport.Enabled = $true; $LblStatusText.Text = "Export klar!"
    }
})

function Get-MPXmlSafe {
    param($Server, $MPId)
    if (!$MPId) { return "" }
    try {
        $tempDir = Join-Path $env:TEMP ("SCSM_DIFF_" + [guid]::NewGuid().ToString("N"))
        New-Item -ItemType Directory $tempDir -Force | Out-Null
        Get-SCSMManagementPack -Id $MPId -ComputerName $Server | Export-SCSMManagementPack -TargetDirectory $tempDir
        Start-Sleep -Milliseconds 50
        $xmlFile = Get-ChildItem -Path $tempDir -Filter "*.xml" | Select-Object -First 1
        if ($xmlFile) { $content = Get-Content $xmlFile.FullName -Raw -Encoding UTF8; Remove-Item $tempDir -Recurse -Force; return $content }
    } catch { return "" }
    return ""
}

$Form.ShowDialog()
