$dispName = "sp_insightdev Usage and Health Data Collection Service"
$svcApp = get-spserviceapplication -Name $dispName
write-host "Id for", $dispName, "is:", $svcApp.Id