# Unit tests for CI parallel build configuration
# Tests Requirements: 7.1, 7.2, 7.8
# Task: 5.4 编写单元测试验证 CI 配置

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "CI Parallel Build Configuration Tests" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

$PASS_COUNT = 0
$FAIL_COUNT = 0
$TEST_COUNT = 0

function Test-Start {
    param([string]$TestName)
    $script:TEST_COUNT++
    Write-Host ""
    Write-Host "Test $script:TEST_COUNT`: $TestName"
}

function Pass {
    param([string]$Message)
    Write-Host "✓ PASS: $Message" -ForegroundColor Green
    $script:PASS_COUNT++
}

function Fail {
    param([string]$Message, [string]$Details)
    Write-Host "✗ FAIL: $Message" -ForegroundColor Red
    Write-Host "   Details: $Details" -ForegroundColor Yellow
    $script:FAIL_COUNT++
}

# Verify workflow file exists
$workflowFile = ".github/workflows/build.yml"
if (-not (Test-Path $workflowFile)) {
    Write-Host "✗ ERROR: Workflow file not found: $workflowFile" -ForegroundColor Red
    exit 1
}

Write-Host "Testing file: $workflowFile"
Write-Host ""

$workflowContent = Get-Content $workflowFile -Raw

# Test 1: Verify build-debian job exists
# Requirement 7.1: THE CI流水线 SHALL 使用独立的 GitHub Actions 作业（job）分别构建 Debian 和 Alpine 变体
Test-Start "build-debian job is defined"
if ($workflowContent -match '(?m)^  build-debian:') {
    Pass "build-debian job is defined in workflow"
} else {
    Fail "build-debian job is not defined" "Expected 'build-debian:' job definition"
}

# Test 2: Verify build-alpine job exists
# Requirement 7.1: THE CI流水线 SHALL 使用独立的 GitHub Actions 作业（job）分别构建 Debian 和 Alpine 变体
Test-Start "build-alpine job is defined"
if ($workflowContent -match '(?m)^  build-alpine:') {
    Pass "build-alpine job is defined in workflow"
} else {
    Fail "build-alpine job is not defined" "Expected 'build-alpine:' job definition"
}

# Extract job sections first
$lines = $workflowContent -split "`n"
$debianStart = -1
$debianEnd = -1
$alpineStart = -1
$alpineEnd = -1

for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match '^\s{2}build-debian:\s*$') {
        $debianStart = $i
    } elseif ($debianStart -ge 0 -and $debianEnd -lt 0 -and $lines[$i] -match '^\s{2}[a-z][\w-]*:\s*$') {
        $debianEnd = $i - 1
    }
    
    if ($lines[$i] -match '^\s{2}build-alpine:\s*$') {
        $alpineStart = $i
    } elseif ($alpineStart -ge 0 -and $alpineEnd -lt 0 -and $lines[$i] -match '^\s{2}[a-z][\w-]*:\s*$') {
        $alpineEnd = $i - 1
    }
}

if ($debianEnd -lt 0) { $debianEnd = $lines.Count - 1 }
if ($alpineEnd -lt 0) { $alpineEnd = $lines.Count - 1 }

$debianJob = $lines[$debianStart..$debianEnd] -join "`n"
$alpineJob = $lines[$alpineStart..$alpineEnd] -join "`n"

# Test 3: Verify build-debian has no needs dependency on build-alpine
# Requirement 7.2: THE CI流水线 SHALL 并行执行 Debian 和 Alpine 构建作业，而不是串行执行
Test-Start "build-debian has no needs dependency on build-alpine"
if ($debianJob -match 'needs:.*build-alpine') {
    Fail "build-debian has needs dependency on build-alpine" "Jobs should run in parallel, not serially"
} else {
    Pass "build-debian has no needs dependency on build-alpine"
}

# Test 4: Verify build-alpine has no needs dependency on build-debian
# Requirement 7.2: THE CI流水线 SHALL 并行执行 Debian 和 Alpine 构建作业，而不是串行执行
Test-Start "build-alpine has no needs dependency on build-debian"
if ($alpineJob -match 'needs:.*build-debian') {
    Fail "build-alpine has needs dependency on build-debian" "Jobs should run in parallel, not serially"
} else {
    Pass "build-alpine has no needs dependency on build-debian"
}

# Test 5: Verify build-debian uses matrix strategy
# Requirement 7.8: THE CI流水线 SHALL 使用矩阵策略（matrix strategy）定义构建变体
Test-Start "build-debian uses matrix strategy"
if ($debianJob -match 'strategy:') {
    Pass "build-debian uses matrix strategy"
} else {
    Fail "build-debian does not use matrix strategy" "Expected 'strategy:' section in build-debian job"
}

# Test 6: Verify build-alpine uses matrix strategy
# Requirement 7.8: THE CI流水线 SHALL 使用矩阵策略（matrix strategy）定义构建变体
Test-Start "build-alpine uses matrix strategy"
if ($alpineJob -match 'strategy:') {
    Pass "build-alpine uses matrix strategy"
} else {
    Fail "build-alpine does not use matrix strategy" "Expected 'strategy:' section in build-alpine job"
}

# Test 7: Verify build-debian matrix includes amd64
# Requirement 7.3: WHEN CI流水线被触发时 THE Debian构建作业 SHALL 构建 AMD64 和 ARM64 两个架构
Test-Start "build-debian matrix includes amd64"
if ($debianJob -match 'amd64') {
    Pass "build-debian matrix includes amd64"
} else {
    Fail "build-debian matrix does not include amd64" "Expected 'amd64' in matrix.arch"
}

# Test 8: Verify build-debian matrix includes arm64
# Requirement 7.3: WHEN CI流水线被触发时 THE Debian构建作业 SHALL 构建 AMD64 和 ARM64 两个架构
Test-Start "build-debian matrix includes arm64"
if ($debianJob -match 'arm64') {
    Pass "build-debian matrix includes arm64"
} else {
    Fail "build-debian matrix does not include arm64" "Expected 'arm64' in matrix.arch"
}

# Test 9: Verify build-alpine matrix includes amd64
# Requirement 7.4: WHEN CI流水线被触发时 THE Alpine构建作业 SHALL 构建 AMD64 和 ARM64 两个架构
Test-Start "build-alpine matrix includes amd64"
if ($alpineJob -match 'amd64') {
    Pass "build-alpine matrix includes amd64"
} else {
    Fail "build-alpine matrix does not include amd64" "Expected 'amd64' in matrix.arch"
}

# Test 10: Verify build-alpine matrix includes arm64
# Requirement 7.4: WHEN CI流水线被触发时 THE Alpine构建作业 SHALL 构建 AMD64 和 ARM64 两个架构
Test-Start "build-alpine matrix includes arm64"
if ($alpineJob -match 'arm64') {
    Pass "build-alpine matrix includes arm64"
} else {
    Fail "build-alpine matrix does not include arm64" "Expected 'arm64' in matrix.arch"
}

# Test 11: Verify build-debian uses fail-fast: false
# Requirement 7.6: WHEN 任何构建变体失败时 THE CI流水线 SHALL 报告失败但不阻塞其他变体
Test-Start "build-debian uses fail-fast: false"
if ($debianJob -match 'fail-fast:\s*false') {
    Pass "build-debian uses fail-fast: false"
} else {
    Fail "build-debian does not use fail-fast: false" "Expected 'fail-fast: false' to allow other builds to continue"
}

# Test 12: Verify build-alpine uses fail-fast: false
# Requirement 7.6: WHEN 任何构建变体失败时 THE CI流水线 SHALL 报告失败但不阻塞其他变体
Test-Start "build-alpine uses fail-fast: false"
if ($alpineJob -match 'fail-fast:\s*false') {
    Pass "build-alpine uses fail-fast: false"
} else {
    Fail "build-alpine does not use fail-fast: false" "Expected 'fail-fast: false' to allow other builds to continue"
}

# Extract test-debian job section
$testDebianStart = -1
$testDebianEnd = -1
$testAlpineStart = -1
$testAlpineEnd = -1
$releaseStart = -1
$releaseEnd = -1

for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match '^\s{2}test-debian:\s*$') {
        $testDebianStart = $i
    } elseif ($testDebianStart -ge 0 -and $testDebianEnd -lt 0 -and $lines[$i] -match '^\s{2}[a-z][\w-]*:\s*$') {
        $testDebianEnd = $i - 1
    }
    
    if ($lines[$i] -match '^\s{2}test-alpine:\s*$') {
        $testAlpineStart = $i
    } elseif ($testAlpineStart -ge 0 -and $testAlpineEnd -lt 0 -and $lines[$i] -match '^\s{2}[a-z][\w-]*:\s*$') {
        $testAlpineEnd = $i - 1
    }
    
    if ($lines[$i] -match '^\s{2}release:\s*$') {
        $releaseStart = $i
    } elseif ($releaseStart -ge 0 -and $releaseEnd -lt 0 -and $lines[$i] -match '^\s{2}[a-z][\w-]*:\s*$') {
        $releaseEnd = $i - 1
    }
}

if ($testDebianEnd -lt 0) { $testDebianEnd = $lines.Count - 1 }
if ($testAlpineEnd -lt 0) { $testAlpineEnd = $lines.Count - 1 }
if ($releaseEnd -lt 0) { $releaseEnd = $lines.Count - 1 }

$testDebianJob = $lines[$testDebianStart..$testDebianEnd] -join "`n"
$testAlpineJob = $lines[$testAlpineStart..$testAlpineEnd] -join "`n"
$releaseJob = $lines[$releaseStart..$releaseEnd] -join "`n"

# Test 13: Verify test-debian job depends on both build-debian and build-alpine
# Requirement 7.7: THE CI流水线 SHALL 为 Alpine 和 Debian 构建生成独立的构建报告
Test-Start "test-debian job depends on both build-debian and build-alpine"
if ($testDebianJob -match 'needs:\s*\[build-debian,\s*build-alpine\]' -or 
    $testDebianJob -match 'needs:\s*\[build-alpine,\s*build-debian\]') {
    Pass "test-debian job depends on both build-debian and build-alpine"
} else {
    Fail "test-debian job does not depend on both build jobs" "Expected 'needs: [build-debian, build-alpine]'"
}

# Test 13.1: Verify test-alpine job depends on both build-debian and build-alpine
# Requirement 7.7: THE CI流水线 SHALL 为 Alpine 和 Debian 构建生成独立的构建报告
Test-Start "test-alpine job depends on both build-debian and build-alpine"
if ($testAlpineJob -match 'needs:\s*\[build-debian,\s*build-alpine\]' -or 
    $testAlpineJob -match 'needs:\s*\[build-alpine,\s*build-debian\]') {
    Pass "test-alpine job depends on both build-debian and build-alpine"
} else {
    Fail "test-alpine job does not depend on both build jobs" "Expected 'needs: [build-debian, build-alpine]'"
}

# Test 13.2: Verify test-debian calls test.yml workflow
Test-Start "test-debian calls test.yml workflow"
if ($testDebianJob -match 'uses:.*test\.yml') {
    Pass "test-debian calls test.yml workflow"
} else {
    Fail "test-debian does not call test.yml workflow" "Expected 'uses: ./.github/workflows/test.yml'"
}

# Test 13.3: Verify test-alpine calls test-alpine.yml workflow
Test-Start "test-alpine calls test-alpine.yml workflow"
if ($testAlpineJob -match 'uses:.*test-alpine\.yml') {
    Pass "test-alpine calls test-alpine.yml workflow"
} else {
    Fail "test-alpine does not call test-alpine.yml workflow" "Expected 'uses: ./.github/workflows/test-alpine.yml'"
}

# Test 13.4: Verify release job depends on both test-debian and test-alpine
Test-Start "release job depends on both test-debian and test-alpine"
if ($releaseJob -match 'needs:\s*\[test-debian,\s*test-alpine\]' -or 
    $releaseJob -match 'needs:\s*\[test-alpine,\s*test-debian\]') {
    Pass "release job depends on both test-debian and test-alpine"
} else {
    Fail "release job does not depend on both test jobs" "Expected 'needs: [test-debian, test-alpine]'"
}

# Test 14: Verify build-alpine uses Dockerfile.alpine
Test-Start "build-alpine uses Dockerfile.alpine"
if ($alpineJob -match 'Dockerfile\.alpine') {
    Pass "build-alpine uses Dockerfile.alpine"
} else {
    Fail "build-alpine does not use Dockerfile.alpine" "Expected '--file Dockerfile.alpine' in build command"
}

# Test 15: Verify build-debian does NOT use Dockerfile.alpine
Test-Start "build-debian does NOT use Dockerfile.alpine"
if ($debianJob -match 'Dockerfile\.alpine') {
    Fail "build-debian incorrectly uses Dockerfile.alpine" "Debian build should use default Dockerfile"
} else {
    Pass "build-debian does not use Dockerfile.alpine (uses default Dockerfile)"
}

# Test 16: Verify both jobs use matrix.arch variable
Test-Start "Both jobs use matrix.arch variable"
$debianArchCount = ([regex]::Matches($debianJob, '\$\{\{\s*matrix\.arch\s*\}\}')).Count
$alpineArchCount = ([regex]::Matches($alpineJob, '\$\{\{\s*matrix\.arch\s*\}\}')).Count

if ($debianArchCount -gt 0 -and $alpineArchCount -gt 0) {
    Pass "Both jobs use matrix.arch variable (Debian: $debianArchCount times, Alpine: $alpineArchCount times)"
} else {
    Fail "Jobs do not properly use matrix.arch variable" "Debian: $debianArchCount, Alpine: $alpineArchCount"
}

# Test 17: Verify both jobs set up QEMU for cross-platform builds
# Requirement 3.5: WHEN 在 AMD64 主机上为 ARM64 编译时 THE Alpine构建器 SHALL 使用 QEMU 模拟
Test-Start "Both jobs set up QEMU for cross-platform builds"
$debianHasQemu = $debianJob -match 'setup-qemu-action'
$alpineHasQemu = $alpineJob -match 'setup-qemu-action'

if ($debianHasQemu -and $alpineHasQemu) {
    Pass "Both jobs set up QEMU for cross-platform builds"
} else {
    Fail "Jobs do not set up QEMU" "Debian: $debianHasQemu, Alpine: $alpineHasQemu"
}

# Test 18: Verify both jobs set up Docker Buildx
# Requirement 3.4: THE Alpine构建器 SHALL 使用 Docker Buildx 进行跨平台编译
Test-Start "Both jobs set up Docker Buildx"
$debianHasBuildx = $debianJob -match 'setup-buildx-action'
$alpineHasBuildx = $alpineJob -match 'setup-buildx-action'

if ($debianHasBuildx -and $alpineHasBuildx) {
    Pass "Both jobs set up Docker Buildx"
} else {
    Fail "Jobs do not set up Docker Buildx" "Debian: $debianHasBuildx, Alpine: $alpineHasBuildx"
}

# Print summary
Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Test Summary" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Total tests run: $TEST_COUNT"
Write-Host "Passed: $PASS_COUNT" -ForegroundColor Green
if ($FAIL_COUNT -gt 0) {
    Write-Host "Failed: $FAIL_COUNT" -ForegroundColor Red
} else {
    Write-Host "Failed: $FAIL_COUNT"
}
Write-Host "==========================================" -ForegroundColor Cyan

# Exit with appropriate code
if ($FAIL_COUNT -gt 0) {
    exit 1
} else {
    Write-Host "All tests passed!" -ForegroundColor Green
    exit 0
}
