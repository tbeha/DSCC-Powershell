Import-Module .\HPEDSCC.psd1 -SkipEditionCheck #-Verbose

[xml]$xml = Get-Content -Path ./dscc.xml
$Client_ID = $xml.DSCC.ClientID 
$Client_Secret = $xml.DSCC.ClientSecret

$doc = Select-Xml -Xml $xml -XPath /DSCC | Select-Object -ExpandProperty Node 
$doc | Format-List

# Read the System Ids
$SystemIds =@{}
foreach($sys in (Select-Xml -Xml $xml -XPath /DSCC/SystemIds | Select-Object -ExpandProperty Node).System){
	$SystemIds = $SystemIds + @{$sys.Name = $sys.Id}
}
$ystemIds | Format-Table

# Read the VolumeSets and the volumes

$VolumeSetName = $xml.DSCC.VolumeSet.Name
$Volumes = @{}
foreach($vol in (Select-Xml $xml -XPath /DSCC/VolumeSet | Select-Object -ExpandProperty Node).Volume){
	$Volumes = $volumes +@{$vol.name = @{size= $vol.size; system=$vol.system}}
}
$VolumeSetName
$Volumes | Format-Table



