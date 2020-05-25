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
Selects certificates from the given store.

.Description
Selects certificates from the given store based on the given search criteria.
This cmdlet has two main parameter sets, byThumb and byFilters (default).
To search byThumb, use the parameter '-Thumbprint' and pass a part of the thumbprint
of the certificate that you want to select. If '-Thumbprint' is not used, you are
selecting certificates 'byFilter', and there are a number of parameters that can be used.
If you don't specify any parameter, you are searching everything.

.Parameter Store
The certificate store to be searched. Mandatory. Accepts pipeline input.
Must be cert:\ or one of its child containers.

.Parameter Thumbprint
Select by certificate thumbprint. This string can be only a part of the thumbprint.

.Parameter Subject
Filter by certificate subject.

.Parameter Issuer
Filter by certificate issuer.

.Parameter NoPrivateKey
Select only certificates that have no private key

.Parameter HasPrivateKey
Select only certificates that have a private key

.Parameter Expired
Select only certificates that have expired

.Parameter NotExpired
Select only certificates that have not expired

.Parameter Recurse
Search recursively through the store

.Link
New-HttpsCertificateBinding

.Example
PS> Select-Certificate cert:\LocalMachine\My -Subject localhost -HasPrivateKey

Selects certificates in cert:\LocalMachine\My issued to localhost that have a private key
.Example
PS> Get-Item cert:\CurrentUser\my | Select-Certificate -Recurse -NoPrivateKey

Selects all certificates in cert:\CurrentUser\my that have no private key
.Example
PS> Select-Certificate -Store cert:\ -Recurse -Expired

Selects all certificates that have expired
.Example
PS Cert:\> Get-Location | Select-Certificate -Recurse
Selects all certificates (note the current location)
.Example
PS> 'Cert:\LocalMachine\CA', 'Cert:\CurrentUser\CA' | Select-Certificate -Subject contoso.com -Issuer acne.com

Selects all certificates in Cert:\LocalMachine\CA and Cert:\CurrentUser\CA
that have been issued by CN=acne.com to CN=contoso.com
#>
function Select-Certificate {
	[CmdletBinding(
		DefaultParameterSetName = 'byFilters'
	)]
	param (
		[Parameter(
			Position = 0,
			Mandatory = $true,
			ValueFromPipeline = $true)]
		$Store,

		[Parameter(
			Mandatory = $true,
			ParameterSetName = 'byThumb')]
		[string]
		$Thumbprint,

		[Parameter(ParameterSetName = 'byFilters')]
		[string]
		$Subject,

		[Parameter(ParameterSetName = 'byFilters')]
		[string]
		$Issuer,

		[Parameter(ParameterSetName = 'byFilters')]
		[Parameter(ParameterSetName = 'noPrivKey')]
		[switch]
		$NoPrivateKey,

		[Parameter(ParameterSetName = 'byFilters')]
		[Parameter(ParameterSetName = 'hasPrivKey')]
		[switch]
		$HasPrivateKey,

		[Parameter(ParameterSetName = 'byFilters')]
		[Parameter(ParameterSetName = 'expired')]
		[switch]
		$Expired,

		[Parameter(ParameterSetName = 'byFilters')]
		[Parameter(ParameterSetName = 'notExpired')]
		[switch]
		$NotExpired,

		[switch]
		$Recurse
	)

	process {

		if ($Store.PSPath) {
			$StoreObj = $Store
		}
		elseif ($Store.Path) {
			$Store = $Store.Path
		}
		else {
			$StoreObj = Get-Item $Store
		}

		if (-not $StoreObj -or ($StoreObj -isnot [System.Security.Cryptography.X509Certificates.X509Store] -and
				$StoreObj -isnot [Microsoft.PowerShell.Commands.X509StoreLocation])) {
			if ($Store -eq 'cert:\') {
				$StoreObj = @{ PSPath = 'cert:\' }
			}
			else {
				Write-Error 'Invalid Store'
				return
			}
		}

		if ($Thumbprint) {
			Write-Output (
				Get-ChildItem $StoreObj.PSPath -Recurse:$Recurse | Where-Object Thumbprint -match $Thumbprint
			)
		}
		else {
			$dontFilterPrivateKey = -not $NoPrivateKey -and -not $HasPrivateKey
			if ($Expired -or $NotExpired) {
				$date = Get-Date
				Write-Verbose "filtering by date $date"
			}
			Write-Output (
				Get-ChildItem $StoreObj.PSPath -Recurse:$Recurse | `
					ForEach-Object {
					if ($_ -is [System.Security.Cryptography.X509Certificates.X509Certificate]) {
						$_
					}
				} | `
					Where-Object Subject -match $Subject | `
					Where-Object Issuer -match $Issuer | `
					ForEach-Object {
					if ($date) {
						if ($Expired) {
							if ($_.NotAfter -le $date) {
								$_
							}
						}
						elseif ($_.NotAfter -ge $date) {
							$_
						}
					}
					else {
						$_
					}
				} | ForEach-Object {
					if ($dontFilterPrivateKey) {
						$_
					}
					elseif ($_.HasPrivateKey -eq $HasPrivateKey) {
						$_
					}
				}
			)
		}
	}
}

<#
.Synopsis
Binds the given certificate to the given address:port. Elevation is required to run this cmdlet.

.Description
Creates an https certificate binding.
An encryption certificate is required if you want to host your website using https.
Use Select-Certificate to find a suitable certificate

.Parameter Address
A string matching the ipv4 address to bind to. The default is 0.0.0.0 (accept requests from any interface).

.Parameter Port
An integer specifying the https port. The default is 8443.

.Parameter Certificate
The certificate used in the binding. Use Select-Certificate to find a suitable one.

.Link
about_POW_Certificates
Select-Certificate
New-HttpsCertificate
Get-HttpsCertificateBinding
Remove-HttpsCertificateBinding

.Example
PS> Select-Certificate cert:\LocalMachine\My -Subject localhost -HasPrivateKey | New-HttpsCertificateBinding

Binds the selected certificate to 0.0.0.0:8443
.Example
PS> Select-Certificate cert:\LocalMachine\My -Subject localhost -HasPrivateKey | New-HttpsCertificateBinding -Address 192.168.0.1 -Port 443

Binds the selected certificate to 192.168.0.1:443
#>
function New-HttpsCertificateBinding {
	param (
		[Parameter(
			Mandatory = $true,
			ValueFromPipeline = $true)]
		[System.Security.Cryptography.X509Certificates.X509Certificate[]]
		$Certificate,

		[ValidateScript( { $_ -match [IPAddress]$_ })]
		[string]
		$Address = '0.0.0.0',

		[int]
		$Port = '8443'
	)

	begin {
		$elevated = util:isElevated
		$certs = @()
	}

	process {
		if (-not $elevated) {
			return
		}
		$certs += $Certificate
	}

	end {

		if (-not $elevated) {
			return
		}

		if ($certs.Count -eq 0) {
			logError "No certificates"
			return
		}

		if ($certs.Count -gt 1) {
			Write-Host "More than one certificate found`: $($certs.Count)"
			Write-Host ''
			for ($i = 0; $i -lt $certs.Count; ++$i) {
				Write-Host "$($i+1). $($certs[$i].Subject) (by $($certs[$i].Issuer)): $($certs[$i].Thumbprint) from $($certs[$i].NotBefore) to $($certs[$i].NotAfter)"
			}
			Write-Host "$($i+1). Or type anything else to abort"

			try {
				[int]$selection = Read-Host 'Choose the certificate for binding'
				--$selection
				if ($selection -lt 0 -or $selection -ge $certs.Count) {
					throw
				}
			}
			catch {
				return
			}

			$cert = $certs[$selection];
		}
		else {
			$cert = $certs[0]
		}

		Write-Host 'Selected certificate:'
		$cert | Format-List

		$appId = "{$([guid]::NewGuid())}"
		$thumb = "$($cert.Thumbprint)"
		$binding = "$Address`:$Port"

		Write-Host -ForegroundColor Magenta "Binding this certificate to $binding"
		$confirm = Read-Host 'Confirm? (y/N)'
		$confirm = $confirm -eq 'y' -or $confirm -eq 'yes'

		if ($confirm) {

			##https://docs.microsoft.com/en-us/dotnet/framework/wcf/feature-details/how-to-configure-a-port-with-an-ssl-certificate
			##to support authentication with client certificates, add "clientcertnegotiation=enable"
			#netsh http add sslcert ipport=$binding certhash="$thumb" appid="$appId"
			$toolArgs = 'http', 'add', 'sslcert', "ipport=$binding",
			"certhash=`"$thumb`"", "appid=`"$appId`""
			$p = util:launchTool -toolPath netsh -toolArgs $toolArgs

			if ($p.ExitCode -eq 0) {
				Write-Host "Successfully created binding ($appid)"
				Write-Host "$thumb <=> $binding"
			}
			else {
				Write-Warning "netsh failed with code $($p.ExitCode)"
			}

		}
	}
}

<#
.Synopsis
Lists the binding associated with the given address:port, if any.

.Parameter Address
A string matching the ipv4 address of the binding to list. The default is 0.0.0.0

.Parameter Port
An integer matching the https port of the binding to list. The default is 8443.

.Link
about_POW_Certificates
New-HttpsCertificate
New-HttpsCertificateBinding
Remove-HttpsCertificateBinding

.Example
PS> Get-HttpsCertificateBinding

Lists bindings for 0.0.0.0:8443, if any
.Example
PS> Get-HttpsCertificateBinding -Address 192.168.0.1 -Port 443

Lists bindings for 192.168.0.1:443, if any
#>
function Get-HttpsCertificateBinding {
	param (
		[ValidateScript( { $_ -match [IPAddress]$_ })]
		[string]
		$Address = '0.0.0.0',

		[int]
		$Port = 8443
	)

	#netsh http show sslcert ipport="$Address`:$Port"
	$toolArgs = 'http', 'show', 'sslcert', "ipport=$Address`:$Port"
	$p = util:launchTool -toolPath netsh -toolArgs $toolArgs

	if ($p.ExitCode -ne 0) {
		Write-Warning "netsh failed with code $($p.ExitCode)"
	}
}

<#
.Synopsis
Removes the binding between a certificate and the given address:port. Elevation is required to run this cmdlet.

.Description
If an https-encription certificate is no longer necessary, or if it has already expired,
you will need to run this command to remove the stablished binding to the given address:port combination.

.Parameter Address
A string matching the ipv4 address of the binding to be removed. The default is 0.0.0.0.

.Parameter Port
An integer specifying the https port. The default is 8443.

.Link
about_POW_Certificates
New-HttpsCertificate
New-HttpsCertificateBinding
Get-HttpsCertificateBinding

.Example
PS> Remove-HttpsCertificateBinding

Removes the binding to 0.0.0.0:8443, if it exists
.Example
PS> Remove-HttpsCertificateBinding -Address 192.168.0.1 -Port 443

Removes the binding to 192.168.0.1:443, if it exists
#>
function Remove-HttpsCertificateBinding {
	param (
		[ValidateScript( { $_ -match [IPAddress]$_ })]
		[string]
		$Address = '0.0.0.0',

		[int]
		$Port = 8443
	)

	if (-not (util:isElevated)) {
		return
	}

	#netsh http delete sslcert ipport="$Address`:$Port"
	$toolArgs = 'http', 'delete', 'sslcert', "ipport=$Address`:$Port"
	$p = util:launchTool -toolPath netsh -toolArgs $toolArgs

	if ($p.ExitCode -ne 0) {
		Write-Warning "netsh failed with code $($p.ExitCode)"
	}
}

<#
.Synopsis
Creates a new self signed certificate. Elevation is required to run this cmdlet.

.Description
Creates a new self signed certificate.
An encryption certificate is required if you want to host your website using https.
The validity of the certificate starts at the current date, and extends until
the value specified in 'ValidUntil'. The new certificate is stored in cert:\LocalMachine\My.

.Parameter DnsName
Subject name for the certificate. Can be an array of strings, which will be added as alternative subject names.
Usually, this name is set to match the dns used to access your website. The default is localhost.

.Parameter ValidUntil
Expiration date for the certificate. If not specified, the default is the current date plus one year.

.Link
about_POW_Certificates
New-HttpsCertificateBinding
Get-HttpsCertificateBinding
Remove-HttpsCertificateBinding

.Notes
After generating a certificate, you will have to bind it to the desired ip:port,
otherwise https requests will not work. To do that, use the cmdlet New-HttpsCertificateBinding
with the Thumbprint of the certificate generated by this cmdlet.

.Example
PS> New-HttpsCertificate

Generates a new certificate for CN=localhost
.Example
PS> New-HttpsCertificate -DnsName contoso.com

Generates a new certificate for CN=contoso.com
.Example
PS> New-HttpsCertificate -DnsName @(contoso.com, acne.com) -ValidUntil (Get-Date).Date.AddMonths(6)

Generates a new certificate for CN=contoso.com, with an alternative subject name for CN=acne.com,
and valid until 6 months from the day this command was run.
#>
function New-HttpsCertificate {
	param (
		[string[]]
		$DnsName,

		[DateTime]
		$ValidUntil
	)

	if (-not (util:isElevated)) {
		return
	}

	if ($ValidUntil) {
		New-SelfSignedCertificate -DnsName $DnsName -NotAfter $ValidUntil `
			-KeyAlgorithm RSA -KeyLength 2048 -CertStoreLocation Cert:\LocalMachine\My
	}
	else {
		New-SelfSignedCertificate -DnsName $DnsName `
			-KeyAlgorithm RSA -KeyLength 2048 -CertStoreLocation Cert:\LocalMachine\My
	}

}