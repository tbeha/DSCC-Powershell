function Invoke-ConvertHost
{
[CmdletBinding()]
param(
    )
process
    {   

        Log-Message "-----------------------------------------------------------------------------------------" $True
        Log-Message "                            Staring Host Migration Job                                   " $True
        Log-Message "-----------------------------------------------------------------------------------------" $True

        <# Make DSCC public REST API 'api/v1/storage-systems' call to get all storage systems. DSCC REST APIs specification can be 
        found here - 'https://console-us1.data.cloud.hpe.com/doc/api/v1/' #>
        $MyAdd = 'storage-systems'   
        $Sys = Invoke-DSCCrestmethod -UriAdd $MyAdd -method Get -whatifBoolean $WhatIf
        $Sys = $Sys | measure
        Log-Message $Sys.Count
        If ( $Sys.Count -eq 0 ) 
        {   
            Write-Warning "No system found. Ensure that you have connected to a HPE Data Storage Cloud Services using Connect-DSCC command."
            return
        } 

        Log-Message "Identify hosts discovered from onboarded systems and migrate them to DSCC hosts." $True
        Log-Message "Identify multiple discovered hosts for host migration."
        $HostToUpdate1 = $false
        $HostToUpdate2 = $false
        $InitList = Get-CommonHosts
        

        if ($InitList.Count -eq 0) 
        { 
           Log-Message "No multiple discovered hosts found for host migration." $true
        } else {
            $HostToUpdate1 = Get-Choice1

            if ($HostToUpdate1 -ne $true)
            {
                Log-Message "------------------------------------------------------------------------------------------" $True
                Log-Message "                       Multiple Discovered Host PreMerge Summary" $True 
                Log-Message "------------------------------------------------------------------------------------------" $True
                $line = "{0,-20} {1,-25}  {2,-20}" -f "Host Name" , "Operating System", "Initiators Ids"
                Log-Message $line $True
                Log-Message "------------------------------------------------------------------------------------------" $True              
            } else {
                Log-Message "Starting the migration tasks..." $True 
            }
	        foreach ($intiator in $InitList) 
            {
                  $hostName, $os, $initiatorList = Get-HostDetailsByInitiatorId $intiator

                  if ($initiatorList.Count -gt 0)
                  {    if ($HostToUpdate1 -ne $true) 
                       {
                           $initStrList = ""
                           foreach ($initStr in $initiatorList) {
                              $initStrList = $initStrList + " "+ $initStr
                           }
                            $line = "{0,-20} {1,-25} {2,-20}" -f $hostName, $os, $initStrList
                            Log-Message $line $true 
                        }
                        if ($HostToUpdate1 -eq $true)
                        {   Log-Message "Creating host $hostName with initiators $initiatorList"  
                            Create-NewHost $hostName $os $initiatorList
                        }
                  } 
                  else
                  {
                     Log-Message "No host to be migrated as initiator count is 0."
                  } 
            }
        }
	
     	Log-Message "Identify single discovered hosts for host migration."

        $InitList = Get-SingleDisoveredHost
        

        if ($InitList.Count -eq 0) 
        { 
            Log-Message "No single discovered hosts found for host migration."
        } else {

            $HostToUpdate2 = Get-Choice1

            if ($HostToUpdate1 -ne $true) 
            {
                Log-Message "------------------------------------------------------------------------------------------" $True
                Log-Message "                       Single Discovered Host PreMerge Summary" $True 
                Log-Message "------------------------------------------------------------------------------------------" $True
                $line = "{0,-20} {1,-25}  {2,-20}" -f "Host Name" , "Operating System", "Initiators Ids"
                Log-Message $line $True
                Log-Message "------------------------------------------------------------------------------------------" $True
            }

	        foreach ($intiator in $InitList) 
            {
                 $hostName, $os, $initiatorList = Get-SingleHostDetailsByInitiatorId $intiator
                 if ($HostToUpdate1 -ne $true) 
                 {
                      $initStrList = ""
                      foreach ($initStr in $initiatorList) {
                         $initStrList = $initStrList + " "+ $initStr
                      }
                     $line = "{0,-20} {1,-25} {2,-20}" -f $hostName, $os, $initStrList 
                     Log-Message $line $true 
                }
                if ($HostToUpdate2 -eq $true)
                {
                    Log-Message  "Creating host $hostName with initiators $initiatorList" 
                    Create-NewHost $hostName $os $initiatorList
                }
            }
        }

        if ($HostToUpdate1 -or $HostToUpdate2) 
        {    
             Log-Message "Waiting for edit host operations to complete..." $true    
             $hostIdList, $hostNameList = Get-HostDetailsByName
             $log = "No of Hosts which needs to be Updated Back to original HostName is " + ($hostIdList).Count
             Log-Message $log
              For ($i=0; $i -lt $hostIdList.Count; $i++) {
                Set-HostDetails $hostIdList[$i] $hostNameList[$i]
             }
              Log-Message "Task for all the Hosts which has HostName -DSSC is submitted successfully"
            Log-Message "Submitted requests to migrate DSCC hosts successfully. Verify if the hosts are created from DSCC UI" $true     
        }
    }
}   


function Get-CommonHosts
{

[CmdletBinding()]
param(
    )
process
    {
    
     $MyAdd = 'initiators'   
     $intiators = Invoke-DSCCrestmethod -UriAdd $MyAdd -method Get -whatifBoolean $WhatIf
     $InitiatorsList = @()

     foreach ($intiator in $intiators)
     {
          $HostCount = (($intiator).hosts | measure).Count
          if ($HostCount -gt 1)
          {    $hosts =  ($intiator).hosts
               Log-Message "For the intiator found more than two hosts"
               $userCreatedHostFound = $false
               foreach ($host in ($intiator).hosts)
               {
                  Log-Message "Individual Host $host"
                  $UserCreated = ($host).UserCreated
                  $InitId = ($intiator).id
                  $hostName = ($host).Name
                  if ( $UserCreated -eq $false ) 
                  {
					Log-Message "Initiator Found $InitId associated with $hostName which is Discovered Host"
					$userCreatedHostFound = $true
				  } 
                  else 
                  {
					Log-Message "Initiator Found $InitId associated with $hostName which is User Created Host"
					$userCreatedHostFound = $false
					break
				  }
               }
               if ($userCreatedHostFound -eq $true)
               {
                    Log-Message "Adding initiator $InitId in the list."
                    $InitiatorsList += $InitId
               }
            }

         }

         if ($InitiatorsList.Count -eq 0) 
         {
		    Log-Message "initiator with merged host not found on the Array"
	     }
         return $InitiatorsList    
     }
 }

function Get-Choice1
{

[CmdletBinding()]
param(
    )
process
    {

        $title    = 'Do you want to update the Host Definition for multiple discovered host?'
        $question = 'Yes to update the Host Definitions, No for the dry run only'
        $choices  = '&Yes', '&No'

        $decision = $Host.UI.PromptForChoice($title, $question, $choices, 1)
        if ($decision -eq 0) {
            return $true
        } else {
            return $false
        }
    }
}

function Get-Choice2
{

[CmdletBinding()]
param(
    )
process
    {

        $title    = 'Do you want to update the Host Definition for single discovered host?'
        $question = 'Yes to update the Host Definitions, No for the dry run only'
        $choices  = '&Yes', '&No'

        $decision = $Host.UI.PromptForChoice($title, $question, $choices, 1)
        if ($decision -eq 0) {
            return $true
        } else {
            return $false
        }
    }
}


function Get-HostDetailsByInitiatorId
{
[CmdletBinding()]
Param
    (
         [Parameter(Mandatory=$true, Position=0)]
         [string] $InitId
    )
    process
    {
       Log-Message "Getting host detail from initiator Id $InitId"
       $MyAdd = 'host-initiators?filter=initiatorId%20eq%20' + $InitId   
       $hosts = Invoke-DSCCrestmethod -UriAdd $MyAdd -method Get -whatifBoolean $WhatIf
       $hostCount = ($hosts | measure).Count
       if ($hostCount -eq 0) 
       {
		 Log-Message "No host found"
		 return "", "", @()
	  }
   
      $matchedOperatingSystem = ""
      
      foreach ($host1 in $hosts)
      {    Log-Message $host 
           $InitiatorsList1 = @() 
           foreach ($Initiator in ($host1).Initiators) {
            $InitId = ($Initiator).id
            $InitiatorsList1 += $InitId
          }

          $host1Id = ($host1).id
          $host1Name = ($host1).name
          $matchedOperatingSystem = ""

          foreach ($host2 in $hosts)
          {  
              
            $host2Id = ($host2).id  

            if ($host1Id -eq $host2Id) 
            {
                <# Skipping the same host #> 
                continue
            }
              
          
            $InitiatorsList2 = @()
            foreach ($Initiator in ($host2).Initiators) {
                $InitId = ($Initiator).id
                $InitiatorsList2 += $InitId
            }

            <# Complare the host operating system list #>
            if (($host1).operatingSystem -ne ($host2).operatingSystem)
            {
                Log-Message "host operating system is not matching"
                continue
            }

            $matchedOperatingSystem = ($host1).operatingSystem
            $host1InitCount = (($host1).Initiators | measure).Count
            $host2InitCount = (($host2).Initiators | measure).Count

            Log-Message "Number of initiator in host1 $host1InitCount and number of initiator in host2 $host2InitCount"

            <# Complare the initiator list #>
            if ($host1InitCount -ne $host2InitCount)
            {
                Log-Message "host initiator count is not matching"
                continue
            }

            $initListMatched = $false
            $diff = (Compare-Object $InitiatorsList1 $InitiatorsList2).InputObject
            $diffCount = ($diff | measure).Count
            if ($diffCount -eq 0) {
                $initListMatched = $true
                Log-Message "host initiators list is matching"

            } else {
                Log-Message "host initiators list is not matching" 
            }

            if ($initListMatched -eq $true) {
               Log-Message "host initiator count matched"   

               if ($matchedOperatingSystem -eq "")
               {
			         $matchedOperatingSystem = "VMware (ESXi)"
		       }

               return $host1Name, $matchedOperatingSystem, $InitiatorsList1 

            }
          }
      }
       return "", "", @()
    }
 }


function Create-NewHost
{
[CmdletBinding()]
Param
    (
         [Parameter(Mandatory=$true, Position=0)]
         [string] $hostName,
         [Parameter(Mandatory=$true, Position=1)]
         [string] $operatingSystem,
         [Parameter(Mandatory=$true, Position=2)]
         [String[]] $initIds
    )
    process
    {   $newHostName = $hostName + "-DSSC"
        $MyBody = @{name=$newHostName
                userCreated = $true
                initiatorIds = $initIds
                operatingSystem = $operatingSystem     
        }
        $MyAdd = "host-initiators"
        $host = Invoke-DSCCrestmethod -UriAdd $MyAdd -method POST -Body ( $MyBody | convertto-json ) -whatifBoolean $WhatIf

        $hostCount = ($host | measure).Count
        if ($hostCount -eq 0) 
        {
		     Log-Message "Failed to create the Host with name $hostName"
             Log-Message "Error: Unable to migrate the host $hostName." $True
		     return
	    }
        else
        {
          Log-Message "Host with HostName $newHostName is created successfully."
          $initStrList = ""
          foreach ($initStr in $initiatorList) {
               $initStrList = $initStrList + " "+ $initStr
           }
        }
    }
}


function Get-SingleDisoveredHost
{
[CmdletBinding()]
Param
    (
    )
    process
    {
     $MyAdd = 'initiators'   
     $intiators = Invoke-DSCCrestmethod -UriAdd $MyAdd -method Get -whatifBoolean $WhatIf
     $InitiatorsList = @()

     Log-Message "Getting discovered/system hosts"
     foreach ($intiator in $intiators)
     {
          $HostCount = (($intiator).hosts | measure).Count
          if ($HostCount -eq 1)
          {    $hosts =  ($intiator).hosts
               Log-Message "Found single discovered Host for the initiator"
               $userCreatedHostFound = $false
               foreach ($host in ($intiator).hosts)
               {
                  Log-Message "Individual Host $host"
                  $UserCreated = ($host).UserCreated
                  $InitId = ($intiator).id
                  $hostName = ($host).Name
                  if ( $UserCreated -eq $false ) 
                  {
					Log-Message "Initiator found $InitId associated with $hostName which is Discovered Host"
					$userCreatedHostFound = $false
				  } 
                  else 
                  {
					Log-Message "Initiator found $InitId associated with $hostName which is User Created Host"
					$userCreatedHostFound = $true
					break
				  }
               }
               if ($userCreatedHostFound -eq $false)
               {
                    Log-Message "Adding initiator $InitId in the list."
                    $InitiatorsList += $InitId
               }
            }

         }

         if ($InitiatorsList.Count -eq 0) 
         {
		    Log-Message "initiator with single discovered host not found on the Array!!"
	     }
         
         $log = "Initiator with single discovered host found on the Array: " + $InitiatorsList.Count
         Log-Message $log
         return $InitiatorsList    
    }
 }


function Get-SingleHostDetailsByInitiatorId
{
[CmdletBinding()]
Param
    (
         [Parameter(Mandatory=$true, Position=0)]
         [string] $InitId
    )
    process
    {
       Log-Message "Getting host detail from initiator Id $InitId"
       $MyAdd = 'host-initiators?filter=initiatorId%20eq%20' + $InitId   
       $hosts = Invoke-DSCCrestmethod -UriAdd $MyAdd -method Get -whatifBoolean $WhatIf
       $hostCount = ($hosts | measure).Count
       if ($hostCount -eq 0) 
       {
		 Log-Message "No host found"
         return "", "", $InitiatorsList
	  }
      if ($hostCount -gt 1) 
      {
	 	  Log-Message "Initiator is common for more than one host, so skipping"
          return "", "", $InitiatorsList
  	  }

      $host = $hosts[0]
      $InitiatorsList = @()
      foreach ($Initiator in ($host).Initiators) {
         $InitId = ($Initiator).id
         $InitiatorsList += $InitId
      }

     $hostId = ($host).id

     if ($hostId -eq "") {
         Log-Message "No host found."
         return "", "", @()
     }

     Log-Message "Host Id: $hostId"

     $os = ($host).OperatingSystem
     Log-Message "Operating System: $os"

     $name = ($host).Name
     Log-Message "Host Name: $name"
          
    if ($os -eq "")
    {
	   $os = "VMware (ESXi)"
	}

    Log-Message "Initiator List: $InitiatorsList"
    return $name, $os, $InitiatorsList

    }

 }


function Get-HostDetailsByName
{
[CmdletBinding()]
Param
    (
    )
    process
    {
       Log-Message "Getting host detail"
       $MyAdd = 'host-initiators'   
       $hosts = Invoke-DSCCrestmethod -UriAdd $MyAdd -method Get -whatifBoolean $WhatIf
       $hostCount = ($hosts | measure).Count
       if ($hostCount -eq 0) 
       {
		 Log-Message "No host found"
		 return
	   }
       $HostNameList = @()
       $HostIdList = @()
       foreach ($host in $hosts)
       {  
          $hostId = ($host).id
          $name = ($host).Name
          Log-Message "Host Name: $name"
          $index = $name.IndexOf("-DSSC") 
          if ( $index -gt -1)
          { 
             $HostNameList += $name
             $HostIdList += $hostId
          }

          if ($HostIdList.Count -eq 0) 
          {
		    Log-Message "No Host Initiators with -DSSC in hostName found on the array!!"
	      }
         
       }
       return $HostIdList,$HostNameList 
    }

 }


function Set-HostDetails
{
[CmdletBinding()]
Param
    (
         [Parameter(Mandatory=$true, Position=0)]
         [string] $hostId,
         [Parameter(Mandatory=$true, Position=1)]
         [string] $hostName
    )
    process
    {
       Log-Message "Editing host detail of host Id $hostId"
       $MyAdd = 'host-initiators/' + $hostId

       #$newHostName = $hostName.Trim("-DSCC")
       $newHostName = $hostName.Substring(0,($hostName.Length -5))
       Log-Message "Updating the host name to $newHostName with URL $MyAdd"
       $MyBody = @{name=$newHostName}  
       $response = Invoke-DSCCrestmethod -UriAdd $MyAdd -method PUT -Body ( $MyBody | convertto-json ) -whatifBoolean $WhatIf
       Log-Message " Response: $response"
       $responseCount = ($response | measure).Count
       if ($responseCount -eq 0) 
       {
		 Log-Message "host $hostName Could not be updated"
		 return
	   } else {
          $taskId = ($response).taskUri 
          Log-Message "Task Id of the edit host operaton is $taskId"
          WaitForTaskToComplete $taskId      
       } 
 
    }

 }


Function WaitForTaskToComplete()
{
 param
    (
    [Parameter(Mandatory=$true, Position=0)]
    [string] $taskId
    )
    process
    {
        Log-Message "Getting task status of task $taskId and waiting for task to complete"
        $maxRetryCount = 12
        $retryCount = 0
        do {
           Start-Sleep 5 
           $MyAdd = 'tasks/' + $taskId
           $tast = Invoke-DSCCrestmethod -UriAdd $MyAdd -method Get -whatifBoolean $WhatIf
           $resposeCount = ($tast | measure).Count
           if ($resposeCount -eq 0)  {
               Log-Message "Unable to get task status"
               return
           }
           $taskStatus = ($tast).State
           Log-Message "The task status is $taskStatus"
           $retryCount++

       } while ($taskStatus -eq 'RUNNING' -and $retryCount -lt $maxRetryCount)
    }
}

Function Log-Message()
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