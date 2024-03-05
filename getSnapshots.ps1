###
#
#    Creates CSV file of VMware snapshots and sends to team.
#
#    Created by: Aaron G
#       Created: 2021/06/18
#       Updated: 2024/03/04
#
#       PRE-REQ: 
# Install-Module VMware.PowerCLI -Scope CurrentUser
#
#         USAGE:
# ./getSnapshots.ps1 -smtpserver 'smtp.host.com' -emailfrom 'email@email.com' -emailto 'email@email.com' -vcserver 'myvcenter.e.com' -vcuser 'my@user.com' -vcpassword 'PaSSWoRD'
# 
#            OR:
# Setting Env:Variables for VM_SMTP_SERVER, VM_EMAIL_FROM, VM_EMAIL_TO, VM_VSPHERE_SERVER, VM_VSPHERE_USER, VM_VSPHERE_PASSWORD
# $Env:VM_SMTP_SERVER=
# $Env:VM_EMAIL_FROM=
# $Env:VM_EMAIL_TO=
# $Env:VM_VSPHERE_SERVER=
# $Env:VM_VSPHERE_USER=
# $Env:VM_VSPHERE_PASSWORD=
#
###
param (
    [string]    $smtpserver,
    [string]    $emailfrom,
    [string]    $emailto,
    [string]    $vcserver,
    [string]    $vcuser,
    [string]    $vcpassword
)
$version = "0.1.4"
Write-Host "---------------------------------------"
Write-Host ("VMware SnapShots Handler, v" + $version)
Write-Host "Aaron at It's Geekhead, 2024"
Write-Host "---------------------------------------"

### SET DEFAULT VARS HERE
if ($Env:VM_SMTP_SERVER) {
    $smtpserver = $Env:VM_SMTP_SERVER
} else {
    if ([string]::IsNullOrWhiteSpace($smtpserver))  { $smtpserver   = "mailhost.home.itsgeekhead.com" }
}
if ($Env:VM_EMAIL_FROM) {
    $emailfrom = $Env:VM_EMAIL_FROM
} else {
    if ([string]::IsNullOrWhiteSpace($emailfrom))   { $emailfrom    = "No Reply <no-reply@itsgeekhead.com>" }
}
if ($Env:VM_EMAIL_TO) {
    $emailto = $Env:VM_EMAIL_TO
} else {
    if ([string]::IsNullOrWhiteSpace($emailto))     { $emailto      = "Aaron <no-reply@itsgeekhead.com>" }
}
if ($Env:VM_VSPHERE_SERVER) {
    $vcserver = $Env:VM_VSPHERE_SERVER
} else {
    if ([string]::IsNullOrWhiteSpace($vcserver))    { $vcserver     = "192.168.15.17" }
}
if ($Env:VM_VSPHERE_USER) {
    $vcuser = $Env:VM_VSPHERE_USER
} else {
    if ([string]::IsNullOrWhiteSpace($vcuser))      { $vcuser       = "root" }
}
if ($Env:VM_VSPHERE_PASSWORD) {
    $vcpassword = $Env:VM_VSPHERE_PASSWORD
} else {
    if ([string]::IsNullOrWhiteSpace($vcpassword))  {   
        Write-Host "VMware Password: NOT SET"
        throw 'vcpassword Parameter and VSPHERE_PASSWORD environment variable not set, cannot continue'
    }
}

[securestring]$vm_creds_password    = ConvertTo-SecureString $vcpassword -AsPlainText -Force
[pscredential]$vm_creds             = New-Object System.Management.Automation.PSCredential ($vcuser, $vm_creds_password)


Write-Host ("VMware Host         : " + $vcserver)
Write-Host ("VMware Username     : " + $vcuser)
Write-Host ("VMware Password     : *****")
Write-Host ("SMTP Server         : " + $smtpserver)
Write-Host ("From Email          : " + $emailfrom)
Write-Host ("To Email            : " + $emailto)


# start work
Write-Host ""
Write-Host "---"

# connect to vcenters
try {
    Write-Host ("Connecting to " + $vcserver + "...")
    Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Scope Session -Confirm:$false
    connect-viserver -server $vcserver -force -Credential $vm_creds -ErrorAction Stop
} catch {
    throw "Could not connect to " + $vcserver
}


# Get snapshots and output to CSV file
$getdatetoday  = get-date -f yyyy-MM-dd
$filename      = "snapshots-$getdatetoday.csv"
$html_filename = "snapshots-$getdatetoday.html"
try {
    Write-Host ("Getting VM snapshots ...")
    get-vm | get-snapshot | Sort-Object -Property Created `
      | select-object VM, SizeGB, Created, Name, PowerState | export-csv -path .\$filename
    
    Write-Host (" ----- CSV Contents ----- ")
    get-content -Path .\$filename
    Write-Host (" ----- End Contents ----- ")
} catch {
    throw "Could not get snapsots"
}


# Check if a file for snapshots was created
if (Test-Path -Path .\$filename -PathType Leaf) {
    
    # lets read in the CSV
    Write-Host (" ----- Import CSV Contents ----- ")
    try {
        $snaps = Import-Csv -Path .\$filename
        $snapcount = $snaps | measure
    } catch {
        throw "Could not read CSV " + $filename
    }

    Write-Host (" ----- Process CSV Contents ----- ")
    if ($snapcount.Count -ge 1) {
        # start creating the email
        $email_str = "<html>"
        $email_str = $email_str + "<head><style type=`"text/css`">"
        $email_str = $email_str + "td { padding:5px; }"
        $email_str = $email_str + "</style></head>"
        $email_str = $email_str + "<body>"
        $email_str = $email_str + "<p>"
        $email_str = $email_str + "<p>This alert displays all snaps in VMware.</p>"
        $email_str = $email_str + "<p><b><u>(" + $snapcount.Count + ") active snapshots</u></b></p>"
        $email_str = $email_str + "<p><table style=`"border: 1px solid #CCCCCC;`">"
        $email_str = $email_str + "<tr style=`"background-color: #CCCCCC;`"><td><b>VM</b></td><td><b>SizeGB</b></td><td><b>Created</b></td><td><b>Notes</b></td></tr>"
        
        Write-Host "$($snapcount.Count) ACTIVE SNAPSHOTS:"
        # next lets iterate each item from the import
        try {
            ForEach ($snap in $snaps) {
                $vm_vm = $snap.VM
                $vm_sizegb = [math]::round([decimal]$snap.SizeGB + 0.05,1)
                $vm_created = $snap.Created
                $vm_notes = $snap.Name
                Write-Host "- $($vm_vm) is $($vm_sizegb), created on $($vm_created), name: $($vm_notes)."
                $email_str = $email_str + "<tr><td>" + $vm_vm + "</td><td>" + $vm_sizegb + "</td><td>" + $vm_created + "</td><td>" + $vm_notes + "</td></tr>"
            }
        } catch {
            throw "Can't process CSV"
        }

        $email_str = $email_str + "</table></p><br/><hr/>"
        $email_str = $email_str + "<p>Produced by Your Team. Written by It's Geekhead (www.itsgeekhead.com)</p>"
        $email_str = $email_str + "</body></html>"

        # Write HTML to disk too
        $email_str | Out-File .\$html_filename

        # Send email
        Write-Host (" ----- Send Email ----- ")
        try {
            Send-MailMessage -From "${emailfrom}" -To "${emailto}" `
            -Subject "VM Snapshots Report for ${getdatetoday}" -Body "${email_str}" -BodyAsHtml `
            -Attachments .\$filename -Priority High -DeliveryNotificationOption OnSuccess, OnFailure -SmtpServer $smtpserver  
        } catch {
            throw "Could not send email to " + $emailto
        }
    } else {
        Write-Host "0 ACTIVE SNAPSHOTS. No processing needed."
    }

}
