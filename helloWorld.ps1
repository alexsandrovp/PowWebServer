#Get-Help about_POW_Scripts
#For a list of request properties and methods see
#https://docs.microsoft.com/en-us/dotnet/api/system.net.httplistenerrequest

param(
	$request,
	$requestFolder,
	$responseObject
)

Foreach-Object {

	Write-Host ''
	Write-Host "(script) http method: $($request.HttpMethod)"
	Write-Host "(script) from url: $($request.Url.AbsolutePath)"
	Write-Host "(script) content-type: $($request.ContentType)"
	Write-Host "(script) content-encoding: $($request.ContentEncoding.WebName)"
	Write-Host "(script) accept-types: $($request.AcceptTypes)"
	if ($request.ContentLength64 -gt 0) {
		Write-Host "(script) length of payload: $($request.ContentLength64)"
		Write-Host "(script) request payload dumped @ $requestFolder/payload"
	}

	Write-Host ''

	$result = '{"greeting": "Hello world"}'
	$result = [Text.Encoding]::UTF8.GetBytes($result)

	$responseObject.HttpStatus = [int][Net.HttpStatusCode]::OK
	$responseObject.Buffer = [byte[]]$result
	$responseObject.Mime = 'application/json'
	$responseObject.Encoding = 'utf-8'

} | Out-Null

return $responseObject