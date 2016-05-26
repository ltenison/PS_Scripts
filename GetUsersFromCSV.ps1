$FilePath = "<PATH>\users.csv"
Import-CSV $FilePath | ForEach-Object {
    Get-User -UserPrincipalName $_.UserName -DisplayName $_.DisplayName | Select-Object UserPrincipalName, SamAccountName }

