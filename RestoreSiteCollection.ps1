# script to restore a site-collection to a specific content db
$siteName = "http://archive.iaccess.insight.com/services/salessupportold"
$pathName = "Z:\SSupport.bak"
$contentDBName = "SP_ARCHIVE_CONTENT_DB03"
Write-Host "Starting restore..."
Restore-SPSIte $siteName -path $pathName -ContentDatabase $contentDBName
Write-Host "Finished Restoring to ",$siteName