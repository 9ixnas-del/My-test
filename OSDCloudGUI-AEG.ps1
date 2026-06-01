function Start-OSDCloudGUI {
    [CmdletBinding()]
    param (
        [Alias('Brand')]
        [System.String]
        $BrandName = "AEG WORLDWIDE",

        [Alias('Color')]
        [System.String]
        $BrandColor = "#1b59e8",

        [System.String]
        $ComputerManufacturer = (Get-MyComputerManufacturer -Brief),

        [System.String]
        $ComputerProduct = (Get-MyComputerProduct),

        [System.Management.Automation.SwitchParameter]
        $v2
    )

    $global:OSDCloudHotfix = $false

    if ($Hotfix) {
        $global:OSDCloudHotfix = $true
        $HotfixUrl = 'https://raw.githubusercontent.com/OSDeploy/OSD/master/cloud/hotfix/osdcloudgui.ps1'
        $Result = Invoke-WebRequest -Uri $HotfixUrl -UseBasicParsing -Method Head
        if ($Result.StatusCode -eq 200) {
            Invoke-Expression (Invoke-RestMethod -Uri $HotfixUrl -UseBasicParsing)
        }
        else {
            Write-Warning "[$(Get-Date -format G)] [$($MyInvocation.MyCommand.Name)] OSDCloud failed to reach the Hotfix URL"
            Write-Warning $HotfixUrl
        }
    }

    if ($v2) {
        $DriverPacks = Get-OSDCloudDriverPacks | Where-Object { $_.Manufacturer -eq $ComputerManufacturer }
    }
    else {
        $DriverPacks = Get-OSDCloudDriverPacks
    }

    $Global:OSDCloudGUI = $null
    $Global:OSDCloudGUI = [ordered]@{
        Function                    = [System.String]'Start-OSDCloudGUI'
        LaunchMethod                = [System.String]'OSDCloudGUI'

        AutomateConfiguration       = $null
        AutomateJsonFile            = $null

        BrandName                   = [System.String]$BrandName
        BrandColor                  = [System.String]$BrandColor

        ComputerManufacturer        = [System.String]$ComputerManufacturer
        ComputerModel               = [System.String](Get-MyComputerModel -Brief)
        ComputerProduct             = [System.String]$ComputerProduct

        DriverPack                  = $null
        DriverPacks                 = [array]$DriverPacks
        DriverPackName              = $null

        IsOnBattery                 = [System.Boolean](Get-OSDGather -Property IsOnBattery)

        OSActivation                = [System.String]$Global:OSDModuleResource.OSDCloud.Default.Activation
        OSEdition                   = [System.String]$Global:OSDModuleResource.OSDCloud.Default.Edition
        OSLanguage                  = [System.String]$Global:OSDModuleResource.OSDCloud.Default.Language
        OSImageIndex                = [System.Int32]$Global:OSDModuleResource.OSDCloud.Default.ImageIndex
        OSName                      = [System.String]$Global:OSDModuleResource.OSDCloud.Default.Name
        OSReleaseID                 = [System.String]$Global:OSDModuleResource.OSDCloud.Default.ReleaseID
        OSVersion                   = [System.String]$Global:OSDModuleResource.OSDCloud.Default.Version

        OSActivationValues          = [array]$Global:OSDModuleResource.OSDCloud.Values.Activation
        OSEditionValues             = [array]$Global:OSDModuleResource.OSDCloud.Values.Edition
        OSLanguageValues            = [array]$Global:OSDModuleResource.OSDCloud.Values.Language
        OSNameValues                = [array]$Global:OSDModuleResource.OSDCloud.Values.Name
        OSNameARM64Values           = [array]$Global:OSDModuleResource.OSDCloud.Values.NameARM64
        OSReleaseIDValues           = [array]$Global:OSDModuleResource.OSDCloud.Values.ReleaseID
        OSVersionValues             = [array]$Global:OSDModuleResource.OSDCloud.Values.Version

        captureScreenshots          = $false
        ClearDiskConfirm            = $true
        restartComputer             = $true

        updateDiskDrivers           = $true
        updateFirmware              = $true
        updateNetworkDrivers        = $true
        updateSCSIDrivers           = $true
        SyncMSUpCatDriverUSB        = $true

        OEMActivation               = $true
        WindowsUpdate               = $true
        WindowsUpdateDrivers        = $true
        WindowsDefenderUpdate       = $true

        HPIAALL                     = $false
        HPIADrivers                 = $false
        HPIAFirmware                = $false
        HPIASoftware                = $false
        HPTPMUpdate                 = $false
        HPBIOSUpdate                = $false

        TimeStart                   = [datetime](Get-Date)
    }

    Write-Host -ForegroundColor DarkGray "[$(Get-Date -format G)] Exporting default configuration to $env:Temp\Start-OSDCloudGUI.json"
    $Global:OSDCloudGUI | ConvertTo-Json -Depth 10 | Out-File -FilePath "$env:TEMP\Start-OSDCloudGUI.json" -Force

    $Global:OSDCloudGUI.AutomateJsonFile = Get-PSDrive -PSProvider FileSystem | Where-Object {$_.Name -ne 'C'} | ForEach-Object {
        Get-ChildItem "$($_.Root)OSDCloud\Automate" -Include "Start-OSDCloudGUI.json" -File -Force -Recurse -ErrorAction Ignore
    }
    if ($Global:OSDCloudGUI.AutomateJsonFile) {
        foreach ($Item in $Global:OSDCloudGUI.AutomateJsonFile) {
            Write-Host -ForegroundColor DarkGray "[$(Get-Date -format G)] $($Item.FullName)"
            $Global:OSDCloudGUI.AutomateConfiguration = Get-Content -Path "$($Item.FullName)" -Raw | ConvertFrom-Json -ErrorAction "Stop" | ConvertTo-Hashtable
        }
    }
    if ($Global:OSDCloudGUI.AutomateConfiguration) {
        foreach ($Key in $Global:OSDCloudGUI.AutomateConfiguration.Keys) {
            $Global:OSDCloudGUI.$Key = $Global:OSDCloudGUI.AutomateConfiguration.$Key
        }
    }

    # AEG WORLDWIDE Branding
    $Global:OSDCloudGuiBranding = @{
        Title = "AEG WORLDWIDE"
        Color = "#D4A017"
    }

    $Global:OSDCloudGUI.DriverPack = Get-OSDCloudDriverPack -Product $ComputerProduct -OSVersion $Global:OSDCloudGUI.OSVersion -OSReleaseID $Global:OSDCloudGUI.OSReleaseID
    if ($Global:OSDCloudGUI.DriverPack) {
        $Global:OSDCloudGUI.DriverPackName = $Global:OSDCloudGUI.DriverPack.Name
    }

    Write-Host -ForegroundColor Green "OSDCloudGUI Configuration"
    $Global:OSDCloudGUI | Out-Host

    # TPM Check
    try {
        $Win32Tpm = Get-CimInstance -Namespace "ROOT\cimv2\Security\MicrosoftTpm" -ClassName Win32_Tpm
        if ($null -eq $Win32Tpm) {
            Write-Host -ForegroundColor Yellow "[$(Get-Date -format G)] TPM: Not Supported"
            Write-Host -ForegroundColor Yellow "[$(Get-Date -format G)] Autopilot: Not Supported"
            Start-Sleep -Seconds 5
        }
        elseif ($Win32Tpm.SpecVersion) {
            $majorVersion = $Win32Tpm.SpecVersion.Split(",")[0] -as [int]
            if ($majorVersion -lt 2) {
                Write-Host -ForegroundColor Yellow "[$(Get-Date -format G)] TPM: Version is less than 2.0"
                Write-Host -ForegroundColor Yellow "[$(Get-Date -format G)] Autopilot: Not Supported"
                Start-Sleep -Seconds 5
            }
            else {
                Write-Host -ForegroundColor Green "[$(Get-Date -format G)] TPM 2.0: Supported"
                Write-Host -ForegroundColor Green "[$(Get-Date -format G)] Autopilot: Supported"
            }
        }
        else {
            Write-Host -ForegroundColor Yellow "[$(Get-Date -format G)] TPM: Not Supported"
            Write-Host -ForegroundColor Yellow "[$(Get-Date -format G)] Autopilot: Not Supported"
            Start-Sleep -Seconds 5
        }
    }
    catch {}

    # Launch GUI
    & "$($MyInvocation.MyCommand.Module.ModuleBase)\Projects\OSDCloudGUI\MainWindow.ps1"
    Start-Sleep -Seconds 2

    # Auto-cleanup OSDCloud folder at first boot
    $CleanupScript = @'
if (Test-Path "C:\OSDCloud") {
    Remove-Item -Path "C:\OSDCloud" -Recurse -Force -ErrorAction SilentlyContinue
}
Unregister-ScheduledTask -TaskName "OSDCloud-Cleanup" -Confirm:$false -ErrorAction SilentlyContinue
'@

    $SetupScriptsPath = "C:\Windows\Setup\Scripts"
    New-Item -Path $SetupScriptsPath -ItemType Directory -Force | Out-Null
    $CleanupScript | Out-File -FilePath "$SetupScriptsPath\OSDCloudCleanup.ps1" -Encoding utf8 -Force

    $Action  = New-ScheduledTaskAction -Execute "PowerShell.exe" `
               -Argument "-NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File C:\Windows\Setup\Scripts\OSDCloudCleanup.ps1"
    $Trigger = New-ScheduledTaskTrigger -AtStartup
    Register-ScheduledTask -TaskName "OSDCloud-Cleanup" -Action $Action -Trigger $Trigger -RunLevel Highest -Force
}