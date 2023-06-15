$Client_ID = 'caba96ba-52c9-49e5-8ae7-eec301e3000a'  
$Client_Secret = '6a4525e2cd3111edaced4a452722384f' 

<#

Powershell Toolkit test program

Check the Invoke-ConvertHost Routine.

Invoke-ConvertHost is located in the scripts/HostUtilities.ps1 

#>

#$Client_ID = Read-Host "Enter the DSCC Client ID: " 
#$Client_Secret = Read-Host "Enter the DSCC Client Secret: " 

Import-Module .\HPEDSCC.psd1 -SkipEditionCheck

Connect-DSCC -Client_Id $Client_ID -Client_Secret $Client_Secret -GreenlakeType EU #-Verbose -AutoRenew

# Go through each line of the HostMigrationStatus.csv file
# Split the lines into an array:
# 0 - date
# 1 - Hostname temp
# 2 - Hostname current
# 3 - Success: 'Yes' or 'No'
# 4 - Correct Hostname

foreach($line in Get-Content .\HostTest.csv){
	$data = $line -split ','
	if($data[3] -eq 'No'){
		Write-Host ("Change Hostname from "+$data[2]+" to: "+$data[4] )
		# 1. find the current host id
		$Response = Get-DSCCHost  | Where-Object{$_.name -eq $data[2]}
		$hostid = $Response.id
		# 2. change the hostname
		$Response = Set-DSCCHost -hostID $hostid -name $data[4]
		$Response | Format-List
	} else {
		write-Host ("Skip host: "+$data[2])
	}
}

