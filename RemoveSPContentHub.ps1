
# Description: Removes a ContentType hub site collection and configures the managed metadata service application
#
# hubURI:    URL of the ContentType hub site collection (mandatory)
# MMSAName:  Name of the Managed Metadata service application (default: first found instance of MMS)
# Confrim:   Confirm when existing hub is removed (default: true)
#
# Examples: 
#
# Remove-SPContentTypeHub -hubURI "http://<siteurl>" -MMSAName "Managed Metadata Service"
# Remove-SPContentTypeHub -hubURI "http://<siteurl>" -Comfirm:$false
function Remove-SPContentTypeHub {
	[CmdletBinding()]
	param(
		[parameter(Mandatory=$true, Position=0, ValueFromPipeline=$false, ValueFromPipelineByPropertyName=$false)]
		[string]$hubURI, 
		[parameter(Mandatory=$false, Position=1, ValueFromPipeline=$false, ValueFromPipelineByPropertyName=$false)]
		[string]$MMSAName,
		[parameter(Mandatory=$false, Position=2, ValueFromPipeline=$false, ValueFromPipelineByPropertyName=$false)]
		[switch]$Confirm = $true # if set to false the script will not ask when removing an existing hub
	) 
	
	begin{

    }
	
	process {
        try{
            Start-SPAssignment -Global

            # create content type hub site collection
            Write-Host "Checking ContentType hub site at '$hubURI'..." -NoNewline
            $hubExists = (Get-SPSite $hubURI -ErrorAction SilentlyContinue) -ne $null
            if($hubExists){
                Write-Host "Exists" -ForegroundColor Green
                $hubFeatureActive = (Get-SPFeature -site $hubURI –Identity "ContentTypeHub" -ErrorAction SilentlyContinue) -ne $null
                if($hubFeatureActive){
                    Remove-SPSite -Identity $hubURI -Confirm:$Confirm
                }
                else{
                    Write-Host "ContentType hub feature not enabled, confirm to remove site anyway"
                    Remove-SPSite -Identity $hubURI -Confirm:$true
                }
            }
            else{
                Write-Host "False" -ForegroundColor Red
                Throw $("The site '$hubURI' does not exist")
            }

            # check again in case the user cancelled the site removal
            $hubExists = (Get-SPSite $hubURI -ErrorAction SilentlyContinue) -ne $null
            if($hubExists){
                Throw $("ContentType hub still exists, operation cancelled")
            }
     
            #configure the Managed Metadata Service Application to remove ContentType hub
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
                Set-SPMetadataServiceApplication -Identity $mms -hubURI "" -Confirm:$false
                Write-Host "Done" -ForegroundColor Green
             }
             else{
                Write-Host "Failed" -ForegroundColor Red
                Throw $("Managed Metadata Service Application with name '"+$MMSAName+"' does not exist")
             }
 
        
            #configure the Managed Metadata Service Application proxy
            $MMSAProxyName = $MMSAName+" Proxy"
            Write-Host "Configuring the Managed Metadata Service Application proxy '$MMSAProxyName'..." -NoNewline
            $mmsp = Get-SPServiceApplicationProxy | ? {$_.DisplayName -eq $MMSAProxyName}
            if($mmsp -ne $null){
                Set-SPMetadataServiceApplicationProxy -Identity $MMSAProxyName -ContentTypeSyndicationEnabled:$false -ContentTypePushdownEnabled:$false -Confirm:$false
                Write-Host "Done" -ForegroundColor Green
             }
             else{
                Write-Host "Failed" -ForegroundColor Red
                Throw $("Managed Metadata Service Application proxy with name '"+$MMSAProxyName+"' does not exist")
             }
        }
        finally{
            Stop-SPAssignment -Global
        }
    }
	
	end {}
}