<#
=========================================================================
PSModuleInstaller Copyright (c) 2020 Alex Vargas

This software is provided 'as-is', without any express or implied
warranty. In no event will the authors be held liable for any damages
arising from the use of this software.

Permission is granted to anyone to use this software for any purpose,
including commercial applications, and to alter it and redistribute it
freely, subject to the following restrictions:

1. The origin of this software must not be misrepresented; you must not
   claim that you wrote the original software. If you use this software
   in a product, an acknowledgment in the product documentation would be
   appreciated but is not required.
2. Altered source versions must be plainly marked as such, and must not be
   misrepresented as being the original software.
3. This notice may not be removed or altered from any source distribution.

NOTICE: This license is applicable to the PSModuleInstaller.ps1 code,
and to the generated ps1 installer as well.
It does not apply to the module being installed.
=========================================================================
#>
function appendZipToFile($zip, $modName) {
	try {
		$file = New-Item "$($env:TEMP)/$([guid]::NewGuid()).ps1"
		$totalRead = 0
		$stream = [IO.File]::OpenRead($zip)
		$reader = [IO.BinaryReader]::new($stream)
		$appender = [IO.File]::AppendText($file)

		$ownFileContent = Get-Content $PSCommandPath -Raw

		$appender.Write($ownFileContent)
		$appender.Write("`n`n`$ThisModuleName = '$modName'")
		$appender.Write("`n`n`$base64Zip = @`"`n")
		[byte[]]$bytes = New-Object byte[] -ArgumentList 10485760

		$bufferStart = 0;
		while ($totalRead -lt $stream.Length) {
			$read = $reader.Read($bytes, $bufferStart, $bytes.Length - $bufferStart)

			if ($read -gt 0) {

				$totalRead += $read
				$compute = $read + $bufferStart
				$remainder = $compute % 3
				$lastIndex = $compute - $remainder - 1
				if ($lastIndex -gt 0) {
					$str = [Convert]::ToBase64String($bytes[0..($lastIndex)])
					$appender.Write($str)
					$lastIndex++
					for ($i = 0; $i -lt $remainder; ++$i) {
						$bytes[$i] = $bytes[$lastIndex + $i]
					}
					$bufferStart = $i
				}
				else {
					$bufferStart += $read
				}
			}
		}

		if ($bufferStart -gt 0) {
			$str = [Convert]::ToBase64String($bytes[0..($bufferStart - 1)])
			$appender.Write($str)
		}

		$appender.Write("`n`"@`n`n")
		$appender.Write('installXModule')

		return $file
	}
	finally {
		if ($appender) { $appender.Close() }
		if ($reader) { $reader.Close() }
		if ($stream) { $stream.Close() }
	}
}

function New-ModuleInstaller {
	param(
		[Parameter(Mandatory)]
		$ModuleSource,

		[string]
		$OutputPath = '.'
	)

	$ModuleSource = Get-Item $ModuleSource
	if (-not (Test-Path $ModuleSource -PathType Container)) {
		Write-Error "not a directory: $ModuleSource"
		return
	}

	$OutputPath = Get-Item $OutputPath
	$OutputFile = Join-Path $OutputPath "Install-$($ModuleSource.Name).ps1"

	if (Test-Path $OutputFile -PathType Leaf) {
		Write-Error "file already exists: $OutputFile"
		return
	}

	$zip = "$($env:TEMP)/b06976a945d5-$(Get-Random).zip"
	Compress-Archive -Path $ModuleSource -DestinationPath $zip -CompressionLevel Optimal
	$zip = (Get-Item $zip).FullName
	$installer = appendZipToFile $zip $ModuleSource.Name

	Move-Item $installer $OutputFile
	Write-Host "Success: $OutputFile" -ForegroundColor Green
}

function installXModule {

	if (-not $ThisModuleName) {
		Write-Error 'missing module name'
		return -1
	}

	if (-not $base64Zip) {
		Write-Error 'missing binary data'
		return -2
	}

	Write-Host "Installing $ThisModuleName"
	$zip = "$($env:TEMP)/b06976a945d5-$(Get-Random)-$ThisModuleName.zip"

	try {
		$bytes = [Convert]::FromBase64String($base64Zip)
		[IO.File]::WriteAllBytes($zip, $bytes)

		if (-not (Test-Path $zip)) {
			throw
		}
	}
	catch {
		Write-Error 'failed to decode binary data'
		return -3
	}

	$psModulePaths = $env:PSModulePath -split ';' | Where-Object { if (-not $_.StartsWith($env:windir)) { $_ } } | Sort-Object
	Write-Host ''
	Write-Host 'Where to install?'

	$i = 1;
	$psModulePaths | ForEach-Object {
		Write-Host "$i. $_"
		$i++
	}
	Write-Host "$i. Abort"

	do {
		$c = Read-Host 'Your choice'
		try {
			$c = [int]$c
		}
		catch {
			$c = 0
		}
	} while ($c -gt $i -or $c -lt 1)

	if ($c -eq $i) {
		Write-Host 'module not installed, good bye'
		return
	}

	$installDir = $psModulePaths[$c - 1]

	Write-Host "Selected install dir: $installDir"

	if (-not (Test-Path $installDir)) {
		Write-Error "installdir does not exist: $installDir"
		return -4
	}

	if (Test-Path "$installDir/$ThisModuleName") {
		Write-Error "Module $ThisModuleName already exists in $installDir"
		return -5
	}

	Expand-Archive $zip -DestinationPath $installDir

	if (Test-Path "$installDir/$ThisModuleName") {
		Write-Host "Successfully installed $ThisModuleName in $installDir"
		return 0
	}

	Write-Error "Failed to install $ThisModuleName in $installDir, probably bad zip file. Check that folder for garbage."
	return -6
}