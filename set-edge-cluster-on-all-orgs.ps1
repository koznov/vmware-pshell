# Set address of Cloud Director
$vCDServer = "vcd.iaas.lab"

# Connect to Cloud Director server
Connect-CIServer $vCDServer -Credential $(Get-Credential -UserName $env:USERNAME -Message "Please specify $vCDServer credential") -SaveCredentials | Out-Null

# Add function that will be used to proceed with JSON body 
Function vCloud-JSON-REST(
    [Parameter(Mandatory=$true)][string]$URI,
    [string]$ContentType,
    [string]$Method = 'Get',
    [string]$ApiVersion = '32.0',
    [string]$Body,
    [int]$Timeout = 40
    )
{
    $SessionID = ($global:DefaultCIServers | Where { $_.Name -eq $vCDServer }).SessionId
    $Headers = @{ "x-vcloud-authorization" = $SessionID; "Accept" = 'application/*;version=' + $ApiVersion}
    if (!$ContentType) { Remove-Variable ContentType }
    if (!$Body) { Remove-Variable Body }
        Try
            {
                $response = Invoke-RestMethod -Method $Method -Uri $URI -Headers $headers -Body $Body -ContentType $ContentType -TimeoutSec $Timeout
            }
        Catch
{
    Write-Host "Exception: " $_.Exception.Message
    if ( $_.Exception.ItemName ) { Write-Host "Failed Item: " $_.Exception.ItemName }
        Write-Host "Exiting."
    Return
}
    return $response
}

# The same function but using XML output
Function vCloud-REST(
    [Parameter(Mandatory=$true)][string]$URI,
    [string]$ContentType,
    [string]$Method = 'Get',
    [string]$ApiVersion = '32.0',
    [string]$Body,
    [int]$Timeout = 40
    )
{
    $SessionID = ($global:DefaultCIServers | Where { $_.Name -eq $vCDServer }).SessionId
    $Headers = @{ "x-vcloud-authorization" = $SessionID; "Accept" = 'application/*;version=' + $ApiVersion}
    if (!$ContentType) { Remove-Variable ContentType }
    if (!$Body) { Remove-Variable Body }
        Try
            {
                [xml]$response = Invoke-RestMethod -Method $Method -Uri $URI -Headers $headers -Body $Body -ContentType $ContentType -TimeoutSec $Timeout
            }
        Catch
{
    Write-Host "Exception: " $_.Exception.Message
    if ( $_.Exception.ItemName ) { Write-Host "Failed Item: " $_.Exception.ItemName }
        Write-Host "Exiting."
    Return
}
    return $response
}

# In case where you've got more that one ProviderVDC you should use some additional commandlets to get all OrgVDC's with needed PVDC. I use manual list that I get from Cloud Director interface. 
# Setting list of URI of Organization VDCs that should be updated with Edge Gateway Cluster settings
$vdc_ids = @"
XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX
XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX
XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX
su
"@ -split "`n" | % { $_.trim() }

# In case when you've got only one Provider VDC you can use next construction to get all Orgs in Cloud Director installation
# Getting all OrgVDCs from Cloud Director site

# Counter of OrgVDCs
$c1 = 0

Write-Host "
		        	Getting all OrgVDCs from all Orgs from Cloud Director $vcdServer"

# URL that provides all OrgVDCs
$AllOrgVDCURL = 'https://' + $vCDServer + "/cloudapi/1.0.0/vdcs?page=1&pageSize=128"

# Getting info from that URL
$response = vCloud-JSON-REST -URI $AllOrgVDCURL -ContentType "application/json;version=35.0" -Method Get -ApiVersion '35.0'

# Block for looking through all pages if count of resultTotal in first request more than 128
$vdc_ids = [System.Collections.Generic.List[string]]::new()
if ($response.resultTotal -lt 128){
    $orgvdcs = $response.values
    foreach ($orgvdc in $orgvdcs){
        if (-not ($vdc_ids.Contains($orgvdc.id.split(':')[3]))){
            $vdc_ids.Add($orgvdc.id.split(':')[3])
        }

    }
} else {
    for ($num = 1 ; $num -le $response.pageCount ; $num++){
        $URI = 'https://' + $vCDServer + "/cloudapi/1.0.0/vdcs?page=" + $num + '&pageSize=128'
        $response = vCloud-JSON-REST -URI $URI -ContentType "application/json;version=35.0" -Method Get -ApiVersion '35.0'
        $orgvdcs = $response.values
        foreach ($orgvdc in $orgvdcs){
            if (-not ($vdc_ids.Contains($orgvdc.id.split(':')[3]))){
                $vdc_ids.Add($orgvdc.id.split(':')[3])
            }

        }
    }

}

# Going through all OrgVDCs
Foreach ($vdc_id in $vdc_ids) { 

# Section with settings of Edge Clusters for Organization VDC
# Creating URI for current OrgVDC in loop
$OrgvDCNameURI = "https://" + $vCDServer + "/api/query?type=adminOrgVdc&filter=((id==$vdc_id))"
# Getting OrgVDC name
$orgvdcname = (vCloud-REST -URI $OrgvDCNameURI -Method Get -ApiVersion '32.0')

# Adding counter of OrgVDC
$c1++
# Decorations
Write-Progress -Id 0 -Activity 'Checking and setting Org VDC Edge Cluster settings' -Status "Processing $($c1) OrgVDC of $($vdc_ids.count)" -CurrentOperation $($orgvdcname.QueryResultRecords.AdminVdcRecord.name) -PercentComplete (($c1/$vdc_ids.Count) * 100)

# URI for network profile of OrgVDC
$OrgvDCNPURI = 'https://' + $vCDServer + "/cloudapi/1.0.0/vdcs/urn:vcloud:vdc:" + $vdc_id + "/networkProfile"

# Check for current settings of Edge Gateway cluster in current OrgVDC.
$checkEC = ($null -eq (vCloud-JSON-REST -URI $OrgvDCNPURI -ContentType "application/json;version=32.0" -Method Get -ApiVersion '32.0').primaryEdgeCluster)

# Getting ProviderVDC name
$ProviderVDC = $orgvdcname.QueryResultRecords.AdminVdcRecord.providerVdcName

# If we already have settings in network profile of OrgVDC - we skip this org and goes to another one.
if (-not $checkEC)

{
Write-Host "
		!!! Edge Cluster configuration at Org VDC $($orgvdcname.QueryResultRecords.AdminVdcRecord.name) already exists !!! Skipping." -ForegroundColor green 

}
# If we don't have settings in network profile of OrgVDC - we setup that settings to network profile of OrgVDC.
else
{
# Compiling content of future JSON request with Primary and Secondary Edge cluster for needed ProviderVDC and Cloud Director
    $primaryEdgeCluster = $(
        SWITCH ($vCDServer) {
                "vcd.iaas.lab" {
                SWITCH ( $ProviderVDC )
                    {
                        "ProviderVDC-Name01" { 'urn:vcloud:edgeCluster:YYYYYYYY-YYYY-YYYY-YYYY-YYYYYYYYYYYY' } 
                        "ProviderVDC-Name02" { 'urn:vcloud:edgeCluster:YYYYYYYY-YYYY-YYYY-YYYY-YYYYYYYYYYYY' }
                    }
            }
            }
    )
    
    $secondaryEdgeCluster = $(
        SWITCH ($vCDServer) {
            "vcd.iaas.lab" {
            SWITCH ( $ProviderVDC )
                {
                        "ProviderVDC-Name01" { 'urn:vcloud:edgeCluster:ZZZZZZZZ-ZZZZ-ZZZZ-ZZZZ-ZZZZZZZZZZZZ' } 
                        "ProviderVDC-Name02" { 'urn:vcloud:edgeCluster:ZZZZZZZZ-ZZZZ-ZZZZ-ZZZZ-ZZZZZZZZZZZZ' }
                }
        }
        }
    )
              
# Putting settings to array
$EdgeClusterConfig = @{
    primaryEdgeCluster = @{
        name = "Edge-Cluster-01";
        id = $primaryEdgeCluster
    };
    secondaryEdgeCluster = @{
        name = "Edge-Cluster-02";
        id = $secondaryEdgeCluster
    };
}

# Converting array to JSON
$JSONClusterConfig = $EdgeClusterConfig | ConvertTo-Json

# Decorations
Write-Host "
		       Current settings of Edge Cluster is empty. 	Setting Edge Cluster configuration to Org VDC $($orgvdcname.QueryResultRecords.AdminVdcRecord.name)"  -ForegroundColor yellow

# Putting JSON settings with Edge Cluster configuration to Network Profile of OrgVDC
vCloud-JSON-REST -URI $OrgvDCNPURI -ContentType "application/json;version=32.0" -Method Put -ApiVersion '32.0' -Body $JSONClusterConfig

}

}

0..2 | % {Write-Host -NoNewline "."; Start-Sleep 1}
