# Este script foi projetado para ser executado após uma instalação limpa do Windows ou formatação. Ele instala programas essenciais e o que pode ser a melhor configuração de shell já criada: ProcrastinateShell.
# Para executá-lo a partir do sistema, temos duas opções: remover a restrição de acesso à internet e, em seguida, alterar a política para o usuário atual ou ignorar o script.
# Unblock-File -Path .\setup.ps1
# Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
# ou use para executá-lo sem alterar a política
# powershell -ExecutionPolicy Bypass -File .\setup.ps1

# Função para verificar se o script está sendo executado como administrador

$scriptName = "setup.ps1";

function Test-Admin {
    $currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentIdentity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}
# Verificar permissões elevadas
if (-not (Test-Admin)) {
    Write-Host "Este script requer privilégios elevados (Administrador). Execute-o como Administrador." -ForegroundColor Red
    exit
}
# 1. Obtenha informações sobre a versão mais recente.
$repo = "microsoft/winget-cli"
$urlApi = "https://api.github.com/repos/$repo/releases/latest"
try {
    Write-Host "🚀 Consultando ultima versão do winget..." -ForegroundColor Cyan
    $latestRelease = Invoke-RestMethod -Uri $urlApi
    $latestVersionTag = $latestRelease.tag_name.Replace('v', '').Trim()
    $requiredVersion = [version]$latestVersionTag
    $downloadUrl = ($latestRelease.assets | Where-Object { $_.name -like "*.msixbundle" }).browser_download_url | Select-Object -First 1

    # 2. Verifique a versão atual
    $currentVersion = [version]"0.0.0.0"
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        $currentVersion = [version](winget -v).Replace('v', '').Trim()
    }

    if ($currentVersion -ge $requiredVersion) {
        Write-Host "✅ Winget está atualizado ($currentVersion)." -ForegroundColor Green
    } else {
        Write-Host "🚀 Atualizando de $currentVersion a $requiredVersion..." -ForegroundColor Yellow
        $destination = "$env:USERPROFILE\Downloads\Winget_Update.msixbundle"
        Invoke-WebRequest -Uri $downloadUrl -OutFile $destination

       # --- AQUI ESTÁ A SOLUÇÃO PARA O ERRO 0x80073D02 ---
        Write-Host "🚀 Ecerrando processos bloquedos..." -ForegroundColor Yellow
        
		# Encerramos qualquer instância do Winget ou do instalador
        Get-Process -Name "WinGet", "AppInstaller" -ErrorAction SilentlyContinue | Stop-Process -Force
        Start-Sleep -Seconds 2 # Estamos dando um descanso ao sistema.
        Write-Host "🚀 Instalando pacote (forçando o encerramento do aplicativo)..."  -ForegroundColor Yellow
        
		# Usamos o parâmetro -ForceApplicationShutdown para fazer com que o próprio Windows tente fechar tudo o que estiver interferindo.
        Add-AppxPackage -Path $destination -ForceApplicationShutdown -ErrorAction Stop
        Write-Host "✅ Feito! Winget atualizado para a versão $requiredVersion." -ForegroundColor Green
        Remove-Item $destination -ErrorAction SilentlyContinue
    }
} catch {
    Write-Host "❌ Error: $_" -ForegroundColor Red
    Write-Host "🚀 Observação: Certifique-se de executar o PowerShell como ADMINISTRADOR.." -ForegroundColor Yellow
}

# Function to check if PowerShell 7+ is running
function Is-PowerShell7 {
    return $PSVersionTable.PSVersion.Major -ge 7
}
# Certifique-se de que estamos executando o PowerShell 7; caso contrário, instale-o e saia do script.
if (-not (Is-PowerShell7)) {
    Write-Host "🚀 É necessário o PowerShell 7 ou superior. Instalando o PowerShell 7..."  -ForegroundColor Yellow
    try {
        winget install --id Microsoft.Powershell --source winget --accept-package-agreements --accept-source-agreements --silent
        Write-Host "✅ PowerShell 7 Instalado com sucesso." -ForegroundColor Green
        Write-Host "✅ Continue no PowerShell 7." -ForegroundColor Green
        Start-Sleep -Seconds 2
        # Mudando para o PowerShell 7.
        $desktopPath = [System.IO.Path]::Combine($env:USERPROFILE, "Desktop",  $scriptName)
        Start-Process "pwsh" -ArgumentList "-NoProfile -NoExit -File `"$desktopPath`""
        exit
    } catch {
        Write-Host "❌ A instalação do PowerShell 7 falhou. Encerrando o script." -ForegroundColor Red
        exit
    }
} else {
    Write-Host "🚀 O PowerShell 7 já está em execução." -ForegroundColor Yellow
}

# Verifique e instale o Terminal do Windows, caso ainda não esteja instalado.
if (-not (Get-Command wt -ErrorAction SilentlyContinue)) {
    Write-Host "Terminal do Windows não encontrado, instalando..." -ForegroundColor Gray
    try {
        winget install --id Microsoft.WindowsTerminal -e --accept-package-agreements --accept-source-agreements --silent
        Write-Host "✅ O Terminal do Windows foi instalado com sucesso." -ForegroundColor Green
    } catch {
        Write-Host "❌ A instalação do Windows Terminal falhou. Saindo do script."  -ForegroundColor Red
        exit
    }
} else {
    Write-Host "🚀 O Terminal do Windows já está instalado." -ForegroundColor Yellow
}

# Instale Oh My Posh
if (-not (Get-Command oh-my-posh -ErrorAction SilentlyContinue)) {
    try {
        winget install JanDeDobbeleer.OhMyPosh -s winget --accept-package-agreements --accept-source-agreements --silent
        Write-Host "✅ Oh My Posh instalado com sucesso. Recarregar..." -ForegroundColor Green
        Start-Sleep -Seconds 2
        # Inicie outro PowerShell para carregar os comandos do Oh My Posh
        $desktopPath = [System.IO.Path]::Combine($env:USERPROFILE, "Desktop",$scriptName)
        Start-Process "pwsh" -ArgumentList "-NoProfile -File `"$desktopPath`""
        Start-Sleep -Seconds 1
        exit
    } catch {
        Write-Host "❌ A instalação do Oh My Posh falhou. Continuando..." -ForegroundColor Red
    }
}
# Define o caminho para a pasta de temas
$ThemesDir = Join-Path  $env:LOCALAPPDATA "Programs\oh-my-posh\themes"
# Cria a pasta se não existir
if (-not (Test-Path $ThemesDir)) {
    New-Item -ItemType Directory -Path $ThemesDir | Out-Null
    Write-Host "✅ Pasta criada em: $ThemesDir" -ForegroundColor Green
} else {
    Write-Host "🚀 A pasta já existe em: $ThemesDir" -ForegroundColor Yellow
}
# --- Função de detecção de fonte aprimorada ---
function Is-FontInstalled {
    param (
        [string]$FontName
    )
    # Caminhos do registro onde o Windows armazena as fontes instaladas
    $regPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts",
        "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts"
    )
    foreach ($path in $regPaths) {
        if (Test-Path $path) {
            # Verificamos se alguma propriedade do registro contém o nome da fonte
            $fonts = Get-ItemProperty -Path $path
            if ($fonts.PSObject.Properties.Name -like "*$FontName*") {
                return $true
            }
        }
    }
    return $false
}

# Instalar as fontes (se o OMP existir)
if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
    $fuentes = @("Meslo", "MesloLG Nerd Font")
    foreach ($f in $fuentes) {
        if (-not (Is-FontInstalled -FontName "$f*Nerd Font")) {
            Write-Host "🚀 Instalando fonte $f..." -ForegroundColor Yellow
            try {
                # Usamos o nome que o oh-my-posh reconhece internamente
                $nombreFuente = $f.ToLower()
                oh-my-posh font install $nombreFuente
                Write-Host "✅ $f instalada corretamente." -ForegroundColor Green
            } catch {
                Write-Host "❌ Erro ao instalar a fonte $f." -ForegroundColor Red
            }
        } else {
            Write-Host "🚀 A fonte $f já está instalada. Ignorando..." -ForegroundColor Yellow
        }
    }
}

# Obtenha o caminho do arquivo settings.json no Terminal do Windows
$terminalSettingsPath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
# Certifique-se de que o arquivo settings.json exista antes de tentar modificá-lo.
if (-not (Test-Path $terminalSettingsPath)) {
    Write-Host "❌ O arquivo Settings.json não foi encontrado. Certifique-se de que o Terminal do Windows esteja instalado e executado pelo menos uma vez." -ForegroundColor Red
    exit
}
# Leia o arquivo settings.json
$settingsJson = Get-Content -Path $terminalSettingsPath -Raw | ConvertFrom-Json
# Crie a seção 'defaults' se ela não existir.
if (-not $settingsJson.profiles.defaults) {
    $settingsJson.profiles.defaults = @{}
}
# Crie a seção 'fonte' se ela não existir.
if (-not $settingsJson.profiles.defaults.font) {
    $settingsJson.profiles.defaults | Add-Member -MemberType NoteProperty -Name "font" -Value @{}
}
$settingsJson.profiles.defaults.font.face = "MesloLGM Nerd Font"
$settingsJson.profiles.defaults.font.size = 12
# Salvar alterações em settings.json
$settingsJson | ConvertTo-Json -Depth 100 | Set-Content -Path $terminalSettingsPath -Force
Write-Host "✅ O arquivo Settings.json foi atualizado com a fonte MesloLGM Nerd e os perfis." -ForegroundColor Green

# Obtenha o caminho correto do perfil dependendo da versão do PowerShell
$profilePath = if (Is-PowerShell7) {
    "$env:USERPROFILE\Documents\PowerShell\Microsoft.PowerShell_profile.ps1"
} else {
    "$env:USERPROFILE\Documents\WindowsPowerShell\profile.ps1"
}
# Criar e editar perfil do PowerShell
try {
    if (-not (Test-Path $profilePath)) {
        New-Item -Path $profilePath -Type File -Force
    }
    $profileContent = Get-Content -Path $profilePath -Raw
	function Add-IfNotExists($path, $content) {
        if (-not ($profileContent -contains $content)) {
            Add-Content -Path $path -Value $content
        }
    }
	Add-IfNotExists $profilePath '$HistorySaveLocalPath = "D:\Programas\PowerShell\ConsoleHost_history.txt"'	
    #Add-IfNotExists $profilePath '$OhMyPoshThemesFile   = "~/AppData/Local/Programs/oh-my-posh/themes/HardDev.omp.json"' 
    Add-IfNotExists $profilePath '$OhMyPoshThemesFile   = "D:\Programas\PowerShell\Styles\HardDev.omp.json"' 
	Add-IfNotExists $profilePath '$StyleColors = @{'
    Add-IfNotExists $profilePath '	"Command"                   	= "#EFFA78"'
	Add-IfNotExists $profilePath '	"Comment"                    	= "#483C67"'
	Add-IfNotExists $profilePath '	"ContinuationPrompt"   	= "#E1E1E6"'
	Add-IfNotExists $profilePath '	"Default"                    		= "#E1E1E6"'
	Add-IfNotExists $profilePath '	"Emphasis"                   	= "#c678dd"'
	Add-IfNotExists $profilePath '	"Error"                      		= "#FF5555"'
	Add-IfNotExists $profilePath '	"InlinePrediction"          	= "#4D4D4D"'
	Add-IfNotExists $profilePath '	"Keyword"                    	= "#00008b"'
	Add-IfNotExists $profilePath '	"ListPrediction"             	= "#98c379"'
	Add-IfNotExists $profilePath '	"Member"                     	= "#E1E1E6"'
	Add-IfNotExists $profilePath '	"Number"                     	= "#98c379"'
	Add-IfNotExists $profilePath '	"Operator"                   	= "#757575"'
	Add-IfNotExists $profilePath '	"Parameter"                  	= "#4D4D4D"'
	Add-IfNotExists $profilePath '	"String"                     		= "#8D79BA"'
	Add-IfNotExists $profilePath '	"Type"                       		= "#008080"'
	Add-IfNotExists $profilePath '	"Variable"                   		= "#FF5555"'
	Add-IfNotExists $profilePath '	"ListPredictionSelected"	= "#41414D"'
	Add-IfNotExists $profilePath '	"Selection"                  		= "#41414D"}'
	Add-IfNotExists $profilePath 'Import-Module -Name Terminal-Icons'
	Add-IfNotExists $profilePath '$PSStyle.Formatting.FormatAccent	= $PSStyle.Foreground.FromRGB(0x008080)'
	Add-IfNotExists $profilePath '$PSStyle.Formatting.TableHeader      = $PSStyle.Foreground.FromRGB(0x483C67)'
	Add-IfNotExists $profilePath '$PSStyle.Formatting.ErrorAccent       = $PSStyle.Foreground.FromRGB(0xFF5555)'
	Add-IfNotExists $profilePath '$PSStyle.Formatting.Error              	= $PSStyle.Foreground.FromRGB(0xff2828)'
	Add-IfNotExists $profilePath '$PSStyle.Formatting.Warning            	= $PSStyle.Foreground.FromRGB(0xff9966)'
	Add-IfNotExists $profilePath '$PSStyle.Formatting.Verbose            	= $PSStyle.Foreground.FromRGB(0x008080)'
	Add-IfNotExists $profilePath '$PSStyle.Formatting.Debug              	= $PSStyle.Foreground.FromRGB(0x4D4D4D)'
	Add-IfNotExists $profilePath '$PSStyle.Progress.Style                		= $PSStyle.Foreground.FromRGB(0x41b15d)'
	Add-IfNotExists $profilePath '$PSStyle.FileInfo.Directory            		= $PSStyle.Background.FromRGB(0xFF6E67)'
	Add-IfNotExists $profilePath '$PSStyle.FileInfo.SymbolicLink         	= $PSStyle.Foreground.FromRGB(0x2f6aff)'
	Add-IfNotExists $profilePath '$PSStyle.FileInfo.Executable           	= $PSStyle.Foreground.FromRGB(0xB8B80A)'
	Add-IfNotExists $profilePath 'Set-PSReadLineOption -HistorySavePath $HistorySaveLocalPath'
	Add-IfNotExists $profilePath 'Set-PSReadLineOption -PredictionViewStyle ListView '
	Add-IfNotExists $profilePath 'Set-PSReadLineOption -Colors $StyleColors  '
	Add-IfNotExists $profilePath 'clear-host'
	Add-IfNotExists $profilePath 'oh-my-posh init pwsh --config $OhMyPoshThemesFile | Invoke-Expression'
	Add-IfNotExists $profilePath 'cls'
    Write-Host "✅ Perfil do PowerShell criado/atualizado com sucesso."  -ForegroundColor Green
} catch {
    Write-Host "❌ Falha ao criar ou atualizar o perfil do PowerShell. Continuando..." -ForegroundColor Red
}
# Defina a política de execução como Irrestrita para o usuário atual
try {
    Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope CurrentUser -Force
    Write-Host "✅ Política de execução definida como Irrestrita." -ForegroundColor Green
} catch {
    Write-Host "❌ Falha ao definir a política de execução. Continuando..." -ForegroundColor Red
}
# Baixe o tema personalizado do Oh My Posh se o Oh My Posh estiver instalado
if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
    try {
        $themePath = "$env:LOCALAPPDATA\Programs\oh-my-posh\themes\"
        Invoke-WebRequest -Uri "https://raw.githubusercontent.com/Rtrevisan20/TampletesDelphi/master/HardDev.omp.json" -OutFile $themePath
        Write-Host "✅ Tema personalizado baixado com sucesso."  -ForegroundColor Green
    } catch {
        Write-Host "❌ Falha ao baixar o tema personalizado. Continuando..."  -ForegroundColor Red
    }
} else {
    Write-Host "🚀 Oh My Posh não encontrado, pulando o download do tema." -ForegroundColor Yellow
}
# Instalar ícones do terminal
try {
    Install-Module -Name Terminal-Icons -Force
    Write-Host "✅ Módulo de ícones do terminal instalado com sucesso." -ForegroundColor Green
} catch {
    Write-Host "❌ Falha ao instalar os ícones do Terminal. Continuando..." -ForegroundColor Red
}
# Instale o Git (necessário para o posh-git)
try {
    winget install -e --id Git.Git --accept-package-agreements --accept-source-agreements --silent
    Write-Host "✅ Git instalado com sucesso." -ForegroundColor Green
} catch {
    Write-Host "❌ A instalação do Git falhou. Continuando..." -ForegroundColor Red
}
# Instale o posh-git (se o Git estiver instalado)
if (Get-Command git -ErrorAction SilentlyContinue) {
    try {
        Install-Module posh-git -Scope CurrentUser -Force 
        Write-Host "✅ posh-git instalado com sucesso." -ForegroundColor Green
    } catch {
        Write-Host "❌ A instalação do posh-git falhou. Continuando..." -ForegroundColor Red
    }
} else {
    Write-Host "🚀 Git não encontrado, instalação do posh-git ignorada." -ForegroundColor Yellow
}

# ==============================INSTALAÇÃO DO APPS=========================================
function Install-App {
    param (
        [string]$AppId,
        [string]$AppName
    )
    try {
        winget install -e --id $AppId --accept-package-agreements --accept-source-agreements --silent --source winget
        Write-Host "✅ $AppName Instalado com sucesso." -ForegroundColor Green
    } catch {
        Write-Host "❌ $AppName a instalação falhou. Continuando..." -ForegroundColor Red
    }
}
# Lista de aplicaciones a instalar
$apps = @(
    @{ id = "AnyDeskSoftwareGmbH.AnyDesk"; name = "AnyDesk" },
    @{ id = "Microsoft.PowerToys"; name = "PowerToys" },
	@{ id = "Mobatek.MobaXterm"; name = "MobaXterm" },
    @{ id = "Microsoft.VisualStudioCode"; name = "Visual Studio Code" },
	@{id = "Google.Chrome"; name = "Google Chrome"},
	@{id = "Notepad++.Notepad++"; name = "Notepad++"},
	@{id = "Microsoft.Teams"; name = "Teams"},
	@{id = "DBeaver.DBeaver.Community"; name = "DBeaver Community"},
	@{id = "Postman.Postman"; name = "Postman"},
	@{id = "Brave.Brave"; name = "Brave"},
	@{id = "Neomatica.RustDesk"; name = "RustDesk"},
	@{id = "TortoiseSVN.TortoiseSVN"; name = "TortoiseSVN"},
	@{id = "TortoiseGit.TortoiseGit"; name = "TortoiseGit"},
	@{id = "WhatsApp.WhatsApp"; name = "WhatsApp"},
	@{id = "WhatsApp.WhatsApp.Beta"; name = "WhatsApp Beta"},
	@{id = "Zoom.Zoom"; name = "Zoom"},
	@{id = "Foxit.FoxitReader"; name = "FoxitReader"},
	@{id = "Skillbrains.Lightshot"; name = "Lightshot"},
	@{id = "Figma.Figma"; name = "Figma"},
    @{ id = "7zip.7zip"; name = "7zip" }
)
# Instalar todas las aplicaciones
foreach ($app in $apps) {
    Install-App -AppId $app.id -AppName $app.name
}
# Update PowerShell Help
if (-not (Get-Help -ErrorAction SilentlyContinue)) {
    try {
        Update-Help
        Write-Host "✅ A Ajuda do PowerShell foi atualizada com sucesso." -ForegroundColor Green
    } catch {
        Write-Host "❌ Falha ao atualizar a Ajuda do PowerShell. Continuando..." -ForegroundColor Red
    }
} else {
    Write-Host "🚀 A Ajuda do PowerShell já foi atualizada." -ForegroundColor Yellow
}

#======================CONFIGURAÇÃO DO WSL COM UBUNTU========================
# Define a versão padrão do WSL para a versão 2
Write-Host "🚀 Definindo WSL 2 como versão padrão..." -ForegroundColor Cyan
wsl --set-default-version 2
# Define a distro a ser utilizada
$ubuntu = "Ubuntu-24.04"
# Verificando distros instaladas e incluindo a distro padrão
Write-Host "Verificando distros instaladas..." -ForegroundColor Yellow
# Verifica se essa versão do Ubuntu encontra-se instalada
$installed_distros_raw = wsl --list --quiet
$installed_distros = @()
for ($i = 0; $i -lt $installed_distros_raw.length; $i++) {
    $aux = $installed_distros_raw[$i] -replace "[^a-zA-Z-0-9.]"
    if ($aux.length -gt 0) { 
        $installed_distros += ,$aux
    }
}
# Verifica se $ubuntu está em $installed_distros
$ubuntu_installed = $false
foreach ($distro in $installed_distros) {
    if ($distro -eq $ubuntu) {
        $ubuntu_installed = $true
    }
}
Write-Host "Distros instaladas:" -ForegroundColor Yellow
foreach ($distro in $installed_distros) {
    Write-Host "🚀 $distro" -ForegroundColor Green
}
# Se a distro não estiver instalada, instala
if ($ubuntu_installed) {
    Write-Host "✅ A distro $ubuntu já está instalada." -ForegroundColor Cyan
} else {
    Write-Host "❌ A distro $ubuntu não está instalada." -ForegroundColor Red
    Write-Host "🚀 Instalando a distro $ubuntu..." -ForegroundColor Yellow
    if (Get-Command wt -ErrorAction SilentlyContinue) {
        wt -w 0 wsl --install -d $ubuntu
    } else {
        Start-Process wsl.exe -ArgumentList "--install -d $ubuntu"
    }
}
# Espera a instalação da distro
$count = 0
while ($true) {
    $installed_distros_raw = wsl --list --quiet
    $installed_distros = @()
    for ($i = 0; $i -lt $installed_distros_raw.length; $i++) {
        $aux = $installed_distros_raw[$i] -replace "[^a-zA-Z-0-9.]"
        if ($aux.length -gt 0) { 
            $installed_distros += ,$aux
        }
    }
    $ubuntu_installed = $false
    foreach ($distro in $installed_distros) {
        if ($distro -eq $ubuntu) {
            $ubuntu_installed = $true
        }
    }
    if ($ubuntu_installed) {
        Write-Host "✅ A instalação da distro $ubuntu foi concluída." -ForegroundColor Green
        break
    }
    Start-Sleep -Seconds 1
    $count += 1
    if ($count -gt 60) {
        Write-Host "❌ A instalação da distro $ubuntu falhou." -ForegroundColor Red
        exit -1
    }
}
# Write-Host "Definindo a distro $ubuntu como a distro padrão de instalação"
wsl --set-default $ubuntu
Write-Host "Definindo todas as distros como WSL 2:" -ForegroundColor Yellow
$installed_distros_raw = wsl --list --quiet
$installed_distros = @()
for ($i = 0; $i -lt $installed_distros_raw.length; $i++) {
    $aux = $installed_distros_raw[$i] -replace "[^a-zA-Z-0-9.]"
    if ($aux.length -gt 0) { 
        $installed_distros += ,$aux
    }
}
# Define a versão WSL 2 para cada distro listada
foreach ($distro in $installed_distros) {
    Write-Host "Definindo WSL 2 como a versão para $distro..." -ForegroundColor Cyan
    $command = (wsl --set-version $distro) 2> $null
}

Write-Host "Execução do script concluída!" -ForegroundColor Green