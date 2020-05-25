@{
	ModuleVersion     = '0.1'
	GUID              = 'bce904c3-0054-4ef1-9122-639e58af963a'
	Author            = 'Alex Vargas'
	CompanyName       = 'The Void Company'
	Copyright         = '(c) 2019 Alex Vargas. All rights reserved.'
	Description       = 'A simple powershell webserver'

	NestedModules     = @(
		'log.ps1',
		'utils.ps1',
		'headers.ps1',
		'bytes.ps1',
		'multipart.ps1',
		'get.ps1',
		'putpost.ps1',
		'scriptrunner.ps1',
		'certificates.ps1',
		'webserver.ps1')

	FunctionsToExport = @(
		'Start-PowWebServer',
		'New-PowConfig',
		'New-PowScript',
		'Select-Certificate',
		'New-HttpsCertificate',
		'New-HttpsCertificateBinding',
		'Get-HttpsCertificateBinding',
		'Remove-HttpsCertificateBinding')

	PrivateData       = @{
		PSData = @{
			LicenseUri               = 'https://github.com/alexsandrovp/pwshws/blob/master/LICENSE'
			ProjectUri               = 'https://github.com/alexsandrovp/pwshws'
			RequireLicenseAcceptance = $true
		}
	}
}
