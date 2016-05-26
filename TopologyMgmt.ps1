#Search Topology Management

$queryA = Get-SPEnterpriseSearchServiceInstance -Identity "PLKFSHPO01V"
$queryB = Get-SPEnterpriseSearchServiceInstance -Identity "PLKFSHPO02V"
$index = Get-SPEnterpriseSearchServiceInstance -Identity "PLKFSHPO03V"
$indexLocation = "D:\SharePoint\Index"

Start-SPEnterpriseSearchServiceInstance -Identity $queryA
Start-SPEnterpriseSearchServiceInstance -Identity $queryB
Start-SPEnterpriseSearchServiceInstance -Identity $index

$ssa = Get-SPEnterpriseSearchServiceApplication
$active = Get-SPEnterpriseSearchTopology -Active -Search Application $ssa


$clone = New-SPEnterpriseSearchTopology -SearchApplication $ssa -Clone -SearchTopology $active

#Lists out all of the existing provisioned search components
Get-SPEnterpriseSearchComponent -SearchTopology $clone

New-SPEnterpriseSearchAdminComponent -SearchTopology $clone -SearchServiceInstance $index

New-SPEnterpriseSearchContentProcessingComponent -SearchTopology $clone -SearchServiceInstance $index

New-SPEnterpriseSearchAnalyticsProcessingComponent -SearchTopology $clone -SearchServiceInstance $index

New-SPEnterpriseSearchCrawlComponent -SearchTopology $clone -SearchServiceInstance $index

New-SPEnterpriseSearchQueryProcessingComponent -SearchTopology $clone -SearchServiceInstance $queryA

New-SPEnterpriseSearchQueryProcessingComponent -SearchTopology $clone -SearchServiceInstance $queryB

New-SPEnterpriseSearchIndexComponent -SearchTopology $clone -SearchServiceInstance $index -RootDirectory $indexLocation

Set-SPEnterpriseSearchTopology -Identity $clone

#Search Topology Management End