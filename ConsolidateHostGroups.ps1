

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

function Get-ChoiceHG
{

[CmdletBinding()]
param(
	[Parameter(Mandatory)]	[string]	$hgname
    )
process
    {

        $title    = 'Do you want to update the Host Group Definition for '+$hgname+' ?'
        $question = 'Yes to update the HostGroup Definitions, No for the dry run only'
        $choices  = '&Yes', '&No'

        $decision = $Host.UI.PromptForChoice($title, $question, $choices, 1)
        if ($decision -eq 0) {
            return $true
        } else {
            return $false
        }
    }
}

function Get-ChoiceHG2
{

[CmdletBinding()]
param(
	[Parameter(Mandatory)]	[string]	$hgname
    )
process
    {

        $title    = 'Do you want to consolidate and update the Host Group Definition for '+$hgname+' ?'
        $question = 'Yes to update the HostGroup Definitions, No for the dry run only'
        $choices  = '&Yes', '&No'

        $decision = $Host.UI.PromptForChoice($title, $question, $choices, 1)
        if ($decision -eq 0) {
            return $true
        } else {
            return $false
        }
    }
}


Connect-DSCC -Client_Id $Client_ID -Client_Secret $Client_Secret -GreenlakeType EU #-Verbose -AutoRenew

#$Response = Invoke-ConvertHost
# Get the list of system created host groups
$Response = Get-DSCCHostGroup | Where-Object{$_.userCreated -eq $false}

# Consolidate the system generated HostGroup list by merging multiple entries of the same Host Group name into a single one
$hglist=@()
$hglist += $Response[0]
for($i=1; $i -lt $Response.Count; $i++){
    $new = $true
    for($j=0; $j -lt $hglist.Count; $j++){
        if($hglist[$j].name -eq $Response[$i].name){
            $new = $false
            $x=$j
            $j = $hglist.Count
        }
    }
    if($new){
        $hglist += $Response[$i]
    } else { # consolidate the entries
        for($k=0; $k -lt $Response[$i].hosts.Count; $k++){
            $new = $true
            for($l=0; $l -lt $hglist[$x].hosts.Count; $l++){
                if($Response[$i].hosts[$k].id -eq $hglist[$x].hosts[$l].id){ 
                    $new = $false
                    $l = $hglist[$x].hosts.Count
                }
            }
            if($new){$hglist[$x].hosts += $Response[$i].hosts[$k] }
        }
    }
}

# use the consolidated Host Group list to create user created host groups

$userHG = Get-DSCCHostGroup | Where-Object{$_.userCreated -eq $true}

for($i =0; $i -lt $hglist.Count; $i++){
    $name = $hglist[$i].name
    $comment = $hglist[$i].comment
    $hostIds = @()
    for($j =0; $j -lt $hglist[$i].hosts.Count; $j++){
        $hostIds += $hglist[$i].hosts[$j].id
    }
    Write-Host ($name+":"+$comment+":"+$hostIDs)
    # Check if the user created host group already exists
    $hgExist=$false
    for($j=0;$j -lt $userHG.Count; $j++){
        if($userHG[$j].name -eq $name){
            $hgExist = $true
            $hgID = $userHG[$J].id
            $j = $userHG.Count
        }
    }

    if($hgExist){
        write-Host ("Edit existing host Group: " + $name)
        $Response = Set-DSCCHostGroup -hostGroupID $hgID -updatedHosts $hostIds 
        write-Host $Response
    } else {
       Write-Host ("Create new Host Group: "+$name) 
       $Response = New-DSCCHostGroup -DeviceType1 -name $name -hostIds $hostIds -comment $comment -userCreated $true
       write-Host $Response
    }

}

$Response = Get-DSCCHostGroup | Where-Object{$_.userCreated -eq $false}
write-Host $Response.Count
