$site = Get-SPSite("https://apriaconnect.apria.com/sites/tc");
$site.AllWebs | foreach { $_.Lists | foreach { $_.WorkflowAssociations | foreach { 
  write-host "Site URL :" $_.ParentWeb.Url ", List Name :" $_.ParentList.Title ", Workflow Name :" $_.Name
} } }