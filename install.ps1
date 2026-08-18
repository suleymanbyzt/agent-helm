# agent-helm installer (Windows)
# Usage: .\install.ps1 [-Target <project-dir>]   (default: current directory)
param([string]$Target = ".")

$ErrorActionPreference = "Stop"
$Src = $PSScriptRoot
$Target = (Resolve-Path $Target).Path

Write-Host "Installing agent-helm into: $Target"

# 1. AGENTS.md — the constitution (read natively by Codex, Cursor, Copilot, ...)
if (Test-Path "$Target\AGENTS.md") {
    $srcHash = (Get-FileHash "$Src\core\AGENTS.md").Hash
    $dstHash = (Get-FileHash "$Target\AGENTS.md").Hash
    if ($srcHash -eq $dstHash) {
        Write-Host "  = AGENTS.md already up to date"
    } else {
        Copy-Item "$Src\core\AGENTS.md" "$Target\AGENTS.helm.md"
        Write-Host "  ! AGENTS.md already exists - wrote AGENTS.helm.md instead."
        Write-Host "    Merge it into your AGENTS.md manually."
    }
} else {
    Copy-Item "$Src\core\AGENTS.md" "$Target\AGENTS.md"
    Write-Host "  + AGENTS.md"
}

# 2. CLAUDE.md — imports AGENTS.md (official pattern) + Claude-specific setup
if (Test-Path "$Target\CLAUDE.md") {
    $srcHash = (Get-FileHash "$Src\core\CLAUDE.md").Hash
    $dstHash = (Get-FileHash "$Target\CLAUDE.md").Hash
    $claudeMd = Get-Content "$Target\CLAUDE.md" -Raw
    if ($srcHash -eq $dstHash) {
        Write-Host "  = CLAUDE.md already up to date"
    } elseif ($claudeMd -match "@AGENTS\.md") {
        Write-Host "  = CLAUDE.md exists and imports AGENTS.md - keeping yours."
        Write-Host "    (See core/CLAUDE.md for the recommended advisor-loop setup.)"
    } else {
        Write-Host "  ! CLAUDE.md already exists. Add this line to it yourself: @AGENTS.md"
    }
} else {
    Copy-Item "$Src\core\CLAUDE.md" "$Target\CLAUDE.md"
    Write-Host "  + CLAUDE.md (imports AGENTS.md + advisor loop)"
}

# 3. Skills — same files, both agents' native locations
#    Claude Code: .claude\skills\   Codex: .agents\skills\
$skillCount = 0
foreach ($dest in @(".claude\skills", ".agents\skills")) {
    New-Item -ItemType Directory -Force -Path "$Target\$dest" | Out-Null
    $skillCount = 0
    Get-ChildItem "$Src\skills" -Directory | ForEach-Object {
        $name = $_.Name
        New-Item -ItemType Directory -Force -Path "$Target\$dest\$name" | Out-Null
        Copy-Item "$($_.FullName)\SKILL.md" "$Target\$dest\$name\SKILL.md"
        $skillCount++
    }
    Write-Host "  + $dest\ ($skillCount skills)"
}

# 4. Templates + journal/brief directories
foreach ($dir in @("docs\agent-journal", "docs\briefs", "templates")) {
    New-Item -ItemType Directory -Force -Path "$Target\$dir" | Out-Null
}
Copy-Item "$Src\templates\journal.md" "$Target\templates\journal.md"
Copy-Item "$Src\templates\integration-brief.md" "$Target\templates\integration-brief.md"
New-Item -ItemType File -Force -Path "$Target\docs\agent-journal\.gitkeep" | Out-Null
New-Item -ItemType File -Force -Path "$Target\docs\briefs\.gitkeep" | Out-Null
Write-Host "  + templates\, docs\agent-journal\, docs\briefs\"

Write-Host ""
Write-Host "Done. Commit the new files so the whole team's agents use the same rules."
