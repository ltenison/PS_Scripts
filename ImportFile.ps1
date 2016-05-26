$siteName = "http://insightaccess-qa.insight.com/services/sales-support"
$exportName = "d:\backup\services collateral.cmp"
write-host "Starting import..."
Import-SPWeb $siteName -Path $exportName -UpdateVersions Overwrite -NoLogFile
write-host "Finished importing" $exportName