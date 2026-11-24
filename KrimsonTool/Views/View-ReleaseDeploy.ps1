function Get-ViewConfig {
    return [PSCustomObject]@{
        MainMenu     = "Release"
        MainMenuPrio = 20
        SubMenu      = "Deploy"
        SubMenuPrio  = 20
        Enabled      = $true
        StatusText   = "Compare and deploy Management Packs from PreProd to Prod"
        MainFunc     = "Show-ReleaseDeploy"
    }
}

if ((Get-ViewConfig).Enabled) {
    function Global:Register-ViewSettings-ReleaseDeploy {
        param($Container, [int]$StartY)

        $regPath = "HKCU:\Software\KrimsonTools\Settings\ReleaseDeploy"
        if (-not (Test-Path $regPath)) { New-Item -Path $regPath -Force | Out-Null }
        $cfg = Get-ItemProperty -Path $regPath -ErrorAction SilentlyContinue

        $panelWidth  = $Container.ClientSize.Width - 40
        $anchorTopLR = ([System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right)
        $anchorTopR  = ([System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Right)

        $pnlCfg = New-Object System.Windows.Forms.Panel
        $pnlCfg.Location = New-Object System.Drawing.Point(20, $StartY)
        $pnlCfg.Size = New-Object System.Drawing.Size($panelWidth, 165)
        $pnlCfg.BackColor = $Global:colorBgMain
        $pnlCfg.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
        $pnlCfg.Anchor = $anchorTopLR
        $Container.Controls.Add($pnlCfg)

        $lblTitle = New-Object System.Windows.Forms.Label
        $lblTitle.Text = "Release - Deploy Konfiguration (Orchestrator-skript):"
        $lblTitle.Font = New-Object System.Drawing.Font($Global:ThemeConfig.Typography.FontFamily, 11, [System.Drawing.FontStyle]::Bold)
        $lblTitle.ForeColor = $Global:colorTextWhite
        $lblTitle.Location = New-Object System.Drawing.Point(20, 15)
        $lblTitle.AutoSize = $true
        $pnlCfg.Controls.Add($lblTitle)

        $lblOrcSrc = New-Object System.Windows.Forms.Label
        $lblOrcSrc.Text = "Orchestrator-skript Källa (UNC):"
        $lblOrcSrc.ForeColor = $Global:colorTextWhite
        $lblOrcSrc.Location = New-Object System.Drawing.Point(20, 52)
        $lblOrcSrc.AutoSize = $true
        $pnlCfg.Controls.Add($lblOrcSrc)

        $txtOrcSrc = New-Object System.Windows.Forms.TextBox
        $txtOrcSrc.Location = New-Object System.Drawing.Point(240, 49)
        $txtOrcSrc.Size = New-Object System.Drawing.Size(($panelWidth - 360), 23)
        $txtOrcSrc.Anchor = $anchorTopLR
        $txtOrcSrc.Text = if ($cfg.OrcScriptsSourceUNC) { $cfg.OrcScriptsSourceUNC } else { "" }
        $pnlCfg.Controls.Add($txtOrcSrc)

        $btnBrwSrc = New-Object System.Windows.Forms.Button
        $btnBrwSrc.Text = "Bläddra..."
        $btnBrwSrc.Location = New-Object System.Drawing.Point(($panelWidth - 110), 48)
        $btnBrwSrc.Size = New-Object System.Drawing.Size(80, 25)
        $btnBrwSrc.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
        $btnBrwSrc.BackColor = $Global:colorBgSideMenu
        $btnBrwSrc.ForeColor = $Global:colorTextWhite
        $btnBrwSrc.Anchor = $anchorTopR
        $pnlCfg.Controls.Add($btnBrwSrc)

        $lblOrcDst = New-Object System.Windows.Forms.Label
        $lblOrcDst.Text = "Orchestrator-skript Mål (UNC):"
        $lblOrcDst.ForeColor = $Global:colorTextWhite
        $lblOrcDst.Location = New-Object System.Drawing.Point(20, 86)
        $lblOrcDst.AutoSize = $true
        $pnlCfg.Controls.Add($lblOrcDst)

        $txtOrcDst = New-Object System.Windows.Forms.TextBox
        $txtOrcDst.Location = New-Object System.Drawing.Point(240, 83)
        $txtOrcDst.Size = New-Object System.Drawing.Size(($panelWidth - 360), 23)
        $txtOrcDst.Anchor = $anchorTopLR
        $txtOrcDst.Text = if ($cfg.OrcScriptsDestUNC) { $cfg.OrcScriptsDestUNC } else { "" }
        $pnlCfg.Controls.Add($txtOrcDst)

        $btnBrwDst = New-Object System.Windows.Forms.Button
        $btnBrwDst.Text = "Bläddra..."
        $btnBrwDst.Location = New-Object System.Drawing.Point(($panelWidth - 110), 82)
        $btnBrwDst.Size = New-Object System.Drawing.Size(80, 25)
        $btnBrwDst.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
        $btnBrwDst.BackColor = $Global:colorBgSideMenu
        $btnBrwDst.ForeColor = $Global:colorTextWhite
        $btnBrwDst.Anchor = $anchorTopR
        $pnlCfg.Controls.Add($btnBrwDst)

        $btnSave = New-Object System.Windows.Forms.Button
        $btnSave.Text = "Spara Deploy-inställningar"
        $btnSave.Location = New-Object System.Drawing.Point(240, 120)
        $btnSave.Size = New-Object System.Drawing.Size(200, 28)
        $btnSave.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
        $btnSave.BackColor = $Global:colorBgSideMenu
        $btnSave.ForeColor = $Global:colorTextWhite
        $pnlCfg.Controls.Add($btnSave)

        $btnBrwSrc.Add_Click({ $fbd = New-Object System.Windows.Forms.FolderBrowserDialog; if ($fbd.ShowDialog() -eq "OK") { $txtOrcSrc.Text = $fbd.SelectedPath } }.GetNewClosure())
        $btnBrwDst.Add_Click({ $fbd = New-Object System.Windows.Forms.FolderBrowserDialog; if ($fbd.ShowDialog() -eq "OK") { $txtOrcDst.Text = $fbd.SelectedPath } }.GetNewClosure())

        $btnSave.Add_Click({
            Set-ItemProperty -Path $regPath -Name "OrcScriptsSourceUNC" -Value $txtOrcSrc.Text.Trim() -Force
            Set-ItemProperty -Path $regPath -Name "OrcScriptsDestUNC"   -Value $txtOrcDst.Text.Trim() -Force
            if (Get-Command "Write-KrimsonLog" -ErrorAction SilentlyContinue) {
                Write-KrimsonLog "Release Deploy-inställningar sparade." -UpdateStatus
            }
        }.GetNewClosure())

        return $pnlCfg
    }
} else {
    Remove-Item -Path "Function:\Global:Register-ViewSettings-ReleaseDeploy" -ErrorAction SilentlyContinue
}

function Global:Show-ReleaseDeploy {
    if ($Global:panelChildForm) {
        $Global:panelChildForm.Controls.Clear()
        $Global:panelChildForm.AutoScroll = $true
        $Global:panelChildForm.AutoScrollMargin = New-Object System.Drawing.Size(0, 30)
    }

    $regRel  = "HKCU:\Software\KrimsonTools\Settings\Release"
    $regDep  = "HKCU:\Software\KrimsonTools\Settings\ReleaseDeploy"
    $relCfg  = Get-ItemProperty -Path $regRel -ErrorAction SilentlyContinue
    $depCfg  = Get-ItemProperty -Path $regDep -ErrorAction SilentlyContinue

    $relDate = if ($relCfg.ActiveReleaseDate) { $relCfg.ActiveReleaseDate } else { (Get-Date).ToString("yyyy-MM-dd") }
    $dstProf = if ($relCfg.ProdProfile) { $relCfg.ProdProfile } else { "(Ej vald)" }
    $prdSrv  = ((Get-ItemProperty "HKCU:\Software\KrimsonTools\Settings\MiljoProfiler\$dstProf" -ErrorAction SilentlyContinue).SCSM_Server -split ',').Trim()

    # Räkna ut aktuell datummapp under Exportmappen (tar senaste _1, _2 om flera körningar gjorts)
    $defaultImportDir = ""
    if ($relCfg.ReleaseExportDestUNC) {
        $baseDateDir = Join-Path $relCfg.ReleaseExportDestUNC $relDate
        $matchingDirs = Get-ChildItem -Path $relCfg.ReleaseExportDestUNC -Directory -Filter "$relDate*" -ErrorAction SilentlyContinue | Sort-Object Name -Descending
        if ($matchingDirs) { $defaultImportDir = $matchingDirs[0].FullName } else { $defaultImportDir = $baseDateDir }
    }

    $panelWidth  = $Global:panelChildForm.ClientSize.Width - 40
    $anchorTopLR = ([System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right)
    $anchorTopR  = ([System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Right)

    # --- TOPPBANNER: AKTIV RELEASE & MÅLMILJÖ ---
    $pnlBanner = New-Object System.Windows.Forms.Panel
    $pnlBanner.Location = New-Object System.Drawing.Point(20, 15)
    $pnlBanner.Size = New-Object System.Drawing.Size($panelWidth, 45)
    $pnlBanner.BackColor = $Global:colorBgMain
    $pnlBanner.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $pnlBanner.Anchor = $anchorTopLR
    $Global:panelChildForm.Controls.Add($pnlBanner)

    $lblBanner = New-Object System.Windows.Forms.Label
    $lblBanner.Text = "Driftsättningsdatum: $relDate   |   SCSM-Mål: $dstProf ($prdSrv)"
    $lblBanner.Font = New-Object System.Drawing.Font($Global:ThemeConfig.Typography.FontFamily, 10.5, [System.Drawing.FontStyle]::Bold)
    $lblBanner.ForeColor = $Global:colorAccent
    $lblBanner.Location = New-Object System.Drawing.Point(15, 12)
    $lblBanner.AutoSize = $true
    $pnlBanner.Controls.Add($lblBanner)

    # --- STEG 1: IMPORTERA MANAGEMENT PACKS TILL MÅL ---
    $pnlStep1 = New-Object System.Windows.Forms.Panel
    $pnlStep1.Location = New-Object System.Drawing.Point(20, 72)
    $pnlStep1.Size = New-Object System.Drawing.Size($panelWidth, 275)
    $pnlStep1.BackColor = $Global:colorBgMain
    $pnlStep1.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $pnlStep1.Anchor = $anchorTopLR
    $Global:panelChildForm.Controls.Add($pnlStep1)

    $lblS1 = New-Object System.Windows.Forms.Label
    $lblS1.Text = "Steg 1: Importera Management Packs till SCSM-Mål ($dstProf)"
    $lblS1.Font = New-Object System.Drawing.Font($Global:ThemeConfig.Typography.FontFamily, 11, [System.Drawing.FontStyle]::Bold)
    $lblS1.ForeColor = $Global:colorAccent
    $lblS1.Location = New-Object System.Drawing.Point(15, 12)
    $lblS1.AutoSize = $true
    $pnlStep1.Controls.Add($lblS1)

    $txtImportPath = New-Object System.Windows.Forms.TextBox
    $txtImportPath.Location = New-Object System.Drawing.Point(15, 42)
    $txtImportPath.Size = New-Object System.Drawing.Size(($panelWidth - 220), 23)
    $txtImportPath.Anchor = $anchorTopLR
    $txtImportPath.Text = $defaultImportDir
    $pnlStep1.Controls.Add($txtImportPath)

    $btnBrowseImp = New-Object System.Windows.Forms.Button
    $btnBrowseImp.Text = "Bläddra..."
    $btnBrowseImp.Location = New-Object System.Drawing.Point(($panelWidth - 195), 41)
    $btnBrowseImp.Size = New-Object System.Drawing.Size(80, 25)
    $btnBrowseImp.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnBrowseImp.BackColor = $Global:colorBgSideMenu
    $btnBrowseImp.ForeColor = $Global:colorTextWhite
    $btnBrowseImp.Anchor = $anchorTopR
    $pnlStep1.Controls.Add($btnBrowseImp)

    $btnScanMp = New-Object System.Windows.Forms.Button
    $btnScanMp.Text = "Läs in filer"
    $btnScanMp.Location = New-Object System.Drawing.Point(($panelWidth - 105), 41)
    $btnScanMp.Size = New-Object System.Drawing.Size(90, 25)
    $btnScanMp.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnScanMp.BackColor = $Global:colorBgSideMenu
    $btnScanMp.ForeColor = $Global:colorTextWhite
    $btnScanMp.Anchor = $anchorTopR
    $pnlStep1.Controls.Add($btnScanMp)

    $clbMps = New-Object System.Windows.Forms.CheckedListBox
    $clbMps.Location = New-Object System.Drawing.Point(15, 74)
    $clbMps.Size = New-Object System.Drawing.Size(($panelWidth - 30), 145)
    $clbMps.Anchor = $anchorTopLR
    $clbMps.CheckOnClick = $true
    $clbMps.BackColor = $Global:colorBgSideMenu
    $clbMps.ForeColor = $Global:colorTextWhite
    $clbMps.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $pnlStep1.Controls.Add($clbMps)

    $btnImportMps = New-Object System.Windows.Forms.Button
    $btnImportMps.Text = "Importera markerade MPs till $dstProf"
    $btnImportMps.Location = New-Object System.Drawing.Point(15, 228)
    $btnImportMps.Size = New-Object System.Drawing.Size(270, 32)
    $btnImportMps.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnImportMps.BackColor = $Global:colorBgSideMenu
    $btnImportMps.ForeColor = $Global:colorTextWhite
    $pnlStep1.Controls.Add($btnImportMps)

    $LoadMpFiles = {
        $clbMps.Items.Clear()
        $dir = $txtImportPath.Text.Trim()
        if ($dir -and (Test-Path $dir)) {
            $files = Get-ChildItem -Path $dir -File | Where-Object { $_.Extension -in @(".xml", ".mp", ".mpb") } | Sort-Object Name
            foreach ($f in $files) { [void]$clbMps.Items.Add($f.Name, $true) }
            Write-KrimsonLog "Release Deploy: Hittade $($files.Count) MP-filer i $dir" -UpdateStatus
        } else {
            Write-KrimsonLog "Release Deploy: Mappen hittades inte ($dir)" -UpdateStatus
        }
    }.GetNewClosure()

    $btnBrowseImp.Add_Click({
        $fbd = New-Object System.Windows.Forms.FolderBrowserDialog
        if ($txtImportPath.Text -and (Test-Path $txtImportPath.Text)) { $fbd.SelectedPath = $txtImportPath.Text }
        if ($fbd.ShowDialog() -eq "OK") { $txtImportPath.Text = $fbd.SelectedPath; & $LoadMpFiles }
    }.GetNewClosure())

    $btnScanMp.Add_Click($LoadMpFiles)

    $btnImportMps.Add_Click({
        if (-not $prdSrv) { [System.Windows.Forms.MessageBox]::Show("Ingen SCSM-Mål-server hittades för profilen '$dstProf'.", "Konfiguration saknas"); return }
        if ($clbMps.CheckedItems.Count -eq 0) { [System.Windows.Forms.MessageBox]::Show("Markera minst en MP-fil att importera.", "Ingen fil vald"); return }
        if ([System.Windows.Forms.MessageBox]::Show("Vill du importera $($clbMps.CheckedItems.Count) Management Packs till $dstProf ($prdSrv)?", "Bekräfta import", "YesNo", "Question") -ne "Yes") { return }

        $btnImportMps.Enabled = $false
        $dir = $txtImportPath.Text.Trim()
        $ok = 0
        try {
            foreach ($item in $clbMps.CheckedItems) {
                $fullFile = Join-Path $dir $item
                Write-KrimsonLog "Importerar MP till $prdSrv : $item ..." -UpdateStatus
                [System.Windows.Forms.Application]::DoEvents()
                Import-SCManagementPack -Fullname $fullFile -ComputerName $prdSrv -ErrorAction Stop
                Write-KrimsonLog "OK: Importerade $item till $prdSrv"
                $ok++
            }
            Write-KrimsonLog "MP-import klar: $ok av $($clbMps.CheckedItems.Count) importerade till $dstProf." -UpdateStatus
            [System.Windows.Forms.MessageBox]::Show("Importerade $ok Management Packs till $dstProf ($prdSrv)!", "Import slutförd")
        } catch {
            Write-KrimsonLog "FEL vid MP-import: $($_.Exception.Message)" -UpdateStatus
            [System.Windows.Forms.MessageBox]::Show("Fel vid import:`n$($_.Exception.Message)", "Importfel")
        } finally {
            $btnImportMps.Enabled = $true
        }
    }.GetNewClosure())

    & $LoadMpFiles

    # --- STEG 2: SYNKA ORCHESTRATOR-SKRIPT (KÄLLA -> MÅL) ---
    $pnlStep2 = New-Object System.Windows.Forms.Panel
    $pnlStep2.Location = New-Object System.Drawing.Point(20, 360)
    $pnlStep2.Size = New-Object System.Drawing.Size($panelWidth, 125)
    $pnlStep2.BackColor = $Global:colorBgMain
    $pnlStep2.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $pnlStep2.Anchor = $anchorTopLR
    $Global:panelChildForm.Controls.Add($pnlStep2)

    $lblS2 = New-Object System.Windows.Forms.Label
    $lblS2.Text = "Steg 2: Synka Orchestrator-skript (Källa -> Mål)"
    $lblS2.Font = New-Object System.Drawing.Font($Global:ThemeConfig.Typography.FontFamily, 11, [System.Drawing.FontStyle]::Bold)
    $lblS2.ForeColor = $Global:colorAccent
    $lblS2.Location = New-Object System.Drawing.Point(15, 12)
    $lblS2.AutoSize = $true
    $pnlStep2.Controls.Add($lblS2)

    $orcSrcTxt = if ($depCfg.OrcScriptsSourceUNC) { $depCfg.OrcScriptsSourceUNC } else { "(Ej angiven i Inställningar)" }
    $orcDstTxt = if ($depCfg.OrcScriptsDestUNC)   { $depCfg.OrcScriptsDestUNC }   else { "(Ej angiven i Inställningar)" }

    $lblOrcPaths = New-Object System.Windows.Forms.Label
    $lblOrcPaths.Text = "Källa: $orcSrcTxt   -->   Mål: $orcDstTxt"
    $lblOrcPaths.ForeColor = $Global:colorTextGray
    $lblOrcPaths.Location = New-Object System.Drawing.Point(15, 42)
    $lblOrcPaths.AutoSize = $true
    $pnlStep2.Controls.Add($lblOrcPaths)

    $btnSyncOrc = New-Object System.Windows.Forms.Button
    $btnSyncOrc.Text = "Kopiera ändrade skript till Mål"
    $btnSyncOrc.Location = New-Object System.Drawing.Point(15, 76)
    $btnSyncOrc.Size = New-Object System.Drawing.Size(230, 32)
    $btnSyncOrc.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnSyncOrc.BackColor = $Global:colorBgSideMenu
    $btnSyncOrc.ForeColor = $Global:colorTextWhite
    $pnlStep2.Controls.Add($btnSyncOrc)

    $btnSyncOrc.Add_Click({
        $curDep = Get-ItemProperty -Path $regDep -ErrorAction SilentlyContinue
        if (-not $curDep.OrcScriptsSourceUNC -or -not $curDep.OrcScriptsDestUNC) {
            [System.Windows.Forms.MessageBox]::Show("Ange Orchestrator-skript Källa & Mål i Inställningar först.", "Sökväg saknas"); return
        }
        try {
            $srcFiles = Get-ChildItem -Path $curDep.OrcScriptsSourceUNC -File -Recurse -ErrorAction Stop
            $copied = 0
            foreach ($sf in $srcFiles) {
                $relPath = $sf.FullName.Substring($curDep.OrcScriptsSourceUNC.TrimEnd('\').Length).TrimStart('\')
                $dfPath  = Join-Path $curDep.OrcScriptsDestUNC $relPath
                $dfItem  = Get-Item $dfPath -ErrorAction SilentlyContinue
                if (-not $dfItem -or $sf.LastWriteTime -gt $dfItem.LastWriteTime) {
                    $dfDir = Split-Path $dfPath -Parent
                    if (-not (Test-Path $dfDir)) { New-Item -ItemType Directory -Path $dfDir -Force | Out-Null }
                    Copy-Item -Path $sf.FullName -Destination $dfPath -Force
                    Write-KrimsonLog "Synkade skript: $relPath"
                    $copied++
                }
            }
            Write-KrimsonLog "Orchestrator-synk klar: $copied ändrade skript kopierade." -UpdateStatus
            [System.Windows.Forms.MessageBox]::Show("Synkronisering klar! $copied ändrade filer kopierades.", "Synk slutförd")
        } catch {
            Write-KrimsonLog "FEL vid Orchestrator-synk: $($_.Exception.Message)" -UpdateStatus
            [System.Windows.Forms.MessageBox]::Show("Fel vid skriptsynk:`n$($_.Exception.Message)", "Fel")
        }
    }.GetNewClosure())

    # --- STEG 3: AVSLUTANDE CHECKLISTA (CHANGE & PORTAL) ---
    $pnlStep3 = New-Object System.Windows.Forms.Panel
    $pnlStep3.Location = New-Object System.Drawing.Point(20, 498)
    $pnlStep3.Size = New-Object System.Drawing.Size($panelWidth, 165)
    $pnlStep3.BackColor = $Global:colorBgMain
    $pnlStep3.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $pnlStep3.Anchor = $anchorTopLR
    $Global:panelChildForm.Controls.Add($pnlStep3)

    $lblS3 = New-Object System.Windows.Forms.Label
    $lblS3.Text = "Steg 3: Change-hantering & Portalmeddelande"
    $lblS3.Font = New-Object System.Drawing.Font($Global:ThemeConfig.Typography.FontFamily, 11, [System.Drawing.FontStyle]::Bold)
    $lblS3.ForeColor = $Global:colorAccent
    $lblS3.Location = New-Object System.Drawing.Point(15, 12)
    $lblS3.AutoSize = $true
    $pnlStep3.Controls.Add($lblS3)

    $yChk = 44
    foreach ($chkTxt in @(
        "1. Verifierat att alla driftsättningsärenden är knutna till pågående Change",
        "2. Skapat ny Change för nästa planerade driftsättning",
        "3. Uppdaterat driftmeddelande i självbetjäningsportalen & slutfört pågående Change"
    )) {
        $chk = New-Object System.Windows.Forms.CheckBox
        $chk.Text = $chkTxt
        $chk.ForeColor = $Global:colorTextWhite
        $chk.Location = New-Object System.Drawing.Point(15, $yChk)
        $chk.AutoSize = $true
        $chk.Add_CheckedChanged({
            if ($this.Checked) {
                $this.ForeColor = [System.Drawing.Color]::LightGreen
                Write-KrimsonLog "Deploy-check avbockad: $($this.Text)" -UpdateStatus
            } else {
                $this.ForeColor = $Global:colorTextWhite
            }
        }.GetNewClosure())
        $pnlStep3.Controls.Add($chk)
        $yChk += 32
    }
}
