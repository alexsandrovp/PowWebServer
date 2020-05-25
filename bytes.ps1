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
Find the next line break in a sequence of bytes, starting from a given index.
The returned index actually indicates the position past the line break, where
the next line begins. If a line break is not found, the returned object will
have the 'exhausted' property set to $true, and the 'index' property is not valid.
In that case, the caller will have to continue checking in the next chunk of bytes.
#>
function findEOL ($bytes, $fromIndex) {
	$crlf = $false
	$i = $fromIndex
	while ($i -lt $bytes.Length) {
		$byte = $bytes[$i++]
		if ($byte -eq 10) {
			break;
		}
		if ($byte -eq 13) {
			if ($i -eq $bytes.Length) {
				break
			}
			$byte = $bytes[$i++]
			if ($byte -eq 10) {
				$crlf = $true
				break;
			}
		}
	}
	return @{
		'index'     = $i;
		'crlf'      = $crlf;
		'exhausted' = $i -ge $bytes.Length;
	}
}
