$status = @()
$status = get-spenterprisesearchserviceapplication | get-spenterprisesearchstatus
$s = $status[0].State
if($s -eq "Active") {
   write-host "Search topolgy is Active...skipped"
   }
else {
   write-host "Search is not yet Active..."
   }