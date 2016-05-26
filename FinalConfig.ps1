# Load SharePoint Snappin if not loaded
if((Get-PSSnapin | Where {$_.Name -eq "Microsoft.SharePoint.PowerShell"}) -eq $null) {
	Add-PSSnapin Microsoft.SharePoint.PowerShell;
}

# Set Additional Configuration Options
$SharePointLogLocation = read-host "What is the root folder to store SharePoint Logs? (i.e. d:\sharepoint\logs)";
Write-Host $SharePointLogLocation"\Diag";
