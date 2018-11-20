<#
.SYNOPSIS
    Invoke BIOS Update process.

.DESCRIPTION
    This script will invoke a Thunderbolt Firmware update process for a varity of manufactures. This process should be ran in WINPE.

.PARAMETER LogFileName
    Set the name of the log file produced by the flash utility.

.EXAMPLE
    

.NOTES
    FileName:    Update-TBFirmware.ps1
    Author:      Richard tracy
    Contact:     richard.j.tracy@gmail.com
    Created:     2018-08-24
    Inspired:    Anton Romanyuk,Nickolaj Andersen
    
    Version history:
    1.0.0 - (2018-08-24) Script created
#>

##*===========================================================================
##* FUNCTIONS
##*===========================================================================
function Write-LogEntry {
    param(
        [parameter(Mandatory=$true, HelpMessage="Value added to the log file.")]
        [ValidateNotNullOrEmpty()]
        [string]$Value,

        [parameter(Mandatory=$false)]
        [ValidateSet(0,1,2,3)]
        [int16]$Severity,

        [parameter(Mandatory=$false, HelpMessage="Name of the log file that the entry will written to.")]
        [ValidateNotNullOrEmpty()]
        [string]$fileArgName = $LogFilePath,

        [parameter(Mandatory=$false)]
        [switch]$Outhost
    )
    
    [string]$LogTime = (Get-Date -Format 'HH:mm:ss.fff').ToString()
	[string]$LogDate = (Get-Date -Format 'MM-dd-yyyy').ToString()
	[int32]$script:LogTimeZoneBias = [timezone]::CurrentTimeZone.GetUtcOffset([datetime]::Now).TotalMinutes
	[string]$LogTimePlusBias = $LogTime + $script:LogTimeZoneBias
    #  Get the file name of the source script

    Try {
	    If ($script:MyInvocation.Value.ScriptName) {
		    [string]$ScriptSource = Split-Path -Path $script:MyInvocation.Value.ScriptName -Leaf -ErrorAction 'Stop'
	    }
	    Else {
		    [string]$ScriptSource = Split-Path -Path $script:MyInvocation.MyCommand.Definition -Leaf -ErrorAction 'Stop'
	    }
    }
    Catch {
	    $ScriptSource = ''
    }
    
    
    If(!$Severity){$Severity = 1}
    $LogFormat = "<![LOG[$Value]LOG]!>" + "<time=`"$LogTimePlusBias`" " + "date=`"$LogDate`" " + "component=`"$ScriptSource`" " + "context=`"$([Security.Principal.WindowsIdentity]::GetCurrent().Name)`" " + "type=`"$Severity`" " + "thread=`"$PID`" " + "file=`"$ScriptSource`">"
    
    # Add value to log file
    try {
        Out-File -InputObject $LogFormat -Append -NoClobber -Encoding Default -FilePath $LogFilePath -ErrorAction Stop
    }
    catch [System.Exception] {
        Write-LogEntry -Message "Unable to append log entry to $LogFilePath file"
    }
    If($Outhost){
        Switch($Severity){
            0       {Write-Host $Value -ForegroundColor Gray}
            1       {Write-Host $Value}
            2       {Write-Warning $Value}
            3       {Write-Host $Value -ForegroundColor Red}
            default {Write-Host $Value}
        }
    }
}

##*===========================================================================
##* VARIABLES
##*===========================================================================
## Instead fo using $PSScriptRoot variable, use the custom InvocationInfo for ISE runs
If (Test-Path -LiteralPath 'variable:HostInvocation') { $InvocationInfo = $HostInvocation } Else { $InvocationInfo = $MyInvocation }
[string]$scriptDirectory = Split-Path -Path $InvocationInfo.MyCommand.Definition -Parent
[string]$scriptPath = $InvocationInfo.MyCommand.Definition
[string]$scriptName = [IO.Path]::GetFileNameWithoutExtension($scriptPath)

#Create Paths
$TBPath = Join-Path $scriptDirectory -ChildPath TB16
$TempPath = Join-Path $scriptDirectory -ChildPath Temp
$ToolsPath = Join-Path $scriptDirectory -ChildPath Tools

Try
{
	$tsenv = New-Object -COMObject Microsoft.SMS.TSEnvironment
	#$logPath = $tsenv.Value("LogPath")
    $LogPath = $tsenv.Value("_SMSTSLogPath")
    $tsenv.Value("SMSTS_TBUpdate") = "True"
    $inPE = $tsenv.Value("_SMSTSInWinPE")
}
Catch
{
	Write-Warning "TS environment not detected. Assuming stand-alone mode."
	$LogPath = $env:TEMP
}
[string]$fileArgName = $scriptName +'.log'
$LogFilePath = Join-Path -Path $LogPath -ChildPath $fileArgName

##*===========================================================================
##* MAIN
##*===========================================================================
#Get Supported Models from File
#https://www.dell.com/en-us/work/shop/dell-business-thunderbolt-dock-tb16-with-240w-adapter/apd/452-bcnu/pc-accessories
[array]$SupportedModels = Get-Content ModelsSupported.txt -ErrorAction SilentlyContinue

#Create Model Variable
$ComputerModel = Get-WmiObject -Class Win32_computersystem | Select-Object -ExpandProperty Model

#determine if model support thunderbolt
Write-LogEntry ("Comparing this model [{0}] with supported model list [{1}]" -f $ComputerModel,"ModelsSupported.txt") -Outhost
Foreach ($SupportedModel in $SupportedModels){
    If($ComputerModel -eq $SupportedModel){
    
        #Get Thunderbolt Firmware File Name
        $TBFirmwareFileName = Get-ChildItem $TBPath -Recurse -Filter *.exe | Where-Object {$_.Name -match 'Fw' -or $_.Name -match 'Firmware'} | Select -First 1
        
        If($TBFirmwareFileName){
            #Copy TB Installer to the root of the package - the Flash64W didn't like when I left it in the Computer Model folder, because it has spaces. (Yes, I tried qoutes and stuff)
            Copy-Item $TBFirmwareFileName.FullName -Destination $TempPath -ErrorAction SilentlyContinue
        
            #build temp path
            $FMWFilePath = Join-Path -Path $TempPath -ChildPath $TBFirmwareFileName.Name

            #Get TB File Name (No Extension, used to create Log File)
            $TBLogFileName = Get-ChildItem $FMWFilePath -Verbose | Select -ExpandProperty BaseName
            $TBLogFileName = $TBLogFileName + ".log"

            #Get TB Password from File
            $BiosPassword = Get-Content .\BIOSPassword.txt -ErrorAction SilentlyContinue

            #Set Command Arguments for TB Update
            If($BiosPassword){
                $AddArgs = "/s /p=$TBPassword /l=$LogPath\$TBLogFileName"
            }
            else {
                $AddArgs = "/s /l=$LogPath\$TBLogFileName" 
            }
            
            if ($tsenv -and $inPE) {
                Write-LogEntry "TaskSequence is running in Windows Preinstallation Environment (PE)" -Outhost
            }
            Else{
                Write-LogEntry "TaskSequence is running in Windows Environment" -Outhost

                # Detect Bitlocker Status
		        $OSVolumeEncypted = if ((Manage-Bde -Status C:) -match "Protection On") { Write-Output $true } else { Write-Output $false }
		
		        # Supend Bitlocker if $OSVolumeEncypted is $true
		        if ($OSVolumeEncypted -eq $true) {
			        Write-LogEntry "Suspending BitLocker protected volume: C:" -Outhost
			        Manage-Bde -Protectors -Disable C:
		        }
                
            }

            #execute flashing
            If($BiosPassword){$protectedArgs = $($AddArgs -replace $BiosPassword, "<Password Removed>")}Else{$protectedArgs = $AddArgs}
            Write-LogEntry "RUNNING COMMAND : $FMWFilePath $fileArg $AddArgs" -Outhost
            $Process = Start-Process $FMWFilePath -ArgumentList $AddArgs -PassThru -wait

            #Creates and Set TS Variable to be used to run additional steps if reboot required.
            switch($process.ExitCode){
                0   {
                        Write-LogEntry ("Thunderbolt Firmware updated succesfully") -Outhost
                        If($tsenv){$tsenv.Value("SMSTS_TBRebootRequired") = "False"}
                        If($tsenv){$tsenv.Value("SMSTS_TBBatteryCharge") = "False"}
                    }

                2   {
                        Write-LogEntry ("Thunderbolt 16 updated succesfully. A reboot is required") -Outhost
                        If($tsenv){$tsenv.Value("SMSTS_TBRebootRequired") = "True"}
                    }

                10  {
                        Write-LogEntry ("Thunderbolt 16 cannot update because it requires an earlier release first") -Outhost
                        Write-LogEntry ("OR Thunderbolt 16 cannot update because the battery is missing or not charged") -Outhost
                        Write-LogEntry ("OR Thunderbolt 16 update was cancelled") -Outhost
                        If($tsenv){$tsenv.Value("SMSTS_TBBatteryCharge") = "True"}
                    }
            }
        
            Start-Sleep 10
            #remove exe after completed
            Remove-Item $TBFilePath -Force -ErrorAction SilentlyContinue

            If($process.ExitCode -eq 2){
                Write-LogEntry ("Since Thunderbolt 16 firmware updated correctly and requires a reboot, stopping loop process to install additional Thunderbolt software until later") -Outhost
                Exit
            }
        }
        Else{
            Write-LogEntry ("No Firmware Found in folder: {0}, skipping..." -f $TBPath) -Outhost
        }

    }
    Else{
        Write-LogEntry ("Model is not a [{0}]. Thunderbolt Docking Station is not supported, skipping installation" -f $SupportedModel) -Outhost
    }
}

