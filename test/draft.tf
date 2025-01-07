To check if Rapid7 (Insight Agent) and Duo are installed on a Windows EC2 instance, you can use the following methods:

1. Using PowerShell
Run the following commands in PowerShell to check the installed software:

Check for Rapid7 Insight Agent
powershell
Copy code
Get-WmiObject -Class Win32_Product | Where-Object { $_.Name -like "*Insight Agent*" }
Check for Duo Security
powershell
Copy code
Get-WmiObject -Class Win32_Product | Where-Object { $_.Name -like "*Duo*" }
2. Using the Registry
The Windows registry stores information about installed applications. Use these commands to search the registry for Rapid7 and Duo:

Rapid7
powershell
Copy code
Get-ChildItem -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall" | ForEach-Object { Get-ItemProperty $_.PSPath } | Where-Object { $_.DisplayName -like "*Insight Agent*" }
Duo
powershell
Copy code
Get-ChildItem -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall" | ForEach-Object { Get-ItemProperty $_.PSPath } | Where-Object { $_.DisplayName -like "*Duo*" }
3. Using Command Prompt
You can also list installed programs using the wmic command in Command Prompt:

Check for Rapid7 Insight Agent
cmd
Copy code
wmic product get name | findstr /i "Insight Agent"
Check for Duo Security
cmd
Copy code
wmic product get name | findstr /i "Duo"
4. Checking Running Services
Both Rapid7 and Duo may run services. You can check for their services using PowerShell:

Check for Rapid7 Service
powershell
Copy code
Get-Service | Where-Object { $_.DisplayName -like "*Insight Agent*" }
Check for Duo Service
powershell
Copy code
Get-Service | Where-Object { $_.DisplayName -like "*Duo*" }
Additional Notes
If Rapid7 or Duo is not installed as a standard program, they may run as standalone executables or be deployed via a different mechanism (e.g., group policy or an agent). Checking running processes with Get-Process may be another alternative.
Admin privileges are typically required to query installed software or services.
