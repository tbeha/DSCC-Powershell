<# Get the Powershell Toolkit for the DSCC

# Download the PowerShell ToolKit from github.com and store it in the PowerShell Modules Directory

# check module directory

#$env:PSModulePath -split ';'

#URL: https://github.com/HewlettPackard/HPEDSCC-PowerShell-Toolkit
#$FOLDER = 'C:\Windows\System32\WindowsPowerShell\v1.0\Modules'
#invoke-webrequest -uri $PSTK -outfile “MyFile.zip"
#expand-archive -path “MyFile.zip" -DestinationPath $FOLDER 

Get PowerShell 7:

winget search Microsoft.PowerShell
winget install --id Microsoft.Powershell --source winget
winget install --id Microsoft.Powershell.Preview --source winget

#>
# import the module

Import-Module .\HPEDSCC.psd1 -SkipEditionCheck

# and connect to the DSCC 

$ClientID = Read-Host "Enter the DSCC Client ID: " -AsSecureString
$ClientSecret = Read-Host "Enter the DSCC Client Secret: " -AsSecureString


$AuthToken = Connect-DSCC -Client_Id $Client_ID -Client_Secret $Client_Secret -GreenlakeType EU -Verbose #-Autorenew

$AuthToken | Format-List

$Response = Get-DSCCStorageSystem
$Response | Format-List

<#
$AuthUri = "https://sso.common.cloud.hpe.com/as/token.oauth2"
$AuthHeaders =  @{  'Content-Type' = 'application/x-www-form-urlencoded'
}
$AuthBody    = [ordered]@{   'grant_type' = 'client_credentials'
                                                'client_id' = $Client_Id
                                                'client_secret' = $Client_Secret
                        }

$AccessToken = ( Invoke-RestMethod -uri $AuthURI -Method Post -headers $AuthHeaders -body $AuthBody ).access_token

#$AccessToken = "eyJhbGciOiJSUzI1NiIsImtpZCI6ImhscU5ySGxEUEVfRlZDaEt2NmZvd2N0dkhSdyIsInBpLmF0bSI6ImRlejAifQ.eyJjbGllbnRfaWQiOiJjYWJhOTZiYS01MmM5LTQ5ZTUtOGFlNy1lZWMzMDFlMzAwMGEiLCJpc3MiOiJodHRwczovL3Nzby5jb21tb24uY2xvdWQuaHBlLmNvbSIsImF1ZCI6ImV4dGVybmFsX2FwaSIsInN1YiI6InRob21hcy5iZWhhQGhwZS5jb20iLCJ1c2VyX2N0eCI6ImIyYTIwMjZjMzdlOTExZWNiYWE2NjIzMTY4YjJjODFkIiwiYXV0aF9zb3VyY2UiOiJjY3NfdG9rZW5fbWFuYWdlbWVudCIsInBsYXRmb3JtX2N1c3RvbWVyX2lkIjoiMGMyMzc5YjAzN2U1MTFlY2EzYjdkMjg1NDAyYzRmYWEiLCJpYXQiOjE2ODU1MTYyOTgsImFwcGxpY2F0aW9uX2luc3RhbmNlX2lkIjoiZWY4N2YzOWMtNDMwZC00MDc3LWJkZWQtOGE2N2YxYTk0MTdiIiwiZXhwIjoxNjg1NTIzNDk4fQ.NqQ5fMCy1RVIqX0xTIoiZU_PL69XXaVHzMxjGbRp1ePCpR33bpibYZ2hk69JIPrL7vunfrCvOWtbL8jkFs7QN4pjsZWjyemgUKD1PDU-_VWvrkC0XMez226NFs3NvBWz-LVaLnu26eThd-fvYCkBoZv92zzLzLz0ViKUK6N89_JtemQUgLManxG-25rV-T3hgI8RWFjI2IfRrCaHjgNMHiOT2kgwn3Nf9igaCbp_frwJGDOu7_1R-4CfVRppAKqxH_LDGxN6s9aiC4dXbONSWRA3Z2Zze9BKgZA2MZFUDVQBiQMU4Xg2M4RjQwyzyYDNeNVh4M8tdaOcZ8cQ5AIaIw"
$MyHeaders   =  @{  Authorization = 'Bearer '+ $AccessToken
                            }
$BaseUri =   "https://eu1.data.cloud.hpe.com/api/v1/"  

$Uri = $BaseUri + 'storage-systems'

$Response =  Invoke-RestMethod -uri $Uri -Method Get -Headers $MyHeaders 

$Response | Format-List
#>