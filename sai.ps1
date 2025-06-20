[CmdletBinding()]
Param(
    [ValidateNotNullOrEmpty()]
    [string]$SiteName = "SAI",
    [ValidateNotNullOrEmpty()]
    [string]$VirtualPath = "/Archives",
    [ValidateNotNullOrEmpty()]
    [string]$PhysicalPath = "C:\\SAI\\Archives",
    [ValidateNotNullOrEmpty()]
    [string]$AuthUserGroup = "Everyone",
    [switch]$UseBasicAuth = $false
)

Import-Module ServerManager
Import-Module WebAdministration

# 1. Features installation (skip if pending restart)
Write-Host "Checking and installing IIS features..."
$features = @('Web-Server', 'Web-DAV-Publishing', 'Web-Dir-Browsing', 'Web-Basic-Auth')
try {
    $toInstall = $features | Where-Object { (Get-WindowsFeature $_).Installed -eq $false }
    if ($toInstall.Count -gt 0) {
        $result = Install-WindowsFeature $toInstall -IncludeAllSubFeature -IncludeManagementTools
        Write-Host "Installed features: $($toInstall -join ', ')"
        if ($result.RestartNeeded -eq 'Yes') {
            Write-Warning 'Un redémarrage est nécessaire pour terminer l\'installation.'
        }
    } else {
        Write-Host "Required features already installed."
    }
} catch {
    Write-Warning "Feature check failed (pending reboot?). Proceeding without changes."
}

# 2. Create physical folder
if (-Not (Test-Path $PhysicalPath)) {
    New-Item -Path $PhysicalPath -ItemType Directory -Force | Out-Null
    Write-Host "Created folder $PhysicalPath"
} else {
    Write-Host "Folder $PhysicalPath exists"
}

# 3. Create or update web application
$vdName = $VirtualPath.TrimStart('/')
Write-Host "Creating or updating IIS web application..."
$app = Get-WebApplication -Site $SiteName -Name $vdName -ErrorAction SilentlyContinue
if (-Not $app) {
    New-WebApplication -Site $SiteName -Name $vdName -PhysicalPath $PhysicalPath | Out-Null
    Write-Host "Web application $VirtualPath created under site $SiteName"
} else {
    Set-ItemProperty IIS:\Sites\$SiteName\$vdName -Name physicalPath -Value $PhysicalPath
    Write-Host "Web application $VirtualPath updated to path $PhysicalPath"
}

# Define location string for configuration
$location = "$SiteName/$vdName"

# 4. Enable WebDAV
Write-Host "Enabling WebDAV..."
Set-WebConfigurationProperty -Filter "system.webServer/webdav" -Location $location -Name enabled -Value true

# 5. Configure authoring rules
Write-Host "Configuring WebDAV authoring rules..."
$existingRule = Get-WebConfiguration "/system.webServer/webdav/authoringRules/add[@path='/']" -Location $location -ErrorAction SilentlyContinue
if (-not $existingRule) {
    Add-WebConfiguration "/system.webServer/webdav/authoringRules" -Location $location -Value @{path='/';users=$AuthUserGroup;roles='';permissions='Read,Write'}
}

# 6. Enable Directory Browsing
Write-Host "Enabling Directory Browsing..."
Set-WebConfigurationProperty -Filter "system.webServer/directoryBrowse" -Location $location -Name enabled -Value true

# 7. Allow HTTP verbs
Write-Host "Allowing PROPFIND and OPTIONS verbs..."
$verbsPath = 'system.webServer/security/requestFiltering/verbs'
$existingVerbs = Get-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST' -filter $verbsPath -Location $location -Name . | ForEach-Object { $_.verb }
if (-not ($existingVerbs -contains 'PROPFIND')) {
    Add-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST' -filter $verbsPath -Location $location -Name . -Value @{verb='PROPFIND';allowed='True'}
}
if (-not ($existingVerbs -contains 'OPTIONS')) {
    Add-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST' -filter $verbsPath -Location $location -Name . -Value @{verb='OPTIONS';allowed='True'}
}

# 8. Configure Authentication
Write-Host "Configuring authentication..."
Set-WebConfigurationProperty -Filter "system.webServer/security/authentication/anonymousAuthentication" -Location $location -Name enabled -Value false
Set-WebConfigurationProperty -Filter "system.webServer/security/authentication/windowsAuthentication" -Location $location -Name enabled -Value true
if ($UseBasicAuth) {
    Set-WebConfigurationProperty -Filter "system.webServer/security/authentication/basicAuthentication" -Location $location -Name enabled -Value true
    Write-Host "Basic Auth enabled. Use SSL for encryption."
}

# 9. NTFS permissions
Write-Host "Setting NTFS permissions..."
icacls $PhysicalPath /grant "${AuthUserGroup}:(OI)(CI)(M)" /T | Out-Null

# 10. Firewall rules
Write-Host "Ensuring firewall ports open..."
if (-Not (Get-NetFirewallRule -DisplayName 'IIS HTTP' -ErrorAction SilentlyContinue)) {
    New-NetFirewallRule -DisplayName 'IIS HTTP' -Direction Inbound -LocalPort 80 -Protocol TCP -Action Allow | Out-Null
}
if (-Not (Get-NetFirewallRule -DisplayName 'IIS HTTPS' -ErrorAction SilentlyContinue)) {
    New-NetFirewallRule -DisplayName 'IIS HTTPS' -Direction Inbound -LocalPort 443 -Protocol TCP -Action Allow | Out-Null
}

Write-Host "WebDAV configured at http(s)://<server>$VirtualPath/."
