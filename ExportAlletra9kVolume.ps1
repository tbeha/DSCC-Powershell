
<#

Powershell Toolkit test program

Check the Invoke-ConvertHost Routine.

Invoke-ConvertHost is located in the scripts/HostUtilities.ps1 

Datagroup requested the following daily Tasks for their automation:
	Required Task						Powershell Toolkit Function to use
•	Create Hosts						New-DSCCHost
•	Add Hosts to Hostgroups				New-DSCCHostGroup; Set-DSCCHostGroup; Get-DSCCHostGroup
•	Move Hosts to other Hostgroups		Set-DSCCHostGroup; Get-DSCCHostGroup 
•	Create Volumesets					New-VolumeSet
•	Add Volumes to Volumeset			Set-DSCCVolumeSet; Get-DSCCVolumeSet 
•	Export a Volume						Get-DSCCHostGroup; Get-DSCCVolume 
•	Delete Volume						Remove-DSCCVolume	
•	Show exports of Volume				Get-DSCCVolume
•	Show exports for Hostgroup			Get-DSCCHostGroup
•	Show Capacity						Get-DSCCStorageSystem
•	Show Warning/Errors

#>

Import-Module .\HPEDSCC.psd1 -SkipEditionCheck

$systemid =@{
	'p630' = 'CZ29420H95';
	'p650' = 'CZ294112CB';
	'a6030' = '00444f5e31fd5cb296000000000000000000000001'
}

Function Write-Log()
{
 param
    (
    [Parameter(Mandatory=$true, Position=0)]
    [string] $message,
    [Parameter(Mandatory=$false, Position=1)]
    [string] $writeToConsole=$false
    )
 
    Try {
        #Get the current date
        $LogDate = (Get-Date).tostring("yyyyMMdd")

        #Frame Log File with Current Directory and date
        $CurrentDir = (pwd).Path
        $LogFile = $CurrentDir + "\logs\HostMigration_" + $LogDate + ".log"
 
        #Add Content to the Log File
        $TimeStamp = (Get-Date).toString("dd/MM/yyyy HH:mm:ss:fff tt")
        $Line = "$TimeStamp - $message"
        if ($writeToConsole -eq $true)
        {
            Write-Host $message
        }
        Add-content -Path $Logfile -Value $Line
     }
    Catch {
    }
}

function Export-DSCCVolume{

	<#
		Export vlun for volume identified by {id} from Primera / Alletra 9K identified by {systemId}

		PATH PARAMETERS
		systemId	required		string		Example: 7CE751P312		systemId of the device-type1 storage system
		id			required		string		Example: a7c4e6593f51d0b98f0e40d7e6df04fd		UID(volumeuid) of the storage system

		REQUEST BODY SCHEMA: application/json
		autoLun			boolean or null						Auto Lun
		hostGroupIds	Array of strings or null or null	HostGroups
		maxAutoLun		integer or null <int64>				Number of volumes.
		noVcn			boolean or null						No VCN
		override		boolean or null						Override
		position		string or null						Position
		proximity		string	Enum: "PRIMARY" "SECONDARY" "ALL"	Host proximity setting for Active Peer Persistence configuration. Supported values are - PRIMARY, SECONDARY and ALL
		
		
		Configure access for volume identified by {volumeId} from Nimble / Alletra 6K identified by {systemId}

		PATH PARAMETERS
		systemId	required	string		Example: 2a0df0fe6f7dc7bb16000000000000000000004817		ID of the storage system
		volumeId	required	string		Example: 2a0df0fe6f7dc7bb16000000000000000000000007		Identifier of volume. A 42 digit hexadecimal number.

		REQUEST BODY SCHEMA: application/json
		hostGroups			Array of strings or null or null		list of hostGroups

	#>

	param(
		[Parameter(Mandatory=$true)] [string] $VolumeId,
		[Parameter(Mandatory=$true)] [string] $SystemId,
		[Parameter(Mandatory=$true)] [array] $HostGroupIds, 
		[Parameter] [string]  $Proximity,
		[Parameter] [string]  $Override,
		[Parameter] [Boolean] $AutoLun,
		[Parameter] [string]  $Position,
		[Parameter] [Boolean] $NoVcn
	)

	# Get the system URI
	$system = Get-DSCCStorageSystem -SystemId $SystemId
	$systemUri = system.resourceUri
	$Uri = $Base + $systemUri '/volumes/' + $VolumeId + '/export'
	
	$MyBody = @{}
	if($AutoLun)	{ $MyBody = $MyBody + @{'autoLun'   = $AutoLun} }
	if($Proximity)	{ $MyBody = $MyBody + @{'proximity' = $Proximity} }
	if($Override)	{ $MyBody = $MyBody + @{'override'  = $Override} }
	if($Position)	{ $MyBody = $MyBody + @{'position'  = $Position} }
	if($NoVcn)		{ $MyBody = $MyBody + @{'noVcn' 	= $NoVcn} }
	$MyBody = $MyBody + @{'hostGroupIds' = $HostGroupIds} 	

	return Invoke-RestMethod -Uri $Uri -Method 'POST' -Body ($MyBody | ConvertTo-Json) -Headers $MyHeaders -ContentType 'application/json'
}

function Unexport-DSCCVolume{

	param(
		[Parameter(Mandatory=$true)] [string] $VolumeId,
		[Parameter(Mandatory=$true)] [array] $HostGroupIds, 
		[Parameter(Mandatory=$true)] [string] $SystemId
	)

	$MyBody = @{}
	$MyBody = $MyBody + @{'hostGroupIds' = $HostGroupIds} 
	# Get the system URI
	$storageArray = Get-DSCCStorageSystem -SystemId $SystemId
	$systemUri = $storageArray.resourceUri	
	$Uri = $Base + $systemUri + '/volumes/' + $VolumeId + '/unexport'

	return Invoke-RestMethod -Uri $Uri -Method 'POST' -Body ($MyBody | ConvertTo-Json) -Headers $MyHeaders -ContentType 'application/json'
}

$Client_ID = ''  
$Client_Secret = ''

Connect-DSCC -Client_Id $Client_ID -Client_Secret $Client_Secret -GreenlakeType EU #-Verbose -AutoRenew

# Create a new Host

$initiator1 = @{
	address = "10:00:be:d8:0d:50:01:ca";
	name = "syi5he21b5p1";
	protocol = 'FC';
	ipAddress = "10.1.40.21"
}
$initiator2 = @{
	address = "10:00:be:d8:0d:50:01:cc";
	name = "syi5he21b5p2";
	protocol = 'FC';
	ipAddress = "10.1.40.21"
}
$initiators =@( $initiator1, $initiator2 )

$Response = New-DSCCHost -comment "DSCC API Created - Thomas Beha" -contact "thomas.beha@hpe.com" -fqdn "syi5he21b5.demo.local" `
				-initiatorsToCreate $initiators -ipAddress "10.1.40.21" -subnet "255.255.255.0" -location "CTC BBN" `
				-model "SY480Gen10" -name "SYI5HE21B5" -operatingSystem 'VMware (ESXi)' -persona 'VMware' -protocol 'FC' -userCreated $true
Write-Log -message ("Host SYI5HE21B5 Creation Task: " + $Response.taskUri) -writeToConsole $true
WaitForTaskToComplete($Response.taskUri)
Write-Log -message "Host SYI5HE21B5 Creation Task Completed" -writeToConsole $true

$host1 = Get-DSCCHost | Where-Object {$_.name -eq "SYI5HE21B5"}

# Create a Host Group

$hostIds = @( $host1.id )
$Response = New-DSCCHostGroup -DeviceType1 -name "SYI5HE21B5" -SystemId $systemid['p630'] -comment "DSCC API Created - Thomas Beha" -hostIds $hostIds -userCreated $true
Write-Log -message ("Host Group SYI5HE21B5 Creation Task: " + $Response.taskUri) -writeToConsole $true
WaitForTaskToComplete($Response.taskUri)
Write-Log -message "Host Group SYI5HE21B5 Creation Task Completed" -writeToConsole $true
$hostgroup = Get-DSCCHostGroup | Where-Object { $_.name -eq 'SYI5HE21B5' }

# Create a volume on the Primera P630

$volumeName = 'DSCC-API-TB-01'
$Response = New-DSCCVolume -SystemId $systemid['p630'] -DeviceType1 -name $volumeName -sizeMib '61440' -userCpg 'SSD_r6' -snapCpg 'SSD_r6' -comments "DSCC Rest API Test - Thomas Beha" -count 1 -dataReduction $true
WaitForTaskToComplete($Response.taskUri)
Write-Log -message 'New DSCC Volume DSCC-API-TB-01 created' -writeToConsole $true

# Get the Volume Id of the new Volume
$Response = Get-DSCCVolume -SystemId $systemid['p630'] | Where-Object {$_.name -eq $volumeName}
$volumeId = $Response.Id
Write-Log -message ('Volume ID: ' + $volumeId) -writeToConsole $true

# Export the Volume to SYI5HE21B5

$Response = Export-DSCCVolume -VolumeId $volumeId -HostGroupIds $hostgroup.id -SystemId $systemid['p630']
Write-Log -message ("Volume Export Task: " + $Response.taskUri) -writeToConsole $true
WaitForTaskToComplete($Response.taskUri)
Write-Log -message "Completed" -writeToConsole $true

# Unexport the volume
#$Response = UnExport-DSCCVolume -VolumeId $volumeId -HostGroupIds $hostgroup.id -SystemId $systemid['p630']
#Write-Log -message ("Volume Unexport Task: " + $Response.taskUri) -writeToConsole $true
#WaitForTaskToComplete($Response.taskUri)
#Write-Log -message "Completed" -writeToConsole $true

# Delete the volume

$Response = Remove-DSCCVolume -VolumeId $volumeId -SystemId $systemid['p630'] -Cascade -unExport -force
Write-Log -message ("Delete Volume Task: " + $Response.taskUri) -writeToConsole $true
WaitForTaskToComplete($Response.taskUri)
Write-Log -message "Completed" -writeToConsole $true

