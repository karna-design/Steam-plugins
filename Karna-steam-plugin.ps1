

# --- Configuration Section ---
$SteamPath = (Get-ItemProperty "HKLM:\SOFTWARE\WOW6432Node\Valve\Steam").InstallPath
$PluginName = "luatools"
$PluginZipUrl = "https://github.com/madoiscool/ltsteamplugin/releases/latest/download/ltsteamplugin.zip"
$SteamToolsUrl = "https://steam.run"
$MillenniumUrl = "https://raw.githubusercontent.com/karna-design/Steam-plugins/refs/heads/main/millennium.ps1"
# -----------------------------

Write-Host "Stopping Steam..."
Get-Process steam -ErrorAction SilentlyContinue | Stop-Process -Force

# 1. Install Steamtools (xinput)
$xinputPath = Join-Path $SteamPath "xinput1_4.dll"
if (-not (Test-Path $xinputPath)) {
    Write-Host "Installing Steamtools dependencies..."
    $stScript = Invoke-RestMethod $SteamToolsUrl
    # Note: The original script filters this script to remove UI/Exits.
    # For a clean version, we run the installer directly.
    Invoke-Expression $stScript
}

# 2. Install Millennium Framework
$millDll = Join-Path $SteamPath "millennium.dll"
if (-not (Test-Path $millDll)) {
    Write-Host "Installing Millennium Framework..."
    Invoke-Expression "& { $(Invoke-RestMethod $MillenniumUrl) } -NoLog -DontStart -SteamPath '$SteamPath'"
}

# 3. Download and Extract Plugin
$PluginDir = Join-Path $SteamPath "plugins\$PluginName"
$TempZip = Join-Path $env:TEMP "$PluginName.zip"

if (-not (Test-Path $PluginDir)) { New-Item -Path $PluginDir -ItemType Directory -Force }

Write-Host "Downloading Plugin..."
Invoke-WebRequest -Uri $PluginZipUrl -OutFile $TempZip
Expand-Archive -Path $TempZip -DestinationPath $PluginDir -Force
Remove-Item $TempZip

# 4. Clean up Steam Beta/Cache issues
Remove-Item (Join-Path $SteamPath "package\beta") -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item (Join-Path $SteamPath "steam.cfg") -Force -ErrorAction SilentlyContinue

# 5. Update Config JSON to enable plugin
$ConfigFile = Join-Path $SteamPath "ext/config.json"
if (Test-Path $ConfigFile) {
    $Config = Get-Content $ConfigFile | ConvertFrom-Json
    
    # Ensure properties exist
    if (-not $Config.plugins) { $Config | Add-Member -Name "plugins" -Value @{enabledPlugins = @()} -MemberType NoteProperty }
    
    # Add plugin to enabled list if not there
    if ($Config.plugins.enabledPlugins -notcontains $PluginName) {
        $Config.plugins.enabledPlugins += $PluginName
    }
    
    $Config | ConvertTo-Json -Depth 10 | Set-Content $ConfigFile
}

Write-Host "Installation Complete. Restarting Steam..."
Start-Process (Join-Path $SteamPath "steam.exe") -ArgumentList "-clearbeta"