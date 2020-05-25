# Powershell web server

This is a simple powershell web server. The idea is to have a way to do quick prototyping of simple web UI. Once started, the server will run until a '/quit' request is sent to the server (the actual url is configurable). The sever can also be stopped by simply closing powershell, but that is not advisable, since temporary files may be left in the user's temp folder.

As any console application, execution halts if the user selects some text in the console output. If that happens, hit ENTER to resume execution. To avoid the problem altogether, use powershell ISE instead of the normal console.

## How to install
Download the installer script at https://github.com/alexsandrovp/PowWebServer/blob/1.0.0/installer/Install-PowWebServer.ps1
and run it.

```powershell
PS> .\Install-PowWebServer.ps1
```

You will be asked to choose in which Module path to copy the module.
Typically, you will have two options:

```powershell
1.	C:\users\username\Documents\WindowsPowerShell\Modules
	Use this to install for the current user only

2.	C:\Program Files\WindowsPowerShell\Modules
	Use this to install for all users
```

Note: the **username** part is different for each user.

You could modify the environment variable PSModulePath to have more options in this step.

After the installation is complete, new instances of powershell will load the module automatically.

## How to use it
The simplest way:

```powershell
PS> Start-PowWebServer
```

Or specifying a path:

```powershell
PS> Start-PowWebServer <path-to-my-site>
```

If you don't specify a folder to serve, it will use the **current directory**. The default binding address is *localhost:8080*

Using full options:

```powershell
PS> Start-PowWebServer -ServeLocation c:\mysite -Protocol http -Address 192.168.0.1 -Port 80 -Browse
```

Some address/port combinations require administrative privileges to bind to.
The -Browse switch causes your default browser to open at the served address.

This module provides the following cmdlets. After installation, type **Get-Help <cmdlet name>** to get help for each one.
	
```powershell
Start-PowWebServer
New-PowConfig
New-PowScript
Select-Certificate
New-HttpsCertificate
New-HttpsCertificateBinding
Get-HttpsCertificateBinding
Remove-HttpsCertificateBinding
```

# Server configuration
You can create a configuration file in the folder being served to configure advanced options.
To learn more about the server configuration, type

```powershell
PS> Get-Help about_POW_Configuration
```
<a href="about_POW_Configuration.help.txt">about_POW_Configuration</a>

# HTTPS

The POW web server supports the https protocol, but before starting it you must have an https certificate with private key for encryption, and bind this certificate to the port the server will be listening to.

To learn more about certificates, type

```powershell
PS> Get-Help about_POW_Certificates
```

<a href="about_POW_Certificates.help.txt">about_POW_Certificates</a>

# Scripting

There is rudimentary support to server-side scripting. To learn more about this topic, type


```powershell
PS> Get-Help about_POW_Scripts
```

<a href="about_POW_Scripts.help.txt">about_POW_Scripts</a>