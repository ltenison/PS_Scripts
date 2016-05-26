Add-PSSnapin Microsoft.SharePoint.PowerShell -erroraction SilentlyContinue

#Site Parameters
$siteURL = "http://planetcalence.com/"
$site = Get-SPSite($siteURL)
$siteToScan = "Services Sales"

#Output file
$Today = Get-Date -Format "dd-M-yy"
$outFile = "D:\temp\SPListLog-$Today.txt"
$outstring = "ListName;ItemCount"
Write-Output $outstring | Out-File $outFile -Append
foreach($web in $site.AllWebs) {
    $webName = $web.Title
    if($webName -eq $siteToScan) {
        write-host "Scanned Site =", $webName
        foreach($list in $web.Lists) {
            if($list.BaseType -eq 0) {
            $listName = $list.Title
            $items = $list.Items
            $Itemcount = $Items.count
            write-host "SP List Name =", $listName, $itemcount
            $outstring = "$listName;$itemcount"
            Write-Output $outstring | Out-File $outFile -Append
            }
        }
    }
 $web.Dispose();
 }
 $site.Dispose();
 write-host "Finished."