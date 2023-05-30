# Get the Powershell Toolkit for the DSCC

# Download the PowerShell ToolKit from github.com and store it in the PowerShell Modules Directory

# check module directory

#$env:PSModulePath -split ';'

#URL: https://github.com/HewlettPackard/HPEDSCC-PowerShell-Toolkit
#$FOLDER = 'C:\Windows\System32\WindowsPowerShell\v1.0\Modules'
#invoke-webrequest -uri $PSTK -outfile “MyFile.zip"
#expand-archive -path “MyFile.zip" -DestinationPath $FOLDER 

# import the module

Import-Module HPEDSCC

# and connect to the DSCC

