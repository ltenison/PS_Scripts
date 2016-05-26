# Load SharePoint Snappin if not loaded
Add-PsSnapin Microsoft.SharePoint.PowerShell -ErrorAction SilentlyContinue

# Set Diagnostic Log Configuration Options
$logRoot = read-host "What is the root folder to store SharePoint Logs? (i.e. D:\sharepoint\logs)";
$logLocation = "$logRoot\Diag"
Set-SPDiagnosticConfig -LogLocation $logLocation -LogDiskSpaceUsageGB 1 -DaysToKeepLogs 7
Write-Host "SP2013 Diagnostic Logs set to", $logLocation
sleep -s 1
Get-SPDiagnosticConfig
sleep -s 1
$logLocation = "$logRoot\UAP"
Set-SPUsageService -UsageLogLocation $logLocation -UsagelogMaxSpaceGB 1
Write-Host "SP2013 Usage Logs set to", $logLocation
sleep -s 1
Get-SPUsageService