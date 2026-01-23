# Test script to verify GitHub Actions workflow artifact configuration
# Feature: alpine-build-support, Task 5.2
# Validates: Requirements 6.1, 6.2, 6.3, 6.4

Write-Host "=== Workflow Artifact Configuration Verification ===" -ForegroundColor Cyan
Write-Host ""

$PASS_COUNT = 0
$FAIL_COUNT = 0

# Read the workflow file
$workflowPath = ".github/workflows/build.yml"
if (-not (Test-Path $workflowPath)) {
    Write-Host "✗ Workflow file not found: $workflowPath" -ForegroundColor Red
    exit 1
}

$workflowContent = Get-Content $workflowPath -Raw

Write-Host "Testing Debian artifact configuration..."

# Test 1: Debian rename step uses correct pattern
if ($workflowContent -match 'mv \./output/nginx-custom\.tar\.gz \./output/nginx-mainline-mk-\$\{\{ env\.VERSION \}\}-\$\{\{ github\.run_number \}\}-linux-\$\{\{ matrix\.arch \}\}\.tar\.gz') {
    Write-Host "✓ Debian rename step uses correct naming pattern (linux-{arch})" -ForegroundColor Green
    $PASS_COUNT++
} else {
    Write-Host "✗ Debian rename step does not use correct naming pattern" -ForegroundColor Red
    $FAIL_COUNT++
}

# Test 2: Debian upload step uses correct artifact name
if ($workflowContent -match 'name: nginx-mainline-mk-\$\{\{ env\.VERSION \}\}-\$\{\{ github\.run_number \}\}-linux-\$\{\{ matrix\.arch \}\}') {
    Write-Host "✓ Debian upload step uses correct artifact name" -ForegroundColor Green
    $PASS_COUNT++
} else {
    Write-Host "✗ Debian upload step does not use correct artifact name" -ForegroundColor Red
    $FAIL_COUNT++
}

# Test 3: Debian checksum file uses correct naming
if ($workflowContent -match 'sha256sums-debian-\$\{\{ matrix\.arch \}\}\.txt') {
    Write-Host "✓ Debian checksum file uses correct naming pattern" -ForegroundColor Green
    $PASS_COUNT++
} else {
    Write-Host "✗ Debian checksum file does not use correct naming pattern" -ForegroundColor Red
    $FAIL_COUNT++
}

Write-Host ""
Write-Host "Testing Alpine artifact configuration..."

# Test 4: Alpine rename step uses correct pattern
if ($workflowContent -match 'mv \./output/nginx-custom\.tar\.gz \./output/nginx-mainline-mk-\$\{\{ env\.VERSION \}\}-\$\{\{ github\.run_number \}\}-alpine-\$\{\{ matrix\.arch \}\}\.tar\.gz') {
    Write-Host "✓ Alpine rename step uses correct naming pattern (alpine-{arch})" -ForegroundColor Green
    $PASS_COUNT++
} else {
    Write-Host "✗ Alpine rename step does not use correct naming pattern" -ForegroundColor Red
    $FAIL_COUNT++
}

# Test 5: Alpine upload step uses correct artifact name
if ($workflowContent -match 'name: nginx-mainline-mk-\$\{\{ env\.VERSION \}\}-\$\{\{ github\.run_number \}\}-alpine-\$\{\{ matrix\.arch \}\}') {
    Write-Host "✓ Alpine upload step uses correct artifact name" -ForegroundColor Green
    $PASS_COUNT++
} else {
    Write-Host "✗ Alpine upload step does not use correct artifact name" -ForegroundColor Red
    $FAIL_COUNT++
}

# Test 6: Alpine checksum file uses correct naming
if ($workflowContent -match 'sha256sums-alpine-\$\{\{ matrix\.arch \}\}\.txt') {
    Write-Host "✓ Alpine checksum file uses correct naming pattern" -ForegroundColor Green
    $PASS_COUNT++
} else {
    Write-Host "✗ Alpine checksum file does not use correct naming pattern" -ForegroundColor Red
    $FAIL_COUNT++
}

Write-Host ""
Write-Host "Testing artifact uniqueness..."

# Test 7: Verify Debian and Alpine use different OS suffixes
$debianMatches = [regex]::Matches($workflowContent, '-linux-\$\{\{ matrix\.arch \}\}')
$alpineMatches = [regex]::Matches($workflowContent, '-alpine-\$\{\{ matrix\.arch \}\}')

if ($debianMatches.Count -gt 0 -and $alpineMatches.Count -gt 0) {
    Write-Host "✓ Both Debian (linux) and Alpine (alpine) OS suffixes are present" -ForegroundColor Green
    $PASS_COUNT++
} else {
    Write-Host "✗ Missing OS suffixes in artifact names" -ForegroundColor Red
    $FAIL_COUNT++
}

# Test 8: Verify no duplicate artifact names
if ($workflowContent -notmatch 'name: nginx-mainline-mk-\$\{\{ env\.VERSION \}\}-\$\{\{ github\.run_number \}\}-\$\{\{ matrix\.arch \}\}[^-]') {
    Write-Host "✓ No artifacts use old naming pattern without OS type" -ForegroundColor Green
    $PASS_COUNT++
} else {
    Write-Host "✗ Found artifacts using old naming pattern without OS type" -ForegroundColor Red
    $FAIL_COUNT++
}

Write-Host ""
Write-Host "Testing test workflow configuration..."

# Read the test workflow file
$testWorkflowPath = ".github/workflows/test.yml"
if (Test-Path $testWorkflowPath) {
    $testWorkflowContent = Get-Content $testWorkflowPath -Raw
    
    # Test 9: Test workflow downloads correct artifact name
    if ($testWorkflowContent -match 'name: nginx-mainline-mk-\$\{\{ inputs\.version \}\}-linux-amd64') {
        Write-Host "✓ Test workflow downloads Debian artifact with correct name" -ForegroundColor Green
        $PASS_COUNT++
    } else {
        Write-Host "✗ Test workflow does not download artifact with correct name" -ForegroundColor Red
        $FAIL_COUNT++
    }
} else {
    Write-Host "⚠ Test workflow file not found: $testWorkflowPath" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=== Summary ===" -ForegroundColor Cyan
Write-Host "Passed: $PASS_COUNT"
Write-Host "Failed: $FAIL_COUNT"

if ($FAIL_COUNT -eq 0) {
    Write-Host "All workflow artifact configuration tests passed!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "Some workflow artifact configuration tests failed!" -ForegroundColor Red
    exit 1
}
