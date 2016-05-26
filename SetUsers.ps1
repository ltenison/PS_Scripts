$wa = Get-SPWebApplication -Identity "http://splab"
$wa.Properties["portalsuperuseraccount"] = "ltg5lab\sp_superuser"
$wa.Properties["portalsuperreaderaccount"] = "ltg5lab\sp_superreader"
$wa.Update()
