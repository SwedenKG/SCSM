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
    param (
        [string]$TargetFunction,
        [string]$TitleLeft,
        [string]$TitleRight = ""
    )

    # Nollställ inställningsflaggan så fort vi laddar en vanlig skärm
    $Global:SettingsIsOpen = $false

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
    $CurrentTop = 135

    foreach ($MainMenu in $MainMenus) {
        # --- 1. SKAPA HUVUDKNAPP ---
        $btnMainMenu = New-Object System.Windows.Forms.Button
        $btnMainMenu.Name = "btnMain_$MainMenu"
        $btnMainMenu.Text = $MainMenu
        $btnMainMenu.Size = New-Object System.Drawing.Size($panelSideMenu.Width, 40)
        $btnMainMenu.Location = New-Object System.Drawing.Point(0, $CurrentTop)
        $btnMainMenu.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
        $btnMainMenu.FlatAppearance.BorderSize = 0
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
                $Global:toolStripStatusLabelLeft.Text = ""
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
                    $Global:toolStripStatusLabelLeft.Text = ""
                }
            })

            # Klick-händelse för undermenyn
            $btnSubMenu.Add_Click({
                # Starta den dynamiska skärmen!
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
            $TargetPanelName = "panelSubMenu_$($this.Text.Trim())"
            $TargetPanel = $Global:SubMenuPanels[$TargetPanelName]

            if ($TargetPanel.Visible) {
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
    $CurrentTop = 135
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
# ZON 4: REGISTERHANTERING, INSTÄLLNINGAR OCH HUVUDFÖNSTER (WinForms)
# =========================================================================================

# =========================================================================================
# GLOBAL LOGGNINGSFUNKTION (ZON 4)
# =========================================================================================
$Global:GlobalRegPath = "HKCU:\Software\KrimsonTools\Settings\Global"
$Global:LogBuffer = New-Object "System.Text.StringBuilder"

# Läs in globala logginställningar från registret (Standard: Av, log.txt bredvid skriptet)
$Global:LogEnabled = $false
$Global:LogFilePath = Join-Path $PSScriptRoot "KrimsonTools_Log.txt"

if (Test-Path $Global:GlobalRegPath) {
    $RegLogEnabled = Get-ItemProperty -Path $Global:GlobalRegPath -Name "LogEnabled" -ErrorAction SilentlyContinue
    if ($RegLogEnabled) { $Global:LogEnabled = [System.Convert]::ToBoolean($RegLogEnabled.LogEnabled) }
    
    $RegLogPath = Get-ItemProperty -Path $Global:GlobalRegPath -Name "LogFilePath" -ErrorAction SilentlyContinue
    if ($RegLogPath) { $Global:LogFilePath = $RegLogPath.LogFilePath }
}

function Write-KrimsonLog {
    param (
        [string]$Message
    )
    # Skapa tidsstämpel: [2026-10-22 16:00:05]
    $TimeStamp = [DateTime]::Now.ToString("yyyy-MM-dd HH:mm:ss")
    $LogLine = "[$TimeStamp] $Message"
    
    # Skriv till internminnes-buffer (så att loggvisaren kan läsa den blixtsnabbt)
    [void]$Global:LogBuffer.AppendLine($LogLine)
    
    # Om loggvisaren är öppen live just nu, uppdatera dess textruta direkt
    if ($Global:txtLogView -and $Global:txtLogView.IsDisposed -eq $false) {
        $Global:txtLogView.AppendText($LogLine + [Environment]::NewLine)
    }
    
    # Om loggning är aktiverad till fil, skriv direkt till textfilen
    if ($Global:LogEnabled -eq $true) {
        try {
            $LogLine | Out-File -FilePath $Global:LogFilePath -Append -Encoding utf8 -ErrorAction SilentlyContinue
        } catch {}
    }
}

$Global:RegPath = "HKCU:\Software\KrimsonTools\Settings\MiljoProfiler"
$Global:SCSMServer = "scsm-server.domain.local" # Standard fallback om registret är tomt

# Funktion för att läsa in profiler från registret till dropdown
function Refresh-ProfileDropdown {
    $Global:comboMiljöer.Items.Clear()
    if (Test-Path $Global:RegPath) {
        $SubKeys = Get-ChildItem -Path $Global:RegPath | Select-Object -ExpandProperty PSChildName
        foreach ($Key in $SubKeys) {
            [void]$Global:comboMiljöer.Items.Add($Key)
        }
    }
    # Fallback om registret är helt tomt vid första start
    if ($Global:comboMiljöer.Items.Count -eq 0) {
        foreach ($Standard in @("Prod", "PreProd", "Test", "IT")) {
            [void]$Global:comboMiljöer.Items.Add($Standard)
        }
    }
    $Global:comboMiljöer.SelectedIndex = -1
    $Global:comboMiljöer.Text = "-- Välj Miljöprofil --"
}

function Save-KrimsonSettings {
    # 1. Hämta namnet på den aktiva profilen just nu
    $AktivProfil = $Global:comboMiljöer.Text
    if ([string]::IsNullOrWhiteSpace($AktivProfil) -or $AktivProfil -eq "-- Välj Miljöprofil --") { return }

    # Säkra sökvägen i registret för profilen
    $ProfilPath = "$($Global:RegPath)\$AktivProfil"
    if (-not (Test-Path $ProfilPath)) { New-Item -Path $ProfilPath -Force | Out-Null }

    # Loopa igenom matrisen och spara alla 15/17 profilfält om de existerar i minnet
    if ($Global:MatrixTextBoxes) {
        foreach ($Key in $Global:MatrixTextBoxes.Keys) {
            if ($Global:MatrixTextBoxes[$Key] -and $Global:MatrixTextBoxes[$Key].IsDisposed -eq $false) {
                Set-ItemProperty -Path $ProfilPath -Name $Key -Value $Global:MatrixTextBoxes[$Key].Text -Force
            }
        }
    }

    # 2. Spara de globala logginställningarna (om kontrollerna finns på skärmen just nu)
    if ($Global:chkLogEnabled -and $Global:chkLogEnabled.IsDisposed -eq $false) {
        if (-not (Test-Path $Global:GlobalRegPath)) { New-Item -Path $Global:GlobalRegPath -Force | Out-Null }
        
        $StatusString = $Global:chkLogEnabled.Checked.ToString()
        Set-ItemProperty -Path $Global:GlobalRegPath -Name "LogEnabled" -Value $StatusString -Force
        Set-ItemProperty -Path $Global:GlobalRegPath -Name "LogFilePath" -Value $Global:txtLogPath.Text -Force

        # Uppdatera minnesvariablerna live
        $Global:LogEnabled = $Global:chkLogEnabled.Checked
        $Global:LogFilePath = $Global:txtLogPath.Text
    }

    Write-KrimsonLog "Autosave utfört: Inställningar för profilen '$AktivProfil' och global logg har sparats."
}

# Funktion för att hämta inställningar från registret
function Get-KrimsonSettings {
    if (-not (Test-Path $Global:RegPath)) {
        New-Item -Path $Global:RegPath -Force | Out-Null
    }
}

# Funktion för att spara inställningar till registret


# HUVUDFÖNSTER (Skapar själva grundskalet)
function Create-FormMain {

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

    # HUVUDFÖNSTER
    $Global:formMain = New-Object System.Windows.Forms.Form
    $Global:formMain.Text = "KrimsonTools v1.0"
    $Global:formMain.Size = New-Object System.Drawing.Size(1200, 800)
    $Global:formMain.StartPosition = "CenterScreen"
    $Global:formMain.BackColor = [System.Drawing.Color]::FromArgb(31, 31, 43)

    # =========================================================================================
    # 1. SIDOMENY BEHÅLLARE (VÄNSTER)
    # =========================================================================================
    # --- # 1. SIDOMENY BEHÅLLARE (Vänster) ---
    $panelLeftContainer = New-Object System.Windows.Forms.Panel
    $panelLeftContainer.Width = 240
    $panelLeftContainer.Dock = [System.Windows.Forms.DockStyle]::Left
    $panelLeftContainer.BackColor = [System.Drawing.Color]::FromArgb(20, 30, 105)

    # Klistra in din långa Base64-textsträng från gamla Tools.ps1 mellan citattecknen:
    $logoBase64String = $Global:logoBase64String

    # Konvertera binärsträngen till en bild i minnet
    $imageBytes = [System.Convert]::FromBase64String($logoBase64String)
    $ms = New-Object System.IO.MemoryStream($imageBytes, 0, $imageBytes.Length)
    $ms.Write($imageBytes, 0, $imageBytes.Length)
    $ms.Position = 0  # <--- DENNA RAD SÄKRAR ATT BILDEN LÄSES FRÅN BÖRJAN!
    $logoImage = [System.Drawing.Image]::FromStream($ms, $true)

    # Din logotyp-ruta (Klickbar med hand-muspekare)
    $pictureBoxLogo = New-Object System.Windows.Forms.PictureBox
    $pictureBoxLogo.Location = New-Object System.Drawing.Point(12, 18)
    $pictureBoxLogo.BackColor = [System.Drawing.Color]::Transparent
    $pictureBoxLogo.SizeMode = [System.Windows.Forms.PictureBoxSizeMode]::AutoSize
    $pictureBoxLogo.Image = $logoImage
        
    # Ändra muspekaren till en hand när man hovrar över loggan
    $pictureBoxLogo.Cursor = [System.Windows.Forms.Cursors]::Hand

    # Klick-händelse: Öppnar inställningarna direkt
    $pictureBoxLogo.Add_Click({
    
    # Kontrollera direkt i minnet om panelSettings fysiskt ligger på arbetsytan
    $IsSettingsOpen = $Global:panelChildForm.Controls.ContainsKey("panelSettings")
    
    if ($IsSettingsOpen -eq $true) {
        # Om den finns öppen -> Töm arbetsytan direkt så den blir helt tom och ren till höger
        $Global:panelChildForm.Controls.Clear()
        
        # Nollställ även titlarna i toppanelen så de försvinner
        if ($Global:lblTitleLeft) { $Global:lblTitleLeft.Text = "" }
        if ($Global:lblTitleRight) { $Global:lblTitleRight.Text = "" }
        
        $Global:formMain.Refresh()
        Write-KrimsonLog "Stängde konfigurationsskärmen via logotypen."
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
    # HÄR SKAPAS DEN GLOBALA VARIABELN SOM MENYN BEHÖVER:
    $Global:toolStripStatusLabelLeft = New-Object System.Windows.Forms.ToolStripStatusLabel
    $Global:toolStripStatusLabelLeft.Name = "toolStripStatusLabelLeft"
    $Global:toolStripStatusLabelLeft.Text = ""
    $Global:toolStripStatusLabelLeft.Margin = New-Object System.Windows.Forms.Padding(0, 1, 0, 0)

    $statusStrip = New-Object System.Windows.Forms.StatusStrip
    $statusStrip.AutoSize = $False
    $statusStrip.BackColor = [System.Drawing.Color]::FromArgb(255, 180, 0) # Orange #FFB400
    $statusStrip.Dock = [System.Windows.Forms.DockStyle]::Bottom
    $statusStrip.Font = New-Object System.Drawing.Font("Verdana", 10)
    $statusStrip.GripStyle = [System.Windows.Forms.ToolStripGripStyle]::Hidden
    $statusStrip.Items.AddRange($Global:toolStripStatusLabelLeft)
    $statusStrip.Name = "statusStrip"
    $statusStrip.Size = New-Object System.Drawing.Size(0, 28)

    # =========================================================================================
    # 4. MONTERING AV KONTROLLER (DEN DEFINITIVA ORIGINALORDNINGEN)
    # =========================================================================================
    
    $Global:panelChildForm.Padding = New-Object System.Windows.Forms.Padding(0, 65, 0, 0)

    # 1. Montera arbetsytan (Fill) ALLRA FÖRST. I WinForms innebär detta att den tar ytan som blir över 
    # efter att de andra kontrollerna har mutat in sina kanter.
    $Global:panelChildForm.Dock = [System.Windows.Forms.DockStyle]::Fill
    $Global:formMain.Controls.Add($Global:panelChildForm)
    
    # 2. Montera toppanelen (Top)
    $panelTop.Dock = [System.Windows.Forms.DockStyle]::Top
    $Global:formMain.Controls.Add($panelTop)
    
    # 3. Montera statusraden i botten (Bottom)
    $statusStrip.Dock = [System.Windows.Forms.DockStyle]::Bottom
    $Global:formMain.Controls.Add($statusStrip)
    
    # 4. Montera sidomenyn (Left) ALLRA SIST. Då spärrar den vänsterkanten från tak till botten 
    # och trycker undan både toppanelen, statusraden och arbetsytan till höger!
    $panelLeftContainer.Dock = [System.Windows.Forms.DockStyle]::Left
    $Global:formMain.Controls.Add($panelLeftContainer)
    
    # 5. Kör menylayouten så att den slimmade bredden räknas ut dynamiskt
    Build-DynamicMenu -ParentContainer $panelLeftContainer
    $pictureBoxLogo.BringToFront()

    # Tvinga fönstret att uppdatera grafiken
    $Global:formMain.Refresh()

    # =========================================================================================
    # HOVRINGSHÄNDELSER FÖR LOGOTYPEN (Placerade efter att statusraden har skapats)
    # =========================================================================================
    
    $pictureBoxLogo.Add_MouseEnter({
        if ($Global:toolStripStatusLabelLeft) {
            $Global:toolStripStatusLabelLeft.Text = "Settings - Konfiguration och inställningar"
            $Global:formMain.Refresh() # Tvingar hela fönstret att rita om sig och visa texten direkt
        }
    })

    $pictureBoxLogo.Add_MouseLeave({
        if ($Global:toolStripStatusLabelLeft) {
            $Global:toolStripStatusLabelLeft.Text = ""
            $Global:formMain.Refresh() # Tvingar fönstret att rensa bort texten direkt
        }
    })

    # =========================================================================================
    # DUBBELKLICK-TUNNEL FÖR LOGGVISAREN PÅ STATUSRADEN (SWITCH-FUNKTION)
    # =========================================================================================
    $statusStrip.Add_DoubleClick({
        # Kontrollera om loggvisaren redan är öppen och synlig
        $IsLogOpen = $Global:panelChildForm.Controls | Where-Object { $_.Name -eq "panelLogView" }
        
        if ($IsLogOpen) {
            # Om den är öppen -> Töm och återställ till tomt rent läge
            $Global:panelChildForm.Controls.Clear()
            if ($Global:labelTitleLeft) { $Global:labelTitleLeft.Text = "" }
            if ($Global:labelTitleRight) { $Global:labelTitleRight.Text = "" }
            $Global:LogViewIsOpen = $false
            $Global:formMain.Refresh()
            Write-KrimsonLog "Stängde händelseloggen via statusraden."
        }
        else {
            # Om den inte är öppen -> Kör Invoke-Screen för att rita ut loggvisaren
            $Global:LogViewIsOpen = $true
            Invoke-Screen -TargetFunction "Create-FormLogView" -TitleLeft "Händelselogg" -TitleRight "Systemhändelser"
        }
    })

    # Skriv den första raden i loggen precis innan gränssnittet öppnas
    Write-KrimsonLog "KrimsonTools GUI startades - Gränssnitt helt inläst."

    # Visa fönstret
    [System.Windows.Forms.Application]::Run($Global:formMain)
}

# =========================================================================================
# ZON 5: SKÄRMFUNKTIONER (Platshållare för dina vyer)
# =========================================================================================

function Create-FormSettings {
    
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

    $Global:comboMiljöer = New-Object System.Windows.Forms.ComboBox
    $Global:comboMiljöer.Location = New-Object System.Drawing.Point(180, 21) # Ändrad från 160 till 180 för perfekt linjering
    $Global:comboMiljöer.Size = New-Object System.Drawing.Size(250, 25) # Bredden anpassad så knapparna får plats efteråt
    $Global:comboMiljöer.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDown # Ändrad från DropDownList så du kan SKRIVA ett nytt namn!
    $Global:comboMiljöer.BackColor = [System.Drawing.Color]::FromArgb(20, 20, 30)
    $Global:comboMiljöer.ForeColor = [System.Drawing.Color]::White
    $Global:comboMiljöer.Font = $FontFalt # Ändrad från $FontRubrik så höjden matchar fälten under
    $panelSettings.Controls.Add($Global:comboMiljöer)

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
                New-Item -Path $Path -Force | Out-Null
                Refresh-ProfileDropdown
                $Global:comboMiljöer.SelectedItem = $NyProfil
                [System.Windows.Forms.MessageBox]::Show("Profilen '$NyProfil' har skapats!", "Profil skapad", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
            } else {
                [System.Windows.Forms.MessageBox]::Show("En profil med det namnet finns redan.", "Fel", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
            }
        }
    })

    # --- KLICK-HÄNDELSE FÖR MINUS-KNAPPEN (TA BORT VALD PROFIL) ---
    $btnMinus.Add_Click({
        $ValdProfil = $Global:comboMiljöer.SelectedItem
        if ($ValdProfil) {
            $Bekräfta = [System.Windows.Forms.MessageBox]::Show("Är du helt säker på att du vill ta bort profilen '$ValdProfil' och alla dess serverinställningar?", "Bekräfta borttagning", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Question)
            
            if ($Bekräfta -eq [System.Windows.Forms.DialogResult]::Yes) {
                $Path = "$($Global:RegPath)\$ValdProfil"
                if (Test-Path $Path) {
                    Remove-Item -Path $Path -Recurse -Force
                }
                Refresh-ProfileDropdown
            }
        }
    })

    # 2. DEFINITION AV MATRISEN/TABELLEN FÖR SYSTEM OCH ROLLER
    $SystemMatris = @(
        @{ System = "SCSM";         Roll = "Server";    Desc = "SCSM Management Servrar" }
        @{ System = "SCSM";         Roll = "SQL"; Desc = "SCSM SQL Server / Instans" }
        @{ System = "SCSM";         Roll = "DB";    Desc = "SCSM Databasnamn" }
        @{ System = "Cireson";      Roll = "Web";    Desc = "Cireson Portal Webbservrar" }
        @{ System = "Cireson";      Roll = "SQL"; Desc = "Cireson SQL Server" }
        @{ System = "Cireson";      Roll = "DB";    Desc = "Cireson Portal Databasnamn" }
        @{ System = "Cireson";      Roll = "Cache";  Desc = "Cireson Cache Builder Server" }
        @{ System = "Analytics";    Roll = "SQL";    Desc = "Cireson Analytics SQL Server" }
        @{ System = "Analytics";    Roll = "DB";     Desc = "Cireson Analytics Databasnamn" }
        @{ System = "DW";           Roll = "Server";    Desc = "DataWarehouse Management Server" }
        @{ System = "DW";           Roll = "SQL"; Desc = "DataWarehouse SQL Server" }
        @{ System = "DW";           Roll = "Repo DB"; Desc = "DataWarehouse Repository Databasnamn" }
        @{ System = "DW";           Roll = "Stage DB";Desc = "DataWarehouse Staging and Config Databasnamn" }
        @{ System = "DW";           Roll = "Mart DB"; Desc = "DataWarehouse DataMart Databasnamn" }
        @{ System = "Orc";          Roll = "Server";    Desc = "Orchestrator Runbook Server / Web Service URL" }
        @{ System = "Orc";          Roll = "SQL"; Desc = "Orchestrator SQL Server" }
        @{ System = "Orc";          Roll = "DB";    Desc = "Orchestrator Databasnamn" }
    )

    # --- DYNAMISK GENERERING AV MATRISEN ---
    $CurrentTop = 85

    foreach ($Rad in $SystemMatris) {
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
        $txtFalt.Anchor = [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Top
        $txtFalt.Font = $FontFalt
        $txtFalt.BackColor = [System.Drawing.Color]::FromArgb(20, 20, 30)
        $txtFalt.ForeColor = [System.Drawing.Color]::White
        $txtFalt.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
        $txtFalt.Location = New-Object System.Drawing.Point(180, $CurrentTop)
        $txtFalt.Size = New-Object System.Drawing.Size(340, 23)
        $panelSettings.Controls.Add($txtFalt)
        $Global:MatrixTextBoxes[$KeyName] = $txtFalt

        # Förklarande hjälptext (Höger kolumn)
        $lblDesc = New-Object System.Windows.Forms.Label
        $lblDesc.Text = $Rad.Desc
        $lblDesc.Font = $FontFalt
        $lblDesc.ForeColor = [System.Drawing.Color]::Gray
        $lblDesc.Location = New-Object System.Drawing.Point(540, ($CurrentTop + 3))
        $lblDesc.Size = New-Object System.Drawing.Size(400, 20)
        $lblDesc.Anchor = [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Top
        $panelSettings.Controls.Add($lblDesc)

        $CurrentTop += 28
    }

    # --- HÄNDELSEHANTERING FÖR DROPDOWN (LÄS FRÅN REGISTRET) ---
    $Global:comboMiljöer.Add_SelectedIndexChanged({
    $ValdProfil = $Global:comboMiljöer.SelectedItem

    # SPÄRR: Gör absolut ingenting om starttexten är aktiv eller om valet är tomt!
    if ([string]::IsNullOrWhiteSpace($ValdProfil) -or $ValdProfil -eq "-- Välj Miljöprofil --") { 
        return 
    }

    # Kör autosave för den förra profilen, och läs sedan in den nya!
    Save-KrimsonSettings

    $Path = "$($Global:RegPath)\$ValdProfil"
            
            # Töm alla fält först ifall profilen är ny eller saknar värden
            foreach ($Key in $Global:MatrixTextBoxes.Keys) {
                $Global:MatrixTextBoxes[$Key].Text = ""
            }

            # Om nyckeln finns i registret, läs in värdena till rätt textruta
            if (Test-Path $Path) {
                foreach ($Key in $Global:MatrixTextBoxes.Keys) {
                    $Varde = Get-ItemProperty -Path $Path -Name $Key -ErrorAction SilentlyContinue
                    if ($Varde -and $Varde.$Key) {
                        $Global:MatrixTextBoxes[$Key].Text = $Varde.$Key
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

    $Global:panelChildForm.Controls.Add($panelSettings)

    # Fyll dropdown-listan från registret direkt vid start
    Refresh-ProfileDropdown
    
    # Tvinga textrutorna att läsa in värdena för den profil som automatiskt valdes i dropdownen
    $Global:comboMiljöer.SelectedIndex = 0

}

function Create-FormLogView {
    Write-KrimsonLog "Öppnar intern händelselogg..."

    $panelLogView = New-Object System.Windows.Forms.Panel
    $panelLogView.Name = "panelLogView"
    $panelLogView.Dock = [System.Windows.Forms.DockStyle]::Fill
    $panelLogView.BackColor = [System.Drawing.Color]::FromArgb(20, 20, 30)

    # Stor, låst textruta för loggen
    $Global:txtLogView = New-Object System.Windows.Forms.TextBox
    $Global:txtLogView.Multiline = $true
    $Global:txtLogView.ScrollBars = [System.Windows.Forms.ScrollBars]::Vertical
    $Global:txtLogView.Font = New-Object System.Drawing.Font("Consolas", 9.5)
    $Global:txtLogView.BackColor = [System.Drawing.Color]::FromArgb(15, 15, 22)
    $Global:txtLogView.ForeColor = [System.Drawing.Color]::LightGray
    $Global:txtLogView.BorderStyle = [System.Windows.Forms.BorderStyle]::None
    $Global:txtLogView.Dock = [System.Windows.Forms.DockStyle]::Fill
    $Global:txtLogView.ReadOnly = $true

    # Hämta allt som sparats i vår StringBuilder-buffer under sessionen
    if ($Global:LogBuffer) {
        $Global:txtLogView.Text = $Global:LogBuffer.ToString()
    }
    
    # Skrolla automatiskt ner till sista loggraden
    $Global:txtLogView.SelectionStart = $Global:txtLogView.Text.Length
    $Global:txtLogView.ScrollToCaret()

    $panelLogView.Controls.Add($Global:txtLogView)
    $Global:panelChildForm.Controls.Add($panelLogView)
    $panelLogView.BringToFront()
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
    $AktivProfil = $Global:comboMiljöer.SelectedItem
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
