<#
Copyright (c) 2020 Alex Vargas

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
#>


function scripts:select ($reqPath, $method) {
	$scriptToRun = $null
	if ($null -ne $ServerConfig.psScripts) {
		if ($null -ne $ServerConfig.psScripts."$method") {
			$allScripts = $ServerConfig.psScripts."$method"
			if ($null -ne $allScripts."$reqPath") {

				$absolute = $false
				$p = $allScripts."$reqPath"
				if ($p.StartsWith('/') -or $p.StartsWith('\')) {
					$p = '.' + $p
				}
				else {
					$absolute = [IO.Path]::IsPathRooted($p)
					if (-not $absolute) {
						$p = './' + $p
					}
				}

				if (-not $absolute) {
					$p = "$ServeLocation/$p"
				}

				$scriptToRun = (Get-Item $p).FullName
			}
		}
	}
	return $scriptToRun
}

function scripts:newResponseObject {
	return @{
		HttpStatus        = [int][Net.HttpStatusCode]::NotImplemented;
		Error             = $null;
		StatusDescription = $null;
		Buffer            = $null;
		Mime              = 'application/octet-stream';
		Encoding          = 'ascii'
	}
}

function scripts:runner {
	param (
		$request,
		[string]$scriptToRun,
		[string]$requestFolder
	)

	if (-not $scriptToRun) {
		logWarning "null sript file requested"
		return $null
	}

	try {

		$scrpt = Get-Item $scriptToRun -ErrorAction SilentlyContinue

		if (-not $scrpt -or -not $scrpt.Exists) {
			throw 'script does not exist'
		}

		$resp = scripts:newResponseObject
		$resp = & "$scrpt" $request $requestFolder $resp

		if (-not $resp) {
			throw 'null script output'
		}

		if (-not $resp.HttpStatus) {
			throw 'invalid script response'
		}

		if (-not $resp.Encoding) {
			$resp.Encoding = [Text.Encoding]::ASCII
		}

		if ($resp.Encoding -isnot [System.Text.Encoding]) {
			$resp.Encoding = util:stringToEncoding("$($resp.Encoding)")
		}

		return $resp
	}
	catch {
		logError "exception running script $scriptToRun`: $_"
		$resp = scripts:newResponseObject
		$resp.HttpStatus = [int][Net.HttpStatusCode]::InternalServerError
		$resp.Error = $_
		return $resp
	}
}