# =========================================================================================
# ZON 0: ISOLERING OCH MILJÖSÄKRING (Körs absolut först)
# =========================================================================================

function Initialize-KrimsonEnvironment {
    [CmdletBinding()]
    param()

    Write-Host "[*] Initierar isolerad Krimson-miljö..." -ForegroundColor Cyan

    # Säkraste sättet att hitta skriptets mapp (fungerar även vid framtida kompilering)
    $ScriptRoot = $PSScriptRoot
    if ([string]::IsNullOrEmpty($ScriptRoot)) { 
        $ScriptRoot = Get-Location 
    }

    # Definiera absoluta sökvägar till dina lokala resurser
    $LocalLibsPath = Join-Path $ScriptRoot "SMLets"
    $LocalSMLetsPath = $LocalLibsPath
    $TargetModule = Join-Path $LocalSMLetsPath "SMLets.psd1"

    # 1. Tvinga laddning av dina specifika Service Manager DLL-filer
    $RequiredDlls = @(
        "Microsoft.EnterpriseManagement.Core.dll",
        "Microsoft.EnterpriseManagement.ServiceManager.dll"
    )

    foreach ($DllName in $RequiredDlls) {
        $TargetDll = Join-Path $LocalLibsPath $DllName
        if (Test-Path $TargetDll) {
            try {
                # LoadFrom tvingar processen att läsa DINA lokala filer före Windows globala GAC
                [System.Reflection.Assembly]::LoadFrom($TargetDll) | Out-Null
                Write-Host " [✓] Framgång: Lokala $DllName har laddats." -ForegroundColor Green
            }
            catch {
                Write-Error "Kunde inte läsa $DllName trots att den finns: $_"
                return $false
            }
        } else {
            Write-Warning " [X] Kritisk brist: Hittade inte lokala $DllName på: $TargetDll"
            return $false
        }
    }


    # =========================================================================================
    # 2. Isolera och tvinga laddning av din lokala SMLets-modul
    # =========================================================================================
    if (Test-Path $TargetModule) {
        if (Get-Module -Name SMLets) { 
            Write-Host " [-] Hittade en aktiv SMLets-modul i sessionen. Laddar ur den..." -ForegroundColor Yellow
            Remove-Module -Name SMLets -Force -ErrorAction SilentlyContinue 
        }
        
        try {
            # --- ÖVERLISTA SMLETS (LÖSNINGEN PÅ FELET) ---
            # Vi skapar de globala variabler som SMLets internt försöker bygga via registret.
            # Genom att peka dessa direkt till din lokala SMLets-mapp slipper modulen leta i HKLM-registret!
            $Global:SMDIR   = $LocalSMLetsPath
            $Global:SMDLL   = $LocalSMLetsPath
            $Global:SMLets_OOB = $true # Berättar för vissa versioner av SMLets att den körs fristående

            # Importera modulen via dess absoluta sökväg.
            Import-Module $TargetModule -Force -ErrorAction Stop | Out-Null
            Write-Host " [✓] Framgång: Din lokala SMLets-modul har laddats isolerat." -ForegroundColor Green
        }
        catch {
            Write-Error "Kunde inte initiera SMLets-modulen: $_"
            return $false
        }
    } else {
        Write-Warning " [X] Kritisk brist: Hittade inte din lokala SMLets-modul på: $TargetModule"
        return $false
    }


    return $true
}

# --- ANROP AV MILJÖSÄKRINGEN ---
# Detta måste ligga UNDER funktionsdefinitionen, annars vet inte PowerShell vad den ska köra!
if (-not (Initialize-KrimsonEnvironment)) {
    Write-Host " [X] Miljöinitieringen misslyckades. Skriptet avbryts av säkerhetsskäl." -ForegroundColor Red
    Exit
}


# =========================================================================================
# ZON 1: CENTRAL MENY-KONFIGURATION (Här fortsätter ditt skript...)
# =========================================================================================

# Här lägger du till nya rader i framtiden om du vill utöka menyn. 
# TargetFunction MÅSTE matcha namnet på den funktion som ritar upp just den skärmen.

$Global:MenuConfig = @(
    [PSCustomObject]@{ MainMenu = 'Daily';     SubMenu = 'Ärenden';       TargetFunction = 'Create-FormArenden';           StatusText = 'Daily - Daglig hantering av ärenden' }
    [PSCustomObject]@{ MainMenu = 'Release';   SubMenu = 'Förberedelse ';  TargetFunction = 'Create-FormForberedelseSteg1'; StatusText = 'Release - Förberedelse steg för steg' }
    [PSCustomObject]@{ MainMenu = 'Release';   SubMenu = 'Exportera';  TargetFunction = 'Create-FormExportera'; StatusText = 'Release - Export Managemenpacks' }
    [PSCustomObject]@{ MainMenu = 'Release';   SubMenu = 'Importera';  TargetFunction = 'Create-FormImportera'; StatusText = 'Release - Import Managemenpacks' }
    [PSCustomObject]@{ MainMenu = 'Statistik'; SubMenu = 'Tele2';         TargetFunction = 'Create-FormTele2';            StatusText = 'Statistik - Analysera Tele2-data' }
    [PSCustomObject]@{ MainMenu = 'Tools';     SubMenu = 'Kontakter';     TargetFunction = 'Create-FormKontakter';         StatusText = 'Tools - Hantera interna kontakter' }
    [PSCustomObject]@{ MainMenu = 'Tools';     SubMenu = 'Skapa MP';      TargetFunction = 'Create-FormSkapaMP';           StatusText = 'Tools - Skapa nytt Management Pack' }
)

$Global:MatrixReleaseBoxes = @{}
$Global:RegPathBase = "HKCU:\Software\KrimsonTools\Settings"
$Global:RegPath     = "$Global:RegPathBase\MiljoProfiler"

# Global behållare för att hålla reda på de dynamiska undermenypanelerna
$Global:SubMenuPanels = @{}

# =========================================================================================
# ZON 2: NAVIGATIONS- OCH FÖNSTERLOGIK (Hanterar skärmbyten)
# =========================================================================================

# =========================================================================================
# ASYNKRON RUNSPACE-MOTOR FÖR SCSM-ANROP
# =========================================================================================

function Invoke-SCSMTaskAsynchronous {
    param(
        [ScriptBlock]$ScriptBlock,
        [HashTable]$ArgumentList,
        [ScriptBlock]$OnComplete
    )

    Write-KrimsonLog "Startar asynkron SCSM-uppgift i bakgrunden..."

    # 1. Skapa en ny isolerad PowerShell-instans för bakgrundstråden
    $PowerShell = [PowerShell]::Create()
    
    # 2. Skicka med skriptblocket och argumenten
    [void]$PowerShell.AddScript($ScriptBlock)
    if ($ArgumentList) {
        [void]$PowerShell.AddArgument($ArgumentList)
    }

    # 3. Starta tråden asynkront
    $AsyncResult = $PowerShell.BeginInvoke()

    # 4. Starta en WinForms-timer som kollar när tråden är klar utan att frysa GUI
    $Timer = New-Object System.Windows.Forms.Timer
    $Timer.Interval = 200 # Kolla 5 gånger i sekunden
    
    $Timer.Add_Tick({
        if ($AsyncResult.IsCompleted) {
            $Timer.Stop()
            $Timer.Dispose()
            
            # Hämta datan som bakgrundstråden producerade
            $Data = $PowerShell.EndInvoke($AsyncResult)
            
            # Stäng ner tråden säkert för att förhindra minnesläckor
            $PowerShell.Dispose()
            
            Write-KrimsonLog "Bakgrundsfrågan mot SCSM slutfördes framgångsrikt."
            
            # Kör OnComplete-blocket i huvudtråden och skicka med datan
            if ($OnComplete) {
                & $OnComplete $Data
            }
        }
    })
    
    $Timer.Start()
}

# Funktion för att dölja alla undermenyer och återställa knappfärger i sidomenyn
function Close-AllSubMenus {
    foreach ($Key in $Global:SubMenuPanels.Keys) {
        $Global:SubMenuPanels[$Key].Visible = $false
    }
    
    # Återställ textfärgen till vit på ALLA huvudknappar i sidomenyn
    if ($Global:panelSideMenu) {
        foreach ($Control in $Global:panelSideMenu.Controls) {
            if ($Control.Name -like "btnMain_*") {
                $Control.ForeColor = [System.Drawing.Color]::White
            }
        }
    }
}

# Funktion för att dynamiskt ladda en ny skärm i högerpanelen (panelChildForm)
function Invoke-Screen {
    param(
        [string]$TargetFunction,
        [string]$TitleLeft,
        [string]$TitleRight
    )
    
    # --- REGISTERMINNE: SPARA AKTIV SKÄRM UNIVERSUELLT I REGISTRET ---
    $RegPath = "HKCU:\Software\KrimsonTools"
    if ($TargetFunction -and $TargetFunction -notmatch "Create-FormLogView") {
        # Vi blockerar 'Create-FormSettings' från att sparas om fönstret inte har visats än (ShowDialog)
        if ($TargetFunction -ne "Create-FormSettings" -or ($Global:formMain -and $Global:formMain.Visible)) {
            if (-not (Test-Path $RegPath)) { [void](New-Item -Path $RegPath -Force) }
            Set-ItemProperty -Path $RegPath -Name "LastActiveScreen" -Value $TargetFunction -Force
            Set-ItemProperty -Path $RegPath -Name "LastActiveScreenTitle" -Value $TitleLeft -Force
        }
    }

    # #1. SPARA INSTÄLLNINGARNA FÖRST (om användaren lämnar inställningsvyn)
    Save-KrimsonSettings
    $Global:SettingsIsOpen = $false

    # #2. Rensa och frigör minnet från alla gamla kontroller så att inte ISE hänger sig
    if ($Global:panelChildForm) {
        while ($Global:panelChildForm.Controls.Count -gt 0) {
            $oldControl = $Global:panelChildForm.Controls[0]
            $Global:panelChildForm.Controls.Remove($oldControl)
            $oldControl.Dispose()
        }
    }

    # #3. Anropa funktionen dynamiskt baserat på namnet i strängen (t.ex. 'Create-FormArenden')
    if (Get-Command $TargetFunction -ErrorAction SilentlyContinue) {
        Write-Host "[*] Laddar vy: $TargetFunction" -ForegroundColor Green
        
        # --- UNIVERSUELL REGISTERLAGRING ---
        # Vi sparar ENDAST i registret OM funktionen faktiskt existerar och körs igång!
        # Vi blockerar även 'Create-FormLogView' och tysta uppstarter (när fönstret inte syns än)
        $RegPath = "HKCU:\Software\KrimsonTools"
        if ($TargetFunction -notmatch "Create-FormLogView") {
            if ($TargetFunction -ne "Create-FormSettings" -or ($Global:formMain -and $Global:formMain.Visible)) {
                if (-not (Test-Path $RegPath)) { [void](New-Item -Path $RegPath -Force) }
                Set-ItemProperty -Path $RegPath -Name "LastActiveScreen" -Value $TargetFunction -Force
                Set-ItemProperty -Path $RegPath -Name "LastActiveScreenTitle" -Value $TitleLeft -Force
            }
        }

        # Kör själva skärmfunktionen nu när historiken är säkrad
        & $TargetFunction

        # #4. Uppdatera rubriktexterna högst upp i gränssnittet
        if ($Global:labelPanelTopLeft) { $Global:labelPanelTopLeft.Text = $TitleLeft }
        if ($Global:labelPanelTopRight) { $Global:labelPanelTopRight.Text = $TitleRight }

    } else {
        Write-Host "[X] Fel: Funktionen '$TargetFunction' kunde inte hittas i skriptet!" -ForegroundColor Red
        
        # --- BLANK SKÄRM-SÄKRING ---
        # Om användaren klickar på en meny som inte är färdigbyggd än (eller rensar skärmen),
        # så nollställer vi registret direkt! Då fattar logg-funktionen att den ska gå tillbaka
        # till en ren, blank skärm istället för att hoppa till Settings!
        $RegPath = "HKCU:\Software\KrimsonTools"
        if (Test-Path $RegPath) {
            Set-ItemProperty -Path $RegPath -Name "LastActiveScreen" -Value "" -Force
            Set-ItemProperty -Path $RegPath -Name "LastActiveScreenTitle" -Value "" -Force
        }
        
        if ($Global:labelPanelTopLeft) { $Global:labelPanelTopLeft.Text = $TitleLeft }
        if ($Global:labelPanelTopRight) { $Global:labelPanelTopRight.Text = $TitleRight }
    }
}

# =========================================================================================
# ZON 3: DEN DYNAMISKA MENYBYGGAREN (Sätter ihop sidomenyn med rätt färger & statusbar)
# =========================================================================================
function Build-DynamicMenu {
    # 🛠️ 1. Lägg till parametern här så funktionen kan ta emot behållaren från Create-FormMain
    param($ParentContainer) 
    
    # 🛠️ 2. Ändra till variabeln från parametern här!
    $Global:panelSideMenu = $ParentContainer

    # --- DYNAMISK BREDDBERÄKNING ---
    $MinBredd = 180
    $MaxBredd = 300
    $OptimalBredd = $MinBredd

    # Mät texten på alla huvud- och undermenyer
    foreach ($Item in $Global:MenuConfig) {
        $Font = New-Object System.Drawing.Font("Verdana", 14)
        $BreddHuvud = [System.Windows.Forms.TextRenderer]::MeasureText($Item.MainMenu, $Font).Width + 20
        $BreddUnder = [System.Windows.Forms.TextRenderer]::MeasureText($Item.SubMenu, $Font).Width + 30
        
        if ($BreddHuvud -gt $OptimalBredd) { $OptimalBredd = $BreddHuvud }
        if ($BreddUnder -gt $OptimalBredd) { $OptimalBredd = $BreddUnder }
    }

    # Håll bredden inom dina gränser
    if ($OptimalBredd -gt $MaxBredd) { $OptimalBredd = $MaxBredd }

    # Sätt den nya dynamiska bredden på sidomenyn
    $panelSideMenu.Width = $OptimalBredd
    $panelLeftContainer.Width = $OptimalBredd

    # Gruppera menykonfigurationen per huvudmeny för att rita dem i ordning
    $MainMenus = $Global:MenuConfig | Select-Object -ExpandProperty MainMenu -Unique

    # Vi ritar upp menyerna nerifrån och upp (eller sätter en fast startposition)
    $Global:MenuStartTop = 110
    $CurrentTop = $Global:MenuStartTop

    foreach ($MainMenu in $MainMenus) {
        # --- 1. SKAPA HUVUDKNAPP ---
        $btnMainMenu = New-Object System.Windows.Forms.Button
        $btnMainMenu.Name = "btnMain_$MainMenu"
        $btnMainMenu.Text = $MainMenu
        $btnMainMenu.Size = New-Object System.Drawing.Size($panelSideMenu.Width, 40)
        $btnMainMenu.Location = New-Object System.Drawing.Point(0, $CurrentTop)
        $btnMainMenu.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
        $btnMainMenu.FlatAppearance.BorderSize = 0
        $btnMainMenu.TabStop = $false
        $btnMainMenu.FlatAppearance.MouseOverBackColor = [System.Drawing.Color]::FromArgb(45, 45, 60)
        $btnMainMenu.ForeColor = [System.Drawing.Color]::White
        $btnMainMenu.Font = New-Object System.Drawing.Font("Verdana", 14)
        $btnMainMenu.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
        $btnMainMenu.Padding = New-Object System.Windows.Forms.Padding(15, 0, 0, 0)
        $btnMainMenu.BackColor = [System.Drawing.Color]::FromArgb(20, 30, 105)

        # Spara texten som ska visas i statusraden på knappen via .Tag
        if ($MainMenu -eq 'Daily') { $btnMainMenu.Tag = "Daily - Dagliga rutiner" }
        elseif ($MainMenu -eq 'Release') { $btnMainMenu.Tag = "Release - Driftsättning" }
        elseif ($MainMenu -eq 'Statistik') { $btnMainMenu.Tag = "Statistik - Analysera och presentera data" }
        elseif ($MainMenu -eq 'Tools') { $btnMainMenu.Tag = "Tools - Diverse verktyg" }

        # Hover-effekter för Huvudknappen kopplat till den Orangea Statusraden
        $btnMainMenu.Add_MouseEnter({
            if ($Global:toolStripStatusLabelLeft) {
                $Global:toolStripStatusLabelLeft.Text = $this.Tag
            }
        })
        $btnMainMenu.Add_MouseLeave({
            if ($Global:toolStripStatusLabelLeft) {
                $Global:toolStripStatusLabelLeft.Text = "Redo"
            }
        })

        $panelSideMenu.Controls.Add($btnMainMenu)

        # --- 2. SKAPA UNDERMENYPANEL (Behållare för underknappar) ---
        $panelSubMenu = New-Object System.Windows.Forms.Panel
        $panelSubMenu.Name = "panelSubMenu_$MainMenu"
        $panelSubMenu.Width = $panelSideMenu.Width
        $panelSubMenu.BackColor = [System.Drawing.Color]::FromArgb(20, 30, 105)
        $panelSubMenu.Visible = $false # Dold som standard
        
        # Spara panelen i vår globala lista för att lätt kunna stänga den sen
        $Global:SubMenuPanels[$panelSubMenu.Name] = $panelSubMenu

        # Hämta alla undermenyer som tillhör denna huvudmeny
        $SubItems = $Global:MenuConfig | Where-Object { $_.MainMenu -eq $MainMenu }
        $SubTop = 0

        foreach ($Item in $SubItems) {
            $btnSubMenu = New-Object System.Windows.Forms.Button
            $btnSubMenu.Text = $Item.SubMenu
            $btnSubMenu.Size = New-Object System.Drawing.Size($panelSideMenu.Width, 40)
            $btnSubMenu.Location = New-Object System.Drawing.Point(0, $SubTop)
            $btnSubMenu.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
            $btnSubMenu.FlatAppearance.BorderSize = 0
            $btnSubMenu.TabStop = $false
            $btnSubMenu.ForeColor = [System.Drawing.Color]::FromArgb(180, 180, 190)
            $btnSubMenu.Font = New-Object System.Drawing.Font("Verdana", 14)
            $btnSubMenu.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
            $btnSubMenu.Padding = New-Object System.Windows.Forms.Padding(30, 0, 0, 0)

            # Spara information på knappen så händelserna vet vad de ska göra
            $btnSubMenu.Tag = $Item

            # Hover-effekt för underknappar (Ändrar bakgrundsfärg och skriver till statusraden)
            $btnSubMenu.Add_MouseEnter({
                $this.BackColor = [System.Drawing.Color]::FromArgb(43, 43, 60)
                if ($Global:toolStripStatusLabelLeft) {
                    $Global:toolStripStatusLabelLeft.Text = $this.Tag.StatusText
                }
            })
            $btnSubMenu.Add_MouseLeave({
                $this.BackColor = [System.Drawing.Color]::FromArgb(20, 30, 105)
                if ($Global:toolStripStatusLabelLeft) {
                    $Global:toolStripStatusLabelLeft.Text = "Redo"
                }
            })

            # Klick-händelse för undermenyn
            $btnSubMenu.Add_Click({
                # Starta den dynamiska skärmen!
                $this.Parent.Focus()
                $Data = $this.Tag
                Invoke-Screen -TargetFunction $Data.TargetFunction -TitleLeft $Data.MainMenu -TitleRight $Data.SubMenu
            })

            $panelSubMenu.Controls.Add($btnSubMenu)
            $SubTop += 40
        }

        # Sätt höjden på panelen baserat på hur många knappar den har
        $panelSubMenu.Tag = $SubTop # Sparar den beräknade höjden för klick-händelsen!
        $panelSubMenu.Height = 0   # Tvingar panelen att starta helt stängd (platt)
        
        # 1. Placera undermenyn precis där vi står just nu
        $panelSubMenu.Location = New-Object System.Drawing.Point(0, $CurrentTop)

        # 2. Öka startpositionen för NÄSTA huvudmeny med huvudknappens höjd (35 pixlar)
        $CurrentTop += 40

        # 3. Lägg till undermenyn i sidopanelen
        $panelSideMenu.Controls.Add($panelSubMenu)

        # Klick-händelse för huvudmenyn (Öppna/stäng undermenyn och gör texten Orange!)
        $btnMainMenu.Add_Click({
            $this.Parent.Focus()
            # Hämta ut "Daily", "Release" osv. genom att ta bort "btnMain_" från knappens namn
            $CleanName = $this.Name.Replace("btnMain_", "")
            $TargetPanelName = "panelSubMenu_${CleanName}"
            $TargetPanel = $Global:SubMenuPanels[$TargetPanelName]

            if ($null -ne $TargetPanel -and $TargetPanel.Visible) {
                $TargetPanel.Visible = $false
                $TargetPanel.Height = 0
                $this.ForeColor = [System.Drawing.Color]::White
            } else {
                # Stäng alla andra först
                Close-AllSubMenus
                # Öppna denna och gör texten KRIMSON ORANGE
                $TargetPanel.Visible = $true
                $TargetPanel.Height = $TargetPanel.Controls.Count * 40
                $this.ForeColor = [System.Drawing.Color]::FromArgb(255, 180, 0)
            }
            # Uppdatera layouten (flyttar ner efterföljande knappar automatiskt)
            Refresh-MenuLayout
        })
    }
}

# =========================================================================================
# ZON 3 HELP: REFRESH LAYOUT (Styr flytten av knappar helt blint utan bredd-beroende)
# =========================================================================================
function Refresh-MenuLayout {
    $CurrentTop = $Global:MenuStartTop
    $MenuOrder = @("Daily", "Release", "Statistik", "Tools")
    
    foreach ($MenuName in $MenuOrder) {
        $BtnName = "btnMain_$MenuName"
        $MainMenuBtn = $Global:panelSideMenu.Controls[$BtnName]
        if ($MainMenuBtn) {
            $MainMenuBtn.Location = New-Object System.Drawing.Point(0, $CurrentTop)
            $CurrentTop += 40
        }
        
        $SubPanelName = "panelSubMenu_$MenuName"
        $SubPanel = $Global:SubMenuPanels[$SubPanelName]
        if ($SubPanel -and $SubPanel.Visible) {
            $SubPanel.Location = New-Object System.Drawing.Point(0, $CurrentTop)
            $CurrentTop += $SubPanel.Height
        }
    }
}

# =========================================================================================
# ZON 4: REGISTERHANTERING, LOGGNINGSFUNKTION, INSTÄLLNINGAR OCH HUVUDFÖNSTER (WinForms)
# =========================================================================================

$Global:GlobalRegPath = "HKCU:\Software\KrimsonTools\Settings\Global"
$Global:LogBuffer = New-Object "System.Text.StringBuilder"

# Läs in globala logginställningar från registret (Standard: Av, log.txt bredvid skriptet)
$Global:LogEnabled = $false
$Global:LogFilePath = Join-Path $PSScriptRoot "KrimsonTools_Log.txt"

if (Test-Path $Global:GlobalRegPath) {
    $RegLog = Get-ItemProperty -Path $Global:GlobalRegPath -ErrorAction SilentlyContinue
    if ($null -ne $RegLog) {
        if ($RegLog.LogEnabled) { $Global:LogEnabled = [System.Convert]::ToBoolean($RegLog.LogEnabled) }
        if ($RegLog.LogFilePath) { $Global:LogFilePath = $RegLog.LogFilePath }
    }
}

function write-KrimsonLog {
    param (
        [string]$Message
    )

    # FIX: Stora MM för månad, små mm för minuter
    $timeStamp = [DateTime]::Now.ToString("yyyy-MM-dd HH:mm:ss")
    $LogLine = "[$timeStamp] $Message"

    # Skriv till internminnes-buffer (så att loggvisaren kan läsa den blixtsnabbt)
    [void]$Global:LogBuffer.AppendLine($LogLine)

    # Om loggvisaren är öppen live just nu, uppdatera dess textruta direkt
    if ($Global:txtLogView -and $Global:txtLogView.IsDisposed -eq $false) {
        $Global:txtLogView.AppendText($LogLine + [Environment]::NewLine)
    }

    # FIX: Om loggning är aktiverad till fil, kontrollera och skapa mappen om den saknas, skriv sedan säkert med Add-Content
    if ($Global:LogEnabled -eq $true -and -not [string]::IsNullOrWhiteSpace($Global:LogFilePath)) {
        try {
            $LogMapp = Split-Path -Path $Global:LogFilePath
            if (-not (Test-Path $LogMapp)) { New-Item -ItemType Directory -Path $LogMapp -Force | Out-Null }
            Add-Content -Path $Global:LogFilePath -Value $LogLine -Encoding Utf8 -ErrorAction SilentlyContinue
        } catch {
            # Svälj eventuella skrivfel så att inte hela verktyget låser sig vid rättighetsproblem
        }
    }
}

$Global:RegPath = "HKCU:\Software\KrimsonTools\Settings\MiljoProfiler"

# Funktion för att läsa in Miljöprofiler från registret till dropdown
function Refresh-ProfileDropdown {
    $Global:comboEnvironments.Items.Clear()
    
    # Läs ENDAST in de profiler som användaren faktiskt har skapat i registret
    if (Test-Path $Global:RegPath) {
        $SubKeys = Get-ChildItem -Path $Global:RegPath | Select-Object -ExpandProperty PSChildName
        foreach ($Key in $SubKeys) {
            [void]$Global:comboEnvironments.Items.Add($Key)
        }
    }
    
    # Om inga profiler existerar alls i registret ännu
    if ($Global:comboEnvironments.Items.Count -eq 0) {
        $Global:comboEnvironments.SelectedIndex = -1
        $Global:comboEnvironments.Text = "-- Inga profiler skapade --"
    } else {
        $Global:comboEnvironments.SelectedIndex = -1
        $Global:comboEnvironments.Text = "Välj Miljöprofil"
    }
}

function Save-KrimsonSettings {
    # 1. Hämta namnet på den aktiva profilen just nu
    $AktivProfil = $Global:CurrentActiveProfileOnScreen
    
    # 1. Grundläggande kontroller för tomma eller ogiltiga namn
        if ($Global:IsDeleting -or [string]::IsNullOrWhiteSpace($AktivProfil) -or [string]::IsNullOrWhiteSpace($Global:CurrentActiveProfileOnScreen) -or $AktivProfil -eq "Välj Miljöprofil" -or $AktivProfil -eq "-- Inga profiler skapade --") { return }

    # 2. TOTALSPÄRR: Om profilen inte finns kvar i dropdown-listan, TILLÅT INTE att den återskapas!
    if ($Global:comboEnvironments -and (-not $Global:comboEnvironments.Items.Contains($AktivProfil) -or -not $Global:comboEnvironments.Items.Contains($Global:CurrentActiveProfileOnScreen))) {
        return
    }

    # SÄKERHETSSPÄRR: Om textrutorna inte finns eller är stängda, AVBRYT direkt så vi inte raderar registret!
    if (-not $Global:MatrixTextBoxes -or $Global:MatrixTextBoxes.Count -eq 0) { return }
    
    # Kontrollera om den första rutan är borttagen ur minnet
    $FirstKey = ($Global:MatrixTextBoxes.Keys | Select-Object -First 1)
    if ($Global:MatrixTextBoxes[$FirstKey].IsDisposed) { return }

    # Säkra sökvägen i registret för profilen
    $ProfilPath = "$($Global:RegPath)\$AktivProfil"
    if (-not (Test-Path $ProfilPath)) { return }

    # Loopa igenom matrisen och spara alla profilfält
    foreach ($Key in $Global:MatrixTextBoxes.Keys) {
        if ($Global:MatrixTextBoxes[$Key] -and $Global:MatrixTextBoxes[$Key].IsDisposed -eq $false) {
            Set-ItemProperty -Path $ProfilPath -Name $Key -Value $Global:MatrixTextBoxes[$Key].Text -Force
        }
    }

    # #2. Spara de globala logginställningarna (om kontrollerna finns på skärmen)
    if ($Global:chkLogEnabled -and $Global:chkLogEnabled.IsDisposed -eq $false) {
        if (-not (Test-Path $Global:GlobalRegPath)) { New-Item -Path $Global:GlobalRegPath -Force | Out-Null }
        
        $StatusString = $Global:chkLogEnabled.Checked.ToString()
        Set-ItemProperty -Path $Global:GlobalRegPath -Name "LogEnabled" -Value $StatusString -Force
        Set-ItemProperty -Path $Global:GlobalRegPath -Name "LogFilePath" -Value $Global:txtLogFilePath.Text -Force

        # Uppdatera minnesvariablerna live
        $Global:LogEnabled = $Global:chkLogEnabled.Checked
        $Global:LogFilePath = $Global:txtLogFilePath.Text
    }

    # =========================================================================================
    # LIVE-UPPDATERING AV STATUSRADENS DROPDOWN NERE TILL HÖGER
    # =========================================================================================
    if ($Global:toolStripComboEnvironment) {
        $CurrentSelected = $Global:toolStripComboEnvironment.SelectedItem
        $Global:toolStripComboEnvironment.Items.Clear()
        
        if (Test-Path $Global:RegPath) {
            $Profiles = Get-ChildItem -Path $Global:RegPath | Select-Object -ExpandProperty PSChildName
            foreach ($P in $Profiles) {
                [void]$Global:toolStripComboEnvironment.Items.Add($P)
            }
        }
        
        if ($CurrentSelected -and $Global:toolStripComboEnvironment.Items.Contains($CurrentSelected)) {
            $Global:toolStripComboEnvironment.SelectedItem = $CurrentSelected
        } else {
            $Global:toolStripComboEnvironment.SelectedIndex = -1
            $Global:toolStripComboEnvironment.Text = "Välj Miljöprofil"
            
            if ($Global:toolStripComboEnvironment.Control) {
                $Global:toolStripComboEnvironment.Control.Refresh()
            }
        }
    }

    # # Spara globala release-inställningar till HKCU:\Software\KrimsonTools\Release
    $ReleaseRegPath = "$Global:RegPathBase\Release"
    if (-not (Test-Path $ReleaseRegPath)) {
        [void](New-Item -Path $ReleaseRegPath -Force)
    }

    foreach ($Key in $Global:MatrixReleaseBoxes.Keys) {
        if ($Global:MatrixReleaseBoxes[$Key] -and $Global:MatrixReleaseBoxes[$Key].IsDisposed -eq $false) {
            Set-ItemProperty -Path $ReleaseRegPath -Name $Key -Value $Global:MatrixReleaseBoxes[$Key].Text -Force
        }
    }

    Write-KrimsonLog "Autosave utfört: Inställningar för profilen '$AktivProfil' har sparats säkert."
}

function Load-KrimsonEnvironmentVariables {
    # 1. Hämta den aktiva miljöprofilen från statusradens dropdown
    $ActiveProfile = $Global:toolStripComboEnvironment.SelectedItem
    if ([string]::IsNullOrWhiteSpace($ActiveProfile) -or $ActiveProfile -eq "Välj Miljöprofil") {
        return
    }

    $ProfilPath = "$($Global:RegPath)\$ActiveProfile"
    if (Test-Path $ProfilPath) {
        $RegData = Get-ItemProperty -Path $ProfilPath -ErrorAction SilentlyContinue
        
        # 2. Läs in PRECIS ALLA variabler i helt rena globala namn baserat på ditt register!
        # SCSM-sektionen
        $Global:SCSMServer       = $RegData.SCSM_Server
        $Global:SCSMSQL          = $RegData.SCSM_SQL
        $Global:SCSMDB           = $RegData.SCSM_DB

        # Cireson-sektionen
        $Global:CiresonWeb       = $RegData.Cireson_Web
        $Global:CiresonSQL       = $RegData.Cireson_SQL
        $Global:CiresonDB        = $RegData.Cireson_DB
        $Global:CiresonCache     = $RegData.Cireson_Cache

        # Analytics-sektionen
        $Global:AnalyticsSQL     = $RegData.Analytics_SQL
        $Global:AnalyticsDB      = $RegData.Analytics_DB

        # DataWarehouse-sektionen
        $Global:DWServer         = $RegData.DW_Server
        $Global:DWSQL            = $RegData.DW_SQL
        $Global:DWRepoDB         = $RegData.DW_Repo_DB
        $Global:DWStageDB        = $RegData.DW_Stage_DB
        $Global:DWMartDB         = $RegData.DW_Mart_DB

        # Orchestrator-sektionen
        $Global:OrcServer        = $RegData.Orc_Server
        $Global:OrcSQL           = $RegData.Orc_SQL
        $Global:OrcDB            = $RegData.Orc_DB

        write-KrimsonLog "Samtliga miljövariabler inlästa i minnet för profil: '$ActiveProfile' (SCSM Server: $Global:SCSMServer)"
    }
}


# Funktion för att hämta inställningar från registret
function Get-KrimsonSettings {
    if (Test-Path $Global:GlobalRegPath) {
        $RegLog = Get-ItemProperty -Path $Global:GlobalRegPath -ErrorAction SilentlyContinue
        if ($null -ne $RegLog) {
            if ($RegLog.LogEnabled) { $Global:LogEnabled = [System.Convert]::ToBoolean($RegLog.LogEnabled) }
            if ($RegLog.LogFilePath) { $Global:LogFilePath = $RegLog.LogFilePath }
        }
    }
}

function Remove-KrimsonMemoryLeaks {
    Write-Host "[*] Rensar minne och tar bort kvarhängande kontroller..." -ForegroundColor Yellow
    
    # 1. Stäng och frigör huvudfönstret om det existerar
    if ($Global:formMain -and $Global:formMain.IsDisposed -eq $false) {
        $Global:formMain.Close()
        $Global:formMain.Dispose()
    }

    # 2. Loopa igenom och rensa kända paneler/kontroller i Script/Global scope
    $ControlsToDispose = @(
        $Global:panelChildForm, 
        $Global:panelSideMenu, 
        $Global:toolStripStatusLabelLeft,
        $Global:txtLogView,
        $Script:iconMs,
        $Script:ms
    )

    foreach ($Control in $ControlsToDispose) {
        if ($Control -and $Control.IsDisposed -eq $false) {
            $Control.Dispose()
        }
    }

    # Rensa ikonens Windows-koppling på ett säkert sätt
    if ($Global:formMain -and $Global:formMain.Icon) { $Global:formMain.Icon.Dispose() }

    # 4. Tvinga .NET Garbage Collector att omedelbart rensa RAM-minnet
    [System.GC]::Collect()
    [System.GC]::WaitForPendingFinalizers()
    
    Write-Host "[✓] Minnesstädning klar!" -ForegroundColor Green
}

# HUVUDFÖNSTER (Skapar själva grundskalet) 
function Create-FormMain {
    Remove-KrimsonMemoryLeaks

    $Global:PreviousActiveScreen = ""
    # Läs miljöval från registret direkt vid start
    Get-KrimsonSettings

    [void][System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")
    [void][System.Reflection.Assembly]::LoadWithPartialName("System.Drawing")

    $Global:logoBase64String = @"
iVBORw0KGgoAAAANSUhEUgAAAI0AAABMCAMAAABnNMSGAAAABGdBTUEAALGPC/xhBQAAAAFzUkdCAK7OHOkAAACWUExURUdwTP7y2f////7z3v////////////////nu2f///////////////////
/////////////+0AP////////20B/////+0AP+0AP////+0AP21DThCgf+0ANSkNlRek623zmtymjM1Z5iiwH6IsEVPiRMdaf////+0AOLs8SIqbf+2AMuSF8PN3YJkOHqErF5omoeRtYyWuUTQLd
QAAAAldFJOUwAE9wxO7XaJFSa34x0/M6vET2TOkNly65zQsfws/q3+j/w4XdSvOx2sAAAIT0lEQVRo3s2ai3qiOhCACeEqoNwF9Fitiquu7dn3f7kzl3Dxgu2e3Y92+hVCCMnPZGYyodW0WxFRtdS
+jYi0jL4Pjcy/E016OMy/DY5THg6H6ttMFNKk32amonL+TZxKOMsoStM8ipbyq+coyqtyfmCZl1W+FF/GsszLeQk2U6JPpXPAgRmLnK9hSecwdj4/VMsIaJZReSjzHA/j80jAKCMJWqkcLUcabQna
ibh+5PlaVjA3EjHKJUW/A0S/iIIg3RpTPSKaU/CF0yHXWhpRERwqrBzP4UXOKwHGYBwWKYgqwigo6P6IC1dVpvjuTgVmTKpS0Q9WzznQYIYxz0cLvWmkCS4sm5qbgsjTseaqUmYBZvOkMNZU5QceS
hnv48J8LN1E4MJLNA4w5rwppDeFciwnhzAHPpWr1WmgUI0VASm7Sku1WHaFql8zWr5D8SXCpRJ/7gp06zCah2tplUdC5nk6z/NIawptjVimY24i8lJqSwd1BBp4UJDg4eMtDdEhzSG1wpnJHxfKcr
x1c9mke8NSjZdUyPJDmjG3ENWHNOO51HZb/fORrLevXXxyXdxOCN/1hXRBHJ5GrOCT27ZQJX7EwUtsouGjVw006IhNc3H8WDbHVWs5lplN4WR4ZgEHkKwIaIjQLASesM6ACjfBEt6LTTxZpueZExh
czMwQx3ZCrInx4UCdtcX+M9LR2LUeYI+1bmhGTUI9+V49gUauWWd6beEIep3VNd6y6tqgB7PahDcRkzpDGm5aYKfQkfUHNFOzhveDTkJ7otdm0NIAQ+HREHGtF8xlITk8aNo60jU0BjTNatQWFv+E
xqa3pleSll7PREODVQkNAaPHZm33aWIPWzY0MfQBRX+A5ni5XI503O83l8tmmMbPqBdWsAxrz21oQCPGjEYrai/IcPSWRg9o8IYG8KYFzd1j3ZxPh81+czid9/vL6XRhxEc0YAl2N93UpaKB21MYx
kXGxE/qUPZoplRSNHjy2aQe6+Z8+qelOSiaR7qBkfiViAa67XQDGnEtpb6ZnNSJ06cBq7IbGgdQhXqfId2cL2cIdxc4DtNM0f5ESwPWAXbCNDSSgUY1RZuZ1Z7fp0ECqWjApQpsVQzr5nA6nYAGj0
90wzbMNNPCpMGYBrQWSgKhAWzSYWc3NKmKhho4Gc3lDc2x0U0nz3XDjglUoHzdEg0Nzo+A4gw9xtBozvo06EeKBkymMGLlDgO6+QxNAPaAo5BuhCozDalf4nyQWmJSYo8G78uJ8jkVO6fDdvMpGhy
lUMFFU0bENGym4OI+mUxAo/RoYCYzn2jgLWpQa01OdU8D69ENTW+luqEBa/SmisZhB2MaMmA0lwANiE25T4NHg2jAYhLDMGxyhDuay/l8vkkkzp2kN7GYAw77FJeZhqwFQ2BMgc+l4NungXFtolHe
xCekESAtzZm9qS+nTqobGhgGrI9pODAzTTtkQVpxaJHo00DjMEQapQ52KrjIJiANzfUsdUD8c0fDC5WKXaRtpikwDOMLezRlGJCdbg3HB2HxN5FGRWEMnX6TDNQf0NxnxnESYhiehoktgjCkTGaSF
NKZQYWwkxmG2VkIgokHXcMjQfuggbeg0komLuVLeA5ClquZGpaORkop1FkTXVlQBR+wXjWjEzdTNXyv60eoFlzdt+JhSUfaNfQ9fFhWQzROXBSW//dpPpltXQsEOZBk+j1owJ1McJ/J3/qrxPM9ww
c0GGqm7oSznb8hP5/K4o6GQqYq4CI4ayI/3RG9Vr0XEKKpEFfP38mPp/J2RzOdTeL2jOtV4CakG2lDMJ1ZpCVhYbmIXdE8g1JAxC7wRsB1xu/S/HtHg+oQKuPnNQoCKdZAjEfxYkERli9screAr3Q
Xnzavcuo/pHE481aBPuZ8y+YbegJEesybvyQB865Dlzd6XpJg0IX1bcId/B+adqY6E+BcF08um4zSFmL6vmXSJgXvSjdOAMcnGltKR/KizruWxzQvPbkm+Qk1jRWv+06NSoH8LnF486JyW6U0Wk4V
sgaJFepNaU+jtb+Iu53hnax6/vxyo5fWwY/b7gHuzG22jZ4veMOoaAyV/RGNcCnbuKbBXzFAsz52efHLw1kC2XRfTFTXfASCRPLurkdjtTSkKuOaBndZbW509/1m8wmaXe/DH2ul1VCbYjGNLGg72
dKQqoAmKWYz8HB8mNs/pnF2n6Dph2JJ+mCCgL54MBnSOEGh48eLjoYyzUDn3YHLNKSqxzTa+mOazbb/uZu8iV0KurR9P25mLYSNd+0FWo8mULoxsywLFQ2sJxMxQPO66NP8evsF3vT29tKn2TnXKy
XsqJr9PiyaHsSVQs2UzaGtoyG9IZIDwh6uCdysD9CIVY8GFqbFzx8v+/17j6bvUWoAn4wHbZQFFnGigdHQ8VsaSStq0GxQmIZ2FgM0nXI6muMVzer64zW+KXsJhtwCxKMNEqmrIBtqaUB5M3njU2x
M7RZq0Mnf39+P+yMc9/vF+3sDuXi9SSOgRzZcFQLZkpgmoA8Wisa3+SvcrW5wKxEP0cjVs0TruL5tDtvIgjdHHudZzf4zlOrzJBxN2yrUqoU0E8uyYkfRqG+A1kA+uXsGc5fXwVAZvbvaL+J8xL3o
NxPNGl5nuKLfejg1SgZptNfdb8Bolm6aOirFMHXqkc5OSHVyosMWfQZNTC+0XLY0Ey/1DGgyHfn9BLuIhzLA19XxIczmAYzmTEFcLjiqAtZtd0rJlY+VLjVpnpVTFokll9YvvBz+y46zfpCuH3fbx
/mweFBqy+LuBl2K2x6ebdHE62pzw7JYv37h/yZtV4suh9js1q9f979JrJ/tarcA2e3W26/4t6T/APFx2ILozLglAAAAAElFTkSuQmCC
"@

    # Binärsträng för applikationsikonen (Kriminalvårdens logotyp)
    $Global:iconBase64String = @"
AAABAAYAAAAAAAEAIAA9LgAAZgAAAICAAAABACAAKAgBAKMuAABAQAAAAQAgAChCAADLNgEAMDAAAAEAIACoJQAA83gBACAgAAABACAAqBAAAJueAQAQEAAAAQAgAGgEAABDrwEAiVBORw0KGgoAAAANSUhEUgAAAQAAAAEACAYAAABccqhmAAAuBElEQVR42u2dWYwk2XWe/3tjyz1rr16ml+nuWcghZ8jhSKSoEbULpmkLkiXbsGTZ0IP1ohe/GTBgw08G/GL7xYb9JAO2ARsCKJCWZEKQIQgQxWGTHJGcGc6wt+m1uvasyiUy1nv9cG5EZnVVdWV1VXVWVZwPGHRMVmTcG5Fxzz3n3HPOFTilXL14WY+7D8zp4fb9u2LcfTgK5Lg7wDDM+GABwDAFhgUAwxQYFgAMU2BYADBMgWEBwDAFhgUAwxQYFgAMU2BYADBMgWEBwDAFhgUAwxQYFgAMU2BYADBMgWEBwDAFhgUAwxQYFgAMU2BYADBMgWEBwDAFxh53B5jnj2NrZPWtSg79qzTQj+hYQ0CpcfeSeR6wACgI0hIQgob9T1zzUfFohP/mF1MAwHpX4L/9PxcA0A0kFtb51SgCbAIwTIFhMV9AqiWNWomKJnt2av4V8Bz6LEy4oHJRYAFQQK6dTTFVIxNgpuEDACwpMT9BDgEpgXvj7iTzXGATgGEKDGsABUEKCSnJCRhEAn447h4xxwEWAAXBsixYFil8nT5wKre5YfYNmwAMU2BYAygIr13oY36CvPu/+LqPZpm8//NN+rdRVvjK53oAgLvLDvoh6QjrXQurbWvc3WeOCBYABeHqfIiXzyUAgJ+8FqBZSbf8PVXA26+SgJiqKXzwgIKCtBYsAE4xbAIwTIFhDeAQyRxrxyWMxvNcuC6t7V+e6+LV830AgGtvD/SXAqiV6fPz0wpvf4KOhVC4+Xjcd8IcFSwADonj6FW3LAnHoZ+4VtGYqJLab+2g9wkBOBaJrqqncWaSjuvlcd8Fc5SwCcAwBebUagDPOiOPor7vde1R2n4eZkKSpAhDyvFV+8jvDWLgcYt62PafQ0eZsXFqBQADaK2htc7+Zx/fAxKzSKD28T3m5MECoCAoPSjyofVAHpgSAdAYfKY1FQih4+Po3WAOCxYATzD8uh/l3LefYfWs/YjjBHFMa/9fv17Ctz6iFYF/+nNtTJpswCwQKIglPnjYAADcXpT42rfp3PUuxwCcZtgJyDAFhjWAE4zI1QgBKUmWS6EgBc3ulgSkIP3BHhL1/VjCM9mAbQoNQBhL9M1ncQK4Nn2v7GrUSnS9VIncNEhSmWsmSrGf4KTCAuApHBfrd7d+ZNl9lmWhVq0AAEpWgJrTAQBMVBUale3e/xuPyii5WwdtkgIrm/RZP1I4O0mmQfYvAKx3JLoBtbncrSJKyDzo98Pc2cii4GTBJgDDFBjWAI4pUsq8im+zEudRemVXQQAQEphqkPx2rATNGjn7SnaMuhsAAOoVldf+G+bSXAr3iV8+VcB0nY6jRKDtb58bNnsSvskSXOkCUUoaQLuroczKQqtL7cWpwKa5RpwKhDEda2hWE44RLACOKbZtwbZpgL10to96mQb4C1MJpARsC/jsVRqMrp1iztT2K7saDRPTX3bVNlX/IPihRBhnacIdxCkdL7RqUFogSYG/uW0CiPoSP7hLGYWdwMKyyShUCoPYhF04yiAuZitsAjBMgWENYMy4tkbdzNj1ssJE1WTkzQSYqtGcdmkmQMU1nn2LdvWREmiUaa4sOSlm6uSssy0Nz+z2EyYC3ZBk/FrHRhDR8avng7wEeIbWyGf3bmDh0TpdZKqWYLZB2ocQyDWKqqcRG/9goxzlgUavnh+YAFfmYwBAq2djoVUCACxtAGtt+l7LLyMwjsQwiA4cdSjAWsB+YQEwZlxbY9oM3hemE1yeo8H25pUQl+ZoAE3VVO4DWGlbeHLVrexqzDTSbdfu9K08kOfHCx5aXfq5L89F8Jyt59PWYNK0YeNvPqY0wGtnwnwZsOKpXHAkKZAYE6AfRXmfJqr0r2PpvPT4asfFvVX6/L17Ejce0fdur9aw2SfBEEcxdHrw4buT+cBCYXfYBGCYAsMawHPkzCTN7mVX4/XLdDxTT/Dpi+S1r3gaVTPbKm1jvUuz43duCfh0CiqeznP3v/RaVuBjMMe1eg4erXsAgB98bOOjhyaUVwhk86OJDt6VVlfg2zfIBPh4SeKD+/SavPFiiIuz9OVmRaHqZDO8BWjSCL7/MbUthc5XGuoVjdkm3cDPfELhp1+h/t5fi9EJ6KR3bw0Ckb53b5qegVLwsxs/AMclnuM4wgLgOdLIbX2NT10k9f7MRIzPv7T9Jb+36mC1Q4Pwx48k1jr0GmerACVHo2TUcdsaCIB+JLG4QYPwxoKNd++QAJhtpigb+z3dIzO4HwncX6HvbfQEljdJUZxpprmPYrKabhE8AJkRD1a3v1KX5mJcmqW05LlmiqkamR/nppI8sKjrV9Dt0/F7j+m+01QBOLgAYHaHTQCGKTCsARwBrmvnsflvv9JGxaMZ77e/RCG6jqVxboo+i1NgvUvnfvjQzVXo28tVLLfp+Kde6uBTF0n1/jtvdeDZGkLoPMy3G1i4fouieH5wv4L/+zcTAIDVjRitNmkaL0wnODNhSoLtI8Hv8bqNG49M+O+mla82/P6XN3HZOCkvTMeAAJQS+I2f6tL3Wja++g55BG8tlfCH78wAAD553se1M2S6vHU1xLzp09//Yjf31n326scAgLYv8bXrZAZt9CzcWqTnobWG5vyDQ4EFwBEghMwFwEQ1RcPU4H/RDBhLAg1TlrsbSGz06GfY9CUerdPxwzUby206lq/Qjr4AcGYi2b6EB6Ddp3PXuw4etSgAx/cVAmPwSzHwFezHJg4TgbZRzZc2LARR5vkXSBUde46CEDQwZ81qhB8KRAn9faNn4c4SDd56KUbNo+eQpFG+utGopHmtwsvG7m91JRplupcokYPkJw4mPDTYBGCYAsMawCExU08xYZxbX3nLx5UzpJ5/8eUNVL3BbA+Qavv171LxjTtLHv7kXToOoxRBSOd+4eU+vvQqRcz81tttvDBNM3nm8EsVcHuRZse7yzb+8zdoht3oKrRa9L3hkNuJGnBmEuYa2/tvSeRVg2caKS7MUHtqaGOQ5U0bK5t0/n/6xgQmzfn/9rfXUC2RFpBdo1pS+Df/cB0A8O4dD3/07Sjv63dukLnyF++V81Lk//jnIkyawKef/eS6uUeBK/N0vLhh4/pNMil+8KCG67ebAADfD/K6h8z+YQFwWAhSswHAsXWubru2hmNvV9mzIJo4FQhMokycqNxDL4TOB7tt6S2e/ozMDE61yJf2kl1i7YUYrh+wyy2I/Fa2HOf9HlK94wS5iq93uMawyWFbGpbUeZ+zew8TAcdEH6ZK5PeePUcthp8j8udoS+SJUszBYAFwACw5qKXfKKt8eavqKZTMGrnGYKBm2XHdQOZ2tR+KfMBaUsMy9n3FGxTi2KmOv9YCfWOPh5HIB5VSz2dgxInIQ4fDWMK2SFh4TrahyGAgu/bgXkrOQJjpIWHQ9iWEKV7SM+HL0INr2JZG1VPmWaeYqpEfQcUKaZJpRWI/tU8ZsADYN0IA0ozIs5MxXj1H0St/67M+vvRJ8m7XSiqfrdq+hc0eqdD/7o9IB/dDib/+qDR0VbrGpbkYL52lF/vXPt/FW1fp8yxXYJg4Bb7xLqnES5sW7iw5z/U5vPegnM/2f/VRimpJw7F0rr5bUqNpzIHPvDjw9v/xd6v5IF1Yt/G4Rc/yP/5JDdKM9m6fzm1WUvz658nmaFZTvHSWnscvdjtY3lwGAPzvv6rh+k16lg9WnVwoMqPBTkCGKTCsAYxIZnO6jsZskwzuSzMJXj1PDqjZRpqbA0ojz5W/t2IjyHLoO6QJZP+fXTfL+5+sJbg4Mwi1za43bO76oYCGQD8U2OgZk6K/ixwXgEBWM0DkWYJ7mc9S7hxluAWtc9t/pS3QCwHP3vlcWyJX3ydrCvMTdLzWBXphZrqovAT53WXbPAOJu8vU6YqnMNccZDxm1zs/neDlHmlNYSLQMc+i1bXYHBgBFgAjIi16OafqKX7ldQp2eeNyiL/9ud62c7uBRGxe7D/86xpWjBf93TvetnMdx0atRvX8PnU5wK9/ga59djLJPeTDPFp3kCqyk9+/T6sAu6m9UggIo1Y3qgKzTTq299D7PBv5YFva2DlqaLgQ6DsfSTi2Rq0E/MYXtp9bLak8x+GNyzEsSddc6TjY8KlPURzn3sT/9c0aABKCQUTfe+lchN80QUaNssrDqr/yOR9vfyLIn/WCiaP4yw/KiJODmgOnX4KwCcAwBYY1gBHJQk9tCcxN0GeeI9AyDr5OX6IX0vG9ZSuvqXd70cm9/3sRpxa6Aam8/Wighrd6DuLUJMrcs2npMBLYMG3H6d7XXmwBVY9mxJfPStTNsmFWaCRVAmtd0igertt43DL1/vp7932p7cGWQNlT+N5tcsiVHIVz00Zll4PlvL0SkYafdRABHz0ircmPZF7zYKIKTNezlQSFiklyqnkadaNpsCtwNFgAjEim8rqWxqU5er0qnsxV5PurLhbWaQB980MXC+s0cO4uO/l6+V4EsYUNnwZQs6Lg2fQy310poxtkqq2FKKFluOXN0YP6P16S6BhB9PpFC5M16tN8M2tb4scLtKpwe1Hi9uLoOwPdWy1DCAHPVviz75M5M11P83Tl4TqFo6jl2bP2Q+Dbt6gwye0lB6tt6v/L5zU+fYmud2nGx0yd/DATVZX7VyRLgJFgE4BhCgxrACNgSeDa2SyfXWHDlL5ebFno9mmGurPk4sEqzZqLGxZ8E8yS7hGYkyQpfJ9mykcrCb5/h7632XMxU6fZ9/pNJ1f3P3xoI0kHG30+Dcqao+OHqxbWzAz6Vx+W89iCT7xAanUvFPjmh/Q6LG/KXLvIynk/jWz/wTQBvvVj0mAma2qoTJjG2Ulq7/37Lm4s0HPa6IqBM3Enf5seaAMdX+DHj1zTP+DDR3TKZy5pXJimvqZaokEKCGabKcKYdjLKQplH5/Q7/zJYAIyAlDqPja+XNbqmRsXKUADOzccO7pklK2mJfNkw1U8fqUopBEFkrpfi9qIJr9UOOn16cd+/b+fq7/0VZyQ7mq6BfMvf4UHw/n0PFbOMVnLpvjp9ge9/TOdQhuLogyYxe4knoJRmgNTxrI3ZpkIQ0/HtRRu3Hpt2+tgzrVfn5oCAH5pMyXWRBw0lSYJNsxAz3QCqJr5qokoCIFX7FQDFGfwAmwAMU2hYAxgBxwJ+5jWawZrlBJ+9QlNOqyvxaJ1ml794r4LUBP+sda28BPdeE0qzqnDVlM/+yZeC3HE2WVWomBoAF2ccdAO69n/5RhP9SEJp5Gveo3D1TIymKSDyW1/q5HkL542nPogELs2SanN70cHXr9NafKcvR17FsC2N1y9F5roJ/tHPUAGUqqcxYSoEf/KChUWzwvD167Xc2bi4YeV5AXsx10jwgtHIfuFTPt64HObPMst0/M5NG34oEKcCtxef6WcvBCwARkAKYK5Jg3GionFukgZs1ZN5ltt0Pc1V3o2e3HP3mwzX0piqD2rkXTtD1x4uwR0ng2Cfmkm7HdUMyKiVVd7Oi3NxXrhj0giCKBGIzNJgnIj8XoajFvdCCORtzDXT/F48R+fXs+UgiGeqnubLjVKMrqaXXJWnIs9PJHmqdL2s8sjFiqegtISVjHzZQsImAMMUGNYARiBJgR/coZnl3JTGW1fp83pZoWrKW12ajXF+erB23h2xmG2zqvHZKzRNvTif5hl0w/PuC9NJHtd+fiZFL1CIk/2ptlfmFa6dpXZmG4N2Mhxb5zN2LxQ4b2bVVImRnWi2RH4v881kx3uZqaf5hiEXZ5I8n+HhmpNrIHsx3xw8swszg3vxA4lU0fUW1m10+nIfmlKxnH8ZLABGJHs5k6FxIwUg86Idg7z9/cSgUOEM5NfYKYAlMzMAiqqzpIDap+5mW4M6/VJub0dgkPjjyMG97CugZuheHHvn70oJSDPYLEsP1TrQIz85Sw7asYbuZbj2QqoG/+1NMQc/wAJgJIZW07ZlmGX/n+3XB2wdYDutcm09V+9YfefJ9rN3NKvsM1xwY7h/w0ixtULPXlmAw9cY7l/ezi7FOLNBbMmhSkJPaStrR4qhdsQez2zo77s9M62HfyfKmizu0B4NFgAjoDTwYI0elTtUkTeMRR7wM9PQ+IlrpCZEsUTTVP0dDgW2TBpexVP4/DXazvvclMb56Sxjb+f2u32Ze8jPTqQIYoU4FXlwUj8SeRCSkIM18qvzES7O0Dkvn1c4N0WfOzto9Kmi4iUA4Ngiv5dGeTColjbsfEVAWoMqvW+/2oNjNIzsXiYqO0uAfiTzysKXZhU8h9pZa8fo9OnzGwsUSwABWEa6DO+g9PL5wTOrDNVVafWs3Fm6GkyjG1jGGdve5Zdl8cBOQIYpMKwBjIIeFMCMErElvDezz2tlhel65pgS8Mxsv9Eb1NIvlbKsNZXvsTfbGCTKZHUEn8SSg0Kf8xMJwoRqAL44R210+jIvO2ZZgOMYbWEyyduZris0ynQNKXYuGprdS8kZ3MvZSaDjm0InQzX3XFfn6vuFmYSKn1qDe8k2Q3kSKQZ2f7OiEKemuMqsRM/EOiy26LUUEvBMpt9cM83vZb45uBdnqGBJkkpEiQnBThXSFCMvxxaVU5szde3i5UP75S0JXD1jVOlzMf71P6C6d8Pr28N0A5lnvf2H/zORFwTJqv1M11P83q9sHqhPWiMP1723YuO//hml9dVKKvey//ynfXzh5YPtrRdEIt82/Kvv1PDd25SeO99M8ziFf/53W/m+g89K27dyh92//J+0OahjaZydJEEyXBBkN757u4kNn4THv/jvjVygpMlunsDR+3zr/r1TOVbYBGCYAsMmwAhoAGFKM1+QiK0559urfMG2dK5aTdY0sup5WUJRtqffQcmKbJRdjZkGHTcrCmcmBpFxB4WW3LLtu1TeznQDI9cYHAVnaEkwa8O1B0lYM/W97yWINXyzxbhW2iRDHbxvpxkWACOgtUAnpt17OlF/KDZeobmD577kaMCox5fnUkxSWD3eukbquGsf/K0UAnmdvcmawtUzWQhujCvzoTkeoVTQHjhDG5ucm1LohVk7Aq7xNViHoEeWh0yp7F7KrsIbl+mZZfsKPI22D6x3qK9JqqEOfvunHjYBGKbAsAYwIkFIs2o/TNDuk97vOTEoC353Fjck1jokZx+s0fp21VO4YjIAh0lSkZcTd+3BdlpU2MKsJLgKAqTZZhmHnb7EwzVpzrXzGbvkRnnW3zDD1yubmoBaI9+izBqq4Tfcp5X2oB3b0qh4gx1+nkTpQTERWw60iDgd7GLk2mpH7SFro+QITNXpmc02Bkk/u+GHQIeSKZ9SEpxtgmFYAIyA1jrfgLIfpGj36aWslfZ+mZY2JJY26IV+ZARAFiT0JEmKfMlweLksSgaDpuQAmQTIzu30BR6ZQRMlVKwUAM5O7DxgwngQI29234Yaup5jY0gADD5fa8u8nWYlzcOidxQASuTf85zBvn5JOvjclmJLmHNG1kbJ1ZhpUAetEfwM/ZCKjFCn9v0zFxI2ARimwLAGMCIqpSklihXWOlmJaxupoq2u19oaLVOaqu3LPHDou7fLeYnwVVNht1FOAGzXAhwLuWPt2pkQ82YHondulNAy33UsDQhAKQrNBYCVtoX37pFZUvYEPnxE5z5at3Hz8fafuOIKCCP6f/oV6nQ3kPjLD6i+oRCDxKBuMKgmfP1WCXeWaEZe2JBw7UwrSfJNQTMsCZTcrPJwgmtnyIT68KGbl1Gzpc770erKPMDqgwcU3+s6Gr7RvB6syDzwaJj5ZoyG0aiW2xZWze5LijWAkWABMCJZRFmqSNUEAClkvsvNg1WNRYoPwkp7EJO+0LLzfIHNgAZPo2zjI1M7b5haCaibopbzzSQvevFw1cHiEzv0KEX1+wEqQJKVJ7dtC8sdGmBlN4bcwUcx20ReOScTVH4o8uo8w7T7Mk/ZvbfqYLlNbbb6DqRZ//vokZuXMM9wbVoqBGigX5zJ/AjWju08blm5ryFrw7E0PCs19ytwd3n7M5NC57sKU93A7VuWM7vDJgDDFBjWAPZJkgArJorXsxPMN0lF/daPm/jzH5I54AcJkiRbo08wXaX5aDOmgIAwTfFH36ZjIZBn733x1Qi/9HpkvqfzgCFrKN79T79XRWhmbVONG46lcWmWVhViLdFPaab86FEZHz0w2XtS5AE7v/9lH9MmsCZrY7jOweOWjXdukBquhnLqa2WFC1Ok/nSTElJt530CKPgp20PxwkyK3/0F8sjNNAbtDMdAvHOjhMcm7j9JB87ErI1USyx16DmtdFP86AHd17mpBBfN/V6Y1pg2oc+bPZmXGBulbDrDAmDfaD0YLBoajkVvWpSIPA49DCkRBQBmGmn+0gszcFMlsdmlgSmEyAdNmEg4eXGQwTLgsAN8oye31ekruxqzDjWoU0AYW9qPJIIgS98dlCoXAnk7WRvD9nWckE3+JNWSyu/FUqSWA0BrqAZilvI8WcPQvQy1M9T1biB3bOfcFEm2ROl8S7Q0BUIThFT2BGYaZldhPfBXpEoM7Tx0KkP3Dx02ARimwLAGsE/CRODBKj22F2YSvHKOVPZffauNy7N03OoCoYnz+aXX/Xyb74fr9Pcg0nj/Hs1anoM8VPjTlwK8dZUKhQzH1//qT/aQGHXftfU2DWCqpvCl1+h7vdBFq0cFMB6uaiy2qJ3J2iB2/ytvbuae84yJqsLv/TLZNndXnLzs9jCfvRLmpsZyu48oIXX7+7cVEmWqJ0/QufPNBL/wKerHcG8//3KA1y+Rin9xJsHdle2v4K99nrL+klRicZPMiI0ucOsx3ctLZ2N86iJdQ0jkuxit+hNYDciLqnQbA1cguwR3gwXAMzD8Og2XwBoujZWpupYc/lw/9e/DZbGGkULnfoKdzrGk3tLGQK0flPOSQ/0TO7ajdyzPtaUdgV3aAaTe2sZOdQfztncoN7b1fkyP9M7PVEq9xWQZDHNW+/cLC4B9Qj4AY8unA2eTa+s8+04pE7EHqhng5Fl7NOtKQVtc09+Bejk73tlzNVw7r1lVKD2hAdTLKm/DUzpvp14CAtNOozLQAHYsCIJBG56jMVHd3peyp4buZRDGO1Elv4gUg3vZqU4CtTMQZrXSzu1kbUgxuJe4NHhmNW8otDiRSIwvQikNxd6/fXFqReZhFgQZpuxqXJghNfhnX+vjn/1y23yuUDpgUQxm//zoYQ0LLQqC+vdfr+HOktkoNDncVEAuCMIwzKmDTYB9orRAEJvlvsTK1+QpLJY1gOdNnAJmc2UopbkG4D5hAbBP4lRitUdBMmvdNA+TdW2N6kEuzDwT3b7GajtLm1ZQI24wyhBsAjBMgWENYJ9orZGYRfkgBromwWeiGmKnDD/maAljoGcKH/MCwP5hAbBPtNaIzEaB/QDY8MkDTdttxwe4MvMsBJFG2+xbkLL83TdsAjBMgWENYASklJiavbDt81qzBeARAGAznsSCPz/urhaOu7053O5SFqY3kWLGlGmLYx/QGlortDfWxt3NYwsLgBEQQqI+Mbvt81J5EC/fT2pYDyfG3dXCsRK8gKVgCgDgVLqol+g3CfstaK2hVMoC4CmwCcAwBYY1gBHQkOillwFQiGm3Q5l3m+06PnjwAgDAthxImx/n86bTt/Jy5n7YzIuXzM1MQAoNlcaQ1n36UINzBZ6A39gR0BBINYX5xCpBPzSrAKGLVVOxhhkPFTeBa5P7PwhtJMoUWrEEJTeJKC+EojlScxtsAjBMgWENYJ+kqUa7mxz8Qsyh0BGAAGUAaq2gke105BzksoWBBcAzwPkmxwf+LQ4GmwAMU2BYADBMgWEBwDAFhgUAwxQYFgAMU2BYADBMgeFlwBOAbYt8J94XZ9Zgyd3DWdv9EpY7lB2Xphqp2SfbtkRejvviVAuuvXssQydw8WCtvu1zKnFOx/ONNrwnrqGUxMONCWpbAf2Qy3Mdd1gAnABKroRl9g/8+U8+3Dbwhrm5PINv3moCAIJQIY1IALiuhGPTNd5+ZQHNcrDrNe4sN3cUALWyRq1M1/viS0uYqva2/D1KbPzp+7QneBgLFgAnADYBGKbAsAZwAghjBWnKj1+d20DViyCFxrkpMwMPRcN5rsC796h4SRIDofnctdN8t6IvvrSAM03afy/bGiZOJZY2KqY9a8d+nJvYxIVpavNnXnmAMxPdLX8PYhv31icBAK2uh8X1WTwLJY/mJa2BMOLsvaOEBcAJII41slF+aXoTjXIE21L4zIsrg5PMOFnp1uGZrcJ9SyIb4Y6l4Dl0jTcvL+PyzAZ9weiAQWTj/fvTAIClzcqO/ZhvdPDSHBXX+Imrj3FhurPl735k45s/PgcAWHCrAJ5NAHgudUopjTAa99M/3bAJwDAFhjWAE0DJk7kHX4jtjrUwLWOpR4VJ1sPnVJdwoJQc+g6Tfp80GE70OXpYAJwAbEvkqwA7kWoL7Zhs735SGfWyB+eIBECc8Mh/XrAJwDAFhjWAE4AfpMim2Z02vyxZPl5q/BAAUH21iovVmwCAW8sTuL9K6/mvX1jFTL0PAJipD63fG+ehZ6X41AVy8FlS45+8/eG2dj5zaRmXpmk79EY5BHPyYQFwAqA6lrurxVIoeBYF9tQ9gTNN+lk3fRedPq39zTV6mGtQMVNbbr+WEBolhwKMql6Myer2QKFGKULVo92PLMFq+mmATQCGKTCsAZwAahUrdwLutAowzEyjj5kmqfpvXVva+aQ9YmtePtfCv/p77zz9JI7PORWwBsAwBYY1gOdItpYPUJTbqChFNjrDHDYsAJ4j9SrF2Cul0emNvpc1rQIQeq/omOEAnWflMK7BnAjYBGCYAsMawHMki3DbcxZ/AtsSEJxazxwBLACeI1mM+34peXLkVQCG2Q9sAjBMgWEN4AQQxRoyNeYDe+eYQ4QFwAkgioeibnj8M4cImwAMU2BYAzhG2LbIK/fuxknxAVpCoFwa3/xyQh7T2GEBcIywpIDr7DVoTsarLSRGuJej7MC4n8DJgE0AhikwrAGMmfOTXfz0ywsAgBemurg823nq+W9cWoZrpWQKHJeMPNOPkpXid7/0PgCg3ffwU9cWxtalxY0ESgNBpPE/bo77AR1fWACMGc9JcXaCKvRcmm7j5fn1p57fKFFJ8OOIFBovTNFeAd0ghB+O7/VKo4i2J7MEgIlxP5pjC5sADFNgWAMYM7N1H7/02j0AwNnJHi7MdJ96vnVs9P6nUy3F+OyVlYNf6Bnp9JuIU4FewN7Ap8ECYMxIQbv2AIBtqafu/Avg+Nj9eyCAve/lCJESkIqeL7M7LADGRLaef1LW9ZnTCQuAMSClyIuDlEs7b8R5Kopy7KUACAzW64fPlTtcY/jcJ3clYiH6zLATkGEKDAsA5viidzlmDg02AZjxsZuZs5vpoPZxDRYYI8EaAMMUGNYAxoDWOs/xT5KneMrYufXs8LMbCRYAY0BroB/QwI/iXXRVfoGZ5wCbAAxTYFgDGDOdwMGHC1MAgF7kQGue+g+DjS4Qpxp+yM/zabAAGDN+5ODuahMAha1W3XjcXToVtH2TDRjxcsDTYBOAYQoMawBjZnGjiq+9exUA0KykmKwl4+7SqaBa1xACSJIEwHvj7s6xhQXAmPEjG3dXGgAAz5UoeayUHQaXLwpYElBpBBYAu8NvG8MUGNYAjhFRrPINRJmDoTW/2qPAT+kYofX+dw5mmIPAJgDDFBgWAAxTYFgAMEyBYR/AM2BxpclDQWkNdnmMFxYA+8SyBGpV6+AXYuD3U171GDNsAjBMgWENYARsy8Ibb1wCQAU8/K4/7i6dCj66sYRWi7ZF8/0ISrE28LxhATACnufgd37nZ8fdjVPHH/zBX+CDDx4AAO7fX0MUpePuUuFgE4BhCgxrACMgJNBsVsbdjVPH+fNT8P0QAPD48SZrAGOABcAISCEwMcEC4LC5cGEaaUq1Eb/znTvj7k4hYROAYQoMawDM2HBdG6WSCwAQvEvqWGABwIwNy5JwHAqqYgEwHtgEYJgCwwKAYQoMCwCGKTAsABimwLATkBkb/X6MbrcPAFBKHfBqO6MBpAkHGO0GCwBmjHA9gHHDAmAEtAai6Hhs2OG6x/snyyL7tNZ7ZveFYYIwjM35h9sPAQ1h/mV253i/TceEJE3x/e/fHXc3AABvvvkibPt4FiRRSuHhw3UAQBwnWF/vPvX8d965gVu3FgEA/X54qH1xZR+2BaSa91p8GuwEZJgCwxrACKhU4dGDxwCAVAHhGHecvXJlDq5rQwiBer087kezBaU01tY6AIBeL8SdO0sAACkFpMzOQW4arK114ftR/t2DYlkCWTyh0imU0lDqeJhuxxUWACMQRzH++Gt/BgAIQuDR4/EJgHPnplGterBtC2+++eK4H80WkkTh+vVbAIDFxU187WvfBQC4jkS5RBIgCBXC6Gg8/mVPwrJIBCRxDzpVSFMWAE+DTQCGKTCsAYyIJWgmkUIgk5tKaSTp0WsDji1xknNlUqURxTTrp0f4vBxLwTFvtEpCQKZIU44BeBosAEZBaNiSbFVLSAAeACBJNfrB0aizw1gVkau2J5E01eg/B0HpOSk8h9pJYh9CpFCKBcDTYBOAYQoMawCjoIEkppBVrSyUXSv/vD/uvjE5bslDyTgbU98HEHOp8T1gATASGmlqAlWUDc8uAQDieOAPYMaP7bpwSiScg04IrSLebn0P+O1lmALDGsAIaK3Q23xE/yPrqDTOAQAipEA7Gnf3GIMlY9iSVmt8vw+lIk422gMWACOgtUYS0XZg0vHgOA4dH8+Q/MIihDLLtJS/oXgJcE/YBGCYAsMawAhorbGxQTHupYrE9HwLAOBb7AQcN5N1hapHer4nNgFT/EMlCQcBjQALgBHJKtZorSEEHQvBg3/cSAFYxhQTUIDOBj0b/6PAAmDf6KGlJQ0pyebU+nhUt9FaD4XbDvpEpjH11bJ2Di3O7mvrNQZIKfLvCXFMwpPFoE8aGlobQT3ufp0QWADskzQJ0W7dBQA4ch5XrrwEgFJbWy1/3N3D3bsr+T57vh8iCGiVolYr59WEvvzlN7alEsdxioUFMm2Wlzfxve9t36vv0qUZTE/XAQCf/OQLqNVK475dlKoV1CbIKRusfwQV0z1oDgEeCdZhGabAsAawT7TWSGITFejEsCTNNOOsPae1RhxTP3w/QqtFpbi63SAvuBFFKTyPfu4giOF5NGsOagxuvcbKSmdbO/V6GZYxuJMxVtoVArnpJUVCtj8AlSZj7ddJ5NQKgFHM02cZskkcYn11AQBQa1qYap4FAGzY43vxoijB4uImAOBHP3qIP//zHwLYapacPdtEtUpZjG++eQVzcw0ApNYDVMxzfZ0G/Y0bC/jqV69va+f11y/iwoVpAMCrr57DxER1LPfrOhIlj5TXkrUBR9E9+r0NBP3uQS5dONgEYJgCc2o1gKMk85arNIKKaeZ17XLuWOv3IyTJ0dcJOCqkEHAcYe6RCnocJ1wHqBnlQ+g+4rBNfWXH374ptAB4plUsDWizRKbiLmL/IQCgUroMrzoPAHj8eBNJcrhlrp8nlgVUTFZdGCmk4fESAJUKMD9Lv15/ow2/TaXFVcp5GfuFTQCGKTCF1gAOShxF6GzSRhjl5iSqZXKslb0UaUKyNYzUgQOEolhDJHSRmzcfo1RyIaVAq9UDQB75bpc0jlu3HqNn9tuLh3YzCoIIMEEy7713D81m1ZxPs2ccp1heJnPm/v11BOH2Gn7dboDVVVK3v/Wtm7h5c3FrP6MkLwW+sXG4MRGua+VxByW3gyRYo+fbbyPoBwAOp7R40WABcADiOERslgTL1U1U3AkAQMl1EcekQkexPnBRiqygJgDcurWUL9199NHCtnOXFlvwe0YADH0vDCKohHbJ+eD9ByhXvF3bW1ra3LF0d7cb5PX9r1+/hXLZ3fL3NFX4+ONlALTUeJg4jo2pKRJaVtpCEi6b++oc+q5CRYJNAIYpMKwBHBJ+Zxk6pZm3UrqCSmUCANAPgMPcB+OHP7yfB8HsRBDE8PvkDU+H2g0jhdhMyu9/8BCWJZ96jZ3Y3OzD92m2bbeDbdfQGvl234dR/lsKoGSckdVygkaJzK3e5gpa62RqxFFweA+3gLAAOCSisAetaHA0ay/Aq9Dn8pB1rKWlzWf6XppqZItky8vtZ7pGGMYIjbad+RyOFCHg2CTsXDuFZ5OXv5f6CHwO+DkM2ARgmALDGsAhkSSDXWjKnbsQMTmpLpx/DVqQ9/rWbZ61RqFWJbXftTUunydNIwo28Pj+bQBAGHAx9sOCBcAhMVwPQKUhdEqqq1fB4dsBpxxLZnULAM81iT5xgjikZc804Q0/Dwt+MxmmwLAGcAS01lsQpkzNjP4hbJtSb1/7xOcAkEeezYGt1KpWPvN/4gqp+Encx4Nb79JxmiIMeL3/sGEBcEQMlw3LEo8H5bTG3bvjx/AjGX4++XM8DvXWTiEsAI6YNEnyl9s2y4RCa3iuybbTQFa89rjUFXxeWHIw2B1b58U9k5jW9tMk3FKnkDl8WAAcMesrg3Dds8YUcKWH1165BgDo+cDiMr3cYaTyGPwiMNVQqJiS3nOzMWzzNj64+V0AFNsfBBzoc5SwE5BhCgxrAM+RMKAMOSFjSIfCWoWyUatQ2KBtW5AW/SRRlJzooiLDSAFIi3R9x5awTXRfyQvgOrSkF/htSJllIJJNxGr/0cMC4DmyvvIYANXl11klofIELp6l0uJ+VEMvagKgcN12+3Sov7YtUS6Rsjkx4aBeJ1PI0W1ITWv7j+9/iDi3/Xeu7DPsKGTRcDiwCcAwBYY1gDGgtUZg1rQT1YEWD+hzWYclKT6gWXVQckk+R0EKszMZOn1xbFcKBADX9FlKCa9E9QI8J0G1RIk8jt1Hlpbo+4tIk6yoSQzNBT2eOywAxoBSGr5P6q7oh+h1NwAAlVoTtfoUAGCqcQ6WOwkA2GylSExxj25gHVsBAIG8XLfj2JiYqgEASo6PukcDPfDXEQV0v53WIoJ+71mbOjDH9TE+T9gEYJgCwxrAmNFa5+p94Pu5A8zxQ9gOOQ09dwolhxxnF85OQENAQyCMqQx5mij4/qAQRxQfzdzmOgKW8eZ7dgpLmm25KxVAUFBPvZRl6gVAQkU7oqCH5TWq4ZfEAVJTMTkrpzYuMi2iyJoAC4BjQGb7xlGIOKJB4UZ92DaFxpXnXDimwohXEwAktBboBCQA4jjJtyuLoIAjEgCWJeA6pDRWSylsIwBqkw6EEBDQqLm0u1CaBOiZct1x0EV7cxUAbbPOtv7xgU0AhikwrAEcU5IkQWLy3lcWP4aQpA1I6y4gBISQqDXPAQAcIVGdoSq/SnhQIOdbqi0oTT9xktpQajR5L6WCbW3PuS/bfTgWaRpa+YCmc8KNW9BQ0Fqj1aX4Bq0VUrNRh1IplClQeByDe4qcm8UC4Jii1HBJ70GNfcumYyklZIPKZEthw/XMayxtaGOnp8pCqk158sTZlwBw7e0DtWQDjonWi6MEWpEA6CctaJVCaw2/92z1BpnxwCYAwxQY1gCOHU9XkbNVglSkWFq4m38uMlkuBIaVWp0da2B0ZVfveKoYqm1AmySaI50CKFYq82mBBcBJRQMqHY6Z551xmf3DJgDDFBgWAAxTYFgAMEyBYQFwrGAvGvN8YSfgsYAHPjMeWANgmALDAoBhCgwLAIYpMCwAGKbAsBNwbLDjjxk/rAEwTIFhAcAwBYZNgOcKq/3M8YI1AIYpMCwAGKbAsABgmALDAoBhCgwLAIYpMP8fIhJ9ftg4Y1MAAAAASUVORK5CYIIoAAAAgAAAAAABAAABACAAAAAAAAAAAQB0EgAAdBIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAIB4l/yAeJf8gHiX/IB4l/yAeJf8gHiX/IB4l/yAeJf8gHiX/IB4l/yAeJf8gHiX/IB4l/yAeJf8gHiX/IB4l/yAeJf8gHiX/IB4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAgHiX/IB4l/yAeJf8gHiX/IB4l/yAeJf8gHiX/IB4l/yAeJf8gHiX/IB4l/yAeJf8gHiX/IB4l/yAeJf8gHiX/IB4l/yAeJf8gHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/wAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACAeJf8gHiX/IB4l/yAeJf8gHiX/IB4l/yAeJf8gHiX/IB4l/yAeJf8gHiX/IB4l/yAeJf8gHiX/IB4l/yAeJf8gHiX/IB4l/yAeJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAIB4l/yAeJf8gHiX/IB4l/yAeJf8gHiX/IB4l/yAeJf8gHiX/IB4l/yAeJf8gHiX/IB4l/yAeJf8gHiX/IB4l/yAeJf8gHiX/IB4l/yAeJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAgHiX/IB4l/yAeJf8gHiX/IB4l/yAeJf8gHiX/IB4l/yAeJf8gHiX/IB4l/yAeJf8gHiX/IB4l/yAeJf8gHiX/IB4l/yAeJf8gHiX/IB4l/yAeJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/wAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACAeJf8gHiX/IB4l/yAeJf8gHiX/IB4l/yAeJf8gHiX/IB4l/yAeJf8gHiX/IB4l/yAeJf8gHiX/IB4l/yAeJf8gHiX/IB4l/yAeJf8gHiX/IB4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAIB4l/yAeJf8gHiX/IB4l/yAeJf8gHiX/IB4l/yAeJf8gHiX/IB4l/yAeJf8gHiX/IB4l/yAeJf8gHiX/IB4l/yAeJf8gHiX/IB4l/yAeJf8gHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAgHiX/IB4l/yAeJf8gHiX/IB4l/yAeJf8gHiX/IB4l/yAeJf8gHiX/IB4l/yAeJf8gHiX/IB4l/yAeJf8gHiX/IB4l/yAeJf8gHiX/IB4l/yAeJf8gHiX/IB4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/wAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACAeJf8gHiX/IB4l/yAeJf8gHiX/IB4l/yAeJf8gHiX/IB4l/yAeJf8gHiX/IB4l/yAeJf8gHiX/IB4l/yAeJf8gHiX/IB4l/yAeJf8gHiX/IB4l/yAeJf8gHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAIB4l/yAeJf8gHiX/IB4l/yAeJf8gHiX/IB4l/yAeJf8gHiX/IB4l/yAeJf8gHiX/IB4l/yAeJf8gHiX/IB4l/yAeJf8gHiX/IB4l/yAeJf8gHiX/IB4l/yAeJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/yAfJv8hHyb/ISAm/yIgJv8jICb/IyAm/yMgJv8jICb/IyAm/yMgJv8jICb/IyAm/yMgJv8jICb/IyAm/yIgJ/8hICb/IR8m/yAfJv8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA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HiT/Hx4k/x8eJP8AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAgHiT/IB4k/yAeJP8gHiT/IB4k/yAeJP8gHiT/IB4k/yAeJP8kHyX/f0E3/3ErIf9pHRP/aR0T/2kdE/9pHRP/aR0T/2kdE/9pHRP/aR0T/2kdE/9pHRP/aR0T/2kdE/9pHRP/aR0T/2kdE/9pHRP/aR0T/2kdE/9pHRP/aR0T/2kdE/9pHRP/aR0T/2kdE/9pHRP/aR0T/2kdE/9pHRP/aR0T/2kdE/9pHRP/aR0T/2kdE/9pHRP/aR0T/2kdE/9pHRP/aR0T/2kdE/9pHRP/aR0T/2kdE/9pHRP/aR0T/2kdE/9pHRP/aR0T/2kdE/9pHRP/aR0T/2kdE/9pHRP/bkhD/0U0Nf8iIif/Hx4k/x8eJP8fHiT/Hx4k/x8eJP8fHiT/Hx4k/wAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACAeJP8gHiT/IB4k/yAeJP8gHiT/IB4k/yAeJP8gHiT/IB4k/yQfJf9/QTf/cSsh/2kdE/9pHRP/aR0T/2kdE/9pHRP/aR0T/2kdE/9pHRP/aR0T/2kdE/9pHRP/aR0T/2kdE/9pHRP/aR0T/2kdE/9pHRP/aR0T/2kdE/9pHRP/aR0T/2kdE/9pHRP/aR0T/2kdE/9pHRP/aR0T/2kdE/9pHRP/aR0T/2kdE/9pHRP/aR0T/2kdE/9pHRP/aR0T/2kdE/9pHRP/aR0T/2kdE/9pHRP/aR0T/2kdE/9pHRP/aR0T/2kdE/9pHRP/aR0T/2kdE/9pHRP/aR0T/2kdE/9uSEP/RTQ1/yIiJ/8fHiT/Hx4k/x8eJP8fHiT/Hx4k/x8eJP8fHiT/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAIB4k/yAeJP8gHiT/IB4k/yAeJP8gHiT/IB4k/yAeJP8gHiT/JB8l/39BN/9xKyH/aR0T/2kdE/9pHRP/aR0T/2kdE/9pHRP/aR0T/2kdE/9pHRP/aR0T/2kdE/9pHRP/aR0T/2kdE/9pHRP/aR0T/2kdE/9pHRP/aR0T/2kdE/9pHRP/aR0T/2kdE/9pHRP/aR0T/2kdE/9pHRP/aR0T/2kdE/9pHRP/aR0T/2kdE/9pHRP/aR0T/2kdE/9pHRP/aR0T/2kdE/9pHRP/aR0T/2kdE/9pHRP/aR0T/2kdE/9pHRP/aR0T/2kdE/9pHRP/aR0T/2kdE/9pHRP/aR0T/25IQ/9FNDX/IiIn/x8eJP8fHiT/Hx4k/x8eJP8fHiT/Hx4k/x8eJP8AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAgHiT/IB4k/yAeJP8gHiT/IB4k/yAeJP8gHiT/IB4k/yAeJP8k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AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACAeJP8gHiT/IB4k/yAeJP8gHiT/IB4k/yAeJP8gHiT/IB4k/yAeJP8gHiT/IB4k/x4yQf8Th7v/BKrv/wC0//8AtP//ALT//wC0//8AtP//ALT//wC0//8AtP//ALT//wC0//8AtP//ALT//wC0//8AtP//ALT//wC0//8AtP//ALT//wC0//8AtP//ALT//wC0//8AtP//ALT//wC0//8AtP//ALT//wC0//8AtP//ALT//wC0//8AtP//ALT//wC0//8AtP//ALT//wC0//8AtP//ALT//wC0//8AtP//ALT//wC0//8AtP//ALT//wC0//8OcZ3/Fkdg/x8eJP8fHiT/Hx4k/x8eJP8fHiT/Hx4k/x8eJP8fHiT/Hx4k/x8eJP8fHiT/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAIB4k/yAeJP8gHiT/IB4k/yAeJP8gHiT/IB4k/yAeJP8gHiT/IB4k/yAeJP8kIyn/ITtM/wmV0f8CrfT/ALT//wC0//8AtP//ALT//wC0//8AtP//ALT//wC0//8AtP//ALT//wC0//8AtP//ALT//wC0//8AtP//ALT//wC0//8AtP//ALT//wC0//8AtP//ALT//wC0//8AtP//ALT//wC0//8AtP//ALT//wC0//8A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HiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAIB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/ycmK/8fQFL/EmGF/waZ1v8PbZb/GEZd/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAgHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8g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AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAIB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAgHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/wAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAIB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAgHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/wAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAIB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAgHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/wAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAP///+AAAAAAAAAAAAf////////gAAAAAAAAAAAH////////4AAAAAAAAAAAB////////+AAAAAAAAAAAAf////////gAAAAAAAAAAAH////////4AAAAAAAAAAAB////////+AAAAAAAAAAAAf////////gAAAAAAAAAAAH////////4AAAAAAAAAAAB////////+AAAAAAAAAAAAf////////gAAAAAAAAAAAH////////4AAAAAAAAAAAB////////+AAAAAAAAAAAAf////////gAAAAAAAAAAAH////////4AAAAAAAAAAAB////////+AAAAAAAAAAAAf////////gAAAAAAAAAAAH////////4AAAAAAAAAAAB////////+AAAAAAAAAAAAf////////gAAAAAAAAAAAH////////4AAAAAAAAAAAB////////+AAAAAAAAAAAAf////////gAAAAAAAAAAAH////////4AAAAAAAAAAAB////////+AAAAAAAAAAAAf////////gAAAAAAAAAAAH////////4AAAAAAAAAAAB////////+AAAAAAAAAAAAf////////gAAAAAAAAAAAH////////4AAAAAAAAAAAB////////+AAAAAAAAAAAAf////////gAAAAAAAAAAAH////////4AAAAAAAAAAAB////////+AAAAAAAAAAAAf////////gAAAAAAAAAAAH////////4AAAAAAAAAAAB////////+AAAAAAAAAAAAf////////gAAAAAAAAAAAH////////4AAAAAAAAAAAB////////+AAAAAAAAAAAAf////////gAAAAAAAAAAAH////////4AAAAAAAAAAAB////////+AAAAAAAAAAAAf////////gAAAAAAAAAAAH////////4AAAAAAAAAAAB////////+AAAAAAAAAAAAf////////gAAAAAAAAAAAH////////4AAAAAAAAAAAB////////+AAAAAAAAAAAAf////////gAAAAAAAAAAAH////////4AAAAAAAAAAAB////////+AAAAAAAAAAAAf////////gAAAAAAAAAAAH////////4AAAAAAAAAAAB////////+AAAAAAAAAAAAf////////gAAAAAAAAAAAH////////4AAAAAAAAAAAB////////+AAAAAAAAAAAAf////////gAAAAAAAAAAAH////////4AAAAAAAAAAAB////////+AAAAAAAAAAAAf////////gAAAAAAAAAAAH////////4AAAAAAAAAAAB////////+AAAAAAAAAAAAf////////gAAAAAAAAAAAH////////4AAAAAAAAAAAB////////+AAAAAAAAAAAAf////////gAAAAAAAAAAAH////////4AAAAAAAAAAAB////////+AAAAAAAAAAAAf////////gAAAAAAAAAAAH////////4AAAAAAAAAAAB////////+AAAAAAAAAAAAf////////gAAAAAAAAAAAH////////4AAAAAAAAAAAB////////+AAAAAAAAAAAAf////////gAAAAAAAAAAAH////////4AAAAAAAAAAAB////////+AAAAAAAAAAAAf////////gAAAAAAAAAAAH////////4AAAAAAAAAAAB////////+AAAAAAAAAAAAf////////gAAAAAAAAAAAH////////4AAAAAAAAAAAB////////+AAAAAAAAAAAAf////////gAAAAAAAAAAAH////////4AAAAAAAAAAAB////////+AAAAAAAAAAAAf////////gAAAAAAAAAAAH////////4AAAAAAAAAAAB////////+AAAAAAAAAAAAf////////gAAAAAAAAAAAH////////4AAAAAAAAAAAB////////+AAAAAAAAAAAAf////////gAAAAAAAAAAAH////////4AAAAAAAAAAAB////////+AAAAAAAAAAAAf////////gAAAAAAAAAAAH////////4AAAAAAAAAAAB////////+AAAAAAAAAAAAf////////gAAAAAAAAAAAH////////4AAAAAAAAAAAB////////+AAAAAAAAAAAAf////////gAAAAAAAAAAAH////////4AAAAAAAAAAAB////////+AAAAAAAAAAAAf////////gAAAAAAAAAAAH////////4AAAAAAAAAAAB////////+AAAAAAAAAAAAf////////gAAAAAAAAAAAH////////4AAAAAAAAAAAB////////+AAAAAAAAAAAAf////////gAAAAAAAAAAAH////////4AAAAAAAAAAAB////////+AAAAAAAAAAAAf////////gAAAAAAAAAAAH////////4AAAAAAAAAAAB////////+AAAAAAAAAAAAf////////gAAAAAAAAAAAH////////4AAAAAAAAAAAB////////+AAAAAAAAAAAAf////////gAAAAAAAAAAAH////////4AAAAAAAAAAAB////////+AAAAAAAAAAAAf////////gAAAAAAAAAAAH////////4AAAAAAAAAAAB////////+AAAAAAAAAAAAf////////gAAAAAAAAAAAH////KAAAAEAAAACAAAAAAQAgAAAAAAAAQAAAdBIAAHQSAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAgHiWAIB4l/yAeJf8gHiX/IB4l/yAeJf8gHiX/IB4l/yAeJf8gHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4lgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAIB4lgCAeJf8gHiX/IB4l/yAeJf8gHiX/IB4l/yAeJf8gHiX/IB4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJYAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACAeJYAgHiX/IB4l/yAeJf8gHiX/IB4l/yAeJf8gHiX/IB4l/yAeJf8gHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiWAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAgHiWAIB4l/yAeJf8gHiX/IB4l/yAeJf8gHiX/IB4l/yAeJf8gHiX/IB4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4lgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAIB4lgCAeJf8gHiX/IB4l/yAeJf8gHiX/IB4l/yAeJf8gHiX/IB4l/yAeJf8gHiX/Hx4l/x8eJf8fHiX/IB8m/yEfJv8hHyb/IR8l/yEfJf8hHyb/IR8m/yAfJv8gHyX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJYAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACAeJYAgHiX/IB4l/yAeJf8gHiX/IB4l/yAeJf8gHiX/IB4l/yAeJf8gHiX/IB4l/yEfJv8rJy3/QTI0/1k9O/9r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AAAAIB4jgCAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8hICT/GUlg/xJ2o/8dLDf/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI4AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACAeI4AgHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAfJP8gICb/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiOAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAgHiOAIB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4jgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAIB4jgCAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI4AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACAeI4AgHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiOAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAgHiOAIB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4jgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD/+AAAAAAf///4AAAAAB////gAAAAAH///+AAAAAAf///4AAAAAB////gAAAAAH///+AAAAAAf///4AAAAAB////gAAAAAH///+AAAAAAf///4AAAAAB////gAAAAAH///+AAAAAAf///4AAAAAB////gAAAAAH///+AAAAAAf///4AAAAAB////gAAAAAH///+AAAAAAf///4AAAAAB////gAAAAAH///+AAAAAAf///4AAAAAB////gAAAAAH///+AAAAAAf///4AAAAAB////gAAAAAH///+AAAAAAf///4AAAAAB////gAAAAAH///+AAAAAAf///4AAAAAB////gAAAAAH///+AAAAAAf///4AAAAAB////gAAAAAH///+AAAAAAf///4AAAAAB////gAAAAAH///+AAAAAAf///4AAAAAB////gAAAAAH///+AAAAAAf///4AAAAAB////gAAAAAH///+AAAAAAf///4AAAAAB////gAAAAAH///+AAAAAAf///4AAAAAB////gAAAAAH///+AAAAAAf///4AAAAAB////gAAAAAH///+AAAAAAf///4AAAAAB////gAAAAAH///+AAAAAAf///4AAAAAB////gAAAAAH///+AAAAAAf///4AAAAAB////gAAAAAH///+AAAAAAf/ygAAAAwAAAAYAAAAAEAIAAAAAAAACQAAHQSAAB0EgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAIB4l3yAeJf8gHiX/IB4l/yAeJf8gHiX/IB4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l3wAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAIB4l3yAeJf8gHiX/IB4l/yAeJf8gHiX/IB4l/yAeJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l3wAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAIB4l3yAeJf8gHiX/IB4l/yAeJf8gHiX/IB4l/yAeJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l/x8eJf8fHiX/Hx4l3wAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAIB4l3yAeJf8gHiX/IB4l/yAeJf8gHiX/IB4l/yAeJf8gHiX/Hx4l/yEgJ/8s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HiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j3wAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAIB4j3yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j3wAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAIB4j3yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j/yAeI/8gHiP/IB4j3wAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD/wAAAA/8AAP/AAAAD/wAA/8AAAAP/AAD/wAAAA/8AAP/AAAAD/wAA/8AAAAP/AAD/wAAAA/8AAP/AAAAD/wAA/8AAAAP/AAD/wAAAA/8AAP/AAAAD/wAA/8AAAAP/AAD/wAAAA/8AAP/AAAAD/wAA/8AAAAP/AAD/wAAAA/8AAP/AAAAD/wAA/8AAAAP/AAD/wAAAA/8AAP/AAAAD/wAA/8AAAAP/AAD/wAAAA/8AAP/AAAAD/wAA/8AAAAP/AAD/wAAAA/8AAP/AAAAD/wAA/8AAAAP/AAD/wAAAA/8AAP/AAAAD/wAA/8AAAAP/AAD/wAAAA/8AAP/AAAAD/wAA/8AAAAP/AAD/wAAAA/8AAP/AAAAD/wAA/8AAAAP/AAD/wAAAA/8AAP/AAAAD/wAA/8AAAAP/AAD/wAAAA/8AAP/AAAAD/wAA/8AAAAP/AAD/wAAAA/8AAP/AAAAD/wAA/8AAAAP/AAD/wAAAA/8AAP/AAAAD/wAA/8AAAAP/AAAoAAAAIAAAAEAAAAABACAAAAAAAAAQAAB0EgAAdBIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA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
"@

    # HUVUDFÖNSTER
    $Global:formMain = New-Object System.Windows.Forms.Form
    $Global:formMain.Text = "KrimsonTools v1.0"
    $Global:formMain.Size = New-Object System.Drawing.Size(1200, 800)
    $Global:formMain.StartPosition = "CenterScreen"
    $Global:formMain.BackColor = [System.Drawing.Color]::FromArgb(31, 31, 43)

    # Aktivera standardramen för den snygga, moderna Windows-looken
    $Global:formMain.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::Sizable
    $Global:formMain.MaximizeBox = $true
    $Global:formMain.MinimizeBox = $true

    # --- BINÄR IKONHANTERING (BILD-METODEN FÖR PERFEKT TRANSPARENS) ---
    # 1. Konvertera textsträngen till byte-data i RAM-minnet
    $iconBytes = [System.Convert]::FromBase64String($Global:iconBase64String)
    $iconMs = New-Object System.IO.MemoryStream($iconBytes, 0, $iconBytes.Length)
    
    # 2. Läs in som en Bitmap-bild (denna behåller transparensen perfekt!)
    $iconBitmap = New-Object System.Drawing.Bitmap($iconMs)
    
    # 3. Omvandla till en Windows-ikon via bildens inbyggda handtag
    $Global:formMain.Icon = [System.Drawing.Icon]::FromHandle($iconBitmap.GetHicon())
    $Global:formMain.ShowIcon = $true

    # =========================================================================================
    # 1. SIDOMENY BEHÅLLARE (VÄNSTER)
    # =========================================================================================
    # --- # 1. SIDOMENY BEHÅLLARE (Vänster) ---
    $panelLeftContainer = New-Object System.Windows.Forms.Panel
    $panelLeftContainer.Width = 240
    $panelLeftContainer.Dock = [System.Windows.Forms.DockStyle]::Left
    $panelLeftContainer.BackColor = [System.Drawing.Color]::FromArgb(20, 30, 105)

    # Konvertera binärsträngen till en bild i minnet
    $imageBytes = [System.Convert]::FromBase64String($Global:logoBase64String)
    $ms = New-Object System.IO.MemoryStream($imageBytes, 0, $imageBytes.Length)
    $ms.Write($imageBytes, 0, $imageBytes.Length)
    $ms.Position = 0  # <--- DENNA RAD SÄKRAR ATT BILDEN LÄSES FRÅN BÖRJAN!
    $logoImage = [System.Drawing.Image]::FromStream($ms, $true)

    # Din logotyp-ruta (Klickbar med hand-muspekare)
    $pictureBoxLogo = New-Object System.Windows.Forms.PictureBox
    $pictureBoxLogo.Location = New-Object System.Drawing.Point(20, 18)
    $pictureBoxLogo.BackColor = [System.Drawing.Color]::Transparent
    $pictureBoxLogo.SizeMode = [System.Windows.Forms.PictureBoxSizeMode]::AutoSize
    $pictureBoxLogo.Image = $logoImage
        
    # Ändra muspekaren till en hand när man hovrar över loggan
    $pictureBoxLogo.Cursor = [System.Windows.Forms.Cursors]::Hand

    # Klick-händelse: Öppnar inställningarna direkt
    $pictureBoxLogo.Add_Click({
    
    # Kontrollera direkt i minnet om panelSettings fysiskt ligger på arbetsytan
    $IsSettingsOpen = $Global:panelChildForm.Controls.ContainsKey("panelSettings")
    
    if ($isSettingsOpen -eq $true) {
        # 1. SPARA AKTIV PROFIL FÖRST (Medan textrutorna fortfarande existerar på skärmen)
        Save-KrimsonSettings
        $Global:CurrentActiveProfileOnScreen = ""

        # Om den finns öppen -> Töm arbetsytan direkt så den blir helt tom och ren till höger
        $Global:panelChildForm.Controls.Clear()

        # Nollställ även titlarna i toppanelen så de försvinner
        if ($Global:lblTitleLeft) { $Global:lblTitleLeft.Text = "" }
        if ($Global:lblTitleRight) { $Global:lblTitleRight.Text = "" }

        $Global:formMain.Refresh()
        write-KrimsonLog "Stängde konfigurationsskärmen via logotypen och sparade ändringar."
    }
    else {
        # Om den INTE finns på skärmen -> Öppna den omedelbart på det ABSOLUT FÖRSTA klicket!
        Invoke-Screen -TargetFunction "Create-FormSettings" -TitleLeft "Konfiguration" -TitleRight "Miljöprofiler"
    }
})

    $panelLeftContainer.Controls.Add($pictureBoxLogo)
    $pictureBoxLogo.BringToFront()

    # --- # 2. TOPPANEL (Mörkblå överkant) ---
    $panelTop = New-Object System.Windows.Forms.Panel
    $panelTop.Height = 60
    $panelTop.Dock = [System.Windows.Forms.DockStyle]::Top
    $panelTop.BackColor = [System.Drawing.Color]::FromArgb(20, 30, 105) # Din mörkblå färg

    # Vänster text i toppanelen (Aktiv flik)
    $Global:lblTitleLeft = New-Object System.Windows.Forms.Label
    $Global:lblTitleLeft.Text = "KrimsonTools"
    $Global:lblTitleLeft.Font = New-Object System.Drawing.Font("Verdana", 14, [System.Drawing.FontStyle]::Bold)
    $Global:lblTitleLeft.ForeColor = [System.Drawing.Color]::White
    $Global:lblTitleLeft.Location = New-Object System.Drawing.Point(20, 15)
    $Global:lblTitleLeft.AutoSize = $true
    $panelTop.Controls.Add($Global:lblTitleLeft)

    # Höger text i toppanelen (Aktiv underfunktion)
    $Global:lblTitleRight = New-Object System.Windows.Forms.Label
    $Global:lblTitleRight.Text = ""
    $Global:lblTitleRight.Font = New-Object System.Drawing.Font("Verdana", 12)
    $Global:lblTitleRight.ForeColor = [System.Drawing.Color]::FromArgb(255, 180, 0) # Orange text
    $Global:lblTitleRight.Location = New-Object System.Drawing.Point(300, 18)
    $Global:lblTitleRight.AutoSize = $true
    $panelTop.Controls.Add($Global:lblTitleRight)

    # # 2. HÖGERPANELEN (Fyller ut hela det resterande utrymmet till höger)
    $Global:panelChildForm = New-Object System.Windows.Forms.Panel

    $Global:panelChildForm.Dock = [System.Windows.Forms.DockStyle]::Fill 
    $Global:panelChildForm.BackColor = [System.Drawing.Color]::FromArgb(31, 31, 43)

    # =========================================================================================
    # 3. STATUSRAD (LÄNGST NER - APPLICERAR ORANGE FÄRG OCH GLOBAL TEXT)
    # =========================================================================================
# # HÄR SKAPAS DE GLOBALA VARIABLERNA SOM MENYN BEHÖVER
# =========================================================================================
# Säkra att statusraden skapas som ett objekt i Windows!
$statusStrip = New-Object System.Windows.Forms.StatusStrip
$statusStrip.AutoSize = $false
$statusStrip.BackColor = [System.Drawing.Color]::FromArgb(255, 180, 0)
$statusStrip.Dock = [System.Windows.Forms.DockStyle]::Bottom
$statusStrip.Font = New-Object System.Drawing.Font("Verdana", 10)
$statusStrip.GripStyle = [System.Windows.Forms.ToolStripGripStyle]::Hidden

# 1. Status-textboxen till vänster (LÅST OCH FIXERAD STORLEK)
$Global:toolStripStatusLabelLeft = New-Object System.Windows.Forms.ToolStripStatusLabel
$Global:toolStripStatusLabelLeft.Name = "toolStripStatusLabelLeft"
$Global:toolStripStatusLabelLeft.Text = "Redo"
$Global:toolStripStatusLabelLeft.AutoSize = $false
$Global:toolStripStatusLabelLeft.Size = New-Object System.Drawing.Size(450, 22)
$Global:toolStripStatusLabelLeft.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
$Global:toolStripStatusLabelLeft.ForeColor = [System.Drawing.Color]::FromArgb(45, 45, 48)

# 2. Den klickbara mittenytan (En osynlig fjäder som fyller ut hela tomrummet i mitten)
$Global:toolStripStatusSpringLeft = New-Object System.Windows.Forms.ToolStripStatusLabel
$Global:toolStripStatusSpringLeft.Spring = $true
$Global:toolStripStatusSpringLeft.Text = ""
$Global:toolStripStatusSpringLeft.Available = $true

# 3. Textetikett före rullgardinsmenyn till höger
$Global:toolStripStatusLabelEnvText = New-Object System.Windows.Forms.ToolStripStatusLabel
$Global:toolStripStatusLabelEnvText.Text = "Miljöprofil:"
$Global:toolStripStatusLabelEnvText.Font = New-Object System.Drawing.Font("Verdana", 9, [System.Drawing.FontStyle]::Bold)
$Global:toolStripStatusLabelEnvText.ForeColor = [System.Drawing.Color]::FromArgb(45, 45, 48)

# 4. Själva rullgardinsboxen för miljöerna
$Global:toolStripComboEnvironment = New-Object System.Windows.Forms.ToolStripComboBox
$Global:toolStripComboEnvironment.Size = New-Object System.Drawing.Size(140, 22)
$Global:toolStripComboEnvironment.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
$Global:toolStripComboEnvironment.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$Global:toolStripComboEnvironment.BackColor = [System.Drawing.Color]::FromArgb(45, 45, 48)
$Global:toolStripComboEnvironment.ForeColor = [System.Drawing.Color]::White
$Global:toolStripComboEnvironment.Margin = New-Object System.Windows.Forms.Padding(0, 0, 5, 0)

# =========================================================================================
# LÄS IN FYSISKA PROFILER FRÅN REGISTRET TILL DROPDOWN NERE TILL HÖGER
# =========================================================================================

# --- REGISTERLOGIK FÖR ATT SPARA OCH KOMMA IHÅG MILJÖ ---
$RegPath = "HKCU:\Software\KrimsonTools"

$Global:toolStripComboEnvironment.Add_SelectedIndexChanged({
    if ($Global:IsLoading) { return } # TOTALSPÄRR UNDER UPPSTART!
    $Global:formMain.ActiveControl = $null
    $ValdMiljo = $Global:toolStripComboEnvironment.SelectedItem.ToString()
    Write-KrimsonLog "Aktiv miljö ändrad till: $ValdMiljo"
    if (-not (Test-Path $RegPath)) { [void](New-Item -Path $RegPath -Force) }
    Set-ItemProperty -Path $RegPath -Name "LastActiveEnvironment" -Value $ValdMiljo -Force
    if ($Global:toolStripComboEnvironment.Control -and $Global:toolStripComboEnvironment.Control.Focused) {
        $Global:toolStripComboEnvironment.SelectionLength = 0
    }
})

    # --- 1. LÄS IN DE FAKTISKA PROFILERNA FRÅN REGISTRET FÖRST ---
    $Global:toolStripComboEnvironment.Items.Clear()

    $Global:IsLoading = $true

    $ProfilSokvag = "$RegPath\Settings\MiljoProfiler"
    if (Test-Path $ProfilSokvag) {
        $FysiskaMappar = Get-ChildItem -Path $ProfilSokvag | Select-Object -ExpandProperty PSChildName
        foreach ($Mapp in $FysiskaMappar) {
            [void]$Global:toolStripComboEnvironment.Items.Add($Mapp)
        }
    }

    # --- 2. HÄMTA VILKEN PROFIL SOM VAR AKTIV SENAST ---
    $LastSavedEnv = $null
    if (Test-Path $RegPath) {
        $LastSavedEnv = (Get-ItemProperty -Path $RegPath -Name "LastActiveEnvironment" -ErrorAction SilentlyContinue).LastActiveEnvironment
    }

    # --- 3. AKTIVERA RÄTT PROFIL ELLER SÄTT NEUTRAL LEDTEXT ---
    if ($LastSavedEnv -and $Global:toolStripComboEnvironment.Items.Contains($LastSavedEnv)) {
        $Global:toolStripComboEnvironment.SelectedItem = $LastSavedEnv
    } elseif ($Global:toolStripComboEnvironment.Items.Count -gt 0) {
        $Global:toolStripComboEnvironment.SelectedIndex = 0
    } else {
        $Global:toolStripComboEnvironment.SelectedIndex = -1
        $Global:toolStripComboEnvironment.Text = "Välj Miljöprofil"
    }

    $Global:IsLoading = $false

    # --- 4. UTPLÅNA DEN FULA LJUSBLÅ MARKERINGEN ENBART OM KONTROLLEN HAR FOKUS ---
    if ($Global:toolStripComboEnvironment.Control -and $Global:toolStripComboEnvironment.Control.Focused) {
        $Global:toolStripComboEnvironment.SelectionLength = 0
    }

# --- MONTERA ALLT I STATUSRADEN I EXAKT ORDNING FÖR OSYNLIG MITTENZON ---
$statusStrip.Items.AddRange(@(
    $Global:toolStripStatusLabelLeft, 
    $Global:toolStripStatusSpringLeft, # Denna osynliga fjäder tar upp hela mittendelen!
    $Global:toolStripStatusLabelEnvText,
    $Global:toolStripComboEnvironment
))

$statusStrip.Name = "statusStrip"
$statusStrip.Size = New-Object System.Drawing.Size(0, 30)

# =========================================================================================
# HOVRINGSHÄNDELSER FÖR DEN OSYNLIGA LOGG-ZONEN I MITTEN
# =========================================================================================

$Global:toolStripStatusSpringLeft.Add_MouseEnter({
    if ($Global:toolStripStatusLabelLeft) {
        # Spara undan nuvarande text så vi kan återställa den sen
        $Script:OldStatusText = $Global:toolStripStatusLabelLeft.Text
        
        # Sätt den snygga hovringstexten
        $Global:toolStripStatusLabelLeft.Text = "[Dubbelklicka för Händelselogg]"
        $Global:formMain.Refresh()
    }
})

$Global:toolStripStatusSpringLeft.Add_MouseLeave({
    if ($Global:toolStripStatusLabelLeft) {
        # Återställ till "Redo" eller vad som stod innan musen åkte in
        if ($Script:OldStatusText) {
            $Global:toolStripStatusLabelLeft.Text = $Script:OldStatusText
        } else {
            $Global:toolStripStatusLabelLeft.Text = "Redo"
        }
        $Global:formMain.Refresh()
    }
})

# --- GLOBALT OCH SKOTTSÄKERT DUBBELKLICK PÅ HELA STATUSRADEN ---
$Global:LastStatusClickTicks = 0

$Script:StatusDoubleClickHandler = {
    $CurrentTicks = [DateTime]::Now.Ticks
    $DoubleClickTicks = [System.Windows.Forms.SystemInformation]::DoubleClickTime * 10000
    
    if (($CurrentTicks - $Global:LastStatusClickTicks) -le $DoubleClickTicks) {
        
        # 1. Kör din inbyggda funktion som döljer ärenden och bygger loggen dynamiskt
        Toggle-KrimsonLogView
        
        # 2. Tvinga gränssnittet att trycka fram den nya vyn i ljuset
        $statusStrip.BringToFront()
        $Global:panelChildForm.Refresh()
        $Global:formMain.Refresh()
        
        $Global:LastStatusClickTicks = 0
    } else {
        $Global:LastStatusClickTicks = $CurrentTicks
    }
}

# =========================================================================================
# # 4. MONTERING AV KONTROLLER (DEN RENA ORIGINALORDNINGEN)
# =========================================================================================
$Global:panelChildForm.Padding = New-Object System.Windows.Forms.Padding(0, 65, 0, 0)

# 1. Skapa arbetsytan (Fill) som en stabil bottenplatta FÖRST
$Global:panelChildForm.Dock = [System.Windows.Forms.DockStyle]::Fill
$Global:formMain.Controls.Add($Global:panelChildForm)

# 2. Montera toppanelen (Top)
$panelTop.Dock = [System.Windows.Forms.DockStyle]::Top
$Global:formMain.Controls.Add($panelTop)

# 3. Montera statusraden i botten (Bottom)
$statusStrip.Dock = [System.Windows.Forms.DockStyle]::Bottom
$Global:formMain.Controls.Add($statusStrip)

# 4. Montera sidomenyn (Left)
$panelLeftContainer.Dock = [System.Windows.Forms.DockStyle]::Left
$Global:formMain.Controls.Add($panelLeftContainer)

# 5. Kör menylayouten som bygger upp ditt snygga menysystem live
Build-DynamicMenu -ParentContainer $panelLeftContainer
$pictureBoxLogo.BringToFront()

$Global:formMain.Refresh()

# =========================================================================================
# HOVRINGSHÄNDELSER FÖR LOGOTYPEN
# =========================================================================================
$pictureBoxLogo.Add_MouseEnter({
    if ($Global:toolStripStatusLabelLeft) {
        $Global:toolStripStatusLabelLeft.Text = "Settings - Konfiguration och inställningar"
        $Global:formMain.Refresh()
    }
})

$pictureBoxLogo.Add_MouseLeave({
    if ($Global:toolStripStatusLabelLeft) {
        $Global:toolStripStatusLabelLeft.Text = "Redo"
        $Global:formMain.Refresh()
    }
})

# --- GLOBALT OCH SKOTTSÄKERT DUBBELKLICK PÅ STATUSRADS-NIVÅ ---
$Script:StatusMouseHandler = {
    param($sender, $e)
    if ($e.Clicks -eq 2) {
        $Global:toolStripStatusLabelLeft.Text = "[Triggar skärmväxling...]"
        Toggle-KrimsonLogView
    }
}

# Koppla hårdvarulyssnaren till ALLA delar i botten för 100 % klick-täckning
$statusStrip.Add_MouseDown($Script:StatusMouseHandler)
$Global:toolStripStatusLabelLeft.Add_MouseDown($Script:StatusMouseHandler)
$Global:toolStripStatusSpringLeft.Add_MouseDown($Script:StatusMouseHandler)

    # Visa fönstret inuti ett try/finally block för skottsäker hantering i ISE
    try {
        Write-Host "[*] Öppnar huvudfönster..." -ForegroundColor Cyan
        [void]$Global:formMain.ShowDialog()
    }
    finally {
        # Detta körs ALLTID när fönstret stängs eller när du klickar "Stopp" i ISE
        Remove-KrimsonMemoryLeaks
    }
}

function Toggle-KrimsonLogView {
    $isLogOpen = $Global:panelChildForm.Controls.ContainsKey("panelLogView")
    $RegPath = "HKCU:\Software\KrimsonTools"
    
    if ($isLogOpen) {
        $Global:panelChildForm.Controls.Clear()
        $Global:panelChildForm.Padding = New-Object System.Windows.Forms.Padding(0, 65, 0, 0)
        
        $SavedScreen = ""
        $SavedTitle = ""
        if (Test-Path $RegPath) {
            $SavedScreen = (Get-ItemProperty -Path $RegPath -Name "LastActiveScreen" -ErrorAction SilentlyContinue).LastActiveScreen
            $SavedTitle = (Get-ItemProperty -Path $RegPath -Name "LastActiveScreenTitle" -ErrorAction SilentlyContinue).LastActiveScreenTitle
        }
        
        if (-not [string]::IsNullOrEmpty($SavedScreen)) {
            Invoke-Screen -TargetFunction $SavedScreen -TitleLeft $SavedTitle -TitleRight "KrimsonTools"
        } else {
            # Återvänd till din önskade blanka, rena arbetsskärm utan Settings-hopp!
            if ($Global:lblTitleLeft) { $Global:lblTitleLeft.Text = "" }
            if ($Global:lblTitleRight) { $Global:lblTitleRight.Text = "" }
        }
    } else {
        if ($Global:panelChildForm) { $Global:panelChildForm.Controls.Clear() }
        $Global:panelChildForm.Padding = New-Object System.Windows.Forms.Padding(0, 0, 0, 0)
        Invoke-Screen -TargetFunction "Create-FormLogView" -TitleLeft "Händelselogg" -TitleRight "Systemstatus"
        if ($Global:panelChildForm) {
            foreach ($Control in $Global:panelChildForm.Controls) {
                if ($Control.Name -eq "panelLogView") {
                    $Control.Visible = $true
                    $Control.BringToFront()
                }
            }
        }
    }
    $Global:toolStripStatusLabelLeft.Text = "Redo"
    $statusStrip.BringToFront()
    $Global:formMain.Refresh()
}

# =========================================================================================
# ZON 5: SKÄRMFUNKTIONER (Platshållare för dina vyer)
# =========================================================================================

function Create-FormLogView {
    # Skapa behållarpanelen för loggvyn
    $panelLogView = New-Object System.Windows.Forms.Panel
    $panelLogView.Name = "panelLogView"
    $panelLogView.Dock = [System.Windows.Forms.DockStyle]::Fill
    $panelLogView.BackColor = [System.Drawing.Color]::FromArgb(31, 31, 43)

    # Skapa själva textrutan där loggtexten ska visas
    $Global:txtLogView = New-Object System.Windows.Forms.RichTextBox
    $Global:txtLogView.Dock = [System.Windows.Forms.DockStyle]::Fill
    $Global:txtLogView.BackColor = [System.Drawing.Color]::FromArgb(20, 20, 30)
    $Global:txtLogView.ForeColor = [System.Drawing.Color]::LightGreen
    $Global:txtLogView.Font = New-Object System.Drawing.Font("Consolas", 10)
    $Global:txtLogView.ReadOnly = $true
    $Global:txtLogView.BorderStyle = [System.Windows.Forms.BorderStyle]::None

    # Läs in allt som hittills har sparats i minnesbufferten ($Global:LogBuffer)
    if ($Global:LogBuffer) {
        $Global:txtLogView.Text = $Global:LogBuffer.ToString()
        
        # Snygg automatiskt scroll till botten så man ser de senaste händelserna direkt
        $Global:txtLogView.SelectionStart = $Global:txtLogView.TextLength
        $Global:txtLogView.ScrollToCaret()
    }

    # Montera kontrollerna på arbetsytan
    $panelLogView.Controls.Add($Global:txtLogView)
    $Global:panelChildForm.Controls.Add($panelLogView)
}

function Create-FormSettings {
    
    # Skapa en minnesvariabel som kommer ihåg vilken profil som är öppen på skärmen JUST NU
    $Global:CurrentActiveProfileOnScreen = ""
    $Global:MatrixTextBoxes = @{}

    # 1. HUVUDPANEL (Mörkt tema) samt hantering av miljöprofiler (Dropdown, +, -)
    $panelSettings = New-Object System.Windows.Forms.Panel
    $panelSettings.Name = "panelSettings"
    $panelSettings.AutoScroll = $true
    $panelSettings.Dock = [System.Windows.Forms.DockStyle]::Fill
    $panelSettings.AutoScrollMinSize = New-Object System.Drawing.Size(0, 950)
    $panelSettings.BackColor = [System.Drawing.Color]::FromArgb(31, 31, 43)

    $FontRubrik = New-Object System.Drawing.Font("Verdana", 10, [System.Drawing.FontStyle]::Bold)
    $FontFalt = New-Object System.Drawing.Font("Verdana", 9)
    $FontEtikett = New-Object System.Drawing.Font("Verdana", 9, [System.Drawing.FontStyle]::Bold)

    # --- PROFIL-VAL (DROPDOWN) ---
    $lblVäljMiljö = New-Object System.Windows.Forms.Label
    $lblVäljMiljö.Text = "Miljöprofil:"
    $lblVäljMiljö.Font = $FontRubrik
    $lblVäljMiljö.ForeColor = [System.Drawing.Color]::FromArgb(255, 180, 0) # Krimson Orange
    $lblVäljMiljö.Location = New-Object System.Drawing.Point(30, 25)
    $lblVäljMiljö.AutoSize = $true
    $panelSettings.Controls.Add($lblVäljMiljö)

    $Global:comboEnvironments = New-Object System.Windows.Forms.ComboBox
    $Global:comboEnvironments.Location = New-Object System.Drawing.Point(180, 21) # Ändrad från 160 till 180 för perfekt linjering
    $Global:comboEnvironments.Size = New-Object System.Drawing.Size(250, 25) # Bredden anpassad så knapparna får plats efteråt
    $Global:comboEnvironments.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDown # Ändrad från DropDownList så du kan SKRIVA ett nytt namn!
    $Global:comboEnvironments.BackColor = [System.Drawing.Color]::FromArgb(20, 20, 30)
    $Global:comboEnvironments.ForeColor = [System.Drawing.Color]::White
    $Global:comboEnvironments.Font = $FontFalt # Ändrad från $FontRubrik så höjden matchar fälten under
    $panelSettings.Controls.Add($Global:comboEnvironments)

    # # Plus-KNAPP (Skapa ny profil)
    $btnPlus = New-Object System.Windows.Forms.Button
    $btnPlus.Text = "+"
    $btnPlus.Font = New-Object System.Drawing.Font("Verdana", 12, [System.Drawing.FontStyle]::Bold)
    $btnPlus.FlatStyle = [System.Windows.Forms.DockStyle]::None
    $btnPlus.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnPlus.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(255, 180, 0)
    $btnPlus.ForeColor = [System.Drawing.Color]::LightGreen
    $btnPlus.BackColor = [System.Drawing.Color]::FromArgb(20, 20, 30)
    $btnPlus.Location = New-Object System.Drawing.Point(440, 21) # Justerad position
    $btnPlus.Size = New-Object System.Drawing.Size(35, 25)
    $panelSettings.Controls.Add($btnPlus)

    # # Minus-KNAPP (Ta bort vald profil)
    $btnMinus = New-Object System.Windows.Forms.Button
    $btnMinus.Text = "-"
    $btnMinus.Font = New-Object System.Drawing.Font("Verdana", 12, [System.Drawing.FontStyle]::Bold)
    $btnMinus.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnMinus.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(255, 180, 0)
    $btnMinus.ForeColor = [System.Drawing.Color]::Red
    $btnMinus.BackColor = [System.Drawing.Color]::FromArgb(20, 20, 30)
    $btnMinus.Location = New-Object System.Drawing.Point(480, 21) # Justerad position
    $btnMinus.Size = New-Object System.Drawing.Size(35, 25)
    $panelSettings.Controls.Add($btnMinus)

# --- KLICK-HÄNDELSE FÖR PLUS-KNAPPEN (SKAPA NY PROFIL) ---
$btnPlus.Add_Click({
    # Ladda VB Interaction för en smidig InputBox-dialog
    [void][System.Reflection.Assembly]::LoadWithPartialName("Microsoft.VisualBasic")
    $NyProfil = [Microsoft.VisualBasic.Interaction]::InputBox("Ange namn på den nya miljöprofilen (t.ex. Utv, Staging, Lab):", "Skapa miljöprofil")

    if (-not [string]::IsNullOrWhiteSpace($NyProfil)) {
        $Path = "$($Global:RegPath)\$NyProfil"
        if (-not (Test-Path $Path)) {
            # 1. Skapa profilen fysiskt i registret
            New-Item -Path $Path -Force | Out-Null
            
            # 2. Uppdatera och markera i inställningsfönstrets egna rullista direkt
            Refresh-ProfileDropdown
            $Global:comboEnvironments.Text = [string]$NyProfil
            $Global:comboEnvironments.SelectedItem = [string]$NyProfil
            
            # =========================================================================================
            # LIVE-SYNKRONISERING: UPPDATERA DROPDOWN NERE TILL HÖGER DIREKT VID SKAPANDET
            # =========================================================================================
            if ($Global:toolStripComboEnvironment) {
                # Spara undan nuvarande val innan vi rensar listan
                $CurrentMainSelected = $Global:toolStripComboEnvironment.SelectedItem

                # Töm rutan på de gamla objekten
                $Global:toolStripComboEnvironment.Items.Clear()
                
                # Läs in alla fysiska mappar som faktiskt ligger i registret just nu (så att det blir rätt!)
                if (Test-Path $Global:RegPath) {
                    $Profiles = Get-ChildItem -Path $Global:RegPath | Select-Object -ExpandProperty PSChildName
                    foreach ($P in $Profiles) { 
                        [void]$Global:toolStripComboEnvironment.Items.Add($P) 
                    }
                }
                
                # ÅTERSTÄLL VALET NERE TILL HÖGER:
                # 1. Om du redan hade en aktiv profil vald på huvudskärmen, behåll den orörd!
                if ($CurrentMainSelected -and $Global:toolStripComboEnvironment.Items.Contains($CurrentMainSelected)) {
                    $Global:toolStripComboEnvironment.SelectedItem = $CurrentMainSelected
                } 
                # 2. Om rutan var helt tom innan (Välj Miljöprofil), aktivera din nya profil direkt
                else {
                    $Global:toolStripComboEnvironment.SelectedItem = $NyProfil
                }
            } # <-- Denna stänger if ($Global:toolStripComboEnvironment) klockrent
            
            [System.Windows.Forms.MessageBox]::Show("Profilen '$NyProfil' har skapats!", "Profil skapad", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
        } else {
            [System.Windows.Forms.MessageBox]::Show("En profil med det namnet finns redan.", "Fel", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
        }
    }
})

# --- KLICK-HÄNDELSE FÖR MINUS-KNAPPEN (TA BORT PROFIL) ---
$btnMinus.Add_Click({
    # 1. Frys namnet på profilen omedelbart innan WinForms hinner flytta fokus
    $ProfilAttRadera = [string]$Global:comboEnvironments.SelectedItem

    # Enkel och helt öppen spärr - så länge det inte är tomt eller våra fasta ledtexter så kör vi!
    if (-not [string]::IsNullOrWhiteSpace($ProfilAttRadera) -and $ProfilAttRadera -ne "Välj Miljöprofil" -and $ProfilAttRadera -ne "-- Inga profiler skapade --") {
        
        $Bekräfta = [System.Windows.Forms.MessageBox]::Show("Är du helt säker på att du vill ta bort profilen '$ProfilAttRadera'?", "Bekräfta borttagning", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Warning)
        
        if ($Bekräfta -eq [System.Windows.Forms.DialogResult]::Yes) {
            # --- STARTA TOTALBLOCKERING AV SPÖKHÄNDELSER ---
            $Global:IsDeleting = $true
            
            # 2. Ta bort profilen permanent från Windows-registret
            $Path = "$($Global:RegPath)\$ProfilAttRadera"
            if (Test-Path $Path) {
                Remove-Item -Path $Path -Recurse -Force
                Write-KrimsonLog "Tog bort mappen för '$ProfilAttRadera' från registret."
            }
            
            # 3. Rensa alla textrutor på skärmen live
            foreach ($Key in $Global:MatrixTextBoxes.Keys) {
                if ($Global:MatrixTextBoxes[$Key].IsDisposed -eq $false) {
                    $Global:MatrixTextBoxes[$Key].Text = ""
                }
            }
            
            # 4. Uppdatera inställningsfönstrets egna rullista
            Refresh-ProfileDropdown
            
            # 5. Uppdatera statusraden nere till höger live
            if ($Global:toolStripComboEnvironment) {
                # Kom ihåg vad som var valt i huvudfönstret innan raderingen
                $TidigareValdMain = $Global:toolStripComboEnvironment.SelectedItem
                
                $Global:toolStripComboEnvironment.Items.Clear()
                if (Test-Path $Global:RegPath) {
                    $Profiles = Get-ChildItem -Path $Global:RegPath | Select-Object -ExpandProperty PSChildName
                    foreach ($P in $Profiles) { 
                        [void]$Global:toolStripComboEnvironment.Items.Add($P) 
                    }
                }
                
            # ÅTERSTÄLL VALET NERE TILL HÖGER UTIFRÅN VAD SOM RADERADES
            if ($TidigareValdMain -and $Global:toolStripComboEnvironment.Items.Contains($TidigareValdMain)) {
                $Global:toolStripComboEnvironment.SelectedItem = $TidigareValdMain
            } 
        else {
            # 1. Töm listan och läs in ENDAST de profiler som faktiskt finns kvar i registret
            $Global:toolStripComboEnvironment.Items.Clear()
            if (Test-Path $Global:RegPath) {
                $ProfilesLeft = Get-ChildItem -Path $Global:RegPath | Select-Object -ExpandProperty PSChildName
                foreach ($P in $ProfilesLeft) { 
                    [void]$Global:toolStripComboEnvironment.Items.Add($P) 
                }
            }
            
            # 2. Sätt index till -1 (inget valt) och tvinga gränssnittet att visa ledtexten
            $Global:toolStripComboEnvironment.SelectedIndex = -1
            $Global:toolStripComboEnvironment.Text = "Välj Miljöprofil"
        
            if ($Global:toolStripComboEnvironment.Control) {
                $Global:toolStripComboEnvironment.Control.Refresh()
            }
        }
            
            # Nollställ skärmminnet helt
            $Global:CurrentActiveProfileOnScreen = $null
            
            # --- AVSLUTA BLOCKERING ---
            $Global:IsDeleting = $false
        }
        }
    }
})

    # 2. DEFINITION AV MATRISEN/TABELLEN FÖR SYSTEM OCH ROLLER
    $SystemMatris = @(
        @{ System = "SCSM";        Roll = "Server";    Desc = "SCSM Management Servrar" }
        @{ System = "SCSM";        Roll = "SQL";       Desc = "SCSM SQL Server / Instans" }
        @{ System = "SCSM";        Roll = "DB";        Desc = "SCSM Databasnamn" }
        @{ System = "Cireson";     Roll = "Web";       Desc = "Cireson Portal Webbservrar" }
        @{ System = "Cireson";     Roll = "URL";       Desc = "Cireson Web Service URL" }
        @{ System = "Cireson";     Roll = "SQL";       Desc = "Cireson SQL Server" }
        @{ System = "Cireson";     Roll = "DB";        Desc = "Cireson Portal Databasnamn" }
        @{ System = "Cireson";     Roll = "Cache";     Desc = "Cireson Cache Builder Server" }
        @{ System = "Analytics";   Roll = "SQL";       Desc = "Cireson Analytics SQL Server" }
        @{ System = "Analytics";   Roll = "DB";        Desc = "Cireson Analytics Databasnamn" }
        @{ System = "DW";          Roll = "Server";    Desc = "DataWarehouse Management Server" }
        @{ System = "DW";          Roll = "SQL";       Desc = "DataWarehouse SQL Server" }
        @{ System = "DW";          Roll = "Repo DB";   Desc = "DataWarehouse Repository Databasnamn" }
        @{ System = "DW";          Roll = "Stage DB";  Desc = "DataWarehouse Staging and Config Databasnamn" }
        @{ System = "DW";          Roll = "Mart DB";   Desc = "DataWarehouse DataMart Databasnamn" }
        @{ System = "Orc";         Roll = "Server";    Desc = "Orchestrator Runbook Server" }
        @{ System = "Orc";         Roll = "URL";       Desc = "Orchestrator Web Service URL" }
        @{ System = "Orc";         Roll = "SQL";       Desc = "Orchestrator SQL Server" }
        @{ System = "Orc";         Roll = "DB";        Desc = "Orchestrator Databasnamn" }
    )

    # --- DYNAMISK GENERERING AV MATRISEN ---

    $panelSettings.Width = $Global:panelChildForm.Width
    $panelSettings.Height = $Global:panelChildForm.Height
    $panelSettings.Anchor = [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right -bor [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Bottom

    $CurrentTop = 85

    foreach ($Rad in $SystemMatris) {
        # Rita ut orange sektionsrubrik dynamiskt om det finns angivet i matrisen
        if ($Rad.GroupHeader) {
            $CurrentTop += 15 # Extra mellanrum före rubriken
            $lblGroup = New-Object System.Windows.Forms.Label
            $lblGroup.Text = $Rad.GroupHeader
            $lblGroup.Font = New-Object System.Drawing.Font("Verdana", 10, [System.Drawing.FontStyle]::Bold)
            $lblGroup.ForeColor = [System.Drawing.Color]::FromArgb(255, 140, 0) # Kriminalvårdens Orange
            $lblGroup.Location = New-Object System.Drawing.Point(30, $CurrentTop)
            $lblGroup.Size = New-Object System.Drawing.Size(400, 25)
            $panelSettings.Controls.Add($lblGroup)
            $CurrentTop += 30 # Flytta ner för att ge plats åt fälten under
        }

        # Skapa en unik identifierare (t.ex. SCSM_Server, SCSM_SQLServer...)
        $KeyName = "$($Rad.System)_$($Rad.Roll)"

        # Textetikett för fältet (Vänster kolumn)
        $lblFalt = New-Object System.Windows.Forms.Label
        $lblFalt.Text = "$($Rad.System) $($Rad.Roll):"
        $lblFalt.Font = $FontEtikett
        $lblFalt.ForeColor = [System.Drawing.Color]::White
        $lblFalt.Location = New-Object System.Drawing.Point(30, ($CurrentTop + 3))
        $lblFalt.Size = New-Object System.Drawing.Size(140, 20)
        $panelSettings.Controls.Add($lblFalt)

        # Inmatningsbox (Mittenkolumnen - breddad för kommatecken)
        $txtFalt = New-Object System.Windows.Forms.TextBox
        $txtFalt.BackColor = [System.Drawing.Color]::FromArgb(20, 20, 30)
        $txtFalt.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle

        # Gemensamma egenskaper för både TextBox och ComboBox
        $txtFalt.Anchor = [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Right
        $txtFalt.Font = $FontFalt
        $txtFalt.ForeColor = [System.Drawing.Color]::White
        $txtFalt.Location = New-Object System.Drawing.Point(180, $CurrentTop)
        $DynamicWidth = $Global:panelChildForm.Width - 180 - 470
        $txtFalt.Size = New-Object System.Drawing.Size($DynamicWidth, 23)
        $panelSettings.Controls.Add($txtFalt)
        $Global:MatrixTextBoxes[$KeyName] = $txtFalt

        # Förklarande hjälptext (Höger kolumn)
        $lblDesc = New-Object System.Windows.Forms.Label
        $lblDesc.Text = $Rad.Desc
        $lblDesc.Font = $FontFalt
        $lblDesc.ForeColor = [System.Drawing.Color]::Gray
        $lblDesc.Location = New-Object System.Drawing.Point(($Global:panelChildForm.Width - 430), ($CurrentTop + 3))
        $lblDesc.Size = New-Object System.Drawing.Size(400, 20)
        $lblDesc.Anchor = [System.Windows.Forms.AnchorStyles]::Right -bor [System.Windows.Forms.AnchorStyles]::Top
        $panelSettings.Controls.Add($lblDesc)

        $CurrentTop += 28
    }

    # =========================================================================
    # RELEASE - MANAGEMENTPACKS (GLOBAL SEKTION)
    # =========================================================================

    # Sätt banan till den nya globala release-nyckeln under Settings (RegPath)
    $ReleaseRegPath = "$Global:RegPathBase\Release"
    
    # Skapa nyckeln i registret om den inte redan finns
    if (-not (Test-Path $ReleaseRegPath)) {
        [void](New-Item -Path $ReleaseRegPath -Force)
    }

    $CurrentTop += 30 # Skapa ett snyggt avstånd från miljöprofilerna

    # 1. Definiera din helt egna Release-matris (Här kan du fylla på med fler fält sen!)
    $ReleaseMatris = @(
        @{ System = "MP"; Roll = "Source"; Desc = "Miljöprofil att Exportera  MP's"; GroupHeader = "Release - Managementpacks" }
        @{ System = "MP"; Roll = "Target"; Desc = "Miljöprofil att Importera  MP's" }
    )

    # 2. Loopa igenom Release-matrisen för att rita ut fälten
    foreach ($Rad in $ReleaseMatris) {
        
        # Rita ut din Orangea rubrik för Release
        if ($Rad.GroupHeader) {
            $CurrentTop += 15
            $lblGroup = New-Object System.Windows.Forms.Label
            $lblGroup.Text = $Rad.GroupHeader
            $lblGroup.Font = New-Object System.Drawing.Font("Verdana", 10, [System.Drawing.FontStyle]::Bold)
            $lblGroup.ForeColor = [System.Drawing.Color]::FromArgb(255, 140, 0)
            $lblGroup.Location = New-Object System.Drawing.Point(30, $CurrentTop)
            $lblGroup.Size = New-Object System.Drawing.Size(400, 25)
            $panelSettings.Controls.Add($lblGroup)
            $CurrentTop += 30
        }

        $KeyName = "$($Rad.System)_$($Rad.Roll)"

        # Textetikett (Vänsterkolumn)
        $lblFalt = New-Object System.Windows.Forms.Label
        $lblFalt.Text = "$($Rad.System) $($Rad.Roll):"
        $lblFalt.Font = $FontEtikett
        $lblFalt.ForeColor = [System.Drawing.Color]::White
        $lblFalt.Location = New-Object System.Drawing.Point(30, ($CurrentTop + 3))
        $lblFalt.Size = New-Object System.Drawing.Size(140, 20)
        $panelSettings.Controls.Add($lblFalt)

        # Inmatningsbox (Mittenkolumn)
        $txtFalt = New-Object System.Windows.Forms.TextBox
        $txtFalt.BackColor = [System.Drawing.Color]::FromArgb(20, 20, 30)
        $txtFalt.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
        $txtFalt.Anchor = [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Right
        $txtFalt.Font = $FontFalt
        $txtFalt.ForeColor = [System.Drawing.Color]::White
        $txtFalt.Location = New-Object System.Drawing.Point(180, $CurrentTop)
        $DynamicWidth = $Global:panelChildForm.Width - 180 - 470
        $txtFalt.Size = New-Object System.Drawing.Size($DynamicWidth, 23)
        $panelSettings.Controls.Add($txtFalt)
        
        # Hämta sparade värden direkt och säkert från registernyckeln via Windows API (.GetValue)
        if (Test-Path $ReleaseRegPath) {
            $RegObj = Get-Item -Path $ReleaseRegPath -ErrorAction SilentlyContinue
            $SparatVarde = $RegObj.GetValue($KeyName, "")
            if (-not [string]::IsNullOrWhiteSpace($SparatVarde)) {
                $txtFalt.Text = $SparatVarde
            }
        }

        # Spara i en helt egen Global matris för Release-kontroller så de inte töms vid miljöbyte!
        $Global:MatrixReleaseBoxes[$KeyName] = $txtFalt

        # Förklarande hjälptext (Högerkolumn)
        $lblDesc = New-Object System.Windows.Forms.Label
        $lblDesc.Text = $Rad.Desc
        $lblDesc.Font = $FontFalt
        $lblDesc.ForeColor = [System.Drawing.Color]::Gray
        $lblDesc.Location = New-Object System.Drawing.Point(($Global:panelChildForm.Width - 430), ($CurrentTop + 3))
        $lblDesc.Size = New-Object System.Drawing.Size(400, 20)
        $lblDesc.Anchor = [System.Windows.Forms.AnchorStyles]::Right -bor [System.Windows.Forms.AnchorStyles]::Top
        $panelSettings.Controls.Add($lblDesc)

        $CurrentTop += 28
    }

# --- HÄNDELSEHANTERING FÖR DROPDOWN (LÄS FRÅN REGISTRET) ---
$Global:comboEnvironments.Add_SelectedIndexChanged({
    # TOTALSPÄRR: Om vi håller på att radera en profil, rör inte registret eller skärmen!
    if ($Global:IsDeleting) { return }

    $NyProfil = $Global:comboEnvironments.SelectedItem
    if ([string]::IsNullOrWhiteSpace($NyProfil) -or $NyProfil -eq "Välj Miljöprofil") { return }

    # 1. KÖR AUTOSAVE PÅ DEN GAMLA PROFILEN FÖRST (Om det fanns en profil öppen på skärmen)
    if (-not [string]::IsNullOrWhiteSpace($Global:CurrentActiveProfileOnScreen) -and $Global:CurrentActiveProfileOnScreen -ne "Välj Miljöprofil") {
        # Säkra sökvägen till den GAMLA profilen i registret innan vi rör textrutorna
        $GamlaProfilPath = "$($Global:RegPath)\$Global:CurrentActiveProfileOnScreen"
        if (-not (Test-Path $GamlaProfilPath)) { New-Item -Path $GamlaProfilPath -Force | Out-Null }

        # Spara innehållet från skärmen till den GAMLA profilen
        foreach ($Key in $Global:MatrixTextBoxes.Keys) {
            if ($Global:MatrixTextBoxes[$Key] -and $Global:MatrixTextBoxes[$Key].IsDisposed -eq $false) {
                Set-ItemProperty -Path $GamlaProfilPath -Name $Key -Value $Global:MatrixTextBoxes[$Key].Text -Force
}
    }

    # SPARA GLOBALA RELEASE-INSTÄLLNINGAR VID PROFILBYTE
    $ReleaseRegPath = "$Global:RegPathBase\Release"
    if (-not (Test-Path $ReleaseRegPath)) {
        [void](New-Item -Path $ReleaseRegPath -Force)
    }
    foreach ($Key in $Global:MatrixReleaseBoxes.Keys) {
        if ($Global:MatrixReleaseBoxes[$Key] -and $Global:MatrixReleaseBoxes[$Key].IsDisposed -eq $false) {
            Set-ItemProperty -Path $ReleaseRegPath -Name $Key -Value $Global:MatrixReleaseBoxes[$Key].Text -Force
        }
    }

    Write-KrimsonLog "Autosave utfört..."
}

    # 2. UPPDATERA MINNESVARIABELN TILL DEN NYA PROFILEN
    $Global:CurrentActiveProfileOnScreen = $NyProfil
    $Path = "$($Global:RegPath)\$NyProfil"

    # 3. Töm alla fält på skärmen inför laddningen
    foreach ($Key in $Global:MatrixTextBoxes.Keys) {
        if ($Global:MatrixTextBoxes[$Key] -is [System.Windows.Forms.ComboBox]) {
            $Global:MatrixTextBoxes[$Key].SelectedIndex = -1
        } else {
            $Global:MatrixTextBoxes[$Key].Text = ""
        }
    }

    # 4. Läs in värdena från registret för den NYA profilen
    if (Test-Path $Path) {
        foreach ($Key in $Global:MatrixTextBoxes.Keys) {
            $Varde = Get-ItemProperty -Path $Path -Name $Key -ErrorAction SilentlyContinue
            if ($Varde -and $Varde.$Key) {
                # Om kontrollen är en Dropdown (ComboBox), sätt SelectedItem
                if ($Global:MatrixTextBoxes[$Key] -is [System.Windows.Forms.ComboBox]) {
                    $Global:MatrixTextBoxes[$Key].SelectedItem = $Varde.$Key
                } else {
                    # Annars sätter vi .Text som vanligt för vanliga textrutor
                    $Global:MatrixTextBoxes[$Key].Text = $Varde.$Key
                }
            }
        }
    }

        # Läs in globala release-data igen på ett skottsäkert sätt via GetValue efter profilbyte
        $ReleaseRegPath = "$Global:RegPathBase\Release"
        if (Test-Path $ReleaseRegPath) {
            $RegObj = Get-Item -Path $ReleaseRegPath -ErrorAction SilentlyContinue
            foreach ($Key in $Global:MatrixReleaseBoxes.Keys) {
                $SparatVarde = $RegObj.GetValue($Key, "")
                if (-not [string]::IsNullOrWhiteSpace($SparatVarde)) {
                    $Global:MatrixReleaseBoxes[$Key].Text = $SparatVarde
                }
            }
        }
})

    # =========================================================================================
    # GLOBAL LOGGNINGS-PANEL (PLACERAS OVANFÖR SPARA-KNAPPEN)
    # =========================================================================================
    $lblLogSection = New-Object System.Windows.Forms.Label
    $lblLogSection.Text = "Global Loggningsfunktion (Gäller alla profiler)"
    $lblLogSection.Font = New-Object System.Drawing.Font("Verdana", 9, [System.Drawing.FontStyle]::Bold)
    $lblLogSection.ForeColor = [System.Drawing.Color]::FromArgb(255, 180, 0) # Orange
    $lblLogSection.Location = New-Object System.Drawing.Point(30, ($CurrentTop + 15))
    $lblLogSection.Size = New-Object System.Drawing.Size(400, 20)
    $panelSettings.Controls.Add($lblLogSection)

    # Kryssruta för att aktivera loggning
    $Global:chkLogEnabled = New-Object System.Windows.Forms.CheckBox
    $Global:chkLogEnabled.Text = "Aktivera händelseloggning till fil"
    $Global:chkLogEnabled.Font = $FontFalt
    $Global:chkLogEnabled.ForeColor = [System.Drawing.Color]::White
    $Global:chkLogEnabled.Location = New-Object System.Drawing.Point(180, ($CurrentTop + 40))
    $Global:chkLogEnabled.Size = New-Object System.Drawing.Size(300, 20)
    $Global:chkLogEnabled.Checked = $Global:LogEnabled
    $panelSettings.Controls.Add($Global:chkLogEnabled)
    # Spara direkt till registret så fort man bockar i eller ur rutan
    $Global:chkLogEnabled.Add_CheckedChanged({
            if (-not (Test-Path $Global:GlobalRegPath)) { New-Item -Path $Global:GlobalRegPath -Force | Out-Null }
            $StatusString = $Global:chkLogEnabled.Checked.ToString()
            Set-ItemProperty -Path $Global:GlobalRegPath -Name "LogEnabled" -Value $StatusString -Force
    
            # Uppdatera minnesvariabeln live så att loggningen aktiveras omedelbart
            $Global:LogEnabled = $Global:chkLogEnabled.Checked
            Write-KrimsonLog "Fil-loggning har ändrats till: $StatusString"
        })

    # Etikett för loggsökväg
    $lblLogPath = New-Object System.Windows.Forms.Label
    $lblLogPath.Text = "Sökväg Loggfil"
    $lblLogPath.Font = $FontEtikett
    $lblLogPath.ForeColor = [System.Drawing.Color]::White
    $lblLogPath.Location = New-Object System.Drawing.Point(30, ($CurrentTop + 70))
    $lblLogPath.Size = New-Object System.Drawing.Size(140, 20)
    $panelSettings.Controls.Add($lblLogPath)

    # Textruta för loggsökväg
    $Global:txtLogPath = New-Object System.Windows.Forms.TextBox
    $Global:txtLogPath.Font = $FontFalt
    $Global:txtLogPath.BackColor = [System.Drawing.Color]::FromArgb(20, 20, 30)
    $Global:txtLogPath.ForeColor = [System.Drawing.Color]::White
    $Global:txtLogPath.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $Global:txtLogPath.Location = New-Object System.Drawing.Point(180, ($CurrentTop + 67))
    $Global:txtLogPath.Size = New-Object System.Drawing.Size(340, 23)
    $Global:txtLogPath.Text = $Global:LogFilePath
    $Global:txtLogPath.Anchor = [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Top
    $panelSettings.Controls.Add($Global:txtLogPath)

    # Spara sökvägen till registret automatiskt när texten ändras
    $Global:txtLogPath.Add_TextChanged({
        if (-not (Test-Path $Global:GlobalRegPath)) { New-Item -Path $Global:GlobalRegPath -Force | Out-Null }
        Set-ItemProperty -Path $Global:GlobalRegPath -Name "LogFilePath" -Value $Global:txtLogPath.Text -Force
        $Global:LogFilePath = $Global:txtLogPath.Text
    })

    # Sätt en fast marginal (Padding) i toppen av barn-formuläret så att rullningsytan 
    # fysiskt stoppas precis under den mörkblå topppanelen. Detta eliminerar det svarta blocket helt!
    $Global:panelChildForm.Padding = New-Object System.Windows.Forms.Padding(0, 0, 0, 0)

    # Lägg till inställningspanelen
    $Global:panelChildForm.Controls.Add($panelSettings)

    # SÄKER OCH STABIL Z-ORDER JUSTERING (Utan kraschande if-parenteser)
    $panelSettings.SendToBack()
    if ($null -ne $Global:panelTop) { $Global:panelTop.BringToFront() }
    if ($null -ne $Global:panelMenu) { $Global:panelMenu.BringToFront() }

    # Fyll dropdown-listan från registret direkt vid start
    Refresh-ProfileDropdown

    # Sätt dropdownen till ett tomt neutralläge vid uppstart
    $Global:comboEnvironments.SelectedIndex = -1
    $Global:comboEnvironments.Text = "Välj Miljöprofil"

    # # Loggning
    $Global:chkLogEnabled.Checked = $Global:LogEnabled
    $Global:txtLogPath.Text = $Global:LogFilePath
}

function Create-FormForberedelseSteg1 {
    # 1. Skapa huvudpanelen för Release-vyn
    $panelRelease = New-Object System.Windows.Forms.Panel
    $panelRelease.Size = $Global:panelChildForm.Size
    $panelRelease.Dock = [System.Windows.Forms.DockStyle]::Fill
    $panelRelease.BackColor = [System.Drawing.Color]::FromArgb(31, 31, 43)

    # Rubrik
    $lblRubrik = New-Object System.Windows.Forms.Label
    $lblRubrik.Text = "Förberedelse inför release - Välj datummapp"
    $lblRubrik.Font = New-Object System.Drawing.Font("Verdana", 12, [System.Drawing.FontStyle]::Bold)
    $lblRubrik.ForeColor = [System.Drawing.Color]::White
    $lblRubrik.Location = New-Object System.Drawing.Point(30, 25)
    $lblRubrik.AutoSize = $true
    $panelRelease.Controls.Add($lblRubrik)

    # ListBox för att visa mapparna på filservern
    $Global:listBoxMappar = New-Object System.Windows.Forms.ListBox
    $Global:listBoxMappar.Location = New-Object System.Drawing.Point(30, 70)
    $Global:listBoxMappar.Size = New-Object System.Drawing.Size(400, 350)
    $Global:listBoxMappar.BackColor = [System.Drawing.Color]::FromArgb(20, 20, 30)
    $Global:listBoxMappar.ForeColor = [System.Drawing.Color]::White
    $Global:listBoxMappar.Font = New-Object System.Drawing.Font("Verdana", 10)
    $panelRelease.Controls.Add($Global:listBoxMappar)

    # --- MAPPHANTERING BASERAT PÅ AKTIV PROFIL (GET-CHILDITEM) ---
    $AktivProfil = $Global:comboEnvironments.SelectedItem
    $MappSökväg = ""

    if ($AktivProfil) {
        # Kopplar ihop vald profil med dina globala mappsökvägar
        if ($AktivProfil -eq "Prod")    { $MappSökväg = $Global:MPPath_Prod }
        if ($AktivProfil -eq "PreProd") { $MappSökväg = $Global:MPPath_PreProd }
        if ($AktivProfil -eq "Test")    { $MappSökväg = $Global:MPPath_Test }
        if ($AktivProfil -eq "IT")      { $MappSökväg = $Global:MPPath_IT }
    }

    # Kör din gamla Get-ChildItem-logik om sökvägen existerar
    if ($MappSökväg -and (Test-Path $MappSökväg)) {
        $Mappar = Get-ChildItem -Path $MappSökväg -Directory | Sort-Object LastWriteTime -Descending
        foreach ($Mapp in $Mappar) {
            [void]$Global:listBoxMappar.Items.Add($Mapp.Name)
        }
    } else {
        [void]$Global:listBoxMappar.Items.Add("Inga mappar hittades eller sökväg saknas för profil: $AktivProfil")
    }

    # Montera upp vyn i gränssnittet
    $Global:panelChildForm.Controls.Add($panelRelease)
}

function Create-FormArenden {
    Write-Host "[*] Startar Ärenden-vyn baserat på ditt original-skript..." -ForegroundColor Cyan

    # Rensa den stora högerpanelen helt först
    $Global:panelChildForm.Controls.Clear()
    
    # Skapa tabellobjektet direkt så att det existerar i minnet för DataSource
    $Global:dataGridViewArenden = New-Object System.Windows.Forms.DataGridView

    # =========================================================================================
    # 1. SKAPA ARBETSYTAN (Ett speglat fönster inuti panelen)
    # =========================================================================================
    # Vi tömmer och återanvänder den befintliga globala panelen direkt
    $Global:panelChildForm.BackColor = [System.Drawing.Color]::FromArgb(31, 31, 43)

    # =========================================================================================
    # 2. FILTERBOXAR OCH TEXT (PLATS OCH LABELS)
    # =========================================================================================
    
    # --- HANDLÄGGARE ---
    $labelArendenAnalyst = New-Object System.Windows.Forms.Label
    $labelArendenAnalyst.Text = "Handläggare:"
    $labelArendenAnalyst.ForeColor = [System.Drawing.Color]::White
    $labelArendenAnalyst.Font = New-Object System.Drawing.Font("Verdana", 10, [System.Drawing.FontStyle]::Bold) # Ändrad till Verdana
    $labelArendenAnalyst.Location = New-Object System.Drawing.Point(20, 5)
    $labelArendenAnalyst.AutoSize = $true

    $comboBoxArendenAnalyst = New-Object System.Windows.Forms.ComboBox
    $comboBoxArendenAnalyst.Location = New-Object System.Drawing.Point(20, 35) # Perfekt Y-placering för Verdana
    $comboBoxArendenAnalyst.Size = New-Object System.Drawing.Size(250, 25)
    $comboBoxArendenAnalyst.BackColor = [System.Drawing.Color]::FromArgb(20, 20, 30)
    $comboBoxArendenAnalyst.ForeColor = [System.Drawing.Color]::White
    $comboBoxArendenAnalyst.Font = New-Object System.Drawing.Font("Verdana", 9) # Ändrad till Verdana
    $comboBoxArendenAnalyst.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
    $comboBoxArendenAnalyst.Items.AddRange(@('Gedin Kerry - HK', 'Alla Handläggare'))
    $comboBoxArendenAnalyst.SelectedIndex = 0

    # --- SUPPORTGRUPP ---
    $labelArendenSupportGroup = New-Object System.Windows.Forms.Label
    $labelArendenSupportGroup.Text = "Supportgrupp:"
    $labelArendenSupportGroup.ForeColor = [System.Drawing.Color]::White
    $labelArendenSupportGroup.Font = New-Object System.Drawing.Font("Verdana", 10, [System.Drawing.FontStyle]::Bold) # Ändrad till Verdana
    $labelArendenSupportGroup.Location = New-Object System.Drawing.Point(290, 5)
    $labelArendenSupportGroup.AutoSize = $true

    $comboBoxArendenSupportGroup = New-Object System.Windows.Forms.ComboBox
    $comboBoxArendenSupportGroup.Location = New-Object System.Drawing.Point(290, 35) # Perfekt Y-placering för Verdana
    $comboBoxArendenSupportGroup.Size = New-Object System.Drawing.Size(250, 25)
    $comboBoxArendenSupportGroup.BackColor = [System.Drawing.Color]::FromArgb(20, 20, 30)
    $comboBoxArendenSupportGroup.ForeColor = [System.Drawing.Color]::White
    $comboBoxArendenSupportGroup.Font = New-Object System.Drawing.Font("Verdana", 9) # Ändrad till Verdana
    $comboBoxArendenSupportGroup.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
    $comboBoxArendenSupportGroup.Items.AddRange(@('IT Förvaltning Krimson', 'Alla Supportgrupper'))
    $comboBoxArendenSupportGroup.SelectedIndex = 0

    # =========================================================================================
    # 3. DATA GRID VIEW (Den stora ärendetabellen)
    # =========================================================================================
    $Global:dataGridViewArenden.Location = New-Object System.Drawing.Point(20, 75)
    $Global:dataGridViewArenden.Size = New-Object System.Drawing.Size(910, 490)
    $Global:dataGridViewArenden.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
    $Global:dataGridViewArenden.ScrollBars = [System.Windows.Forms.ScrollBars]::Both # Aktiverar scrollbars precis som i Settings
    $Global:dataGridViewArenden.ForeColor = [System.Drawing.Color]::White
    $Global:dataGridViewArenden.GridColor = [System.Drawing.Color]::FromArgb(43, 43, 60)
    $Global:dataGridViewArenden.BorderStyle = [System.Windows.Forms.BorderStyle]::None
    $Global:dataGridViewArenden.AutoSizeColumnsMode = [System.Windows.Forms.DataGridViewAutoSizeColumnsMode]::Fill
    $Global:dataGridViewArenden.AllowUserToAddRows = $false
    $Global:dataGridViewArenden.ReadOnly = $true
    
    # Gör radmarkeringarna mörkt orangea/krimson när man klickar på dem
    $Global:dataGridViewArenden.DefaultCellStyle.BackColor = [System.Drawing.Color]::FromArgb(31, 31, 43)
    $Global:dataGridViewArenden.DefaultCellStyle.ForeColor = [System.Drawing.Color]::White
    $Global:dataGridViewArenden.DefaultCellStyle.SelectionBackColor = [System.Drawing.Color]::FromArgb(255, 180, 0)
    $Global:dataGridViewArenden.DefaultCellStyle.SelectionForeColor = [System.Drawing.Color]::Black

    # Snygga till rubrikerna högst upp i tabellen
    $Global:dataGridViewArenden.EnableHeadersVisualStyles = $false
    $Global:dataGridViewArenden.ColumnHeadersDefaultCellStyle.BackColor = [System.Drawing.Color]::FromArgb(20, 30, 105)
    $Global:dataGridViewArenden.ColumnHeadersDefaultCellStyle.ForeColor = [System.Drawing.Color]::White

    # Bygg kolumner direkt så tabellen inte startar tom
    $dataTable = New-Object System.Data.DataTable
    [void]$dataTable.Columns.Add("Ärende Nr.")
    [void]$dataTable.Columns.Add("Beskrivning")
    [void]$dataTable.Columns.Add("Startdatum")
    
    $Row = $dataTable.NewRow()
    $Row["Ärende Nr."] = "IR12345"
    $Row["Beskrivning"] = "Här laddas dina live-ärenden automatiskt inom kort..."
    $Row["Startdatum"]  = (Get-Date).ToString("yyyy-MM-dd HH:mm")
    $dataTable.Rows.Add($Row)

    # =========================================================================================
    # 4. MONTERA OCH VISA ELEMENTEN
    # =========================================================================================
    
    # --- EVENTS: UPPDATERA DATA NÄR ANVÄNDAREN GÖR VAL ---
    $comboBoxArendenSupportGroup.Add_SelectedIndexChanged({
        Update-KrimsonArendenView -SupportGroup $comboBoxArendenSupportGroup.Text -Analyst $comboBoxArendenAnalyst.Text
    })

    $comboBoxArendenAnalyst.Add_SelectedIndexChanged({
        Update-KrimsonArendenView -SupportGroup $comboBoxArendenSupportGroup.Text -Analyst $comboBoxArendenAnalyst.Text
    })

    # Montera alla element direkt på den responsiva huvudpanelen
    $Global:panelChildForm.Controls.Add($labelArendenAnalyst)
    $Global:panelChildForm.Controls.Add($comboBoxArendenAnalyst)
    $Global:panelChildForm.Controls.Add($labelArendenSupportGroup)
    $Global:panelChildForm.Controls.Add($comboBoxArendenSupportGroup)
    $Global:panelChildForm.Controls.Add($Global:dataGridViewArenden)
    
    # Tvinga fönstret att rita upp sig direkt
    $Global:panelChildForm.BringToFront()
    $Global:panelChildForm.Refresh()

        # Dynamisk resize-lyssnare som tvingar tabellen att sträcka ut sig live när du ändrar fönsterstorlek
    $Global:panelChildForm.Add_Resize({
        $Global:dataGridViewArenden.Width = $Global:panelChildForm.Width - 40
        $Global:dataGridViewArenden.Height = $Global:panelChildForm.Height - 100
    })

    # Tvinga tabellen att räkna ut rätt maxbredd och maxhöjd direkt vid första uppstarten
    $Global:dataGridViewArenden.Width = $Global:panelChildForm.Width - 40
    $Global:dataGridViewArenden.Height = $Global:panelChildForm.Height - 100

    Update-KrimsonArendenView -SupportGroup $comboBoxArendenSupportGroup.Text -Analyst $comboBoxArendenAnalyst.Text
}

function Update-KrimsonArendenView {
    param (
        [string]$SupportGroup,
        [string]$Analyst
    )

    Write-KrimsonLog "Uppdaterar ärendelistan för Supportgrupp: '$SupportGroup' och Handläggare: '$Analyst'..."

    # Skapa en tom datatabell med samma kolumner som gränssnittet förväntar sig
    $newDataTable = New-Object System.Data.DataTable
    [void]$newDataTable.Columns.Add("Ärende Nr.")
    [void]$newDataTable.Columns.Add("Beskrivning")
    [void]$newDataTable.Columns.Add("Startdatum")

    # Kontrollera att SMLets-miljön är inläst och att vi har anslutning
    if ($Global:SMEnvironmentLoaded -eq $true) {
        try {
            # --- HÄR HÄMTAR VI RIKTIG DATA VIA SMLETS ---
            # 1. Hämta klassen för Incidenter (eller önskad ärendetyp)
            $IncidentClass = Get-SCSMClass -Name "System.WorkItem.Incident$"
            
            # 2. Hämta ärenden som matchar supportgruppen (anpassa fältnamn efter er miljö om det behövs)
            $Tickets = Get-SCSMObject -Class $IncidentClass | Where-Object { $_.TierQueue.Value -eq $SupportGroup }

            foreach ($Ticket in $Tickets) {
                # Hämta tilldelad handläggare för ärendet via relationen
                $AssignedUser = Get-SCSMRelationshipObject -BySource $Ticket | Where-Object { $_.RelationshipId -eq "System.WorkItemAssignedToUser$" } | Select-Object -ExpandProperty TargetObject
                $DisplayName = if ($AssignedUser) { $AssignedUser.DisplayName } else { "Unassigned" }

                # Filtrera på vald handläggare om användaren inte har valt "Alla Handläggare"
                if ($Analyst -eq "Alla Handläggare" -or $DisplayName -eq $Analyst) {
                    $row = $newDataTable.NewRow()
                    $row["Ärende Nr."] = $Ticket.Id
                    $row["Beskrivning"] = $Ticket.Title
                    $row["Startdatum"] = if ($Ticket.CreatedDate) { $Ticket.CreatedDate.ToString("yyyy-MM-dd HH:mm") } else { "" }
                    [void]$newDataTable.Rows.Add($row)
                }
            }
        }
        catch {
            Write-KrimsonLog "FEL: Misslyckades med att hämta live-data från SCSM: $_"
        }
    } else {
        # --- RESERVLÄGE (Om skriptet körs utanför Kriminalvårdens SM-nätverk) ---
        Write-KrimsonLog "SCSM-miljö ej tillgänglig. Genererar simulerad testdata för demonstration."
        
        $row1 = $newDataTable.NewRow()
        $row1["Ärende Nr."] = "IR99542"
        $row1["Beskrivning"] = "Lösenordsåterställning - Godstransporten"
        $row1["Startdatum"] = (Get-Date).AddHours(-2).ToString("yyyy-MM-dd HH:mm")
        [void]$newDataTable.Rows.Add($row1)

        $row2 = $newDataTable.NewRow()
        $row2["Ärende Nr."] = "IR99611"
        $row2["Beskrivning"] = "Skrivarproblem på anstalten"
        $row2["Startdatum"] = (Get-Date).AddMinutes(-30).ToString("yyyy-MM-dd HH:mm")
        [void]$newDataTable.Rows.Add($row2)
    }

    # Skicka ut den nya datan till gränssnittet OM tabellen är skapad och aktiv
    if ($Global:dataGridViewArenden -and $Global:dataGridViewArenden.IsDisposed -eq $false) {
        $Global:dataGridViewArenden.DataSource = $newDataTable
        $Global:dataGridViewArenden.Refresh()
    }
    else {
        Write-KrimsonLog "VARNING: `$Global:dataGridViewArenden är inte redo eller har tagits bort från minnet!"
    }
    
    Write-KrimsonLog "Ärendelistan har uppdaterats på skärmen."
}

function Create-FormTele2 {
    $lblTele2 = New-Object System.Windows.Forms.Label
    $lblTele2.Text = "Här kommer Tele2 Statistik-vyn att ligga!"
    $lblTele2.ForeColor = [System.Drawing.Color]::White
    $lblTele2.Font = New-Object System.Drawing.Font("Segoe UI", 12)
    $lblTele2.Location = New-Object System.Drawing.Point(30, 30)
    $lblTele2.AutoSize = $true
    $Global:panelChildForm.Controls.Add($lblTele2)
}

function Create-FormKontakter {
    $lblKontakter = New-Object System.Windows.Forms.Label
    $lblKontakter.Text = "Här kommer vyn för interna kontakter att ligga!"
    $lblKontakter.ForeColor = [System.Drawing.Color]::White
    $lblKontakter.Font = New-Object System.Drawing.Font("Segoe UI", 12)
    $lblKontakter.Location = New-Object System.Drawing.Point(30, 30)
    $lblKontakter.AutoSize = $true
    $Global:panelChildForm.Controls.Add($lblKontakter)
}

function Create-FormExportera {
Write-KrimsonLog "Initierar arbetsytan för Exportera Management Packs..."

# 1. Skapa en huvudbehållare för hela denna skärmen
$panelExportera = New-Object System.Windows.Forms.Panel
$panelExportera.Name = "panelExportera"
$panelExportera.Dock = [System.Windows.Forms.DockStyle]::Fill
$panelExportera.BackColor = [System.Drawing.Color]::FromArgb(31, 31, 43)

# 2. Lägg till en test-etikett så du ser att vyn laddas korrekt i det svarta fönstret
$lblTest = New-Object System.Windows.Forms.Label
$lblTest.Text = "Management Pack Exporter – Master Professional (Kommer snart)"
$lblTest.Font = New-Object System.Drawing.Font("Verdana", 12, [System.Drawing.FontStyle]::Bold)
$lblTest.ForeColor = [System.Drawing.Color]::White
$lblTest.Location = New-Object System.Drawing.Point(20, 20)
#$lblTest.AutoSize = true
$panelExportera.Controls.Add($lblTest)

# 3. Montera behållaren på din globala arbetsyta (panelChildForm)
$Global:panelChildForm.Controls.Add($panelExportera)
$panelExportera.BringToFront()
Write-KrimsonLog "Arbetsytan för Exportera har laddats framgångsrikt."
}

# Starta applikationen och visa fönstret!
Create-FormMain
