$db = Get-SPCONTENTDatabase "sp_insightqa_Onenetqa_DB01"
$db.Repair($true)
$db.Update() 