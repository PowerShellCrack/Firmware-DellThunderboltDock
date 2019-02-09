<#
.SYNOPSIS
    Check Thnderbolt model support from list.

.DESCRIPTION
    This script adds driver group to TS driver injection. This process should be ran in WINPE before driver injection.

.PARAMETER LogFileName
    Set the name of the log file produced by the firmware.

.EXAMPLE
    

.NOTES
    FileName:    Check-TBSupportedModels.ps1
    Author:      Richard tracy
    Contact:     richard.j.tracy@gmail.com
    Created:     2018-08-24
    
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
        [Alias("Message")]
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
        Write-Host "Unable to append log entry to $LogFilePath file" -ForegroundColor Red
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

Try
{
	$tsenv = New-Object -COMObject Microsoft.SMS.TSEnvironment
	#$logPath = $tsenv.Value("LogPath")
    $LogPath = $tsenv.Value("_SMSTSLogPath")
    $tsenv.Value("SMSTS_TBSupported") = "False"
    $inPE = $tsenv.Value("_SMSTSInWinPE")
}
Catch
{
	Write-Warning "TS environment not detected. Assuming stand-alone mode."
	$LogPath = $env:TEMP
}

[string]$FileName = $scriptName +'.log'
$LogFilePath = Join-Path -Path $LogPath -ChildPath $FileName

##*===========================================================================
##* MAIN
##*===========================================================================
#Get Supported Models from File
#https://www.dell.com/en-us/work/shop/dell-business-thunderbolt-dock-tb16-with-240w-adapter/apd/452-bcnu/pc-accessories
[array]$SupportedModels = Get-Content ModelsSupported.txt -ErrorAction SilentlyContinue

#Create Model Variable
$ComputerModel = Get-WmiObject -Class Win32_computersystem | Select-Object -ExpandProperty Model

if ($tsenv -and $inPE) { 
    Write-LogEntry "Script is running in Windows Preinstallation Environment (PE)" -Outhost 
}
Else{
    Write-LogEntry "Script is running in Windows Environment" -Outhost          
}

#determine if model support thunderbolt
Write-LogEntry ("Comparing this model [{0}] with supported model list [{1}]" -f $ComputerModel,"ModelsSupported.txt") -Outhost 
Foreach ($SupportedModel in $SupportedModels){
    If($ComputerModel -eq $SupportedModel)
    {
        $tsenv.Value("SMSTS_TBSupported") = "True"  
    }
    Else{
        Write-LogEntry ("Model is not a [{0}]. Thunderbolt Docking Station is not supported, skipping drivers..." -f $SupportedModel) -Outhost
    }
}