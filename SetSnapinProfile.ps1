﻿if ($host.UI.RawUI.WindowTitle -ne "Administrator: SharePoint 2013 Management Shell") {
    $ver = $host | select version
    if ($ver.Version.Major -gt 1) {
        $host.Runspace.ThreadOptions = "ReuseThread"
        }
    if ((Get-PSSnapin "Microsoft.SharePoint.PowerShell" -ErrorAction SilentlyContinue) -eq $null) {
        Add-PSSnapin "Microsoft.SharePoint.PowerShell"
        }
    }