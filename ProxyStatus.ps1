#------------------------------------------------------------------------------------------------------
# Name:			Rename-SPServiceApplication
# Descrption: 	This script will rename a Service Application and its Proxy
# Usage:		Run the function with the Name and NewName Parameters
# By: 			Ivan Josipovic, Softlanding.ca
#------------------------------------------------------------------------------------------------------
Function Rename-SPServiceApplication ($Name,$NewName){
$Service = Get-SPServiceApplication -Name $Name

if ($Service -eq $null){
	Write-host -Foreground red "Error: Cant find $Name"
	return 1
}

$proxies = Get-SPServiceApplicationProxy
foreach ($Proxy in $proxies){
	if ($Service.IsConnected($Proxy)){
		Write-host "Proxy Found"
		if ($Proxy.Status -ne "Online"){
			Write-host -Foreground red "Error: The Proxy is currently is Status: $($Proxy.Status)"
			Write-host -Foreground red "Error: You will have to enable the Proxy before it can be modified, re-run the script once completed"
			return 1
		} else {
			$Proxy.Name = $NewName
			$Proxy.Update()
		}
	}
}
$Service.Name = $NewName
$Service.Update()
Write-host "Completed with no Errors"
return 0
}

Rename-SPServiceApplication -Name "WSS_UsageApplication" -NewName "WSS Usage Application"