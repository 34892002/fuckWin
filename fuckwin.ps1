#requires -Version 5.1
<#
.SYNOPSIS
    A transparent, reversible Windows privacy and update control tool.
.DESCRIPTION
    Changes are grouped into explicit modules. Registry, service, and scheduled
    task state is backed up before it is changed so Restore can undo this script's
    changes. Use -WhatIf to preview every operation.
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param(
    [ValidateSet('Menu', 'All', 'Updates', 'Privacy', 'AI', 'UX', 'Bloatware', 'Restore', 'Audit')]
    [string]$Action = 'Menu',
    [ValidateSet('Notify', 'Disable', 'Lockdown')]
    [string]$UpdateMode = 'Notify',
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$script:BackupRoot = Join-Path $env:ProgramData 'fuckWin'
$script:BackupFile = Join-Path $script:BackupRoot 'backup.json'
$script:Backup = @()
$script:UpdatePolicyPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU'
$script:StandardUpdateTasks = @(
    '\Microsoft\Windows\UpdateOrchestrator\Schedule Scan',
    '\Microsoft\Windows\UpdateOrchestrator\Schedule Scan Static Task',
    '\Microsoft\Windows\WindowsUpdate\Scheduled Start'
)
$script:LockdownUpdateTasks = @(
    '\Microsoft\Windows\UpdateOrchestrator\Report policies',
    '\Microsoft\Windows\UpdateOrchestrator\Schedule Maintenance Work',
    '\Microsoft\Windows\UpdateOrchestrator\Schedule Scan',
    '\Microsoft\Windows\UpdateOrchestrator\Schedule Scan Static Task',
    '\Microsoft\Windows\UpdateOrchestrator\Schedule Wake To Work',
    '\Microsoft\Windows\UpdateOrchestrator\Schedule Work',
    '\Microsoft\Windows\UpdateOrchestrator\UpdateModelTask',
    '\Microsoft\Windows\UpdateOrchestrator\USO_UxBroker',
    '\Microsoft\Windows\WaaSMedic\PerformRemediation',
    '\Microsoft\Windows\WindowsUpdate\Scheduled Start'
)

function Write-Status {
    param([string]$Message, [ValidateSet('Info','Success','Warning','Error')][string]$Level = 'Info')
    $color = @{ Info = 'Cyan'; Success = 'Green'; Warning = 'Yellow'; Error = 'Red' }[$Level]
    Write-Host "[$Level] $Message" -ForegroundColor $color
}

function Test-Administrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Assert-Windows {
    if ($env:OS -ne 'Windows_NT') {
        throw 'fuckWin can only run on Windows.'
    }
    if (-not $WhatIfPreference -and -not (Test-Administrator)) {
        throw 'Run PowerShell as Administrator, then run fuckwin.ps1 again.'
    }
}

function Load-Backup {
    if (Test-Path $script:BackupFile) {
        try { $script:Backup = @(Get-Content $script:BackupFile -Raw | ConvertFrom-Json) }
        catch { throw "The backup file is not valid JSON: $script:BackupFile" }
    }
}

function Save-Backup {
    if ($script:Backup.Count -eq 0) { return }
    New-Item -ItemType Directory -Path $script:BackupRoot -Force | Out-Null
    $script:Backup | ConvertTo-Json -Depth 8 | Set-Content -Path $script:BackupFile -Encoding UTF8
}

function Add-Backup {
    param([hashtable]$Entry)
    $key = ($Entry.Type, $Entry.Path, $Entry.Name -join '|')
    if (-not ($script:Backup | Where-Object { ($_.Type, $_.Path, $_.Name -join '|') -eq $key })) {
        $script:Backup += [pscustomobject]$Entry
        if (-not $WhatIfPreference) { Save-Backup }
    }
}

function Set-RegistryValue {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)]$Value,
        [Microsoft.Win32.RegistryValueKind]$Kind = [Microsoft.Win32.RegistryValueKind]::DWord
    )
    $exists = Test-Path $Path
    $oldValue = $null
    $oldKind = $null
    if ($exists) {
        try {
            if ($Name -eq '(Default)') {
                $item = Get-Item $Path
                $oldValue = $item.GetValue('', $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
                $oldKind = $item.GetValueKind('').ToString()
            } else {
                $oldValue = Get-ItemPropertyValue -Path $Path -Name $Name -ErrorAction Stop
                $oldKind = (Get-Item $Path).GetValueKind($Name).ToString()
            }
        } catch { }
    }
    Add-Backup @{ Type = 'Registry'; Path = $Path; Name = $Name; Exists = ($null -ne $oldKind); Value = $oldValue; Kind = $oldKind }
    if ($PSCmdlet.ShouldProcess("$Path\$Name", "Set registry value to $Value")) {
        New-Item -Path $Path -Force | Out-Null
        if ($Name -eq '(Default)') {
            Set-Item -Path $Path -Value $Value
        } else {
            New-ItemProperty -Path $Path -Name $Name -Value $Value -PropertyType $Kind -Force | Out-Null
        }
    }
}

function Get-RegistryValueOrNull {
    param([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)][string]$Name)
    try { return Get-ItemPropertyValue -Path $Path -Name $Name -ErrorAction Stop }
    catch { return $null }
}

function Remove-RegistryValue {
    param([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)][string]$Name)
    $oldValue = $null
    $oldKind = $null
    try {
        $oldValue = Get-ItemPropertyValue -Path $Path -Name $Name -ErrorAction Stop
        $oldKind = (Get-Item $Path).GetValueKind($Name).ToString()
    } catch { return }
    Add-Backup @{ Type = 'Registry'; Path = $Path; Name = $Name; Exists = $true; Value = $oldValue; Kind = $oldKind }
    if ($PSCmdlet.ShouldProcess("$Path\$Name", 'Remove registry value')) {
        Remove-ItemProperty -Path $Path -Name $Name -Force
    }
}

function Disable-ServiceSafely {
    param([Parameter(Mandatory)][string]$Name)
    $service = Get-Service -Name $Name -ErrorAction SilentlyContinue
    if ($null -eq $service) { Write-Status "Service not found: $Name" Warning; return }
    $cim = Get-CimInstance Win32_Service -Filter "Name='$Name'"
    Add-Backup @{ Type = 'Service'; Path = $Name; Name = $Name; StartMode = $cim.StartMode; State = $cim.State }
    if (-not $PSCmdlet.ShouldProcess($Name, 'Stop and disable service')) { return }

    try {
        if ($service.Status -ne 'Stopped') { Stop-Service -Name $Name -Force -ErrorAction Stop }
        Set-Service -Name $Name -StartupType Disabled -ErrorAction Stop
    } catch {
        Write-Status "Could not fully disable service $Name`: $($_.Exception.Message)" Warning
    }

    $actual = Get-CimInstance Win32_Service -Filter "Name='$Name'" -ErrorAction SilentlyContinue
    if ($actual.StartMode -eq 'Disabled') {
        Write-Status "Service disabled: $Name" Success
    } else {
        Write-Status "Service remains $($actual.StartMode): $Name" Warning
    }
}

function Disable-TaskSafely {
    param([Parameter(Mandatory)][string]$TaskPath, [Parameter(Mandatory)][string]$TaskName)
    $task = Get-ScheduledTask -TaskPath $TaskPath -TaskName $TaskName -ErrorAction SilentlyContinue
    if ($null -eq $task) { Write-Status "Task not found: $TaskPath$TaskName" Info; return }
    Add-Backup @{ Type = 'Task'; Path = $TaskPath; Name = $TaskName; Enabled = ($task.Settings.Enabled -ne $false) }
    if (-not $PSCmdlet.ShouldProcess("$TaskPath$TaskName", 'Disable scheduled task')) { return }

    try {
        Disable-ScheduledTask -TaskPath $TaskPath -TaskName $TaskName -ErrorAction Stop | Out-Null
    } catch {
        Write-Status "Could not disable task $TaskPath$TaskName`: $($_.Exception.Message)" Warning
    }

    $actual = Get-ScheduledTask -TaskPath $TaskPath -TaskName $TaskName -ErrorAction SilentlyContinue
    if ($actual -and $actual.Settings.Enabled -eq $false) {
        Write-Status "Task disabled: $TaskPath$TaskName" Success
    } else {
        Write-Status "Task remains enabled: $TaskPath$TaskName" Warning
    }
}

function Disable-TaskByFullPath {
    param([Parameter(Mandatory)][string]$FullPath)
    $separator = $FullPath.LastIndexOf('\')
    Disable-TaskSafely $FullPath.Substring(0, $separator + 1) $FullPath.Substring($separator + 1)
}

function Restore-UpdateInfrastructure {
    $serviceNames = @('wuauserv','UsoSvc','WaaSMedicSvc')
    foreach ($entry in @($script:Backup | Where-Object { $_.Type -eq 'Service' -and $_.Path -in $serviceNames })) {
        if (-not $PSCmdlet.ShouldProcess($entry.Path, 'Restore update service for Notify mode')) { continue }
        try {
            $startupType = if ($entry.StartMode -eq 'Auto') { 'Automatic' } else { $entry.StartMode }
            Set-Service -Name $entry.Path -StartupType $startupType -ErrorAction Stop
            if ($entry.State -eq 'Running') { Start-Service -Name $entry.Path -ErrorAction Stop }
            Write-Status "Update service restored: $($entry.Path)" Success
        } catch {
            Write-Status "Could not restore update service $($entry.Path): $($_.Exception.Message)" Warning
        }
    }

    foreach ($entry in @($script:Backup | Where-Object { $_.Type -eq 'Task' -and $_.Enabled })) {
        $fullPath = "$($entry.Path)$($entry.Name)"
        if ($fullPath -notin $script:LockdownUpdateTasks) { continue }
        if (-not $PSCmdlet.ShouldProcess($fullPath, 'Restore update task for Notify mode')) { continue }
        try {
            Enable-ScheduledTask -TaskPath $entry.Path -TaskName $entry.Name -ErrorAction Stop | Out-Null
            Write-Status "Update task restored: $fullPath" Success
        } catch {
            Write-Status "Could not restore update task $fullPath`: $($_.Exception.Message)" Warning
        }
    }
}

function Test-UpdatePolicy {
    param([Parameter(Mandatory)][string]$Mode)
    $noAutoUpdate = Get-RegistryValueOrNull $script:UpdatePolicyPath 'NoAutoUpdate'
    $auOptions = Get-RegistryValueOrNull $script:UpdatePolicyPath 'AUOptions'
    $matches = if ($Mode -eq 'Notify') { $noAutoUpdate -eq 0 -and $auOptions -eq 2 } else { $noAutoUpdate -eq 1 }
    if ($matches) {
        Write-Status "Update policy verified: $Mode" Success
    } else {
        Write-Status "Update policy verification failed: NoAutoUpdate=$noAutoUpdate, AUOptions=$auOptions" Warning
    }
}

function Invoke-Updates {
    param([ValidateSet('Notify', 'Disable', 'Lockdown')][string]$Mode = 'Notify')

    if ($Mode -eq 'Notify') {
        Write-Status 'Configuring Windows Update to notify before download and installation.'
        Restore-UpdateInfrastructure
        Set-RegistryValue $script:UpdatePolicyPath 'NoAutoUpdate' 0
        Set-RegistryValue $script:UpdatePolicyPath 'AUOptions' 2
        Set-RegistryValue $script:UpdatePolicyPath 'NoAutoRebootWithLoggedOnUsers' 1
        if (-not $WhatIfPreference) { Test-UpdatePolicy $Mode }
        return
    }

    Write-Status "Applying the $Mode update profile. Windows security updates will be blocked." Warning
    Set-RegistryValue $script:UpdatePolicyPath 'NoAutoUpdate' 1
    Disable-ServiceSafely 'wuauserv'
    Disable-ServiceSafely 'UsoSvc'

    $tasks = $script:StandardUpdateTasks
    if ($Mode -eq 'Lockdown') {
        Disable-ServiceSafely 'WaaSMedicSvc'
        $tasks = $script:LockdownUpdateTasks
    }
    $tasks | ForEach-Object { Disable-TaskByFullPath $_ }
    if (-not $WhatIfPreference) { Test-UpdatePolicy $Mode }
    Write-Status "$Mode update profile complete. Review warnings above for protected items Windows refused to change." Success
}

function Invoke-Privacy {
    Write-Status 'Disabling telemetry, advertising ID, and consumer suggestions.'
    Set-RegistryValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' 'AllowTelemetry' 0
    Set-RegistryValue 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo' 'Enabled' 0
    Set-RegistryValue 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'ContentDeliveryAllowed' 0
    Set-RegistryValue 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'SubscribedContent-338388Enabled' 0
    Set-RegistryValue 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Privacy' 'TailoredExperiencesWithDiagnosticDataEnabled' 0
    Set-RegistryValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' 'DisableWindowsConsumerFeatures' 1
    Write-Status 'Privacy module complete.' Success
}

function Invoke-AI {
    Write-Status 'Disabling Copilot, Recall policy, and AI suggestions.'
    Set-RegistryValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'ShowCopilotButton' 0
    Set-RegistryValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot' 'TurnOffWindowsCopilot' 1
    Set-RegistryValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI' 'DisableAIDataAnalysis' 1
    Set-RegistryValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI' 'AllowRecallEnablement' 0
    Write-Status 'AI module complete. Existing app features may require separate app settings.' Success
}

function Invoke-UX {
    Write-Status 'Restoring classic context menu and disabling web search suggestions.'
    Set-RegistryValue 'HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32' '(Default)' '' ([Microsoft.Win32.RegistryValueKind]::String)
    Set-RegistryValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search' 'BingSearchEnabled' 0
    Set-RegistryValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search' 'CortanaConsent' 0
    Write-Status 'UX module complete. Restart Explorer to see the context-menu change.' Success
}

function Invoke-Bloatware {
    $packages = @('Microsoft.549981C3F5F10', 'Microsoft.XboxApp', 'Microsoft.XboxGamingOverlay', 'Microsoft.GetHelp', 'Microsoft.Getstarted', 'Microsoft.MicrosoftOfficeHub', 'Microsoft.People', 'Microsoft.SkypeApp', 'Microsoft.YourPhone', 'Microsoft.ZuneMusic', 'Microsoft.ZuneVideo')
    Write-Status 'Removing selected consumer Appx packages for the current user.'
    foreach ($name in $packages) {
        $found = Get-AppxPackage -Name $name -ErrorAction SilentlyContinue
        foreach ($package in @($found)) {
            if ($PSCmdlet.ShouldProcess($package.Name, 'Uninstall Appx package')) {
                Remove-AppxPackage -Package $package.PackageFullName
                Write-Status "Removed $($package.Name)" Success
            }
        }
    }
    Write-Status 'Bloatware module complete. System-critical packages were intentionally excluded.' Success
}

function Restore-Changes {
    Load-Backup
    if ($script:Backup.Count -eq 0) { Write-Status 'No fuckWin backup was found.' Warning; return }
    foreach ($entry in $script:Backup) {
        if ($entry.Type -eq 'Registry') {
            if ($entry.Exists) {
                if ($PSCmdlet.ShouldProcess("$($entry.Path)\$($entry.Name)", 'Restore registry value')) {
                    New-Item -Path $entry.Path -Force | Out-Null
                    if ($entry.Name -eq '(Default)') {
                        Set-Item -Path $entry.Path -Value $entry.Value
                    } else {
                        $kind = [Microsoft.Win32.RegistryValueKind]::$($entry.Kind)
                        New-ItemProperty -Path $entry.Path -Name $entry.Name -Value $entry.Value -PropertyType $kind -Force | Out-Null
                    }
                }
            } elseif ($PSCmdlet.ShouldProcess("$($entry.Path)\$($entry.Name)", 'Remove created registry value')) {
                if ($entry.Name -eq '(Default)') {
                    Set-Item -Path $entry.Path -Value $null -ErrorAction SilentlyContinue
                } else {
                    Remove-ItemProperty -Path $entry.Path -Name $entry.Name -Force -ErrorAction SilentlyContinue
                }
            }
        } elseif ($entry.Type -eq 'Service') {
            if ($PSCmdlet.ShouldProcess($entry.Path, 'Restore service startup mode')) {
                try {
                    $startupType = if ($entry.StartMode -eq 'Auto') { 'Automatic' } else { $entry.StartMode }
                    Set-Service -Name $entry.Path -StartupType $startupType -ErrorAction Stop
                    if ($entry.State -eq 'Running') { Start-Service -Name $entry.Path -ErrorAction Stop }
                    Write-Status "Service restored: $($entry.Path)" Success
                } catch {
                    Write-Status "Could not restore service $($entry.Path): $($_.Exception.Message)" Warning
                }
            }
        } elseif ($entry.Type -eq 'Task' -and $entry.Enabled) {
            if ($PSCmdlet.ShouldProcess("$($entry.Path)$($entry.Name)", 'Enable scheduled task')) {
                try {
                    Enable-ScheduledTask -TaskPath $entry.Path -TaskName $entry.Name -ErrorAction Stop | Out-Null
                    Write-Status "Task restored: $($entry.Path)$($entry.Name)" Success
                } catch {
                    Write-Status "Could not restore task $($entry.Path)$($entry.Name): $($_.Exception.Message)" Warning
                }
            }
        }
    }
    Write-Status 'Restoration attempted for every backup entry. Review warnings above. Appx packages are not reinstalled.' Success
}

function Show-Audit {
    Write-Host "`nfuckWin audit" -ForegroundColor Cyan
    Get-CimInstance Win32_OperatingSystem | Select-Object Caption, Version, BuildNumber | Format-List

    Write-Host 'Update policy' -ForegroundColor Cyan
    [pscustomobject]@{
        NoAutoUpdate = Get-RegistryValueOrNull $script:UpdatePolicyPath 'NoAutoUpdate'
        AUOptions = Get-RegistryValueOrNull $script:UpdatePolicyPath 'AUOptions'
        NoAutoRebootWithLoggedOnUsers = Get-RegistryValueOrNull $script:UpdatePolicyPath 'NoAutoRebootWithLoggedOnUsers'
    } | Format-List

    Write-Host 'Update services' -ForegroundColor Cyan
    $services = foreach ($name in 'wuauserv','UsoSvc','WaaSMedicSvc') {
        $service = Get-Service $name -ErrorAction SilentlyContinue
        if ($service) {
            $cim = Get-CimInstance Win32_Service -Filter "Name='$name'"
            [pscustomobject]@{ Name = $name; Status = $service.Status; StartMode = $cim.StartMode }
        }
    }
    $services | Format-Table -AutoSize

    Write-Host 'Update tasks' -ForegroundColor Cyan
    $tasks = foreach ($fullPath in $script:LockdownUpdateTasks) {
        $separator = $fullPath.LastIndexOf('\')
        $taskPath = $fullPath.Substring(0, $separator + 1)
        $taskName = $fullPath.Substring($separator + 1)
        $task = Get-ScheduledTask -TaskPath $taskPath -TaskName $taskName -ErrorAction SilentlyContinue
        [pscustomobject]@{ Task = $fullPath; State = if ($task) { $task.State } else { 'NotFound' }; Enabled = if ($task) { $task.Settings.Enabled } else { $null } }
    }
    $tasks | Format-Table -AutoSize

    if (Test-Path $script:BackupFile) {
        Write-Status "Backup available at $script:BackupFile" Info
    } else {
        Write-Status 'No fuckWin backup exists.' Info
    }
}

function Show-Menu {
    Write-Host "`nfuckWin - Windows control panel`n" -ForegroundColor Cyan
    Write-Host '1. Updates  2. Privacy  3. AI  4. Classic UX  5. Bloatware  6. All  7. Restore  8. Audit  0. Exit'
    switch (Read-Host 'Choose a module') {
        '1' {
            $selectedMode = Read-Host 'Update mode: Notify, Disable, or Lockdown (default: Notify)'
            if ([string]::IsNullOrWhiteSpace($selectedMode)) { $selectedMode = 'Notify' }
            if ($selectedMode -notin @('Notify','Disable','Lockdown')) { Write-Status 'Unknown update mode.' Warning; return }
            Invoke-Updates $selectedMode
        }
        '2' { Invoke-Privacy }; '3' { Invoke-AI }; '4' { Invoke-UX }; '5' { Invoke-Bloatware }
        '6' { Invoke-Updates $UpdateMode; Invoke-Privacy; Invoke-AI; Invoke-UX; Invoke-Bloatware }
        '7' { Restore-Changes }; '8' { Show-Audit }; '0' { return }
        default { Write-Status 'Unknown selection.' Warning }
    }
}

try {
    if ($Action -eq 'Audit') { Show-Audit; exit 0 }
    Assert-Windows
    Load-Backup
    if (-not $Force -and $Action -in @('All','Updates','Privacy','AI','UX','Bloatware','Restore')) {
        $description = if ($Action -in @('All','Updates')) { "$Action with update mode '$UpdateMode'" } else { $Action }
        $prompt = if ($UpdateMode -eq 'Lockdown' -and $Action -in @('All','Updates')) {
            "Run '$description'? Store, optional features, drivers, and manual update checks may stop working. Type LOCKDOWN to continue"
        } else {
            "Run '$description'? This may change system settings. Type YES to continue"
        }
        $expected = if ($UpdateMode -eq 'Lockdown' -and $Action -in @('All','Updates')) { 'LOCKDOWN' } else { 'YES' }
        if ((Read-Host $prompt) -cne $expected) { Write-Status 'Cancelled.' Warning; exit 0 }
    }
    switch ($Action) {
        'Menu' { Show-Menu }
        'All' { Invoke-Updates $UpdateMode; Invoke-Privacy; Invoke-AI; Invoke-UX; Invoke-Bloatware }
        'Updates' { Invoke-Updates $UpdateMode }; 'Privacy' { Invoke-Privacy }; 'AI' { Invoke-AI }; 'UX' { Invoke-UX }
        'Bloatware' { Invoke-Bloatware }; 'Restore' { Restore-Changes }
    }
    if (-not $WhatIfPreference) { Save-Backup }
} catch {
    Write-Status $_.Exception.Message Error
    exit 1
}
