if (!(Test-Path $profile.AllUsersAllHosts)) {
     New-Item -Type file -Path $profile.AllUsersAllHosts -Force
     }