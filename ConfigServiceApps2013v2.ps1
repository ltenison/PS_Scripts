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
	$server = $env:COMPUTERNAME
    $ServiceInstance = (Get-SPServiceInstance -Server $server | Where {$_.TypeName -eq $ServiceInstanceTypeName})
	
    #Instead of checking here to see if the service is already running
    #We come into here already knowing we need to Start the service application
    #So, the following check is not needed

	#if($ServiceInstance.Status -ne "Online" -and $ServiceInstance.Status -ne "Provisioning") {
	#	$ServiceInstance | Start-SPServiceInstance 
	#}
	
    #And we can just start the thing right off the bat
    $ServiceInstance | Start-SPServiceInstance
     
    #With a message to say that's what we're doing
    Write-Host -ForegroundColor Green "Starting the $ServiceInstanceTypeName Service Application..."

    #And then loop for a while
	$i = 0
	while(-not ($ServiceInstance.Status -eq "Online") -and $i -lt 10) {
		Write-Host -ForegroundColor Yellow "Waiting for the $ServiceInstanceTypeName service to provision..."
		sleep -s 20
		$ServiceInstance = (Get-SPServiceInstance -Server $server | Where {$_.TypeName -eq $ServiceInstanceTypeName})
		
		$i += 1
		
		if($i -eq 10) {
			$continue = Read-Host "Service $ServiceInstanceTypeName has not yet been provisioned. Would you like to wait? (Y/N)"
			
			if($continue -eq "Y") {
				$i = 0
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
    $SearchServiceName = $FarmName+" Search Service Application"
    $SearchServiceProxyName = $FarmName+" Search Service Application Proxy"

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

#Set Default Values
$appPoolName = "ServiceAppPool"
$managedAccountName = "LTG5LAB\sp_serviceapps"
$FarmName =  "SPLAB2013"
$IndexLocation =  "E:\SharePoint"
$DatabaseServer =  "VM4\VM4SP2013"

#Collect Service App Parameters
write-host "Default values are --"
write-host "Farm Name:", $FarmName
write-host "Database Server Name:", $DatabaseServer
write-host "App Pool Name:", $appPoolName
write-host "Service App Account:", $managedAccountName
write-host "Search Index Location:", $IndexLocation

$useDef = Read-Host "Do you want to use default values for this run? (Y/N)"
if(($useDef -ne "Y") -and ($useDef -ne "y")) {
    $FarmName =  Read-Host "Please enter the name of your SP2013 Farm (e.g. SPLAB2013)"
    $DatabaseServer =  Read-Host "Please enter the name or instance of your SQL DB Server (e.g. VM4 or VM4\VM4SP2013)"
    $appPoolName = Read-Host "Please specify a name for ServiceApp application pool (eg. ServiceAppPool)"
    $managedAccountName = Read-Host "Please enter service app pool managed account (eg. CompanyABC\sp_service)"
    $IndexLocation =  Read-Host "Please enter the root file system location for Search index (e.g. E:\SharePoint)"
    }

#Load the Object References
$managedAccount = Get-SPManagedAccountByName $managedAccountName
$appPool = Get-SPServiceApplicationPoolByName $appPoolName $managedAccount
$server = $env:COMPUTERNAME

#Step Through the Service Apps to Provision

# 1 - State Service Application
    $appName = "$FarmName State Service Application"
    $app = Get-SPStateServiceApplication -Name $appname
    if($app -ne $null) {
        Write-Host -ForegroundColor Green "State Service already provisioned, skipped."
        }
	else {
        $decision = read-host "State Service not running, would you like to start it? (Y/N)"
        if ($decision -eq "Y") { 
	        New-SPStateServiceApplicationGroup $FarmName
        }
    }

# 2 - Usage and Health Data Collection Service Application
    $appName = "$FarmName Usage and Health Data Collection Service"
    $app = Get-SPUsageApplication $appname
    if($app -ne $null) {
        Write-Host -ForegroundColor Green "Usage and Health Service already provisioned, skipped."
        }
	else {
        $decision = read-host "Usage and Health Data Collection not running, would you like to start it? (Y/N)"
        if ($decision -eq "Y") { 
	        New-SPUsageApplicationAndProxy $FarmName
        }
    }

# 3 - Secure Store Service Application
    $svcTypeName = "Secure Store Service"
	$ServiceInstance = (Get-SPServiceInstance -Server $server | Where {$_.TypeName -eq $svcTypeName})
    if($ServiceInstance.Status -eq "Online" -or $ServiceInstance.Status -eq "Provisioning") {
        Write-Host -ForegroundColor Green "Secure Store Service already provisioned, skipped."
    }
    else {
        $decision = read-host "Would you like to install Secure Store Service? (Y/N)"
        if ($decision -eq "Y") { 
	        Write-Host -ForegroundColor Yellow "Installing Secure Store Service..."
	        Start-SPService($svcTypeName)
	        $dbName = $FarmName + "_SecureStore"
	        $secureStoreServiceApp = New-SPSecureStoreServiceApplication -Name "$FarmName Secure Store Service Application" -ApplicationPool $appPool -DatabaseName $dbName -AuditingEnabled:$true
	        New-SPSecureStoreServiceApplicationProxy -ServiceApplication $secureStoreServiceApp -Name "$FarmName Secure Store Service Application Proxy" -DefaultProxyGroup
	        Write-Host -ForegroundColor Green "Secure Store Service installed."
        }
    }

# 4 - Application Management Service Application
    $svcTypeName = "App Management Service"
	$ServiceInstance = (Get-SPServiceInstance -Server $server | Where {$_.TypeName -eq $svcTypeName})
    if($ServiceInstance.Status -eq "Online" -or $ServiceInstance.Status -eq "Provisioning") {
        Write-Host -ForegroundColor Green "App Management Service already provisioned, skipped."
    }
    else {
        $decision = read-host "Would you like to install App Management Service? (Y/N)"
        if ($decision -eq "Y") {
	        Write-Host -ForegroundColor Yellow "App Management Translation Service..."
	        Start-SPService($svcTypeName)
	        $dbName = $FarmName + "_AppManagement"
            $amServiceApp = New-SPAppManagementServiceApplication -ApplicationPool $appPool -Name "$FarmName App Management Service" -DatabaseName $dbName
	        New-SPAppManagementServiceApplicationProxy -Name "$FarmName App Management Service Application Proxy" -ServiceApplication $amServiceApp
	        Write-Host -ForegroundColor Green "App Management Service installed."
       }
    }

# 5 - Business Data Connectivity Service Application
    $svcTypeName = "Business Data Connectivity Service"
	$ServiceInstance = (Get-SPServiceInstance -Server $server | Where {$_.TypeName -eq $svcTypeName})
    if($ServiceInstance.Status -eq "Online" -or $ServiceInstance.Status -eq "Provisioning") {
        Write-Host -ForegroundColor Green "BDC Service already provisioned, skipped."
    }
    else {
        $decision = read-host "BDC Service is not running, would you like to start it? (Y/N)"
        if ($decision -eq "Y") { 
        	Write-Host -ForegroundColor Yellow "Installing Business Data Connectivity Service..."
    	    Start-SPService($svcTypeName)
        	$dbName = $FarmName + "_BusinessDataConnectivityService"
        	New-SPBusinessDataCatalogServiceApplication -Name "$FarmName Business Data Connectivity Service" -ApplicationPool $appPool -databaseName $dbName
    	    Write-Host -ForegroundColor Green "Business Data Connectivity Service installed."
        }
    }


# 6 - Excel Services Service Application
    $svcTypeName = "Excel Calculation Services"
	$ServiceInstance = (Get-SPServiceInstance -Server $server | Where {$_.TypeName -eq $svcTypeName})
    if($ServiceInstance.Status -eq "Online" -or $ServiceInstance.Status -eq "Provisioning") {
        Write-Host -ForegroundColor Green "Excel Calc Service already provisioned, skipped."
    }
    else {
        $decision = read-host "Would you like to install Excel Services? (Y/N)"
        if ($decision -eq "Y") { 	
	        Write-Host -ForegroundColor Yellow "Installing Excel Services..."
	        Start-SPService($svcTypeName)
	        New-SPExcelServiceApplication -Name "$FarmName Excel Services" -ApplicationPool $appPool -Default
	        Write-Host -ForegroundColor Green "Excel Services installed."
        }
    }

# 7 - Managed Metadata Service Application
    $svcTypeName = "Managed Metadata Web Service"
	$ServiceInstance = (Get-SPServiceInstance -Server $server | Where {$_.TypeName -eq $svcTypeName})
    if($ServiceInstance.Status -eq "Online" -or $ServiceInstance.Status -eq "Provisioning") {
        Write-Host -ForegroundColor Green "Managed Metadata Service already provisioned, skipped."
    }
    else {
        $decision = read-host "Would you like to install Managed Metadata Service? (Y/N)"
        if ($decision -eq "Y") { 
	        Write-Host -ForegroundColor Yellow "Installing Managed Metadata Service..."
	        Start-SPService($svcTypeName)
		    $dbName = $FarmName + "_ManagedMetadataService"
	        $MetaDataServiceApp = New-SPMetadataServiceApplication -Name "$FarmName Managed Metadata Service" -ApplicationPool $appPool -DatabaseName $dbName
	        $MetaDataServiceAppProxy = New-SPMetadataServiceApplicationProxy -Name "$FarmName Managed Metadata Service Proxy" -ServiceApplication $MetaDataServiceApp -DefaultProxyGroup
	        Write-Host -ForegroundColor Green "Managed Metadata Service installed."
        }
    }

# 8 - Visio Graphics Service Application
    $svcTypeName = "Visio Graphics Service"
	$ServiceInstance = (Get-SPServiceInstance -Server $server | Where {$_.TypeName -eq $svcTypeName})
    if($ServiceInstance.Status -eq "Online" -or $ServiceInstance.Status -eq "Provisioning") {
        Write-Host -ForegroundColor Green "Visio Graphics Service already provisioned, skipped."
    }
    else {
        $decision = read-host "Would you like to install Visio Graphics Service? (Y/N)"
        if ($decision -eq "Y") {
	        Write-Host -ForegroundColor Yellow "Installing Visio Graphics Service..."
	        Start-SPService($svcTypeName)
	        New-SPVisioServiceApplication -Name "$FarmName Visio Graphics Service" -ApplicationPool $appPool
	        New-SPVisioServiceApplicationProxy -Name "$FarmName Visio Graphics Service Proxy" -ServiceApplication "$FarmName Visio Graphics Service"
	        Write-Host -ForegroundColor Green "Visio Graphics Service installed."
        }
    }

# 9 - Word Automation Service Application
    $svcTypeName = "Word Automation Services"
	$ServiceInstance = (Get-SPServiceInstance -Server $server | Where {$_.TypeName -eq $svcTypeName})
    if($ServiceInstance.Status -eq "Online" -or $ServiceInstance.Status -eq "Provisioning") {
        Write-Host -ForegroundColor Green "Word Automation Service already provisioned, skipped."
    }
    else {
        $decision = read-host "Would you like to install Word Automation Services? (Y/N)"
        if ($decision -eq "Y") { 
	        Write-Host -ForegroundColor Yellow "Installing Word Automation Services..."
	        Start-SPService($svcTypeName)
		    $dbName = $FarmName + "_WordAutomationServices"
	    	New-SPWordConversionServiceApplication -Name "$FarmName Word Automation Services" -ApplicationPool $appPool -DatabaseName $dbName -Default
	        Write-Host -ForegroundColor Green "Word Automation Services installed."
        }
    }

# 10 - Work Management Service Application
    $svcTypeName = "Work Management Service"
	$ServiceInstance = (Get-SPServiceInstance -Server $server | Where {$_.TypeName -eq $svcTypeName})
    if($ServiceInstance.Status -eq "Online" -or $ServiceInstance.Status -eq "Provisioning") {
        Write-Host -ForegroundColor Green "Work Management Service already provisioned, skipped."
    }
    else {
        $decision = read-host "Would you like to install Work Management Service? (Y/N)"
        if ($decision -eq "Y") {
	        Write-Host -ForegroundColor Yellow "Installing Work Management Service..."
	        Start-SPService($svcTypeName)
            $wmServiceApp = New-SPWorkManagementServiceApplication -ApplicationPool $appPool -Name "$FarmName Work Management Service"
	        New-SPWorkManagementServiceApplicationProxy -Name "$FarmName Work Management Service Application Proxy" -ServiceApplication $wmServiceApp
	        Write-Host -ForegroundColor Green "Work Management Service installed."
       }
    }

# 11 - PerformancePoint Service Application
    $svcTypeName = "PerformancePoint Service"
	$ServiceInstance = (Get-SPServiceInstance -Server $server | Where {$_.TypeName -eq $svcTypeName})
    if($ServiceInstance.Status -eq "Online" -or $ServiceInstance.Status -eq "Provisioning") {
        Write-Host -ForegroundColor Green "PerformancePoint Service already provisioned, skipped."
    }
    else {
        $decision = read-host "Would you like to install PerformancePoint Service? (Y/N)"
        if ($decision -eq "Y") {
	        Write-Host -ForegroundColor Yellow "Installing PerformancePoint Service..."
	        Start-SPService($svcTypeName)
	        $dbName = $FarmName + "_PerformancePoint"
            $ppServiceApp = New-SPPerformancePointServiceApplication -Name "$FarmName PerformancePoint Service" -ApplicationPool $appPool -DatabaseName $dbName
	        New-SPPerformancePointServiceApplicationProxy -Name "$FarmName PerformancePoint Service Application Proxy" -ServiceApplication $ppServiceApp
	        Write-Host -ForegroundColor Green "PerformancePoint Service installed."
       }
    }

# 12 - PowerPoint Conversion Service Application
    $svcTypeName = "PowerPoint Conversion Service"
	$ServiceInstance = (Get-SPServiceInstance -Server $server | Where {$_.TypeName -eq $svcTypeName})
    if($ServiceInstance.Status -eq "Online" -or $ServiceInstance.Status -eq "Provisioning") {
        Write-Host -ForegroundColor Green "PowerPoint Conversion Service already provisioned, skipped."
    }
    else {
        $decision = read-host "Would you like to install PowerPoint Conversion Service? (Y/N)"
        if ($decision -eq "Y") {
	        Write-Host -ForegroundColor Yellow "Installing PowerPoint Conversion Service..."
	        Start-SPService($svcTypeName)
            $ppServiceApp = New-SPPowerPointConversionServiceApplication -Name "$FarmName PowerPoint Conversion Service" -ApplicationPool $appPool
	        New-SPPowerPointConversionServiceApplicationProxy -Name "$FarmName PowerPoint Conversion Service Application Proxy" -ServiceApplication $ppServiceApp
	        Write-Host -ForegroundColor Green "PowerPoint Conversion Service installed."
       }
    }

# 13 - Search Service Application
#      Instead of checking to see if the service is Online, let's check to see if the topology is Active.
#      If so, Search is already configured.

#    $svcTypeName = "SharePoint Server Search"
#	$ServiceInstance = (Get-SPServiceInstance -Server $server | Where {$_.TypeName -eq $svcTypeName})
#    if($ServiceInstance.Status -eq "Online" -or $ServiceInstance.Status -eq "Provisioning") {
#        Write-Host -ForegroundColor Green "Search Service already provisioned, skipped."
#    }

    $status = @()
    $status = get-spenterprisesearchserviceapplication | get-spenterprisesearchstatus
    $s = $status[0].State
    if($s -eq "Active") {
       Write-Host -ForegroundColor Green "Search Topology is active, skipped."
       }
    else {
        $decision = read-host "Would you like to install SP2013 Search Service? (Y/N)"
        if ($decision -eq "Y") { 	
	        Write-Host -ForegroundColor Yellow "Installing Search Service..."
	    	$newAccount = Read-Host "Would you like to use $managedAccountName as the search service account? (Y/N)"
	        if($newAccount -eq "N") {
		        $searchAccountName = Read-Host "Please enter Search managed account (eg. CompanyABC\sp_search)"
		        $SearchAppPoolAccountName = Get-SPManagedAccountByName $searchAccountName
	        }
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
	
        Configure-SPSearch $SearchAppPoolName $FarmName $SearchAppPoolAccountName $IndexLocation $DatabaseServer 
	
	    Write-Host -ForegroundColor Green "Search Service installed."
    }
	
iisreset
sleep -s 10
Write-Host -ForegroundColor Green "Installation completed."	
