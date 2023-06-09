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
Function New-DSCCAppSet($SystemId,$appSetName,$appSetType,$appSetBusinessUnit,$appSetComments,$appSetImportance,$customAppType,$Members) {
    <#
    
    #>

    $system = Get-DSCCStorageSystem -SystemId $SystemId
	$systemUri = $system.resourceUri
	$Uri = $Base + $systemUri + '/applicationsets'

	$MyBody = @{}
	if($appSetName)	        { $MyBody = $MyBody + @{'appSetName'   = $appSetName} }
	if($appSetType)	        { $MyBody = $MyBody + @{'appSetType' = $appSetType} }
	if($appSetBusinessUnit)	{ $MyBody = $MyBody + @{'appSetBusinessUnit'  = $appSetBusinessUnit} }
	if($appSetComments)	    { $MyBody = $MyBody + @{'appSetComments'  = $appSetComments} }
	if($appSetImportance)	{ $MyBody = $MyBody + @{'appSetImportance' 	= $appSetImportance} }
    if($customAppType)      { $MyBody = $MyBody + @{'customAppType' = $customAppType}}
    if($Members)            { $MyBody = $MyBody + @{'members' = $Members}}

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

Function Set-DSCCAppSet($SystemId, $appSetId, $appSetName,$appSetType,$appSetBusinessUnit,$appSetComments,$customAppType,$AddMembers, $RemoveMembers) {
    <#
    
    #>

    $system = Get-DSCCStorageSystem -SystemId $SystemId
	$systemUri = $system.resourceUri
	$Uri = $Base + $systemUri + '/applicationsets/' + $appSetId

	$MyBody = @{}
	if($appSetName)	        { $MyBody = $MyBody + @{'appSetName'   = $appSetName} }
	if($appSetType)	        { $MyBody = $MyBody + @{'appSetType' = $appSetType} }
	if($appSetBusinessUnit)	{ $MyBody = $MyBody + @{'appSetBusinessUnit'  = $appSetBusinessUnit} }
	if($appSetComments)	    { $MyBody = $MyBody + @{'appSetComments'  = $appSetComments} }
    if($customAppType)      { $MyBody = $MyBody + @{'customAppType' = $customAppType}}
    if($AddMembers)         { $MyBody = $MyBody + @{'addMembers' = $AddMembers}}
	if($RemoveMembers)		{ $MyBody = $MyBody + @{'removeMembers' = $RemoveMembers}}

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

FUnction Delete-DSCCAppSet($SystemId, $appSetId){

    $system = Get-DSCCStorageSystem -SystemId $SystemId
	$systemUri = $system.resourceUri
	$Uri = $Base + $systemUri + '/applicationsets/' + $appSetId

    try{
    	return Invoke-RestMethod -Uri $Uri -Method 'DELETE'  -Headers $MyHeaders -ContentType 'application/json'  
    }
    catch{   ThrowHTTPError -ErrorResponse $_ 
        # Note that value__ is not a typo.
       Write-Log -message ("StatusCode:" + $_.Exception.Response.StatusCode.value__) 
       Write-Log -message ("StatusDescription:" + $_.Exception.Response.StatusDescription)
       return
   }      
}

Write-Log -message "Create Volumeset / Appset example " -writeToConsole $true
Write-Log -message "Read the inputfile: ./dscc.xml " -writeToConsole $true

# Read the XML Input File 
[xml]$xml = Get-Content -Path ./dscc.xml
$Client_ID = $xml.DSCC.ClientID 
$Client_Secret = $xml.DSCC.ClientSecret
# Read the System Ids
$SystemIds =@{}
foreach($sys in (Select-Xml -Xml $xml -XPath /DSCC/SystemIds | Select-Object -ExpandProperty Node).System){
	$SystemIds = $SystemIds + @{$sys.Name = $sys.Id}
}
# Read the VolumeSets Information 
$Volumes = @()
$VolumeNames = @()
foreach($vol in (Select-Xml $xml -XPath /DSCC/VolumeSet | Select-Object -ExpandProperty Node).Volume){
	$size = [int]$vol.size * 1024
	$Volumes = $volumes +@(@{name=$vol.Name;size= [string]$size})
    $VolumeNames = $VolumeNames + $vol.Name
}

# Check if the volumes already exist and create the volumes if the do not exist
Connect-DSCC -Client_Id $Client_ID -Client_Secret $Client_Secret -GreenlakeType EU #-Verbose -AutoRenew

Write-Log -message "DSCC Connection established " -writeToConsole $true
Write-Log -message "Check whether the volumes exist " -writeToConsole $true
$sysID = $SystemIds[$xml.DSCC.VolumeSet.System]
foreach($vol in $Volumes){
	Write-Log -message ($vol.Name+" :: "+$vol.size) -writeToConsole $true
	$Response = Get-DSCCVolume -SystemId $sysID | Where-Object {$_.name -eq $vol.Name}
	if($Response){
		Write-Log -message ($Response) -writeToConsole $true
	} else {
		Write-Log ("Volume not found - Create the Volume " + $vol.Name) -writeToConsole $true
		$Response = New-DSCCVolume -SystemId $sysId -DeviceType1 -name $vol.Name -sizeMib $vol.Size -userCpg 'SSD_r6' -snapCpg 'SSD_r6' -comments "DSCC Rest API Test - Thomas Beha" -count 1 -dataReduction $true
		WaitForTaskToComplete($Response.taskUri)
		Write-Log -message ('New DSCC Volume ' +$vol.name +' created') -writeToConsole $true
		$Response = Get-DSCCVolume -SystemId $sysID | Where-Object {$_.name -eq $vol.Name}
		Write-Log -message ($Response.name + " " +$Response.id) -writeToConsole $true
	}
}

# Create the volumeset/appset

$Members = @()
$Members = $Members + $VolumeNames[0]
Write-Log -message ("Create Appset " + $xml.DSCC.VolumeSet.Name) -writeToConsole $true
if($Members){
   $Members | Format-Table
}

if($xml.DSCC.VolumeSet.AppSetType -eq 'CUSTOM'){
    $Response = New-DSCCAppSet -SystemId $sysID -appSetName $xml.DSCC.VolumeSet.Name `
      -appSetType 'CUSTOM' -customAppType $xml.DSCC.VolumeSet.customAppType -appSetBusinessUnit $xml.DSCC.VolumeSet.AppSetBU`
       -appSetComments $xml.DSCC.VolumeSet.Comment -appSetImportance $xml.DSCC.VolumeSet.AppSetImportance -Members $Members

} else {
    $Response = New-DSCCAppSet -SystemId $sysID -appSetName $xml.DSCC.VolumeSet.Name `
      -appSetType $xml.DSCC.VolumeSet.AppSetType -appSetBusinessUnit $xml.DSCC.VolumeSet.AppSetBU`
       -appSetComments $xml.DSCC.VolumeSet.Comment -appSetImportance $xml.DSCC.VolumeSet.AppSetImportance -Members $Members
}    
Write-Log -message $Response -writeToConsole $true
WaitForTaskToComplete($Response.taskUri)
Write-Log -message ('New DSCC VolumeSet ' + $xml.DSCC.VolumeSet.Name + ' created.' ) -writeToConsole $true

$Response = Get-DSCCVolumeSet -SystemId $sysID | Where-Object {$_.name -eq $xml.DSCC.VolumeSet.Name}
$AppSetId = $Response.Id
Write-Log -message ($Response.appSetName + " " + $AppSet.id) -writeToConsole $true

# Add a second member to the AppSet

$AddMembers = @()
$AddMembers = $AddMembers + $VolumeNames[1]
$Response = Set-DSCCAppSet -SystemId $sysID -appSetId $AppSetId -AddMembers $AddMembers
Write-Log -message $Response -writeToConsole $true
WaitForTaskToComplete($Response.taskUri)
Write-Log 'AppSet Edited' -writeToConsole $true

# Delete AppSet

$Response = Delete-DSCCAppSet -SystemId $sysID -appSetId $AppSetId
Write-Log -message $Response -writeToConsole $true
WaitForTaskToComplete($Response.taskUri)
Write-Log 'AppSet Deleted' -writeToConsole $true



