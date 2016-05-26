$web = Get-SPWeb http://insightaccess-dev/services/sales-support
write-host "Web Template:" $web.WebTemplate " | Web Template ID:" $web.WebTemplateId
$web.Dispose()
