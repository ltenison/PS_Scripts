#Take command line arguments
#$custName == Customer Name
#$custNum == Customer Account Number
Param($custName = "", $custNum = "")

#Region Global Variables
#Create global counting variables to keep track of SiteCollections and Users in Farm
$global:farmSiteCount=0
$global:userObj = @()
#EndRegion Global Variables

#Region Functions
function Bindings()
{
	return [System.Reflection.BindingFlags]::CreateInstance -bor
	[System.Reflection.BindingFlags]::GetField -bor
	[System.Reflection.BindingFlags]::Instance -bor
	[System.Reflection.BindingFlags]::NonPublic
}

function GetFieldValue([object]$o, [string]$fieldName)
{
	$bindings = Bindings
	return $o.GetType().GetField($fieldName, $bindings).GetValue($o);
}

function ConvertTo-UnsecureString([System.Security.SecureString]$string)
{
	$intptr = [System.IntPtr]::Zero
	$unmanagedString = [System.Runtime.InteropServices.Marshal]::SecureStringToGlobalAllocUnicode($string)
	$unsecureString = [System.Runtime.InteropServices.Marshal]::PtrToStringUni($unmanagedString)
	[System.Runtime.InteropServices.Marshal]::ZeroFreeGlobalAllocUnicode($unmanagedString)
	return $unsecureString
}

#Function to crawl Web Application Configuration Objects
function EnumWebApps
{
	#Take input of collection of Web Applications and the Farm ID
    param($waColl,[string]$farmID)
	
	#Region Audit WebApp Info
	#Loop through each Web Application in the Collection
    foreach ($wa in $waColl)                                                                                                 
    {
		#Is the current Web Application the Central Admin App?
		if ($wa.IsAdministrationWebApplication)
        {
            [string]$waName = "Central Administration"
            $AppPool = $oAdminService.ApplicationPools | where {$_.Displayname -match "Central Administration"}
            $apName = $AppPool.Name
            $apUser = $AppPool.UserName                       
        }
		# Handle all non-CA Web Applications
        else
        {
            [string]$waName = $wa.Name
            $apName = $wa.ApplicationPool.Name
            $apUser = $wa.ApplicationPool.UserName            
        }
        
        # Replace end-dashes ([char]8211) with normal dashes ([char]45) in the Web Application Name
        $waName = ForEach-Object{$waName -replace [char]8211, [char]45}
        
		# Select the Web Applications Node in the XML Variable
        $webAppNode=$auditxml.selectSingleNode("//Customer/Farm/WebApplications")
                
        # Create a new WebApplication Element and populate it with WebApplication Settings
        $newWebApp = $auditxml.CreateElement("WebApplication")
        $newWebApp.SetAttribute("Name",$waName)
        $newWebApp.SetAttribute("WebAppID",$wa.ID)
        $newWebApp.SetAttribute("URL",$wa.URL)
        
		# Populate Web Application sub-elements   
        $newElement = $auditxml.CreateElement("AppPoolName")
        $newElement.Set_InnerText($apName)
        $newWebApp.AppendChild($newElement)

        $newElement = $auditxml.CreateElement("AppPoolUser")
        $newElement.Set_InnerText($apUser)
        $newWebApp.AppendChild($newElement)
		
		if($spFarm.BuildVersion.Major -eq "12")
		{
			#Check to see if the Service Account data has already been logged
			$serviceAcct = $wa.ApplicationPool.UserName
			if(-not $auditxml.selectSingleNode("//Customer/Farm/FarmAccounts/Account[@UserName='$serviceAcct']"))
			{
				$newElement = $auditxml.CreateElement("Account")
			    $newElement.SetAttribute("UserName",$wa.ApplicationPool.UserName)
				$newElement.SetAttribute("Password",$wa.ApplicationPool.Password)
			    $farmAcctNode.AppendChild($newElement)
			}
		}

        $newElement = $auditxml.CreateElement("AlternateDomains")        
        $newWebApp.AppendChild($newElement)
                
        $newElement = $auditxml.CreateElement("Databases")
        $newWebApp.AppendChild($newElement)
                
        $newOBMail = $auditxml.CreateElement("OutboundMailSettings")
        $newOBMail.SetAttribute("WebAppID",$wa.ID)
        
        $newElement = $auditxml.CreateElement("OutboundMailServer")
        $newElement.Set_InnerText($wa.OutboundMailServiceInstance.Parent.Name)
        $newOBMail.AppendChild($newElement)
        
        $newElement = $auditxml.CreateElement("OutboundMailSender")
        $newElement.Set_InnerText($wa.OutboundMailSenderAddress)
        $newOBMail.AppendChild($newElement)
        
        $newElement = $auditxml.CreateElement("OutboundMailReplyTo")
        $newElement.Set_InnerText($wa.OutboundMailReplyToAddress)
        $newOBMail.AppendChild($newElement)
        
        $newElement = $auditxml.CreateElement("OutboundMailCodePage")
        $newElement.Set_InnerText($wa.OutboundMailCodePage)
        $newOBMail.AppendChild($newElement)
        
		# Append OutBound Mail Settings Node to the current Web Application Node
        $newWebApp.AppendChild($newOBMail)
        
		#Region Audit Web Application Policies
		$newPols = $auditxml.CreateElement("Policies")		
		foreach($policy in $wa.policies)
		{
			$newPol = $auditxml.CreateElement("Policy")
			
			$newElement = $auditxml.CreateElement("DisplayName")
	        $newElement.Set_InnerText($policy.DisplayName)
	        $newPol.AppendChild($newElement)
			
			$newElement = $auditxml.CreateElement("UserName")
	        $newElement.Set_InnerText($policy.UserName)
	        $newPol.AppendChild($newElement)
	        
	        $newElement = $auditxml.CreateElement("IsSystemUser")
	        $newElement.Set_InnerText($policy.IsSystemUser)
	        $newPol.AppendChild($newElement)
	        
			$newPRB = $auditxml.CreateElement("PolicyRoleBindings")
			
			foreach($binding in $policy.PolicyRoleBindings)
			{
		        $newElement = $auditxml.CreateElement("Binding")
		        $newElement.Set_InnerText($binding.Name)
		        $newPRB.AppendChild($newElement)	        
			}
			$newPol.AppendChild($newPRB)	
			
			$newPols.AppendChild($newPol)
		}
		
		$newWebApp.AppendChild($newPols)		
		#EndRegion Audit Web Application Policies
		
		#Region Audit People Picker Settings
		# Create new PeoplePicker configuration Node
        $newPP = $auditxml.CreateElement("PeoplePickerSettings")    
        
		# Get an object of People Picker Configuration
        $ppSettings = $wa.PeoplePickerSettings        
        
		# Populate PeoplePicker sub-elements 
        $newElement = $auditxml.CreateElement("ActiveDirectoryCustomQuery")
        $newElement.Set_InnerText($ppSettings.ActiveDirectoryCustomQuery)
        $newPP.AppendChild($newElement)
        
        $newElement = $auditxml.CreateElement("ActiveDirectoryCustomFilter")
        $newElement.Set_InnerText($ppSettings.ActiveDirectoryCustomFilter)
        $newPP.AppendChild($newElement)
        
        $newElement = $auditxml.CreateElement("OnlySearchWithinSiteCollection")
        $newElement.Set_InnerText($ppSettings.OnlySearchWithinSiteCollection)
        $newPP.AppendChild($newElement)
        
        $newElement = $auditxml.CreateElement("PeopleEditorOnlyResolveWithinSiteCollection")
        $newElement.Set_InnerText($ppSettings.PeopleEditorOnlyResolveWithinSiteCollection)
        $newPP.AppendChild($newElement)
        
        $newElement = $auditxml.CreateElement("ActiveDirectorySearchTimeout")
        $newElement.Set_InnerText($ppSettings.ActiveDirectorySearchTimeout.TotalSeconds)
        $newPP.AppendChild($newElement)
        
        $newElement = $auditxml.CreateElement("NoWindowsAccountsForNonWindowsAuthenticationMode")
        $newElement.Set_InnerText($ppSettings.NoWindowsAccountsForNonWindowsAuthenticationMode)
        $newPP.AppendChild($newElement)
        
        $newElement = $auditxml.CreateElement("ReferralChasingOption")
        $newElement.Set_InnerText($ppSettings.ReferralChasingOption)
        $newPP.AppendChild($newElement)
        
        $newElement = $auditxml.CreateElement("ServiceAccountDirectoryPaths")
        $newElement.Set_InnerText($ppSettings.ServiceAccountDirectoryPaths)
        $newPP.AppendChild($newElement)
        
        $newElement = $auditxml.CreateElement("DistributionListSearchDomains")
        $newElement.Set_InnerText($ppSettings.DistributionListSearchDomains)
        $newPP.AppendChild($newElement)
        
		# Loop through the collection of custom People Picker Domains
        if ($domains = $ppSettings.SearchActiveDirectoryDomains)
        {                        
            $newPPAD = $auditxml.CreateElement("PPickerADForests")

            foreach($item in $domains)
            {   
				#Populate the current PeoplePicker Domain and sub-elements
                $newDomain = $auditxml.CreateElement("Domain")
                                
                $newElement = $auditxml.CreateElement("DomainName")
                $newElement.Set_InnerText($item.DomainName)
                $newDomain.AppendChild($newElement)
                
                $newElement = $auditxml.CreateElement("IsForest")
                $newElement.Set_InnerText($item.IsForest)
                $newDomain.AppendChild($newElement)
                
                $newElement = $auditxml.CreateElement("LoginName")
                $newElement.Set_InnerText($item.LoginName)
                $newDomain.AppendChild($newElement)
                
                $loginName = $item.LoginName                
                               
                $newElement = $auditxml.CreateElement("CustomString")
                $newElement.Set_InnerText($item.CustomString)
                $newDomain.AppendChild($newElement)
                
				#Append the current Domain to the PeoplePicker AD Node
                $newPPAD.AppendChild($newDomain)
                
            }  
			#Append the PeoplePicker AD Node to the PeoplePicker Configuration Node
            $newPP.AppendChild($newPPAD)
        }
		#Append the new PeoplePicker Node to the current Web Application Node
        $newWebApp.AppendChild($newPP)
		#EndRegion Audit People Picker Settings                             
                            
        # Append the new WebApplication Node to the XML variable
        $auditxml.Customer.Farm["WebApplications"].AppendChild($newWebApp)
		
		#Region Audit ContentDBs for the current Web Application
		#Select the current Web Application Node in the Audit XML variable
		$currWebAppNode=$auditxml.selectSingleNode("//Customer/Farm/WebApplications/WebApplication[@Name='$waName']")
		
		#Get the collection of Databases for the current Web Application
        $ContentDBs = $wa.ContentDatabases
		
		#Create the Site Collection count variable for the current Web Application
		$siteCount = 0
		
		#Get Database Config for SP2007
		if($spFarm.BuildVersion.Major -eq "12")
		{
	        #Thanks to local San Antonio Dev Travis Lingenfelder for the workaround for using non-CLS compliant types in Powershell
	        $DBName = [Microsoft.SharePoint.Administration.SPContentDatabase].GetProperty("Name")
	    	$DBID = [Microsoft.SharePoint.Administration.SPContentDatabase].GetProperty("ID") 
	        $DBServer = [Microsoft.SharePoint.Administration.SPContentDatabase].GetProperty("ServiceInstance")
	        $DBStatus =  [Microsoft.SharePoint.Administration.SPContentDatabase].GetProperty("Status")
	    	$DBCurrSiteCount = [Microsoft.SharePoint.Administration.SPContentDatabase].GetProperty("CurrentSiteCount")
	        $DBDiskSizeRequired = [Microsoft.SharePoint.Administration.SPContentDatabase].GetProperty("DiskSizeRequired")
	    	$DBWarningSiteCount = [Microsoft.SharePoint.Administration.SPContentDatabase].GetProperty("WarningSiteCount")
	    	$DBMaximumSiteCount = [Microsoft.SharePoint.Administration.SPContentDatabase].GetProperty("MaximumSiteCount")
	        $DBPreferredTimerServiceInstance = [Microsoft.SharePoint.Administration.SPContentDatabase].GetProperty("PreferredTimerServiceInstance")
	    	$DBIsReadOnly = [Microsoft.SharePoint.Administration.SPContentDatabase].GetProperty("IsReadOnly")
	    	        
	        # Loop through each of the Content Databases in the XML Variable
		    ForEach ($ContentDB in $ContentDBs)
		    {	
				#Get the count of Site Collections for the current Web Application
				$siteCount += $DBCurrSiteCount.GetValue($ContentDB, $null)
				
				#Create new Database Node in the current Web Application Node
		    	$newDB = $auditxml.CreateElement("Database")                       
		        $newDB.SetAttribute("Name",$DBName.GetValue($ContentDB, $null))
				$newDB.SetAttribute("Database_ID",$DBID.GetValue($ContentDB, $null))
				$newDB.SetAttribute("Server",$DBServer.GetValue($ContentDB, $null))
				$newDB.SetAttribute("Status",$DBStatus.GetValue($ContentDB, $null))
				
				$newElement = $auditxml.CreateElement("CurrentSiteCount")
		        $newElement.Set_InnerText($DBCurrSiteCount.GetValue($ContentDB, $null))
		        $newDB.AppendChild($newElement)
							
				$newElement = $auditxml.CreateElement("DiskSizeRequiredInGB")
		        $newElement.Set_InnerText($DBDiskSizeRequired.GetValue($ContentDB, $null)/1024/1024/1024)
		        $newDB.AppendChild($newElement)
				
				$newElement = $auditxml.CreateElement("WarningSiteCount")
		        $newElement.Set_InnerText($DBWarningSiteCount.GetValue($ContentDB, $null))
		        $newDB.AppendChild($newElement)
				
				$newElement = $auditxml.CreateElement("MaximumSiteCount")
		        $newElement.Set_InnerText($DBMaximumSiteCount.GetValue($ContentDB, $null))
		        $newDB.AppendChild($newElement)
			
		        $newElement = $auditxml.CreateElement("IsReadOnly")
		        $newElement.Set_InnerText($DBIsReadOnly.GetValue($ContentDB, $null))
		        $newDB.AppendChild($newElement)
				
				$newElement = $auditxml.CreateElement("Sites")
	        	$newDB.AppendChild($newElement)	
				
				#Append the new Database Node to the current Web Application Node
		        $currWebAppNode["Databases"].AppendChild($newDB) 
				                       
				#Get a collection of Site Collections in the current Content DB			
	            $DBSites = [Microsoft.SharePoint.Administration.SPContentDatabase].GetProperty("Sites")
	                                    
				#Loop through each Site Collection in the Database
				foreach($DBSite in $DBSites)
				{
	                $siteProps = $DBSite.GetValue($ContentDB, $null) 
	                
	                $siteNameObj = "$siteProps".split("=")
	                $siteUrl = $siteNameObj[1]
	                
	                $site = New-Object Microsoft.SharePoint.SPSite($siteUrl)
	                
					#Create a new Site Element for the current Site Collection
					$newSite = $auditxml.CreateElement("Site")                       
			        $newSite.SetAttribute("ServerRelativeURL",$site.ServerRelativeURL)
					$newSite.SetAttribute("SiteSubscription",$site.SiteSubscription)
					$newSite.SetAttribute("SizeInGB",$site.Usage.Storage/1024/1024/1024)				
					
					#Get the UserInfoList for the root Web of the Site Collection
					$userinfolist = $site.rootweb.SiteUserInfoList
					$users = $userinfolist.items
					
					#Loop through each user in the list
					foreach ($user in $users)
					{				
						#Insert any unique "Person" object in the list into the global userObj array
						if($user.ContentType.Name -eq "Person" -and $user.Name -ne "System Account" -and $user.Name -ne "NT AUTHORITY\LOCAL SERVICE")
						{
							if($global:userObj -contains $user.Name){}					
							else{$global:userObj += $user.Name}
						}
					}
					#Append the current Site Collection to the current Database Node
					$newDB["Sites"].AppendChild($newSite)
				}
			}
	    }
		#Get Database config for SP2010
		elseif($spFarm.BuildVersion.Major -eq "14")
		{
			# Loop through each of the Content Databases in the XML Variable
		    ForEach ($ContentDB in $ContentDBs)
		    {	
				#Get the count of Site Collections for the current Web Application
				$siteCount += $ContentDB.CurrentSiteCount
				
				#Create new Database Node in the current Web Application Node
		    	$newDB = $auditxml.CreateElement("Database")                       
		        $newDB.SetAttribute("Name",$ContentDB.Name)
				$newDB.SetAttribute("Database_ID",$ContentDB.ID)
				$newDB.SetAttribute("Server",$ContentDB.Server)
				$newDB.SetAttribute("Status",$ContentDB.Status)
				
				$newElement = $auditxml.CreateElement("CurrentSiteCount")
		        $newElement.Set_InnerText($ContentDB.CurrentSiteCount)
		        $newDB.AppendChild($newElement)
							
				$newElement = $auditxml.CreateElement("DiskSizeRequiredInGB")
		        $newElement.Set_InnerText($ContentDB.DiskSizeRequired/1024/1024/1024)
		        $newDB.AppendChild($newElement)
				
				$newElement = $auditxml.CreateElement("WarningSiteCount")
		        $newElement.Set_InnerText($ContentDB.WarningSiteCount)
		        $newDB.AppendChild($newElement)
				
				$newElement = $auditxml.CreateElement("MaximumSiteCount")
		        $newElement.Set_InnerText($ContentDB.MaximumSiteCount)
		        $newDB.AppendChild($newElement)
				
				$newElement = $auditxml.CreateElement("PreferredTimerServiceInstance")
		        $newElement.Set_InnerText($ContentDB.PreferredTimerServiceInstance)
		        $newDB.AppendChild($newElement)
				
		        $newElement = $auditxml.CreateElement("IsReadOnly")
		        $newElement.Set_InnerText($ContentDB.IsReadOnly)
		        $newDB.AppendChild($newElement)
				
				$newElement = $auditxml.CreateElement("Sites")
	        	$newDB.AppendChild($newElement)	
				
				#Append the new Database Node to the current Web Application Node
		        $currWebAppNode["Databases"].AppendChild($newDB) 
				
				#Get a collection of Site Collections in the current Content DB
				$sites = $ContentDB.Sites
				
				#Loop through each Site Collection in the Database
				foreach($site in $sites)
				{
					#Create a new Site Element for the current Site Collection
					$newSite = $auditxml.CreateElement("Site")                       
			        $newSite.SetAttribute("ServerRelativeURL",$site.ServerRelativeURL)
					$newSite.SetAttribute("SiteSubscription",$site.SiteSubscription)
					$newSite.SetAttribute("SizeInGB",$site.Usage.Storage/1024/1024/1024)
					
					#Get the root Web for the current Site Collection
					$siteCollWeb = New-Object Microsoft.SharePoint.SPSite($site.URL)
					
					#Get the UserInfoList for the root Web of the Site Collection
					$userinfolist = $siteCollWeb.rootweb.SiteUserInfoList
					$users = $userinfolist.items
					
					#Loop through each user in the list
					foreach ($user in $users)
					{				
						#Insert any unique "Person" object in the list into the global userObj array
						if($user.ContentType.Name -eq "Person" -and $user.Name -ne "System Account" -and $user.Name -ne "NT AUTHORITY\LOCAL SERVICE")
						{
							if($global:userObj -contains $user.Name){}					
							else{$global:userObj += $user.Name}
						}
					}
					#Append the current Site Collection to the current Database Node
					$newDB["Sites"].AppendChild($newSite)
				}	        
		    }
		}
	
		#Log the number of Site Collections in the current Web App Node
		$currWebAppNode.SetAttribute("WebAppSiteCount",$siteCount)
		
		#Add the current Web App Site Collection account to the Farm Site Collection count
		$global:farmSiteCount += $siteCount

		#EndRegion Audit ContentDBs for the current Web Application
		#Region Audit AAMs
        # Get the Alternate URL Collection for the Web App
        foreach($node in $altdomainsxml.GetElementsByTagName("Collection"))
        {           
           # Get the name of each Collection (Web App) 
           if ($waName -eq $node.Name)
           {                       
               # Loop through each item in the Node
               foreach($item in $node)
               {	      
                  # Loop through each of the Arguments in the Item (IncomingUrl, UrlZone, MappedUrl)
        	      foreach($argItem in $item.AlternateDomain)
        	      {	 
				  	#Create a new AAM Node
                    $newAAM = $auditxml.CreateElement("AlternateDomain")                    
                    
                    $newElement = $auditxml.CreateElement("IncomingUrl")
                    $newElement.Set_InnerText($argItem.IncomingUrl)
                    $newAAM.AppendChild($newElement)
                    
                    $newElement = $auditxml.CreateElement("UrlZone")
                    $newElement.Set_InnerText($argItem.UrlZone)
                    $newAAM.AppendChild($newElement)
                    
                    $newElement = $auditxml.CreateElement("MappedUrl")
                    $newElement.Set_InnerText($argItem.MappedUrl)
                    $newAAM.AppendChild($newElement)
                    
					#Detect if the current AAM is an Extended IIS Site
                    if ($argItem.IncomingUrl -eq $argItem.MappedUrl)
                    {
                        #Create a new Node for the current AAM's IIS Settings                                    
                        $newIIS = $auditxml.CreateElement("IISSettings")
                        
						#Get a collection of AAM Zones in the current Web Application
                        foreach ($zone in $wa.IisSettings.Keys)
                        {
                            #Detect if the current zone in the collection matches the UrlZone of the current Extended Site
							if ($zone -eq $argItem.UrlZone)
                            {
                                $iisSettings = $wa.IisSettings[$zone]
								
                                $newElement = $auditxml.CreateElement("AuthenticationMode")
                                $newElement.Set_InnerText($iisSettings.AuthenticationMode)
                                $newIIS.AppendChild($newElement)
                                    
                                $newElement = $auditxml.CreateElement("AllowAnonymous")
                                $newElement.Set_InnerText($iisSettings.AllowAnonymous)
                                $newIIS.AppendChild($newElement)
                                 
                                $newElement = $auditxml.CreateElement("EnableClientIntegration")
                                $newElement.Set_InnerText($iisSettings.EnableClientIntegration)
                                $newIIS.AppendChild($newElement)
                                 
                                $newElement = $auditxml.CreateElement("UseBasicAuthentication")
                                $newElement.Set_InnerText($iisSettings.UseBasicAuthentication)
                                $newIIS.AppendChild($newElement)
                                    
                                $newElement = $auditxml.CreateElement("DisableKerberos")
                                $newElement.Set_InnerText($iisSettings.DisableKerberos)
                                $newIIS.AppendChild($newElement)
                                  
                                $newElement = $auditxml.CreateElement("Path")
                                $newElement.Set_InnerText($iisSettings.Path)
                                $newIIS.AppendChild($newElement)
                                   
                                $newElement = $auditxml.CreateElement("InstanceID")
                                $newElement.Set_InnerText($iisSettings.PreferredInstanceId)
                                $newIIS.AppendChild($newElement)
                                
								#Get a collection of IIS Bindings for the current Extended Site
                                if ($iisSettings.ServerBindings)
                                {
                                    #Loop through each of the bindings in the collection
									foreach ($binding in $iisSettings.ServerBindings)
                                    {
                                        $newBinding = $auditxml.CreateElement("ServerBindings")                                             
                                        
                                        $newElement = $auditxml.CreateElement("HostHeader")
                                        $newElement.Set_InnerText($binding.HostHeader)
                                        $newBinding.AppendChild($newElement)
                                        
                                        $newElement = $auditxml.CreateElement("Port")
                                        $newElement.Set_InnerText($binding.Port)
                                        $newBinding.AppendChild($newElement)
                                        
										#Append the current binding to the current IIS Settings Node
                                        $newIIS.AppendChild($newBinding)
                                    }
                                }
                                #Get a collection of Secure IIS Bindings for the current Extended Site                                								
								elseif ($iisSettings.SecureBindings)
                                {
                                    foreach ($binding in $iisSettings.SecureBindings)
                                    {
                                        $newBinding = $auditxml.CreateElement("SecureBindings")                                             
                                        
                                        $newElement = $auditxml.CreateElement("Port")
                                        $newElement.Set_InnerText($binding.Port)
                                        $newBinding.AppendChild($newElement)
                                        
										#Append the current binding to the current IIS Settings Node
                                        $newIIS.AppendChild($newBinding)
                                    }
                                }
								
								#Create a new Node for Authentication Providers
								$newAuth = $auditxml.CreateElement("Authentication")
								
								#If the Farm is 2007 only collect the Membership and Role Providers
								if($spFarm.BuildVersion.Major -eq "12")
								{
									$newElement = $auditxml.CreateElement("MembershipProvider")
	                                $newElement.Set_InnerText($iisSettings.MembershipProvider)
	                                $newAuth.AppendChild($newElement)
	                                    
	                                $newElement = $auditxml.CreateElement("RoleManager")
	                                $newElement.Set_InnerText($iisSettings.RoleManager)
	                                $newAuth.AppendChild($newElement)
								}
								#If the Farm is 2010 collect all Claims Info
								elseif($spFarm.BuildVersion.Major -eq "14")
								{
									if($iisSettings.UseClaimsAuthentication)
									{
										$newElement = $auditxml.CreateElement("UseClaimsAuthentication")
		                                $newElement.Set_InnerText($iisSettings.UseClaimsAuthentication)
		                                $newAuth.AppendChild($newElement)
		                                    
		                                $newElement = $auditxml.CreateElement("UseTrustedClaimsAuthenticationProvider")
		                                $newElement.Set_InnerText($iisSettings.UseTrustedClaimsAuthenticationProvider)
		                                $newAuth.AppendChild($newElement)
										
										$newElement = $auditxml.CreateElement("WindowsClaimsAuthenticationProvider")
		                                $newElement.Set_InnerText($iisSettings.WindowsClaimsAuthenticationProvider)
		                                $newAuth.AppendChild($newElement)
										
										$newElement = $auditxml.CreateElement("FormsClaimsAuthenticationProvider")
		                                $newElement.Set_InnerText($iisSettings.FormsClaimsAuthenticationProvider)
		                                $newAuth.AppendChild($newElement)
										
										$newElement = $auditxml.CreateElement("ClaimsAuthenticationRedirectionUrl")
		                                $newElement.Set_InnerText($iisSettings.ClaimsAuthenticationRedirectionUrl)
		                                $newAuth.AppendChild($newElement)
		                                
										#Get a collection of Claims Auth Providers for the current Extended Site
		                                foreach($CAP in $iisSettings.ClaimsAuthenticationProviders)
										{
											#Gather Windows Auth Provider config
											if($CAP.DisplayName -eq "Windows Authentication")
											{
												$newWinProv = $auditxml.CreateElement("WindowsProvider")
												
												$newElement = $auditxml.CreateElement("DisplayName")
				                                $newElement.Set_InnerText($CAP.DisplayName)
				                                $newWinProv.AppendChild($newElement)
				                                    
				                                $newElement = $auditxml.CreateElement("ClaimProviderName")
				                                $newElement.Set_InnerText($CAP.ClaimProviderName)
				                                $newWinProv.AppendChild($newElement)
												
												$newElement = $auditxml.CreateElement("AllowAnonymous")
				                                $newElement.Set_InnerText($CAP.AllowAnonymous)
				                                $newWinProv.AppendChild($newElement)
												
												$newElement = $auditxml.CreateElement("UseBasicAuthentication")
				                                $newElement.Set_InnerText($CAP.UseBasicAuthentication)
				                                $newWinProv.AppendChild($newElement)
												
												$newElement = $auditxml.CreateElement("DisableKerberos")
				                                $newElement.Set_InnerText($CAP.AllowAnonymous)
				                                $newWinProv.AppendChild($newElement)
												
												$newElement = $auditxml.CreateElement("UseWindowsIntegratedAuthentication")
				                                $newElement.Set_InnerText($CAP.UseWindowsIntegratedAuthentication)
				                                $newWinProv.AppendChild($newElement)
												
												$newElement = $auditxml.CreateElement("AuthenticationRedirectionUrl")
				                                $newElement.Set_InnerText($CAP.AuthenticationRedirectionUrl)
				                                $newWinProv.AppendChild($newElement)
												
												#Append the current Auth Provider to the current Extended Site Node
												$newAuth.AppendChild($newWinProv)
											}
											#Gather Forms Auth Provider config
											elseif($CAP.DisplayName -eq "Forms Authentication")
											{
												$newFormProv = $auditxml.CreateElement("FormsProvider")
												
												$newElement = $auditxml.CreateElement("DisplayName")
				                                $newElement.Set_InnerText($CAP.DisplayName)
				                                $newFormProv.AppendChild($newElement)
				                                    
				                                $newElement = $auditxml.CreateElement("MembershipProvider")
				                                $newElement.Set_InnerText($CAP.MembershipProvider)
				                                $newFormProv.AppendChild($newElement)
												
												$newElement = $auditxml.CreateElement("RoleProvider")
				                                $newElement.Set_InnerText($CAP.RoleProvider)
				                                $newFormProv.AppendChild($newElement)
																													
												$newElement = $auditxml.CreateElement("ClaimProviderName")
				                                $newElement.Set_InnerText($CAP.ClaimProviderName)
				                                $newFormProv.AppendChild($newElement)
												
												$newElement = $auditxml.CreateElement("AuthenticationRedirectionUrl")
				                                $newElement.Set_InnerText($CAP.AuthenticationRedirectionUrl)
				                                $newFormProv.AppendChild($newElement)								
												
												$newAuth.AppendChild($newFormProv)
											}
										}
										#Append the collection of Auth Provider Nodes to the current IIS Settings Node
										$newIIS.AppendChild($newAuth)
									}								
								}                                
                            }              
                        } 
                        #Append the IIS Settings Node to the current AAM Node
                        $newAAM.AppendChild($newIIS)                        
                    }  
                    #Append the AlternateDomains Node to the Current Web App Node in the XML variable
                    $currWebAppNode["AlternateDomains"].AppendChild($newAAM)
        	      }
                }
            }
        }
		#EndRegion Audit AAMs-----------------------------------------------
    }
	#EndRegion Audit WebApp Info
}
#EndRegion Functions

#Region Get Domain Data
#Get the current Active Directory Domain
$forestName = [System.DirectoryServices.ActiveDirectory.Domain]::getcomputerdomain()

#Extract the NetBios name of the domain from Net Config
if ($forestName)
{
	$nb = net config workstation | findstr /C:"Workstation domain"
	$domainName = $nb -replace "Workstation domain                   ",""
}
#If no domain exists, use the computer name. Should only happen with 2007 Farms
else
{
	$domainName = gc env:computername
}

#EndRegion Get Domain Data

#Region Build XML Template
# Build Base XML Template variable to be used throughout the rest of the script
[xml]$auditxml = '<?xml version="1.0" encoding="UTF-8"?>
    <Customer>
		<Farm> 
		<FarmAccounts>
		</FarmAccounts>
    	</Farm>		
	</Customer>
    '
#EndRegion Build XML Template

#Region Set Customer Data
#Set the Customer Name and Number taken from Script Arguments
if($custName -eq "" -or $custNum -eq ""){Write-Host "No Customer Data was entered"}
else
{
	$auditxml.Customer.SetAttribute("Name",$custName)
	$auditxml.Customer.SetAttribute("Number",$custNum)
}
#EndRegion Set Customer Data

#Region Get Farm Objects and Load Assemblies
#Load SharePoint .NET Assemblies
if([System.reflection.Assembly]::LoadWithPartialName("Microsoft.SharePoint")){}

#Get the Farm Accounts Node for storing Service Account Data
$farmAcctNode=$auditxml.selectSingleNode("//Customer/Farm/FarmAccounts")
	
# Get the Current Directory that the script is operating from
[string]$curloc = get-location

# Create an Instance of the Local Farm Object
$spFarm = [Microsoft.SharePoint.Administration.SPfarm]::Local

if($spFarm.BuildVersion.Major -eq "14")
{
	Add-PSSnapin Microsoft.SharePoint.PowerShell -EA 0
}

# Get All Alternate Access Mappings into an XML variable
[xml]$altdomainsxml = (stsadm -o enumalternatedomains)

# Create the Admin Service Object which will hold data about the Central Admin Web App
$oAdminService = [Microsoft.SharePoint.Administration.SPWebService]::AdministrationService

# Create the Content Service Object which will hold data about all of the Web Apps in the Farm
$oContentService = [Microsoft.Sharepoint.Administration.SPWebService]::ContentService

# Generate a list of Servers in the Farm
$farmServers = $spFarm.Servers
#EndRegion Get Farm Objects and Load Assemblies

#Region Document Farm ID and Build Version

# Get Farm Build Version & FarmID and Update the Farm Node in the XML variable
$farmNode=$auditxml.selectSingleNode("//Customer/Farm")
$farmNode.SetAttribute('BuildVersion',$spFarm.BuildVersion)
$farmNode.SetAttribute('FarmID',$spFarm.Id)
$farmNode.SetAttribute('ForestName',$forestName)
$farmNode.SetAttribute('TimerServiceAcct',$spFarm.TimerService.ProcessIdentity.Username)


if($spFarm.BuildVersion.Major -eq "12")
{
	#Check to see if the Service Account data has already been logged
	$serviceAcct = $spFarm.TimerService.ProcessIdentity.Username
	if(-not $auditxml.selectSingleNode("//Customer/Farm/FarmAccounts/Account[@UserName='$serviceAcct']"))
	{	
		$newElement = $auditxml.CreateElement("Account")
	    $newElement.SetAttribute("UserName",$spFarm.TimerService.ProcessIdentity.Username)
		$newElement.SetAttribute("Password",$spFarm.TimerService.ProcessIdentity.Password)
	    $farmAcctNode.AppendChild($newElement)
	}
}

# Determine License Level
if($spFarm.BuildVersion.Major -eq "12")
{
	$farmFeatures = $spFarm.FeatureDefinitions
	$Enterprise = $farmFeatures | ? {$_.DisplayName -eq "ExcelServer"}
	$Standard = $farmFeatures | ? {$_.DisplayName -eq "MySite"}
	$SearchServer = $farmFeatures | ? {$_.DisplayName -eq "OSearchBasicFeature"}
	$Foundation = $farmFeatures | ? {$_.DisplayName -eq "SPSearchFeature"}

	if($Enterprise -ne $null){$farmNode.SetAttribute('LicenseLevel',"SharePoint Server 2007 Enterprise")}
	elseif($Standard -ne $null){$farmNode.SetAttribute('LicenseLevel',"SharePoint Server 2007 Standard")}
	elseif($SearchServer -ne $null){$farmNode.SetAttribute('LicenseLevel',"SharePoint Search Server Express 2008")}
	elseif($Foundation -ne $null){$farmNode.SetAttribute('LicenseLevel',"Windows SharePoint Services 3.0")}
}
elseif($spFarm.BuildVersion.Major -eq "14")
{
	$products = @{"BEED1F75-C398-4447-AEF1-E66E1F0DF91E" = "SharePoint Foundation 2010"; "1328E89E-7EC8-4F7E-809E-7E945796E511" = "Search Server Express 2010"; "3FDFBCC8-B3E4-4482-91FA-122C6432805C" = "SharePoint Server 2010 Standard"; "D5595F62-449B-4061-B0B2-0CBAD410BB51" = "SharePoint Server 2010 Enterprise"; "ED21638F-97FF-4A65-AD9B-6889B93065E2" = "Project Server 2010"; "926E4E17-087B-47D1-8BD7-91A394BC6196" = "Office Web Companions 2010"}

	if($spFarm.Products -contains "D5595F62-449B-4061-B0B2-0CBAD410BB51"){$farmNode.SetAttribute('LicenseLevel', "SharePoint Server 2010 Enterprise")}
	elseif($spFarm.Products -contains "3FDFBCC8-B3E4-4482-91FA-122C6432805C"){$farmNode.SetAttribute('LicenseLevel',"SharePoint Server 2010 Standard")}
	elseif($spFarm.Products -contains "1328E89E-7EC8-4F7E-809E-7E945796E511"){$farmNode.SetAttribute('LicenseLevel',"Search Server Express 2010")}
	elseif($spFarm.Products -contains "BEED1F75-C398-4447-AEF1-E66E1F0DF91E"){$farmNode.SetAttribute('LicenseLevel',"SharePoint Foundation 2010")}
}
#EndRegion Document Farm ID and Build Version

#Region Document the WebApps and their associated Content Databases & AAMs
#Create the WebApplications Node
$newNode = $auditxml.CreateElement("WebApplications")

#Append the WebApplications Node to the current Farm
$auditxml.Customer["Farm"].AppendChild($newNode)

# Document the Central Admin Web App Properties
EnumWebApps $oAdminService.WebApplications $spFarm.ID

# Document all of the other Web App Properties
EnumWebApps $oContentService.webApplications $spFarm.ID

#Log the Farm Site Collection and User Counts
$farmNode.SetAttribute("FarmSiteCount", $global:farmSiteCount)
$farmNode.SetAttribute("FarmUserCount", $global:userObj.Count)

 #EndRegion Document the WebApps and their associated Content Databases & AAMs
 
#Region Document Farm Services and Settings
#Create the FarmServices Node
$newNode = $auditxml.CreateElement("FarmServices")

#Append the FarmServices Node to the current Farm Node
$auditxml.Customer["Farm"].AppendChild($newNode)

# Get a collection of Services in the Farm
$services = $spFarm.Services

#Loop through each service in the services collection
foreach ($service in $services)
{
    #Document Incoming E-mail settings
	if ($service.TypeName -eq "Windows SharePoint Services Incoming E-Mail" -or $service.TypeName -eq "Microsoft SharePoint Foundation Incoming E-Mail")
    {
        $newService = $auditxml.CreateElement("Service")
        $newService.SetAttribute("Name",$service.TypeName)
           
        $newElement = $auditxml.CreateElement("Enabled")
        $newElement.Set_InnerText($service.Enabled)
        $newService.AppendChild($newElement)
        
        $newElement = $auditxml.CreateElement("UseAutomaticSettings")
        $newElement.Set_InnerText($service.UseAutomaticSettings)
        $newService.AppendChild($newElement)
        
        $newElement = $auditxml.CreateElement("IncMailServerDisplayAddress")
        $newElement.Set_InnerText($service.ServerDisplayAddress)
        $newService.AppendChild($newElement)
        
        $newElement = $auditxml.CreateElement("DropFolder")
        $newElement.Set_InnerText($service.DropFolder)
        $newService.AppendChild($newElement)  
        
        $newElement = $auditxml.CreateElement("SmtpInstanceId")
        $newElement.Set_InnerText($service.SmtpInstanceId)
        $newService.AppendChild($newElement)       
        
        $newElement = $auditxml.CreateElement("UseDirectoryManagementService")
        $newElement.Set_InnerText($service.UseDirectoryManagementService)
        $newService.AppendChild($newElement)
        
        $newElement = $auditxml.CreateElement("RemoteDirectoryManagementService")
        $newElement.Set_InnerText($service.RemoteDirectoryManagementService)
        $newService.AppendChild($newElement)
                        
        $newElement = $auditxml.CreateElement("DirectoryMgmtMailServerAddress")
        $newElement.Set_InnerText($service.ServerAddress)
        $newService.AppendChild($newElement)       
        
        $newElement = $auditxml.CreateElement("DistributionGroupsEnabled")
        $newElement.Set_InnerText($service.DistributionGroupsEnabled)
        $newService.AppendChild($newElement)
        
        $newElement = $auditxml.CreateElement("DLsRequireAuthenticatedSenders")
        $newElement.Set_InnerText($service.DLsRequireAuthenticatedSenders)
        $newService.AppendChild($newElement)        
               
        # Append the new Outbound Mail Service Node to the XML variable
        $auditxml.Customer.Farm["FarmServices"].AppendChild($newService)
    }
    #Document WSS Search settings
    elseif ($service.TypeName -eq "Windows SharePoint Services Help Search" -or $service.TypeName -eq "SharePoint Foundation Search")
    {
        $newService = $auditxml.CreateElement("Service")
        $newService.SetAttribute("Name",$service.TypeName)
           
        $newElement = $auditxml.CreateElement("SearchServiceAccount")
        $newElement.Set_InnerText($service.ProcessIdentity.UserName)
        $newService.AppendChild($newElement)
        
        if($spFarm.BuildVersion.Major -eq "12")
		{
			#Check to see if the Service Account data has already been logged
			$serviceAcct = $service.ProcessIdentity.UserName
			if(-not $auditxml.selectSingleNode("//Customer/Farm/FarmAccounts/Account[@UserName='$serviceAcct']"))
			{			
				$newElement = $auditxml.CreateElement("Account")
			    $newElement.SetAttribute("UserName",$service.ProcessIdentity.UserName)
				$newElement.SetAttribute("Password",$service.ProcessIdentity.Password)
			    $farmAcctNode.AppendChild($newElement)
			}
		}
        
        $newElement = $auditxml.CreateElement("CrawlAccount")
        $newElement.Set_InnerText($service.CrawlAccount)
        $newService.AppendChild($newElement)  
		        
        # Append the new Outbound Mail Service Node to the XML variable
        $auditxml.Customer.Farm["FarmServices"].AppendChild($newService)
          
    }
    #Document Timer Service settings
    elseif ($service.TypeName -eq "Windows SharePoint Services Timer")
    {
        $newService = $auditxml.CreateElement("Service")
        $newService.SetAttribute("Name",$service.TypeName)
           
        $newElement = $auditxml.CreateElement("TimerServiceAccount")
        $newElement.Set_InnerText($service.ProcessIdentity.UserName)
        $newService.AppendChild($newElement)
        
        $newElement = $auditxml.CreateElement("TimerServicePass")
        $newElement.Set_InnerText($service.ProcessIdentity.Password)
        $newService.AppendChild($newElement)
                        
        # Append the new Outbound Mail Service Node to the XML variable
        $auditxml.Customer.Farm["FarmServices"].AppendChild($newService)          
    }
    #Document OSearch settings
    elseif ($service.TypeName -eq "Office SharePoint Server Search" -or $service.TypeName -eq "SharePoint Server Search")
    {
        $newService = $auditxml.CreateElement("Service")        
        $newService.SetAttribute("Name",$service.TypeName)
           
        $newElement = $auditxml.CreateElement("OSearchServiceAccount")
        $newElement.Set_InnerText($service.ProcessIdentity.UserName)
        $newService.AppendChild($newElement)
		
		if($spFarm.BuildVersion.Major -eq "12")
		{
			#Check to see if the Service Account data has already been logged
			$serviceAcct = $service.ProcessIdentity.UserName
			if(-not $auditxml.selectSingleNode("//Customer/Farm/FarmAccounts/Account[@UserName='$serviceAcct']"))
			{			
				$newElement = $auditxml.CreateElement("Account")
			    $newElement.SetAttribute("UserName",$service.ProcessIdentity.UserName)
				$newElement.SetAttribute("Password",$service.ProcessIdentity.Password)
			    $farmAcctNode.AppendChild($newElement)
			}
		}
        
        $newElement = $auditxml.CreateElement("ContactEmail")
        $newElement.Set_InnerText($service.ContactEmail)
        $newService.AppendChild($newElement)
                       
        $newElement = $auditxml.CreateElement("IgnoreSSLWarnings")
        $newElement.Set_InnerText($service.IgnoreSSLWarnings)
        $newService.AppendChild($newElement)
        
        $newElement = $auditxml.CreateElement("PerformanceLevel")
        $newElement.Set_InnerText($service.PerformanceLevel)
        $newService.AppendChild($newElement)
        
        $newElement = $auditxml.CreateElement("ProxyType")
        $newElement.Set_InnerText($service.ProxyType)
        $newService.AppendChild($newElement)
        
        $newElement = $auditxml.CreateElement("ConnectionTimeout")
        $newElement.Set_InnerText($service.ConnectionTimeout)
        $newService.AppendChild($newElement)
        
        $newElement = $auditxml.CreateElement("AcknowledgementTimeout")
        $newElement.Set_InnerText($service.AcknowledgementTimeout)
        $newService.AppendChild($newElement)
                        
        # Append the new Outbound Mail Service Node to the XML variable
        $auditxml.Customer.Farm["FarmServices"].AppendChild($newService)          
    }        
}
#EndRegion Document Farm Services and Settings

#Region Managed Accounts
if($spFarm.BuildVersion.Major -eq "14")
{
	#Get a collection of SP2010 Managed Accounts
	$mgdAccounts = Get-SPManagedAccount | select UserName, @{Name=“Password”; Expression={ConvertTo-UnsecureString (GetFieldValue $_ “m_Password”).SecureStringValue}}

	foreach($mgdAccount in $mgdAccounts)
	{
		$newElement = $auditxml.CreateElement("Account")
	    $newElement.SetAttribute("UserName",$mgdAccount.UserName)
		$newElement.SetAttribute("Password",$mgdAccount.Password)
	    $farmAcctNode.AppendChild($newElement)	
	}
}
#EndRegion Managed  Accounts

#Region Document SSPs and Service Apps
if($spFarm.BuildVersion.Major -eq "12")
{
	# ---------------------------------------Document SSP Configuration---------------------------------------------

	# Generate a list of all of the SSPs in the Farm and their Configurations
	[xml]$farmSSP = (stsadm -o enumssp -all)

	$newNode = $auditxml.CreateElement("FarmSSPs")

	$auditxml.Customer["Farm"].AppendChild($newNode)

	# Process the dumped SSP configuration and populate the SSP XML node
	foreach($node in $farmSSP.GetElementsByTagName("Ssp"))
	{                      
	    # Create the SSP Node and set attributes
	    $newSSP = $auditxml.CreateElement("Ssp")
	    $newSSP.SetAttribute("Name",$node.Name)
	    $newSSP.SetAttribute("Default",$node.Default)
	    $newSSP.SetAttribute("Ssl",$node.Ssl)
	    $newSSP.SetAttribute("Status",$node.Status)
		
		$SplitVar = $node.Account.Username.Split("\")
		
	    $newElement = $auditxml.CreateElement("ServiceAccountName")
	    $newElement.Set_InnerText($SplitVar[1])
	    $newSSP.AppendChild($newElement)
		
		
		#Check to see if the Service Account data has already been logged
		$serviceAcct = $node.Account.Username
		if(-not $auditxml.selectSingleNode("//Customer/Farm/FarmAccounts/Account[@UserName='$serviceAcct']"))
		{
			$newElement = $auditxml.CreateElement("Account")
		    $newElement.SetAttribute("UserName",$node.Account.Username)
			$newElement.SetAttribute("Password",$node.Account.Password)
		    $farmAcctNode.AppendChild($newElement)
		}
		
	   
	    # Loop through each of the SSP related Web Apps (SSP, MySite) and document their properties
	    foreach ($item in $node.Site)
	    {    
	        $newElement = $auditxml.CreateElement("Site")
	        $newElement.SetAttribute("Type",$item.Type)
	        $newElement.SetAttribute("Url",$item.Url)
	        $newSSP.AppendChild($newElement)
	    }
	    
	    # Loop through each of the SSP Databases and document their properties
	    foreach ($item in $node.Database)
	    {    
	        $newElement = $auditxml.CreateElement("Database")
	        $newElement.SetAttribute("Type",$item.Type)
	        $newElement.SetAttribute("Name",$item.Name)
	        $newElement.SetAttribute("Server",$item.Server)
	        $newElement.SetAttribute("AuthType",$item.Authentication)
	        $newSSP.AppendChild($newElement)
	    }
	    
	    $newElement = $auditxml.CreateElement("IndexServer")
	    $newElement.Set_InnerText($node.IndexServer.Server)
	    $newSSP.AppendChild($newElement)
	            
	    $newElement = $auditxml.CreateElement("IndexServerPath")
	    $newElement.Set_InnerText($node.IndexServer.Path)
	    $newSSP.AppendChild($newElement)
	    
	    $newWebApp = $auditxml.CreateElement("AssociatedWebApplications")
	    
	           
	    # Loop through each Web Application that is assigned to the current SSP and document them
	    foreach ($item in $node.AssociatedWebApplications.WebApplication)
	    {	      
	        $newElement = $auditxml.CreateElement("WebApp")
	        $newElement.SetAttribute("Name",$item.Name)
	        $newElement.SetAttribute("Url",$item.Url)
	        $newWebApp.AppendChild($newElement)              
	    }          
	    
	    # Append each web app element to the SSP Node
	    $newSSP.AppendChild($newWebApp)
	    
	    # Append the new SSP Node to the XML variable
	    $auditxml.Customer.Farm["FarmSSPs"].AppendChild($newSSP)
	}
}
elseif($spFarm.BuildVersion.Major -eq "14")
{
	# ---------------------------------------Document Service App Configuration---------------------------------------------
	
	#Create the FarmServiceApplications Node
	$newNode = $auditxml.CreateElement("FarmServiceApplications")
	
	#Append the FarmServiceApplications Node to the current Farm Node
	$auditxml.Customer["Farm"].AppendChild($newNode)
	
	#Get a collection of Service Apps in the Farm
	$serviceApps = Get-SPServiceApplication
	
	#Loop through each Service App in the collection
	foreach($serviceApp in $serviceApps)
	{
		#Document properties of each Service Application
		$newServiceApp = $auditxml.CreateElement("ServiceApp")
        $newServiceApp.SetAttribute("TypeName",$serviceApp.TypeName)
        $newServiceApp.SetAttribute("Status",$serviceApp.Status)
		
		$newElement = $auditxml.CreateElement("DisplayName")
        $newElement.Set_InnerText($serviceApp.DisplayName)
        $newServiceApp.AppendChild($newElement)
		
		$newElement = $auditxml.CreateElement("ServiceApplicationPoolName")
        $newElement.Set_InnerText($serviceApp.ApplicationPool.Name)
        $newServiceApp.AppendChild($newElement)
		
		if($serviceApp.ApplicationPool.ProcessAccountName)
		{
			$SplitVar = $serviceApp.ApplicationPool.ProcessAccountName.Split("\")
			$uName = $splitVar[1]
		}
		else{$uName = ""}
		
		$newElement = $auditxml.CreateElement("ServiceApplicationPoolAcctName")
        $newElement.Set_InnerText($uName)
        $newServiceApp.AppendChild($newElement)
		
		$newElement = $auditxml.CreateElement("ServiceApplicationProxyGroup")
        $newElement.Set_InnerText($serviceApp.ServiceApplicationProxyGroup.FriendlyName)
        $newServiceApp.AppendChild($newElement)
		
		$newElement = $auditxml.CreateElement("Partitioning")
		$newElement.Set_InnerText($serviceApp.Properties.Values)
        $newServiceApp.AppendChild($newElement)
		
		#Document Search Service App specific properties
		if($serviceApp.TypeName -eq "Search Service Application")
		{
			$newElement = $auditxml.CreateElement("SearchAdminComponent")
        	$newElement.SetAttribute("IndexLocation",$serviceApp.AdminComponent.IndexLocation)
			$newElement.SetAttribute("Initialized",$serviceApp.AdminComponent.Initialized)
			$newElement.SetAttribute("ServerName",$serviceApp.AdminComponent.ServerName)
			$newElement.SetAttribute("Standalone",$serviceApp.AdminComponent.Standalone)
        	$newServiceApp.AppendChild($newElement)
			
			$splitVar = $serviceApp.SearchAdminDatabase.Server.ToString().Split("=")
			$newElement = $auditxml.CreateElement("SearchAdminDatabase")
        	$newElement.SetAttribute("DBName",$serviceApp.SearchAdminDatabase.Name)
			$newElement.SetAttribute("DBType",$serviceApp.SearchAdminDatabase.Type)
			$newElement.SetAttribute("ID",$serviceApp.SearchAdminDatabase.ID)
			$newElement.SetAttribute("DBServer",$splitVar[1])
        	$newServiceApp.AppendChild($newElement)
			
			$newElement = $auditxml.CreateElement("SearchApplicationType")
        	$newElement.Set_InnerText($serviceApp.SearchApplicationType)
        	$newServiceApp.AppendChild($newElement)
			
			$newCrawlStores = $auditxml.CreateElement("CrawlStores")
			foreach($crawlStore in $serviceApp.CrawlStores)
			{
				$newElement = $auditxml.CreateElement("CrawlStore")
	        	$newElement.SetAttribute("DBName",$crawlStore.Name)
				$newElement.SetAttribute("ID",$crawlStore.ID)
				$newElement.SetAttribute("IsDedicated",$crawlStore.IsDedicated)
	        	$newCrawlStores.AppendChild($newElement)
			}
			$newServiceApp.AppendChild($newCrawlStores)
			
			$crawlTops = $serviceApp.CrawlTopologies
			foreach($crawlTop in $crawlTops)
			{
				$newCrawlTop = $auditxml.CreateElement("CrawlTopology")
			    $newCrawlTop.SetAttribute("ID",$crawlTop.ID)
			    $newCrawlTop.SetAttribute("State",$crawlTop.State)
												
				foreach($crawlComp in $crawlTop.CrawlComponents)
				{
					$newElement = $auditxml.CreateElement("CrawlComponent")
		        	$newElement.SetAttribute("ID",$crawlComp.Id)
					$newElement.SetAttribute("ServerName",$crawlComp.ServerName)
					$newElement.SetAttribute("IndexLocation",$crawlComp.IndexLocation)
					$newElement.SetAttribute("CrawlStoreId",$crawlComp.CrawlDatabaseId)
					$newElement.SetAttribute("State",$crawlComp.State)
					$newElement.SetAttribute("DesiredState",$crawlComp.DesiredState)
		        	$newCrawlTop.AppendChild($newElement)
				}
				$newServiceApp.AppendChild($newCrawlTop)
				
			}
			
			$queryTops = $serviceApp.QueryTopologies
			foreach($queryTop in $queryTops)
			{
				$newQueryTop = $auditxml.CreateElement("QueryTopology")
			    $newQueryTop.SetAttribute("ID",$queryTop.ID)
			    $newQueryTop.SetAttribute("State",$queryTop.State)
				
				$indexParts = $queryTop.IndexPartitions
				
				foreach($indexPart in $indexParts)
				{
					$newIndexPart = $auditxml.CreateElement("IndexPartition")
				    $newIndexPart.SetAttribute("ID",$indexPart.ID)
				    $newIndexPart.SetAttribute("Ordinal",$indexPart.Ordinal)
					$newIndexPart.SetAttribute("PropertyDatabaseId",$indexPart.PropertyDatabaseId)
				
					foreach($queryComp in $indexPart.QueryComponents)
					{
						$newElement = $auditxml.CreateElement("QueryComponent")
			        	$newElement.SetAttribute("Name",$queryComp.Name)
						$newElement.SetAttribute("ServerName",$queryComp.ServerName)
						$newElement.SetAttribute("IndexLocation",$queryComp.IndexLocation)
						$newElement.SetAttribute("FailoverOnly",$queryComp.FailoverOnly)
						$newElement.SetAttribute("State",$queryComp.State)				
			        	$newIndexPart.AppendChild($newElement)
					}
					$newQueryTop.AppendChild($newIndexPart)
				}
				$newServiceApp.AppendChild($newQueryTop)
			}
		}
		#Document Web Analytics Service App specific properties
		elseif($serviceApp.TypeName -eq "Web Analytics Service Application")
		{			
			[xml]$reportingDBs = $serviceApp.WarehouseSubscriptions
			foreach($reportingDB in $reportingDBs.ReportingDatabases)
			{
				$splitVar = $reportingDB.ReportingDatabase.ToString().Split(";")
				$newElement = $auditxml.CreateElement("WarehouseDatabase")
				$newElement.SetAttribute("DBName",$SplitVar[1])	
		        $newElement.SetAttribute("DBServer",$SplitVar[0])			
		        $newServiceApp.AppendChild($newElement)
			}
			
			[xml]$stagerDBs = $serviceApp.StagerSubscriptions
			foreach($stagerDB in $stagerDBs.StagingDatabases)
			{
				$splitVar = $stagerDB.StagingDatabase.ToString().Split(";")
				$newElement = $auditxml.CreateElement("StagingDatabase")
				$newElement.SetAttribute("DBName",$SplitVar[1])	
		        $newElement.SetAttribute("DBServer",$SplitVar[0])			
		        $newServiceApp.AppendChild($newElement)
			}			
		}
		#Document Usage and Health Data Collection Service App specific properties
		elseif($serviceApp.TypeName -eq "Usage and Health Data Collection Service Application")
		{
			$splitVar = $serviceApp.UsageDatabase.Server.ToString().Split("=")
			$newElement = $auditxml.CreateElement("UsageDatabase")
	        $newElement.SetAttribute("DBName",$serviceApp.UsageDatabase.Name)
			$newElement.SetAttribute("DBType",$serviceApp.UsageDatabase.Type)
			$newElement.SetAttribute("DBServer",$splitVar[1])
	        $newServiceApp.AppendChild($newElement)
			
		}
		#Document User Profile Service App specific properties
		elseif($serviceApp.TypeName -eq "User Profile Service Application")
		{
			
			$serviceApp
			#Still need to figure out how to get the Databases associated with this Service App
		}		
		#Document State Service App specific properties
		elseif($serviceApp.TypeName -eq "State Service")
		{			
			foreach($database in $serviceApp.Databases)
			{
				$splitVar = $database.Server.ToString().Split("=")
				$newElement = $auditxml.CreateElement("Database")
		        $newElement.SetAttribute("DBName",$database.Name)
				$newElement.SetAttribute("DBType",$database.Type)
				$newElement.SetAttribute("DBServer",$splitVar[1])
		        $newServiceApp.AppendChild($newElement)
			}			
		}		
		elseif($serviceApp.TypeName -eq "Business Data Connectivity Service Application" -or $serviceApp.TypeName -eq "Managed Metadata Service" -or $serviceApp.TypeName -eq "PerformancePoint Service Application")
		{	
			$splitVar = $serviceApp.Database.Server.ToString().Split("=")
			$newElement = $auditxml.CreateElement("Database")
	        $newElement.SetAttribute("DBName",$serviceApp.Database.Name)
			$newElement.SetAttribute("DBType",$serviceApp.Database.Type)
			$newElement.SetAttribute("DBServer",$splitVar[1])
	        $newServiceApp.AppendChild($newElement)
		}
	    
		$newNode.AppendChild($newServiceApp)
	}
	
}
#EndRegion Document SSPs and Service Apps

#Region Document Farm Solutions

$newNode = $auditxml.CreateElement("FarmSolutions")

$auditxml.Customer["Farm"].AppendChild($newNode)

# Query Farm Solutions
$farmSolutions = $spFarm.Solutions

# Loop through each Solution installed in the Farm and Document their settings
foreach ($solution in $farmSolutions)
{          
    # Create a new Solution Element and give it a Name
    $newSolution = $auditxml.CreateElement("Solution")
    $newSolution.SetAttribute("Name",$solution.Name)    
    $newSolution.SetAttribute("SolutionID",$solution.SolutionID)
    
    # Create a Solution File Element       
    $newElement = $auditxml.CreateElement("Filename")
    $newElement.Set_InnerText($solution.SolutionFile)
    $newSolution.AppendChild($newElement)
    
    # Create a Solution Deployment Status Element       
    $newElement = $auditxml.CreateElement("Deployed")
    $newElement.Set_InnerText($solution.Deployed)
    $newSolution.AppendChild($newElement)
    
    # Create a Solution Deployment State Element       
    $newElement = $auditxml.CreateElement("DeploymentState")
    $newElement.Set_InnerText($solution.DeploymentState)
    $newSolution.AppendChild($newElement)
    
    # Create a Solution Deployment State Element       
    $newElement = $auditxml.CreateElement("ContainsGlobalAssembly")
    $newElement.Set_InnerText($solution.ContainsGlobalAssembly)
    $newSolution.AppendChild($newElement)
    
    # Create a Solution Deployment State Element       
    $newElement = $auditxml.CreateElement("ContainsCasPolicy")
    $newElement.Set_InnerText($solution.ContainsCasPolicy)
    $newSolution.AppendChild($newElement)
       
    # Create a Deployed WebApps Element to document all of the Appications that the current Solution is deployed to
    $newDeployedUrls = $auditxml.CreateElement("DeployedUrls")
    
    # Loop through each of the WebApps for the current Solution and create a new Element for each
    foreach ($depWebApp in $solution.DeployedWebApplications)
    {
        foreach ($site in $depWebApp.Sites)
        {        
            if ($site.ServerRelativeUrl -eq "/")
            {
                $newElement = $auditxml.CreateElement("DeployedUrl")
                $newElement.Set_InnerText($site.Url)
                $newDeployedUrls.AppendChild($newElement)             
            }
        }                    
    }   
    
    # Append all of the new Deployed Url Elements to the current Solution Node
    $newSolution.AppendChild($newDeployedUrls) 
    
    # Append the finalized Solution Node to the Solutions Node
    $auditxml.Customer.Farm["FarmSolutions"].AppendChild($newSolution)
}
#EndRegion Document Farm Solutions

#Region Document the Servers in the Farm and all of their Roles

$newNode = $auditxml.CreateElement("FarmServers")

$auditxml.Customer["Farm"].AppendChild($newNode)

foreach ($server in $farmServers)
{  
    # Create a new Server Element and give it a Name
    $newServer = $auditxml.CreateElement("Server")
    $newServer.SetAttribute("Name",$server.Name)    
    
    # Create a Server Role Element
    if (-not ($server.Role -eq "Invalid"))
    {       
        $newElement = $auditxml.CreateElement("Role")
        $newElement.Set_InnerText($server.Role)
        $newServer.AppendChild($newElement)
    }
    
    # Create a Services Element to document all of the Farm Services on the current server
    $newServices = $auditxml.CreateElement("Services")
    
    # Loop through each of the Services for the current server and create a new Element for each
    foreach ($service in $server.ServiceInstances | sort -Property TypeName)
    {        
        $newElement = $auditxml.CreateElement("Service")
        $newElement.SetAttribute("Name",$service.TypeName)
		$newElement.SetAttribute("Status",$service.Status)
        $newServices.AppendChild($newElement)                
    }
    
    # Append all of the new Services Elements to the current Server Node
    $newServer.AppendChild($newServices)
    
    # Append the finalized Server Node to the Servers Node
    $auditxml.Customer.Farm["FarmServers"].AppendChild($newServer)
    
}
#EndRegion Document the Servers in the Farm and all of their Roles

#Region Output to File
# Create the output file name
$farmID = $spFarm.Id
$outFile = "Farm" + '-' + "$farmID" + '_' +"audit.xml"

# Write the XML file to disk
$auditxml.Save("$curloc\$outFile")
#EndRegion Output to File$var