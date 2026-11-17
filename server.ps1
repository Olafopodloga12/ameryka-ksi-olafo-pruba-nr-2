param (
    [int]$startPort = 8080
)

$currentDir = $PSScriptRoot
if (-not $currentDir) { $currentDir = (Get-Location).Path }

# Find an available port starting from $startPort
$port = $startPort
$listener = $null
$started = $false

while (-not $started -and $port -lt ($startPort + 50)) {
    try {
        $tempListener = New-Object System.Net.HttpListener
        $tempListener.Prefixes.Add("http://localhost:$port/")
        $tempListener.Start()
        $listener = $tempListener
        $started = $true
    } catch {
        if ($tempListener) {
            try { $tempListener.Close() } catch {}
        }
        $port++
    }
}

if (-not $started) {
    Write-Host "Nie udalo sie znalezc wolnego portu HTTP." -ForegroundColor Red
    exit 1
}

try {
    Write-Host "==================================================" -ForegroundColor Green
    Write-Host "   Olafo Killer vs Pierogi - Serwer Uruchomiony!" -ForegroundColor Yellow
    Write-Host "   Adres gry: http://localhost:$port" -ForegroundColor Cyan
    Write-Host "   Nacisnij Ctrl+C, aby zatrzymac serwer." -ForegroundColor Gray
    Write-Host "==================================================" -ForegroundColor Green

    Start-Process "http://localhost:$port"

    while ($listener.IsListening) {
        $context = $listener.GetContext()
        $request = $context.Request
        $response = $context.Response

        $path = $request.Url.LocalPath.TrimStart('/')
        if ([string]::IsNullOrWhiteSpace($path)) { $path = "index.html" }

        # Normalize path
        $path = [System.Uri]::UnescapeDataString($path).Replace('/', [System.IO.Path]::DirectorySeparatorChar)
        $filePath = Join-Path $currentDir $path

        if (Test-Path $filePath -PathType Leaf) {
            $ext = [System.IO.Path]::GetExtension($filePath).ToLower()
            $mime = switch ($ext) {
                ".html" { "text/html; charset=utf-8" }
                ".css"  { "text/css; charset=utf-8" }
                ".js"   { "application/javascript; charset=utf-8" }
                ".png"  { "image/png" }
                ".jpg"  { "image/jpeg" }
                ".svg"  { "image/svg+xml" }
                ".json" { "application/json; charset=utf-8" }
                Default { "application/octet-stream" }
            }

            $bytes = [System.IO.File]::ReadAllBytes($filePath)
            $response.ContentType = $mime
            $response.ContentLength64 = $bytes.Length
            $response.AddHeader("Cache-Control", "no-cache")
            if ($request.HttpMethod -ne "HEAD") {
                $response.OutputStream.Write($bytes, 0, $bytes.Length)
            }
        } else {
            $response.StatusCode = 404
            $errBytes = [System.Text.Encoding]::UTF8.GetBytes("404 Not Found: $path")
            $response.OutputStream.Write($errBytes, 0, $errBytes.Length)
        }
        $response.Close()
    }
} catch {
    # Ignored on Ctrl+C or listener abort
} finally {
    if ($listener) {
        try {
            if ($listener.IsListening) { $listener.Stop() }
            $listener.Close()
        } catch {}
    }
}
