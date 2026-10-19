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

    # 1. Rensa och frigör minnet från alla gamla kontroller så att inte ISE hänger sig
    if ($Global:panelChildForm) {
        while ($Global:panelChildForm.Controls.Count -gt 0) {
            $OldControl = $Global:panelChildForm.Controls[0]
            $Global:panelChildForm.Controls.Remove($OldControl)
            $OldControl.Dispose()
        }
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
    # 🛠️ 1. Lägg till parametern här så funktionen kan ta emot behållaren från Create-FormMain
    param($ParentContainer) 

    # Skapa den fasta sidopanelen till vänster
    $panelSideMenu = New-Object System.Windows.Forms.Panel
    $panelSideMenu.Width = 220
    $panelSideMenu.Dock = [System.Windows.Forms.DockStyle]::Left
    $panelSideMenu.BackColor = [System.Drawing.Color]::FromArgb(20, 30, 105)
    
    # 🛠️ 2. Ändra till variabeln från parametern här!
    $ParentContainer.Controls.Add($panelSideMenu)

    # Gruppera menykonfigurationen per huvudmeny för att rita dem i ordning
    $MainMenus = $Global:MenuConfig | Select-Object -ExpandProperty MainMenu -Unique

    # Vi ritar upp menyerna nerifrån och upp (eller sätter en fast startposition)
    $CurrentTop = 120

    foreach ($MainMenu in $MainMenus) {
        # --- 1. SKAPA HUVUDKNAPP ---
        $btnMainMenu = New-Object System.Windows.Forms.Button
        $btnMainMenu.Name = "btnMain_$MainMenu"
        $btnMainMenu.Text = "  $MainMenu"
        $btnMainMenu.Size = New-Object System.Drawing.Size(220, 40)
        $btnMainMenu.Location = New-Object System.Drawing.Point(0, $CurrentTop)
        $btnMainMenu.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
        $btnMainMenu.FlatAppearance.BorderSize = 0
        $btnMainMenu.ForeColor = [System.Drawing.Color]::White
        $btnMainMenu.Font = New-Object System.Drawing.Font("Verdana", 14, [System.Drawing.FontStyle]::Bold)
        $btnMainMenu.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
        $btnMainMenu.BackColor = [System.Drawing.Color]::FromArgb(20, 30, 105)

        $panelSideMenu.Controls.Add($btnMainMenu)
        $CurrentTop += 40

        # --- 2. SKAPA UNDERMENYPANEL (Behållare för underknappar) ---
        $panelSubMenu = New-Object System.Windows.Forms.Panel
        $panelSubMenu.Name = "panelSubMenu_$MainMenu"
        $panelSubMenu.Width = 220
        $panelSubMenu.BackColor = [System.Drawing.Color]::FromArgb(20, 30, 105)
        $panelSubMenu.Visible = $false # Dold som standard
        
        # Spara panelen i vår globala lista för att lätt kunna stänga den sen
        $Global:SubMenuPanels[$panelSubMenu.Name] = $panelSubMenu

        # Hämta alla undermenyer som tillhör denna huvudmeny
        $SubItems = $Global:MenuConfig | Where-Object { $_.MainMenu -eq $MainMenu }
        $SubTop = 0

        foreach ($Item in $SubItems) {
            $btnSubMenu = New-Object System.Windows.Forms.Button
            $btnSubMenu.Text = "    $($Item.SubMenu)"
            $btnSubMenu.Size = New-Object System.Drawing.Size(220, 40)
            $btnSubMenu.Location = New-Object System.Drawing.Point(0, $SubTop)
            $btnSubMenu.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
            $btnSubMenu.FlatAppearance.BorderSize = 0
            $btnSubMenu.ForeColor = [System.Drawing.Color]::FromArgb(180, 180, 190)
            $btnSubMenu.Font = New-Object System.Drawing.Font("Verdana", 14)
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
            $SubTop += 40
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
            #Refresh-MenuLayout
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
    $panelLogo.Size = New-Object System.Drawing.Size(220, 110)
    $panelLogo.Location = New-Object System.Drawing.Point(0, 0)
    $panelLogo.BackColor = [System.Drawing.Color]::FromArgb(23, 23, 33)
    
    # Din logotyp-ruta (Här dubbelklickar du för att byta miljö!)
    $pictureBoxLogo = New-Object System.Windows.Forms.PictureBox
    $pictureBoxLogo.Size = New-Object System.Drawing.Size(180, 50)
    $pictureBoxLogo.Location = New-Object System.Drawing.Point(20, 30)
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

    # 🛠️ HÄR STARTAR VI MENYN:
    Build-DynamicMenu -ParentContainer $panelLeftContainer

    # Visa fönstret
    [System.Windows.Forms.Application]::Run($Global:formMain)
}

# =========================================================================================
# ZON 5: SKÄRMFUNKTIONER (Platshållare för dina vyer)
# =========================================================================================

function Create-formÄrenden {
    Write-Host "[*] Startar Ärenden-vyn baserat på ditt original-skript..." -ForegroundColor Cyan

    # Rensa den stora högerpanelen helt först
    $Global:panelChildForm.Controls.Clear()

    # =========================================================================================
    # 1. SKAPA ARBETSYTAN (Ett speglat fönster inuti panelen)
    # =========================================================================================
    $formTickets = New-Object System.Windows.Forms.Form
    $formTickets.TopLevel = $False
    $formTickets.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None
    $formTickets.BackColor = [System.Drawing.Color]::FromArgb(31, 31, 43) # Matchar huvudfönstrets mörka färg
    $formTickets.Dock = [System.Windows.Forms.DockStyle]::Fill

    # =========================================================================================
    # 2. FILTERBOXAR OCH TEXT (PLATS OCH LABELS)
    # =========================================================================================
    
    # --- HANDLÄGGARE ---
    $labelÄrendenAnalyst = New-Object System.Windows.Forms.Label
    $labelÄrendenAnalyst.Text = "Handläggare"
    $labelÄrendenAnalyst.ForeColor = [System.Drawing.Color]::FromArgb(160, 160, 160)
    $labelÄrendenAnalyst.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $labelÄrendenAnalyst.Location = New-Object System.Drawing.Point(20, 15)
    $labelÄrendenAnalyst.AutoSize = $True

    $comboBoxÄrendenAnalyst = New-Object System.Windows.Forms.ComboBox
    $comboBoxÄrendenAnalyst.Location = New-Object System.Drawing.Point(20, 40)
    $comboBoxÄrendenAnalyst.Size = New-Object System.Drawing.Size(250, 25)
    $comboBoxÄrendenAnalyst.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
    $comboBoxÄrendenAnalyst.Items.AddRange(@('Gedin Kerry - HK', 'Alla Handläggare'))
    $comboBoxÄrendenAnalyst.SelectedIndex = 0

    # --- SUPPORTGROUP ---
    $labelÄrendenSupportGroup = New-Object System.Windows.Forms.Label
    $labelÄrendenSupportGroup.Text = "Supportgroup"
    $labelÄrendenSupportGroup.ForeColor = [System.Drawing.Color]::FromArgb(160, 160, 160)
    $labelÄrendenSupportGroup.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $labelÄrendenSupportGroup.Location = New-Object System.Drawing.Point(650, 15)
    $labelÄrendenSupportGroup.Anchor = [System.Windows.Forms.AnchorStyles]::Right
    $labelÄrendenSupportGroup.AutoSize = $True

    $comboBoxÄrendenSupportGroup = New-Object System.Windows.Forms.ComboBox
    $comboBoxÄrendenSupportGroup.Location = New-Object System.Drawing.Point(650, 40)
    $comboBoxÄrendenSupportGroup.Size = New-Object System.Drawing.Size(250, 25)
    $comboBoxÄrendenSupportGroup.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
    $comboBoxÄrendenSupportGroup.Items.AddRange(@('IT Förvaltning Krimson', 'Alla Supportgrupper'))
    $comboBoxÄrendenSupportGroup.SelectedIndex = 0
    $comboBoxÄrendenSupportGroup.Anchor = [System.Windows.Forms.AnchorStyles]::Right

    # =========================================================================================
    # 3. DATA GRID VIEW (Den stora ärendetabellen)
    # =========================================================================================
    $Global:dataGridViewÄrenden = New-Object System.Windows.Forms.DataGridView
    $Global:dataGridViewÄrenden.Location = New-Object System.Drawing.Point(20, 90)
    $Global:dataGridViewÄrenden.Size = New-Object System.Drawing.Size(880, 500)
    $Global:dataGridViewÄrenden.Anchor = [System.Windows.Forms.AnchorStyles]@"
Top, Bottom, Left, Right
"@
    # Snygg design på tabellen
    $Global:dataGridViewÄrenden.BackgroundColor = [System.Drawing.Color]::FromArgb(160, 160, 160) # Din ljusgrå färg enligt skiss
    $Global:dataGridViewÄrenden.ForeColor = [System.Drawing.Color]::Black
    $Global:dataGridViewÄrenden.BorderStyle = [System.Windows.Forms.BorderStyle]::None
    $Global:dataGridViewÄrenden.AutoSizeColumnsMode = [System.Windows.Forms.DataGridViewAutoSizeColumnsMode]::Fill
    $Global:dataGridViewÄrenden.AllowUserToAddRows = $False
    $Global:dataGridViewÄrenden.ReadOnly = $True
    $Global:dataGridViewÄrenden.EnableHeadersVisualStyles = $False
    $Global:dataGridViewÄrenden.ColumnHeadersDefaultCellStyle.BackColor = [System.Drawing.Color]::FromArgb(240, 240, 240)

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
    $Global:dataGridViewÄrenden.DataSource = $dataTable

    # =========================================================================================
    # 4. MONTERA OCH VISA ELEMENTEN
    # =========================================================================================
    # Lägg till kontrollerna i fönstret $formTickets
    $formTickets.Controls.AddRange(@(
        $labelÄrendenAnalyst, $comboBoxÄrendenAnalyst,
        $labelÄrendenSupportGroup, $comboBoxÄrendenSupportGroup,
        $Global:dataGridViewÄrenden
    ))

    # Montera $formTickets inuti huvudpanelen
    $Global:panelChildForm.Controls.Add($formTickets)
    $formTickets.Show()
    
    # Tvinga fönstret att rita upp sig direkt
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

