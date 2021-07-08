# Change Cloud Director address where Organization with problem OrgVDC network is placed
$VCDConnection = connect-ciserver -server "vcd01.localdomain.local"
$sessionkey = $VCDConnection.SessionId
 
# Change this to needed Organization name where OrgVDC network is placed
$org = get-org -name "AcmeOrg"
 
# Change this to needed OrgVDC name of Organization where OrgVDC network is placed
$vdc = Get-OrgVdc -org $org -name AcmeOrg-VDC
 
# Change this to needed OrgVDC network name of Organization 
$vdcorgNetwork = Get-OrgVdcNetwork -OrgVdc $vdc -name AcmeOrg-Net

# Deleting OrgVDC network via API
$sessionkey = $VCDConnection.SessionId
write-host ("`tDeleting OrgVDC Network: "+$vdcorgNetwork.name)
$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$Headers.Add('x-vcloud-authorization', $sessionkey)
$Headers.Add('accept','application/*+xml;version=32.0')
$Headers.Add('Content-Type','application/xml')
$vdcnetURL = $vdcorgNetwork.href+'?force=true'
# Send API request for deleting problem OrgVDC network
$wr = (Invoke-WebRequest -uri $vdcnetURL -Method Delete -Headers $Headers).content
[xml]$wrxml = $wr
$wrtaskhref= $wrxml.Task.href
Write-Verbose  "wrtaskhref: $wrtaskhref"
# Check status of task where we deleting OrgVDC network until result will be successful
try{
while($ts -ne 'success')
{
[xml]$taskstatus = (Invoke-WebRequest -uri $wrtaskhref -Method get -Headers $headers).content
$ts = $taskstatus.Task.Status
Write-Verbose "ts: $ts"
start-sleep -Seconds 3}
}
catch{}
Write-Verbose -Message 'Pausing for 15 seconds so system can stabilized'
start-sleep -seconds 15
