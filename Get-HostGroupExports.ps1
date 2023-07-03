$Client_ID = ''  
$Client_Secret = ''

$systemid =@{
	'p630' = 'CZ29420H95';
	'p650' = 'CZ294112CB';
	'a6030' = '00444f5e31fd5cb296000000000000000000000001'
}

function Write-Log()
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


function Get-DSCCAllVolumes($resourceUri){
	$i = 0
	$offset = $i * 50
	$MyUri = $resourceUri +'/volumes?limit=50&offset='
	$Uri = $MyUri + $offset
	$Response = (Invoke-RestMethod -Uri $Uri -Method 'GET' -Headers $MyHeaders -ContentType 'application/json').items
	$Volumes = $Response
	while ($Response.Count -eq 50) {
		$i = $i + 1
		$offset = $i * 50
		$Uri = $MyUri + $offset
		$Response = (Invoke-RestMethod -Uri $Uri -Method 'GET' -Headers $MyHeaders -ContentType 'application/json').items
		$Volumes = $Volumes + $Response
	}
	return $Volumes
}

Import-Module .\HPEDSCC.psd1 -SkipEditionCheck #-Verbose
Connect-DSCC -Client_Id $Client_ID -Client_Secret $Client_Secret -GreenlakeType EU #-Verbose -AutoRenew

$HostGroupName = 'VDI' #Read-Host "Enter the Hostgroup Name: "

$HostGroup = Get-DSCCHostGroup | Where-Object {$_.name -eq $HostGroupName}
$Initiators = @()
$Hosts = @()
$Systems = $HostGroup.Systems

foreach($hg in $HostGroup.hosts) {
	$Initiators += $hg.id 
	$Hosts += $hg.name 
}
$Hosts = $Hosts | Sort-Object
$Initiators = $Initiators | Sort-Object

$ExportedVolumes =@()
$Volumes = @()
foreach($s in $Systems){
	$resourceUri = (Get-DSCCStorageSystem -SystemId $s).resourceUri
	if( $resourceUri | Select-String -Pattern 'device-type1'){
		Write-Host "Device-Type1"
		$MyUri="https://eu1.data.cloud.hpe.com/api/v1/storage-systems/device-type1/"+$s
		$Volumes = Get-DSCCAllVolumes -resourceUri $MyUri
		# Check for Volumes exported to the Host Group
		foreach($v in $Volumes){
			$vinit = @()
			if($v.initiators){
				foreach($vi in $v.initiators){
					if($vi.id -eq $HostGroup.id){
						$ExportedVolumes += $v
					}
					else{
						$vinit += $vi.Id
					}
				}
				if($vinit.Count -eq $Initiators.Count){
					$vexport = $true
					$vinit = $vinit | Sort-Object
					for($i=0;$i -lt $vinit.Count; $i++){
						if($vinit[$i] -ne $Initiators[$i]){
							$vexport = $false
							$i = $vinit.Count
						}
					}
					if($vexport){
						$ExportedVolumes += $v
					}
				}
			}
		}
	} else {
		Write-Host "Device-Type2"
		$MyUri="https://eu1.data.cloud.hpe.com/api/v1/storage-systems/device-type2/"+$s
		$Volumes = Get-DSCCAllVolumes -resourceUri $MyUri
		# Check for Volumes exported to the Host Group
		foreach($v in $Volumes){
			$vinit = @()
			foreach($a in $v.access_control_records){
				$vinit += $a.initiator_group_name 
			}
			if($vinit.Count -eq $Hosts.Count){
				$vexport = $true
				$vinit = $vinit | Sort-Object
				for($i=0;$i -lt $vinit.Count; $i++){
					if($vinit[$i] -ne $Hosts[$i]){
						$vexport = $false
						$i = $vinit.Count
					}
				}
				if($vexport){
					$ExportedVolumes += $v
				}
			}
		}

	}
}
$ExportedVolumes | Format-Table