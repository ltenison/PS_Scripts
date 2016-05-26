Add-PsSnapin Microsoft.SharePoint.PowerShell -ErrorAction SilentlyContinue
 
#Settings
$IndexLocation = "E:\Search"  #Location must be empty, will be deleted during the process!
$SearchAppPoolName = "SearchAppPool"
$SearchAppPoolAccountName = "ltg5lab\SP_serviceapps"
$farmName = "SPLAB2013"
$SearchServiceName = $farmName+" Search Service Application"
$SearchServiceProxyName = $farmName+" Search Service Application Proxy"

 
$DatabaseServer = "VM4\VM4SP2013"
$DatabaseName = $farmName+"_Search"
 
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
    try {
    $ServiceApplication = New-SPEnterpriseSearchServiceApplication -Name $SearchServiceName -ApplicationPool $spAppPool.Name -DatabaseServer  $DatabaseServer -DatabaseName $DatabaseName
    }
    catch {
    "Error creating Search Service Application"
    }
    finally {
    Write-Host "Continuing..."
    }
}
 
Write-Host -ForegroundColor Yellow "Checking if Search Service Application Proxy exists"
$Proxy = Get-SPEnterpriseSearchServiceApplicationProxy -Identity $SearchServiceProxyName -ErrorAction SilentlyContinue
if (!$Proxy)
{
    Write-Host -ForegroundColor Green "Creating Search Service Application Proxy"
    try {
    New-SPEnterpriseSearchServiceApplicationProxy -Name $SearchServiceProxyName -SearchApplication $SearchServiceName
    }
    catch {
    "Error creating Search Service App Proxy"
    }
    finally {
    Write-Host "Continuing..."
    }
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
sleep -s 5
Write-Host -ForegroundColor Green "Re-Creating Root Dir", $IndexLocation
mkdir -Path $IndexLocation -Force 
sleep -s 10

# The cmdlet below bombs when trying to bind to the RootDirectory parameter
# New-SPEnterpriseSearchIndexComponent -SearchTopology $SearchTopology -SearchServiceInstance $searchInstance -RootDirectory $IndexLocation 
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
Write-Host -ForegroundColor Green "Done - start a full crawl and you are good to go (search)." 
