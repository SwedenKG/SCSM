
#region functionsDaily

function buttonDaily_Click{
    if($panelSubMenuDaily.Visible -eq $true){
        # Hide SubMenuDaily
        $buttonDaily.ForeColor="255,255,255" # Vit
        $panelSubMenuDaily.Visible=$false
    }
    else{
 
    # Open panelSubMenuDaily
    $buttonDaily.ForeColor="255,180,0" # Orange
    $panelSubMenuDaily.Visible=$true
 
    # Close panelSubMenuRelease
    $buttonRelease.ForeColor="255,255,255" # Vit
    $panelSubMenuRelease.Visible=$false
 
    # Close panelSubMenuTools
    $panelSubMenuTools.Visible=$false
    $buttonTools.ForeColor="255,255,255" # Vit
 
    }
}

function buttonDaily_MouseHover{
    $toolStripStatusLabelLeft.Text = "Daily - Dagliga rutiner"
}

function buttonDaily_MouseLeave{
    $toolStripStatusLabelLeft.Text = ""
}

function buttonÄrenden_Click{
    # Close panelSubMenuDaily
    $buttonDaily.ForeColor="255,255,255" # Vit
    $panelSubMenuDaily.Visible=$false
 
    # Start Ärenden
    $labelPanelTopLeft.Text = "Daily - Ärenden"
    $labelPanelTopRight.Text = ""
 
    #
    #$panelChildForm.Controls.Clear()
    Create-formÄrenden
    #$panelChildForm.Controls.Add($formÄrenden)
    #$formÄrenden.Show()

    #
    $ÄrendenColumns = @(
           'Ärende Nr.'
           'Beskrivning'
           'Startdatum'
    )

    #
    $dataTableÄrenden = New-Object System.Data.DataTable
    [void]$dataTableÄrenden.Columns.AddRange($TicketsColumns)

    # $Ärenden = Get-KV -ServiceRequest | Select-Object $ÄrendenColumns

    #foreach($Ärende in $Ärenden){
    #    $Entry=@()
    #    foreach($ÄrendenColumn in $ÄrendenColums){
    #        $Entry += $Ticket.$ÄrendenColum
    #    }
    #    [void]$dataTableÄrenden.Rows.Add($Entry)
    #}

       
}

function buttonÄrenden_MouseHover{
    $toolStripStatusLabelLeft.Text = "Ärenden - Daglig hantering av ärenden"
}

function buttonÄrenden_MouseLeave{
    $toolStripStatusLabelLeft.Text = ""
}

#endregion
#region functionsRelease

function buttonRelease_Click{
    if($panelSubMenuRelease.Visible -eq $true){
        # Hide SubMenuRelease
        $buttonRelease.ForeColor = "255,255,255" # Vit
        $panelSubMenuRelease.Visible=$false
 
        #
        # Create formRelease1
        #$formRelease1=New-Object System.Windows.Forms.Form
        #$formRelease1.ClientSize="600,400"
        #$formRelease1.BackColor="10,10,10"
        #$formRelease1.FormBorderStyle="None"
        # Add formRelease1 to panelSubMenuDaily
        #$panelSubMenuDaily.Controls.Add($formRelease1)
    }
    else{
 
    # Hide SubMenuDaily
    $buttonDaily.ForeColor="255,255,255" # Vit
    $panelSubMenuDaily.Visible=$false            
    # Show SubMenuRelease
    $buttonRelease.ForeColor="255,180,0" # Orange
    $panelSubMenuRelease.Visible=$true
 
    # Hide SubMenuTools
    $panelSubMenuTools.Visible=$false
    $buttonTools.ForeColor="255,255,255" # Vit
    }
}

function buttonRelease_MouseHover{
    $toolStripStatusLabelLeft.Text = "Release - Driftsättning"
}

function buttonRelease_MouseLeave{
    $toolStripStatusLabelLeft.Text = ""
}

function buttonFörberedelse_Click{

    # Close panelSubMenuRelease
    $buttonDaily.ForeColor="255,255,255" # Vit
    $panelSubMenuRelease.Visible=$false
 
    # Start Förberedelse
    $labelPanelTopLeft.Text = "Release - Datum och tid"
    $labelPanelTopRight.Text = "Steg 1 av 99"
 
    #
    #$panelChildForm.Controls.Clear()
    
    Create-formFörberedelseSteg1
    #$panelChildForm.Controls.Add($formFörberedelseSteg1)
    #$formFörberedelseSteg1.Show()

    #


}

function buttonFörberedelse_MouseHover{
    $toolStripStatusLabelLeft.Text = "Release - Förberedelse inför release"
}

function buttonFörberedelse_MouseLeave{
    $toolStripStatusLabelLeft.Text = ""
}

function buttonFörberedelseCancel_Click{
        # Tillbaka till Menyn
        #####################
        $labelPanelTopLeft.Text = ""
        $labelPanelTopRight.Text = ""

        #
        $panelChildForm.Controls.Clear()
        MenuClose
}

function buttonFörberedelseSteg1Next_Click{
    
    # Close panelSubMenuRelease
    #$buttonDaily.ForeColor="255,255,255" # Vit
    #$panelSubMenuRelease.Visible=$false
 
    # Start Förberedelse
    $labelPanelTopLeft.Text = "Release - Förberedelser"
    $labelPanelTopRight.Text = "Steg 2 av 99"
 
    #
    #$panelChildForm.Controls.Clear()
    
    Create-formFörberedelseSteg2
    #$panelChildForm.Controls.Add($formFörberedelseSteg1)
    #$formFörberedelseSteg1.Show()

    #
}

function buttonFörberedelseSteg2Back_Click{
    
    #$panelChildForm.Controls.Clear()
    Create-formFörberedelseSteg1


}

function buttonFörberedelseSteg2Next_Click{
    # Close panelSubMenuRelease
    #$buttonDaily.ForeColor="255,255,255" # Vit
    #$panelSubMenuRelease.Visible=$false
 
    # Start Förberedelse
    $labelPanelTopLeft.Text = "Release - Backup MP(Management Packs)"
    $labelPanelTopRight.Text = "Steg 3 av 99"
 
    #
    #$panelChildForm.Controls.Clear()
    
    Create-formFörberedelseSteg3
    #$panelChildForm.Controls.Add($formFörberedelseSteg1)
    #$formFörberedelseSteg1.Show()

    #
}

function buttonFörberedelseSteg3Next_Click{
    # Close panelSubMenuRelease
    #$buttonDaily.ForeColor="255,255,255" # Vit
    #$panelSubMenuRelease.Visible=$false
 
    # Start Förberedelse
    $labelPanelTopLeft.Text = "Release - Hämta MP(Management Packs)"
    $labelPanelTopRight.Text = "Steg 4 av 99"
 
    #
    #$panelChildForm.Controls.Clear()
    
    Create-formFörberedelseSteg4
    #$panelChildForm.Controls.Add($formFörberedelseSteg1)
    #$formFörberedelseSteg1.Show()

    #    
}

#endregion
#region functionsStatistik

function buttonStatistik_Click{
    if($panelSubMenuStatistik.Visible -eq $true){
        # Close panelSubMenuStatistik
        $buttonStatistik.ForeColor="255,255,255" # Vit
        $panelSubMenuStatistik.Visible=$false
    }
    else{
 
    # Open panelSubMenuStatistik
    $buttonStatistik.ForeColor="255,180,0" # Orange
    $panelSubMenuStatistik.Visible=$true
 
    # Close panelSubMenuDaily
    $buttonDaily.ForeColor="255,255,255" # Vit
    $panelSubMenuDaily.Visible=$false

    # Close panelSubMenuRelease
    $buttonRelease.ForeColor="255,255,255" # Vit
    $panelSubMenuRelease.Visible=$false
 
    # Close panelSubMenuTools
    $panelSubMenuTools.Visible=$false
    $buttonTools.ForeColor="255,255,255" # Vit
 
    }
}

function buttonStatistik_MouseHover{
    $toolStripStatusLabelLeft.Text = "Statistik - Analysera och presentera data"
}

function buttonStatistik_MouseLeave{
    $toolStripStatusLabelLeft.Text = ""
}

#endregion
#region functionsTools

function buttonTools_Click{
    if($panelSubMenuTools.Visible -eq $true){
        # Close panelSubMenuTools
        $buttonTools.ForeColor="255,255,255" # Vit
        $panelSubMenuTools.Visible=$false
    }
    else{
 
    # Open panelSubMenuTools
    $buttonTools.ForeColor="255,180,0" # Orange
    $panelSubMenuTools.Visible=$true
 
    # Close panelSubMenuDaily
    $buttonDaily.ForeColor="255,255,255" # Vit
    $panelSubMenuDaily.Visible=$false

    # Close panelSubMenuRelease
    $buttonRelease.ForeColor="255,255,255" # Vit
    $panelSubMenuRelease.Visible=$false
 
    # Close panelSubMenuStatistik
    $panelSubMenuStatistik.Visible=$false
    $buttonStatistik.ForeColor="255,255,255" # Vit
 
    }
}

function buttonTools_MouseHover{
    $toolStripStatusLabelLeft.Text = "Tools - Diverse verktyg"
}

function buttonTools_MouseLeave{
    $toolStripStatusLabelLeft.Text = ""
}

#endregion

function MenuClose{


        # Hide SubMenuDaily
        $buttonDaily.ForeColor="255,255,255" # Vit
        $panelSubMenuDaily.Visible=$false


        # Hide SubMenuRelease
        $buttonRelease.ForeColor = "255,255,255" # Vit
        $panelSubMenuRelease.Visible=$false

    
}

function Create-formMain{
#region formMain

    # Skapa formMain
    $formMain = New-Object System.Windows.Forms.Form
    $formMain.Font = "Verdana,14"
    $formMain.MinimumSize = "640,480"
    $formMain.Name = "formMain"
    $formMain.Size = "1024,640"
    $formMain.StartPosition = "CenterScreen"
    $formMain.Text = "Krimson Tool v0.1"

    # Skapa formMain's icon
    [String]$iconBase64=@"
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
AAAAAAAAvKKXWGkeFP9pHhT/aR4U/2keFP9pHhT/aR4U/2keFP9pHhT/aR4U/2keFP9pHhT/aR4U/2keFP9pHhT/aR4U/2keFP9pHhT/aR4U/2keFP9pHhT/aR4U/2keFP9pHhT/
aR4U/7yil1gAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALyi
l1ggse7AE7L01ROy9NUTsvTVE7L01ROy9NUTsvTVE7L01ROy9NUTsvTVE7L01ROy9NUTsvTVE7L01ROy9NUTsvTVE7L01ROy9NUTsvTVE7L01ROy9NUvr+SsvKKXWO/n3yAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAtP/fALT//wC0
//8AtP//ALT//wC0//8AtP//ALT//wC0//8AtP//ALT//wC0//8AtP//ALT//wC0//8AtP//ALT//wC0//8AtP//ALT//wC0//8AtP//AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC3/yAAtP//ALT/3wC0//8AtP/fALT//wC0
//8AtP/fALT//wC0/98AtP/fALT//wC0//8AtP/fALT//wC0/98AtP//ALT//wC0//8AtP+/ALT//wC0//8AtP//AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACz/0AAtP+/AAAAAACz/0AAAAAAALX/YAC0/98At/8gAAAAAAC3
/yAAAAAAALT/vwC0/78AAAAAALP/QAC3/yAAt/8gALT//wC0/58AAAAAALP/QAAAAAAAtP+/ALf/IAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACz/0AAtP+/ALT/3wC3/yAAtP+fALP/gAC0/98AtP+/ALX/YAC3/yAAtP+/ALT/vwC0
/78AtP+/ALP/QACz/4AAtP+/ALT/3wC0/78AtP/fALf/IAC0/78AtP/fALX/YAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACz/4AAtP//ALT//wCz/4AAtP//ALT//wC0//8AtP//ALT/3wC0/58AtP//ALT//wC0//8AtP//ALP/gAC0
/98AtP//ALT//wC0//8AtP//ALX/YAC0//8AtP//ALT/nwAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC0/78AtP/fALP/gAAAAAAAs/+AALT//wC0//8AtP+/ALX/YAC3/yAAtP+fALT//wC0//8As/+AALf/IAC3/yAAtP+fALT//wC0
/98As/+AAAAAAACz/4AAtP/fALT/nwAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAC0/98AtP+/AAAAAAAAAAAAAAAAALT/3wC0//8As/+AAAAAAAAAAAAAAAAAALT//wC0//8As/9AAAAAAAAAAAAAtf9gALT//wC0/98AAAAAAAAAAAAA
AAAAtP+/ALT//wAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAC1/5AAt/8gAAAAAAAAAAAAAAAAALf/IAC0/3QAt/8gAAAAAAAAAAAAAAAAALT/dAC1/2AAAAAAAAAAAAAAAAAAAAAAALX/kAC3/yAAAAAAAAAAAAAAAAAAt/88ALP/gAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC1/2AAtP//
ALT/nwAAAAAAAAAAALP/gAC0//8AtP/fAAAAAAAAAAAAs/9AALT//wC0//8As/9AAAAAAAAAAAAAtP+fALT//wC0/58AAAAAALf/IACz/4AAtP//ALP/gAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAs/+AALT//wC0/78AAAAA
AAAAAAC0//8AtP//ALP/QAAAAAAAs/9AALT//wC0//8As/9AAAAAAACz/0AAtP//ALT/3wC3/yAAt/8gALP/gAC0//8As/+AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALf/IAC0/78AtP/fALP/QACz/0AAtP//
ALT/3wAAAAAAt/8gALT//wC0//8As/9AALf/IAC0/98AtP/fALP/QACz/0AAtP/fALT/3wCz/0AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAs/+AALT/3wC0/98AtP+fALT/vwC0/98As/9A
ALT//wC0//8As/9AALT/3wC0//8As/+AALT/vwC0/98As/+AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC3/yAAs/+AALT/vwC0//8AtP//ALT//wC0//8AtP//
ALT/3wC0/98AtP+fALP/QAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAt/8gALT/WAC0/4gAt/8gAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAtf9gALT//wC0//8Atf9gAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAt/8gALT//wC0//8As/9AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALX/YAC1/2AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
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
/2AAtP/fAAAAAAAAAAAAtP+/ALT/vwAAAAAAAAAAALT/3wCz/4AAAAAAAAAAAAC0//8AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAALX/YACz/4AAAAAAALP/QAC0/98At/8gAAAAAACz/4AAtf9gAAAAAAC3/yAAtP+/ALP/QAAAAAAAs/+AALP/gAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALT/vwC0/78AAAAAALT/vwC0/78AAAAAALT/3wC0/98AAAAAALT/nwC0/98At/8gALP/gAC0/58At/8g
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALP/QAC0/58AtP+fALT/vwCz/4AAtP+fALT/vwCz
/4AAtP//ALP/gAC0/78Atf9gAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAC3/yAAs/+AALP/gAC0/78AtP+fALT/nwC1/2AAs/9AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALT/3wC0/78AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAtP+/ALT/nwAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACz/0AAs/9A
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA//AP///gB///gAP//4AB//8AAP//AAD//wAA//8AAP/+AAB//gAAf/4A
AH/+AAB//gAAf/4AAH/+AAB//gAAf/4AAH/+AAB//gAAf/8AAP//AAD//wAA//8AAP//AAD//yZm//8iRP//kkD//8AD///wD////n////5////+f/8oAAAAEAAAACAAAAABACAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACme3M8lmJYwIhMQvd4NSv7nmxjzwAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AACme3M8ejct/3o3Lf96Ny3/ejct/2keFP94NSv77+ffIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAk15U52keFP+thHr/vp6U/864rv+thHr/aR4U/41WTNsAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAJtrYf+ba2H/vp6U//Dr4f/w6+H/zriu/2keFP9pHhT/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAO/n3yDf0sj/39LI/9/S
yP/f0sj/39LI/9/SyP+LUUf/aR4U/+/n3yAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAADv598gaR4U/1wxMf9PQ0//T0NP/09DT/9PQ0//T0NP/09DT//v598gAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAA7+ffIGkeFP9cMTH/ALT//wC0//8AtP//DaHi/w2h4v8NoeL/7+ffIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAO/n3yBpHhT/aR4U/zRpiv8AtP//ALT//zRp
iv9pHhT/aR4U/+/n3yAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAADv598gaR4U/2keFP9BV2z/QVds/0FXbP9BV2z/aR4U/2keFP/v598gAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAHJWV/FiY3DzYmNw82JjcPNiY3DzYmNw82JjcPNyVlfx7+ffIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAtP+fALT/vwC0/98AtP/fALT/vwC0/98AtP+fALP/gAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALT/nwCz/4AAtP+/ALP/gAC0/58As/+AALP/gAC0/98AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC0/3QAt/8g
ALf/PAC3/zwAt/88ALf/PAC3/yAAtP9wAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAt/8gALP/gAC0/78AtP+fALP/gACz/4AAs/+AALf/IAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAt/8gALT/dAC0/4gAs/9AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACz/0AAs/9A
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAPg/AADwDwAA8A8AAPAPAADgBwAA4AcAAOAHAADgBwAA4AcAAPAHAADwDwAA8A8AAPAPAADwDwAA/D8AAP5/AAA=
"@
    $iconBytes = [Convert]::FromBase64String($iconBase64)
    $iconStream = [System.IO.MemoryStream]::new($iconBytes, 0, $iconBytes.Length)
    $formMain.Icon = [System.Drawing.Icon]::FromHandle(([System.Drawing.Bitmap]::new($iconStream).GetHicon()))

#endregion
#region panelChildForm
    # Create panelChildForm
    $panelChildForm = New-Object System.Windows.Forms.Panel
    $panelChildForm.Anchor = "Top,Bottom,Left,Right"
    $panelChildForm.AutoSize = $False
    $panelChildForm.BackColor = "255,255,255" # "255,255,255" (Vit)
    $panelChildForm.Dock = "Fill"

#endregion
#region panelTop
    # Create labelPanelTopLeft
    $labelPanelTopLeft = New-Object System.Windows.Forms.Label
    $labelPanelTopLeft.AutoSize = $True
    $labelPanelTopLeft.BackColor = "20,30,105" # "20,30,105" (MörkBlå) #141E69
    $labelPanelTopLeft.Font = "Verdana,14"
    $labelPanelTopLeft.ForeColor = "255,255,255" # "255,255,255" (Vit)
    $labelPanelTopLeft.Location = "2,2"
    #$labelPanelTopLeft.Text = "Testing...123"
    $labelPanelTopLeft.TextAlign = "MiddleLeft"

    # Create labelPanelTopRight
    $labelPanelTopRight = New-Object System.Windows.Forms.Label
    $labelPanelTopRight.Anchor = "Top, Right"
    $labelPanelTopRight.AutoSize = $True
    $labelPanelTopRight.BackColor = "20,30,105" # "20,30,105" (MörkBlå) #141E69
    $labelPanelTopRight.Font = "Verdana,14"
    $labelPanelTopRight.ForeColor = "255,255,255" # "255,255,255" (Vit)
    $labelPanelTopRight.Location = "38,2"
    #$labelPanelTopRight.Text = "Steg 1 av 99"
    $labelPanelTopRight.TextAlign = "MiddleLeft"

    # Create panelTop
    $panelTop = New-Object System.Windows.Forms.Panel
    #$panelTop.Anchor = "Top, Left, Right"
    #$panelTop.AutoSize = $True
    $panelTop.BackColor = "20,30,105" # "20,30,105" (MörkBlå) #141E69
    $panelTop.Controls.Add($labelPanelTopLeft)
    $panelTop.Controls.Add($labelPanelTopRight)
    $panelTop.Dock = "Top"
    #$panelTop.Location = "190,0"
    $panelTop.Size = "0,32"
#endregion
#region panelMenu
    # Skapa panelMenu
    $panelMenu = New-Object System.Windows.Forms.Panel
    $panelMenu.BackColor = "20,30,105" # "20,30,105" (MörkBlå) #141E69
    $panelMenu.Dock = "Left"
    $panelMenu.Name = "panelMenu"
    $panelMenu.Size = "190,0"
#endregion    
#region statusStrip

    # Create toolStripStatusLabelLeft
    $toolStripStatusLabelLeft = New-Object System.Windows.Forms.ToolStripStatusLabel
    $toolStripStatusLabelLeft.Name = "toolStripStatusLabelLeft"
    #$toolStripStatusLabelLeft.Text = "Testing..."

    # Create statusStrip
    $statusStrip = New-Object System.Windows.Forms.StatusStrip
    $statusStrip.AutoSize = $False
    $statusStrip.BackColor = "255,180,0" # Orange #FFB400
    $statusStrip.Dock = "Bottom"
    $statusStrip.Font = "Verdana,10"
    $statusStrip.GripStyle = "Hidden"
    $statusStrip.Items.AddRange($toolStripStatusLabelLeft)
    $statusStrip.Name = "statusStrip"
    $statusStrip.Size = "0,24"

#endregion

    # GUI order...
    $formMain.Controls.Add($panelChildForm)
    $formMain.Controls.Add($statusStrip)
    $panelTop.Controls.Add($labelPanelTopLeft)
    $panelTop.Controls.Add($labelPanelTopRight)
    $formMain.Controls.Add($panelTop)
    $formMain.Controls.Add($panelMenu)
  
#region Tools
    # Create buttonTools
    $buttonTools = New-Object System.Windows.Forms.Button
    $buttonTools.Add_Click({buttonTools_Click})
    $buttonTools.Add_MouseHover({buttonTools_MouseHover})
    $buttonTools.Add_MouseLeave({buttonTools_MouseLeave})
    $buttonTools.Dock = "Top"
    $buttonTools.FlatAppearance.BorderSize = "0"
    $buttonTools.FlatStyle = "Flat"
    $buttonTools.Font = "Verdana,14"
    $buttonTools.ForeColor = "255,255,255" # Vit
    $buttonTools.Padding = "10,0,0,0"
    $buttonTools.Size = "190,40"
    $buttonTools.Text = "Tools"
    $buttonTools.TextAlign = "MiddleLeft"

    # Create panelSubMenuTools
    $panelSubMenuTools=New-Object System.Windows.Forms.Panel
    $panelSubMenuTools.BackColor="20,30,105" # "200,30,105" # MörkBlå
    $panelSubMenuTools.Dock="Top"
    $panelSubMenuTools.Size="0,40" # 40 för varje menuval
    $panelSubMenuTools.Visible=$false ### För Debug av SubMenu

    # Contacts buttonKontakter
    $buttonKontakter=New-Object System.Windows.Forms.Button
    #$buttonKontakter.Add_Click({Kontakter})
    $buttonKontakter.Dock="Top"
    $buttonKontakter.FlatAppearance.BorderSize="0"
    $buttonKontakter.FlatStyle = "Flat"
    $buttonKontakter.Font="Verdana,14"
    $buttonKontakter.ForeColor = "255,255,255" # Vit
    $buttonKontakter.Padding="35,0,0,0"
    $buttonKontakter.Size="190,40"
    $buttonKontakter.Text="Kontakter"
    $buttonKontakter.TextAlign="MiddleLeft"
    
    # GUI order...  
    $panelSubMenuTools.Controls.Add($buttonKontakter)
    $panelMenu.Controls.Add($panelSubMenuTools)
    $panelMenu.Controls.Add($buttonTools)

#endregion
#region Statistik
    # Create buttonStatistik
    $buttonStatistik = New-Object System.Windows.Forms.Button
    $buttonStatistik.Add_Click({buttonStatistik_Click})
    $buttonStatistik.Add_MouseHover({buttonStatistik_MouseHover})
    $buttonStatistik.Add_MouseLeave({buttonStatistik_MouseLeave})
    $buttonStatistik.Dock = "Top"
    $buttonStatistik.FlatAppearance.BorderSize = "0"
    $buttonStatistik.FlatStyle = "Flat"
    $buttonStatistik.Font = "Verdana,14"
    $buttonStatistik.ForeColor = "255,255,255" # Vit
    $buttonStatistik.Padding = "10,0,0,0"
    $buttonStatistik.Size = "190,40"
    $buttonStatistik.Text = "Statistik"
    $buttonStatistik.TextAlign = "MiddleLeft"

    # Create panelSubMenuStatistik
    $panelSubMenuStatistik=New-Object System.Windows.Forms.Panel
    $panelSubMenuStatistik.BackColor="20,30,105" # MörkBlå #141E69
    $panelSubMenuStatistik.Dock="Top"
    $panelSubMenuStatistik.Size="0,40" # 40 för varje menuval
    $panelSubMenuStatistik.Visible=$false ### För Debug av SubMenu

    # Create buttonTele2
    $buttonTele2 = New-Object System.Windows.Forms.Button
    #$buttonTele2.Add_Click({buttonTele2_Click})
    $buttonTele2.Dock = "Top"
    $buttonTele2.FlatAppearance.BorderSize = "0"
    $buttonTele2.FlatStyle = "Flat"
    $buttonTele2.Font = "Verdana,14"
    $buttonTele2.ForeColor = "255,255,255" # Vit
    $buttonTele2.Padding = "35,0,0,0"
    $buttonTele2.Size = "0,40"
    $buttonTele2.Text = "Tele2"
    $buttonTele2.TextAlign = "MiddleLeft"

    # GUI order...  
    $panelSubMenuStatistik.Controls.Add($buttonTele2)
    $panelMenu.Controls.Add($panelSubMenuStatistik)
    $panelMenu.Controls.Add($buttonStatistik)

#endregion
#region Release
    # Create buttonRelease
    $buttonRelease = New-Object System.Windows.Forms.Button
    $buttonRelease.Add_Click({buttonRelease_Click})
    $buttonRelease.Add_MouseHover({buttonRelease_MouseHover})
    $buttonRelease.Add_MouseLeave({buttonRelease_MouseLeave})
    $buttonRelease.Dock = "Top"
    $buttonRelease.FlatAppearance.BorderSize = "0"
    #$buttonRelease.FlatAppearance.MouseDownBackColor="255,180,0" # Orange
    #$buttonRelease.FlatAppearance.MouseOverBackColor="255,180,0" # Orange
    $buttonRelease.FlatStyle = "Flat"
    $buttonRelease.Font = "Verdana,14"
    $buttonRelease.ForeColor = "255,255,255" # Vit
    $buttonRelease.Padding = "10,0,0,0"
    $buttonRelease.Size="0,40"
    $buttonRelease.Text="Release"
    $buttonRelease.TextAlign="MiddleLeft"
 
    # Create panelSubMenuRelease
    $panelSubMenuRelease=New-Object System.Windows.Forms.Panel
    $panelSubMenuRelease.BackColor="20,30,105" # MörkBlå #141E69
    $panelSubMenuRelease.Dock="Top"
    $panelSubMenuRelease.Size="190,80"
    $panelSubMenuRelease.Visible=$false ### För Debug av SubMenu

    # Create buttonFörberedelse
    $buttonFörberedelse = New-Object System.Windows.Forms.Button
    $buttonFörberedelse.Add_Click({buttonFörberedelse_Click})
    $buttonFörberedelse.Add_MouseHover({buttonFörberedelse_MouseHover})
    $buttonFörberedelse.Add_MouseLeave({buttonFörberedelse_MouseLeave})
    $buttonFörberedelse.Dock = "Top"
    $buttonFörberedelse.FlatAppearance.BorderSize = "0"
    $buttonFörberedelse.FlatStyle = "Flat"
    $buttonFörberedelse.Font = "Verdana,14"
    $buttonFörberedelse.ForeColor = "255,255,255" # Vit
    $buttonFörberedelse.Padding = "35,0,0,0"
    $buttonFörberedelse.Size = "0,40"
    $buttonFörberedelse.Text = "Förberedelse"
    $buttonFörberedelse.TextAlign = "MiddleLeft"
    
    # Create buttonPlanned
    $buttonPlanned = New-Object System.Windows.Forms.Button
    #$buttonPlanned.Add_Click({buttonPlanned_Click})
    $buttonPlanned.Dock = "Top"
    $buttonPlanned.FlatAppearance.BorderSize = "0"
    $buttonPlanned.FlatStyle = "Flat"
    $buttonPlanned.Font = "Verdana,14"
    $buttonPlanned.ForeColor = "255,255,255" # Vit
    $buttonPlanned.Padding = "35,0,0,0"
    $buttonPlanned.Size = "190,40"
    $buttonPlanned.Text = "Driftsättning"
    $buttonPlanned.TextAlign = "MiddleLeft"

    # GUI order...
    $panelSubMenuRelease.Controls.Add($buttonPlanned)
    $panelSubMenuRelease.Controls.Add($buttonFörberedelse)
    $panelMenu.Controls.Add($panelSubMenuRelease)
    $panelMenu.Controls.Add($buttonRelease) 


#endregion
#region Daily
    # Skapa buttonDaily
    $buttonDaily = New-Object System.Windows.Forms.Button
    $buttonDaily.Add_Click({buttonDaily_Click})
    $buttonDaily.Add_MouseHover({buttonDaily_MouseHover})
    $buttonDaily.Add_MouseLeave({buttonDaily_MouseLeave})
    $buttonDaily.Dock = "Top"
    $buttonDaily.FlatAppearance.BorderSize = "0"
    $buttonDaily.FlatStyle = "Flat"
    $buttonDaily.Font = "Verdana,14"
    $buttonDaily.ForeColor = "255,255,255" # Vit
    $buttonDaily.Name = "buttonDaily"
    $buttonDaily.Padding = "10,0,0,0"
    $buttonDaily.Size = "0,40"
    $buttonDaily.Text = "Daily"
    $buttonDaily.TextAlign = "MiddleLeft"

    # Create panelSubMenuDaily
    $panelSubMenuDaily = New-Object System.Windows.Forms.Panel
    $panelSubMenuDaily.BackColor = "20,30,105" # "20,30,105" (MörkBlå) #141E69
    $panelSubMenuDaily.Dock="Top"
    $panelSubMenuDaily.Size="0,40"
    $panelSubMenuDaily.Visible=$false ### För Debug av SubMenu

    # Create buttonÄrenden
    $buttonÄrenden = New-Object System.Windows.Forms.Button
    $buttonÄrenden.Add_Click({buttonÄrenden_Click})
    $buttonÄrenden.Add_MouseHover({buttonÄrenden_MouseHover})
    $buttonÄrenden.Add_MouseLeave({buttonÄrenden_MouseLeave})
    $buttonÄrenden.Dock = "Top"
    $buttonÄrenden.FlatAppearance.BorderSize = "0"
    $buttonÄrenden.FlatStyle = "Flat"
    $buttonÄrenden.Font = "Verdana,14"
    $buttonÄrenden.ForeColor = "255,255,255" # Vit
    $buttonÄrenden.Padding = "35,0,0,0"
    $buttonÄrenden.Size = "0,40"
    $buttonÄrenden.Text = "Ärenden"
    $buttonÄrenden.TextAlign = "MiddleLeft"

    # GUI order...
    $panelSubMenuDaily.Controls.Add($buttonÄrenden)
    $panelMenu.Controls.Add($panelSubMenuDaily)
    $panelMenu.Controls.Add($buttonDaily)


#endregion
#region Logo

    # Skapa panelLogo
    $panelLogo = New-Object System.Windows.Forms.Panel
    $panelLogo.BackColor = "20,30,105" # "20,30,105" (MörkBlå) #141E69
    $panelLogo.Dock = "Top"
    $panelLogo.Name = "panelLogo"
    $panelLogo.Size = "190,110"

    # Skapa pictureBox
    $pictureBoxLogo = New-Object System.Windows.Forms.PictureBox
    #$pictureBoxLogo.Anchor = "Top, Left"
    $pictureBoxLogo.Padding = "15,15,0,0"
    $pictureBoxLogo.Size = "190,110"

    # Skapa Logo
    [String]$logoBase64=@"
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
    $logoBytes = [Convert]::FromBase64String($logoBase64)
    $logoStream = New-Object System.IO.MemoryStream(,$logoBytes)
    $logo = [System.Drawing.Image]::FromStream($logoStream)
    $pictureBoxLogo.Image = $logo

    # Dubbelklick på Logo
    $pictureBoxLogo.Add_DoubleClick({
        Write-Host "Öpna inställningar"
        
        Create-formSettings

    })

    # GUI order...
    $panelLogo.Controls.Add($pictureBoxLogo)
    $panelMenu.Controls.Add($panelLogo)

#endregion

    # Visa formMain
    #[void]$formMain.ShowDialog()
    [System.Windows.Forms.Application]::Run($formMain)
}

function Create-formÄrenden{

    # Create labelÄrendenAnalyst
    $labelÄrendenAnalyst = New-Object System.Windows.Forms.Label
    $labelÄrendenAnalyst.Anchor = "Top,Left"
    $labelÄrendenAnalyst.AutoSize = $True
    $labelÄrendenAnalyst.Font = "Verdana,10"
    $labelÄrendenAnalyst.Location = "10,10"
    #$labelÄrendenAnalyst.Size = "180,29"
    $labelÄrendenAnalyst.Text = "Handläggare"

    # Create labelÄrendenSupportGroup
    $labelÄrendenSupportGroup = New-Object System.Windows.Forms.Label
    $labelÄrendenSupportGroup.Anchor = "Top,Right"
    $labelÄrendenSupportGroup.AutoSize = $True
    $labelÄrendenSupportGroup.Font = "Verdana,10"
    $labelÄrendenSupportGroup.Location = "10,10"
    #$labelÄrendenSupportGroup.Size = "80,9"
    $labelÄrendenSupportGroup.Text = "Supportgroup"

    # Create comboBoxÄrendenAnalyst
    $comboBoxÄrendenAnalyst = New-Object System.Windows.Forms.ComboBox
    $comboBoxÄrendenAnalyst.Anchor = "Top,Left"
    $comboBoxÄrendenAnalyst.AutoSize = $True
    $comboBoxÄrendenAnalyst.Font = "Verdana,10"
    $comboBoxÄrendenAnalyst.Location = "10,50"
    $comboBoxÄrendenAnalyst.Size = "250,31"
    $comboBoxÄrendenAnalyst.Text = "Gedin Kerry - HK"

    # Create comboBoxÄrendenSupportGroup
    $comboBoxÄrendenSupportGroup = New-Object System.Windows.Forms.ComboBox
    $comboBoxÄrendenSupportGroup.Anchor = "Top,Right"
    $comboBoxÄrendenSupportGroup.AutoSize = $True
    $comboBoxÄrendenSupportGroup.Font = "Verdana,10"
    $comboBoxÄrendenSupportGroup.Location = "0,50"
    $comboBoxÄrendenSupportGroup.Size = "270,31"
    $comboBoxÄrendenSupportGroup.Text = "IT Förvaltning Krimson"

    # Create dataGridViewÄrenden
    $dataGridViewÄrenden = New-Object System.Windows.Forms.DataGridView
    $dataGridViewÄrenden.Anchor = "Top,Bottom,Left,Right"
    $dataGridViewÄrenden.AutoSize = $True
    $dataGridViewÄrenden.Dock = "None"
    $dataGridViewÄrenden.Font = "Verdana,10"
    $dataGridViewÄrenden.Location = "10,100"
    $dataGridViewÄrenden.Size = "260,140"

    # textBoxÄrendenTickets
    $textBoxÄrendenTickets = New-Object System.Windows.Forms.RichTextBox
    $textBoxÄrendenTickets.Anchor = "Top,Bottom,Left,Right"
    $textBoxÄrendenTickets.AutoSize = $True
    $textBoxÄrendenTickets.Font = "Verdana,10"
    $textBoxÄrendenTickets.Location = "175,120"
    $textBoxÄrendenTickets.Multiline = $True
    $textBoxÄrendenTickets.ReadOnly = $True
    $textBoxÄrendenTickets.Size = "70,100"

    # Create formTickets
    $formTickets = New-Object System.Windows.Forms.Form
    $formTickets.Anchor = "Top,Left"
    $formTickets.AutoSize = $False
    $formTickets.AutoSizeMode = "GrowAndShrink"
    $formTickets.BackColor = "55,55,55" # "255,255,255" (Vit)
    $formTickets.Controls.Add($comboBoxÄrendenSupportGroup)
    $formTickets.Controls.Add($comboBoxÄrendenAnalyst)
    $formTickets.Controls.Add($dataGridViewÄrenden)
    #$formTickets.Controls.Add($textBoxÄrendenTickets)
    $formTickets.Controls.Add($labelÄrendenAnalyst)
    $formTickets.Controls.Add($labelÄrendenSupportGroup)
    $formTickets.Dock = "Fill"
    #$formTickets.DockPadding = "100,100,100,100"
    $formTickets.FormBorderStyle = "None"
    $formTickets.Location = "100,100"
    $formTickets.Size = "818,497"
    $formTickets.TopLevel = $False

    #$formÄrenden.Show()
    $panelChildForm.Controls.Clear()
    Write-Host "Started..."
    $panelChildForm.Controls.Add($formTickets)
    $formTickets.Show()
}

function Create-formFörberedelseSteg1{

    # Create buttonFörberedelseSteg1Back
    $buttonFörberedelseSteg1Back = New-Object System.Windows.Forms.Button
    $buttonFörberedelseSteg1Back.Add_Click({buttonFörberedelseCancel_Click})
    $buttonFörberedelseSteg1Back.Anchor = "Bottom,Right"
    $buttonFörberedelseSteg1Back.Font = "Verdana,14"
    #$buttonFörberedelseSteg1Back.Location = "594,409"
    $buttonFörberedelseSteg1Back.Location = "70,220"
    $buttonFörberedelseSteg1Back.Size = "94,29"
    $buttonFörberedelseSteg1Back.Text = "Back"

    # Create buttonFörberedelseSteg1Next
    $buttonFörberedelseSteg1Next = New-Object System.Windows.Forms.Button
    $buttonFörberedelseSteg1Next.Add_Click({buttonFörberedelseSteg1Next_Click})
    $buttonFörberedelseSteg1Next.Anchor = "Bottom,Right"
    $buttonFörberedelseSteg1Next.Font = "Verdana,14"
    #$buttonFörberedelseSteg1Next.Location = "694,409"
    $buttonFörberedelseSteg1Next.Location = "175,220"
    $buttonFörberedelseSteg1Next.Size = "94,29"
    $buttonFörberedelseSteg1Next.Text = "Next"

    # Create buttonFörberedelseSteg1Cancel
    $buttonFörberedelseSteg1Cancel = New-Object System.Windows.Forms.Button
    $buttonFörberedelseSteg1Cancel.Add_Click({buttonFörberedelseCancel_Click})
    $buttonFörberedelseSteg1Cancel.Anchor = "Bottom,Left"
    $buttonFörberedelseSteg1Cancel.Font = "Verdana,14"
    $buttonFörberedelseSteg1Cancel.Location = "20,220"
    $buttonFörberedelseSteg1Cancel.Size = "100,29"
    $buttonFörberedelseSteg1Cancel.Text = "Cancel"

    # Create Label LastDeploy
    $LabelFörberedelseSteg1LastDepoly = New-Object System.Windows.Forms.Label
    $LabelFörberedelseSteg1LastDepoly.Location = "20,20"
    $LabelFörberedelseSteg1LastDepoly.Anchor = "Top,Left"# "Top,Bottom,Left,Right"
    $LabelFörberedelseSteg1LastDepoly.Text = "Last Deploy: "
    $LabelFörberedelseSteg1LastDepoly.Font = "Verdana,10"

    # Create LabelThisDeploy
    $LabelFörberedelseSteg1ThisDepoly = New-Object System.Windows.Forms.Label
    $LabelFörberedelseSteg1ThisDepoly.Location = "20,60"
    $LabelFörberedelseSteg1ThisDepoly.Anchor = "Top,Left"# "Top,Bottom,Left,Right"
    $LabelFörberedelseSteg1ThisDepoly.Text = "This Deploy: "
    $LabelFörberedelseSteg1ThisDepoly.Font = "Verdana,10"



    # Hämta $LastDeploy från 
    $datePattern = "^\d{4}-\d{2}-\d{2}$"
    try {
        #
        $dateFolders = Get-ChildItem -Path $MPPAth_PreProd -Directory | 
                       Where-Object {$_.Name -match $datePattern} | 
                       Sort-Object Name -Descending
        $output = New-Object System.Text.StringBuilder
        
        #$LastDeploy = $dateFolders[0].Name
        $LastDeploy = [datetime]::ParseExact($dateFolders[0].Name, "yyyy-MM-dd", $null)

        # Test...
        #$val = $dateFolders | Out-GridView -Title "test..." -OutputMode Multiple

        foreach ($dir in $dateFolders) {
            [void]$output.AppendLine("KATALOG: $($dir.Name)")
            
            # 2. Hämta filer i just denna datum-mapp
            $files = Get-ChildItem -Path $dir.FullName -File
            if ($files.Count -eq 0) {
                [void]$output.AppendLine("   (Inga filer hittades)")
            } else {
                foreach ($file in $files) {
                    [void]$output.AppendLine("   - $($file.Name) [$($file.LastWriteTime.ToString('HH:mm'))]")
                }
            }
            [void]$output.AppendLine("-" * 30) # Avskiljare
        }
                      
    }
    catch {
        #
    }


    # Create LastDeploy
    $DateTimePickerFörberedelseSteg1LastDeploy = New-Object System.Windows.Forms.DateTimePicker
    $DateTimePickerFörberedelseSteg1LastDeploy.Anchor = "Top, Left"
    $DateTimePickerFörberedelseSteg1LastDeploy.Format = [System.Windows.Forms.DateTimePickerFormat]::Short
    $DateTimePickerFörberedelseSteg1LastDeploy.Location = [System.Drawing.Point]::new(120,16)
    $DateTimePickerFörberedelseSteg1LastDeploy.Value = $LastDeploy
    $DateTimePickerFörberedelseSteg1LastDeploy.Width = 200

    # Create ThisDeploy
    $DateTimePickerFörberedelseSteg1ThisDeploy = New-Object System.Windows.Forms.DateTimePicker
    $DateTimePickerFörberedelseSteg1ThisDeploy.Anchor = "Top, Left"
    $DateTimePickerFörberedelseSteg1ThisDeploy.Format = [System.Windows.Forms.DateTimePickerFormat]::Short
    $DateTimePickerFörberedelseSteg1ThisDeploy.Location = [System.Drawing.Point]::new(120,60)
    $DateTimePickerFörberedelseSteg1ThisDeploy.Value = Get-Date
    $DateTimePickerFörberedelseSteg1ThisDeploy.Width = 200
 

    # Create textBoxFörberedelseSteg1
    $textBoxFörberedelseSteg1 = New-Object System.Windows.Forms.RichTextBox
    $textBoxFörberedelseSteg1.Size = [System.Drawing.Size]::new(200, 100)
    $textBoxFörberedelseSteg1.Location = "20,100"
    
    $textBoxFörberedelseSteg1.Font = "Verdana,10"
    $textBoxFörberedelseSteg1.Multiline = $True
    $textBoxFörberedelseSteg1.ReadOnly = $True
    $textBoxFörberedelseSteg1.Anchor = "Top,Bottom,Left,Right"
    $textBoxFörberedelseSteg1.AppendText("Release sker normalt mellan 19:00 och 22:00,")
    $textBoxFörberedelseSteg1.AppendText([environment]::NewLine)
    #$textBoxStep1.SelectionBackColor = "120,120,120"
    #$textBoxStep1.SelectionColor = "245,0,0"
    $textBoxFörberedelseSteg1.AppendText("den första tisdagen efter den 20:e varje månad.")
    $textBoxFörberedelseSteg1.AppendText([environment]::NewLine)
    $textBoxFörberedelseSteg1.AppendText([environment]::NewLine)
    #$textBoxFörberedelseSteg1.AppendText("Undantagen är under förändringsstopp. (tex. under semestern, jul och nyår.)")
    #$textBoxFörberedelseSteg1.AppendText([environment]::NewLine)
    #$textBoxFörberedelseSteg1.AppendText([environment]::NewLine)
    #$textBoxFörberedelseSteg1.AppendText([environment]::NewLine)
    #$ReleaseDateTime = $(Get-Krimson -Release -Schedule Now).GetDateTimeFormats()[16]
    #$textBoxFörberedelseSteg1.AppendText("Beräknat datum: $ReleaseDateTime")
    #$textBoxFörberedelseSteg1.AppendText([environment]::NewLine)
    #$textBoxFörberedelseSteg1.AppendText("Dagens datum: $(Get-Date -Format 'yyyy-MM-dd HH.mm')")

    $textBoxFörberedelseSteg1.AppendText($output.ToString())


    # Create formFörberedelseSteg1
    $formFörberedelseSteg1 = New-Object System.Windows.Forms.Form
    #$formFörberedelseSteg1.Add_Click({buttonStep1Next})
    $formFörberedelseSteg1.Anchor = "Top,Left"
    $formFörberedelseSteg1.AutoSize = $False
    $formFörberedelseSteg1.AutoSizeMode = "GrowAndShrink"
    #$formFörberedelseSteg1.BackColor = "55,55,55"
    $formFörberedelseSteg1.Controls.Add($buttonFörberedelseSteg1Next)
    $formFörberedelseSteg1.Controls.Add($buttonFörberedelseSteg1Back)
    $formFörberedelseSteg1.Controls.Add($buttonFörberedelseSteg1Cancel)
    $formFörberedelseSteg1.Controls.Add($LabelFörberedelseSteg1LastDepoly)
    $formFörberedelseSteg1.Controls.Add($LabelFörberedelseSteg1ThisDepoly)
    $formFörberedelseSteg1.Controls.Add($DateTimePickerFörberedelseSteg1LastDeploy)
    $formFörberedelseSteg1.Controls.Add($DateTimePickerFörberedelseSteg1ThisDeploy)
    $formFörberedelseSteg1.Controls.Add($textBoxFörberedelseSteg1)
    $formFörberedelseSteg1.Dock = "Fill"
    $formFörberedelseSteg1.FormBorderStyle = "None"
    #$formFörberedelseSteg1.Location = "100,100"
    #$formFörberedelseSteg1.Size = "818,497"
    $formFörberedelseSteg1.TopLevel = $False

    $panelChildForm.Controls.Clear()
    $panelChildForm.Controls.Add($formFörberedelseSteg1)
    $formFörberedelseSteg1.Show()

}

function Create-formFörberedelseSteg2{
    
    # Create buttonFörberedelseSteg2Back
    $buttonFörberedelseSteg2Back = New-Object System.Windows.Forms.Button
    $buttonFörberedelseSteg2Back.Add_Click({buttonFörberedelseSteg2Back_Click})
    $buttonFörberedelseSteg2Back.Anchor = "Bottom,Right"
    #$buttonFörberedelseSteg2Back.Location = "594,409"
    $buttonFörberedelseSteg2Back.Location = "70,220"
    $buttonFörberedelseSteg2Back.Size = "94,29"
    $buttonFörberedelseSteg2Back.Text = "Back"

    # Create buttonFörberedelseSteg2Next
    $buttonFörberedelseSteg2Next = New-Object System.Windows.Forms.Button
    $buttonFörberedelseSteg2Next.Add_Click({buttonFörberedelseSteg2Next_Click})
    $buttonFörberedelseSteg2Next.Anchor = "Bottom,Right"
    $buttonFörberedelseSteg2Next.Font = "Verdana,14"
    #$buttonFörberedelseSteg2Next.Location = "694,409"
    $buttonFörberedelseSteg2Next.Location = "175,220"
    $buttonFörberedelseSteg2Next.Size = "94, 29"
    $buttonFörberedelseSteg2Next.Text = "Next"

    # Create buttonFörberedelseSteg2Cancel
    $buttonFörberedelseSteg2Cancel = New-Object System.Windows.Forms.Button
    $buttonFörberedelseSteg2Cancel.Add_Click({buttonFörberedelseCancel_Click})
    $buttonFörberedelseSteg2Cancel.Anchor = "Bottom,Left"
    $buttonFörberedelseSteg2Cancel.Font = "Verdana,14"
    $buttonFörberedelseSteg2Cancel.Location = "20,220"
    $buttonFörberedelseSteg2Cancel.Size = "100, 29"
    $buttonFörberedelseSteg2Cancel.Text = "Cancel"

    ###################################


# --- NY HÖGERKLICKSMENY ---
$script:toolTip = New-Object System.Windows.Forms.ToolTip
$script:contextMenu = New-Object System.Windows.Forms.ContextMenuStrip
$script:menuCopyLink = New-Object System.Windows.Forms.ToolStripMenuItem
$script:menuCopyLink.Text = "Kopiera länk"

$script:menuCopyLink.Add_Click({
    if ($script:lastUrl) {
        [System.Windows.Forms.Clipboard]::SetText($script:lastUrl)
        $owner = $script:contextMenu.SourceControl
        $script:toolTip.Show("Länken kopierad!", $owner, 2000)
    }
})
$script:contextMenu.Items.Add($script:menuCopyLink)

# --- SKAPA TEXTBOX ---
$textBoxFörberedelseSteg2 = New-Object System.Windows.Forms.RichTextBox
$textBoxFörberedelseSteg2.Anchor = "Top,Bottom,Left,Right"
$textBoxFörberedelseSteg2.Font = "Verdana,10"
$textBoxFörberedelseSteg2.Location = "20,20"
$textBoxFörberedelseSteg2.Multiline = $True
$textBoxFörberedelseSteg2.ReadOnly = $True
$textBoxFörberedelseSteg2.Size = "245,150"
$textBoxFörberedelseSteg2.ContextMenuStrip = $script:contextMenu

# --- Länk 1: loggbok ---
$textBoxFörberedelseSteg2.SelectionFont = New-Object System.Drawing.Font("Verdana", 12, [System.Drawing.FontStyle]::Bold)
$textBoxFörberedelseSteg2.AppendText("  SharePoint" + [environment]::NewLine)

$textBoxFörberedelseSteg2.SelectionFont = New-Object System.Drawing.Font("Verdana", 10, [System.Drawing.FontStyle]::Regular)
$textBoxFörberedelseSteg2.AppendText("Kontrollera SharePoint-samarbetsytan '")

$script:startPosLoggbok = $textBoxFörberedelseSteg2.TextLength
$script:textLoggbok = "Krimson Prod loggbok"
$script:urlLoggbok = "https://samarbete-mk.kvv.se/Rollbaserad/Krimson_UppoKonfig/Krimson_UppoKonfig/Lists/Releaselista/AllItems.aspx"

$textBoxFörberedelseSteg2.AppendText($script:textLoggbok)
$textBoxFörberedelseSteg2.Select($script:startPosLoggbok, $script:textLoggbok.Length)
$textBoxFörberedelseSteg2.SelectionColor = [System.Drawing.Color]::Blue
$textBoxFörberedelseSteg2.SelectionFont = New-Object System.Drawing.Font("Verdana", 10, [System.Drawing.FontStyle]::Underline)

# ÅTERSTÄLL TILL VANLIG TEXT (Tar bort underline)
$textBoxFörberedelseSteg2.SelectionStart = $textBoxFörberedelseSteg2.TextLength
$textBoxFörberedelseSteg2.SelectionFont = New-Object System.Drawing.Font("Verdana", 10, [System.Drawing.FontStyle]::Regular)
$textBoxFörberedelseSteg2.SelectionColor = [System.Drawing.Color]::Black
$textBoxFörberedelseSteg2.AppendText("'," + [environment]::NewLine + "för att säkra att inga åtgärder krävs före, under eller efter release." + [environment]::NewLine + [environment]::NewLine)

# --- LÄNK 2: Releaselista ---
$textBoxFörberedelseSteg2.AppendText("Använd SharePoint-samarbetsytan '")
$script:startPosNotes = $textBoxFörberedelseSteg2.TextLength
$script:textNotes = "Releaselista"
$script:urlNotes = "https://samarbete-mk.kvv.se/Rollbaserad/Krimson_UppoKonfig/Krimson_UppoKonfig/Lists/Releaselista/AllItems.aspx" 

$textBoxFörberedelseSteg2.AppendText($script:textNotes)
$textBoxFörberedelseSteg2.Select($script:startPosNotes, $script:textNotes.Length)
$textBoxFörberedelseSteg2.SelectionColor = [System.Drawing.Color]::Blue
$textBoxFörberedelseSteg2.SelectionFont = New-Object System.Drawing.Font("Verdana", 10, [System.Drawing.FontStyle]::Underline)

# ÅTERSTÄLL TILL VANLIG TEXT (Tar bort underline)
$textBoxFörberedelseSteg2.SelectionStart = $textBoxFörberedelseSteg2.TextLength
$textBoxFörberedelseSteg2.SelectionFont = New-Object System.Drawing.Font("Verdana", 10, [System.Drawing.FontStyle]::Regular)
$textBoxFörberedelseSteg2.SelectionColor = [System.Drawing.Color]::Black
$textBoxFörberedelseSteg2.AppendText("'," + [environment]::NewLine + "för att identifiera vilka förändringar som ska genomföras och vilka kontroller som ska göras." + [environment]::NewLine)

#
$textBoxFörberedelseSteg2.SelectionFont = New-Object System.Drawing.Font("Verdana", 10, [System.Drawing.FontStyle]::Bold)
$textBoxFörberedelseSteg2.AppendText([environment]::NewLine + "OBS! Var extra noggrann med vad som inte ska driftsättas.")



# --- GEMENSAM KLICK- OCH HÖGERKLICKSLOGIK ---
$textBoxFörberedelseSteg2.Add_MouseDown({
    param($sender, $e)
    $index = $sender.GetCharIndexFromPosition($e.Location)
    
    $isOver1 = ($index -ge $script:startPosLoggbok -and $index -lt ($script:startPosLoggbok + $script:textLoggbok.Length))
    $isOver2 = ($index -ge $script:startPosNotes -and $index -lt ($script:startPosNotes + $script:textNotes.Length))

    if ($isOver1) { $script:lastUrl = $script:urlLoggbok }
    elseif ($isOver2) { $script:lastUrl = $script:urlNotes }
    else { $script:lastUrl = $null }

    if ($e.Button -eq [System.Windows.Forms.MouseButtons]::Left) {
        if ($isOver1) { [System.Diagnostics.Process]::Start($script:urlLoggbok) }
        if ($isOver2) { [System.Diagnostics.Process]::Start($script:urlNotes) }
    }
    
    if ($e.Button -eq [System.Windows.Forms.MouseButtons]::Right) {
        $script:menuCopyLink.Visible = ($isOver1 -or $isOver2)
    }
})






    ###################3333


    #$textBoxFörberedelseSteg2.AppendText("http://www.google.com")
    #$textBoxFörberedelseSteg2.DetectUrls = $True
    #$textBoxFörberedelseSteg2.Add_LinkClicked({[System.Diagnostics.Process]::Start("http://www.google.com")})
    #

    #$textBoxFörberedelseSteg2.AppendText("$textBoxStep2Link1 'n")
    #$textBoxFörberedelseSteg2.Controls.Add($textBoxStep2Link1)
    #if(){}

    #function xxx{
    #    Write-Host "sdsdsdsdsdsdsd"
    #}


    # Create formFörberedelseSteg2
    $formFörberedelseSteg2 = New-Object System.Windows.Forms.Form
    #$formFörberedelseSteg2.Add_Click({buttonStep2Next})
    $formFörberedelseSteg2.Controls.Add($buttonFörberedelseSteg2Next)
    $formFörberedelseSteg2.Controls.Add($buttonFörberedelseSteg2Back)
    $formFörberedelseSteg2.Controls.Add($buttonFörberedelseSteg2Cancel)
    $formFörberedelseSteg2.Controls.Add($textBoxFörberedelseSteg2)
    $formFörberedelseSteg2.Dock = "Fill"
    $formFörberedelseSteg2.FormBorderStyle = "None"
    #$formFörberedelseSteg2.Size = "818,497"
    $formFörberedelseSteg2.TopLevel = $False

    $panelChildForm.Controls.Clear()
    $panelChildForm.Controls.Add($formFörberedelseSteg2)
    $formFörberedelseSteg2.Show()


}

function Create-formFörberedelseSteg3{
    # Create buttonFörberedelseSteg3Back
    $buttonFörberedelseSteg3Back = New-Object System.Windows.Forms.Button
    #$buttonFörberedelseSteg3Back.Add_Click({buttonFörberedelseSteg3Back_Click})
    $buttonFörberedelseSteg3Back.Anchor = "Bottom,Right"
    $buttonFörberedelseSteg3Back.Font = "Verdana,14"
    #$buttonFörberedelseSteg3Back.Location = "594,409"
    $buttonFörberedelseSteg3Back.Location = "70,220"
    $buttonFörberedelseSteg3Back.Size = "94,29"
    $buttonFörberedelseSteg3Back.Text = "Back"

    # Create buttonFörberedelseSteg3Next
    $buttonFörberedelseSteg3Next = New-Object System.Windows.Forms.Button
    $buttonFörberedelseSteg3Next.Add_Click({buttonFörberedelseSteg3Next_Click})
    $buttonFörberedelseSteg3Next.Anchor = "Bottom,Right"
    $buttonFörberedelseSteg3Next.Font = "Verdana,14"
    #$buttonFörberedelseSteg3Next.Location = "694,409"
    $buttonFörberedelseSteg3Next.Location = "175,220"
    $buttonFörberedelseSteg3Next.Size = "94,29"
    $buttonFörberedelseSteg3Next.Text = "Next"

    # Create buttonFörberedelseSteg3Cancel
    $buttonFörberedelseSteg3Cancel = New-Object System.Windows.Forms.Button
    #$buttonFörberedelseSteg3Cancel.Add_Click({buttonFörberedelseSteg3Cancel_Click})
    $buttonFörberedelseSteg3Cancel.Anchor = "Bottom,Left"
    $buttonFörberedelseSteg3Cancel.Font = "Verdana,14"
    $buttonFörberedelseSteg3Cancel.Location = "20,220"
    $buttonFörberedelseSteg3Cancel.Size = "100,29"
    $buttonFörberedelseSteg3Cancel.Text = "Cancel"

    # Create textBoxFörberedelseSteg3
    $textBoxFörberedelseSteg3 = New-Object System.Windows.Forms.RichTextBox
    $textBoxFörberedelseSteg3.Anchor = "Top,Bottom,Left,Right"
    $textBoxFörberedelseSteg3.AutoSize = $True 
    $textBoxFörberedelseSteg3.Font = "Verdana,10"
    $textBoxFörberedelseSteg3.Location = "20,20"
    $textBoxFörberedelseSteg3.Multiline = $True
    $textBoxFörberedelseSteg3.ReadOnly = $True
    $textBoxFörberedelseSteg3.Size = "70,150"
    $textBoxFörberedelseSteg3.AppendText("Val E")
    $textBoxFörberedelseSteg3.AppendText([environment]::NewLine)
    $textBoxFörberedelseSteg3.AppendText("Alla MP (Management Pack) i Prod(VNTAPP0565) kommer att exporteras")
    $textBoxFörberedelseSteg3.AppendText([environment]::NewLine)
    ###$textBoxFörberedelseSteg3.AppendText("Till: \\VNTAPP0565\D$\Backup\Backup MP Inför Release\$($ToDay.GetDateTimeFormats()[0])\")
    $textBoxFörberedelseSteg3.AppendText([environment]::NewLine)
    $textBoxFörberedelseSteg3.AppendText([environment]::NewLine)
    $textBoxFörberedelseSteg3.AppendText("Val K")
    $textBoxFörberedelseSteg3.AppendText([environment]::NewLine)
    $textBoxFörberedelseSteg3.AppendText("Kopier alla MP (Management Pack) i Prod(VNTAPP0565) som exporterades via scheduler.")
    $textBoxFörberedelseSteg3.AppendText([environment]::NewLine)
    $textBoxFörberedelseSteg3.AppendText("Från: \\VNTAPP0565\D$\Backup\ManagementPacks\$($(Get-Date).GetDateTimeFormats()[0])\*")
    $textBoxFörberedelseSteg3.AppendText([environment]::NewLine)
    ###$textBoxFörberedelseSteg3.AppendText("Till: \\VNTAPP0565\D$\Backup\Backup MP Inför Release\$($ToDay.GetDateTimeFormats()[0])\")

    # Create formFörberedelseSteg3
    $formFörberedelseSteg3 = New-Object System.Windows.Forms.Form
    #$formFörberedelseSteg3.Add_Click({buttonStep1Next})
    $formFörberedelseSteg3.Anchor = "Top,Left"
    $formFörberedelseSteg3.AutoSize = $False
    $formFörberedelseSteg3.AutoSizeMode = "GrowAndShrink"
    #$formFörberedelseSteg3.BackColor = "55,55,55"
    $formFörberedelseSteg3.Controls.Add($buttonFörberedelseSteg3Next)
    $formFörberedelseSteg3.Controls.Add($buttonFörberedelseSteg3Back)
    $formFörberedelseSteg3.Controls.Add($buttonFörberedelseSteg3Cancel)
    $formFörberedelseSteg3.Controls.Add($textBoxFörberedelseSteg3)
    $formFörberedelseSteg3.Dock = "Fill"
    $formFörberedelseSteg3.FormBorderStyle = "None"
    #$formFörberedelseSteg3.Location = "100,100"
    #$formFörberedelseSteg3.Size = "818,497"
    $formFörberedelseSteg3.TopLevel = $False

    $panelChildForm.Controls.Clear()
    Write-Host "Startar 3" 
    $panelChildForm.Controls.Add($formFörberedelseSteg3)
    $formFörberedelseSteg3.Show()

}

function Create-FormFörberedelseSteg4{
    # Create buttonFörberedelseSteg4Back
    $buttonFörberedelseSteg4Back = New-Object System.Windows.Forms.Button
    #$buttonFörberedelseSteg4Back.Add_Click({buttonFörberedelseSteg4Back_Click})
    $buttonFörberedelseSteg4Back.Anchor = "Bottom,Right"
    $buttonFörberedelseSteg4Back.Font = "Verdana,14"
    #$buttonFörberedelseSteg4Back.Location = "594,409"
    $buttonFörberedelseSteg4Back.Location = "70,220"
    $buttonFörberedelseSteg4Back.Size = "94,29"
    $buttonFörberedelseSteg4Back.Text = "Back"

    # Create buttonFörberedelseSteg4Next
    $buttonFörberedelseSteg4Next = New-Object System.Windows.Forms.Button
    $buttonFörberedelseSteg4Next.Add_Click({buttonFörberedelseSteg4Next_Click})
    $buttonFörberedelseSteg4Next.Anchor = "Bottom,Right"
    $buttonFörberedelseSteg4Next.Font = "Verdana,14"
    #$buttonFörberedelseSteg4Next.Location = "694,409"
    $buttonFörberedelseSteg4Next.Location = "175,220"
    $buttonFörberedelseSteg4Next.Size = "94,29"
    $buttonFörberedelseSteg4Next.Text = "Next"

    # Create buttonFörberedelseSteg4Cancel
    $buttonFörberedelseSteg4Cancel = New-Object System.Windows.Forms.Button
    #$buttonFörberedelseSteg4Cancel.Add_Click({buttonFörberedelseSteg4Cancel_Click})
    $buttonFörberedelseSteg4Cancel.Anchor = "Bottom,Left"
    $buttonFörberedelseSteg4Cancel.Font = "Verdana,14"
    $buttonFörberedelseSteg4Cancel.Location = "20,220"
    $buttonFörberedelseSteg4Cancel.Size = "100,29"
    $buttonFörberedelseSteg4Cancel.Text = "Cancel"











    #
    $dataGridViewFörberedelseSteg4 = New-Object System.Windows.Forms.DataGridView
    $dataGridViewFörberedelseSteg4.RowHeadersVisible = $false
    $dataGridViewFörberedelseSteg4.SelectionMode = "FullRowSelect"
    $dataGridViewFörberedelseSteg4.Font = "Verdana,10"
    $dataGridViewFörberedelseSteg4.Location = "0,0"
    $dataGridViewFörberedelseSteg4.Size = "800,400"
    #$dataGridViewFörberedelseSteg4.Dock = "Fill"
    #$dataGridViewFörberedelseSteg4.AutoSizeColumnsMode = "Fill"
    $dataGridViewFörberedelseSteg4.Anchor = "Top,Left"
    $dataGridViewFörberedelseSteg4.ReadOnly = $true
    $dataGridViewFörberedelseSteg4.AllowUserToResizeRows = $false

    # test data
    $dtManagementPack = New-Object System.Data.DataTable
    [void]$dtManagementPack.Columns.Add("Filnamn")
    [void]$dtManagementPack.Columns.Add("Datum")
    [void]$dtManagementPack.Columns.Add("Status")
    [void]$dtManagementPack.Rows.Add("Fil_1.mp","2025-03-15","PreProd")
    [void]$dtManagementPack.Rows.Add("Fil_2.mp","2025-03-13","Identisk")
    [void]$dtManagementPack.Rows.Add("Fil Från Helevete.mp","2025-01-13","Warning")

    $dataGridViewFörberedelseSteg4.DataSource = $dtManagementPack

    $dataGridViewFörberedelseSteg4.AutoResizeColumns([System.Windows.Forms.DataGridViewAutoSizeColumnsMode]::AllCells)

    #$dataGridViewFörberedelseSteg4.Columns[0].Width = 250
    #$dataGridViewFörberedelseSteg4.Columns[1].Width = 80
    #$dataGridViewFörberedelseSteg4.Columns[2].Width = 100



    # Create formFörberedelseSteg4
    $formFörberedelseSteg4 = New-Object System.Windows.Forms.Form
    #$formFörberedelseSteg4.Add_Click({buttonStep1Next})
    $formFörberedelseSteg4.Anchor = "Top,Left"
    $formFörberedelseSteg4.AutoSize = $False
    $formFörberedelseSteg4.AutoSizeMode = "GrowAndShrink"
    #$formFörberedelseSteg4.BackColor = "55,55,55"
    $formFörberedelseSteg4.Controls.Add($buttonFörberedelseSteg4Next)
    $formFörberedelseSteg4.Controls.Add($buttonFörberedelseSteg4Back)
    $formFörberedelseSteg4.Controls.Add($buttonFörberedelseSteg4Cancel)
    #$formFörberedelseSteg4.Controls.Add($textBoxFörberedelseSteg4)
    $formFörberedelseSteg4.Controls.Add($dataGridViewFörberedelseSteg4)
    $formFörberedelseSteg4.Dock = "Fill"
    $formFörberedelseSteg4.FormBorderStyle = "None"
    #$formFörberedelseSteg4.Location = "100,100"
    #$formFörberedelseSteg4.Size = "818,497"
    $formFörberedelseSteg4.TopLevel = $False




    $panelChildForm.Controls.Clear()
    Write-Host "Startar 4" 
    $panelChildForm.Controls.Add($formFörberedelseSteg4)
    $formFörberedelseSteg4.Show()


    $dataGridViewFörberedelseSteg4.Columns[0].Width = 300
    $dataGridViewFörberedelseSteg4.Columns[1].Width = 100
    $dataGridViewFörberedelseSteg4.Columns[2].Width = 80



}

function Create-formSettings{

    # Driftsättnings katalog för MP (Management Pack) 



    # Create formSettings
    $formSettings = New-Object System.Windows.Forms.Form
    #$formSettings.Add_Click({buttonStep1Next})
    $formSettings.Anchor = "Top,Left"
    $formSettings.AutoSize = $False
    $formSettings.AutoSizeMode = "GrowAndShrink"
    #$formSettings.BackColor = "55,55,55"
    #$formSettings.Controls.Add($buttonFörberedelseSteg4Next)
    #$formSettings.Controls.Add($buttonFörberedelseSteg4Back)
    #$formSettings.Controls.Add($buttonFörberedelseSteg4Cancel)
    #$formSettings.Controls.Add($textBoxFörberedelseSteg4)
    #$formSettings.Controls.Add($dataGridViewFörberedelseSteg4)
    $formSettings.Dock = "Fill"
    $formSettings.FormBorderStyle = "None"
    $formSettings.TopLevel = $False

    #
    $panelChildForm.Controls.Clear()
    $panelChildForm.Controls.Add($formSettings)
    $formSettings.Show()
    #$formSettings.ShowDialog()


}



# Load Assembl
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

#
$LastDeploy = Get-Date
$ThisDeploy = Get-Date
$NextDeploy = Get-Date

#
$SMServer_PreProd = "VNTAPP0560"
$MPPAth_PreProd = "\\VNTAPP0560\C`$\Temp\"
#
$SMServer_Prod = "VNTAPP0565"
$MPPath_Prod = "\\VNTAPP0565\D$\Backup\ManagementPacks"
$MPBackup_Prod = "\\VNTAPP0565\d`$\Backup\Backup MP Inför Release\"

# Main Program
$logMessages = New-Object System.Collections.Generic.List[string]
$logMessages.Add("$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Krimson Tools v0.1 startades..")

# Settings
$registryPath = "HKCU:\Software\Krimson Tools\Settings"
$defaultSettings = @{
    "ProdMPBackup" = "\\VNTAPP0565\D$\Backup MP Inför Release"
    "Log Path" = "%temp%\KrimsonTool.log"
}
if(-not (Test-Path $registryPath)){
    New-Item -Path $registryPath -Force | Out-Null
    Write-Host "Skapade registermappen: $registryPath"
}
$settings = Get-ItemProperty -Path $registryPath -ErrorAction SilentlyContinue
if(-not $settings.$ProdMPBackup){}


Create-formMain
$logMessages.Add("$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Krimson Tools v0.1 avslutades..") # `r`n
Write-Host $($logMessages -join "`r`n")


# Cleanup

# $iconStream.Dispose()

# $formMain.Dispose()
