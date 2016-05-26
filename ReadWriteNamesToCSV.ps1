Just a quick not on this for everyone. Here are the two option I was able to use and thanks for all the tips everyone. 
 
To get the formatted list on screen as Joe suggested I used the following:
 
Import-csv C:\temp\file.csv | ForEach { Get-user $_.Displayname | FL Displayname,samaccountname }
 
In order to get this properly formatted to export to CSV I changed FL to Select object and piped the export CSV command as follows:

Import-csv C:\temp\file.csv | ForEach { Get-user $_.Displayname | select-object Displayname,samaccountname } | Export-csv -path c:\temp\file_new.csv
 
Thanks again everyone
