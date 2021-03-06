Add-PSSnapin Microsoft.SharePoint.PowerShell -ErrorAction SilentlyContinue 
 
#For Output file generation
$OutputFN = "D:\Insight\LargeListsData.csv"
#delete the file, If already exist!
if (Test-Path $OutputFN)
 { 
    Remove-Item $OutputFN
 }
#Write the CSV Headers
Add-Content $OutputFN "List Name , site Collection , Site URL , Item count"
 
#Get the Web Application URL
$WebAppURL = Read-Host "Enter the Web Application URL:"
$SPwebApp = Get-SPWebApplication $WebAppURL
 
#Loop through All Site collections, Sites, Lists
      foreach($SPsite in $SPwebApp.Sites) 
      {
        foreach($SPweb in $SPSite.AllWebs) 
        {
          foreach($SPlist in $SPweb.Lists) 
             {
                if($splist.ItemCount -gt 2000) 
                  {
                    $content = $SPlist.Title + "," + $SPsite.Rootweb.Title +"," + $SPweb.URL + "," + $SPlist.ItemCount
                    add-content $OutputFN $content
                   }
              }
           $SPweb.Dispose()
         }
         $SPsite.Dispose()
       }
write-host "Large List report generated successfully!"
