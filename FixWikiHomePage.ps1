$webName = "http://insightaccess-qa.insight.com/services/larrytest/"
$web = Get-SPWeb $webName
$listName = "Knowledgebase" 
$list = $web.Lists[$listName]
$newPagename = "Home.aspx" 
$list.RootFolder.WelcomePage = $newPagename
$list.RootFolder.Update()
write-host "Finished Update of", $webName