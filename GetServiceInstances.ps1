$server = $env:computername
get-spserviceinstance -Server $server | sort Status, TypeName