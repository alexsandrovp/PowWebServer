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



function parseHeaderLine([string]$line) {
	$index = $line.IndexOf(':')
	if ($index -lt 0) {
		throw 'invalid header line'
	}
	$ret = @{ }
	$ret.key = $line.Substring(0, $index++).Trim()
	$ret.value = $line.Substring($index).Trim()
	if ($ret.key.Length -eq 0) {
		throw 'invalid header key'
	}
	return $ret
}

function parseContentType ($contentType) {
	$contentType = $contentType.Trim()
	if ($contentType.Length -eq 0) {
		throw 'empty Content-Type'
	}
	$ret = @{ }
	$tokens = $contentType.Split(';', [StringSplitOptions]::RemoveEmptyEntries)
	$ret.mime = $tokens[0].Trim()
	if ($ret.mime -eq 'multipart/form-data') {
		for ($i = 1; $i -lt $tokens.Length; ++$i) {
			$s = $tokens[$i].Trim()
			if ($s -match '^boundary=') {
				$ret.boundary = $s.Substring(9)
				break;
			}
		}
		if (-not $ret.boundary) {
			throw 'no boundary defined for multipart/form-data'
		}
	}
	return $ret
}
