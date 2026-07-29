# TASK_REF: AIG-DEV-20260729-120
param(
    [string]$RobotHost = "192.168.0.198",
    [int]$DaemonPort = 8000,
    [string]$OutputDirectory = "$env:USERPROFILE\Desktop"
)

$ErrorActionPreference = "Continue"
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$reportDir = Join-Path $OutputDirectory "reachy-mini-windows-diagnostics-$timestamp"
$zipPath = "$reportDir.zip"

New-Item -ItemType Directory -Path $reportDir -Force | Out-Null

function Write-Section {
    param([string]$Title)
    "`n===== $Title =====`n"
}

function Save-Command {
    param(
        [string]$Name,
        [scriptblock]$Command
    )

    $path = Join-Path $reportDir "$Name.txt"
    try {
        & $Command 2>&1 | Out-File -FilePath $path -Encoding UTF8
    } catch {
        "Command failed: $($_.Exception.Message)" | Out-File -FilePath $path -Encoding UTF8
    }
}

$summaryPath = Join-Path $reportDir "summary.txt"
@(
    "TASK_REF: AIG-DEV-20260729-120"
    "Generated: $(Get-Date -Format o)"
    "Computer: $env:COMPUTERNAME"
    "User: $env:USERNAME"
    "RobotHost: $RobotHost"
    "DaemonPort: $DaemonPort"
) | Out-File -FilePath $summaryPath -Encoding UTF8

Save-Command "system-info" {
    Write-Section "Windows"
    Get-ComputerInfo | Select-Object WindowsProductName, WindowsVersion, OsBuildNumber, OsArchitecture
    Write-Section "PowerShell"
    $PSVersionTable
}

Save-Command "network-ipconfig" {
    ipconfig /all
}

Save-Command "network-routes" {
    route print
}

Save-Command "network-dns" {
    Get-DnsClientServerAddress
}

Save-Command "tcp-port-8000" {
    Write-Section "Listeners and connections on TCP 8000"
    netstat -ano -p tcp | Select-String ":$DaemonPort"
    Write-Section "Processes owning matching PIDs"
    $pids = netstat -ano -p tcp |
        Select-String ":$DaemonPort" |
        ForEach-Object { ($_ -split "\s+")[-1] } |
        Sort-Object -Unique
    foreach ($pidValue in $pids) {
        if ($pidValue -match "^\d+$") {
            Get-Process -Id ([int]$pidValue) -ErrorAction SilentlyContinue |
                Select-Object Id, ProcessName, Path
        }
    }
}

Save-Command "reachy-processes" {
    Get-Process |
        Where-Object { $_.ProcessName -match "reachy|tauri|webview|msedge|uv" } |
        Select-Object Id, ProcessName, Path, StartTime |
        Format-List
}

Save-Command "robot-http-probes" {
    Write-Section "GET /api/daemon/status"
    curl.exe -i --max-time 10 "http://$RobotHost`:$DaemonPort/api/daemon/status"
    Write-Section "POST /health-check"
    curl.exe -i --max-time 10 -X POST "http://$RobotHost`:$DaemonPort/health-check"
    Write-Section "GET local proxy /api/daemon/status"
    curl.exe -i --max-time 5 "http://127.0.0.1:$DaemonPort/api/daemon/status"
}

Save-Command "firewall-profile" {
    Get-NetFirewallProfile | Format-List
}

Save-Command "firewall-reachy-rules" {
    Get-NetFirewallRule |
        Where-Object { $_.DisplayName -match "Reachy|reachy|WebView|msedge|uv|Tauri" } |
        Format-List
}

Save-Command "installed-reachy" {
    Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*,
        HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -match "Reachy" } |
        Select-Object DisplayName, DisplayVersion, Publisher, InstallLocation, UninstallString |
        Format-List
}

$candidateLogDirs = @(
    "$env:LOCALAPPDATA\com.pollen-robotics.reachy-mini\logs",
    "$env:LOCALAPPDATA\Reachy Mini Control\logs",
    "$env:APPDATA\com.pollen-robotics.reachy-mini\logs",
    "$env:APPDATA\Reachy Mini Control\logs"
)

$logsOut = Join-Path $reportDir "app-logs"
New-Item -ItemType Directory -Path $logsOut -Force | Out-Null
foreach ($dir in $candidateLogDirs) {
    if (Test-Path $dir) {
        Get-ChildItem -Path $dir -File -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 10 |
            ForEach-Object {
                Copy-Item $_.FullName -Destination (Join-Path $logsOut $_.Name) -Force -ErrorAction SilentlyContinue
            }
    }
}

try {
    Compress-Archive -Path (Join-Path $reportDir "*") -DestinationPath $zipPath -Force
    Write-Host "Diagnostics saved to $zipPath"
} catch {
    Write-Host "Diagnostics directory saved to $reportDir"
    Write-Host "Zip failed: $($_.Exception.Message)"
}
