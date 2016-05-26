# Code Snippet
# Load the main SharePoint assemblies
# Add-PSSnapin Microsoft.SharePoint.PowerShell
#[System.Reflection.Assembly]::Load("Microsoft.SharePoint, Version=12.0.0.0, Culture=neutral, PublicKeyToken=71e9bce111e9429c");
#[System.Reflection.Assembly]::Load("Microsoft.SharePoint.Workflows, Version=12.0.0.0, Culture=neutral, PublicKeyToken=71e9bce111e9429c");
#
# Get an SPWeb reference using the URL of the site
$url = "http://splab/teamtest/"
#
$siteCollection = new-object Microsoft.SharePoint.SPSite $url
#
$site = $siteCollection.OpenWeb()
#
# Get a reference to the SPField for the column we want to get rid of.
$doclib = $site.Lists["LTFormTest"]
#
$doclib.Fields
#
# Dispose of the SPSite and SPWeb instances to release resources
$site.Dispose()
$siteCollection.Dispose()

