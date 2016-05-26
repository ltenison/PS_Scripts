Add-PSSnapin Microsoft.SharePoint.PowerShell

## Change these per your environment ##
$databaseServerName = "SP2013\SHAREPOINT"
## Service Application Names ##
## Included Usage and Health, as it does get provisioned and if you want to define DB name ##
## Also Usage Proxy Status is stopped which cause Search Application Topology to not find Admin Service ##
$usageSAName = "Usage and Health Data Collection Service"


Write-Host "Creating Usage Service and Proxy..."

$serviceInstance = Get-SPUsageService

New-SPUsageApplication -Name $usageSAName -DatabaseServer $databaseServerName -DatabaseName "SP2013_UAP_DB" -UsageService $serviceInstance > $null

$usa = Get-SPServiceApplicationProxy | where {$_.TypeName -like "Usage*"} 
$usa.Provision()