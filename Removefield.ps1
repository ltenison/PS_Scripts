# This script will DELETE a given column from a list
# Ask for the site URL
$url = read-host "Enter site URL (in form http://[your name])"
# $url = "http://splab/teamtest"
$web = Get-SPWeb -identity $url
# Ask for the name of List containing target column
$listName = read-host "List name"
$list = $web.Lists[$listName]
# Ask for the Column name to delete
$columnName = read-host "Colunm name to remove"
$column = $list.Fields[$columnName]
# $column.Hidden = $false
$column.ReadOnlyField = $false
$column.Allowdeletion = $true
$column.Sealed = $false
$column.Delete()
$list.Update()
write-host "Finished. Column", $columnName, "has been deleted from", $listName, "at site", $url
$web.dispose()