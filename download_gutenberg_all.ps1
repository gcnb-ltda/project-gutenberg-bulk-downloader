param(
    [string]$Destination = "$HOME\ProjectGutenberg",
    [ValidateSet("full","generated","main")]
    [string]$Mode = "full"
)

$ErrorActionPreference = "Stop"

function Require-Rsync {
    if (-not (Get-Command rsync -ErrorAction SilentlyContinue)) {
        Write-Host "Erro: rsync não encontrado."
        Write-Host "No Windows, use WSL/Ubuntu ou Cygwin e instale rsync."
        exit 1
    }
}

function Sync-One([string]$Module, [string]$Target) {
    New-Item -ItemType Directory -Force -Path $Target | Out-Null
    Write-Host "Sincronizando $Module -> $Target"

    & rsync -avHS --partial --info=progress2 --timeout=600 --delete `
        "gutenberg.pglaf.org::$Module" "$Target"

    if ($LASTEXITCODE -ne 0) {
        Write-Host "Servidor principal indisponível; tentando ibiblio..."
        & rsync -avHS --partial --info=progress2 --timeout=600 --delete `
            "rsync.ibiblio.org::$Module" "$Target"

        if ($LASTEXITCODE -ne 0) {
            throw "Falha ao sincronizar o módulo $Module."
        }
    }
}

Require-Rsync
New-Item -ItemType Directory -Force -Path $Destination | Out-Null

switch ($Mode) {
    "full" {
        Sync-One "gutenberg" (Join-Path $Destination "main")
        Sync-One "gutenberg-epub" (Join-Path $Destination "generated")
    }
    "generated" {
        Sync-One "gutenberg-epub" (Join-Path $Destination "generated")
    }
    "main" {
        Sync-One "gutenberg" (Join-Path $Destination "main")
    }
}

Write-Host ""
Write-Host "Concluído."
Write-Host "Destino: $Destination"
