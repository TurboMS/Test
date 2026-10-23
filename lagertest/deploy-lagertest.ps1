# deploy-lagertest.ps1
# Lagger upp/uppdaterar "Lagertest Utrullning" (index.html) pa GitHub Pages.
# Kors fran samma mapp som index.html. Loggar allt till deploy-log.txt i samma mapp.
# Steg: installera git + GitHub CLI vid behov -> logga in -> skapa/uppdatera repo -> aktivera Pages -> skriv ut lank.

$ErrorActionPreference = 'Continue'  # native stderr far inte avbryta i PS 5.1; koder kontrolleras explicit
$RepoName = 'kart-lagertest'
$Here     = Split-Path -Parent $MyInvocation.MyCommand.Path
$Log      = Join-Path $Here 'deploy-log.txt'
$Work     = Join-Path $env:USERPROFILE $RepoName

function Log($msg, $level = 'INFO') {
    $line = "{0} [{1}] {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $level, $msg
    Add-Content -Path $Log -Value $line -Encoding UTF8
    $color = @{ INFO = 'Gray'; OK = 'Green'; WARN = 'Yellow'; FEL = 'Red' }[$level]
    Write-Host $line -ForegroundColor $color
}
function Run($desc, [scriptblock]$cmd, [switch]$AllowFail) {
    Log "START: $desc"
    $out = & $cmd 2>&1 | Out-String
    $code = $LASTEXITCODE
    if ($out.Trim()) { Add-Content -Path $Log -Value ("    " + ($out.Trim() -replace "`n", "`n    ")) -Encoding UTF8 }
    if ($code -ne 0 -and $null -ne $code) {
        if ($AllowFail) { Log "$desc gav kod $code (tillatet)" 'WARN'; return @{ ok = $false; out = $out; code = $code } }
        Log "$desc misslyckades, kod $code" 'FEL'
        throw "STEG MISSLYCKADES: $desc (kod $code)"
    }
    Log "KLART: $desc" 'OK'
    return @{ ok = $true; out = $out; code = 0 }
}
function RefreshPath {
    $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')
}

try {
    Log "===== Ny korning. Mapp: $Here ====="
    Log ("PowerShell {0}, Windows {1}" -f $PSVersionTable.PSVersion, [Environment]::OSVersion.Version)

    if (-not (Test-Path (Join-Path $Here 'index.html'))) {
        Log "index.html saknas i $Here. Lagg skriptet och index.html i samma mapp." 'FEL'; throw 'index.html saknas'
    }

    # 1. Verktyg
    foreach ($tool in @(@{ cmd = 'git'; id = 'Git.Git' }, @{ cmd = 'gh'; id = 'GitHub.cli' })) {
        if (Get-Command $tool.cmd -ErrorAction SilentlyContinue) { Log "$($tool.cmd) finns redan" 'OK'; continue }
        if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
            Log "winget saknas. Installera 'App Installer' fran Microsoft Store och kor igen." 'FEL'; throw 'winget saknas'
        }
        Run "Installera $($tool.id)" { winget install --id $tool.id -e --silent --accept-source-agreements --accept-package-agreements } | Out-Null
        RefreshPath
        if (-not (Get-Command $tool.cmd -ErrorAction SilentlyContinue)) {
            Log "$($tool.cmd) installerades men hittas inte. Stang fonstret och kor skriptet igen." 'FEL'; throw "$($tool.cmd) ej i PATH"
        }
    }
    Run 'git version' { git --version } | Out-Null
    Run 'gh version'  { gh --version } | Out-Null

    # 2. Inloggning
    $st = Run 'Kontrollera GitHub-inloggning' { gh auth status -h github.com } -AllowFail
    if (-not $st.ok) {
        Log 'Inte inloggad. En webblasare oppnas: logga in/skapa konto pa GitHub och klistra in koden som visas har.' 'WARN'
        gh auth login -h github.com -p https -w
        if ($LASTEXITCODE -ne 0) { Log "gh auth login misslyckades, kod $LASTEXITCODE" 'FEL'; throw 'inloggning misslyckades' }
        Log 'Inloggad' 'OK'
    }
    $User = (gh api user --jq .login).Trim()
    $UserId = (gh api user --jq .id).Trim()
    if (-not $User) { Log 'Kunde inte lasa GitHub-anvandarnamn' 'FEL'; throw 'inget anvandarnamn' }
    Log "GitHub-anvandare: $User" 'OK'
    Run 'Koppla git till GitHub-inloggningen' { gh auth setup-git } | Out-Null

    # 3. Arbetsmapp med repo
    if (-not (Test-Path $Work)) { New-Item -ItemType Directory -Path $Work | Out-Null; Log "Skapade $Work" }
    Copy-Item (Join-Path $Here 'index.html') $Work -Force
    if (Test-Path (Join-Path $Here 'README.md')) { Copy-Item (Join-Path $Here 'README.md') $Work -Force }
    New-Item -ItemType File -Path (Join-Path $Work '.nojekyll') -Force | Out-Null
    Set-Location $Work

    $exists = Run 'Kolla om repot finns pa GitHub' { gh repo view "$User/$RepoName" --json name } -AllowFail
    if (-not (Test-Path (Join-Path $Work '.git'))) {
        if ($exists.ok) {
            Log 'Repot finns pa GitHub men inte lokalt, hamtar historik' 'WARN'
            Run 'git init' { git init -b main } | Out-Null
            Run 'Lagg till remote' { git remote add origin "https://github.com/$User/$RepoName.git" } | Out-Null
            Run 'Hamta' { git fetch origin main } -AllowFail | Out-Null
            Run 'Synka mot main' { git reset --soft origin/main } -AllowFail | Out-Null
        } else {
            Run 'git init' { git init -b main } | Out-Null
        }
    }
    if (-not (git config user.email)) { Run 'Satt git-e-post' { git config user.email "$UserId+$User@users.noreply.github.com" } | Out-Null }
    if (-not (git config user.name))  { Run 'Satt git-namn'   { git config user.name $User } | Out-Null }

    Run 'git add' { git add -A } | Out-Null
    $changes = (git status --porcelain | Out-String).Trim()
    if ($changes) { Run 'git commit' { git commit -m ("Uppdatera lagertest " + (Get-Date -Format 'yyyy-MM-dd HH:mm')) } | Out-Null }
    else { Log 'Inga andringar att committa' }

    if (-not $exists.ok) {
        Run 'Skapa publikt repo och pusha' { gh repo create $RepoName --public --source . --remote origin --push --description 'Lagertest Utrullning: friktionsmatning av kartlager med mobilens gyro' } | Out-Null
    } else {
        Run 'Pusha' { git push -u origin main } | Out-Null
    }

    # 4. GitHub Pages
    $pg = Run 'Kolla Pages-status' { gh api "repos/$User/$RepoName/pages" } -AllowFail
    if (-not $pg.ok) {
        Run 'Aktivera GitHub Pages (main, /)' { gh api -X POST "repos/$User/$RepoName/pages" -f 'source[branch]=main' -f 'source[path]=/' } | Out-Null
    } else { Log 'Pages redan aktivt' 'OK' }

    $Url = "https://$User.github.io/$RepoName/"
    Log 'Vantar pa att sidan byggs (upp till 3 min)...'
    $built = $false
    for ($i = 0; $i -lt 36; $i++) {
        Start-Sleep -Seconds 5
        $s = (gh api "repos/$User/$RepoName/pages/builds/latest" --jq .status 2>$null)
        if ($s) { $s = $s.Trim() }
        if ($s -eq 'built') { $built = $true; break }
        if ($s -eq 'errored') { Log 'Pages-bygget gav fel. Se repo -> Actions pa GitHub.' 'FEL'; break }
    }
    if ($built) { Log "KLART. Oppna pa mobilen: $Url" 'OK' }
    else { Log "Bygget ar inte bekraftat an. Prova lanken om nagon minut: $Url" 'WARN' }
    Set-Clipboard -Value $Url -ErrorAction SilentlyContinue
    Write-Host ""
    Write-Host "  Lank (kopierad till urklipp): $Url" -ForegroundColor Cyan
    Write-Host "  Logg: $Log"
}
catch {
    Log ("AVBRUTET: " + $_.Exception.Message) 'FEL'
    Log ("Rad: " + $_.InvocationInfo.ScriptLineNumber) 'FEL'
    Write-Host "`nNagot gick fel. Skicka filen $Log till Claude." -ForegroundColor Red
    exit 1
}
