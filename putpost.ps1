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


function httpPutPost($context) {

	$ps1File = scripts:select $context.Request.Url.AbsolutePath $context.Request.HttpMethod
	if ($ps1File) {

		$reqDumpFolder = util:dumpRequestToFolder $context.Request
		if ($context.Request.HttpMethod -eq 'POST') {
			multipart:checkContentType -request $context.Request -requestFolder $reqDumpFolder
		}

		$responseObj = scripts:runner -request $context.Request -scriptToRun $ps1File -requestFolder $reqDumpFolder.FullName

		Remove-Item $reqDumpFolder -Recurse -Force

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
	}
	else {
		$context.Response.StatusCode = [int][Net.HttpStatusCode]::NotFound
	}
}
