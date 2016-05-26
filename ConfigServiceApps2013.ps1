# SharePoint 2010 Unleashed - PowerShell farm config script
# Copyright: Conan Flint, Toni Frankola, Michael Noel, Muhanad Omar
# Version: 1.0, Jan 2011.
# 
# Source: http://tinyurl.com/SPFarm-Config
# Licensed under the MIT License:
# http://www.opensource.org/licenses/mit-license.php
# Edited by Jeff Holliday, Ensynch Inc.
# Updated for SP2013 by Larry Tenison, Insight, Inc.

cls
Add-PSSnapin Microsoft.SharePoint.PowerShell -ErrorAction SilentlyContinue

function Start-SPService($ServiceInstanceTypeName) {
	$ServiceInstance = (Get-SPServiceInstance | Where {$_.TypeName -eq $ServiceInstanceTypeName})
	
	if($ServiceInstance.Status -ne "Online" -and $ServiceInstance.Status -ne "Provisioning") {
		$ServiceInstance | Start-SPServiceInstance 
	}
	
	$i = 0;
	while(-not ($ServiceInstance.Status -eq "Online") -and $i -lt 10) {
		Write-Host -ForegroundColor Yellow "Waiting for the $ServiceInstanceTypeName service to provision...";
		sleep 100;
		$ServiceInstance = (Get-SPServiceInstance | Where {$_.TypeName -eq $ServiceInstanceTypeName})
		
		$i += 1;
		
		if($i -eq 10) {
			$continue = Read-Host "Service $ServiceInstanceTypeName has not yet been provisioned. Would you like to wait? (Y/N)"
			
			if($continue -eq "Y") {
				$i = 0;
			}
		}
	}
}

Function Configure-SPSearch  {
	PARAM($SearchAppPoolName, $FarmName, $SearchAppPoolAccountName, $IndexLocation, $DatabaseServer)

#Parameter Settings (examples)
#$SearchAppPoolName = "SearchAppPool"
#$SearchAppPoolAccountName = "ltg5lab\SP_serviceapps"
#$FarmName = "SPLAB2013"
#IndexLocation must be empty on the file system of the server, will be deleted during the process!
#$IndexLocation = "E:\Search" 
#$DatabaseServer = "VM4\VM4SP2013"
#$DatabaseName = "SP2013LAB_Search"

#The two settings below are default service name strings
    $SearchServiceName = "Search Service Application"
    $SearchServiceProxyName = "Search Service Application Proxy"

#Database name is derived from the $FarmName paramter below
    $DatabaseName = $FarmName+"_Search"
 
    Write-Host -ForegroundColor Yellow "Checking if Search Application Pool exists"
    $spAppPool = Get-SPServiceApplicationPool -Identity $SearchAppPoolName -ErrorAction SilentlyContinue
 
    if (!$spAppPool)
    {
        Write-Host -ForegroundColor Green "Creating Search Application Pool"
        $spAppPool = New-SPServiceApplicationPool -Name $SearchAppPoolName -Account $SearchAppPoolAccountName -Verbose
    }
 
    Write-Host -ForegroundColor Yellow "Checking if Search Service Application exists"
    $ServiceApplication = Get-SPEnterpriseSearchServiceApplication -Identity $SearchServiceName -ErrorAction SilentlyContinue
    if (!$ServiceApplication)
    {
        Write-Host -ForegroundColor Green "Creating Search Service Application"
        $ServiceApplication = New-SPEnterpriseSearchServiceApplication -Name $SearchServiceName -ApplicationPool $spAppPool.Name -DatabaseServer  $DatabaseServer -DatabaseName $DatabaseName
    }
 
    Write-Host -ForegroundColor Yellow "Checking if Search Service Application Proxy exists"
    $Proxy = Get-SPEnterpriseSearchServiceApplicationProxy -Identity $SearchServiceProxyName -ErrorAction SilentlyContinue
    if (!$Proxy)
    {
        Write-Host -ForegroundColor Green "Creating Search Service Application Proxy"
        New-SPEnterpriseSearchServiceApplicationProxy -Name $SearchServiceProxyName -SearchApplication $SearchServiceName
    }
 
    $searchInstance = Get-SPEnterpriseSearchServiceInstance -local 
    $InitialSearchTopology = $ServiceApplication | Get-SPEnterpriseSearchTopology -Active 
    $SearchTopology = $ServiceApplication | New-SPEnterpriseSearchTopology
 
    New-SPEnterpriseSearchAnalyticsProcessingComponent -SearchTopology $SearchTopology -SearchServiceInstance $searchInstance
    New-SPEnterpriseSearchContentProcessingComponent -SearchTopology $SearchTopology -SearchServiceInstance $searchInstance
    New-SPEnterpriseSearchQueryProcessingComponent -SearchTopology $SearchTopology -SearchServiceInstance $searchInstance
    New-SPEnterpriseSearchCrawlComponent -SearchTopology $SearchTopology -SearchServiceInstance $searchInstance 
    New-SPEnterpriseSearchAdminComponent -SearchTopology $SearchTopology -SearchServiceInstance $searchInstance
 
    set-SPEnterpriseSearchAdministrationComponent -SearchApplication $ServiceApplication -SearchServiceInstance  $searchInstance

    Write-Host -ForegroundColor Green "Removing Old Root Dir", $IndexLocation  
    Remove-Item -Recurse -Force -LiteralPath $IndexLocation -ErrorAction SilentlyContinue
    sleep -s 10
    Write-Host -ForegroundColor Green "Re-Creating Root Dir", $IndexLocation
    mkdir -Path $IndexLocation -Force 
    sleep -s 5
 
    # The cmdlet below bombs when trying to bind to the RootDirectory parameter
    # The offending paramter has been removed
    $ic = New-SPEnterpriseSearchIndexComponent -SearchTopology $SearchTopology -SearchServiceInstance $searchInstance
     
    # The work-around code below is intended to FORCE the proper RootDirectory just created into the new Index component
    $ic.RootDirectory = $IndexLocation
    # End of work-around

    Write-Host -ForegroundColor Green "Activating new topology"
    $SearchTopology.Activate()
 
    Write-Host -ForegroundColor Yellow "Next call will provoke an error but after that the old topology can be deleted - just ignore it!"
    $InitialSearchTopology.Synchronize()
 
    Write-Host -ForegroundColor Yellow "Deleting old topology"
    Remove-SPEnterpriseSearchTopology -Identity $InitialSearchTopology -Confirm:$false
    Write-Host -ForegroundColor Green "Old topology deleted"
    Write-Host -ForegroundColor Green "Done - Search service app provisioned."
}


function Start-SPTimer {
	$spTimerService = Get-Service "SPTimerV4"
	
	if($spTimerService.Status -ne "Running") {
		Write-Host -ForegroundColor Yellow "SharePoint 2010 Timer Service is not running. Atempting to start the timer."
		Start-Service "SPTimerV4"
		$spTimerService = Get-Service "SPTimerV4"
		
		while($spTimerService.Status -ne "Running") {
			Start-Sleep -Seconds 10
			Start-Service "SPTimerV4"
			$spTimerService = Get-Service "SPTimerV4"
		}
		
		Write-Host -ForegroundColor Green "SharePoint 2010 Timer Service is running."
	}
	else {
		Write-Host -ForegroundColor Green "SharePoint 2010 Timer Service is running."
	}
}



Function Get-SPServiceApplicationPoolByName($SPApplicationPoolName, $ManagedAccount) {

	$appPool = Get-SPServiceApplicationPool | Where {$_.Name -eq $SPApplicationPoolName}
	
	if($appPool -eq $null) {
		$appPool = New-SPServiceApplicationPool -Name $SPApplicationPoolName -Account $ManagedAccount
	}
	
	Return $appPool
}

Function Get-SPManagedAccountByName($AccountName) {
	$managedAccount = Get-SPManagedAccount | Where {$_.Username -eq $AccountName}

	if($managedAccount -eq $null) {
		Write-Host "Please enter the credentials for your Service Applications Managed Account (i.e. ENSYNCH\svc.sp.apps)";
    	$managedAccountCredential = Get-Credential;
		$managedAccount = New-SPManagedAccount $managedAccountCredential
	}
	
	Return $managedAccount
}

Function Get-SPServiceApplicationByType($TypeName) {
	$serviceApplications = Get-SPServiceApplication | Where  {$_.TypeName -eq $TypeName}
	
	if($serviceApplications -ne $null) {
		$true;
	}
	else {
		$false;
	}
}

Function New-SPStateServiceApplicationGroup($FarmName){ 
		$dbName = $FarmName + "_StateService"
		
		Write-Host -ForegroundColor Yellow "Installing State Service Application..."
		
		New-SPStateServiceDatabase $dbName | New-SPStateServiceApplication -Name "$FarmName State Service Application" | New-SPStateServiceApplicationProxy -Name "$FarmName State Service Application Proxy" -DefaultProxyGroup
		sleep 10;
		
		Write-Host -ForegroundColor Green "State Service Application installed..."
}

Function New-SPUsageApplicationAndProxy($FarmName) {
	Write-Host -ForegroundColor Yellow "Installing Usage and Health Data Collection Service..."
	
	$dbName = $FarmName + "_UsageandHealthDataCollectionService"
	New-SPUsageApplication "$FarmName Usage and Health Data Collection Service" -DatabaseName $dbName
	$usageApplicationProxy = Get-SPServiceApplicationProxy | where{$_.Name -eq "$FarmName Usage and Health Data Collection Service"}

	if($usageApplicationProxy.Status -eq "Disabled") {
		$usageApplicationProxy.Status = "Online";
		$usageApplicationProxy.Update();
	}
	
	Write-Host -ForegroundColor Green "Installing Usage and Health Data Collection Service installed."
}

Function Rename-SQLDatabase {
	param (
  		[string] $ServerName,
  		[string] $SourceDb,
  		[string] $DestDb
)

	$connection = New-Object System.Data.SqlClient.SqlConnection
	$command = New-Object System.Data.SqlClient.SqlCommand

	$connection.ConnectionString = "Server=$ServerName;Integrated Security=True;"
 
	$command.CommandText = "ALTER DATABASE [$SourceDb] SET OFFLINE WITH ROLLBACK IMMEDIATE;ALTER DATABASE [$SourceDb] SET ONLINE;EXEC sp_renamedb [$SourceDb], [$DestDb];"
	$command.Connection = $connection

	$command.Connection.Open();
	$command.ExecuteNonQuery();
	$command.Connection.Close();
}


# Starting SP Timer Service
Start-SPTimer

#Collect Service App Parameters
$appPoolName = Read-Host "Please specify a name for ServiceApp application pool (eg. ServiceAppPool)"
$managedAccountName = Read-Host "Please enter service app pool managed account (eg. CompanyABC\sp_service)"
$managedAccount = Get-SPManagedAccountByName $managedAccountName
$appPool = Get-SPServiceApplicationPoolByName $appPoolName $managedAccount
$FarmName =  Read-Host "Please enter the name of your SP2013 Farm (e.g. SPLAB2013)";

#Step Through the Service Apps to Provision
$decision = read-host "Would you like to install State Service Application? (Y/N)"
if ($decision -eq "Y") { 
	New-SPStateServiceApplicationGroup $FarmName
}

$decision = read-host "Would you like to install Usage and Health Data Collection Service Application? (Y/N)"
if ($decision -eq "Y") { 
	New-SPUsageApplicationAndProxy $FarmName
}

$decision = read-host "Would you like to install Access Services? (Y/N)"
if ($decision -eq "Y") { 
	Write-Host -ForegroundColor Yellow "Installing Access Services..."
	Start-SPService("Access Database Service")
	New-SPAccessServiceApplication -Name "$FarmName Access Services" -ApplicationPool $appPool -Default
	Write-Host -ForegroundColor Green "Access Services installed."
}

$decision = read-host "Would you like to install Business Data Connectivity Service? (Y/N)"
if ($decision -eq "Y") { 
	Write-Host -ForegroundColor Yellow "Installing Business Data Connectivity Service..."
	Start-SPService("Business Data Connectivity Service")
	
	$dbName = $FarmName + "_BusinessDataConnectivityService"
	
	New-SPBusinessDataCatalogServiceApplication -Name "$FarmName Business Data Connectivity Service" -ApplicationPool $appPool -databaseName $dbName
	Write-Host -ForegroundColor Green "Business Data Connectivity Service installed."
}

$decision = read-host "Would you like to install SP2013 Search Service? (Y/N)"
if ($decision -eq "Y") { 	
	Write-Host -ForegroundColor Yellow "Installing Search Service..."
	
	$newAccount = Read-Host "Would you like to use $managedAccountName as the search service account? (Y/N)"
	if($newAccount -eq "N") {
		$searchAccountName = Read-Host "Please enter Search managed account (eg. CompanyABC\sp_search)"
		$SearchAppPoolAccountName = Get-SPManagedAccountByName $searchAccountName
	}
	else {
		$SearchAppPoolAccountName = $managedAccount
	}
	
	if(-not (Get-SPServiceApplicationByType("Usage and Health Data Collection Service Application"))) { 
		$decision = Read-Host "Usage and Health Data Collection Service Application needs to be installed to run Search Service. Would you like to install it now (Y/N)?"
		if ($decision -eq "Y") { 
			New-SPUsageApplicationAndProxy $FarmName
		}
	}
	
    #Fill in Function Parameters
    $SearchAppPoolName = $appPoolName
    $IndexLocation =  Read-Host "Please enter the root file system location for Search index (e.g. E:\SharePoint)"
    $DatabaseServer =  Read-Host "Please enter the name or instance of your SQL DB Server (e.g. VM4 or VM4\VM4SP2013)";
	
    Configure-SPSearch $SearchAppPoolName $FarmName $SearchAppPoolAccountName $IndexLocation $DatabaseServer 
	
	Write-Host -ForegroundColor Green "Search Service installed."
}

$decision = read-host "Would you like to install Excel Services? (Y/N)"
if ($decision -eq "Y") { 	
	Write-Host -ForegroundColor Yellow "Installing Excel Services..."
	Start-SPService("Excel Calculation Services")
	New-SPExcelServiceApplication -Name "$FarmName Excel Services" -ApplicationPool $appPool -Default
	Write-Host -ForegroundColor Green "Excel Services installed."
}

$decision = read-host "Would you like to install Managed Metadata Service? (Y/N)"
if ($decision -eq "Y") { 
	Write-Host -ForegroundColor Yellow "Installing Managed Metadata Service..."
	Start-SPService("Managed Metadata Web Service")
	
	$dbName = $FarmName + "_ManagedMetadataService"

	$MetaDataServiceApp = New-SPMetadataServiceApplication -Name "$FarmName Managed Metadata Service" -ApplicationPool $appPool -DatabaseName $dbName
	$MetaDataServiceAppProxy = New-SPMetadataServiceApplicationProxy -Name "$FarmName Managed Metadata Service Proxy" -ServiceApplication $MetaDataServiceApp -DefaultProxyGroup
	Write-Host -ForegroundColor Green "Managed Metadata Service installed."
}


$decision = read-host "Would you like to install Secure Store Service? (Y/N)"
if ($decision -eq "Y") { 
	Write-Host -ForegroundColor Yellow "Installing Secure Store Service..."
	Start-SPService("Secure Store Service")
	$dbName = $FarmName + "_SecureStore"
	$secureStoreServiceApp = New-SPSecureStoreServiceApplication -Name "$FarmName Secure Store Service Application" -ApplicationPool $appPool -DatabaseName $dbName -AuditingEnabled:$true
	New-SPSecureStoreServiceApplicationProxy -ServiceApplication $secureStoreServiceApp -Name "$FarmName Secure Store Service Application Proxy" -DefaultProxyGroup
	Write-Host -ForegroundColor Green "Secure Store Service installed."
}

$decision = read-host "Would you like to install Visio Graphics Service? (Y/N)"
if ($decision -eq "Y") {
	Write-Host -ForegroundColor Yellow "Installing Visio Graphics Service..."
	Start-SPService("Visio Graphics Service")
	New-SPVisioServiceApplication -Name "$FarmName Visio Graphics Service" -ApplicationPool $appPool
	New-SPVisioServiceApplicationProxy -Name "$FarmName Visio Graphics Service Proxy" -ServiceApplication "$FarmName Visio Graphics Service"
	Write-Host -ForegroundColor Green "Visio Graphics Service installed."
}

$decision = read-host "Would you like to install Word Automation Services? (Y/N)"
if ($decision -eq "Y") { 
	Write-Host -ForegroundColor Yellow "Installing Word Automation Services..."
	Start-SPService("Word Automation Services")
	
	$dbName = $FarmName + "_WordAutomationServices"
	
	New-SPWordConversionServiceApplication -Name "$FarmName Word Automation Services" -ApplicationPool $appPool -DatabaseName $dbName -Default
	Write-Host -ForegroundColor Green "Word Automation Services installed."
}

$decision = read-host "Would you like to start Microsoft SharePoint Foundation Sandboxed Code Service? (Y/N)"
if ($decision -eq "Y") { 
	Write-Host -ForegroundColor Yellow "Configuring Microsoft SharePoint Foundation Sandboxed Code Service..."
	Start-SPService("Microsoft SharePoint Foundation Sandboxed Code Service")
	Write-Host -ForegroundColor Green "Microsoft SharePoint Foundation Sandboxed Code Service configured."
}
	
iisreset
sleep -s 10
Write-Host -ForegroundColor Green "Installation completed."	
