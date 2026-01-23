# Test script for release description generation (PowerShell)
# Validates Requirements: 13.3, 13.4, 13.7, 13.8

$ErrorActionPreference = "Stop"

Write-Host "Testing Release Description Generation..."

# Test 1: Verify mainline/stable detection logic
Write-Host "`nTest 1: Mainline/Stable Detection"

function Test-VersionDetection {
    param(
        [string]$Version,
        [string]$Expected
    )
    
    $minorVersion = [int]($Version.Split('.')[1])
    
    if ($minorVersion % 2 -eq 1) {
        $releaseType = "mainline"
    } else {
        $releaseType = "stable"
    }
    
    if ($releaseType -eq $Expected) {
        Write-Host "  ✅ Version $Version correctly detected as $releaseType"
    } else {
        Write-Host "  ❌ Version $Version incorrectly detected as $releaseType (expected $Expected)"
        exit 1
    }
}

# Test mainline versions (odd minor numbers)
Test-VersionDetection -Version "1.29.4" -Expected "mainline"
Test-VersionDetection -Version "1.27.1" -Expected "mainline"
Test-VersionDetection -Version "1.25.3" -Expected "mainline"

# Test stable versions (even minor numbers)
Test-VersionDetection -Version "1.28.2" -Expected "stable"
Test-VersionDetection -Version "1.26.0" -Expected "stable"
Test-VersionDetection -Version "1.24.1" -Expected "stable"

# Test 2: Verify workflow contains release description generation
Write-Host "`nTest 2: Workflow Contains Release Description Step"
$workflowContent = Get-Content -Path ".github/workflows/build.yml" -Raw
if ($workflowContent -match "Generate Release Description") {
    Write-Host "  ✅ Workflow contains 'Generate Release Description' step"
} else {
    Write-Host "  ❌ Workflow missing 'Generate Release Description' step"
    exit 1
}

# Test 3: Verify release description includes mainline/stable explanation
Write-Host "`nTest 3: Release Description Includes Mainline/Stable Explanation"
if ($workflowContent -match "Mainline vs Stable") {
    Write-Host "  ✅ Release description includes mainline/stable explanation"
} else {
    Write-Host "  ❌ Release description missing mainline/stable explanation"
    exit 1
}

# Test 4: Verify release description lists all four artifacts
Write-Host "`nTest 4: Release Description Lists All Four Artifacts"
$artifactMatches = [regex]::Matches($workflowContent, "nginx-mainline-mk.*\.tar\.gz")
if ($artifactMatches.Count -ge 4) {
    Write-Host "  ✅ Release description lists all four artifacts"
} else {
    Write-Host "  ❌ Release description missing artifact listings (found $($artifactMatches.Count) references)"
    exit 1
}

# Test 5: Verify release description includes Debian vs Alpine differences
Write-Host "`nTest 5: Release Description Includes Debian vs Alpine Differences"
if ($workflowContent -match "Debian vs Alpine Differences") {
    Write-Host "  ✅ Release description includes Debian vs Alpine differences"
} else {
    Write-Host "  ❌ Release description missing Debian vs Alpine differences"
    exit 1
}

# Test 6: Verify release title includes release type (Mainline/Stable)
Write-Host "`nTest 6: Release Title Includes Release Type"
if ($workflowContent -match 'name: Nginx \$\{\{ steps\.release_type\.outputs\.RELEASE_LABEL \}\}') {
    Write-Host "  ✅ Release title includes release type label"
} else {
    Write-Host "  ❌ Release title missing release type label"
    exit 1
}

# Test 7: Verify release description includes verification instructions
Write-Host "`nTest 7: Release Description Includes Verification Instructions"
if ($workflowContent -match "sha256sum -c") {
    Write-Host "  ✅ Release description includes checksum verification instructions"
} else {
    Write-Host "  ❌ Release description missing verification instructions"
    exit 1
}

# Test 8: Verify release description includes quick start examples
Write-Host "`nTest 8: Release Description Includes Quick Start Examples"
if ($workflowContent -match "Quick Start") {
    Write-Host "  ✅ Release description includes quick start examples"
} else {
    Write-Host "  ❌ Release description missing quick start examples"
    exit 1
}

Write-Host "`n✅ All release description tests passed!"
