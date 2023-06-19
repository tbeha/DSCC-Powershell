


$Client_ID = 'caba96ba-52c9-49e5-8ae7-eec301e3000a'  
$Client_Secret = '6a4525e2cd3111edaced4a452722384f'

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

	
	$MyBody = @{}
	if($AutoLun)	{ $MyBody = $MyBody + @{'autoLun'   = $AutoLun} }
	if($Proximity)	{ $MyBody = $MyBody + @{'proximity' = $Proximity} }
	if($Override)	{ $MyBody = $MyBody + @{'override'  = $Override} }
	if($Position)	{ $MyBody = $MyBody + @{'position'  = $Position} }
	if($NoVcn)		{ $MyBody = $MyBody + @{'noVcn' 	= $NoVcn} }
	$MyBody = $MyBody + @{'hostGroupIds' = $HostGroupIds} 	

	$Uri = $Base + $systemUri

	$result = Invoke-RestMethod -Uri $Uri -Method 'POST' -Body ($MyBody | ConvertTo-Json) -Headers $MyHeaders -ContentType 'application/json'
	return $result
}

Connect-DSCC -Client_Id $Client_ID -Client_Secret $Client_Secret -GreenlakeType EU #-Verbose -AutoRenew

$HostGroup = Get-DSCCHostGroup |  Where-Object{$_.name -eq 'VDI'}
$HostGroupId = @($HostGroup.id)
$HostGroupId 