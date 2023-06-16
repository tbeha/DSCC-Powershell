
<#

Consolidate multiple system generated Host Group entries into single user generated host groups

#>

$Client_ID = Read-Host "Enter the DSCC Client ID: " 
$Client_Secret = Read-Host "Enter the DSCC Client Secret: " 

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
        if($hglist[$j].name -eq $Response[$i].name){ # Host Group with the same name exists!
            $new = $false
            $x=$j
            $j = $hglist.Count
        }
    }
    if($new){  # add the HostGroup $Response[$i] to the list of hostgroups that need to be created
        $hglist += $Response[$i]
    } else { # A host group with the same name already exist in the consolidated list. 
        for($k=0; $k -lt $Response[$i].hosts.Count; $k++){ # Check for new host ids that are not yet listed in this host group entry
            $new = $true
            for($l=0; $l -lt $hglist[$x].hosts.Count; $l++){
                if($Response[$i].hosts[$k].id -eq $hglist[$x].hosts[$l].id){ 
                    $new = $false
                    $l = $hglist[$x].hosts.Count
                }
            }
            if($new){$hglist[$x].hosts += $Response[$i].hosts[$k] } # if the host id is not yet in the list, add it to the list
        }
    }
}

# use the consolidated Host Group list to create user created host groups

$userHG = Get-DSCCHostGroup | Where-Object{$_.userCreated -eq $true} # get the current list of user created host groups

for($i =0; $i -lt $hglist.Count; $i++){                 # work on the consolidated list of the system generated host groups
    $name = $hglist[$i].name                            # host group name
    $comment = $hglist[$i].comment                      # host group comment
    $hostIds = @()
    for($j =0; $j -lt $hglist[$i].hosts.Count; $j++){   # create the list of host ids, that belong to this host group  
        $hostIds += $hglist[$i].hosts[$j].id
    }
    #Write-Host ("Generate user created hostgroup:comment:hostIds - "+$name+":"+$comment+":"+$hostIDs)
    
    $hgExist=$false                                     # Check if a user created host group with the same name already exists
    for($j=0;$j -lt $userHG.Count; $j++){
        if($userHG[$j].name -eq $name){
            $hgExist = $true
            $hgID = $userHG[$J].id
            $j = $userHG.Count
        }
    }

    if($hgExist){                                       # if a user generated host group already exist, then only add the host ids
        write-Host ("Edit existing host Group: " + $name)
        $Response = Set-DSCCHostGroup -hostGroupID $hgID -updatedHosts $hostIds 
        write-Host $Response
    } else {                                            # create a new host group
       Write-Host ("Create new Host Group: "+$name) 
       $Response = New-DSCCHostGroup -DeviceType1 -name $name -hostIds $hostIds -comment $comment -userCreated $true
       write-Host $Response
    }

}
# Check wether there are still system generated host groups.
$Response = Get-DSCCHostGroup | Where-Object{$_.userCreated -eq $false}
write-Host $Response.Count
