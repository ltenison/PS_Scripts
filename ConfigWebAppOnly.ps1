	do 
    {
	$WebAppCreation = read-host "Would you like to provision a Web Application? (Y/N)";
	if ($WebAppCreation -eq "Y") 
    {
	    $WebAppName = read-host "What is the name of the Web Application? (i.e. SharePoint_Main)";
	    $RegisterNewAppPool = read-host "Would you like to register a new managed account to be used with this Web Application? (Y/N)";
		if ($RegisterNewAppPool -eq "Y") 
        {
			Write-Host "Please enter the credentials to be used for the Web Application AppPool (ex. ENSYNCH\svc.sp.apppool)";
			$AppPoolAcct = Get-Credential;
			New-SPManagedAccount $AppPoolAcct;
		}
		else 
        {
			Write-Host "Please enter the managed account to be used for the Web Application AppPool (ex. ENSYNCH\svc.sp.apppool)";
			$AppPoolAcct = Get-Credential;
		}
	    $AppPoolName = $WebAppName+"_AppPool";
	    $ContentDBName = $WebAppName+"_CONTENT_DB01";
	    $HostHeaderQ = read-host "Would you like to specify a host header? (Y/N)";
        if ($HostHeaderQ -eq "Y") 
        {
            $HostHeader = read-host "Please specify a host header for your Web Application (ex. intranet.ensynch.info)";
            $URL = "http://"+$HostHeader;
			Write-Host $URL;
			Write-Host $WebAppName;
			$objIPProperties = [System.Net.NetworkInformation.IPGlobalProperties]::GetIPGlobalProperties();
			$FQDN = "{0}.{1}" -f $objIPProperties.HostName, $objIPProperties.DomainName;
            Write-Host "Creating your Web Application...";
            New-SPWebApplication -Name $WebAppName -Port 80 -HostHeader $FQDN -Url $URL -ApplicationPool $AppPoolName -ApplicationPoolAccount (Get-SPManagedAccount $AppPoolAcct.UserName) -DatabaseServer $DatabaseServer -DatabaseName $ContentDBName;
            Write-Host "Configuration of "$WebAppName" completed.";
        }
        else 
        {
            Write-Host "Creating your Web Application...";
            New-SPWebApplication -Name $WebAppName -Port 80 -ApplicationPool $AppPoolName -ApplicationPoolAccount (Get-SPManagedAccount $AppPoolAcct.UserName) -DatabaseServer $DatabaseServer -DatabaseName $ContentDBName;
            Write-Host "Configuration of "$WebAppName" completed.";
        }
#
# Add section later for create Site Collection at root of new web application
# New-SPSite $URL -OwnerAlias $FarmAcct.UserName -Language 1033 -Template "STS#0" -Name "Team Site";
#
        }
    }
	until ($WebAppCreation -eq "N");
#
	Write-Host "Finished..."
