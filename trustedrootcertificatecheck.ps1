$SkriptVersion = "0.3 vom 04.09.2020"

<# ROOTCA

.SYNOPSYS

 Vergleicht die installierten Zertifikate mit der CTL

 Version 0.3 vom 04.09.2020, AUTHOR: FLORIAN MANN

.NOTES
 - AddressBook: Certificate store for other users.
 - AuthRoot: Certificate store for third-party certification authorities (CAs).
 - CertificationAuthority: Certificate store for intermediate certification authorities (CAs).
 - Disallowed: Certificate store for revoked certificates.
 - My: Certificate store for personal certificates.
 - Root: Certificate store for trusted root certification authorities (CAs).
 - TrustedPeople: Certificate store for directly trusted people and resources.
 - TrustedPublisher: Certificate store for directly trusted publishers.

 ctldl.windowsupdate.com/msdownload/update/v3/static/trustedr/en/disallowedcertstl.cab
 ctldl.windowsupdate.com/msdownload/update/v3/static/trustedr/en/authrootstl.cab


.TODO Verbesserungen:
 Store des Zertifikates anzeigen
 untrusted Lists
 Zertifikatsdetails anzeigen

.TODO Notwendig:
 Alles Englisch uebersetzen


.Fehler:
     Keine bekannt


.Changelog:
     0.2
       - GUI erstellt
     0.1
       - Download MS .SST ROOTCA Datei PROXY?? ab welcher windows version?
       - Auslesen CAStore local User   ANDERE User????
       - Auslesen CAStore local Machine
       - Abgleich der Listen
#>

#Debug Variable (wenn auf $false wird die Konsole und die Powershell ISE ausgeblendet)
$debug = $true

#Konsole nicht anzeigen
if (!$debug){
Add-Type -Name win -MemberDefinition '[DllImport("user32.dll")] public static extern bool ShowWindow(int handle, int state);' -Namespace native
[native.win]::ShowWindow(([System.Diagnostics.Process]::GetCurrentProcess() | Get-Process).MainWindowHandle,0)
}


#Formular initialisieren
function point ($x,$y)
{
    New-Object Drawing.Point $x, $y
}

[reflection.assembly]::LoadWithPartialName("System.Drawing") > $null #Drawing Library
[reflection.assembly]::LoadWithPartialName("System.Windows.forms") > $null


#Fuer Zertifikate
[reflection.assembly]::LoadWithPartialName("System.Security") | Out-Null
$formmain = New-Object Windows.Forms.Form #Formular erzeugen
$formmain.Text = "ROOTCA - Version $SkriptVersion"
$formmain.Size = Point 550 600
$formmain.StartPosition = "CenterScreen"
$formmain.MaximizeBox = $false


#TabControl und Tabs erzeugen
    $TabControl = New-object System.Windows.Forms.TabControl
    $TabROOTCA = New-Object System.Windows.Forms.TabPage
    $TabCTL = New-Object System.Windows.Forms.TabPage
    $TabHilfe = New-Object System.Windows.Forms.TabPage

    #TabControl 
    $TabControl.DataBindings.DefaultDataSourceUpdateMode = 0
    $TabControl.Size = Point 520 520
    $TabControl.Location = point 10 10
    $TabControl.Name = "tabControl"
    $tabControl.Controls.Add($TabROOTCA)
    $tabControl.Controls.Add($TabCTL)  
    $tabControl.Controls.Add($TabHilfe)        

    #Tabs
    $TabROOTCA.Name = "ROOTCA"
    $TabROOTCA.Text = "ROOTCA    "
    $TabCTL.Name = "CTL"
    $TabCTL.Text = "Certificate Trust Lists    "
    $TabHilfe.Name = "Hilfe"
    $TabHilfe.Text = "Hilfe    "

#Durchsuchen Datei-Dialog erzeugen
    $OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    #Ohne ShowHelp funktioniert InitialDirectory nur in der ISE aber nicht im Skript
    $OpenFileDialog.ShowHelp = $true
    $OpenFileDialog.filter = "CTL (*.sst) |*.sst" 

#Variablen
        $ctldateiname = "Rootstore.sst" #+DATUMUHRZEIT   
        $formmain.Text = "ROOTCA - Version $SkriptVersion"

Function AUTHENTICODESIGNATUREN()
{
    #Sucht nach (auch versteckten) Dateien im angegebenen Ordner und den unterordnern, prueft
    #ob die Datei einen Authenticode hat und fuegt diesen $valids hinzu


    $AuthenticodeSuchPfad = "C:\windows\system32"
    $dateien = Get-ChildItem -Path $AuthenticodeSuchPfad -Force -ErrorAction Continue -Recurse| Where-Object{!($_.PSIsContainer)} 
    $valids = @()
    foreach($datei in $dateien)
    {
        $treffer = $false
        $status = Get-AuthenticodeSignature $datei.FullName
        if($status.SignerCertificate) 
        { 
            foreach($tempthumb in $valids)
            {
                if($tempthumb.SignerCertificate.Thumbprint -eq $status.SignerCertificate.Thumbprint)
                { 
                    $treffer = $true;
                    Write-Host "treffer: " $tempthumb.SignerCertificate.Thumbprint  $tempthumb.SignerCertificate.FriendlyName
                }
            }
            if(!($treffer)) { $valids += $status }
        }
    }

    foreach($validitem in $valids)
    {
        Write-Host $validitem.SignerCertificate.Thumbprint
    }
}


Function ABGLEICH()
{
    #Funktion gleicht lokalen Store mit CTL ab
    if($checkBoxLocalUserStore.Checked -or $checkBoxLocalMachineStore.Checked)
    {   
        #Lokal installierte Zertifikate auslesen
        $LokaleZertifikate = @()                  
        if($checkBoxLocalUserStore.Checked) {$LokaleZertifikate += (Get-ChildItem Cert:\CurrentUser\ -Recurse -Exclude Disallowed | Where-Object -Property FriendlyName ) }
        $checkBoxLocalUserStore.Text = "Local User (" + (Get-ChildItem Cert:\CurrentUser\ -Recurse).count +")"
        if($checkBoxLocalMachineStore.Checked) {$LokaleZertifikate += Get-ChildItem Cert:\LocalMachine\ -Recurse -Exclude Disallowed | Where-Object -Property FriendlyName}
        $checkBoxLocalMachineStore.Text = "Local Machine (" + (Get-ChildItem Cert:\LocalMachine\ -Recurse).count +")"

        #Doppelte aussortieren
        $LokaleZertifikate = $LokaleZertifikate | select -uniq
        $labelCertStoresuniqe.Text = "Unique: " + ($LokaleZertifikate).Count
        #Sortieren
        $LokaleZertifikate = $LokaleZertifikate | Sort-Object -Property FriendlyName

         #Progressbar konfigurieren
         $progress.Visible = $true
         $progress.Value = 0
         if(($LokaleZertifikate).Count -gt 0) {$Fortschritt = 100 / (($LokaleZertifikate).Count)} else { $Fortschritt = 100 }

         $progress.Visible = $true
         
         #CTL Liste in Variable laden
         $ctl = new-object system.security.cryptography.x509certificates.x509certificate2collection
         $ctl.import($ctldateiname)
         $labelButtonquelle.Text = "CTL: (" + $ctl.Count + ")"

         foreach($localcert in $LokaleZertifikate)
         {
            $match = $false
            $gueltig = $true
            #ListViewItem Variable fuer die Zwischenspeicherung der Werte erstellen (inkl. erstem leeren Element)
            $temp  = New-Object System.Windows.Forms.ListViewItem
            $temp.SubItems.Clear()
            $temp.SubItems.Add($localcert.FriendlyName)

            #Abgleich der Listen durchfuehren
            foreach ($ctlcert in $ctl)            
            {

                if($localcert.Thumbprint -eq $ctlcert.Thumbprint)
                { $match = $true; break }
            }

            #Gueltigkeitszeitraum
            if($match)
            { 
                $temp.SubItems.Add("X")
            }
            else
            {                 
                $temp.SubItems.Add("-")
                $gueltig = $false
            }            

            [string]$tempnotbefore = get-date -uformat "%d.%m.%Y" $localcert.NotBefore
            $temp.SubItems.Add($tempnotbefore)
            if(($localcert.NotBefore) -gt (get-date)) {$gueltig = $false}

            [string]$tempnotafter = get-date -uformat "%d.%m.%Y" $localcert.NotAfter
            $temp.SubItems.Add($tempnotafter)
            if(($localcert.NotAfter) -lt (get-date)) {$gueltig = $false}

            $temp.SubItems.Add($localcert.Thumbprint)
            #$temp.SubItems.Add($localcert.Store)
            #Loescht erstes leeres Element
            $temp.SubItems.RemoveAt(0)
            $objListBoxZertifikate.Items.AddRange($temp)

            if($gueltig)
            { $objListBoxZertifikate.Items[$objListBoxZertifikate.Items.Count - 1].BackColor = [system.Drawing.Color]::Green }
            else
            { $objListBoxZertifikate.Items[$objListBoxZertifikate.Items.Count - 1].BackColor = [system.Drawing.Color]::Red }
            if(($progress.Value + $Fortschritt) -lt 100){$progress.Value += $Fortschritt}
        }
        #Spaltenbreiten anpassen
        $objListBoxZertifikate.AutoResizeColumns([Windows.Forms.ColumnHeaderAutoResizeStyle]::HeaderSize)
     }
     else
     { [System.Windows.Forms.MessageBox]::Show("Kein lokaler Speicher ausgewählt!","ROOTCA",0,[System.Windows.Forms.MessageBoxIcon]::Information)| Out-Null }
 $progress.Visible = $false
}

#Tab ROOTCA------------------------------------------------------
#Button Datei auswaehlen
$labelButtonquelle  = New-Object Windows.forms.Label # Label erzeugen
$labelButtonquelle.Text = "CTL: "
$labelButtonquelle.Location = point 10 10
$labelButtonquelle.Size = point 150 20
$labelButtonquelle.Anchor = "top,left"

#Kopieren Button erzeugen
$buttondatei = New-Object Windows.Forms.Button 
$buttondatei.Text = "CTL auswählen..."
$buttondatei.Location = point 20 30
$buttondatei.Width = 150
$buttondatei.Anchor = "top,left"
$buttondatei.Enabled = $true
$buttondatei.add_click({
        #Datei auswahlen
        $result = $OpenFileDialog.ShowDialog()
        $datei = ""
        $datei=$OpenFileDialog.FileName
        If ($datei -AND $result -eq "OK")
        {
            $ctldateiname = $datei
            $labelButtonpfad.Text = $ctldateiname
            $buttonabgleich.Enabled = $true
        }
        elseif (!($result -eq "OK")) #Abbrechen gedrueckt
        { return 0 }
        else
        {
            [System.Windows.Forms.MessageBox]::Show("Fehler beim lesen von $datei.","ROOTCA",0,[System.Windows.Forms.MessageBoxIcon]::Information)| Out-Null
            return 0
        }
                    })                    

$labelButtonpfad  = New-Object Windows.forms.Label # Label erzeugen
$labelButtonpfad.Text = "Dateiname..."
$labelButtonpfad.Location = point 20 55
$labelButtonpfad.Size = point 320 25
$labelButtonpfad.Anchor = "top,left"

#Download Button erzeugen
$buttondownload = New-Object Windows.Forms.Button 
$buttondownload.Text = "CTL download..."
$buttondownload.Location = point 190 30
$buttondownload.Width = 150
$buttondownload.Anchor = "top,left"
$buttondownload.Enabled = $true
$buttondownload.add_click({
        #CTL download
        CertUtil -generateSSTFromWU $ctldateiname | Out-Null
                #AUSGABEMELDUNGEN??

        if(Test-Path $ctldateiname)
        {
            $labelButtonpfad.Text = $ctldateiname
            $buttonabgleich.Enabled = $true
            [System.Windows.Forms.MessageBox]::Show("Download erfolgreich.","ROOTCA",0,[System.Windows.Forms.MessageBoxIcon]::Information)| Out-Null
        }
        else
        { [System.Windows.Forms.MessageBox]::Show("Fehler beim Download!","ROOTCA",0,[System.Windows.Forms.MessageBoxIcon]::Information)| Out-Null }
                    })
                    
#CheckBoxen Cert Store erzeugen
$labelCertStores  = New-Object Windows.forms.Label # Label erzeugen
$labelCertStores.Text = "Abgleich mit folgenden Zertifikatsspeichern:   "
$labelCertStores.Location = point 10 85
$labelCertStores.Size = point 250 20
$labelCertStores.Anchor = "top,left"

#CheckBox Local User Store
$checkBoxLocalUserStore = New-Object System.Windows.Forms.CheckBox
$checkBoxLocalUserStore.Text = "Local User"
$checkBoxLocalUserStore.Location = point 20 105
$checkBoxLocalUserStore.Size = point 150 23
$checkBoxLocalUserStore.Checked = $true
#CheckBox Local Machine Store
$checkBoxLocalMachineStore = New-Object System.Windows.Forms.CheckBox
$checkBoxLocalMachineStore.Text = "Local Machine"
$checkBoxLocalMachineStore.Location = point 180 105
$checkBoxLocalMachineStore.Size = point 150 23
$checkBoxLocalMachineStore.Checked = $true

$labelCertStoresuniqe  = New-Object Windows.forms.Label # Label erzeugen
$labelCertStoresuniqe.Text = "Unique: -"
$labelCertStoresuniqe.Location = point 340 110
$labelCertStoresuniqe.Size = point 75 20
$labelCertStoresuniqe.Anchor = "top,left"

#Clients auslesen Button erzeugen
$buttonabgleich = New-Object Windows.Forms.Button 
$buttonabgleich.Text = "Zertifikats-Speicher mit CTL abgleichen"
$buttonabgleich.Location = point 10 150
$buttonabgleich.Width = 220
$buttonabgleich.Anchor = "top,left"
$buttonabgleich.Enabled = $false
$buttonabgleich.add_click({
                        ABGLEICH
                    })
                    
$objListBoxZertifikate = New-Object System.Windows.Forms.ListView 
$objListBoxZertifikate.Location = point 10 190
$objListBoxZertifikate.Anchor = "top,left"
$objListBoxZertifikate.Size = point 470 290
$objListBoxZertifikate.Height = 290
$objListBoxZertifikate.View = 'Details'
$objListBoxZertifikate.FullRowSelect = $true
$objListBoxZertifikate.HideSelection = $false
$objListBoxZertifikate.MultiSelect = $true
    #Spaltenueberschrift fuer ListView
    $objListBoxZertifikate.Columns.Add('Zertifikat')
    $objListBoxZertifikate.Columns.Add('In CTL')
    $objListBoxZertifikate.Columns.Add('Not before')
    $objListBoxZertifikate.Columns.Add('Not after')
    $objListBoxZertifikate.Columns.Add('Thumbprint')
    $objListBoxZertifikate.Columns.Add('Store')
$objListBoxZertifikate.AutoResizeColumns([Windows.Forms.ColumnHeaderAutoResizeStyle]::HeaderSize)                 

#Tab Hilfe------------------------------------------------------
# Label erzeugen
$labelHilfe  = New-Object Windows.forms.Label 
$Hilfetext = "`nAblauf:"
$Hilfetext += "`n-----------------"
$Hilfetext += "`n1.1 "
$Hilfetext += "`n1.2 "
$Hilfetext += "`n3. "
$Hilfetext += "`n4. "
$Hilfetext += "`n"
$Hilfetext += "`n"
$Hilfetext += "`n`nFarblegende:"
$Hilfetext += "`n-----------------"
$Hilfetext += "`nGrün/Green:  "
$labelHilfe.Text = $Hilfetext 
$labelHilfe.Location = point 10 10
$labelHilfe.Size = point 300 300
#------------------------------------------------------------------

#ProgressBar erzeugen
$progress = New-Object System.Windows.Forms.ProgressBar
$progress.Name = 'progress'
$progress.Visible = $false
$progress.Value = 0
$progress.Location = point 360 535
$progress.Size = point 170 23
$progress.Style="Continuous"

#Beenden Button erzeugen
$buttonbeenden = New-Object Windows.Forms.Button 
$buttonbeenden.Text = "Beenden"
$buttonbeenden.Location = point 10 535
$buttonbeenden.Anchor = "top,left"
$buttonbeenden.add_click({
                    $formmain.DialogResult = "OK"
                    $formmain.Close()
                    })
#------------------------------------------------------------------

#Steuerelemente hinzufuegen
$formmain.Controls.AddRange(($buttonbeenden, $progress, $TabControl)) 
$TabROOTCA.Controls.AddRange(($labelButtonquelle, $labelButtonpfad, $buttondatei, $buttondownload, $labelCertStores, $checkBoxLocalUserStore, $checkBoxLocalMachineStore, $labelCertStoresuniqe, $buttonabgleich, $objListBoxZertifikate))    
$TabHilfe.Controls.AddRange(($labelHilfe)) 
#$TabCTL.Controls.AddRange(())
$formmain.add_shown({$formmain.Activate()})
$formmain.ShowDialog()