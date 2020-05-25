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


function multipart:checkContentType ($request, $requestFolder) {
	if ($request.ContentType) {
		$contentType = parseContentType $request.ContentType
		switch ($contentType.mime) {
			'multipart/form-data' {
				multipart:parseAndDump $contentType $requestFolder
			}
			'application/x-www-form-urlencoded' {
				$q = Get-Content "$requestFolder/payload" -Raw
				if ($request.ContentEncoding) {
					$q = [Web.HttpUtility]::ParseQueryString($q, $request.ContentEncoding)
				}
				else {
					$q = [Web.HttpUtility]::ParseQueryString($q)
				}

				if ($q -and $q.Count -gt 0) {
					$f = New-Item "$requestFolder/query_fue" -ItemType File
					foreach ($k in $q.Keys) {
						"$k`: $($q[$k])" | Add-Content $f
					}
				}
			}
			<#
			'text/plain' {
				New-Item "$requestFolder/form_textplain" -ItemType File | Out-Null
			}#>
		}
	}
}

function multipart:parseAndDump ($contentType, $requestFolder) {
	$boundary = $contentType.boundary
	logVerbose "boundary: $boundary"

	$i = 0
	$bytes = [IO.File]::ReadAllBytes("$requestFolder/payload")
	$parts = multipart:parse -bytes $bytes -boundary $boundary
	New-Item "$requestFolder/multipart" -ItemType Directory | Out-Null
	foreach ($part in $parts) {
		New-Item "$requestFolder/multipart/part-$i" -ItemType Directory | Out-Null
		foreach ($h in $part.headers.Keys) {
			[IO.File]::WriteAllText("$requestFolder/multipart/part-$i/$h", $part.headers[$h])
		}
		$dataOK = $part.data.start -ge 0 -and $part.data.end -lt $bytes.Length -and $part.data.start -le $part.data.end + 1
		if ($dataOK) {
			if ($part.data.start -eq $part.data.end + 1) {
				#empty data
				[IO.File]::WriteAllBytes("$requestFolder/multipart/part-$i/data", @())
			}
			else {
				[IO.File]::WriteAllBytes("$requestFolder/multipart/part-$i/data", $bytes[($part.data.start)..($part.data.end)])
			}
		}
		else {
			Write-Error "part $i data error: Content-Length: $($bytes.Length); Data begin @$($part.data.start); Data end @$($part.data.end)"
		}
		++$i
	}

	return [Net.HttpStatusCode]::OK
}

function multipart:parse($bytes, $boundary) {
	$encoding = [Text.Encoding]::ASCII

	$boundaryCheck = "--$boundary"
	$boundaryCheckBytes = $encoding.GetBytes($boundaryCheck)

	$boundaryEnd = "$boundaryCheck--"
	$boundaryEndBytes = $encoding.GetBytes($boundaryEnd)

	#0 => start parsing
	#1 => first boundary found (header region)
	#2 => empty line found (data region)
	$state = 0
	$parts = @()

	$i = 0;
	while ($i -lt $bytes.Length) {
		$eol = findEOL -bytes $bytes -fromIndex $i
		$trimBytes = $eol.index - 1
		if ($bytes[$trimBytes] -eq 10) {
			--$trimBytes;
		}
		if ($bytes[$trimBytes] -eq 13) {
			--$trimBytes;
		}
		++$trimBytes

		switch ($state) {
			0 {
				$bOK = $trimBytes - $i -eq $boundaryCheckBytes.Length
				for ($j = 0; $bOK -and $j -lt $boundaryCheckBytes.Length; ++$j) {
					if ($boundaryCheckBytes[$j] -eq $bytes[$i + $j]) {
						continue
					}
					$bOK = $false
					break
				}
				if (-not $bOK) {
					$dataEnd = $trimBytes - $i -eq $boundaryEndBytes.Length
					if ($dataEnd) {
						for ($j = 0; $dataEnd -and $j -lt $boundaryEndBytes.Length; ++$j) {
							if ($boundaryEndBytes[$j] -eq $bytes[$i + $j]) {
								continue
							}
							$dataEnd = $false
							break
						}

						if ($dataEnd) {
							if (-not $eol.exhausted) {
								throw 'detected bytes after final boundary'
							}
							#$parts += $part
						}
						else {
							throw 'first line of multipart form is not the boundary marker'
						}
					}
				}
				if (-not $dataEnd) {
					$state = 1
					$part = @{ }
					$part.headers = @{ }
					break
				}
			}
			1 {
				$line = $bytes[$i..($eol.index - 1)]
				$line = $encoding.GetString($line).Trim()
				if ($line.Length -eq 0) {
					$state = 2
					$part.data = @{ }
					$part.data.start = $eol.index
				}
				else {
					$headerEntry = parseHeaderLine -line $line
					$part.headers[$headerEntry.key] = $headerEntry.value
				}
				break
			}
			2 {
				$dataEnd = $trimBytes - $i -eq $boundaryEndBytes.Length
				if ($dataEnd) {
					for ($j = 0; $dataEnd -and $j -lt $boundaryEndBytes.Length; ++$j) {
						if ($boundaryEndBytes[$j] -eq $bytes[$i + $j]) {
							continue
						}
						$dataEnd = $false
						break
					}

					if ($dataEnd) {
						if ($eol.exhausted) {
							$part.data.end = $lastDataLine
						}
						else {
							throw 'detected bytes after final boundary'
						}
						$parts += $part
					}
				}
				else {
					$partEnd = $trimBytes - $i -eq $boundaryCheckBytes.Length
					for ($j = 0; $partEnd -and $j -lt $boundaryCheckBytes.Length; ++$j) {
						if ($boundaryCheckBytes[$j] -eq $bytes[$i + $j]) {
							continue
						}
						$partEnd = $false
						break
					}

					if ($partEnd) {
						if ($eol.exhausted) {
							throw 'byte array exhausted without a final boundary'
						}
						else {
							$part.data.end = $lastDataLine
							#if ($eol.crlf) {
							#--$part.data.end;
							#}
						}
						$parts += $part
						$state = 1
						$part = @{ }
						$part.headers = @{ }
					}
				}
				$lastDataLine = $trimBytes - 1
				break
			}
		}

		$i = $eol.index
	}

	return $parts
}
