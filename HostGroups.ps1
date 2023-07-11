<#
Host Group operations
#>

Import-Module .\HPEDSCC.psd1 -SkipEditionCheck #-Verbose

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

function ThrowHTTPError 
{  
Param   ( $ErrorResponse
        )
Process 
{   $Response =   ((($ErrorResponse).Exception).Response | convertto-json -depth 10 )
    $R2 =         ((($ErrorResponse).Exception).Response)
    $ECode =      (((($ErrorResponse).Exception).Response).StatusCode).value__
    $EText =      ((($ErrorResponse).Exception).Response).StatusDescription + ((($ErrorResponse).Exception).Response).ReasonPhrase 
    write-verbose "The RestAPI Request failed with the following Status: `r`n`tHTTPS Return Code = $ECode`r`n`tHTTPS Return Code Description = $EText"
    Write-verbose "Raw Response  = $Response"
    if ( ($R2).StatusCode -eq 400 )
        {   write-warning "The command returned an error status Code 400:Bad Request"
        } 
    if ( ($R2).StatusCode -eq 401 )
        {   write-warning "The command returned an error status Code 401:Unauthorized"
        } 
    return
}
}
Function New-DSCCHG($name, $Comment, $HostIds, $HostsToCreate, $UserCreated) {
    <#
    
    #>

    #$system = Get-DSCCStorageSystem -SystemId $SystemId
	#$systemUri = $system.resourceUri
	#$Uri = $Base + $systemUri + '/applicationsets'
    $Uri = $Base + '/api/v1/host-initiator-groups'

	$MyBody = @{}
	if($Name)           { $MyBody = $MyBody + @{'name'    = $Name} }
	if($Comment)	    { $MyBody = $MyBody + @{'comment' = $Comment} }
	if($HostIds)	    { $MyBody = $MyBody + @{'hostIds' = $HostIds} }
    if($HostsToCreate)  { $MyBody = $MyBody + @{'hostsToCreate' = $HostsToCreate}}
    if($UserCreated)	{ $MyBody = $MyBody + @{'userCreated' = $UserCreated} }
    try{
    	return Invoke-RestMethod -Uri $Uri -Method 'POST' -Body ($MyBody | ConvertTo-Json) -Headers $MyHeaders -ContentType 'application/json'  
    }
    catch{   ThrowHTTPError -ErrorResponse $_ 
        # Note that value__ is not a typo.
       Write-Log -message ("StatusCode:" + $_.Exception.Response.StatusCode.value__) 
       Write-Log -message ("StatusDescription:" + $_.Exception.Response.StatusDescription)
       return
   }  
}

Function Set-DSCCHG($HostGroupId, $Name, $HostsToRemove, $HostsToAdd, $HostsToCreate){

    $Uri = $Base + '/api/v1/host-initiator-groups/' + $HostGroupId
	if($Name)           { $MyBody = $MyBody + @{'name'    = $Name} }
    if($HostsToRemove)  { $MyBody = $MyBody + @{'removedHosts' = $HostsToRemove}}
    if($HostsToAdd)     { $MyBody = $MyBody + @{'updatedHosts' = $HostsToAdd}}
    if($HostsToCreate)  { $MyBody = $MyBody + @{'hostsToCreate' = $HostsToCreate}}
    try{
    	return Invoke-RestMethod -Uri $Uri -Method 'PUT' -Body ($MyBody | ConvertTo-Json) -Headers $MyHeaders -ContentType 'application/json'  
    }
    catch{   ThrowHTTPError -ErrorResponse $_ 
        # Note that value__ is not a typo.
       Write-Log -message ("StatusCode:" + $_.Exception.Response.StatusCode.value__) 
       Write-Log -message ("StatusDescription:" + $_.Exception.Response.StatusDescription)
       return
   }  



}

# Read the input file dsccHG.xml

[xml]$xml = Get-Content -Path ./dscc.xml
$Client_ID = $xml.DSCC.ClientID 
$Client_Secret = $xml.DSCC.ClientSecret
$SystemIds =@{}
foreach($sys in (Select-Xml -Xml $xml -XPath /DSCC/SystemIds | Select-Object -ExpandProperty Node).System){
	$SystemIds = $SystemIds + @{$sys.Name = $sys.Id}
}

# Connect to the DSCC

Connect-DSCC -Client_Id $Client_ID -Client_Secret $Client_Secret -GreenlakeType EU #-Verbose -AutoRenew
Write-Log -message "DSCC Connection established " -writeToConsole $true

$host1 = Get-DSCCHost | Where-Object {$_.Name -eq 'syi5he21b4'}
$host2 = Get-DSCCHost | Where-Object {$_.Name -eq 'syi5he21b5'}

<#  Create Hostgroup
$hostIds = $host1.id,$host2.id
$Response = New-DSCCHG -name 'DSCC-HG1' -SystemId $SystemIds['p630'] -hostIds $hostIds -userCreated $true -comment 'DSCC API Created Thomas Beha'
Write-Log -message ("Host Group DSCC-HG1 Creation Task: " + $Response.taskUri) -writeToConsole $true
WaitForTaskToComplete($Response.taskUri)
Write-Log -message "Host Group DSCC-HG1 Creation Task Completed" -writeToConsole $true
$hostgroup = Get-DSCCHostGroup | Where-Object { $_.name -eq 'DSCC-HG1' }
#>

# Get Host Group Id of existing and new Host Group
$dscc_hg1 = Get-DSCCHostGroup | Where-Object { $_.name -eq 'DSCC-HG1' }
$dscc_hg1 | Format-Table
$vdi =  Get-DSCCHostGroup | Where-Object { $_.name -eq 'VDI' }
$vdi | Format-Table

# Move $host2 from Disk Group DSCC-HG1 to Host Group VDI and back

$hostsToMove = @($host2.id)
 
$Response = Set-DSCCHG -HostGroupId $dscc_hg1.id -HostsToRemove $hostsToMove
$Response | Format-Table
WaitForTaskToComplete($Response.taskUri)
$Response = Set-DSCCHG -HostGroupId $vdi.id -HostsToAdd $hostsToMove
$Response | Format-Table
WaitForTaskToComplete($Response.taskUri)
$Response = Set-DSCCHG -HostGroupId $vdi.id -HostsToRemove $hostsToMove
$Response | Format-Table
WaitForTaskToComplete($Response.taskUri)
$Response = Set-DSCCHG -HostGroupId $dscc_hg1.Id -HostsToAdd $hostsToMove
$Response | Format-Table
WaitForTaskToComplete($Response.taskUri)

# Delete Host Group

$Response = Remove-DSCCHostGroup -HostGroupID $dscc_hg1.id -Force
$Response | Format-Table
WaitForTaskToComplete($Response.taskUri)
$dscc_hg1 = Get-DSCCHostGroup | Where-Object { $_.name -eq 'DSCC-HG1' }
$dscc_hg1 | Format-Table
