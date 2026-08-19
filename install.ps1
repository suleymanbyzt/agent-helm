# agent-helm installer (Windows)
# Usage:
#   .\install.ps1 [-Target <project-dir>]   install into one project (default: cwd)
#   .\install.ps1 -Global                   install for your user, all projects
#   .\install.ps1 -Uninstall [-Target ...]  remove from a project
#   .\install.ps1 -Global -Uninstall        remove the global install
param([string]$Target = ".", [switch]$Global, [switch]$Uninstall)

$ErrorActionPreference = "Stop"
$Src = $PSScriptRoot
$Target = (Resolve-Path $Target).Path

# Standalone mode (irm | iex): no repo files next to the script — fetch them.
if (-not $Src -or -not (Test-Path "$Src\core\AGENTS.md")) {
    $zipUrl = if ($env:AGENT_HELM_ZIP) { $env:AGENT_HELM_ZIP }
              else { "https://github.com/suleymanbyzt/agent-helm/archive/refs/heads/master.zip" }
    $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("agent-helm-" + [guid]::NewGuid())
    New-Item -ItemType Directory -Path $tmp | Out-Null
    Write-Host "Fetching agent-helm..."
    Invoke-WebRequest $zipUrl -OutFile "$tmp\repo.zip"
    Expand-Archive "$tmp\repo.zip" -DestinationPath $tmp
    $Src = (Get-ChildItem $tmp -Directory |
        Where-Object { Test-Path "$($_.FullName)\core\AGENTS.md" } |
        Select-Object -First 1).FullName
}

# Insert/refresh a marked agent-helm block inside a user-level config file,
# leaving everything else untouched. Idempotent.
$StartMark = "<!-- agent-helm:start -->"
$EndMark = "<!-- agent-helm:end -->"
function Install-Block([string]$File, [string]$Content) {
    New-Item -ItemType Directory -Force -Path (Split-Path $File) | Out-Null
    $block = "$StartMark`n$Content`n$EndMark"
    if ((Test-Path $File) -and ((Get-Content $File -Raw) -match [regex]::Escape($StartMark))) {
        $existing = Get-Content $File -Raw
        $pattern = [regex]::Escape($StartMark) + "[\s\S]*?" + [regex]::Escape($EndMark)
        Set-Content -Path $File -Value ([regex]::Replace($existing, $pattern, $block))
        Write-Host "  ~ $File (agent-helm block refreshed)"
    } else {
        $prefix = if ((Test-Path $File) -and (Get-Item $File).Length -gt 0) { "`n" } else { "" }
        Add-Content -Path $File -Value "$prefix$block"
        Write-Host "  + $File (agent-helm block added)"
    }
}

function Copy-Skills([string]$Dest) {
    New-Item -ItemType Directory -Force -Path $Dest | Out-Null
    $count = 0
    Get-ChildItem "$Src\skills" -Directory | ForEach-Object {
        New-Item -ItemType Directory -Force -Path "$Dest\$($_.Name)" | Out-Null
        Copy-Item "$($_.FullName)\SKILL.md" "$Dest\$($_.Name)\SKILL.md"
        $count++
    }
    Write-Host "  + $Dest\ ($count skills)"
}

function Remove-Block([string]$File) {
    if (-not (Test-Path $File)) { return }
    $existing = Get-Content $File -Raw
    if ($existing -notmatch [regex]::Escape($StartMark)) { return }
    $pattern = [regex]::Escape($StartMark) + "[\s\S]*?" + [regex]::Escape($EndMark)
    $result = [regex]::Replace($existing, $pattern, "")
    if ($result.Trim().Length -eq 0) { Remove-Item $File }
    else { Set-Content -Path $File -Value $result.TrimEnd() }
    Write-Host "  - $File (agent-helm block removed)"
}

function Remove-Skills([string]$Dest) {
    if (-not (Test-Path $Dest)) { return }
    Get-ChildItem "$Src\skills" -Directory | ForEach-Object {
        Remove-Item -Recurse -Force "$Dest\$($_.Name)" -ErrorAction SilentlyContinue
    }
    if (-not (Get-ChildItem $Dest -ErrorAction SilentlyContinue)) { Remove-Item $Dest }
    Write-Host "  - $Dest\ (agent-helm skills removed)"
}

# Remove a file only if it is byte-identical to ours (never a user-edited copy).
function Remove-IfOurs([string]$Ours, [string]$Theirs) {
    if (-not (Test-Path $Theirs)) { return }
    if ((Get-FileHash $Ours).Hash -eq (Get-FileHash $Theirs).Hash) {
        Remove-Item $Theirs
        Write-Host "  - $Theirs"
    } else {
        Write-Host "  ! $Theirs was modified - left in place, review it yourself."
    }
}

if ($Uninstall) {
    if ($Global) {
        Write-Host "Removing global agent-helm install"
        Remove-Block "$HOME\.claude\CLAUDE.md"
        Remove-Skills "$HOME\.claude\skills"
        Remove-Block "$HOME\.codex\AGENTS.md"
        Remove-Skills "$HOME\.agents\skills"
    } else {
        Write-Host "Removing agent-helm from: $Target"
        Remove-IfOurs "$Src\core\AGENTS.md" "$Target\AGENTS.md"
        Remove-IfOurs "$Src\core\AGENTS.md" "$Target\AGENTS.helm.md"
        Remove-IfOurs "$Src\core\CLAUDE.md" "$Target\CLAUDE.md"
        Remove-Skills "$Target\.claude\skills"
        Remove-Skills "$Target\.agents\skills"
        foreach ($d in @("$Target\.claude", "$Target\.agents")) {
            if ((Test-Path $d) -and -not (Get-ChildItem $d)) { Remove-Item $d }
        }
        Remove-IfOurs "$Src\templates\journal.md" "$Target\templates\journal.md"
        Remove-IfOurs "$Src\templates\integration-brief.md" "$Target\templates\integration-brief.md"
        Remove-IfOurs "$Src\templates\decision.md" "$Target\templates\decision.md"
        if ((Test-Path "$Target\templates") -and -not (Get-ChildItem "$Target\templates")) { Remove-Item "$Target\templates" }
        # Journals, briefs, and decisions are YOUR project history — never deleted.
        foreach ($d in @("$Target\docs\agent-journal", "$Target\docs\briefs", "$Target\docs\decisions")) {
            if (Test-Path $d) {
                Remove-Item "$d\.gitkeep" -ErrorAction SilentlyContinue
                if (-not (Get-ChildItem $d)) { Remove-Item $d; Write-Host "  - $d\ (was empty)" }
                else { Write-Host "  = $d\ kept - your journal entries stay yours." }
            }
        }
        if ((Test-Path "$Target\docs") -and -not (Get-ChildItem "$Target\docs")) { Remove-Item "$Target\docs" }
    }
    Write-Host ""
    Write-Host "Done."
    exit 0
}

if ($Global) {
    Write-Host "Installing agent-helm globally (for your user, all projects)"

    # Claude Code: ~\.claude\CLAUDE.md = constitution + advisor loop, ~\.claude\skills\
    $constitution = Get-Content "$Src\core\AGENTS.md" -Raw
    $advisorLoop = (Get-Content "$Src\core\CLAUDE.md" | Where-Object { $_ -notmatch "^@AGENTS\.md" }) -join "`n"
    Install-Block "$HOME\.claude\CLAUDE.md" "$constitution`n$advisorLoop"
    Copy-Skills "$HOME\.claude\skills"

    # Codex: ~\.codex\AGENTS.md = constitution, ~\.agents\skills\
    Install-Block "$HOME\.codex\AGENTS.md" $constitution
    Copy-Skills "$HOME\.agents\skills"

    Write-Host ""
    Write-Host "Done. Applies to all YOUR projects (new sessions). Teammates are not"
    Write-Host "affected - for team-wide rules, run the per-project install and commit."
    exit 0
}

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

# 4. Templates + journal/brief/decision directories
foreach ($dir in @("docs\agent-journal", "docs\briefs", "docs\decisions", "templates")) {
    New-Item -ItemType Directory -Force -Path "$Target\$dir" | Out-Null
}
Copy-Item "$Src\templates\journal.md" "$Target\templates\journal.md"
Copy-Item "$Src\templates\integration-brief.md" "$Target\templates\integration-brief.md"
Copy-Item "$Src\templates\decision.md" "$Target\templates\decision.md"
New-Item -ItemType File -Force -Path "$Target\docs\agent-journal\.gitkeep" | Out-Null
New-Item -ItemType File -Force -Path "$Target\docs\briefs\.gitkeep" | Out-Null
New-Item -ItemType File -Force -Path "$Target\docs\decisions\.gitkeep" | Out-Null
Write-Host "  + templates\, docs\agent-journal\, docs\briefs\, docs\decisions\"

Write-Host ""
Write-Host "Done. Commit the new files so the whole team's agents use the same rules."
