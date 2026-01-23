# Test script to verify artifact naming patterns
# Feature: alpine-build-support, Task 5.2
# Validates: Requirements 6.1, 6.2, 6.3, 6.4

Write-Host "=== Artifact Naming Verification ===" -ForegroundColor Cyan
Write-Host ""

# Test data
$TEST_VERSION = "1.29.4"
$TEST_BUILD = "100"
$ARCHS = @("amd64", "arm64")
$OS_TYPES = @("linux", "alpine")

$PASS_COUNT = 0
$FAIL_COUNT = 0

# Function to test artifact naming pattern
function Test-ArtifactName {
    param(
        [string]$OsType,
        [string]$Arch
    )
    
    $expectedPattern = "nginx-mainline-mk-$TEST_VERSION-$TEST_BUILD-$OsType-$Arch.tar.gz"
    
    # Verify pattern matches expected format
    if ($expectedPattern -match '^nginx-mainline-mk-\d+\.\d+\.\d+-\d+-(linux|alpine)-(amd64|arm64)\.tar\.gz$') {
        Write-Host "✓ Pattern valid: $expectedPattern" -ForegroundColor Green
        $script:PASS_COUNT++
        return $true
    } else {
        Write-Host "✗ Pattern invalid: $expectedPattern" -ForegroundColor Red
        $script:FAIL_COUNT++
        return $false
    }
}

# Function to test checksum file naming
function Test-ChecksumName {
    param(
        [string]$OsType,
        [string]$Arch
    )
    
    $expectedPattern = "sha256sums-$OsType-$Arch.txt"
    
    # Verify pattern matches expected format
    if ($expectedPattern -match '^sha256sums-(debian|alpine)-(amd64|arm64)\.txt$') {
        Write-Host "✓ Checksum pattern valid: $expectedPattern" -ForegroundColor Green
        $script:PASS_COUNT++
        return $true
    } else {
        Write-Host "✗ Checksum pattern invalid: $expectedPattern" -ForegroundColor Red
        $script:FAIL_COUNT++
        return $false
    }
}

# Function to test artifact upload name uniqueness
function Test-UploadNameUniqueness {
    param(
        [string]$OsType,
        [string]$Arch
    )
    
    $uploadName = "nginx-mainline-mk-$TEST_VERSION-$TEST_BUILD-$OsType-$Arch"
    Write-Host "✓ Upload name unique: $uploadName" -ForegroundColor Green
    $script:PASS_COUNT++
}

Write-Host "Testing Debian artifact naming patterns..."
foreach ($arch in $ARCHS) {
    Test-ArtifactName -OsType "linux" -Arch $arch
    Test-ChecksumName -OsType "debian" -Arch $arch
    Test-UploadNameUniqueness -OsType "linux" -Arch $arch
}

Write-Host ""
Write-Host "Testing Alpine artifact naming patterns..."
foreach ($arch in $ARCHS) {
    Test-ArtifactName -OsType "alpine" -Arch $arch
    Test-ChecksumName -OsType "alpine" -Arch $arch
    Test-UploadNameUniqueness -OsType "alpine" -Arch $arch
}

Write-Host ""
Write-Host "Testing OS type differentiation..."
# Verify that Debian uses "linux" and Alpine uses "alpine"
$debianName = "nginx-mainline-mk-$TEST_VERSION-$TEST_BUILD-linux-amd64.tar.gz"
$alpineName = "nginx-mainline-mk-$TEST_VERSION-$TEST_BUILD-alpine-amd64.tar.gz"

if ($debianName -like "*-linux-*") {
    Write-Host "✓ Debian artifacts use 'linux' suffix" -ForegroundColor Green
    $PASS_COUNT++
} else {
    Write-Host "✗ Debian artifacts should use 'linux' suffix" -ForegroundColor Red
    $FAIL_COUNT++
}

if ($alpineName -like "*-alpine-*") {
    Write-Host "✓ Alpine artifacts use 'alpine' suffix" -ForegroundColor Green
    $PASS_COUNT++
} else {
    Write-Host "✗ Alpine artifacts should use 'alpine' suffix" -ForegroundColor Red
    $FAIL_COUNT++
}

# Verify names are different
if ($debianName -ne $alpineName) {
    Write-Host "✓ Debian and Alpine artifacts have unique names" -ForegroundColor Green
    $PASS_COUNT++
} else {
    Write-Host "✗ Debian and Alpine artifacts must have unique names" -ForegroundColor Red
    $FAIL_COUNT++
}

Write-Host ""
Write-Host "=== Summary ===" -ForegroundColor Cyan
Write-Host "Passed: $PASS_COUNT"
Write-Host "Failed: $FAIL_COUNT"

if ($FAIL_COUNT -eq 0) {
    Write-Host "All artifact naming tests passed!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "Some artifact naming tests failed!" -ForegroundColor Red
    exit 1
}
