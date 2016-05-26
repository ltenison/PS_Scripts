#
# SharePoint 2010 Unleashed - PowerShell farm config script
# http://www.amazon.com/Microsoft-SharePoint-2010-Unleashed-Michael/dp/0672333252
# Copyright: Conan Flint, Toni Frankola, Michael Noel, Muhanad Omar
# Version: 1.0.1, Apr 2011.
# 
# Source: http://tinyurl.com/SPFarm-Config
# Licensed under the MIT License:
# http://www.opensource.org/licenses/mit-license.php
# Updated by Jeff Holliday, Ensynch Inc.
#
#
$configType = read-host "Do you wish to create a new farm? (Y/N)"
if ($ConfigType -eq "N") 
{ 
    $DatabaseServer = read-host "Preparing to join existing farm. Please specify the name of the farm SQL Server (with instance name if not default)";
    $ConfigDB = read-host "Specify the name of the Farm Configuration Database (i.e. SP_CONFIG_DB)";
    $Passphrase = read-host "Enter the Farm passphrase" -assecurestring 
} 
else 
{ 
    $DatabaseServer = read-host "Preparing to create a new Farm. Please specify the name of your SQL Server (with instance name if not default)";
    $FarmName = read-host "Please specify a name for your Farm (ex. SP2010Dev)";
    $ConfigDB = $FarmName+"SP_CONFIG_DB";
    $AdminContentDB = $FarmName+"SP_ADMIN_CONTENT_DB";
    Write-Host "Please enter the credentials for your Farm Account, with domain (ex. DOMAIN\svc.sp.farm)";
    $FarmAcct = Get-Credential;
    $Passphrase = read-host "Enter a secure Farm passphrase (must meet password complexity requirements)" -assecurestring;
    $Port = read-host "Enter a port number for Central Admin";
    $Authentication = read-host "Specify your authentication provider (NTLM[default] or Kerberos)"; 
}
if((Get-PSSnapin | Where {$_.Name -eq "Microsoft.SharePoint.PowerShell"}) -eq $null) 
    {
		Add-PSSnapin Microsoft.SharePoint.PowerShell;
    }
if ($ConfigType -eq "N") 
{
    Write-Host "Your SharePoint Farm is being modified..."
    Connect-SPConfigurationDatabase -DatabaseName $ConfigDB -DatabaseServer $DatabaseServer -Passphrase $Passphrase
} 
else
{
    Write-Host "Your SharePoint Farm is being configured..."
    New-SPConfigurationDatabase -DatabaseName $ConfigDB -DatabaseServer $DatabaseServer -AdministrationContentDatabaseName $AdminContentDB -Passphrase $Passphrase -FarmCredentials $FarmAcct
}
Initialize-SPResourceSecurity
Install-SPService
Install-SPFeature -AllExistingFeatures
if ($ConfigType -eq "Y") 
{
    New-SPCentralAdministration -Port $Port -WindowsAuthProvider $Authentication
    Write-Host "Your SharePoint 2010 CA App has been created!"
}
Install-SPHelpCollection -All
Install-SPApplicationContent
if ($ConfigType -eq "Y") 
{
    Write-Host "Your SharePoint 2010 Farm has been created!"
}
else
{
    Write-Host "Your SharePoint 2010 Farm has been modified!"
}
#
if ($ConfigType -eq "Y") 
{
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

}
#
$serviceAppsConfig = read-host "Do you wish to configure Service Applications? (Y/N)"
if($serviceAppsConfig -eq "Y") 
{
#	PowerShell -File "ConfigServiceApps.ps1"
}
else 
{
	Write-Host "Finished..."
#	$x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}