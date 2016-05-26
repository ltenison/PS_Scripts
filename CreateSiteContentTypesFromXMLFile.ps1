$siteName = "http://insightaccess-qa.insight.com/services/sales-support"
$destWeb = Get-SPWeb $siteName
$xmlFilePath = "D:\Temp\Script-SiteContentTypesOld.xml"

#Create Site Content Types
write-host "Opening XML input file..."
$ctsXML = [xml](Get-Content($xmlFilePath))
$ctsXML.ContentTypes.ContentType | ForEach-Object {

    #Create Content Type object inheriting from parent
    $spContentType = New-Object Microsoft.SharePoint.SPContentType ($_.ID,$destWeb.ContentTypes,$_.Name)
    
    #Set Content Type description and group
    $spContentType.Description = $_.Description
    $spContentType.Group = $_.Group
    write-host "Creating Site Content Types..."
    $_.Fields.Field  | ForEach-Object {
        if(!$spContentType.FieldLinks[$_.DisplayName])
        {
            #Create a field link for the Content Type by getting an existing column
            $spFieldLink = New-Object Microsoft.SharePoint.SPFieldLink ($destWeb.Fields[$_.DisplayName])
        
            #Check to see if column should be Optional, Required or Hidden
            if ($_.Required -eq "TRUE") {$spFieldLink.Required = $true}
            if ($_.Hidden -eq "TRUE") {$spFieldLink.Hidden = $true}
        
            #Add column to Content Type
            $spContentType.FieldLinks.Add($spFieldLink)
        }
    }
    
    #Create Content Type on the site and update Content Type object
    $ct = $destWeb.ContentTypes.Add($spContentType)
    $spContentType.Update()
    write-host "Content type" $ct.Name "has been created"
}
write-host "Finished with Content Types"
$destWeb.Dispose()
