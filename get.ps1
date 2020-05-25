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


function get:processScript ($context) {

	$ps1File = scripts:select $context.Request.Url.AbsolutePath $context.Request.HttpMethod
	if (-not $ps1File) {
		return $false
	}

	$reqFolder = util:dumpRequestToFolder $context.Request
	$responseObj = scripts:runner -request $context.Request -scriptToRun $ps1File -requestFolder $reqFolder.FullName
	Remove-Item $reqFolder -Recurse -Force

	if ($responseObj) {
		$context.Response.StatusCode = $responseObj.HttpStatus
		if ($responseObj.Error) {
			$context.Response.StatusDescription = $responseObj.Error
		}
		else {
			if ($responseObj.StatusDescription) {
				$context.Response.StatusDescription = $responseObj.StatusDescription
			}
			if ($responseObj.Buffer -and $responseObj.Buffer.Length -gt 0) {
				$context.Response.ContentType = $responseObj.Mime
				$context.Response.ContentEncoding = $responseObj.Encoding
				$context.Response.ContentLength64 = $responseObj.Buffer.Length
				$context.Response.OutputStream.Write($responseObj.Buffer, 0, $responseObj.Buffer.Length)
			}
		}
	}
	else {
		$context.Response.StatusCode = [int][Net.HttpStatusCode]::InternalServerError
		$context.Response.StatusDescription = 'null script output (?!)'
	}

	return $true
}

function httpGet($context) {

	$quit = $false
	$buffer = @()
	$context.Response.StatusCode = [int][Net.HttpStatusCode]::OK

	if ($context.Request.Url.AbsolutePath -eq $ServerConfig.quitUrl) {
		$quit = $true
	}
	elseif (-not (get:processScript $context)) {
		$resource = util:findResource -request $context.Request
		if ($null -eq $resource) {

			logWarning "resource not found"
			$context.Response.StatusCode = [int][Net.HttpStatusCode]::NotFound

		}
		elseif ($resource.StartsWith("`n")) {

			$resource = $resource.Substring(1)
			logWarning "redirecting client to: $resource"
			$context.Response.Redirect($resource)

		}
		else {

			logInfo "fetching resource: $resource"
			$context.Response.ContentType = util:getFileMime $resource
			$buffer = [IO.File]::ReadAllBytes($resource)

		}
	}

	if ($buffer.Length -gt 0) {

		$mime = $context.Response.ContentType
		if ($mime -and $mime.StartsWith('text/')) {
			$context.Response.ContentEncoding = [Text.Encoding]::UTF8
		}
		$context.Response.ContentLength64 = $buffer.Length
		$context.Response.OutputStream.Write($buffer, 0, $buffer.Length)

	}

	return $quit
}
