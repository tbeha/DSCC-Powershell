function Invoke-ConvertHost
{
<#
.SYNOPSIS
    Returns the HPE DSSC DOM Hosts Collection    
.DESCRIPTION
    Returns the HPE Data Services Cloud Console Data Operations Manager Host Collections;
.PARAMETER WhatIf
    The WhatIf directive will show you the RAW RestAPI call that would be made to DSCC instead of actually sending the request.
    This option is very helpful when trying to understand the inner workings of the native RestAPI calls that DSCC uses.
.EXAMPLE
    PS:> Get-DSCCHost | convertTo-Json

    {
    "id":  "733b0e0808c3469d8a8650974cac8847",
    "name":  "TestHostInitiator1",
    "ipAddress":  null,
    "fqdn":  null,
    "operatingSystem":  "Windows Server",
    "systems":  [
                    "0006b878a5a008ec63000000000000000000000001",
                    "2M202205GF"
                ],
    "associatedSystems":[
                            "0006b878a5a008ec63000000000000000000000001"
                        ],
    "userCreated":  true,
    "hostGroups":  [
                        {
                            "id":  "3ea6d00cb589489c94d928f41ca5ad28",
                            "name":  "TestHostGroup1",
                            "userCreated":  true,
                            "systems":  "0006b878a5a008ec63000000000000000000000001 2M202205GF",
                            "markedForDelete":  false
                        }
                    ],
    "comment":  null,
    "protocol":  null,
    "customerId":  "ffc311463d8711ecbdd5428607ee1704",
    "type":  "host-initiator",
    "generation":  1638468553,
    "consoleUri":  "/data-ops-manager/host-initiators/733b0e0808c3469d8a8650974cac8847",
    "initiators":  [
                        {
                            "id":  "00bace011e774445b208858e2545a048",
                            "ipAddress":  null,
                            "address":  "c0:77:2f:58:5f:19:00:50",
                            "name":  "Host Path C0772F585F190050 (1:3:1)",
                            "protocol":  "FC",
                            "systems":  "0006b878a5a008ec63000000000000000000000001 2M202205GF"
                        }
                    ],
    "location":  null,
    "persona":  null,
    "subnet":  null,
    "markedForDelete":  false,
    "editStatus":  "Not_Applicable",
    "associatedLinks":  [
                            {
                                "type":  "initiators",
                                "resourceUri":  "/api/v1/initiators?filter=hostId in (733b0e0808c3469d8a8650974cac8847)"
                            },
                            {
                                "type":  "host-groups",
                                "resourceUri":  "/api/v1/host-initiator-groups?filter=hostId in (733b0e0808c3469d8a8650974cac8847)"
                            }
                        ],
    "model":  null,
    "contact":  null
}
.EXAMPLE
    PS:> Get-DSCCHost

    id                               name               operatingSystem protocol type
    --                               ----               --------------- -------- ----
    733b0e0808c3469d8a8650974cac8847 TestHostInitiator1 Windows Server           host-initiator
.EXAMPLE
    PS:> Get-DSCCHostServiceHost | where { $_.id -like 'f0b1edd8f8984c8db9e596f25de0bdf4' )

    id                               name               operatingSystem protocol type
    --                               ----               --------------- -------- ----
    f0b1edd8f8984c8db9e596f25de0bdf4 TestHostInitiator1 Windows Server           host-initiator
.LINK
    The API call for this operation is file:///api/v1/host-initiator-groups
#>   
[CmdletBinding()]
param(
    )
process
    {   
        $MyAdd = 'storage-systems'   
        $Sys = Invoke-DSCCrestmethod -UriAdd $MyAdd -method Get -whatifBoolean $WhatIf
        $Sys = $Sys | measure
        Write-Host $Sys.Count
        If ( $Sys.Count -eq 0 ) 
        {   
            Write-Warning "No system found. Ensure that you have connected to a HPE Data Storage Cloud Services using Connect-DSCC command."
            return
        } 

        $HostToUpdate1 = $false
        $HostToUpdate2 = $false
        $InitList = Get-CommonHosts

        Write-Host "Total number of items is: "+ $InitList.Count
       

        if ($InitList.Count -eq 0) 
        { 
            Write-Information "No host found to perform merge operation."
        } else {
            $HostToUpdate1 = Get-Choice
	        foreach ($intiator in $InitList) 
            {
                  $hostName, $os, $initiatorList = Get-HostDetailsByInitiatorId $intiator
                  if ($initiatorList.Count -gt 0)
                  {
                        Write-Host "Host $hostName to be merged for initiator id $intiator"  
                        if ($HostToUpdate1 -eq $true)
                        {
                            Write-Host "Creating host $hostName" 
                            Create-NewHost $hostName $os $InitList
                        }
                  } 
                  else
                  {
                      Write-Host "No host to be merged for initiator id $intiator"
                  } 
            }

            if ($HostToUpdate1 -eq $true) 
            {
		       Write-Host "Submitted requests to create DSCC hosts successfully. Verify if the hosts are created from DSCC UI"
            }
        }
	
     	Write-Host "Convert Hosts to DSSC Hosts from connected Alletra Systems"

        $InitList = Get-SingleDisoveredHost

        if ($InitList.Count -eq 0) 
        { 
            Write-Information "No system host found to covert to DSCC host."
        } else {

            $HostToUpdate2 = Get-Choice
        
	        foreach ($intiator in $InitList) 
            {
                 $hostName, $os, $initiatorList = Get-SingleHostDetailsByInitiatorId $intiator

                if ($HostToUpdate2 -eq $true)
                {
                    Write-Host "Creating host $hostName" 
                    Create-NewHost $hostName $os $InitList
                }
            }

            if ($HostToUpdate2 -eq $true) 
            {
		       Write-Host "Submitted requests to create DSCC hosts successfully. Verify if the hosts are created from DSCC UI"
            }
        }

        if ($HostToUpdate1 -or $HostToUpdate2) 
        {       
             $hostIdList, $hostNameList = Get-HostDetailsByName
             Write-Host "No of Hosts which needs to be Updated Back to original HostName is " + ($hostIdList).Count
              For ($i=0; $i -lt $hostIdList.Count; $i++) {
                Set-HostDetails $hostIdList[$i] $hostNameList[$i]
             }
              Write-Host "Task for all the Hosts which has HostName -DSSC is submitted successfully"
             
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
               Write-Host "For the intiator found more than two hosts"
               $userCreatedHostFound = $false
               foreach ($host in ($intiator).hosts)
               {
                  Write-Host "Individual Host $host"
                  $UserCreated = ($host).UserCreated
                  $InitId = ($intiator).id
                  $hostName = ($host).Name
                  if ( $UserCreated -eq $false ) 
                  {
					Write-Host "Initiator Found $InitId associated with $hostName which is Discovered Host"
					$userCreatedHostFound = $true
				  } 
                  else 
                  {
					Write-Host "Initiator Found $InitId associated with $hostName which is User Created Host"
					$userCreatedHostFound = $false
					break
				  }
               }
               if ($userCreatedHostFound -eq $true)
               {
                    Write-Host "Adding initiator $InitId in the list."
                    $InitiatorsList += $InitId
               }
            }

         }

         if ($InitiatorsList.Count -eq 0) 
         {
		    Write-Host "initiator with merged host not found on the Array"
	     }
         return $InitiatorsList    
     }
 }

function Get-Choice
{

[CmdletBinding()]
param(
    )
process
    {

        $title    = 'Do you want to update the Host Definition?'
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
       Write-Host "Getting host detail from initiator Id $InitId"
       $MyAdd = 'host-initiators?filter=initiatorId%20eq%20' + $InitId   
       $hosts = Invoke-DSCCrestmethod -UriAdd $MyAdd -method Get -whatifBoolean $WhatIf
       $hostCount = ($hosts | measure).Count
       if ($hostCount -eq 0) 
       {
		 Write-Host "No host found"
		 return "", "", @()
	  }
   
      $matchedOperatingSystem = ""
      
      foreach ($host1 in $hosts)
      {    Write-Host $host 
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
            if (($host1).operatingSystem -ne ($host1).operatingSystem)
            {
                Write-Host "host operating system is not matching"
                continue
            }

            $matchedOperatingSystem = ($host1).operatingSystem
            $host1InitCount = (($host1).Initiators | measure).Count
            $host2InitCount = (($host2).Initiators | measure).Count

            Write-Host "Number of initiator in host1 $host1InitCount and number of initiator in host2 $host2InitCount"

            <# Complare the initiator list #>
            if ($host1InitCount -ne $host2InitCount)
            {
                Write-Host "host initiator count is not matching"
                continue
            }

             $initListMatched = $true
             foreach ($Initiator1 in  $InitiatorsList1)
             {
                foreach ($Initiator2 in  $InitiatorsList2)
                {
                    $Init1Id = ($Initiator1).id
                    $Init2Id = ($Initiator2).id

                    if ($Init1Id -ne $Init2Id) {
                       $initListMatched = $false
                       Write-Host "host initiators list is not matching"
                       break

                    }
                }
            }

            if ($initListMatched -eq $true) {
               Write-Host "host initiator count matched"   

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
		     Write-Host "Failed to create the Host with name $hostName"
		     return
	    }
        else
        {
          Write-Host "Host with HostName $newHostName is created successfully."
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

     Write-Host "Getting discovered/system hosts"
     foreach ($intiator in $intiators)
     {
          $HostCount = (($intiator).hosts | measure).Count
          if ($HostCount -eq 1)
          {    $hosts =  ($intiator).hosts
               Write-Host "Found single discovered Host for the initiator"
               $userCreatedHostFound = $false
               foreach ($host in ($intiator).hosts)
               {
                  Write-Host "Individual Host $host"
                  $UserCreated = ($host).UserCreated
                  $InitId = ($intiator).id
                  $hostName = ($host).Name
                  if ( $UserCreated -eq $false ) 
                  {
					Write-Host "Initiator found $InitId associated with $hostName which is Discovered Host"
					$userCreatedHostFound = $false
				  } 
                  else 
                  {
					Write-Host "Initiator found $InitId associated with $hostName which is User Created Host"
					$userCreatedHostFound = $true
					break
				  }
               }
               if ($userCreatedHostFound -eq $false)
               {
                    Write-Host "Adding initiator $InitId in the list."
                    $InitiatorsList += $InitId
               }
            }

         }

         if ($InitiatorsList.Count -eq 0) 
         {
		    Write-Host "initiator with single discovered host not found on the Array!!"
	     }
         
         Write-Host "Initiator with single discovered host found on the Array: " + $InitiatorsList.Count
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
       Write-Host "Getting host detail from initiator Id $InitId"
       $MyAdd = 'host-initiators?filter=initiatorId%20eq%20' + $InitId   
       $hosts = Invoke-DSCCrestmethod -UriAdd $MyAdd -method Get -whatifBoolean $WhatIf
       $hostCount = ($hosts | measure).Count
       if ($hostCount -eq 0) 
       {
		 Write-Host "No host found"
         return "", "", $InitiatorsList
	  }
      if ($hostCount -gt 1) 
      {
	 	  Write-Host "Initiator is common for more than one host, so skipping"
          return "", "", $InitiatorsList
  	  }

      $host = $hosts[0]
      Write-Host $host 
      $InitiatorsList = @()
      foreach ($Initiator in ($host).Initiators) {
         $InitId = ($Initiator).id
         $InitiatorsList += $InitId
      }

     $hostId = ($host).id
     Write-Host "Host Id: $hostId"

     $os = ($host).OperatingSystem
     Write-Host "Operating System: $os"

     $name = ($host).Name
     Write-Host "Host Name: $name"
          
    if ($os -eq "")
    {
	   $os = "VMware (ESXi)"
	}

    Write-Host "Initiator List: $InitiatorsList"
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
       Write-Host "Getting host detail"
       $MyAdd = 'host-initiators'   
       $hosts = Invoke-DSCCrestmethod -UriAdd $MyAdd -method Get -whatifBoolean $WhatIf
       $hostCount = ($hosts | measure).Count
       if ($hostCount -eq 0) 
       {
		 Write-Host "No host found"
		 return
	   }
       $HostNameList = @()
       $HostIdList = @()
       foreach ($host in $hosts)
       {  
          $hostId = ($host).id
          $name = ($host).Name
          Write-Host "Host Name: $name"
          $index = $name.IndexOf("-DSSC") 
          if ( $index -gt -1)
          { 
             $HostNameList += $name
             $HostIdList += $hostId
          }

          if ($HostIdList.Count -eq 0) 
          {
		    Write-Host "No Host Initiators with -DSSC in hostName found on the array!!"
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
       Write-Host "Editing host detail of host Id $hostId"
       $MyAdd = 'host-initiators/' + $hostId
       $newHostName = $hostName.Trim("-DSCC")
       Write-Host "Updating the host name to $newHostName with URL $MyAdd"
       $MyBody = @{name=$newHostName}  
       $response = Invoke-DSCCrestmethod -UriAdd $MyAdd -method PUT -Body ( $MyBody | convertto-json ) -whatifBoolean $WhatIf
       Write-Host " Response: $response"
       $responseCount = ($response | measure).Count
       if ($responseCount -eq 0) 
       {
		 Write-Host "host $hostName Could not be updated"
		 return
	   }
    }

 }
