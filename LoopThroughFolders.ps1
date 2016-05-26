$url = "http://sharepoint"
$folder = "Error Logs"
 
$sites = Get-SPSite -WebApplication $url | Where-Object {$_.Url -like "$url/sites/*"}
foreach ($site in $sites)
	{
	$siteid = $site | Select-Object -ExpandProperty Url
	$webs = Get-SPWeb -Site $siteid -Limit ALL
	foreach ($web in $webs)
		{
		$library = $web.Folders["SitePages"]
		$allcontainers = $library.SubFolders | select Name
		Foreach ($container in $allcontainers)
			{
				If ($container -match $folder)
					{
					$library.SubFolders.Delete($folder)
					Write-Host "Deleted `"$folder`" from $web" -foregroundcolor Red
					}
				else {Write-Host "Finished checking $web." -foregroundcolor DarkGreen}
			}
		}
	}
Write-Host "Finished checking all sites."