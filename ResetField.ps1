# This script RESETS a given site column to allow updates
# Ask for the site URL
$url = read-host "Enter site URL (in form http://[your name])"
# $url = "http://splab/teamtest"
$web = Get-SPWeb -identity $url
# Ask for the name of List containing target column
$listName = read-host "List name"
$list = $web.Lists[$listName]
# Ask for the Column name to reset
$columnName = read-host "Colunm name to reset"
$column = $list.Fields[$columnName]
# $column.Hidden = $false
$column.ReadOnlyField = $false
$column.Allowdeletion = $true
$column.Sealed = $false
$list.Update()
write-host "Finished. Column", $columnName, "has been Reset for", $listName, "at site", $url
$web.dispose()