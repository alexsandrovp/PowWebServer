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


<#
.Synopsis
Start-PowWebServer starts a new instance of the POW web server.

.Description
The Start-PowWebServer function starts a new instance of the POW web server.
The web server will listen on the specified protocol/address/port binding and serve the specified folder.
Supports http and https. Note: serving with https will require that you create an https certificate
and bind it to the necessary interface/port. See about_POW_Certificates.

.Parameter ServeLocation
Specifies the path containing the files to be served.
Enter a relative or absolute path on the local computer.

.Parameter Protocol
Binding protocol. Can be http or https.

.Parameter Address
Binding address. Usually an ip or dns name.
Also accepts + (listens on all interfaces) and * (same as +,
but only if the request has not been handled yet)

.Parameter Port
Binding port.
The default is 8080 for http and 8443 for https

.Parameter Browse
A switch indicating that your default browser will be launched to load the specified protocol://address:port.

.Link
about_POW_Configuration
about_POW_Scripts
about_POW_Certificates

.Notes
Calling this function without parameters will start a server listening on http://localhost:8080
Some protocol/port combinations may require elevated privileges to bind to.
If that is the case, start powershell using 'Run as administrator'
As any console script, execution may halt if the user selects text in the console output.
Hit ENTER to resume execution. To avoid the problem altogether, use Powershell ISE instead of the normal console.
To stop the server, send a GET request to the configured quit url ('/quit' by default).
You can use Invoke-WebRequest for that purpose. See examples.
It is not advisable to simply close powershell without sending the quit command, because
that can leave temporary files in your hard disk.

.Example
PS> Start-PowWebServer

Starts a server listening at http://localhost:8080
Serves the content at powershell's current directory
.Example
PS> Start-PowWebServer -Protocol https

Starts a server listening at https://localhost:8443
Serves the content at powershell's current directory
.Example
PS> Start-PowWebServer -Protocol https -Port 443

Starts a server listening at https://localhost:443
Serves the content at powershell's current directory
.Example
PS> Start-PowWebServer D:\myWebsite -Port 80

Starts a server listening at http://localhost:80
Serves the content at D:\myWebsite
.Example
PS> Start-PowWebServer -Address 192.168.2.3 -ServeLocation D:\myWebsite

Starts a server listening at http://192.168.2.3:8080
Serves the content at D:\myWebsite
.Example
PS> Start-PowWebServer -Protocol https -Address 192.168.2.3 -Port 8888 -Browse -ServeLocation D:\myWebsite

Starts a server listening at https://192.168.2.3:8888
Serves the content at D:\myWebsite
Launches your default browser at https://192.168.2.3:8888
.Example
PS> Invoke-WebRequest http://localhost:8080/quit

Will stop a POW web server previously started at http://localhost:8080
(assuming that the quit url is the default '/quit')
#>
function Start-PowWebServer {

	param(

		[string]
		[Parameter (Position = 0)]
		$ServeLocation = (Get-Item .).FullName,

		[ValidateSet ('http', 'https')]
		[string]
		$Protocol = 'http',

		[string]
		$Address = 'localhost',

		[int]
		$Port = -1,

		[switch]
		$Browse
	)

	begin {
		$SessionTempFolder = New-Item -Path ([System.IO.Path]::GetTempPath()) -Name (Get-Date).Ticks -ItemType Directory
		$SessionTempFolder = $SessionTempFolder.FullName

		if ($Port -lt 0) {
			if ($Protocol -eq 'https') {
				$Port = 8443;
			} else {
				$Port = 8080;
			}
		}
	}

	process {

		try {

			if (-not (Test-Path $ServeLocation)) {
				Write-Error "Path does not exist: $ServeLocation"
				return
			}
			$ServeLocation = (Get-Item $ServeLocation).FullName

			$HomeLocation = (Get-Item "$PSScriptRoot").FullName
			if (-not (Test-Path $HomeLocation)) {
				Write-Error "Path does not exist: $HomeLocation"
				return
			}

			$ServerConfig = util:loadServerConfig
			logVerbose "loaded server configuration ($($ServerConfig.Keys.Count) keys)"

			$AllMimeTypes = util:loadAllMimeTypes
			logVerbose "loaded $($AllMimeTypes.Keys.Count) mime types"

			$serverUrl = "$Protocol`://$Address`:$Port/"
			Write-Host "Server binding: $serverUrl"
			Write-Host "Serving folder: $ServeLocation"
			Write-Host "Session folder: $SessionTempFolder"

			$quit = $false
			$http = [System.Net.HttpListener]::new()
			$http.Prefixes.Add($serverUrl)
			$http.Start()

			if (-not $http.IsListening) {
				throw 'server is not listening'
			}

			if ($Browse) {
				Start-Process "$($serverUrl)"
			}

			while (-not $quit -and $http.IsListening) {

				logInfo "HTTP Server listening"

				$context = $http.GetContext()

				logText "Request from $($context.Request.UserHostAddress) => $($context.Request.HttpMethod) $($context.Request.RawUrl)" -color Cyan
				logText "Referrer url: $($context.Request.UrlReferrer.AbsolutePath)" -color Cyan
				util:logRequestInfo -request $context.Request
				util:logUrl -urlObj $context.Request.Url
				util:logUrl -urlObj $context.Request.UrlReferrer -referrer
				util:logHeaders -headers $context.Request.Headers

				try {

					if ($context.Request.ContentLength64 -gt $ServerConfig.maxPayloadSize) {
						logWarning "request payload exceeds maximum allowed ($($ServerConfig.maxPayloadSize) bytes) and will be ignored"
						$context.Response.StatusCode = 413 # payload too large
					}
					else {
						switch ($context.Request.HttpMethod) {
							'GET' {
								$quit = httpGet -context $context
								break
							}
							'PUT' {
								httpPutPost -context $context
								break
							}
							'POST' {
								httpPutPost -context $context
								break
							}
							default {
								logWarning "method not supported $($context.Request.HttpMethod)"
							}
						}
					}

					if ($context.Response.StatusCode -eq [Net.HttpStatusCode]::NotFound) {
						$buffer = [Text.Encoding]::UTF8.GetBytes("<html><body><p>Not found</p><p>$($context.Request.RawUrl)</p></body></html>")
						$context.Response.ContentEncoding = [Text.Encoding]::UTF8
						$context.Response.ContentLength64 = $buffer.Length
						$context.Response.OutputStream.Write($buffer, 0, $buffer.Length)
					}

				}
				catch {
					logError "Exception processing request`: $error -> $($error.ScriptStackTrace)"
				}

				$context.Response.OutputStream.Close()
			}
		}
		catch {
			logError "$error -> $($error.ScriptStackTrace)"
		}
		finally {
			$http.Stop() | Out-Null
			$http.Close() | Out-Null
			$http.Dispose() | Out-Null
			$http = $null;
		}
	}

	end {
		Write-Host "Server terminated" -ForegroundColor Yellow
		Remove-Item $SessionTempFolder -Recurse -Force
		if (Test-Path $SessionTempFolder) {
			logWarning "Failed to delete session folder: $SessionTempFolder"
		}
	}

}

<#
.Synopsis
New-PowConfig creates a new .powrc.json file.

.Description
This function creates a template json file for advanced configuration of the PowWebServer.
To take effect, this file must reside in the served location before the server is started.

.Parameter OutputFolder
Location where the json file is going to be created.

.Link
about_POW_Configuration

.Example

PS> New-PowConfig

Generates .powrc.json at the current folder

.Example

PS> New-PowConfig -OutputFolder d:\temp

Generates d:\temp\.powrc.json

.Example

PS> gi d:\temp | New-PowConfig

Generates d:\temp\.powrc.json

#>
function New-PowConfig {
	param(
		[Parameter(ValueFromPipeline = $true)]
		[string]
		$OutputFolder = '.'
	)

	$OutputFolder = (Get-Item $OutputFolder -ErrorAction Stop).FullName

	if (Test-Path "$OutputFolder/.powrc.json") {
		$f = Get-Item "$OutputFolder/.powrc.json"
		Write-Error "file already exists: $($f.FullName)"
		return
	}

	$txt = Get-Content "$PSScriptRoot/.powrc.json" -Raw -ErrorAction Stop
	$txt | Set-Content "$OutputFolder/.powrc.json" -Encoding UTF8 -ErrorAction Stop
	if (Test-Path "$OutputFolder/.powrc.json") {
		Write-Host 'New file created'
		Write-Host "$OutputFolder/.powrc.json"
	}
	else {
		Write-Error "'failed to create file at $OutputFolder"
	}
}

<#
.Synopsis
New-PowScript creates a new ps1 file to serve dynamic content with the PowWebServer.

.Description
This function creates a template ps1 file that can be used in the psScripts section
of the config file (.powrc.json). See help about_POW_Scripts for a detailed description
of how to write scripts for the POW server.

.Parameter OutputFolder
Location where the template script is going to be created.
By default, it is the shell's current location (.)

.Parameter Name
Name of the new ps1 file.

.Link
about_POW_Scripts

.Example

PS> New-PowScript

Generates helloWorld.ps1 at the current folder

.Example

PS> New-PowScript -Name getFile

Generates getFile.ps1 at the current folder


.Example

PS> New-PowScript -OutputFolder d:\temp -Name getFile

Generates d:\temp\getFile.ps1

.Example

PS> gi d:\temp | New-PowScript -Name getFile

Generates d:\temp\getFile.ps1

#>
function New-PowScript {
	param(
		[Parameter(ValueFromPipeline = $true)]
		[string]
		$OutputFolder = '.',

		[string]$Name = 'helloWorld.ps1'
	)

	begin {
		if (-not $Name.EndsWith('.ps1')) {
			$Name += '.ps1'
		}
	}

	process {

		$OutputFolder = (Get-Item $OutputFolder -ErrorAction Stop).FullName

		if (Test-Path "$OutputFolder/$Name") {
			$f = Get-Item "$OutputFolder/$Name"
			Write-Error "file already exists: $($f.FullName)"
			return
		}

		$txt = Get-Content "$PSScriptRoot/helloWorld.ps1" -Raw -ErrorAction Stop

		$txt | Set-Content "$OutputFolder/$Name" -Encoding UTF8 -ErrorAction Stop
		if (Test-Path "$OutputFolder/$Name") {
			Write-Host 'New file created'
			Write-Host (Get-Item "$OutputFolder/$Name").FullName
		}
		else {
			Write-Error "'failed to create file at $OutputFolder"
		}
	}

	end {
	}
}