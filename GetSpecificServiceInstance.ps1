$svcName = "Secure Store Service"
$server = $env:computername
$svcInstance = get-spserviceinstance -Server $server | where {$_.TypeName -eq $svcName}
write-host "Status for ", $svcName, "is:", $svcInstance.Status