# Unit tests for build-alpine.sh
# Tests Requirements: 5.1, 5.3, 6.4

$ErrorActionPreference = "Stop"

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
    param([string]$TestName)
    $script:TestsRun++
    Write-Host ""
    Write-Host "Test $($script:TestsRun): $TestName"
}

# Test 1: Verify build-alpine.sh exists
Test-Start "build-alpine.sh exists"
if (Test-Path "build-alpine.sh") {
    Pass "build-alpine.sh file exists"
} else {
    Fail "build-alpine.sh file not found" "Expected file at ./build-alpine.sh"
    exit 1
}

# Read file content
$content = Get-Content "build-alpine.sh" -Raw

# Test 2: Verify script uses POSIX shell shebang
Test-Start "Uses POSIX shell shebang (#!/bin/sh)"
$firstLine = (Get-Content "build-alpine.sh" -First 1)
if ($firstLine -eq "#!/bin/sh") {
    Pass "Uses POSIX shell shebang: $firstLine"
} else {
    Fail "Does not use POSIX shell shebang" "Found: $firstLine, Expected: #!/bin/sh"
}

# Test 3: Verify script contains -Os flag for size optimization
Test-Start "Contains -Os flag for size optimization"
if ($content -match "-Os") {
    $count = ([regex]::Matches($content, "-Os")).Count
    Pass "Contains -Os flag ($count occurrences)"
} else {
    Fail "Does not contain -Os flag" "Expected '-Os' for size optimization"
}

# Test 4: Verify script contains -fPIC flag
Test-Start "Contains -fPIC flag for position-independent code"
if ($content -match "-fPIC") {
    $count = ([regex]::Matches($content, "-fPIC")).Count
    Pass "Contains -fPIC flag ($count occurrences)"
} else {
    Fail "Does not contain -fPIC flag" "Expected '-fPIC' for position-independent code"
}

# Test 5: Verify script does NOT contain GNU-specific compiler flags
Test-Start "Does NOT contain GNU-specific compiler flags"
$gnuCompilerFlags = @(
    "-D_FORTIFY_SOURCE=2",
    "-fstack-protector-strong",
    "-fstack-protector-all"
)

$foundGnuFlags = @()
foreach ($flag in $gnuCompilerFlags) {
    if ($content -match [regex]::Escape($flag)) {
        $foundGnuFlags += $flag
    }
}

if ($foundGnuFlags.Count -eq 0) {
    Pass "No GNU-specific compiler flags found"
} else {
    Fail "Found GNU-specific compiler flags" "Found: $($foundGnuFlags -join ', ')"
}

# Test 6: Verify script does NOT contain GNU-specific linker flags
Test-Start "Does NOT contain GNU-specific linker flags"
$gnuLinkerFlags = @(
    "-Wl,-z,relro",
    "-Wl,-z,now",
    "-pie"
)

$foundGnuLinker = @()
foreach ($flag in $gnuLinkerFlags) {
    if ($content -match [regex]::Escape($flag)) {
        $foundGnuLinker += $flag
    }
}

if ($foundGnuLinker.Count -eq 0) {
    Pass "No GNU-specific linker flags found"
} else {
    Fail "Found GNU-specific linker flags" "Found: $($foundGnuLinker -join ', ')"
}

# Test 7: Verify configure command uses --with-cc-opt with -Os -fPIC
Test-Start "Configure command uses --with-cc-opt with -Os -fPIC"
if ($content -match "--with-cc-opt=.*-Os.*-fPIC") {
    Pass "Configure uses --with-cc-opt with -Os -fPIC"
} else {
    Fail "Configure does not use --with-cc-opt with -Os -fPIC" "Expected '--with-cc-opt' with both -Os and -fPIC"
}

# Test 8: Verify artifact naming includes "alpine"
Test-Start "Build summary indicates Alpine OS type"
if ($content -match '"os_type".*:.*"alpine"') {
    Pass "Build summary includes os_type: alpine"
} else {
    Fail "Build summary does not indicate Alpine OS type" "Expected '`"os_type`": `"alpine`"' in build_summary.json"
}

# Test 9: Verify build summary includes musl libc indicator
Test-Start "Build summary indicates musl libc"
if ($content -match '"libc".*:.*"musl"') {
    Pass "Build summary includes libc: musl"
} else {
    Fail "Build summary does not indicate musl libc" "Expected '`"libc`": `"musl`"' in build_summary.json"
}

# Test 10: Verify LuaJIT is built with musl-compatible flags
Test-Start "LuaJIT build uses musl-compatible flags"
if ($content -match 'Building LuaJIT[\s\S]{0,300}CFLAGS="-Os -fPIC"') {
    Pass "LuaJIT build uses -Os -fPIC flags"
} else {
    Fail "LuaJIT build does not use musl-compatible flags" "Expected CFLAGS=`"-Os -fPIC`" in LuaJIT build section"
}

# Test 11: Verify script uses POSIX-compatible syntax (basic check)
Test-Start "Uses POSIX-compatible syntax (basic check)"
$bashisms = @(
    "function ",
    "\[\[",
    "==\s",
    "^\s*source\s",
    "\$\(\("
)

$foundBashisms = @()
foreach ($bashism in $bashisms) {
    if ($content -match $bashism) {
        $foundBashisms += $bashism
    }
}

if ($foundBashisms.Count -eq 0) {
    Pass "No obvious bash-isms found (POSIX compatible)"
} else {
    Fail "Found potential bash-isms" "Found: $($foundBashisms -join ', ')"
}

# Test 12: Verify script sources versions.env
Test-Start "Script sources versions.env"
if ($content -match '\. .*versions\.env' -or $content -match 'source.*versions\.env') {
    Pass "Script sources versions.env"
} else {
    Fail "Script does not source versions.env" "Expected '. versions.env' or 'source versions.env'"
}

# Test 13: Verify script validates required versions
Test-Start "Script validates required versions"
$requiredVars = @(
    "NGINX_VERSION",
    "OPENSSL_VERSION",
    "PCRE2_VERSION",
    "ZLIB_VERSION"
)

$missingValidation = @()
foreach ($var in $requiredVars) {
    if ($content -notmatch $var) {
        $missingValidation += $var
    }
}

if ($missingValidation.Count -eq 0) {
    Pass "All required version variables are referenced"
} else {
    Fail "Missing validation for version variables" "Missing: $($missingValidation -join ', ')"
}

# Test 14: Verify script uses --with-ld-opt (musl-compatible)
Test-Start "Configure command uses musl-compatible --with-ld-opt"
if ($content -match "--with-ld-opt=") {
    # Check it doesn't use GNU-specific flags
    $ldOptLine = ($content -split "`n" | Where-Object { $_ -match "--with-ld-opt=" }) -join " "
    if ($ldOptLine -notmatch "-Wl,-z,relro" -and $ldOptLine -notmatch "-Wl,-z,now" -and $ldOptLine -notmatch "-pie") {
        Pass "Uses --with-ld-opt without GNU-specific flags"
    } else {
        Fail "Uses --with-ld-opt with GNU-specific flags" "Should use musl-compatible linker options"
    }
} else {
    Fail "Does not use --with-ld-opt" "Expected '--with-ld-opt' in configure command"
}

# Test 15: Verify script generates expected_modules.txt
Test-Start "Script generates expected_modules.txt"
if ($content -match "expected_modules\.txt") {
    Pass "Script generates expected_modules.txt"
} else {
    Fail "Script does not generate expected_modules.txt" "Expected generation of expected_modules.txt for testing"
}

# Test 16: Verify script customizes Server header
Test-Start "Script customizes Server header to nginx-mainline-mk"
if ($content -match "nginx-mainline-mk") {
    Pass "Script customizes Server header to nginx-mainline-mk"
} else {
    Fail "Script does not customize Server header" "Expected 'nginx-mainline-mk' in Server header customization"
}

# Test 17: Verify script strips binary for size optimization
Test-Start "Script strips binary for size optimization"
if ($content -match "strip") {
    Pass "Script strips binary"
} else {
    Fail "Script does not strip binary" "Expected 'strip' command for size optimization"
}

# Test 18: Verify script includes checksum verification
Test-Start "Script includes checksum verification"
if ($content -match "sha256sum" -or $content -match "verify_checksum") {
    Pass "Script includes checksum verification"
} else {
    Fail "Script does not include checksum verification" "Expected sha256sum or verify_checksum function"
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
