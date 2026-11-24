function Get-ViewConfig {
    return [PSCustomObject]@{
        MainMenu     = "Release"
        MainMenuPrio = 20
        SubMenu      = "Prepare"
        SubMenuPrio  = 10
        Enabled      = $true
        StatusText   = "Prepare release: Backup Prod MPs, Compare/Export & Link Incidents"
        MainFunc     = "Show-ReleasePrepare"
    }
}

# Registrera konfigurationspanel för Inställningsvyn endast om vyn är Enabled
if ((Get-ViewConfig).Enabled) {
    function Global:Register-ViewSettings-ReleasePrepare {
        param($Container, [int]$StartY)

        $regReleasePath = "HKCU:\Software\KrimsonTools\Settings\Release"
        if (-not (Test-Path $regReleasePath)) { New-Item -Path $regReleasePath -Force | Out-Null }
        $relSettings = Get-ItemProperty -Path $regReleasePath -ErrorAction SilentlyContinue

        $panelWidth = $Container.ClientSize.Width - 40
        $anchorTopLR = ([System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right)
        $anchorTopR  = ([System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Right)

        $pnlConfig = New-Object System.Windows.Forms.Panel
        $pnlConfig.Location = New-Object System.Drawing.Point(20, $StartY)
        $pnlConfig.Size = New-Object System.Drawing.Size($panelWidth, 310)
        $pnlConfig.BackColor = $Global:colorBgMain
        $pnlConfig.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
        $pnlConfig.Anchor = $anchorTopLR
        $Container.Controls.Add($pnlConfig)

        $lblCfgTitle = New-Object System.Windows.Forms.Label
        $lblCfgTitle.Text = "Release Konfiguration (Sökvägar & SharePoint):"
        $lblCfgTitle.Font = New-Object System.Drawing.Font($Global:ThemeConfig.Typography.FontFamily, 11, [System.Drawing.FontStyle]::Bold)
        $lblCfgTitle.ForeColor = $Global:colorTextWhite
        $lblCfgTitle.Location = New-Object System.Drawing.Point(20, 15)
        $lblCfgTitle.AutoSize = $true
        $pnlConfig.Controls.Add($lblCfgTitle)

        # 1. Källa (Nattlig MP-export)
        $lblSrc = New-Object System.Windows.Forms.Label
        $lblSrc.Text = "Källa (Nattlig MP-backup UNC):"
        $lblSrc.ForeColor = $Global:colorTextWhite
        $lblSrc.Location = New-Object System.Drawing.Point(20, 52)
        $lblSrc.AutoSize = $true
        $pnlConfig.Controls.Add($lblSrc)

        $txtSrcUnc = New-Object System.Windows.Forms.TextBox
        $txtSrcUnc.Location = New-Object System.Drawing.Point(240, 49)
        $txtSrcUnc.Size = New-Object System.Drawing.Size(($panelWidth - 360), 23)
        $txtSrcUnc.Anchor = $anchorTopLR
        $txtSrcUnc.Text = if ($relSettings.NightlyBackupSourceUNC) { $relSettings.NightlyBackupSourceUNC } else { "" }
        $pnlConfig.Controls.Add($txtSrcUnc)

        $btnBrowseSrc = New-Object System.Windows.Forms.Button
        $btnBrowseSrc.Text = "Bläddra..."
        $btnBrowseSrc.Location = New-Object System.Drawing.Point(($panelWidth - 110), 48)
        $btnBrowseSrc.Size = New-Object System.Drawing.Size(80, 25)
        $btnBrowseSrc.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
        $btnBrowseSrc.BackColor = $Global:colorBgSideMenu
        $btnBrowseSrc.ForeColor = $Global:colorTextWhite
        $btnBrowseSrc.Anchor = $anchorTopR
        $pnlConfig.Controls.Add($btnBrowseSrc)

        # 2. Mål (Backup-arkiv)
        $lblDst = New-Object System.Windows.Forms.Label
        $lblDst.Text = "Mål (Backup-arkiv UNC):"
        $lblDst.ForeColor = $Global:colorTextWhite
        $lblDst.Location = New-Object System.Drawing.Point(20, 86)
        $lblDst.AutoSize = $true
        $pnlConfig.Controls.Add($lblDst)

        $txtDstUnc = New-Object System.Windows.Forms.TextBox
        $txtDstUnc.Location = New-Object System.Drawing.Point(240, 83)
        $txtDstUnc.Size = New-Object System.Drawing.Size(($panelWidth - 360), 23)
        $txtDstUnc.Anchor = $anchorTopLR
        $txtDstUnc.Text = if ($relSettings.ReleaseArchiveDestUNC) { $relSettings.ReleaseArchiveDestUNC } else { "" }
        $pnlConfig.Controls.Add($txtDstUnc)

        $btnBrowseDst = New-Object System.Windows.Forms.Button
        $btnBrowseDst.Text = "Bläddra..."
        $btnBrowseDst.Location = New-Object System.Drawing.Point(($panelWidth - 110), 82)
        $btnBrowseDst.Size = New-Object System.Drawing.Size(80, 25)
        $btnBrowseDst.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
        $btnBrowseDst.BackColor = $Global:colorBgSideMenu
        $btnBrowseDst.ForeColor = $Global:colorTextWhite
        $btnBrowseDst.Anchor = $anchorTopR
        $pnlConfig.Controls.Add($btnBrowseDst)

        # 3. Export-katalog för Release MPs
        $lblExp = New-Object System.Windows.Forms.Label
        $lblExp.Text = "Exportmapp (PreProd -> Prod):"
        $lblExp.ForeColor = $Global:colorTextWhite
        $lblExp.Location = New-Object System.Drawing.Point(20, 120)
        $lblExp.AutoSize = $true
        $pnlConfig.Controls.Add($lblExp)

        $txtExpUnc = New-Object System.Windows.Forms.TextBox
        $txtExpUnc.Location = New-Object System.Drawing.Point(240, 117)
        $txtExpUnc.Size = New-Object System.Drawing.Size(($panelWidth - 360), 23)
        $txtExpUnc.Anchor = $anchorTopLR
        $txtExpUnc.Text = if ($relSettings.ReleaseExportDestUNC) { $relSettings.ReleaseExportDestUNC } else { "" }
        $pnlConfig.Controls.Add($txtExpUnc)

        $btnBrowseExp = New-Object System.Windows.Forms.Button
        $btnBrowseExp.Text = "Bläddra..."
        $btnBrowseExp.Location = New-Object System.Drawing.Point(($panelWidth - 110), 116)
        $btnBrowseExp.Size = New-Object System.Drawing.Size(80, 25)
        $btnBrowseExp.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
        $btnBrowseExp.BackColor = $Global:colorBgSideMenu
        $btnBrowseExp.ForeColor = $Global:colorTextWhite
        $btnBrowseExp.Anchor = $anchorTopR
        $pnlConfig.Controls.Add($btnBrowseExp)

        # 4. SharePoint Site URL
        $lblSpSite = New-Object System.Windows.Forms.Label
        $lblSpSite.Text = "SharePoint Site URL:"
        $lblSpSite.ForeColor = $Global:colorTextWhite
        $lblSpSite.Location = New-Object System.Drawing.Point(20, 154)
        $lblSpSite.AutoSize = $true
        $pnlConfig.Controls.Add($lblSpSite)

        $txtSpSite = New-Object System.Windows.Forms.TextBox
        $txtSpSite.Location = New-Object System.Drawing.Point(240, 151)
        $txtSpSite.Size = New-Object System.Drawing.Size(($panelWidth - 270), 23)
        $txtSpSite.Anchor = $anchorTopLR
        $txtSpSite.Text = if ($relSettings.SharePointSiteURL) { $relSettings.SharePointSiteURL } else { "" }
        $pnlConfig.Controls.Add($txtSpSite)

        # 5. SharePoint Releaselista namn
        $lblSpList = New-Object System.Windows.Forms.Label
        $lblSpList.Text = "SharePoint Releaselista:"
        $lblSpList.ForeColor = $Global:colorTextWhite
        $lblSpList.Location = New-Object System.Drawing.Point(20, 188)
        $lblSpList.AutoSize = $true
        $pnlConfig.Controls.Add($lblSpList)

        $txtSpList = New-Object System.Windows.Forms.TextBox
        $txtSpList.Location = New-Object System.Drawing.Point(240, 185)
        $txtSpList.Size = New-Object System.Drawing.Size(260, 23)
        $txtSpList.Text = if ($relSettings.SharePointReleaseList) { $relSettings.SharePointReleaseList } else { "Releaselista" }
        $pnlConfig.Controls.Add($txtSpList)

        # 6. Miljöprofiler (SCSM-Källa / Mål)
        $lblProfs = New-Object System.Windows.Forms.Label
        $lblProfs.Text = "Miljöprofiler (SCSM-Källa / Mål):"
        $lblProfs.ForeColor = $Global:colorTextWhite
        $lblProfs.Location = New-Object System.Drawing.Point(20, 222)
        $lblProfs.AutoSize = $true
        $pnlConfig.Controls.Add($lblProfs)

        $profNames = @()
        $profRoot = "HKCU:\Software\KrimsonTools\Settings\MiljoProfiler"
        if (Test-Path $profRoot) {
            $profNames = Get-ChildItem $profRoot | Select-Object -ExpandProperty PSChildName
        }

        $cmbPreProdProf = New-Object System.Windows.Forms.ComboBox
        $cmbPreProdProf.Location = New-Object System.Drawing.Point(240, 219)
        $cmbPreProdProf.Size = New-Object System.Drawing.Size(180, 23)
        $cmbPreProdProf.DropDownStyle = "DropDownList"
        foreach ($p in $profNames) { [void]$cmbPreProdProf.Items.Add($p) }
        if ($relSettings.PreProdProfile -and $cmbPreProdProf.Items.Contains($relSettings.PreProdProfile)) { $cmbPreProdProf.SelectedItem = $relSettings.PreProdProfile }
        $pnlConfig.Controls.Add($cmbPreProdProf)

        $cmbProdProf = New-Object System.Windows.Forms.ComboBox
        $cmbProdProf.Location = New-Object System.Drawing.Point(435, 219)
        $cmbProdProf.Size = New-Object System.Drawing.Size(180, 23)
        $cmbProdProf.DropDownStyle = "DropDownList"
        foreach ($p in $profNames) { [void]$cmbProdProf.Items.Add($p) }
        if ($relSettings.ProdProfile -and $cmbProdProf.Items.Contains($relSettings.ProdProfile)) { $cmbProdProf.SelectedItem = $relSettings.ProdProfile }
        $pnlConfig.Controls.Add($cmbProdProf)

        # Spara-knapp
        $btnSaveUnc = New-Object System.Windows.Forms.Button
        $btnSaveUnc.Text = "Spara Release-inställningar"
        $btnSaveUnc.Location = New-Object System.Drawing.Point(240, 260)
        $btnSaveUnc.Size = New-Object System.Drawing.Size(200, 28)
        $btnSaveUnc.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
        $btnSaveUnc.BackColor = $Global:colorBgSideMenu
        $btnSaveUnc.ForeColor = $Global:colorTextWhite
        $pnlConfig.Controls.Add($btnSaveUnc)

        $btnBrowseSrc.Add_Click({ $fbd = New-Object System.Windows.Forms.FolderBrowserDialog; if ($fbd.ShowDialog() -eq "OK") { $txtSrcUnc.Text = $fbd.SelectedPath } }.GetNewClosure())
        $btnBrowseDst.Add_Click({ $fbd = New-Object System.Windows.Forms.FolderBrowserDialog; if ($fbd.ShowDialog() -eq "OK") { $txtDstUnc.Text = $fbd.SelectedPath } }.GetNewClosure())
        $btnBrowseExp.Add_Click({ $fbd = New-Object System.Windows.Forms.FolderBrowserDialog; if ($fbd.ShowDialog() -eq "OK") { $txtExpUnc.Text = $fbd.SelectedPath } }.GetNewClosure())

        $btnSaveUnc.Add_Click({
            Set-ItemProperty -Path $regReleasePath -Name "NightlyBackupSourceUNC" -Value $txtSrcUnc.Text.Trim() -Force
            Set-ItemProperty -Path $regReleasePath -Name "ReleaseArchiveDestUNC"  -Value $txtDstUnc.Text.Trim() -Force
            Set-ItemProperty -Path $regReleasePath -Name "ReleaseExportDestUNC"   -Value $txtExpUnc.Text.Trim() -Force
            Set-ItemProperty -Path $regReleasePath -Name "SharePointSiteURL"      -Value $txtSpSite.Text.Trim() -Force
            Set-ItemProperty -Path $regReleasePath -Name "SharePointReleaseList"  -Value $txtSpList.Text.Trim() -Force
            Set-ItemProperty -Path $regReleasePath -Name "PreProdProfile"         -Value ([string]$cmbPreProdProf.SelectedItem) -Force
            Set-ItemProperty -Path $regReleasePath -Name "ProdProfile"            -Value ([string]$cmbProdProf.SelectedItem) -Force
            if ($Global:statusLabel) { $Global:statusLabel.Text = "Release-inställningar sparade i registret!" }
        }.GetNewClosure())

        return $pnlConfig
    }
} else {
    Remove-Item -Path "Function:\Global:Register-ViewSettings-ReleasePrepare" -ErrorAction SilentlyContinue
}

function Global:Show-ReleasePrepare {
    if ($Global:panelChildForm) {
        $Global:panelChildForm.Controls.Clear()
        $Global:panelChildForm.AutoScroll = $true
        $Global:panelChildForm.AutoScrollMargin = New-Object System.Drawing.Size(0, 30)
    }

    $regReleasePath = "HKCU:\Software\KrimsonTools\Settings\Release"
    $relSettings = Get-ItemProperty -Path $regReleasePath -ErrorAction SilentlyContinue

    $panelWidth = $Global:panelChildForm.ClientSize.Width - 40
    $anchorTopLR = ([System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right)

    # =========================================================================
    # STEG 1: VÄLJ DRIFTSÄTTNINGSDATUM
    # =========================================================================
    $pnlStep1 = New-Object System.Windows.Forms.Panel
    $pnlStep1.Location = New-Object System.Drawing.Point(20, 20)
    $pnlStep1.Size = New-Object System.Drawing.Size($panelWidth, 85)
    $pnlStep1.BackColor = $Global:colorBgMain
    $pnlStep1.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $pnlStep1.Anchor = $anchorTopLR
    $Global:panelChildForm.Controls.Add($pnlStep1)

    $lblStep1Title = New-Object System.Windows.Forms.Label
    $lblStep1Title.Text = "Steg 1: Välj Driftsättningsdatum"
    $lblStep1Title.Font = New-Object System.Drawing.Font($Global:ThemeConfig.Typography.FontFamily, 11, [System.Drawing.FontStyle]::Bold)
    $lblStep1Title.ForeColor = $Global:colorAccent
    $lblStep1Title.Location = New-Object System.Drawing.Point(15, 12)
    $lblStep1Title.AutoSize = $true
    $pnlStep1.Controls.Add($lblStep1Title)

    $lblDatePrompt = New-Object System.Windows.Forms.Label
    $lblDatePrompt.Text = "Driftsättningsdatum:"
    $lblDatePrompt.ForeColor = $Global:colorTextWhite
    $lblDatePrompt.Location = New-Object System.Drawing.Point(15, 45)
    $lblDatePrompt.AutoSize = $true
    $pnlStep1.Controls.Add($lblDatePrompt)

    $dtpReleaseDate = New-Object System.Windows.Forms.DateTimePicker
    $dtpReleaseDate.Location = New-Object System.Drawing.Point(175, 41)
    $dtpReleaseDate.Size = New-Object System.Drawing.Size(140, 24)
    $dtpReleaseDate.Format = [System.Windows.Forms.DateTimePickerFormat]::Custom
    $dtpReleaseDate.CustomFormat = "yyyy-MM-dd"
    if ($relSettings.ActiveReleaseDate) {
        try { $dtpReleaseDate.Value = [datetime]::ParseExact($relSettings.ActiveReleaseDate, "yyyy-MM-dd", $null) } catch {}
    }
    $pnlStep1.Controls.Add($dtpReleaseDate)

    # =========================================================================
    # STEG 2: BACKUP AV PROD MPs
    # =========================================================================
    $pnlStep2 = New-Object System.Windows.Forms.Panel
    $pnlStep2.Location = New-Object System.Drawing.Point(20, 120)
    $pnlStep2.Size = New-Object System.Drawing.Size($panelWidth, 275)
    $pnlStep2.BackColor = $Global:colorBgMain
    $pnlStep2.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $pnlStep2.Anchor = $anchorTopLR
    $Global:panelChildForm.Controls.Add($pnlStep2)

    $lblStep2Title = New-Object System.Windows.Forms.Label
    $lblStep2Title.Text = "Steg 2: Säkerhetskopiera Prod MPs"
    $lblStep2Title.Font = New-Object System.Drawing.Font($Global:ThemeConfig.Typography.FontFamily, 11, [System.Drawing.FontStyle]::Bold)
    $lblStep2Title.ForeColor = $Global:colorAccent
    $lblStep2Title.Location = New-Object System.Drawing.Point(15, 12)
    $lblStep2Title.AutoSize = $true
    $pnlStep2.Controls.Add($lblStep2Title)

    $lblPreviewPaths = New-Object System.Windows.Forms.Label
    $lblPreviewPaths.ForeColor = $Global:colorTextGray
    $lblPreviewPaths.Location = New-Object System.Drawing.Point(15, 40)
    $lblPreviewPaths.AutoSize = $true
    $pnlStep2.Controls.Add($lblPreviewPaths)

    $btnRunBackup = New-Object System.Windows.Forms.Button
    $btnRunBackup.Location = New-Object System.Drawing.Point(15, 82)
    $btnRunBackup.Size = New-Object System.Drawing.Size(220, 32)
    $btnRunBackup.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnRunBackup.BackColor = $Global:colorBgSideMenu
    $btnRunBackup.ForeColor = $Global:colorTextWhite
    $pnlStep2.Controls.Add($btnRunBackup)

    $lblStep2Status = New-Object System.Windows.Forms.Label
    $lblStep2Status.Text = "Status: Ej körd"
    $lblStep2Status.ForeColor = $Global:colorTextGray
    $lblStep2Status.Location = New-Object System.Drawing.Point(250, 89)
    $lblStep2Status.AutoSize = $true
    $pnlStep2.Controls.Add($lblStep2Status)

    $txtBackupLog = New-Object System.Windows.Forms.TextBox
    $txtBackupLog.Location = New-Object System.Drawing.Point(15, 126)
    $txtBackupLog.Size = New-Object System.Drawing.Size(($panelWidth - 30), 132)
    $txtBackupLog.Anchor = $anchorTopLR
    $txtBackupLog.Multiline = $true
    $txtBackupLog.ReadOnly = $true
    $txtBackupLog.ScrollBars = "Vertical"
    $txtBackupLog.BackColor = [System.Drawing.Color]::FromArgb(22, 22, 26)
    $txtBackupLog.ForeColor = $Global:colorTextWhite
    $txtBackupLog.Font = New-Object System.Drawing.Font("Consolas", 9)
    $pnlStep2.Controls.Add($txtBackupLog)

    # --- FUNKTION FÖR ATT UPPDATERA DATUM-FÖRHANDSVISNING ---
    $UpdateDateUI = {
        $selDate = $dtpReleaseDate.Value.ToString("yyyy-MM-dd")
        $cur = Get-ItemProperty -Path $regReleasePath -ErrorAction SilentlyContinue
        $sRoot = if ($cur.NightlyBackupSourceUNC) { $cur.NightlyBackupSourceUNC.TrimEnd('\') } else { "(Ej angiven)" }
        $dRoot = if ($cur.ReleaseArchiveDestUNC)  { $cur.ReleaseArchiveDestUNC.TrimEnd('\') }  else { "(Ej angiven)" }

        $lblPreviewPaths.Text = "Källa: $sRoot\$selDate`r`nMål:   $dRoot\$selDate"
        $btnRunBackup.Text = "Kör MP-Backup ($selDate)"
        Set-ItemProperty -Path $regReleasePath -Name "ActiveReleaseDate" -Value $selDate -Force
    }.GetNewClosure()

    & $UpdateDateUI
    $dtpReleaseDate.Add_ValueChanged($UpdateDateUI)

    # --- HÄNDELSE: KÖR BACKUP ---
    $btnRunBackup.Add_Click({
        $curRel  = Get-ItemProperty -Path $regReleasePath -ErrorAction SilentlyContinue
        $srcRoot = $curRel.NightlyBackupSourceUNC
        $dstRoot = $curRel.ReleaseArchiveDestUNC
        $selDateDash    = $dtpReleaseDate.Value.ToString("yyyy-MM-dd")
        $selDateCompact = $dtpReleaseDate.Value.ToString("yyyyMMdd")
        $txtBackupLog.Clear()

        if (-not $srcRoot -or -not $dstRoot) {
            $txtBackupLog.AppendText("[FEL] UNC-sökvägar saknas. Dubbelklicka på loggan och ange dem under 'Release Konfiguration'.`r`n")
            return
        }

        # Leta efter underkatalog med valt datum (stödjer både YYYY-MM-DD och YYYYMMDD)
        $srcDateFolderDash    = Join-Path $srcRoot $selDateDash
        $srcDateFolderCompact = Join-Path $srcRoot $selDateCompact
        $actualSrcFolder = $null

        if (Test-Path $srcDateFolderDash) {
            $actualSrcFolder = $srcDateFolderDash
        } elseif (Test-Path $srcDateFolderCompact) {
            $actualSrcFolder = $srcDateFolderCompact
        } else {
            $txtBackupLog.AppendText("[FEL] Hittar inte källmappen för valt datum:`r`n      Testade: $srcDateFolderDash`r`n      Samt:    $srcDateFolderCompact`r`n")
            $lblStep2Status.Text = "Status: Källmapp saknas"
            $lblStep2Status.ForeColor = [System.Drawing.Color]::Salmon
            return
        }

        try {
            $dstDateFolder = Join-Path $dstRoot $selDateDash
            if (-not (Test-Path $dstDateFolder)) {
                New-Item -Path $dstDateFolder -ItemType Directory -Force | Out-Null
                $txtBackupLog.AppendText("[INFO] Skapade ny målmapp: $dstDateFolder`r`n")
            } else {
                $txtBackupLog.AppendText("[INFO] Använder befintlig målmapp: $dstDateFolder`r`n")
            }

            # 1. Kopiera alla unsealed MPs (.xml) i rotmappen
            $xmlFiles = Get-ChildItem -Path $actualSrcFolder -File | Where-Object { $_.Extension -in ".xml", ".mp", ".mpb" }
            $txtBackupLog.AppendText("[INFO] Kopierar $($xmlFiles.Count) unsealed MPs från roten...`r`n")
            [System.Windows.Forms.Application]::DoEvents()

            foreach ($f in $xmlFiles) {
                Copy-Item -Path $f.FullName -Destination $dstDateFolder -Force
            }

            # 2. Kontrollera och kopiera underkatalogen 'sealed' om den finns
            $srcSealedFolder = Join-Path $actualSrcFolder "sealed"
            $sealedCount = 0
            if (Test-Path $srcSealedFolder) {
                $dstSealedFolder = Join-Path $dstDateFolder "sealed"
                if (-not (Test-Path $dstSealedFolder)) {
                    New-Item -Path $dstSealedFolder -ItemType Directory -Force | Out-Null
                }
                $sealedFiles = Get-ChildItem -Path $srcSealedFolder -File
                $sealedCount = $sealedFiles.Count
                $txtBackupLog.AppendText("[INFO] Kopierar $sealedCount sealed MPs till $dstSealedFolder...`r`n")
                [System.Windows.Forms.Application]::DoEvents()

                foreach ($sf in $sealedFiles) {
                    Copy-Item -Path $sf.FullName -Destination $dstSealedFolder -Force
                }
            } else {
                $txtBackupLog.AppendText("[INFO] Ingen underkatalog 'sealed' hittades i källan.`r`n")
            }

            $totalCount = $xmlFiles.Count + $sealedCount
            if ($totalCount -eq 0) {
                $txtBackupLog.AppendText("[VARNING] Inga MP-filer hittades i $actualSrcFolder`r`n")
                return
            }

            $txtBackupLog.AppendText("[OK] Klart! $($xmlFiles.Count) unsealed + $sealedCount sealed MPs säkrade i $dstDateFolder`r`n")
            $lblStep2Status.Text = "Status: Klart ($($xmlFiles.Count) unsealed + $sealedCount sealed)"
            $lblStep2Status.ForeColor = [System.Drawing.Color]::LightGreen
            if ($Global:statusLabel) { $Global:statusLabel.Text = "MP-backup slutförd ($totalCount filer) till $dstDateFolder" }

        } catch {
            $txtBackupLog.AppendText("[FEL] Kopiering misslyckades: $_`r`n")
            $lblStep2Status.Text = "Status: Fel vid kopiering"
            $lblStep2Status.ForeColor = [System.Drawing.Color]::Salmon
        }
    }.GetNewClosure())

    # =========================================================================
    # STEG 3: KONTROLLERA LOGGBOK I SHAREPOINT
    # =========================================================================
    $pnlStep3 = New-Object System.Windows.Forms.Panel
    $pnlStep3.Location = New-Object System.Drawing.Point(20, 410)
    $pnlStep3.Size = New-Object System.Drawing.Size($panelWidth, 130)
    $pnlStep3.BackColor = $Global:colorBgMain
    $pnlStep3.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $pnlStep3.Anchor = $anchorTopLR
    $Global:panelChildForm.Controls.Add($pnlStep3)

    $lblStep3Title = New-Object System.Windows.Forms.Label
    $lblStep3Title.Text = "Steg 3: Kontrollera Loggbok i SharePoint (pågående ändringar/noteringar)"
    $lblStep3Title.Font = New-Object System.Drawing.Font($Global:ThemeConfig.Typography.FontFamily, 11, [System.Drawing.FontStyle]::Bold)
    $lblStep3Title.ForeColor = $Global:colorAccent
    $lblStep3Title.Location = New-Object System.Drawing.Point(15, 12)
    $lblStep3Title.AutoSize = $true
    $pnlStep3.Controls.Add($lblStep3Title)

    $spUrlVal = if ($relSettings.SharePointLogbookURL) { $relSettings.SharePointLogbookURL } else { "(Ingen URL angiven i Inställningar)" }
    $lblSpInfo = New-Object System.Windows.Forms.Label
    $lblSpInfo.Text = "SharePoint-sida: $spUrlVal"
    $lblSpInfo.ForeColor = $Global:colorTextGray
    $lblSpInfo.Location = New-Object System.Drawing.Point(15, 42)
    $lblSpInfo.AutoSize = $true
    $pnlStep3.Controls.Add($lblSpInfo)

    $btnOpenSp = New-Object System.Windows.Forms.Button
    $btnOpenSp.Text = "Öppna i webbläsare"
    $btnOpenSp.Location = New-Object System.Drawing.Point(15, 76)
    $btnOpenSp.Size = New-Object System.Drawing.Size(175, 32)
    $btnOpenSp.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnOpenSp.BackColor = $Global:colorBgSideMenu
    $btnOpenSp.ForeColor = $Global:colorTextWhite
    $pnlStep3.Controls.Add($btnOpenSp)

    $btnCopySp = New-Object System.Windows.Forms.Button
    $btnCopySp.Text = "Kopiera länk (för RDP/TS)"
    $btnCopySp.Location = New-Object System.Drawing.Point(205, 76)
    $btnCopySp.Size = New-Object System.Drawing.Size(195, 32)
    $btnCopySp.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnCopySp.BackColor = $Global:colorBgSideMenu
    $btnCopySp.ForeColor = $Global:colorTextWhite
    $pnlStep3.Controls.Add($btnCopySp)

    $chkLogbookDone = New-Object System.Windows.Forms.CheckBox
    $chkLogbookDone.Text = "Loggbok läst och kontrollerad"
    $chkLogbookDone.ForeColor = $Global:colorTextWhite
    $chkLogbookDone.Location = New-Object System.Drawing.Point(425, 82)
    $chkLogbookDone.AutoSize = $true
    $pnlStep3.Controls.Add($chkLogbookDone)

    $btnOpenSp.Add_Click({
        $cur = Get-ItemProperty -Path $regReleasePath -ErrorAction SilentlyContinue
        if ($cur.SharePointLogbookURL) {
            Start-Process $cur.SharePointLogbookURL
            if ($Global:statusLabel) { $Global:statusLabel.Text = "Öppnade SharePoint-loggbok i webbläsaren." }
        } else {
            [System.Windows.Forms.MessageBox]::Show("Ingen SharePoint-URL är sparad. Dubbelklicka på loggan och ange den under 'Release Konfiguration'.", "URL saknas")
        }
    }.GetNewClosure())

    $btnCopySp.Add_Click({
        $cur = Get-ItemProperty -Path $regReleasePath -ErrorAction SilentlyContinue
        if ($cur.SharePointLogbookURL) {
            [System.Windows.Forms.Clipboard]::SetText($cur.SharePointLogbookURL)
            if ($Global:statusLabel) { $Global:statusLabel.Text = "SharePoint-länken kopierad till urklipp!" }
        } else {
            [System.Windows.Forms.MessageBox]::Show("Ingen SharePoint-URL är sparad i Inställningar.", "URL saknas")
        }
    }.GetNewClosure())

    $chkLogbookDone.Add_CheckedChanged({
        if ($chkLogbookDone.Checked) {
            $chkLogbookDone.ForeColor = [System.Drawing.Color]::LightGreen
        } else {
            $chkLogbookDone.ForeColor = $Global:colorTextWhite
        }
    }.GetNewClosure())

    # =========================================================================
    # STEG 4: JÄMFÖR & EXPORTERA MANAGEMENT PACKS (PREPROD vs PROD + SHAREPOINT)
    # =========================================================================
    # Huvudpanelen för Steg 4 skapas och placeras i formuläret.
    $pnlStep4 = New-Object System.Windows.Forms.Panel
    $pnlStep4.Location = New-Object System.Drawing.Point(20, 555)
    $pnlStep4.Size = New-Object System.Drawing.Size($panelWidth, 480)
    $pnlStep4.BackColor = $Global:colorBgMain
    $pnlStep4.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $pnlStep4.Anchor = $anchorTopLR
    $Global:panelChildForm.Controls.Add($pnlStep4)

    $lblStep4Title = New-Object System.Windows.Forms.Label
    $lblStep4Title.Text = "Steg 4: Jämför & Exportera Management Packs (PreProd vs Prod)"
    $lblStep4Title.Font = New-Object System.Drawing.Font($Global:ThemeConfig.Typography.FontFamily, 11, [System.Drawing.FontStyle]::Bold)
    $lblStep4Title.ForeColor = $Global:colorAccent
    $lblStep4Title.Location = New-Object System.Drawing.Point(15, 12)
    $lblStep4Title.AutoSize = $true
    $pnlStep4.Controls.Add($lblStep4Title)

    $lblMpFilter = New-Object System.Windows.Forms.Label
    $lblMpFilter.Text = "Ändrade sedan:"
    $lblMpFilter.ForeColor = $Global:colorTextWhite
    $lblMpFilter.Location = New-Object System.Drawing.Point(15, 45)
    $lblMpFilter.AutoSize = $true
    $pnlStep4.Controls.Add($lblMpFilter)

    $dtpMpFilter = New-Object System.Windows.Forms.DateTimePicker
    $dtpMpFilter.Location = New-Object System.Drawing.Point(125, 41)
    $dtpMpFilter.Size = New-Object System.Drawing.Size(110, 23)
    $dtpMpFilter.Format = [System.Windows.Forms.DateTimePickerFormat]::Custom
    $dtpMpFilter.CustomFormat = "yyyy-MM-dd"
    $dtpMpFilter.Value = (Get-Date).AddMonths(-1)
    $pnlStep4.Controls.Add($dtpMpFilter)

    $btnLoadMp = New-Object System.Windows.Forms.Button
    $btnLoadMp.Text = "Ladda & Jämför"
    $btnLoadMp.Location = New-Object System.Drawing.Point(245, 39)
    $btnLoadMp.Size = New-Object System.Drawing.Size(130, 27)
    $btnLoadMp.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnLoadMp.BackColor = $Global:colorBgSideMenu
    $btnLoadMp.ForeColor = $Global:colorTextWhite
    $pnlStep4.Controls.Add($btnLoadMp)

    $chkHideEqual = New-Object System.Windows.Forms.CheckBox
    $chkHideEqual.Text = "Dölj 'Equal'"
    $chkHideEqual.ForeColor = $Global:colorTextWhite
    $chkHideEqual.Location = New-Object System.Drawing.Point(385, 44)
    $chkHideEqual.AutoSize = $true
    $pnlStep4.Controls.Add($chkHideEqual)

    $chkAutoSp = New-Object System.Windows.Forms.CheckBox
    $chkAutoSp.Text = "Auto-markera SP"
    $chkAutoSp.ForeColor = $Global:colorTextWhite
    $chkAutoSp.Location = New-Object System.Drawing.Point(485, 44)
    $chkAutoSp.AutoSize = $true
    $chkAutoSp.Checked = $true
    $pnlStep4.Controls.Add($chkAutoSp)

    $txtMpSearch = New-Object System.Windows.Forms.TextBox
    $txtMpSearch.Location = New-Object System.Drawing.Point(615, 41)
    $txtMpSearch.Size = New-Object System.Drawing.Size(140, 23)
    $pnlStep4.Controls.Add($txtMpSearch)

    $btnExportMp = New-Object System.Windows.Forms.Button
    $btnExportMp.Text = "Exportera markerade"
    $btnExportMp.Location = New-Object System.Drawing.Point(765, 39)
    $btnExportMp.Size = New-Object System.Drawing.Size(155, 27)
    $btnExportMp.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnExportMp.BackColor = $Global:colorBgSideMenu
    $btnExportMp.ForeColor = $Global:colorTextWhite
    $pnlStep4.Controls.Add($btnExportMp)

    $progMp = New-Object System.Windows.Forms.ProgressBar
    $progMp.Location = New-Object System.Drawing.Point(15, 74)
    $progMp.Size = New-Object System.Drawing.Size(($panelWidth - 30), 14)
    $progMp.Anchor = $anchorTopLR
    $progMp.Visible = $false
    $pnlStep4.Controls.Add($progMp)

    $lblMpStatus = New-Object System.Windows.Forms.Label
    $lblMpStatus.Text = "Redo. Klicka på 'Ladda & Jämför' för att hämta MPs."
    $lblMpStatus.ForeColor = $Global:colorTextGray
    $lblMpStatus.Location = New-Object System.Drawing.Point(15, 92)
    $lblMpStatus.AutoSize = $true
    $pnlStep4.Controls.Add($lblMpStatus)

    $dtMp = New-Object System.Data.DataTable
    [void]$dtMp.Columns.Add("Display Name", [string])
    [void]$dtMp.Columns.Add("Name", [string])
    [void]$dtMp.Columns.Add("Prod Modified", [datetime])
    [void]$dtMp.Columns.Add("Status", [string])
    [void]$dtMp.Columns.Add("PreProd Modified", [datetime])
    [void]$dtMp.Columns.Add("SP_Status", [string])
    [void]$dtMp.Columns.Add("PP_ID", [string])
    [void]$dtMp.Columns.Add("PRD_ID", [string])
    $dvMp = New-Object System.Data.DataView($dtMp)

    $dgvMp = New-Object System.Windows.Forms.DataGridView
    $dgvMp.Location = New-Object System.Drawing.Point(15, 115)
    $dgvMp.Size = New-Object System.Drawing.Size(($panelWidth - 30), 348)
    $dgvMp.Anchor = $anchorTopLR
    $dgvMp.SelectionMode = "FullRowSelect"
    $dgvMp.AllowUserToAddRows = $false
    $dgvMp.RowHeadersVisible = $false
    $dgvMp.ReadOnly = $true
    $dgvMp.AutoGenerateColumns = $false
    $dgvMp.BackgroundColor = [System.Drawing.Color]::White
    $dgvMp.DataSource = $dvMp
    $pnlStep4.Controls.Add($dgvMp)

    foreach ($colDef in @(
        @{ Prop="Display Name"; Header="Display Name"; Mode="Fill"; Fmt="" },
        @{ Prop="Name"; Header="Name"; Mode="Fill"; Fmt="" },
        @{ Prop="Prod Modified"; Header="Prod Modified"; Mode="AllCells"; Fmt="yyyy-MM-dd HH:mm" },
        @{ Prop="Status"; Header="Status"; Mode="AllCells"; Fmt="" },
        @{ Prop="PreProd Modified"; Header="PreProd Modified"; Mode="AllCells"; Fmt="yyyy-MM-dd HH:mm" }
    )) {
        $col = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
        $col.DataPropertyName = $colDef.Prop
        $col.HeaderText = $colDef.Header
        $col.AutoSizeMode = $colDef.Mode
        if ($colDef.Fmt) { $col.DefaultCellStyle.Format = $colDef.Fmt }
        [void]$dgvMp.Columns.Add($col)
    }

    $UpdateMpSelection = {
        $dgvMp.ClearSelection()
        if ($chkAutoSp.Checked) {
            foreach ($row in $dgvMp.Rows) {
                $spStat = $row.DataBoundItem.Row["SP_Status"]
                if ($spStat -like "*Ska drifts*") { $row.Selected = $true }
            }
        }
    }.GetNewClosure()

    $ApplyMpFilters = {
        $filters = @()
        if ($chkHideEqual.Checked) { $filters += "Status <> 'Equal'" }
        $s = $txtMpSearch.Text.Trim().Replace("'", "''")
        if ($s) { $filters += "([Display Name] LIKE '*$s*' OR Name LIKE '*$s*')" }
        $dvMp.RowFilter = ($filters -join " AND ")
        & $UpdateMpSelection
    }.GetNewClosure()

    $dgvMp.Add_CellFormatting({
        param($sender, $e)
        if ($e.RowIndex -lt 0 -or -not $dgvMp.Rows[$e.RowIndex].DataBoundItem) { return }
        $dr = $dgvMp.Rows[$e.RowIndex].DataBoundItem.Row
        $st = $dr["Status"]; $sp = $dr["SP_Status"]
        if ($sp -like "*EJ godk*") { $e.CellStyle.BackColor = [System.Drawing.Color]::Crimson; $e.CellStyle.ForeColor = [System.Drawing.Color]::White }
        elseif ($sp -like "*Ska drifts*") { $e.CellStyle.BackColor = [System.Drawing.Color]::Gold; $e.CellStyle.ForeColor = [System.Drawing.Color]::Black }
        elseif ($st -eq "Warning") { $e.CellStyle.BackColor = [System.Drawing.Color]::MistyRose; $e.CellStyle.ForeColor = [System.Drawing.Color]::DarkRed }
        elseif ($st -eq "New") { $e.CellStyle.BackColor = [System.Drawing.Color]::LightGreen; $e.CellStyle.ForeColor = [System.Drawing.Color]::Black }
        elseif ($st -eq "PreProd") { $e.CellStyle.BackColor = [System.Drawing.Color]::LightSkyBlue; $e.CellStyle.ForeColor = [System.Drawing.Color]::Black }
        else { $e.CellStyle.BackColor = [System.Drawing.Color]::White; $e.CellStyle.ForeColor = [System.Drawing.Color]::Black }
    }.GetNewClosure())

    $GetMPXmlSafe = {
        param($MpObj, $Server)
        $tmpDir = Join-Path $env:TEMP "KrimsonMPDiff_$([guid]::NewGuid().ToString('N'))"
        New-Item -ItemType Directory -Path $tmpDir -Force | Out-Null
        try {
            $MpObj | Export-SCManagementPack -Path $tmpDir -ComputerName $Server -ErrorAction Stop | Out-Null
            $f = Get-ChildItem $tmpDir -Filter "*.xml" | Select-Object -First 1
            if ($f) { return Get-Content $f.FullName -Raw -Encoding UTF8 }
        } finally { Remove-Item $tmpDir -Recurse -Force -ErrorAction SilentlyContinue }
        return $null
    }

    $dgvMp.Add_CellDoubleClick({
        param($sender, $e)
        if ($e.RowIndex -lt 0) { return }
        $dr = $dgvMp.Rows[$e.RowIndex].DataBoundItem.Row
        $mpName = $dr["Name"]; $ppId = $dr["PP_ID"]; $prdId = $dr["PRD_ID"]
        if (-not $ppId -or -not $prdId) { [System.Windows.Forms.MessageBox]::Show("MP finns bara i ena miljön.", "Info"); return }

        $cur = Get-ItemProperty -Path $regReleasePath -ErrorAction SilentlyContinue
        $ppSrv  = ((Get-ItemProperty "HKCU:\Software\KrimsonTools\Settings\MiljoProfiler\$($cur.PreProdProfile)" -ErrorAction SilentlyContinue).SCSM_Server -split ',')[0].Trim()
        $prdSrv = ((Get-ItemProperty "HKCU:\Software\KrimsonTools\Settings\MiljoProfiler\$($cur.ProdProfile)" -ErrorAction SilentlyContinue).SCSM_Server -split ',')[0].Trim()

        $lblMpStatus.Text = "Hämtar XML för $mpName..."
        [System.Windows.Forms.Application]::DoEvents()
        $ppXml  = & $GetMPXmlSafe (Get-SCManagementPack -Id $ppId -ComputerName $ppSrv) $ppSrv
        $prdXml = & $GetMPXmlSafe (Get-SCManagementPack -Id $prdId -ComputerName $prdSrv) $prdSrv

        $diffDir = Join-Path $env:TEMP "KrimsonMPCompare"
        if (-not (Test-Path $diffDir)) { New-Item -ItemType Directory -Path $diffDir -Force | Out-Null }
        $fPrd = Join-Path $diffDir "${mpName}_Mal.xml"; $fPp = Join-Path $diffDir "${mpName}_Kalla.xml"
        $prdXml | Out-File $fPrd -Encoding UTF8 -Force; $ppXml | Out-File $fPp -Encoding UTF8 -Force

        $npp = @("$env:ProgramFiles\Notepad++\notepad++.exe", "${env:ProgramFiles(x86)}\Notepad++\notepad++.exe") | Where-Object { Test-Path $_ } | Select-Object -First 1
        if ($npp) { Start-Process $npp -ArgumentList "`"$fPrd`" `"$fPp`"" } else { Start-Process notepad.exe "`"$fPp`"" }
        $lblMpStatus.Text = "Öppnade XML-jämförelse för $mpName."
    }.GetNewClosure())


    # Kopplar händelsehanterare till kontroller
    $chkHideEqual.Add_CheckedChanged($ApplyMpFilters)
    $txtMpSearch.Add_TextChanged($ApplyMpFilters)
    $chkAutoSp.Add_CheckedChanged($UpdateMpSelection)

    $btnLoadMp.Add_Click({
        $cur = Get-ItemProperty -Path $regReleasePath -ErrorAction SilentlyContinue
        $ppSrv  = ((Get-ItemProperty "HKCU:\Software\KrimsonTools\Settings\MiljoProfiler\$($cur.PreProdProfile)" -ErrorAction SilentlyContinue).SCSM_Server -split ',')[0].Trim()
        $prdSrv = ((Get-ItemProperty "HKCU:\Software\KrimsonTools\Settings\MiljoProfiler\$($cur.ProdProfile)" -ErrorAction SilentlyContinue).SCSM_Server -split ',')[0].Trim()
        if (-not $ppSrv -or -not $prdSrv) { [System.Windows.Forms.MessageBox]::Show("Välj miljöprofiler (SCSM-Källa / Mål) i Inställningar först.", "Profil saknas"); return }

        $btnLoadMp.Enabled = $false; $dtMp.Clear(); $progMp.Visible = $true; $progMp.Value = 0
        $lblMpStatus.Text = "Hämtar SharePoint Releaselista..."
        [System.Windows.Forms.Application]::DoEvents()

        # 1. Hämta SharePoint Releaselista för valt driftsättningsdatum i Steg 1
        $spDeployMap = @{}
        if ($cur.SharePointSiteURL) {
            try {
                $site = $cur.SharePointSiteURL.TrimEnd('/')
                $list = if ($cur.SharePointReleaseList) { $cur.SharePointReleaseList } else { "Releaselista" }
                $dStr = $dtpReleaseDate.Value.ToString("yyyy-MM-dd")
                $uri  = "$site/_api/web/lists/getbytitle('$([uri]::EscapeDataString($list))')/items?`$top=5000&`$filter=Drifts_x00e4_ttningsdatum ge datetime'${dStr}T00:00:00Z' and Drifts_x00e4_ttningsdatum le datetime'${dStr}T23:59:59Z'"
                $resp = Invoke-RestMethod -Uri $uri -Method Get -Headers @{ "Accept" = "application/json;odata=verbose" } -UseDefaultCredentials
                foreach ($item in $resp.d.results) {
                    $mpTitle = if ($item.MP_x0020_Namn) { $item.MP_x0020_Namn } else { $item.Title }
                    $spStat  = if ($item.Godk_x00e4_nd -eq $true -or $item.Status -eq "Godkänd") { "Ska driftsättas" } else { "EJ godkänd" }
                    if ($mpTitle) { $spDeployMap[$mpTitle.Trim()] = $spStat }
                }
            } catch {
                $lblMpStatus.Text = "Varning: Kunde inte läsa SharePoint-listan ($($_.Exception.Message)). Fortsätter..."
                [System.Windows.Forms.Application]::DoEvents()
            }
        }

        # 2. Hämta och jämför MPs från Källa (PreProd) & Mål (Prod) via SMLets
        try {
            $cutoff = $dtpMpFilter.Value.Date
            $ppMPs  = Get-SCManagementPack -ComputerName $ppSrv  | Where-Object { -not $_.Sealed -and $_.LastModified -ge $cutoff }
            $prdMPs = Get-SCManagementPack -ComputerName $prdSrv | Where-Object { -not $_.Sealed }
            $prdMap = @{}; foreach ($m in $prdMPs) { $prdMap[$m.Name] = $m }

            $progMp.Maximum = [Math]::Max(1, $ppMPs.Count)
            foreach ($pp in $ppMPs) {
                $progMp.Value++
                $lblMpStatus.Text = "Jämför $($pp.Name)..."
                [System.Windows.Forms.Application]::DoEvents()

                $prd = $prdMap[$pp.Name]
                $spStatus = if ($spDeployMap.ContainsKey($pp.Name)) { $spDeployMap[$pp.Name] } elseif ($spDeployMap.ContainsKey($pp.DisplayName)) { $spDeployMap[$pp.DisplayName] } else { "" }

                if (-not $prd) {
                    [void]$dtMp.Rows.Add($pp.DisplayName, $pp.Name, [DBNull]::Value, "New", $pp.LastModified, $spStatus, $pp.Id.ToString(), "")
                } else {
                    $diffSec = ($pp.LastModified - $prd.LastModified).TotalSeconds
                    $st = if ([Math]::Abs($diffSec) -le 2) { "Equal" } elseif ($diffSec -gt 2) { "PreProd" } else { "Warning" }
                    if ($st -ne "Equal") {
                        $x1 = & $GetMPXmlSafe $pp $ppSrv; $x2 = & $GetMPXmlSafe $prd $prdSrv
                        if ($x1 -and $x2 -and ($x1 -eq $x2)) { $st = "Equal" }
                    }
                    [void]$dtMp.Rows.Add($pp.DisplayName, $pp.Name, $prd.LastModified, $st, $pp.LastModified, $spStatus, $pp.Id.ToString(), $prd.Id.ToString())
                }
            }
            & $ApplyMpFilters
            $lblMpStatus.Text = "Klart! Hittade $($ppMPs.Count) ändrade unsealed MPs sedan $($cutoff.ToString('yyyy-MM-dd'))."
        } catch {
            [System.Windows.Forms.MessageBox]::Show("Fel vid SMLets-hämtning: $_", "Fel")
            $lblMpStatus.Text = "Fel vid jämförelse."
        } finally {
            $progMp.Visible = $false; $btnLoadMp.Enabled = $true
        }
    }.GetNewClosure())

    $btnExportMp.Add_Click({
        if ($dgvMp.SelectedRows.Count -eq 0) { [System.Windows.Forms.MessageBox]::Show("Markera minst en MP i listan först.", "Ingen vald"); return }
        $cur = Get-ItemProperty -Path $regReleasePath -ErrorAction SilentlyContinue
        $ppSrv   = ((Get-ItemProperty "HKCU:\Software\KrimsonTools\Settings\MiljoProfiler\$($cur.PreProdProfile)" -ErrorAction SilentlyContinue).SCSM_Server -split ',').Trim()
        $expRoot = $cur.ReleaseExportDestUNC
        $selDate = $dtpReleaseDate.Value.ToString("yyyy-MM-dd")

        if (-not $expRoot) {
            $fbd = New-Object System.Windows.Forms.FolderBrowserDialog
            if ($fbd.ShowDialog() -ne "OK") { return }
            $targetDir = $fbd.SelectedPath
        } else {
            $targetDir = Join-Path $expRoot $selDate
            if (Test-Path $targetDir) {
                $c = 1
                while (Test-Path (Join-Path $expRoot "${selDate}_$c")) { $c++ }
                $targetDir = Join-Path $expRoot "${selDate}_$c"
            }
            New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
        }

        $count = 0
        foreach ($row in $dgvMp.SelectedRows) {
            $dr = $row.DataBoundItem.Row
            $lblMpStatus.Text = "Exporterar $($dr['Name'])..."
            [System.Windows.Forms.Application]::DoEvents()
            Get-SCManagementPack -Id $dr["PP_ID"] -ComputerName $ppSrv | Export-SCManagementPack -Path $targetDir -ComputerName $ppSrv
            $count++
        }
        $lblMpStatus.Text = "Exporterade $count MPs till $targetDir"
        if ($Global:statusLabel) { $Global:statusLabel.Text = "Exporterade $count MPs till $targetDir" }
        [System.Windows.Forms.MessageBox]::Show("Exporterade $count Management Packs till:`n$targetDir", "Export slutförd")
    }.GetNewClosure())

}
