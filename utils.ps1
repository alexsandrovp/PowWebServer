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


function util:isElevated ($mustBe = $true) {
	$currentUser = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
	if ($currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
		return $true
	}

	if ($mustBe) {
		Write-Error "Not elevated"
	}
	return $false
}

function util:convertNETTicksToJSTicks($ticks) {
	#difference from 1/1/1 to 1/1/1970
	$jsEpochStart = 62135586000000;
	$netTicksAsMicroseconds = [Math]::Floor($ticks / 10000)
	return $netTicksAsMicroseconds - $jsEpochStart
}

function util:launchTool {
	param($toolPath, $toolArgs, $wait = $true)
	$p = Start-Process -FilePath $toolPath -ArgumentList $toolArgs -NoNewWindow -Wait:$wait -PassThru
	return $p
}

function util:loadAllMimeTypes {
	$mimeTypes = @{ }
	$fileText = Get-Content "$HomeLocation/mimetypes.json" -Raw
	$pso = ConvertFrom-Json $fileText
	$pso.psobject.properties | ForEach-Object { $mimeTypes[$_.Name] = $_.Value }
	return $mimeTypes
}

function util:getFileMime ($fileName) {
	$ext = [IO.Path]::GetExtension($fileName)
	return $AllMimeTypes[$ext]
}

function util:stringToEncoding ($encodingStr) {
	switch -regex ($encodingStr) {
		'^(utf8|utf-8)$' {
			return [Text.Encoding]::UTF8
		}
		'^(utf7|utf-7)$' {
			return [Text.Encoding]::UTF7
		}
		'^(utf32|utf-32)$' {
			return [Text.Encoding]::UTF32
		}
		'^(utf16|utf-16|Unicode)$' {
			return [Text.Encoding]::Unicode
		}
		'^(utf16BE|utf-16BE)$' {
			return [Text.Encoding]::BigEndianUnicode
		}
		'^(asc|ascii|us-ascii|byte)$' {
			return [Text.Encoding]::ASCII
		}
		default {
			try {
				$e = [Text.Encoding]::GetEncoding($encodingStr)
				return $e
			}
			catch {
				return [Text.Encoding]::ASCII
			}
		}
	}
}

function util:loadServerConfig {
	$jsonFile = "$ServeLocation\.powrc.json"
	if ((Test-Path $jsonFile)) {
		$config = Get-Content $jsonFile | ConvertFrom-Json
	}
	else {
		$config = '{}' | ConvertFrom-Json
	}

	if (-not $config.quitUrl) {
		$config | Add-Member -MemberType NoteProperty -Name 'quitUrl' -Value '/quit' -Force
	}

	if (-not $config.maxPayloadSize) {
		$config | Add-Member -MemberType NoteProperty -Name 'maxPayloadSize' -Value 5242880 -Force
	}

	try {
		$config.maxPayloadSize = [int]$config.maxPayloadSize
	}
	catch {
		logWarning 'maxPayloadSize reset to default (invalid configuration in file)'
		$config.maxPayloadSize = 5242880
	}

	if ($config.maxPayloadSize -lt 0) {
		$config.maxPayloadSize = 0
	}

	if (-not $config.quitUrl.StartsWith('/')) {
		$config.quitUrl = '/' + $config.quitUrl
	}

	return $config
}

function util:isVirtualPathRequest($reqPath) {
	$diskLocation = $null
	$virtualResourcePath = $null
	if ($null -ne $ServerConfig.virtualPaths) {
		foreach ($vpath in ($ServerConfig.virtualPaths | Get-Member -type NoteProperty)) {
			if ($reqPath -imatch "^$($vpath.Name)(/.*)?$") {
				$diskLocation = $ServerConfig.virtualPaths."$($vpath.Name)"
				$virtualResourcePath = $reqPath.Substring($vpath.Name.Length)
				break
			}
		}
	}
	if ($diskLocation) {
		if ($virtualResourcePath) {
			return "$diskLocation/$virtualResourcePath"
		}
		else {
			return "$diskLocation"
		}
	}
	return $null
}

function util:mustRedirectUrl($reqPath) {
	$redirected = $null
	if ($null -ne $ServerConfig.redirection) {
		foreach ($vpath in ($ServerConfig.redirection | Get-Member -type NoteProperty)) {
			if ($reqPath -imatch "^$($vpath.Name)(/.*)?$") {
				$redirected = $ServerConfig.redirection."$($vpath.Name)"
				$redirected = "`n$redirected" + $reqPath.Substring($vpath.Name.Length)
				break
			}
		}
	}
	return $redirected
}

function util:findResource($request) {

	$reqPath = $context.Request.Url.AbsolutePath
	$resource = util:isVirtualPathRequest $reqPath

	if (-not $resource) {
		$rewrite = util:mustRedirectUrl $reqPath
		if ($rewrite) {
			return $rewrite
		}
		$resource = "$ServeLocation/$reqPath"
	}

	if ((Test-Path $resource -PathType Container)) {
		if ($reqPath.EndsWith('/')) {
			$resource = "`n$($reqPath)index.html"
		}
		else {
			$resource = "`n$($reqPath)/index.html"
		}
		return $resource
	}

	if ((Test-Path $resource -PathType Leaf)) {
		return (Get-Item "$resource").FullName
	}

	return $null
}

function util:randomName {
	$ticks = [Environment]::TickCount
	$rand1 = Get-Random -Maximum 1000
	$rand1 = (($ticks % 1000003) * $rand1) % [int]::MaxValue
	$rand2 = Get-Random -SetSeed $rand1 -Maximum 1000
	$rand2 = (($ticks % 1000003) * $rand2) % [int]::MaxValue
	$name = "$rand1$ticks$rand2"
	return Join-Path $SessionTempFolder $name
}

function util:randomFolder {
	$name = util:randomName
	if (Test-Path $name) {
		throw "what are the odds? path already exists: $name"
	}
	$folder = New-Item $name -ItemType Directory
	return $folder
}

function util:dumpRequestToFolder ($request) {
	$dumpFolder = util:randomFolder

	if ($request.QueryString -and $request.QueryString.Count -gt 0) {
		$f = New-Item "$dumpFolder/query" -ItemType File
		foreach ($k in $request.QueryString.Keys) {
			"$k`: $($request.QueryString[$k])" | Add-Content $f
		}
	}

	if ($request.ContentLength64 -gt 0) {
		$f = New-Item "$dumpFolder/payload" -ItemType File
		util:dumpInputStream -request $request -dumpFile $f
	}

	return $dumpFolder
}

function util:dumpInputStream ($request, $dumpFile) {
	$stream = $request.InputStream
	#$reader = [System.IO.BinaryReader]::new($stream)

	$totalRead = 0
	$chunk = 10485760 #10Mb
	$chunk = $request.ContentLength64 % $chunk
	[byte[]]$bytes = New-Object byte[] -ArgumentList $chunk

	while ($totalRead -lt $request.ContentLength64) {
		$read = $stream.Read($bytes, 0, $bytes.Count)
		$totalRead += $read
		if ($read -lt $bytes.Count) {
			$bytes[0..($read - 1)] | Add-Content -Path $dumpFile -Encoding Byte
		}
		else {
			$bytes | Add-Content -Path $dumpFile -Encoding Byte
		}

		<#
		$chunk = $request.ContentLength64 % $maxChunk
		$bytes = $reader.ReadBytes($chunk)
		$totalRead += $bytes.Count
		$bytes | Add-Content -Path $dumpFile -Encoding Byte
		#>
	}
}

function util:logHeaders ($headers) {
	foreach ($key in $headers.AllKeys) {
		$values = $headers.GetValues($key);
		if ($values.Length -gt 0) {
			foreach ($value in $values) {
				logVerbose "Header: `t$key`:$value"
			}
		}
	}
}

function util:logUrl ($urlObj, [switch]$referrer) {
	if ($referrer) {
		$prefix = 'UrlReferrer'
	}
 else {
		$prefix = 'Url'
	}
	logVerbose "$prefix`:`tAbsolutePath = $($urlObj.AbsolutePath)"
	logVerbose "$prefix`:`tAbsoluteUri = $($urlObj.AbsoluteUri)"
	logVerbose "$prefix`:`tAuthority = $($urlObj.Authority)"
	logVerbose "$prefix`:`tDnsSafeHost = $($urlObj.DnsSafeHost)"
	logVerbose "$prefix`:`tFragment = $($urlObj.Fragment)"
	logVerbose "$prefix`:`tHost = $($urlObj.Host)"
	logVerbose "$prefix`:`tHostNameType = $($urlObj.HostNameType)"
	logVerbose "$prefix`:`tIdnHost = $($urlObj.IdnHost)"
	logVerbose "$prefix`:`tIsAbsoluteUri = $($urlObj.IsAbsoluteUri)"
	logVerbose "$prefix`:`tIsDefaultPort = $($urlObj.IsDefaultPort)"
	logVerbose "$prefix`:`tIsFile = $($urlObj.IsFile)"
	logVerbose "$prefix`:`tIsLoopback = $($urlObj.IsLoopback)"
	logVerbose "$prefix`:`tIsUnc = $($urlObj.IsUnc)"
	logVerbose "$prefix`:`tLocalPath = $($urlObj.LocalPath)"
	logVerbose "$prefix`:`tOriginalString = $($urlObj.OriginalString)"
	logVerbose "$prefix`:`tPathAndQuery = $($urlObj.PathAndQuery)"
	logVerbose "$prefix`:`tPort = $($urlObj.Port)"
	logVerbose "$prefix`:`tQuery = $($urlObj.Query)"
	logVerbose "$prefix`:`tScheme = $($urlObj.Scheme)"
	logVerbose "$prefix`:`tSegments = $($urlObj.Segments)"
	logVerbose "$prefix`:`tUserEscaped = $($urlObj.UserEscaped)"
	logVerbose "$prefix`:`tUserInfo = $($urlObj.UserInfo)"
}

function util:logRequestInfo ($request) {
	logDebug "Request`tUser-Agent = $($request.UserAgent)"
	logVerbose "Request`tUserHostAddress = $($request.UserHostAddress)"
	logVerbose "Request`tUserHostName = $($request.UserHostName)"
	logVerbose "Request`tRawUrl = $($request.RawUrl)"
	logVerbose "Request`tUserLanguages = $($request.UserLanguages)"
	logVerbose "Request`tQueryString = $($request.QueryString)"
	logVerbose "Request`tAccept-Types = $($request.AcceptTypes)"
	logVerbose "Request`tContent-Encoding = $($request.ContentEncoding.WebName) [$($request.ContentEncoding.EncodingName)]"
	logVerbose "Request`tContent-Length = $($request.ContentLength64)"
	logVerbose "Request`tContent-Type = $($request.ContentType)"
	logVerbose "Request`tCookies = $($request.Cookies)"
	logVerbose "Request`tHasEntityBody = $($request.HasEntityBody)"
	logVerbose "Request`tHttp-Method = $($request.HttpMethod)"
	logVerbose "Request`tIsAuthenticated = $($request.IsAuthenticated)"
	logVerbose "Request`tIsLocal = $($request.IsLocal)"
	logVerbose "Request`tIsSecureConnection = $($request.IsSecureConnection)"
	logVerbose "Request`tIsWebSocketRequest = $($request.IsWebSocketRequest)"
	logVerbose "Request`tKeepAlive = $($request.KeepAlive)"
	logVerbose "Request`tLocalEndPoint = $($request.LocalEndPoint)"
	logVerbose "Request`tRemoteEndPoint = $($request.RemoteEndPoint)"
	logVerbose "Request`tProtocolVersion = $($request.ProtocolVersion)"
	logVerbose "Request`tRequestTraceIdentifier = $($request.RequestTraceIdentifier)"
	logVerbose "Request`tServiceName = $($request.ServiceName)"
	logVerbose "Request`tClientCertificateError = $($request.ClientCertificateError)"
}
