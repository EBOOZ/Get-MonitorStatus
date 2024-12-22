<#
.NOTES
    Name: Get-MonitorStatus.ps1
    Author: Danny de Vries
    Requires: PowerShell v2 or higher
    Version History: https://github.com/EBOOZ/Get-MonitorStatus/commits/main
.SYNOPSIS
    Sets the status of an external monitor to Home Assistant.
.DESCRIPTION
    This script is monitoring connected monitors, and it makes use of one sensor that 
    is created in Home Assistant up front. The use case for this script is to monitor
    if my laptop is connected to the external monitor in my home office, and to mute
    the radio automatically either in the home office or downstairs in the kitchen,
    depending on where I'm working in the house.

    Refer to https://edid.tv/manufacturer/ for the manufacturer ID of your monitor.
.PARAMETER RunOnce
    Run the script with the RunOnce-switch to get the current connected monitors
    directly from the commandline. Get the serial number of both your internal (when
    you're using a laptop) and external home office monitors to configure Settings.ps1
.EXAMPLE
    .\Get-MonitorStatus.ps1 -RunOnce
#>
# Configuring parameter for interactive run
param (
    [switch]$RunOnce
)

# Import Settings PowerShell script
. ($PSScriptRoot + "\Settings.ps1")

# Properties like ManufacturerName, UserFriendlyName, and SerialNumberID are stored as byte arrays and need to be decoded to human-readable strings.
function Convert-MonitorProperty {
    param (
        [byte[]]$Property
    )
    # Filter out null bytes and convert to string
    $chars = $Property | Where-Object { $_ -ne 0 } | ForEach-Object { [char]$_ }
    -join $chars
}

# Run the script when a parameter is used and stop when done
If ($RunOnce) {
    $monitors = Get-CimInstance -Namespace root\wmi -ClassName WmiMonitorID
    Write-Output "Number of connected monitors: $($monitors.instanceName.Count)"
    ForEach ($monitor in $monitors) {
        $instanceName = $monitor.InstanceName
        $manufacturer = Convert-MonitorProperty -Property $monitor.ManufacturerName
        $productCode = Convert-MonitorProperty -Property $monitor.ProductCodeID
        $serialNumber = Convert-MonitorProperty -Property $monitor.SerialNumberID
        $friendlyName = Convert-MonitorProperty -Property $monitor.UserFriendlyName
    
        # Display monitor information
        Write-Output "-----------------------------"
        Write-Output "Instance Name: $instanceName"
        Write-Output "Manufacturer: $manufacturer"
        Write-Output "Product Code: $productCode"
        Write-Output "Serial Number: $serialNumber"
        Write-Output "Friendly Name: $friendlyName"
    
        # Check if the monitor is external
        If ($serialNumber -eq $externalMonitor) {
            Write-Output "-----------------------------"
            Write-Output "Home office monitor detected: $friendlyName"
            Write-Output ""
        }
        ElseIf ($serialNumber -notlike $builtInMonitor -and $serialNumber -ne $externalMonitor) {
            Write-Output "-----------------------------"
            Write-Output "External monitor detected: $friendlyName"
            Write-Output ""
        }
    }
    break
}

DO {
# Start monitoring connected monitors when no switch is used to run the script
$headers = @{"Authorization"="Bearer $HAToken";}
$Enable = 1

# Check if the configured external monitor of the home office is connected
$monitors = Get-CimInstance -Namespace root\wmi -ClassName WmiMonitorID
ForEach ($monitor in $monitors) {
    $instanceName = $monitor.InstanceName
    $manufacturer = Convert-MonitorProperty -Property $monitor.ManufacturerName
    $productCode = Convert-MonitorProperty -Property $monitor.ProductCodeID
    $serialNumber = Convert-MonitorProperty -Property $monitor.SerialNumberID
    $friendlyName = Convert-MonitorProperty -Property $monitor.UserFriendlyName

    # Check if the monitor is external
    If ($serialNumber -eq $builtInMonitor) {
        Write-Output "Internal monitor detected: $friendlyName"
        $HomeOfficeMonitor = 0
    }
    ElseIf ($serialNumber -eq $externalMonitor) {
        Write-Output "Home office monitor detected: $friendlyName"
        $HomeOfficeMonitor = 1
    }
    ElseIf ($serialNumber -notlike $builtInMonitor) {
        Write-Output "External monitor detected: $friendlyName"
        $HomeOfficeMonitor = 0
    }
}

# Configure the API call parameters based on the monitor status
If ($HomeOfficeMonitor -eq 1) {
    $Monitor = "on"
    $params = @{
        "state"="on";
        "attributes"= @{
        "icon"="mdi:monitor";
        "device_class"="connectivity";
        }
    }
}
Else {
    $Monitor = "off"
    $params = @{
        "state"="off";
        "attributes"= @{
        "icon"="mdi:monitor-off";
        "device_class"="connectivity";
        }
    }
}

# Calling the Home Assistant API to set the monitor status
Write-Output "Updating home office monitor status in Home Assistant to $Monitor"
$params = $params | ConvertTo-Json
Invoke-RestMethod -Uri "$HAUrl/api/states/$entityID" -Method POST -Headers $headers -Body ([System.Text.Encoding]::UTF8.GetBytes($params)) -ContentType "application/json"

# Wait for the next interval to check the monitor status
Start-Sleep $Interval

} Until ($Enable -eq 0)
