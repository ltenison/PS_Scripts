$id = "4c6d3d3a-5d23-4e04-a239-f297919289ba"
$svcApp = get-spserviceapplication $id
write-host "Service Name for", $id, "is:", $svcApp.DisplayName