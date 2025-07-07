# Connect to vCenter Server
Connect-VIServer -Server "your-vcenter-server" -User "administrator@vsphere.local" -Password "your-password"

# Get all ESXi hosts in the cluster
$ClusterName = "Your-Cluster-Name"
$ESXiHosts = Get-Cluster -Name $ClusterName | Get-VMHost

# Enable SSH service on all hosts in the cluster
foreach ($VMHost in $ESXiHosts) {
    Write-Host "Enabling SSH on $($VMHost.Name)..." -ForegroundColor Green
    
    # Start SSH service
    Get-VMHostService -VMHost $VMHost | Where-Object {$_.Key -eq "TSM-SSH"} | Start-VMHostService
    
    # Set SSH service to start automatically
    Get-VMHostService -VMHost $VMHost | Where-Object {$_.Key -eq "TSM-SSH"} | Set-VMHostService -Policy "On"
    
    # Verify SSH is running
    $SSHStatus = Get-VMHostService -VMHost $VMHost | Where-Object {$_.Key -eq "TSM-SSH"}
    Write-Host "SSH Status on $($VMHost.Name): $($SSHStatus.Running) (Policy: $($SSHStatus.Policy))" -ForegroundColor Yellow
}

Write-Host "SSH has been enabled on all hosts in cluster: $ClusterName" -ForegroundColor Green

# Disconnect from vCenter
Disconnect-VIServer -Confirm:$false



# Get all ESXi hosts in the cluster
$ClusterName = "Your-Cluster-Name"
$ESXiHosts = Get-Cluster -Name $ClusterName | Get-VMHost

# Disable SSH service on all hosts in the cluster
foreach ($VMHost in $ESXiHosts) {
    Write-Host "Disabling SSH on $($VMHost.Name)..." -ForegroundColor Red
    
    # Stop SSH service
    Get-VMHostService -VMHost $VMHost | Where-Object {$_.Key -eq "TSM-SSH"} | Stop-VMHostService -Confirm:$false
    
    # Set SSH service to manual start (off)
    Get-VMHostService -VMHost $VMHost | Where-Object {$_.Key -eq "TSM-SSH"} | Set-VMHostService -Policy "Off"
    
    # Verify SSH is stopped
    $SSHStatus = Get-VMHostService -VMHost $VMHost | Where-Object {$_.Key -eq "TSM-SSH"}
    Write-Host "SSH Status on $($VMHost.Name): $($SSHStatus.Running) (Policy: $($SSHStatus.Policy))" -ForegroundColor Yellow
}

Write-Host "SSH has been disabled on all hosts in cluster: $ClusterName" -ForegroundColor Red

# Disconnect from vCenter
Disconnect-VIServer -Confirm:$false
