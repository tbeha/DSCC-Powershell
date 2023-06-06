<# Get the Powershell Toolkit for the DSCC

# Download the PowerShell ToolKit from github.com and store it in the PowerShell Modules Directory

# check module directory

#$env:PSModulePath -split ';'

#URL: https://github.com/HewlettPackard/HPEDSCC-PowerShell-Toolkit
#$FOLDER = 'C:\Windows\System32\WindowsPowerShell\v1.0\Modules'
#invoke-webrequest -uri $PSTK -outfile “MyFile.zip"
#expand-archive -path “MyFile.zip" -DestinationPath $FOLDER 

Get PowerShell 7:

winget search Microsoft.PowerShell
winget install --id Microsoft.Powershell --source winget
winget install --id Microsoft.Powershell.Preview --source winget

#>
# import the module

Import-Module .\HPEDSCC.psd1 -SkipEditionCheck

function Get-DSCCTask{
<#
.SYNOPSIS
    Returns the HPE DSSC DOM Tasks Collection    
.DESCRIPTION
    Returns the HPE Data Services Cloud Console Data Operations Manager Task Collections;
	
	Parameter: 
	$TaskId  - ID of a specific task
#>
[CmdletBinding()]
param(  [string]    $TaskId
    )
process
    {   
		if( $TaskId){$MyURI = $BaseURI + 'tasks/' + $TaskId }
		else {$MyURI = $BaseURI + 'tasks'}
        return ( invoke-restmethod -Uri $MyUri -Method 'GET' -Headers $MyHeaders  -ContentType 'application/json')
    }
}

function Wait-DSCCTaskCompletion{
<#
.SYNOPSIS
    Waits for completion of  the HPE DSSC DOM Task    
.DESCRIPTION
    Returns ...
	
	Parameter: 
	$TaskId  - ID of a specific task
#>
[CmdletBinding()]
param(  
	[Parameter(Mandatory)] [string]    $TaskId
    )
process
    {   
		$Status = Get-DSCCTask -TaskId $TaskId
		while( $Status.progressPercent -lt 100 ){
			$Status.progressPercent
			Start-Sleep -Seconds 5	
			$Status = Get-DSCCTask -TaskId $TaskId
		}
		return $Status
    }	
}
function DSCCVolumeExport{
<#
.SYNOPSIS
    Exports a volume to a host group    
.DESCRIPTION
    Export vlun for volume identified by {volumeId} from Primera / Alletra 9K 

        body:
            autoLun         boolean     Auto Lun
            hostGroupIds    [string]    HostGroups
            maxAutoLun      int64       Number of volumes
            noVcn           boolean     No VCN
            override        boolean     Override
            position        string      Position
            proximity       enum        Host proximity setting for Active Peer Persistence configuration.
                                        Allowed: PRIMARY, SECONDARY, ALL
            
            Example:
            {
                "autoLun": true,
                "hostGroupIds": [
                    "string"
                ],
                "maxAutoLun": 1,
                "noVcn": true,
                "override": true,
                "position": "position_1",
                "proximity": "PRIMARY"
            }
#>
[CmdletBinding()]
param(  
		[Parameter(Mandatory)]	[string]	$volumeId,
		[Parameter(Mandatory)]	[string]	$ArrayUri,
								[Boolean]	$AutoLun,
		[Parameter(Mandatory)]	[array]	    $HostGroupIds,
								[Int32]		$maxAutoLun,
								[Boolean]	$noVCN,
								[Boolean]	$Override,
								[string]	$Position,
								[string]	$Proximity	
    )
process
    {   
		$MyURI = "https://eu1.data.cloud.hpe.com" + $ArrayUri + '/volumes/' + $volumeId + '/export'
		$MyBody += @{}
		$MyBody += @{ hostGroupIds = $HostGroupIds}
		if($AutoLun){	$MyBody += @{	autoLun = $AutoLun}}
		if($maxAutoLun){$MyBody += @{	maxAutoLun = $maxAutoLun}}
		if($noVCN){$MyBody += @{noVCN = $noVCN}}
		if($Position){$MyBody += @{position = $Position}}
		if($Proximity){$MyBody += @{proximity = $Proximity}}
		if($Override){$MyBody += @{override = $Override}}

        return ( invoke-restmethod -Uri $MyUri -Method 'POST' -Headers $MyHeaders -body ($MyBody | ConvertTo-Json) -ContentType 'application/json')
    }	
}

function DSCCvolumeUnexport{
<#
.SYNOPSIS
    Un Exports a volume to a host group    
.DESCRIPTION
    Unexport vlun for volume identified by {volumeId} storage arrya 

        body:
            hostGroupIds    [string]    HostGroups
            
            Example:
            {
                "hostGroupIds": [
                    "string"
                ]
            }
#>
[CmdletBinding()]
param(  
		[Parameter(Mandatory)]	[string]	$volumeId,
		[Parameter(Mandatory)]	[string]	$ArrayUri,
		[Parameter(Mandatory)]	[array]	    $HostGroupIds
    )
process
    {   
		$MyURI = "https://eu1.data.cloud.hpe.com" + $ArrayUri + '/volumes/' + $volumeId + '/unexport'
		$MyBody += @{}
		$MyBody += @{ hostGroupIds = $HostGroupIds}

        return ( invoke-restmethod -Uri $MyUri -Method 'POST' -Headers $MyHeaders -body ($MyBody | convertTo-Json) -ContentType 'application/json')
    }	
}

$Debug = $true

# and connect to the DSCC 

$Client_ID = 'caba96ba-52c9-49e5-8ae7-eec301e3000a'  
$Client_Secret = '6a4525e2cd3111edaced4a452722384f' 
#$Client_ID = Read-Host "Enter the DSCC Client ID: " 
#$Client_Secret = Read-Host "Enter the DSCC Client Secret: " 
Connect-DSCC -Client_Id $Client_ID -Client_Secret $Client_Secret -GreenlakeType EU

$P650 = Get-DSCCStorageSystem | Where-Object {$_.name -eq "Primera650"}
if($Debug){$P650 | Format-List}

<#
$Response = Invoke-ConvertHost
$Response | Format-List
#>

# Create a volume on Primera650
$volname = "DSCC_Rest_API_Test_TB"
$Response = New-DSCCVolume -comments $comment -name $volname -count 1 -sizeMib 61440 -userCpg 'SSD_r6' -snapCPG 'SSD_r6' -SystemId $P650.id 
$Status = Wait-DSCCTaskCompletion -TaskId $Response.taskURI
if($Debug){ $Status | Format-List }

# Get the volume Information
$x = Get-DSCCVolume -SystemId $P650.id
for($i=0; $i -lt $x.Count; $i++){
	$y = $x[$i]
	if($y.name -eq $volname){
		$Volume = $y
		$VolId = $Volume.id
		$i = $x.Count
	}
}
if($Debug){ $Volume | Format-List }

# Create the host
$name = "SYI5HE21B5"
$comment = "DSCC API Created - Thomas Beha"
$initiator1 =  @{address="10:00:be:d8:0d:50:01:ca";name="syi5he21b5p1"; protocol="FC"}
$initiator2 =  @{address="10:00:be:d8:0d:50:01:cc";name="syi5he21b5p2"; protocol="FC"}
$initiatorsToCreate = @($initiator1, $initiator2)

$DSCCHost = New-DSCCHost -comment $comment  -contact "thomas.beha@hpe.com" -fqdn "syi5he21b5.demo.local" `
		-ipAddress "10.1.40.21" -subnet "255.255.255.0" -model "SY480Gen10" -name $name -operatingSystem "VMware (ESXi)" `
		-persona "VMware" -protocol "FC" -location "CTC BBN" -userCreated $true -initiatorsToCreate $initiatorsToCreate
if($Debug){ $DSCCHost | Format-List }

# Get the Host Object of the new host
$DSCCHost = Get-DSCCHost | Where-Object{$_.name -eq $name}

# Add the host to a hostgroup
$HostGroup = New-DSCCHostGroup -comment $comment -name $name -hostIds $DSCCHost.id -Verbose
if($Debug){ $HostGroup | Format-List }
$HostGroup = Get-DSCCHostGroup | Where-Object{$_.name -eq $name}


# Assign the volume to the host group
$Response = DSCCVolumeExport -volumeId $Volume.id -HostGroupIds $HostGroup.id -ArrayUri $P650.resourceUri -AutoLun $true 
$Status = Wait-DSCCTaskCompletion -TaskId $Response.taskURI
if($Debug){ $Status | Format-List }

# The clean up
$Response = DSCCVolumeUnexport -volumeId $Volume.id -HostGroupIds $HostGroup.id -ArrayUri $P650.resourceUri
$Status = Wait-DSCCTaskCompletion -TaskId $Response.taskURI
if($Debug){ $Status | Format-List }


$Response = Remove-DSCCVolume -SystemId $P650.id -VolumeId $VolId -Force
$Status = Wait-DSCCTaskCompletion -TaskId $Response.taskURI
if($Debug){ $Status | Format-List }

$Response = Remove-DSCCHostGroup -HostGroupID  $HostGroup.ID -Force
$Status = Wait-DSCCTaskCompletion -TaskId $Response.taskURI
if($Debug){ $Status | Format-List }

$Response = Remove-DSCCHost -HostID $DSCCHost.id -Force
$Status = Wait-DSCCTaskCompletion -TaskId $Response.taskURI
if($Debug){ $Status | Format-List }


$Response = Get-DSCCInitiator
for($i=0; $i -lt $Response.Count; $i++){
	if( ($Response[$i]).address -eq"10:00:be:d8:0d:50:01:ca"){ 
		$init1 = $Response[$i]
		$init1
	}
	if( ($Response[$i]).address -eq"10:00:be:d8:0d:50:01:cc"){ 
		$init2 = $Response[$i]
		$init2
	}
}
$Response = Remove-DSCCInitiator -InitiatorId $init1.id -Force
if($Debug){ $Response | Format-List }
$Response = Remove-DSCCInitiator -InitiatorId $init2.id -Force
if($Debug){ $Response | Format-List }