
<#

Consolidate multiple system generated Host Group entries into single user generated host groups



$Client_ID = Read-Host "Enter the DSCC Client ID: " 
$Client_Secret = Read-Host "Enter the DSCC Client Secret: " 
#>

$Client_ID = ''  
$Client_Secret = ''

Import-Module .\HPEDSCC.psd1 -SkipEditionCheck

function Get-ChoiceAddHostGroup
{

[CmdletBinding()]
param(
	[Parameter(Mandatory)]	[string]	$hgname
    )
process
    {

        $title    = 'Do you want to update the Host Group Definition for '+$hgname+' ?'
        $question = 'Yes to update the HostGroup Definitions, No to skip'
        $choices  = '&Yes', '&No'

        $decision = $Host.UI.PromptForChoice($title, $question, $choices, 1)
        if ($decision -eq 0) {
            return $true
        } else {
            return $false
        }
    }
}

function Get-ChoiceAddHost
{

[CmdletBinding()]
param(
	[Parameter(Mandatory)]	[string]	$hname
    )
process
    {

        $title    = 'Do you want to add the Host '+$hname+' ?'
        $question = 'Yes to update the HostGroup Definitions, No to skip'
        $choices  = '&Yes', '&No'

        $decision = $Host.UI.PromptForChoice($title, $question, $choices, 1)
        if ($decision -eq 0) {
            return $true
        } else {
            return $false
        }
    }
}


function Get-ChoiceConsolidateHostGroups
{

[CmdletBinding()]
param(
    )
process
    {

        $title    = 'Do you want to consolidate the Hosts into a single Host Group?'
        $question = 'Yes to update the HostGroup Definition, No to skip'
        $choices  = '&Yes', '&No'

        $decision = $Host.UI.PromptForChoice($title, $question, $choices, 1)
        if ($decision -eq 0) {
            return $true
        } else {
            return $false
        }
    }
}

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

# Connect to the DSCC 
Connect-DSCC -Client_Id $Client_ID -Client_Secret $Client_Secret -GreenlakeType EU #-Verbose -AutoRenew

# Get the list of system created host groups
$Response = Get-DSCCHostGroup | Where-Object{$_.userCreated -eq $false}

# Consolidate the system generated HostGroup list by merging multiple entries of the same Host Group name into a single one
$hglist=@()
#$hglist += $Response[0]
for($i=0; $i -lt $Response.Count; $i++){
    $new = $true
    for($j=0; $j -lt $hglist.Count; $j++){
        if($hglist[$j].name -eq $Response[$i].name){ # Host Group with the same name exists!
            $new = $false
            $x=$j
            $j = $hglist.Count
        }
    }
    if($new){  # add the HostGroup $Response[$i] to the list of hostgroups that need to be created
        $message = "Found new system generated Host Group: " + $Response[$i].name
        Write-Log -message $message -writeToConsole $true
        $hosts = $Response[$i].hosts
        for($j=0; $j -lt $hosts.Count; $j++){
            Write-Log -message ("  - "+ $hosts[$j].name) -writeToConsole $true 
        }
        if(Get-ChoiceAddHostGroup($Response[$i].name)){ 
            $hglist += $Response[$i]
            Write-Log -message "Added to ToDo-List" -writeToConsole $true
        } else {
            Write-log -message "Skipped" -writeToConsole $true
        }
    } else { # A host group with the same name already exist in the consolidated list.
        Write-Log -message "A system generated host group with the same name already exist" -writeToConsole $true
        Write-Log -message "Check the Hosts in the Host Group" -writeToConsole $true
        Write-Log -message ("Host Group: " + $Response[$i].name) -writeToConsole $true
        Write-Log -message ("  Existing Hosts: ") -writeToConsole $true
        for($l=0; $l -lt $hglist[$x].hosts.Count; $l++){
            Write-Log -message ("    "+ $hglist[$x].hosts[$l].name) -writeToConsole $true
        }
        Write-Log -message ("  New Hosts: ") -writeToConsole $true
        for($k=0; $k -lt $Response[$i].hosts.Count; $k++){ # Check for new host ids that are not yet listed in this host group entry
            $new = $true
            for($l=0; $l -lt $hglist[$x].hosts.Count; $l++){
                if($Response[$i].hosts[$k].id -eq $hglist[$x].hosts[$l].id){ 
                    $new = $false
                    $l = $hglist[$x].hosts.Count
                }
            }
            if($new){
                $name = $Response[$i].hosts[$k].name
                Write-Log -message ("      " + $name ) -writeToConsole $true
                if( Get-ChoiceAddHost($name)){    
                    $hglist[$x].hosts += $Response[$i].hosts[$k]
                    Write-Log -message ("     Added") -writeToConsole $true
                } else {
                    Write-Log -message ("     Skipped") -writeToConsole $true
                }
            } 
        }
    }
}

# use the consolidated Host Group list to create user created host groups

Write-Log -message "Check for userCreated Host Groups" -writeToConsole $true 

$userHG = Get-DSCCHostGroup | Where-Object{$_.userCreated -eq $true} # get the current list of user created host groups

for($i =0; $i -lt $hglist.Count; $i++){                 # work on the consolidated list of the system generated host groups
    $name = $hglist[$i].name                            # host group name
    Write-Log -message ("  "+$name) -writeToConsole $true
    $comment = $hglist[$i].comment                      # host group comment
    $hostIds = @()
    $hostNames = @()
    for($j =0; $j -lt $hglist[$i].hosts.Count; $j++){   # create the list of host ids, that belong to this host group  
        $hostIds += $hglist[$i].hosts[$j].id
        $hostNames += $hglist[$i].hosts[$j].name
    }
    
    $hgExist=$false                                     # Check if a user created host group with the same name already exists
    for($j=0;$j -lt $userHG.Count; $j++){
        if($userHG[$j].name -eq $name){
            $hgExist = $true
            $hgID = $userHG[$j].id
            $j = $userHG.Count
        }
    }

    if($hgExist){                                       # if a user generated host group already exist, then only add the host ids
        Write-Log -message "  Found existing user created Host Group with the same name" -writeToConsole $true
        $oldHG = Get-DSCCHostGroup -SystemId $hgID
        Write-Log -message "    Existing Hosts: " -writeToConsole $true
        for($j=0; $j -lt $oldHG.hosts.Count;$j++){
            Write-Log -message ("     " +$oldHG.hosts[$j].name ) -writeToConsole $true
        }
        Write-Log -message "    New Hosts: " -writeToConsole $true
        for($j=0; $j -lt $hostNames.Count; $j++){
            Write-Log -message ("     " + $hostNames[$j])
        }
        if(Get-ChoiceConsolidateHostGroups){ # ask wether the hosts should be consolidated into the single host group
            Write_log -message "  Consolidate the Existing and the new Hosts into the single Host Group" -writeToConsole $true
            $Response = Set-DSCCHostGroup -hostGroupID $hgID -updatedHosts $hostIds
            WaitForTaskToComplete($Response.taskUri)
            Write-Log -message "  Done" -writeToConsole $true
        }
    } else {  # create a new host group
        Write-Log -message ("Create a new Host Group: " + $name) -writeToConsole $true                                  
        $Response = New-DSCCHostGroup -DeviceType1 -name $name -hostIds $hostIds -comment $comment -userCreated $true
        WaitForTaskToComplete($Response.taskUri)
        Write-Log -message "  Done" -writeToConsole $true
    }

}

