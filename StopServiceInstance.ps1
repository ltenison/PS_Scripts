$svcTypeName = "SharePoint Server Search"
$server = $env:COMPUTERNAME
$ServiceInstance = (Get-SPServiceInstance -Server $server | Where {$_.TypeName -eq $svcTypeName})
if($ServiceInstance.Status -eq "Online" -or $ServiceInstance.Status -eq "Provisioning") {
   Write-Host -ForegroundColor Green "Service", $svcTypeName, "currently", $ServiceInstance.Status
   Write-Host -ForegroundColor Green "Now Stopping Service",$svcTypeName
   $ServiceInstance | Stop-SPServiceInstance
   while ($ServiceInstance.Status -ne "Disabled") {
      Start-Sleep 2
      $ServiceInstance = Get-SPServiceInstance $ServiceInstance
      }
   Write-Host "Finished.  Service now stopped."
}
else {
   Write-Host "Finished.  Service was already stopped."
   }