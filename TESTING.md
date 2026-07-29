# Windows Wi-Fi MSI Test

TASK_REF: AIG-DEV-20260729-120

Use these steps on a fresh Windows laptop where Reachy Mini Control has never been installed.

## Test Steps

1. Download the test MSI artifact from the GitHub Actions run named `Windows MSI Test Build`.
2. Install Reachy Mini Control from the downloaded `.msi`.
3. Start Reachy Mini and wait about one minute.
4. Connect the Windows laptop to the same local network.
5. Start Reachy Mini Control.
6. Select the robot at `192.168.0.198`.
7. Click Start.
8. Report whether the dashboard opens.

## If The Test Fails

Return these diagnostics:

1. Take a screenshot of the failure.
2. Press `Ctrl+Shift+D` in Reachy Mini Control.
3. Save the diagnostic report.
4. Run the included PowerShell diagnostic script.
5. Return the screenshot, the diagnostic report, and the PowerShell diagnostic zip.

## Running The PowerShell Diagnostic Script

The GitHub Actions artifact includes:

```text
windows-wifi-diagnostics.ps1
```

Run it from PowerShell:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\windows-wifi-diagnostics.ps1 -RobotHost 192.168.0.198
```

The script writes a zip file to the desktop named like:

```text
reachy-mini-windows-diagnostics-YYYYMMDD-HHMMSS.zip
```
