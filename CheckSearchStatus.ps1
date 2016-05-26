    $checkServiceTypeName = "SharePoint Server Search"
	$ServiceInstance = (Get-SPServiceInstance | Where {$_.TypeName -eq $checkServiceTypeName})
    $status = $ServiceInstance.Status
    write-host "Status is:", $status
    #$dbName = "SPLAB2013_StateService"
    #$db = Get-SPStateServiceDatabase -Name $dbName
    #write-host "DB Status is:", $db
    #$appName = "SPLAB2013 State Service Application"
    #$app = Get-SPStateServiceApplication -Name $appname
    #write-host "App Status is:", $app