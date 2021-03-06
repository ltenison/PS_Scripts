$Service = Get-SPServiceApplication -Name "sp_insightdev Managed Metadata Service"
if ($Service -eq $null)
    {
	   Write-host -Foreground red "Error: Cant find $Name"
    }
    else 
    {
        $proxies = Get-SPServiceApplicationProxy
        foreach ($Proxy in $proxies)
        {
	       if ($Service.IsConnected($Proxy))
           {
		      Write-host "Proxy Found"
		      if ($Proxy.Status -ne "Online")
              {
			     Write-host -Foreground red "Error: The Proxy is currently is Status: $($Proxy.Status)"
			     Write-host -Foreground red "Error: You will have to enable the Proxy before it can be modified, re-run the script once completed"
		      } 
              else 
              {
        	     Write-host -Foreground green "OK: The Proxy is currently in Status: $($Proxy.Status) $($Proxy.DisplayName)"
              }           
           }
	    }
     }
Write-Host "Finished."