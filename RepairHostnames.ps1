<#

RepairHostnames.ps1

Fixes the hostnames as listed in the $Host_List

param([string]$Client_Id, [string]$Client_Secret, [string]$Host_List='./HostTest.csv') 



$Client_ID = Read-Host "Enter the DSCC Client ID: " 
$Client_Secret = Read-Host "Enter the DSCC Client Secret: " 
$Host_List = Read-Host "Enter the filename of the Hostlist: "  # ./HostTest.csv
#>
$Client_ID = ""
$Client_Secret = ""
$Host_List = '.\HostMigrationStatus.csv'

Import-Module .\HPEDSCC.psd1 -SkipEditionCheck

Connect-DSCC -Client_Id $Client_ID -Client_Secret $Client_Secret -GreenlakeType EU #-Verbose -AutoRenew

# Go through each line of the HostMigrationStatus.csv file
# Split the lines into an array:
# 0 - date
# 1 - Hostname temp
# 2 - Hostname current
# 3 - Success: 'Yes' or 'No'
# 4 - Correct Hostname

$HostList = Get-DSCCHost

foreach($line in Get-Content $Host_List){
	$data = $line -split ','
	if($data[3] -eq 'No'){
		Write-Host ("Change Hostname from "+$data[2]+" to: "+$data[4] )
		# 1. find the current host id
		for($i=0; $i -lt $HostList.Count; $i++){
			if($HostList[$i].name -eq $data[2]){
				$Response = Set-DSCCHost -hostID $HostList[$i].id -name $data[4]
				# Task Abfrage
				WaitForTaskToComplete($Response.taskUri)
				$i = $HostList.Count
			}
		}
		# 2. change the hostname
	} else {
		write-Host ("Skip host: "+$data[2])
	}
}

