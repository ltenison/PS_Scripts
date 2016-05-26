# See what properties are available on a site
$site=Get-SPsite "http://splab/teamtest/"
$web=$site.OpenWeb()
## Get all the SPWeb properties
$properties=$web.Properties
## $dictionaryEntry - Defines a dictionary key/value pair that can be set or retrieved.
foreach($dictionaryEntry in $properties)
{  
write-host -f Green "Key: " $dictionaryEntry.Key "--- Value: " $dictionaryEntry.Value
}