[CmdletBinding()]
param (
    [string]$OutputFile = "repo_full_export.txt"
)

$ExcludeDirs = @('.git', '__pycache__', 'node_modules', 'dist', 'build', '.venv', 'venv', '.vs', '.idea')$ExcludeExts = @('.png', '.jpg', '.jpeg', '.gif', '.ico', '.pdf', '.zip', '.tar', '.gz', '.7z',
                 '.exe', '.dll', '.so', '.dylib', '.pyc', '.pyd', '.class', '.o', '.obj')

Write-Host "Exporting repository contents to $OutputFile..." -ForegroundColor Cyan

$sb = [System.Text.StringBuilder]::new()

[void]$sb.AppendLine("==================================================")
[void]$sb.AppendLine("REPOSITORY DIRECTORY STRUCTURE")
[void]$sb.AppendLine("==================================================")

$allFiles = Get-ChildItem -Path . -Recurse -File | Where-Object {
    $filePath =$_.FullName
    $ext =$_.Extension.ToLower()

    $inExcludedDir =$false
    foreach ($dir in$ExcludeDirs) {
        if ($filePath -match "[\\/]$([regex]::Escape($dir))[\\/]") {
            $inExcludedDir =$true
            break
        }
    }

    -not $inExcludedDir -and ($ExcludeExts -notcontains$ext) -and ($_.Name -ne$OutputFile)
}

foreach ($file in$allFiles) {
    $relativePath = Resolve-Path -Path$file.FullName -Relative
    [void]$sb.AppendLine($relativePath)
}

[void]$sb.AppendLine("`n==================================================")
[void]$sb.AppendLine("FILE CONTENTS")
[void]$sb.AppendLine("==================================================")

foreach ($file in $allFiles) {
    $relativePath = Resolve-Path -Path $file.FullName -Relative
    [void]$sb.AppendLine("`n========================================")
    [void]$sb.AppendLine("FILE: $relativePath")
    [void]$sb.AppendLine("========================================")

    try {
        $content = Get-Content -LiteralPath$file.FullName -Raw -ErrorAction Stop
        [void]$sb.AppendLine($content)
    }
    catch {
        [void]$sb.AppendLine("[Error reading file: $_]")
    }
}

[System.IO.File]::WriteAllText((Join-Path (Get-Location) $OutputFile),$sb.ToString(), [System.Text.Encoding]::UTF8)

Write-Host "Done! Export saved to: $OutputFile" -ForegroundColor Green
