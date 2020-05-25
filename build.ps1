param (
	$Increment = 'Build'
)

$ModuleName = 'PowWebServer'
$OutputFolder = "$($env:temp)/$((Get-Date).Ticks)/$ModuleName"

if (Test-Path $OutputFolder) {
	Write-Error "Output folder already exists: $OutputFolder"
	return
}

$FinalOutput = "./installer/Install-$ModuleName.ps1"
Remove-Item $FinalOutput -ErrorAction SilentlyContinue

if (Test-Path $FinalOutput) {
	Write-Error "Installer already exists: $FinalOutput"
	return
}

$OutputFolder = New-Item $OutputFolder -ItemType Directory -ErrorAction Stop

Copy-Item ".\$ModuleName.psd1" $OutputFolder -Force
Copy-Item .\.powrc.json $OutputFolder -Force
Copy-Item .\about_POW_*.help.txt $OutputFolder -Force
Copy-Item .\mimetypes.json $OutputFolder -Force
Copy-Item .\bytes.ps1 $OutputFolder -Force
Copy-Item .\certificates.ps1 $OutputFolder -Force
Copy-Item .\get.ps1 $OutputFolder -Force
Copy-Item .\headers.ps1 $OutputFolder -Force
Copy-Item .\helloWorld.ps1 $OutputFolder -Force
Copy-Item .\log.ps1 $OutputFolder -Force
Copy-Item .\multipart.ps1 $OutputFolder -Force
Copy-Item .\putpost.ps1 $OutputFolder -Force
Copy-Item .\scriptrunner.ps1 $OutputFolder -Force
Copy-Item .\utils.ps1 $OutputFolder -Force
Copy-Item .\webserver.ps1 $OutputFolder -Force

$psd1f = Get-Item "$OutputFolder\$ModuleName.psd1"
$version = [Version](Get-Content .\version.txt -ErrorAction Stop)
$versionStr = $version.ToString(3)
$psd1 = Get-Content -path $psd1f -Raw
$psd1 = $psd1 -replace "(\s*ModuleVersion\s*=\s*)'\S+'", "`$1 '$versionStr'"
$psd1 | Set-Content -Path $psd1f

. ./PSModuleInstaller.ps1

New-ModuleInstaller -ModuleSource $OutputFolder
Remove-Item "$($OutputFolder.Parent.FullName)" -Recurse -Force

if (-not (Test-Path "./Install-$ModuleName.ps1")) {
	Write-Error 'build failed'
	return
}

Move-Item "./Install-$ModuleName.ps1" $FinalOutput

$ma = $version.Major
$mi = $version.Minor
$b = $version.Build
$r = $version.Revision

switch ($Increment) {
	'Major' { $ma += 1 }
	'Minor' { $mi += 1 }
	'Revision' { $r += 1 }
	default { $b += 1 }
}

"$ma.$mi.$b.$r" | Set-Content .\version.txt