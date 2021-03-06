Add-PSSnapin Microsoft.SharePoint.PowerShell -ErrorAction SilentlyContinue 
 
#For Output file generation
$OutputFN = "D:\Insight\Scripts\MySitesNonStdLists.csv"
#delete the file, If already exist!
if (Test-Path $OutputFN)
 { 
    Remove-Item $OutputFN
 }
#Write the CSV Headers
Add-Content $OutputFN "List Name , site Collection , Site URL , Item count"

#Load array of default MySite lists names
$ListNames = @("appdata",
"Cache Profiles",
"Composed Looks",
"Content and Structure Reports",
"Content Organizer Rules",
"Content type publishing error log",
"Converted Forms",
"Device Channels",
"Documents",
"Drop Off Library",
"Form Templates",
"Hold Reports",
"Holds",
"List Template Gallery",
"Long Running Operation Status",
"Maintenance Log Library",
"Master Page Gallery",
"MicroFeed",
"Notification List",
"Quick Deploy Items",
"Relationships List",
"Reusable Content",
"Site Collection Documents",
"Site Collection Images",
"Social",
"Solution Gallery",
"Style Library",
"Submitted E-mail Records",
"Suggested Content Browser Locations",
"TaxonomyHiddenList",
"Theme Gallery",
"Translation Packages",
"Translation Status",
"User Information List",
"Variation Labels",
"Web Part Gallery",
"wfpub",
"Workflow Tasks")
 
#Get the Web Application URL
$WebAppURL = Read-Host "Enter the Web Application URL:"
$SPwebApp = Get-SPWebApplication $WebAppURL
$i = 0

#Loop through All Site collections, Sites, Lists
      foreach($SPsite in $SPwebApp.Sites) 
      {
        $i = $i+1
	Write-host " "
	Write-host "Iteration"," ",$i
        foreach($SPweb in $SPSite.AllWebs) 
        {
          foreach($SPlist in $SPweb.Lists) 
              {
                if($ListNames -notcontains $SPlist.Title)
                   {
#                   if($splist.ItemCount -gt 10) 
#                      {
                      $content = $SPlist.Title + "," + $SPsite.Rootweb.Title +"," + $SPweb.URL + "," + $SPlist.ItemCount
                      add-content $OutputFN $content
                      write-host "Non-Std:"," ",$SPlist.Title," ",$SPsite.Rootweb.Title," ",$SPweb.URL," ",$SPlist.ItemCount
#                      }
                   }
              }
           $SPweb.Dispose()
         }
         $SPsite.Dispose()
#         if($i -gt 10) { break }
       }

write-host "Large List report generated successfully!"
