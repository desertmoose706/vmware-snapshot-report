# vmware-snapshot-report
Connects to VMware vCenter and Reports on Current Snapshots

## PRE-REQ:
```
Install-Module VMware.PowerCLI -Scope CurrentUser
```

## USAGE WITH ARGUMENTS:
```
./getSnapshots.ps1 -emailfrom 'email@email.com' -emailto 'email@email.com' -vcserver 'myvcenter.e.com' -vcuser 'my@user.com' -vcpassword 'PaSSWoRD'
```

## Usage with $Env:Variables
Setting Env:Variables for:
- VM_SMTP_SERVER
- VM_EMAIL_FROM
- VM_EMAIL_TO
- VM_VSPHERE_SERVER
- VM_VSPHERE_USER
- VM_VSPHERE_PASSWORD

```
$Env:VM_SMTP_SERVER=smtp.host.com
$Env:VM_EMAIL_FROM=email@email.com
$Env:VM_EMAIL_TO=email@email.com
$Env:VM_VSPHERE_SERVER=myvcenter.e.com
$Env:VM_VSPHERE_USER=my@user.com
$Env:VM_VSPHERE_PASSWORD=PaSSWoRD
```