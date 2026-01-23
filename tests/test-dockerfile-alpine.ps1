# Unit tests for Dockerfile.alpine
# Tests Requirements: 2.1, 2.5

# Test counters
$script:TestsRun = 0
$script:TestsPassed = 0
$script:TestsFailed = 0

# Helper functions
function Pass {
    param([string]$Message)
    Write-Host "✅ PASS: $Message" -ForegroundColor Green
    $script:TestsPassed++
}

function Fail {
    param([string]$Message, [string]$Details)
    Write-Host "❌ FAIL: $Message" -ForegroundColor Red
    Write-Host "   Details: $Details" -ForegroundColor Yellow
    $script:TestsFailed++
}

function Test-Start {
    param([string]$Name)
    $script:TestsRun++
    Write-Host ""
    Write-Host "Test $($script:TestsRun): $Name"
}

# Test 1: Verify Dockerfile.alpine exists
Test-Start "Dockerfile.alpine exists"
if (Test-Path "Dockerfile.alpine") {
    Pass "Dockerfile.alpine file exists"
} else {
    Fail "Dockerfile.alpine file not found" "Expected file at ./Dockerfile.alpine"
    exit 1
}

# Read the Dockerfile content
$dockerfileContent = Get-Content "Dockerfile.alpine" -Raw

# Test 2: Verify base image is Alpine 3.19 or higher
# Requirement 2.1: THE Alpine构建器 SHALL 使用 Alpine Linux 3.19 或更高版本作为基础镜像
Test-Start "Base image is Alpine 3.19 or higher"
if ($dockerfileContent -match "FROM alpine:3\.19" -or 
    $dockerfileContent -match "FROM alpine:3\.[2-9]\d" -or 
    $dockerfileContent -match "FROM alpine:[4-9]\.") {
    $baseImage = ($dockerfileContent -split "`n" | Where-Object { $_ -match "FROM alpine:" } | Select-Object -First 1).Trim()
    Pass "Base image uses Alpine 3.19+: $baseImage"
} else {
    $baseImage = ($dockerfileContent -split "`n" | Where-Object { $_ -match "FROM alpine:" } | Select-Object -First 1)
    if ($baseImage) {
        Fail "Base image version is not 3.19 or higher" "Found: $baseImage"
    } else {
        Fail "Base image version is not 3.19 or higher" "No Alpine base image found"
    }
}

# Test 3: Verify all required apk packages are present
# Requirement 2.2: THE Alpine构建器 SHALL 使用 apk 包管理器安装构建依赖项
# Requirement 2.3: THE Alpine构建器 SHALL 为所有 Debian 构建依赖项安装 Alpine 等效包
Test-Start "All required apk packages are present"
$requiredPackages = @(
    "build-base",
    "git",
    "curl",
    "wget",
    "ca-certificates",
    "autoconf",
    "automake",
    "libtool",
    "pkgconfig",
    "gd-dev",
    "libxslt-dev",
    "libmaxminddb-dev",
    "linux-pam-dev",
    "perl-dev",
    "readline-dev",
    "ncurses-dev",
    "pcre2-dev",
    "openssl-dev",
    "zlib-dev",
    "zstd-dev",
    "libxml2-dev",
    "luajit-dev"
)

$missingPackages = @()
foreach ($package in $requiredPackages) {
    if ($dockerfileContent -notmatch [regex]::Escape($package)) {
        $missingPackages += $package
    }
}

if ($missingPackages.Count -eq 0) {
    Pass "All $($requiredPackages.Count) required packages are present"
} else {
    Fail "Missing $($missingPackages.Count) required packages" "Missing: $($missingPackages -join ', ')"
}

# Test 4: Verify apk add command is used (not apt-get)
# Requirement 2.2: THE Alpine构建器 SHALL 使用 apk 包管理器安装构建依赖项
Test-Start "Uses apk package manager (not apt-get)"
if ($dockerfileContent -match "apk add") {
    Pass "Uses apk package manager"
} else {
    Fail "Does not use apk package manager" "Expected 'apk add' command"
}

# Test 5: Verify no glibc-specific dependencies
# Requirement 2.5: THE Alpine构建器 SHALL NOT 包含任何 glibc 特定的依赖项
Test-Start "No glibc-specific dependencies present"
$glibcPackages = @(
    "libc6",
    "libc6-dev",
    "glibc",
    "apt-get",
    "dpkg",
    "libc-dev"
)

$foundGlibc = @()
foreach ($package in $glibcPackages) {
    if ($dockerfileContent -match [regex]::Escape($package)) {
        $foundGlibc += $package
    }
}

if ($foundGlibc.Count -eq 0) {
    Pass "No glibc-specific dependencies found"
} else {
    Fail "Found glibc-specific dependencies" "Found: $($foundGlibc -join ', ')"
}

# Test 6: Verify LuaJIT Alpine package is used
# Requirement 2.4: WHEN 安装 LuaJIT 时 THE Alpine构建器 SHALL 使用 Alpine 仓库中的 luajit-dev 包
Test-Start "Uses Alpine's luajit-dev package"
if ($dockerfileContent -match "luajit-dev") {
    Pass "Uses Alpine's luajit-dev package"
} else {
    Fail "Does not use Alpine's luajit-dev package" "Expected 'luajit-dev' in package list"
}

# Test 7: Verify build script is copied
Test-Start "Build script is copied"
if ($dockerfileContent -match "COPY build-alpine\.sh") {
    Pass "build-alpine.sh is copied"
} else {
    Fail "build-alpine.sh is not copied" "Expected 'COPY build-alpine.sh' command"
}

# Test 8: Verify versions.env is copied
Test-Start "versions.env is copied"
if ($dockerfileContent -match "COPY versions\.env") {
    Pass "versions.env is copied"
} else {
    Fail "versions.env is not copied" "Expected 'COPY versions.env' command"
}

# Test 9: Verify export stage exists
Test-Start "Export stage exists"
if ($dockerfileContent -match "FROM scratch AS export") {
    Pass "Export stage is defined"
} else {
    Fail "Export stage is not defined" "Expected 'FROM scratch AS export'"
}

# Test 10: Verify shell is /bin/sh (not /bin/bash)
Test-Start "Uses POSIX shell (/bin/sh)"
if ($dockerfileContent -match "/bin/sh") {
    Pass "Uses /bin/sh for POSIX compatibility"
} else {
    Fail "Does not explicitly use /bin/sh" "Alpine uses /bin/sh by default, but explicit usage is recommended"
}

# Test 11: Verify no Debian-specific package names in RUN commands
Test-Start "No Debian-specific package names in RUN commands"
$debianPackages = @(
    "libssl-dev",
    "libpcre2-dev",
    "zlib1g-dev",
    "libzstd-dev",
    "libgd-dev",
    "libxslt1-dev",
    "libpam0g-dev",
    "libperl-dev",
    "libreadline-dev",
    "libncurses5-dev",
    "build-essential"
)

# Extract only RUN commands (not comments)
$runCommands = ($dockerfileContent -split "`n" | Where-Object { $_ -match "^\s*RUN\s+" -or ($_ -match "^\s+\w" -and $_ -notmatch "^\s*#") }) -join " "

$foundDebian = @()
foreach ($package in $debianPackages) {
    if ($runCommands -match [regex]::Escape($package)) {
        $foundDebian += $package
    }
}

if ($foundDebian.Count -eq 0) {
    Pass "No Debian-specific package names found in RUN commands"
} else {
    Fail "Found Debian-specific package names in RUN commands" "Found: $($foundDebian -join ', ')"
}

# Test 12: Verify NGINX_VERSION ARG is defined
Test-Start "NGINX_VERSION ARG is defined"
if ($dockerfileContent -match "ARG NGINX_VERSION") {
    Pass "NGINX_VERSION ARG is defined"
} else {
    Fail "NGINX_VERSION ARG is not defined" "Expected 'ARG NGINX_VERSION'"
}

# Print summary
Write-Host ""
Write-Host "=========================================="
Write-Host "Test Summary"
Write-Host "=========================================="
Write-Host "Total tests run: $($script:TestsRun)"
Write-Host "Passed: $($script:TestsPassed)" -ForegroundColor Green
if ($script:TestsFailed -gt 0) {
    Write-Host "Failed: $($script:TestsFailed)" -ForegroundColor Red
} else {
    Write-Host "Failed: $($script:TestsFailed)"
}
Write-Host "=========================================="

# Exit with appropriate code
if ($script:TestsFailed -gt 0) {
    exit 1
} else {
    Write-Host "All tests passed!" -ForegroundColor Green
    exit 0
}
