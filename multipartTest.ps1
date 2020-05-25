. ./bytes.ps1
. ./headers.ps1
. ./multipart.ps1

function parseMultipartTest () {

	$boundary = '---------------------------18467633426500'
	$binary = @"
abc
123

"@

	$text = @"
-----------------------------18467633426500
Content-Disposition: form-data; name="myFile"; filename="bin.bin"
Content-Type: application/octet-stream

abc
123

-----------------------------18467633426500--

"@

	$encoding = [Text.Encoding]::ASCII
	$bytes = $encoding.GetBytes($text)
	$parts = multipart:parse -bytes $bytes -boundary $boundary
	if ($parts.headers['Content-Disposition'] -ne 'form-data; name="myFile"; filename="bin.bin"') {
		throw
	}
	if ($parts.headers['Content-Type'] -ne 'application/octet-stream') {
		throw
	}
	if ($parts.data.start -ne 150) {
		throw
	}
	if ($parts.data.end -ne 157) {
		throw
	}
	$data = $bytes[($parts.data.start)..($parts.data.end)]
	$data = $encoding.GetString($data)
	if ($data -ne $binary) {
		throw
	}
}

function parseMultipartTestCRLF () {

	$boundary = '---------------------------18467633426500'
	$binary = @"
abc
123

"@

	$text = @"
-----------------------------18467633426500`r
Content-Disposition: form-data; name="myFile"; filename="bin.bin"`r
Content-Type: application/octet-stream`r
`r
abc
123

-----------------------------18467633426500--`r`n
"@

	$encoding = [Text.Encoding]::ASCII
	$bytes = $encoding.GetBytes($text)
	$parts = multipart:parse -bytes $bytes -boundary $boundary
	if ($parts.headers['Content-Disposition'] -ne 'form-data; name="myFile"; filename="bin.bin"') {
		throw
	}
	if ($parts.headers['Content-Type'] -ne 'application/octet-stream') {
		throw
	}
	if ($parts.data.start -ne 154) {
		throw
	}
	if ($parts.data.end -ne 161) {
		throw
	}
	$data = $bytes[($parts.data.start)..($parts.data.end)]
	$data = $encoding.GetString($data)
	if ($data -ne $binary) {
		throw
	}
}

parseMultipartTest
parseMultipartTestCRLF
