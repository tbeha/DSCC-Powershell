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


# and connect to the DSCC 

$Client_ID = 'caba96ba-52c9-49e5-8ae7-eec301e3000a'   # Read-Host "Enter the DSCC Client ID: " -AsSecureString
$Client_Secret = '6a4525e2cd3111edaced4a452722384f' # Read-Host "Enter the DSCC Client Secret: " -AsSecureString
$AuthToken = Connect-DSCC -Client_Id $Client_ID -Client_Secret $Client_Secret -GreenlakeType EU -Verbose -Autorenew


$P650 = Get-DSCCStorageSystem | Where-Object {$_.name -eq "Primera650"}
$P650 | Format-List

#$Response | Format-List
#$P650 = Where-Object { $Response.name -eq 'Primera650'}

<#
$Response = Invoke-ConvertHost
$Response | Format-List

$Response = Get-DSCCHost
$hosts = $Response | ConvertTo-Json
$hosts | Format-List

$Response = Get-DSCCHostGroup
$hostgroups = $Response | ConvertTo-Json
$hostgroups | Format-List


# Create a volume on Primera650

$Volume = New-DSCCVolume -comments $comment -name "DSCC_Rest_API_Test_TB" -count 1 -sizeMib 61440 -userCpg 'SSD_r6' -snapCPG 'SSD_r6' -SystemId $P650.id 
$Volume | Format-List

# Create the host
$name = "SYI5HE21B5"
$comment = "DSCC API Created - Thomas Beha"
$initiator1 =  @{address="10:00:be:d8:0d:50:01:ca";name="syi5he21b5p1"; protocol="FC"}
$initiator2 =  @{address="10:00:be:d8:0d:50:01:cc";name="syi5he21b5p2"; protocol="FC"}
$initiatorsToCreate = @($initiator1, $initiator2)

$Response = New-DSCCHost -comment $comment  -contact "thomas.beha@hpe.com" -fqdn "syi5he21b5.demo.local" `
		-ipAddress "10.1.40.21" -subnet "255.255.255.0" -model "SY480Gen10" -name $name -operatingSystem "VMware (ESXi)" `
		-persona "VMware" -protocol "FC" -location "CTC BBN" -userCreated $true -initiatorsToCreate $initiatorsToCreate

$Response | Format-List

# Get the HostId of the new host
$HostId = Get-DSCCHost | Where-Object{$_.name -eq $name}

$Response = Get-DSCCHost 
for($i=0; $i -lt $Response.Count; $i++){
	if( ($Response[$i]).name -eq $name){ 
		$HostId = $Response[$i].id
	}
}


# Add the host to a hostgroup

$HostGroup = New-DSCCHostGroup -comment $comment -name $name -hostIds $HostId -Verbose
$HostGroup | Format-List



# Assign the volume to the host group




# The clean up

$Response = Remove-DSCCVolume -VolumeId $Volume.id -force
$Response

$Response = Remove-DSCCHostGroup -HostGroupID $HostGroup.id -Force
$Response

$Response = Remove-DSCCHost -HostID $HostId -Force
$Response 


$Response = Get-DSCCInitiator
for($i=0; $i -lt $Response.Count; $i++){
	if( ($Response[$i]).address -eq"10:00:be:d8:0d:50:01:ca"){ 
		$init1 = $Response[$i]
	}
	if( ($Response[$i]).address -eq"10:00:be:d8:0d:50:01:cc"){ 
		$init2 = $Response[$i]
	}
}
$init1 
$init2

$Response = Remove-DSCCInitiator -InitiatorId $init1.id -Force
$Response 
$Response = Remove-DSCCInitiator -InitiatorId $init2.id -Force
$Response
#>