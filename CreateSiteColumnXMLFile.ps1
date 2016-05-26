$siteName = "http://archive.iaccess.insight.com/services/salessupportold"
$sourceWeb = Get-SPWeb $siteName
$xmlFilePath = "D:\Temp\Script-SiteColumnsOld.xml"

#Create Export Files
Write-Host "Creating Export XML file at" $xmlFilePath
New-Item $xmlFilePath -type file -force

#Export Site Columns to XML file
Add-Content $xmlFilePath "<?xml version=`"1.0`" encoding=`"utf-8`"?>"
Add-Content $xmlFilePath "`n<Fields>"
Write-Host "Reading through Site Columns..."
$sourceWeb.Fields | ForEach-Object {
    if ($_.Group -eq "Custom Columns") {
        Add-Content $xmlFilePath $_.SchemaXml
    }
}
Add-Content $xmlFilePath "</Fields>"
Write-Host "Finished..."
$sourceWeb.Dispose()
