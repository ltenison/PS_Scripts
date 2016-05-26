# Description: Creates a ContentType hub site collection and configures the managed metadata service application
#
# hubURI:    URL of the ContentType hub site collection (mandatory)
# hubOwner:  Owner of the hub (default: current user) 
# MMSAName:  Name of the Managed Metadata service application (default: first found instance of MMS)
# Overwrite: Overwrites hub site collection if it already exists (default: false)
# Confrim:   Confirm when existing hub is removed (default: true)
#
# Examples: 
#
# Create-SPContentTypeHub -hubURI "http://<siteurl>" -MMSAName "Managed Metadata Service"
# Create-SPContentTypeHub -hubURI "http://<siteurl>" -hubOwner "domain\user"
function Create-SPContentTypeHub {
	[CmdletBinding()]
	param(
		[parameter(Mandatory=$true, Position=0, ValueFromPipeline=$false, ValueFromPipelineByPropertyName=$false)]
		[string]$hubURI, 
		[parameter(Mandatory=$false, Position=1, ValueFromPipeline=$false, ValueFromPipelineByPropertyName=$false)]
		[string]$hubOwner = $env:USERDOMAIN+"\"+$env:USERNAME, # default is current user
		[parameter(Mandatory=$false, Position=2, ValueFromPipeline=$false, ValueFromPipelineByPropertyName=$false)]
		[string]$MMSAName,
		[parameter(Mandatory=$false, Position=3, ValueFromPipeline=$false, ValueFromPipelineByPropertyName=$false)]
		[switch]$Overwrite = $false,  # if set to true then an existing hub will be recreated
		[parameter(Mandatory=$false, Position=4, ValueFromPipeline=$false, ValueFromPipelineByPropertyName=$false)]
		[switch]$Confirm = $true # if set to false the script will not ask when removing an existing hub
	) 
	
	begin{

    }
	
	process {
        try{
            Start-SPAssignment -Global

            # create content type hub site collection
            Write-Host "Checking if ContentType hub site already exists at '$hubURI'..." -NoNewline
            $hubExists = (Get-SPSite $hubURI -ErrorAction SilentlyContinue) -ne $null
            if($hubExists -and $Overwrite){
                Write-Host "True" -ForegroundColor Yellow
                Write-Host "Overwrite is set, existing hub will be removed"
                Remove-SPSite -Identity $hubURI -Confirm:$Confirm
                $hubExists = (Get-SPSite $hubURI -ErrorAction SilentlyContinue) -ne $null

            }
            elseif($hubExists -and -not $Overwrite){
                Write-Host "True" -ForegroundColor Green
	            Write-Host "Overwrite not set, using existing ContentType hub"
            }
	        else{
                Write-Host "False" -ForegroundColor Green
	        }	

	        if(-not $hubExists){
               # create hub site
	           Write-Host "Creating ContentType hub SiteCollection..." -NoNewline
	           $site = New-SPSite -Url $hubURI -Template 'STS#1' -OwnerAlias $hubOwner -Name "Content Type hub"
               Write-Host "Done" -ForegroundColor Green
   
	        }


            #activate the Content Type hub feature 
            Write-Host "Checking if ContentType hub feature is enabled..." -NoNewline
            $feature = Get-SPFeature -site $hubURI –Identity "ContentTypeHub" -ErrorAction SilentlyContinue
            if($feature -eq $null) {     
                Write-Host "False" -ForegroundColor Yellow

               # enable feature
	           Write-Host "Activating 'ContentTypehub' feature..." -NoNewline
               Enable-SPFeature –Identity "ContentTypeHub" –url $hubURI -Force -ErrorAction SilentlyContinue
               Write-Host "Done" -ForegroundColor Green
            } 
    	    else{
	           Write-Host "True" -ForegroundColor Green
	        }	

        
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
                Set-SPMetadataServiceApplication -Identity $mms -hubURI $hubURI -Confirm:$false
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
                Set-SPMetadataServiceApplicationProxy -Identity $MMSAProxyName -ContentTypeSyndicationEnabled -ContentTypePushdownEnabled -Confirm:$false
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