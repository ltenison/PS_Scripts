Add-PSSnapin Microsoft.SharePoint.PowerShell -erroraction SilentlyContinue


#Site Parameters
$siteURL = "http://splab/"
$site = Get-SPSite($siteURL)
$siteToScan = "Portal"

#Output file
$Today = Get-Date -Format "dd-M-yy"
$outFile = "E:\temp\LibraryListLog-$siteToScan-$Today.txt"
foreach($web in $site.AllWebs) {
    $webName = $web.Title
    if($webName -eq $siteToScan) {
        write-host "Scanned Site =", $webName
        foreach($list in $web.Lists) {
            if($list.BaseType -eq "DocumentLibrary") {
            $listName = $list.Title
            write-host "Doc Lib Name =", $listName
            Write-Output $listName | Out-File $outFile -Append
            }
        }
    }
 $web.Dispose();
 }
 $site.Dispose();
 write-host "Finished."