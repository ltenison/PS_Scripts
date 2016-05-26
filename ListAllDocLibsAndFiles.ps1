Add-PSSnapin Microsoft.SharePoint.PowerShell -erroraction SilentlyContinue

$webUrl = "http://splab/teamtest"
$listUrl = "http://splab/teamtest/FolderDocLib"

$web = Get-SPWeb -Identity $webUrl
$list = $web.GetList($listUrl)

function ProcessFolder {    
      param($folderUrl)    
      $folder = $web.GetFolder($folderUrl)
      if($folder.Files.Count -gt 0) {
        write-host "Now processing", $folderURL, $folder.Files.Count 
        foreach ($file in $folder.Files) {        
            $fileURL = $file.url
            write-host "File Found:", $fileURL       
            }
      }
}

#Loop through files in folders
foreach ($folder in $list.Folders) {    
        ProcessFolder($folder.Url)
    }
Write-host "Finished."