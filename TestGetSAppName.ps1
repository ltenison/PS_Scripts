          #configure the Managed Metadata Service Application to use ContentType hub
            if($null -eq $MMSAName -or $MMSAName -eq ""){
                $mmscoll = Get-SPServiceApplication | ? { $_.TypeName -eq "Managed Metadata Service"}
                if($mmscoll -ne $null -and $mmscoll.Count -gt 1){
                    $MMSAName = $mmscoll[0].DisplayName
                }
                elseif($mmscoll -ne $null){
                    $MMSAName = $mmscoll.DisplayName
                }
                else{
                    Throw $("Managed Metadata Service Application could not be found")
                }
            }
            Write-Host "Configuring the Managed Metadata Service Application '$MMSAName'..." -NoNewline
            $mms = Get-SPServiceApplication -Name $MMSAName -ErrorAction SilentlyContinue

            if($mms -ne $null){
#                Set-SPMetadataServiceApplication -Identity $mms -hubURI $hubURI -Confirm:$false
                Write-Host "Done" -ForegroundColor Green
             }
             else{
                Write-Host "Failed" -ForegroundColor Red
                Throw $("Managed Metadata Service Application with name '"+$MMSAName+"' does not exist")
             }
        
            #configure the Managed Metadata Service Application proxy
            Write-Host "Configuring the Managed Metadata Service Application proxy '$MMSAName'..." -NoNewline
            $mmsp = Get-SPServiceApplicationProxy | ? {$_.DisplayName -eq $MMSAName}
            if($mmsp -ne $null){
#                Set-SPMetadataServiceApplicationProxy -Identity $MMSAName -ContentTypeSyndicationEnabled -ContentTypePushdownEnabled -Confirm:$false
                Write-Host "Done" -ForegroundColor Green
             }
             else{
                Write-Host "Failed" -ForegroundColor Red
                Throw $("Managed Metadata Service Application proxy with name '"+$MMSAName+"' does not exist")
             }
      