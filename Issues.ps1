Import-Module .\HPEDSCC.psd1 -SkipEditionCheck #-Verbose

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
Function Get-DSCCIssues() {
    <#
    
    #>

	$Uri = $Base + '/api/v1/issues'


    try{
    	return Invoke-RestMethod -Uri $Uri -Method 'GET' -Headers $MyHeaders -ContentType 'application/json'
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

Connect-DSCC -Client_Id $Client_ID -Client_Secret $Client_Secret -GreenlakeType EU #-Verbose -AutoRenew

$Response = (Get-DSCCIssues).items
$Response | Format-Table
