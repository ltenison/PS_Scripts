# SharePoint 2010 Unleashed - PowerShell farm config script
# http://www.amazon.com/Microsoft-SharePoint-2010-Unleashed-Michael/dp/0672333252
# Copyright: Conan Flint, Toni Frankola, Michael Noel, Muhanad Omar
# Version: 1.0.1, Apr 2011.
# 
# Source: http://tinyurl.com/SPFarm-Config
# Licensed under the MIT License:
# http://www.opensource.org/licenses/mit-license.php
# Updated by Jeff Holliday, Ensynch Inc.
# Updated for SP2013 by Larry Tenison, Insight Inc.

# Load SharePoint Snappin if not loaded
Add-PsSnapin Microsoft.SharePoint.PowerShell -ErrorAction SilentlyContinue

$configNewFarm = read-host "Do you wish to create a NEW farm? (Y/N)"
if ($configNewFarm -eq "N") { 
    Write-Host "Preparing to join EXISTING farm."
    $DatabaseServer = read-host "Please specify the name of your SQL Server (with instance name if not default)";
    $ConfigDB = read-host "Specify the name of the Farm Configuration Database (i.e. SP_CONFIG_DB)";
    $Passphrase = read-host "Enter the Farm passphrase" -assecurestring 
} 
else { 
    Write-Host "Preparing to join CREATE a NEW farm."
    $DatabaseServer = read-host "Please specify the name of your SQL Server (with instance name if not default)";
    $FarmName = read-host "Please specify a name for your Farm (ex. SP2010Dev)";
    $ConfigDB = "SP_CONFIG_DB";
    $AdminContentDB = "SP_ADMIN_CONTENT_DB";
    Write-Host "Please enter the credentials for your Farm Account (ex. ENSYNCH\svc.sp.farm)";
    $FarmAcct = Get-Credential;
    $Passphrase = read-host "Enter a secure Farm passphrase (must meet password complexity requirements)" -assecurestring;
    $Port = read-host "Enter a port number for Central Admin";
    $Authentication = read-host "Specify your authentication provider (NTLM[default] or Kerberos)"; 
}
if ($configNewFarm -eq "N") {
    Write-Host "Your SharePoint Farm is being modified..."
    Connect-SPConfigurationDatabase -DatabaseName $ConfigDB -DatabaseServer $DatabaseServer -Passphrase $Passphrase
} 
else {
    Write-Host "Your SharePoint Farm is being configured..."
    New-SPConfigurationDatabase -DatabaseName $ConfigDB -DatabaseServer $DatabaseServer -AdministrationContentDatabaseName $AdminContentDB -Passphrase $Passphrase -FarmCredentials $FarmAcct
}
Initialize-SPResourceSecurity
Install-SPService
Install-SPFeature -AllExistingFeatures
if ($configNewFarm -eq "Y") {
    Write-Host "Central Administration is being provisioned..."
    New-SPCentralAdministration -Port $Port -WindowsAuthProvider $Authentication
}
Install-SPHelpCollection -All
Install-SPApplicationContent
if ($configNewFarm -eq "Y") {
    Write-Host "Your SharePoint 2010 Farm has been created!"
}
else {
    Write-Host "Your SharePoint 2010 Farm has been modified!"
}
#
if ($configNewFarm -eq "Y") {
  do {
	$WebAppCreation = read-host "Would you like to provision a NEW Web Application? (Y/N)";
	if ($WebAppCreation -eq "Y") {
	    $WebAppName = read-host "What is the name of the Web Application? (i.e. SharePoint_Main)";
	    $RegisterNewAppPool = read-host "Would you like to register a new managed account for this Web Application? (Y/N)";
		if ($RegisterNewAppPool -eq "Y") {
			Write-Host "Please enter the credentials to be used for the Web Application AppPool (ex. ENSYNCH\svc.sp.apppool)";
			$AppPoolAcct = Get-Credential;
			New-SPManagedAccount $AppPoolAcct;
		}
		else {
			Write-Host "Please enter the managed account to be used for the Web Application AppPool (ex. ENSYNCH\svc.sp.apppool)";
			$AppPoolAcct = Get-Credential;
		}
	    $AppPoolName = $WebAppName+"_AppPool";
	    $ContentDBName = $WebAppName+"_CONTENT_DB01";
	    $HostHeaderQ = read-host "Would you like to specify a host header? (Y/N)";
        if ($HostHeaderQ -eq "Y") {
            $HostHeader = read-host "Please specify a host header for your Web Application (ex. intranet.ensynch.info)";
            $URL = "http://"+$HostHeader;
			Write-Host $URL;
			Write-Host $WebAppName;
			$objIPProperties = [System.Net.NetworkInformation.IPGlobalProperties]::GetIPGlobalProperties();
			$FQDN = "{0}.{1}" -f $objIPProperties.HostName, $objIPProperties.DomainName;
            Write-Host "Creating your Web Application with host header...";
            New-SPWebApplication -Name $WebAppName -Port 80 -HostHeader $FQDN -Url $URL -ApplicationPool $AppPoolName -ApplicationPoolAccount (Get-SPManagedAccount $AppPoolAcct.UserName) -DatabaseServer $DatabaseServer -DatabaseName $ContentDBName;
            Write-Host "Configuration of "$WebAppName" completed.";
        }
        else {
            Write-Host "Creating your Web Application...";
            New-SPWebApplication -Name $WebAppName -Port 80 -ApplicationPool $AppPoolName -ApplicationPoolAccount (Get-SPManagedAccount $AppPoolAcct.UserName) -DatabaseServer $DatabaseServer -DatabaseName $ContentDBName;
            Write-Host "Configuration of "$WebAppName" completed.";
        }
    }
  }
  until ($WebAppCreation -eq "N");
}

$serviceAppsConfig = read-host "Do you wish to configure Service Applications? (Y/N)"
if($serviceAppsConfig -eq "Y") {
    PowerShell -File "ConfigServiceApps.ps1"
    }
else {
	Write-Host "Farm Configuration Finished..."
}