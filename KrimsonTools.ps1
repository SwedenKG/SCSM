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
    $LocalLibsPath   = Join-Path $ScriptRoot "Libs"
    $LocalSMLetsPath = Join-Path $ScriptRoot "SMLets"
    $TargetModule    = Join-Path $LocalSMLetsPath "SMLets.psd1"

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

# Central databas för alla dina fyra miljöer och deras tillhörande servrar
$Global:EnvironmentConfig = @{
    'Prod'    = [PSCustomObject]@{ SCSM = 'scsm-prod.domain.local'; Cireson = 'https://domain.local'; Orchestrator = 'orch-prod.domain.local'; SQL = 'sql-prod.domain.local' }
    'PreProd' = [PSCustomObject]@{ SCSM = 'scsm-preprod.domain.local'; Cireson = 'https://domain.local'; Orchestrator = 'orch-pp.domain.local'; SQL = 'sql-pp.domain.local' }
    'Test'    = [PSCustomObject]@{ SCSM = 'scsm-test.domain.local'; Cireson = 'https://domain.local'; Orchestrator = 'orch-test.domain.local'; SQL = 'sql-test.domain.local' }
    'IT'      = [PSCustomObject]@{ SCSM = 'scsm-it.domain.local'; Cireson = 'https://domain.local'; Orchestrator = 'orch-it.domain.local'; SQL = 'sql-it.domain.local' }
}

# Standardmiljö om inget finns sparat i registret ännu
$Global:ActiveEnvironment = 'PreProd'

# Dynamiska variabler som uppdateras automatiskt baserat på vald miljö
$Global:SCSMServer  = ""
$Global:CiresonURL  = ""
$Global:OrchServer  = ""
$Global:SQLServer   = ""

# Här lägger du till nya rader i framtiden om du vill utöka menyn. 
# TargetFunction MÅSTE matcha namnet på den funktion som ritar upp just den skärmen.

$Global:MenuConfig = @(
    [PSCustomObject]@{ MainMenu = 'Daily';     SubMenu = 'Ärenden';       StatusText = 'Daily - Daglig hantering av ärenden'; TargetFunction = 'Create-FormArenden' }
    [PSCustomObject]@{ MainMenu = 'Release';   SubMenu = 'Förberedelse'; StatusText = 'Release - Förberedelse inför release'; TargetFunction = 'Create-FormForberedelseSteg1' }
    [PSCustomObject]@{ MainMenu = 'Statistik'; SubMenu = 'Tele2';        StatusText = 'Statistik - Analysera data från Tele2'; TargetFunction = 'Create-FormTele2' }
    [PSCustomObject]@{ MainMenu = 'Tools';     SubMenu = 'Kontakter';     StatusText = 'Tools - Hantera interna kontakter';     TargetFunction = 'Create-FormKontakter' }
)

# Global behållare för att hålla reda på de dynamiska undermenypanelerna
$Global:SubMenuPanels = @{}

# =========================================================================================
# ZON 2: NAVIGATIONS- OCH FÖNSTERLOGIK (Hanterar skärmbyten)
# =========================================================================================

# Funktion för att dölja alla undermenyer och återställa knappfärger i sidomenyn
function Close-AllSubMenus {
    foreach ($Key in $Global:SubMenuPanels.Keys) {
        $Global:SubMenuPanels[$Key].Visible = $false
    }
    # 🛠️ RÄTTAD RAD: Använder -Name istället för -Pattern för att fungera i standard Windows PowerShell
    Get-Variable -Name "btnMain_*" -ErrorAction SilentlyContinue | ForEach-Object {
        if ($_.Value) { $_.Value.ForeColor = [System.Drawing.Color]::FromArgb(255, 255, 255) }
    }
}

# Funktion för att dynamiskt ladda en ny skärm i högerpanelen (panelChildForm)
function Invoke-Screen {
    param (
        [string]$TargetFunction,
        [string]$TitleLeft,
        [string]$TitleRight = ""
    )

    # 1. Rensa det gamla innehållet i högerfönstret så att skärmar inte ritas ovanpå varandra
    if ($Global:panelChildForm) {
        $Global:panelChildForm.Controls.Clear()
    }

    # 2. Uppdatera rubriktexterna högst upp i gränssnittet
    if ($Global:labelPanelTopLeft)  { $Global:labelPanelTopLeft.Text = $TitleLeft }
    if ($Global:labelPanelTopRight) { $Global:labelPanelTopRight.Text = $TitleRight }

    # 3. Anropa funktionen dynamiskt baserat på namnet i strängen (t.ex. 'Create-FormArenden')
    if (Get-Command $TargetFunction -ErrorAction SilentlyContinue) {
        Write-Host "[*] Laddar vy: $TargetFunction" -ForegroundColor Green
        & $TargetFunction
    } else {
        Write-Host "[X] Fel: Funktionen '$TargetFunction' kunde inte hittas i skriptet!" -ForegroundColor Red
    }
}


# =========================================================================================
# ZON 3: DEN DYNAMISKA MENYBYGGAREN (Sätter ihop sidomenyn)
# =========================================================================================

function Build-DynamicMenu {
    # Skapa den fasta sidopanelen till vänster
    $panelSideMenu = New-Object System.Windows.Forms.Panel
    $panelSideMenu.Width = 220
    $panelSideMenu.Dock = [System.Windows.Forms.DockStyle]::Left
    $panelSideMenu.BackColor = [System.Drawing.Color]::FromArgb(23, 23, 33)
    $Global:formMain.Controls.Add($panelSideMenu)

    # Gruppera menykonfigurationen per huvudmeny för att rita dem i ordning
    $MainMenus = $Global:MenuConfig | Select-Object -ExpandProperty MainMenu -Unique

    # Vi ritar upp menyerna nerifrån och upp (eller sätter en fast startposition)
    $CurrentTop = 10

    foreach ($MainMenu in $MainMenus) {
        # --- 1. SKAPA HUVUDKNAPP ---
        $btnMainMenu = New-Object System.Windows.Forms.Button
        $btnMainMenu.Name = "btnMain_$MainMenu"
        $btnMainMenu.Text = "  $MainMenu"
        $btnMainMenu.Size = New-Object System.Drawing.Size(220, 45)
        $btnMainMenu.Location = New-Object System.Drawing.Point(0, $CurrentTop)
        $btnMainMenu.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
        $btnMainMenu.FlatAppearance.BorderSize = 0
        $btnMainMenu.ForeColor = [System.Drawing.Color]::White
        $btnMainMenu.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
        $btnMainMenu.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
        $btnMainMenu.BackColor = [System.Drawing.Color]::FromArgb(23, 23, 33)

        $panelSideMenu.Controls.Add($btnMainMenu)
        $CurrentTop += 45

        # --- 2. SKAPA UNDERMENYPANEL (Behållare för underknappar) ---
        $panelSubMenu = New-Object System.Windows.Forms.Panel
        $panelSubMenu.Name = "panelSubMenu_$MainMenu"
        $panelSubMenu.Width = 220
        $panelSubMenu.BackColor = [System.Drawing.Color]::FromArgb(32, 32, 45)
        $panelSubMenu.Visible = $false # Dold som standard
        
        # Spara panelen i vår globala lista för att lätt kunna stänga den sen
        $Global:SubMenuPanels[$panelSubMenu.Name] = $panelSubMenu

        # Hämta alla undermenyer som tillhör denna huvudmeny
        $SubItems = $Global:MenuConfig | Where-Object { $_.MainMenu -eq $MainMenu }
        $SubTop = 0

        foreach ($Item in $SubItems) {
            $btnSubMenu = New-Object System.Windows.Forms.Button
            $btnSubMenu.Text = "    $($Item.SubMenu)"
            $btnSubMenu.Size = New-Object System.Drawing.Size(220, 35)
            $btnSubMenu.Location = New-Object System.Drawing.Point(0, $SubTop)
            $btnSubMenu.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
            $btnSubMenu.FlatAppearance.BorderSize = 0
            $btnSubMenu.ForeColor = [System.Drawing.Color]::FromArgb(180, 180, 190)
            $btnSubMenu.Font = New-Object System.Drawing.Font("Segoe UI", 10)
            $btnSubMenu.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft

            # Spara information på knappen så händelserna vet vad de ska göra
            $btnSubMenu.Tag = $Item

            # Hover-effekt (Highlight när man drar musen över)
            $btnSubMenu.Add_MouseEnter({
                if ($this.ForeColor -ne [System.Drawing.Color]::FromArgb(0, 122, 204)) {
                    $this.BackColor = [System.Drawing.Color]::FromArgb(43, 43, 60)
                }
            })
            $btnSubMenu.Add_MouseLeave({
                if ($this.ForeColor -ne [System.Drawing.Color]::FromArgb(0, 122, 204)) {
                    $this.BackColor = [System.Drawing.Color]::FromArgb(32, 32, 45)
                }
            })

            # Klick-händelse för undermenyn
            $btnSubMenu.Add_Click({
                # Återställ alla andra underknappars färg i denna panel
                $this.Parent.Controls | ForEach-Object { 
                    $_.ForeColor = [System.Drawing.Color]::FromArgb(180, 180, 190) 
                    $_.BackColor = [System.Drawing.Color]::FromArgb(32, 32, 45)
                }
                # Highlighta den klickade knappen (Krimson Blå text)
                $this.ForeColor = [System.Drawing.Color]::FromArgb(0, 122, 204)
                
                # Starta den dynamiska skärmen!
                $Data = $this.Tag
                Invoke-Screen -TargetFunction $Data.TargetFunction -TitleLeft $Data.SubMenu -TitleRight $Data.StatusText
            })

            $panelSubMenu.Controls.Add($btnSubMenu)
            $SubTop += 35
        }

        # Sätt höjden på panelen baserat på hur många knappar den har
        $panelSubMenu.Height = $SubTop
        $panelSideMenu.Controls.Add($panelSubMenu)
        $panelSubMenu.Location = New-Object System.Drawing.Point(0, $CurrentTop)
        $CurrentTop += $panelSubMenu.Height

        # Klick-händelse för huvudmenyn (Öppna/stäng undermenyn)
        $btnMainMenu.Add_Click({
            $TargetPanelName = "panelSubMenu_$($this.Text.Trim())"
            $TargetPanel = $Global:SubMenuPanels[$TargetPanelName]

            if ($TargetPanel.Visible) {
                $TargetPanel.Visible = $false
                $this.ForeColor = [System.Drawing.Color]::White
            } else {
                # Stäng alla andra först
                Close-AllSubMenus
                # Öppna denna
                $TargetPanel.Visible = $true
                $this.ForeColor = [System.Drawing.Color]::FromArgb(0, 122, 204)
            }
            # Uppdatera layouten (flytta knappar under om det behövs)
            Refresh-MenuLayout
        })
    }
}

# Hjälpfunktion för att flytta knappar upp/ner när menyer öppnas/stängs
function Refresh-MenuLayout {
    $SideMenu = $Global:formMain.Controls | Where-Object { $_.Width -eq 220 -and $_ -ne $Global:panelChildForm }
    $CurrentTop = 10
    
    # Sortera kontrollerna så de flyttas i rätt ordning
    $Controls = $SideMenu.Controls | Sort-Object Location.Y
    foreach ($Control in $Controls) {
        if ($Control.Name -like "btnMain_*") {
            $Control.Location = New-Object System.Drawing.Point(0, $CurrentTop)
            $CurrentTop += 45
            
            $SubName = "panelSubMenu_$($Control.Name.Substring(8))"
            $SubPanel = $Global:SubMenuPanels[$SubName]
            if ($SubPanel -and $SubPanel.Visible) {
                $SubPanel.Location = New-Object System.Drawing.Point(0, $CurrentTop)
                $CurrentTop += $SubPanel.Height
            }
        }
    }
}



# =========================================================================================
# ZON 4: REGISTERHANTERING, INSTÄLLNINGAR OCH HUVUDFÖNSTER (WinForms)
# =========================================================================================

$Global:RegPath = "HKCU:\Software\KrimsonTools"
$Global:SCSMServer = "scsm-server.domain.local" # Standard fallback om registret är tomt

# Funktion för att hämta inställningar från registret
function Get-KrimsonSettings {
    if (Test-Path $Global:RegPath) {
        $Settings = Get-ItemProperty -Path $Global:RegPath -ErrorAction SilentlyContinue
        if ($Settings.SCSMServer) { $Global:SCSMServer = $Settings.SCSMServer }
    }
}

# Funktion för att spara inställningar till registret
function Save-KrimsonSettings {
    param ([string]$ServerName)
    if (-not (Test-Path $Global:RegPath)) {
        New-Item -Path "HKCU:\Software" -Name "KrimsonTools" -Force | Out-Null
    }
    Set-ItemProperty -Path $Global:RegPath -Name "SCSMServer" -Value $ServerName -Force
    $Global:SCSMServer = $ServerName
    Write-Host "[✓] Inställningar sparade i registret: $ServerName" -ForegroundColor Green
}

# Dold inställningsvy (öppnas via dubbelklick på loggan)
function Show-FormSettings {
    $formSettings = New-Object System.Windows.Forms.Form
    $formSettings.Text = "KrimsonTools - Inställningar"
    $formSettings.Size = New-Object System.Drawing.Size(400,200)
    $formSettings.StartPosition = "CenterParent"
    $formSettings.FormBorderStyle = "FixedDialog"
    $formSettings.MaximizeBox = $false

    $lblServer = New-Object System.Windows.Forms.Label
    $lblServer.Text = "SCSM Server:"
    $lblServer.Location = New-Object System.Drawing.Point(20,30)
    $lblServer.Size = New-Object System.Drawing.Size(100,20)

    $txtServer = New-Object System.Windows.Forms.TextBox
    $txtServer.Text = $Global:SCSMServer
    $txtServer.Location = New-Object System.Drawing.Point(130,27)
    $txtServer.Size = New-Object System.Drawing.Size(220,20)

    $btnSave = New-Object System.Windows.Forms.Button
    $btnSave.Text = "Spara"
    $btnSave.Location = New-Object System.Drawing.Point(275,100)
    $btnSave.DialogResult = [System.Windows.Forms.DialogResult]::OK

    $formSettings.Controls.AddRange(@($lblServer, $txtServer, $btnSave))

    if ($formSettings.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        Save-KrimsonSettings -ServerName $txtServer.Text
        if ($Global:labelPanelTopRight) { $Global:labelPanelTopRight.Text = "Server: $Global:SCSMServer" }
    }
}

# HUVUDFÖNSTER (Skapar själva grundskalet)
function Create-FormMain {
    [void][System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")
    [void][System.Reflection.Assembly]::LoadWithPartialName("System.Drawing")

    # Läs miljöval från registret direkt vid start
    Get-KrimsonSettings 

    # HUVUDFÖNSTER
    $Global:formMain = New-Object System.Windows.Forms.Form
    $Global:formMain.Text = "KrimsonTools v1.0"
    $Global:formMain.Size = New-Object System.Drawing.Size(1200, 800)
    $Global:formMain.StartPosition = "CenterScreen"
    $Global:formMain.BackColor = [System.Drawing.Color]::FromArgb(31, 31, 43)

    # =========================================================================================
    # 1. SIDOMENY BEHÅLLARE (VÄNSTER)
    # =========================================================================================
    $panelLeftContainer = New-Object System.Windows.Forms.Panel
    $panelLeftContainer.Width = 220
    $panelLeftContainer.Dock = [System.Windows.Forms.DockStyle]::Left
    $panelLeftContainer.BackColor = [System.Drawing.Color]::FromArgb(23, 23, 33)
    $Global:formMain.Controls.Add($panelLeftContainer)

    # Logo-panel (Högst upp till vänster, fast höjd 80)
    $panelLogo = New-Object System.Windows.Forms.Panel
    $panelLogo.Size = New-Object System.Drawing.Size(220, 80)
    $panelLogo.Location = New-Object System.Drawing.Point(0, 0)
    $panelLogo.BackColor = [System.Drawing.Color]::FromArgb(23, 23, 33)
    
    # Din logotyp-ruta (Här dubbelklickar du för att byta miljö!)
    $pictureBoxLogo = New-Object System.Windows.Forms.PictureBox
    $pictureBoxLogo.Size = New-Object System.Drawing.Size(180, 50)
    $pictureBoxLogo.Location = New-Object System.Drawing.Point(20, 15)
    $pictureBoxLogo.BackColor = [System.Drawing.Color]::FromArgb(0, 122, 204) # Loggan
    $pictureBoxLogo.Add_DoubleClick({ Show-FormSettings })
    $panelLogo.Controls.Add($pictureBoxLogo)
    $panelLeftContainer.Controls.Add($panelLogo)

    # =========================================================================================
    # 2. TOPPANEL (RUBRIK OCH MILJÖINFO HÖGST UPP)
    # =========================================================================================
    $panelTop = New-Object System.Windows.Forms.Panel
    $panelTop.Height = 60
    $panelTop.Dock = [System.Windows.Forms.DockStyle]::Top
    $panelTop.BackColor = [System.Drawing.Color]::FromArgb(37, 37, 56)

    # Rubrik som ändras dynamiskt via Invoke-Screen (t.ex. "Ärenden")
    $Global:labelPanelTopLeft = New-Object System.Windows.Forms.Label
    $Global:labelPanelTopLeft.Text = "KrimsonTools"
    $Global:labelPanelTopLeft.ForeColor = [System.Drawing.Color]::White
    $Global:labelPanelTopLeft.Font = New-Object System.Drawing.Font("Segoe UI", 16, [System.Drawing.FontStyle]::Bold)
    $Global:labelPanelTopLeft.Location = New-Object System.Drawing.Point(20, 15)
    $Global:labelPanelTopLeft.AutoSize = $true

    # Miljö- och serverstatus till höger
    $Global:labelPanelTopRight = New-Object System.Windows.Forms.Label
    $Global:labelPanelTopRight.Text = "Miljö: [$Global:ActiveEnvironment] | Server: $Global:SCSMServer"
    $Global:labelPanelTopRight.ForeColor = [System.Drawing.Color]::LightGray
    $Global:labelPanelTopRight.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $Global:labelPanelTopRight.Location = New-Object System.Drawing.Point(500, 20)
    $Global:labelPanelTopRight.Anchor = [System.Windows.Forms.AnchorStyles]::Right
    $Global:labelPanelTopRight.AutoSize = $true

    $panelTop.Controls.AddRange(@($Global:labelPanelTopLeft, $Global:labelPanelTopRight))
    $Global:formMain.Controls.Add($panelTop)

    # =========================================================================================
    # 3. HÖGERPANELEN (Fyller ut hela det resterande utrymmet till höger)
    # =========================================================================================
    $Global:panelChildForm = New-Object System.Windows.Forms.Panel
    $Global:panelChildForm.Dock = [System.Windows.Forms.DockStyle]::Fill 
    $Global:panelChildForm.BackColor = [System.Drawing.Color]::FromArgb(31, 31, 43)
    $Global:formMain.Controls.Add($Global:panelChildForm)

    # 🛠️ HÄR STARTAR VI MENYN: Vi skickar med behållaren till Build-DynamicMenu
    Build-DynamicMenu -ParentPanel $panelLeftContainer

    # Visa fönstret
    [System.Windows.Forms.Application]::Run($Global:formMain)
}




# =========================================================================================
# ZON 5: SKÄRMFUNKTIONER (Platshållare för dina vyer)
# =========================================================================================

function Create-FormArenden {
    Write-Host "[*] Anpassar Ärenden-vyn till din exakta original-look..." -ForegroundColor Cyan

    # Rensa panelen helt först så inga gamla bildelement (som den blå fyrkanten) ligger kvar
    $Global:panelChildForm.Controls.Clear()

    # =========================================================================================
    # 1. TOPPANEL FÖR FILTER (Mörkt färgblock klistrat högst upp)
    # =========================================================================================
    $panelFilter = New-Object System.Windows.Forms.Panel
    $panelFilter.Height = 80
    $panelFilter.Dock = [System.Windows.Forms.DockStyle]::Top
    $panelFilter.BackColor = [System.Drawing.Color]::FromArgb(45, 45, 45) # Din exakta mörka filterfärg

    # --- FILTER 1: HANDLÄGGARE ---
    $lblHandlaggare = New-Object System.Windows.Forms.Label
    $lblHandlaggare.Text = "Handläggare"
    $lblHandlaggare.Location = New-Object System.Drawing.Point(20, 12)
    $lblHandlaggare.Size = New-Object System.Drawing.Size(150, 20)
    $lblHandlaggare.ForeColor = [System.Drawing.Color]::FromArgb(160, 160, 160)
    $lblHandlaggare.Font = New-Object System.Drawing.Font("Segoe UI", 10)

    $comboBoxHandlaggare = New-Object System.Windows.Forms.ComboBox
    $comboBoxHandlaggare.Location = New-Object System.Drawing.Point(20, 37)
    $comboBoxHandlaggare.Size = New-Object System.Drawing.Size(250, 25)
    $comboBoxHandlaggare.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
    $comboBoxHandlaggare.Items.AddRange(@('Gedin Kerry - HK', 'Alla Handläggare'))
    $comboBoxHandlaggare.SelectedIndex = 0

    # --- FILTER 2: SUPPORTGROUP ---
    $lblSupport = New-Object System.Windows.Forms.Label
    $lblSupport.Text = "Supportgroup"
    $lblSupport.Location = New-Object System.Drawing.Point(645, 12)
    $lblSupport.Size = New-Object System.Drawing.Size(150, 20)
    $lblSupport.ForeColor = [System.Drawing.Color]::FromArgb(160, 160, 160)
    $lblSupport.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $lblSupport.Anchor = [System.Windows.Forms.AnchorStyles]::Right

    $comboBoxSupport = New-Object System.Windows.Forms.ComboBox
    $comboBoxSupport.Location = New-Object System.Drawing.Point(645, 37)
    $comboBoxSupport.Size = New-Object System.Drawing.Size(255, 25)
    $comboBoxSupport.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
    $comboBoxSupport.Items.AddRange(@('IT Förvaltning Krimson', 'Alla Supportgrupper'))
    $comboBoxSupport.SelectedIndex = 0
    $comboBoxSupport.Anchor = [System.Windows.Forms.AnchorStyles]::Right

    $panelFilter.Controls.AddRange(@($lblHandlaggare, $comboBoxHandlaggare, $lblSupport, $comboBoxSupport))

    # =========================================================================================
    # 2. DATA GRID VIEW (Den stora grå tabellen som fyller resten av ytan)
    # =========================================================================================
    $Global:dataGridViewArenden = New-Object System.Windows.Forms.DataGridView
    $Global:dataGridViewArenden.Dock = [System.Windows.Forms.DockStyle]::Fill # Fyller ut ALLY yta under filtren
    $Global:dataGridViewArenden.BackgroundColor = [System.Drawing.Color]::FromArgb(160, 160, 160) # Din ljusgrå tabellfärg
    $Global:dataGridViewArenden.BorderStyle = [System.Windows.Forms.BorderStyle]::None
    $Global:dataGridViewArenden.AutoSizeColumnsMode = [System.Windows.Forms.DataGridViewAutoSizeColumnsMode]::Fill
    $Global:dataGridViewArenden.AllowUserToAddRows = $false
    $Global:dataGridViewArenden.ReadOnly = $true
    
    # Grid-linjer och cell-styling för att matcha stilen
    $Global:dataGridViewArenden.EnableHeadersVisualStyles = $false
    $Global:dataGridViewArenden.ColumnHeadersDefaultCellStyle.BackColor = [System.Drawing.Color]::FromArgb(240, 240, 240)
    $Global:dataGridViewArenden.DefaultCellStyle.BackColor = [System.Drawing.Color]::FromArgb(160, 160, 160)
    $Global:dataGridViewArenden.DefaultCellStyle.ForeColor = [System.Drawing.Color]::Black

    # Skapa och koppla tabell-data
    $dataTable = New-Object System.Data.DataTable
    [void]$dataTable.Columns.Add("ID")
    [void]$dataTable.Columns.Add("Titel")
    [void]$dataTable.Columns.Add("Status")
    [void]$dataTable.Columns.Add("Skapad")
    
    $Row = $dataTable.NewRow()
    $Row["ID"]     = "IR12345"
    $Row["Titel"]  = "Här laddas dina SCSM-ärenden automatiskt..."
    $Row["Status"] = "Aktiv"
    $Row["Skapad"] = (Get-Date).ToString("yyyy-MM-dd HH:mm")
    $dataTable.Rows.Add($Row)
    $Global:dataGridViewArenden.DataSource = $dataTable

    # =========================================================================================
    # 3. KOPPLING TILL PROJEKTET
    # =========================================================================================
    # VIKTIGT: Lägg till tabellen FÖRST och filtret SIST när vi använder Dock, annars hamnar de bakom varandra!
    $Global:panelChildForm.Controls.Add($Global:dataGridViewArenden)
    $Global:panelChildForm.Controls.Add($panelFilter)
    
    $Global:panelChildForm.BringToFront()
    $Global:panelChildForm.Refresh()
}




function Create-FormForberedelseSteg1 {
    $lblRelease = New-Object System.Windows.Forms.Label
    $lblRelease.Text = "Här kommer dina releaseförberedelser och mappar (Get-ChildItem) att ligga!"
    $lblRelease.ForeColor = [System.Drawing.Color]::White
    $lblRelease.Font = New-Object System.Drawing.Font("Segoe UI", 12)
    $lblRelease.Location = New-Object System.Drawing.Point(30, 30)
    $lblRelease.AutoSize = $true
    $Global:panelChildForm.Controls.Add($lblRelease)
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







# Starta applikationen och visa fönstret!
Create-FormMain

