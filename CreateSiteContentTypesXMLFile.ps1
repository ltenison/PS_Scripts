$siteName = "http://archive.iaccess.insight.com/services/salessupportold"
$sourceWeb = Get-SPWeb $siteName
$xmlFilePath = "D:\Temp\Script-SiteContentTypesOld.xml"

#Create Export File
Write-Host "Creating Export XML file at" $xmlFilePath
New-Item $xmlFilePath -type file -force

#Export Content Types to XML file
Add-Content $xmlFilePath "<?xml version=`"1.0`" encoding=`"utf-8`"?>"
Add-Content $xmlFilePath "`n<ContentTypes>"
Write-Host "Reading through Site Content Types..."
$sourceWeb.ContentTypes | ForEach-Object {
    if ($_.Group -eq "Custom Content Types") {
        Add-Content $xmlFilePath $_.SchemaXml
    }
}
Add-Content $xmlFilePath "</ContentTypes>"
Write-Host "Finished..."
$sourceWeb.Dispose()
