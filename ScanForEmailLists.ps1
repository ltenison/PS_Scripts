$SPwebApp = Get-SPWebApplication "http://teamsites.na.dlmfoods.net"
$fileName = "EMail-Enabled-Teamsites.txt"
#create a CSV file 
"E-Mail,List,Site" > $fileName #Write the Headers in to a text file

foreach ($SPsite in $SPwebApp.Sites)  # get the collection of site collections
{
  foreach($SPweb in $SPsite.AllWebs)  # get the collection of sub sites
  {
    foreach ($SPList list in $SPweb.Lists)
    {
      if ( ($splist.CanReceiveEmail) -and ($SPlist.EmailAlias) )
       {
         WRITE-HOST "E-Mail -" $SPList.EmailAlias "is configured for the list "$SPlist.Title "in "$SPweb.Url
         $SPList.EmailAlias + "," + $SPlist.Title +"," + $SPweb.Url >> $fileName  #append the data
       }
    }
  }
}
