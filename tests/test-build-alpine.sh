#!/bin/bash
# Unit tests for build-alpine.sh
# Tests Requirements: 5.1, 5.3, 6.4

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Helper functions
pass() {
    echo -e "${GREEN}✅ PASS${NC}: $1"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

fail() {
    echo -e "${RED}❌ FAIL${NC}: $1"
    echo -e "   ${YELLOW}Details:${NC} $2"
    TESTS_FAILED=$((TESTS_FAILED + 1))
}

test_start() {
    TESTS_RUN=$((TESTS_RUN + 1))
    echo ""
    echo "Test $TESTS_RUN: $1"
}

# Test 1: Verify build-alpine.sh exists
test_start "build-alpine.sh exists"
if [ -f "build-alpine.sh" ]; then
    pass "build-alpine.sh file exists"
else
    fail "build-alpine.sh file not found" "Expected file at ./build-alpine.sh"
    exit 1
fi

# Test 2: Verify script uses POSIX shell shebang
test_start "Uses POSIX shell shebang (#!/bin/sh)"
SHEBANG=$(head -n 1 build-alpine.sh)
if [ "$SHEBANG" = "#!/bin/sh" ]; then
    pass "Uses POSIX shell shebang: $SHEBANG"
else
    fail "Does not use POSIX shell shebang" "Found: $SHEBANG, Expected: #!/bin/sh"
fi

# Test 3: Verify script contains -Os flag for size optimization
# Requirement 5.1: THE Alpine构建器 SHALL 使用编译器标志 "-Os" 进行大小优化
test_start "Contains -Os flag for size optimization"
if grep -q "\-Os" build-alpine.sh; then
    # Count occurrences
    COUNT=$(grep -o "\-Os" build-alpine.sh | wc -l)
    pass "Contains -Os flag ($COUNT occurrences)"
else
    fail "Does not contain -Os flag" "Expected '-Os' for size optimization"
fi

# Test 4: Verify script contains -fPIC flag
# Requirement 5.2: THE Alpine构建器 SHALL 使用编译器标志 "-fPIC" 生成位置无关代码
test_start "Contains -fPIC flag for position-independent code"
if grep -q "\-fPIC" build-alpine.sh; then
    COUNT=$(grep -o "\-fPIC" build-alpine.sh | wc -l)
    pass "Contains -fPIC flag ($COUNT occurrences)"
else
    fail "Does not contain -fPIC flag" "Expected '-fPIC' for position-independent code"
fi

# Test 5: Verify script does NOT contain GNU-specific compiler flags
# Requirement 5.3: THE Alpine构建器 SHALL NOT 使用 GNU 特定的编译器标志，如 "-D_FORTIFY_SOURCE=2"
test_start "Does NOT contain GNU-specific compiler flags"
GNU_COMPILER_FLAGS=(
    "-D_FORTIFY_SOURCE=2"
    "-fstack-protector-strong"
    "-fstack-protector-all"
)

FOUND_GNU_FLAGS=()
for flag in "${GNU_COMPILER_FLAGS[@]}"; do
    if grep -q "$flag" build-alpine.sh; then
        FOUND_GNU_FLAGS+=("$flag")
    fi
done

if [ ${#FOUND_GNU_FLAGS[@]} -eq 0 ]; then
    pass "No GNU-specific compiler flags found"
else
    fail "Found GNU-specific compiler flags" "Found: ${FOUND_GNU_FLAGS[*]}"
fi

# Test 6: Verify script does NOT contain GNU-specific linker flags
# Requirement 5.4: THE Alpine构建器 SHALL NOT 使用 GNU 特定的链接器标志，如 "-Wl,-z,relro"
test_start "Does NOT contain GNU-specific linker flags"
GNU_LINKER_FLAGS=(
    "-Wl,-z,relro"
    "-Wl,-z,now"
    "-pie"
)

FOUND_GNU_LINKER=()
for flag in "${GNU_LINKER_FLAGS[@]}"; do
    if grep -q "$flag" build-alpine.sh; then
        FOUND_GNU_LINKER+=("$flag")
    fi
done

if [ ${#FOUND_GNU_LINKER[@]} -eq 0 ]; then
    pass "No GNU-specific linker flags found"
else
    fail "Found GNU-specific linker flags" "Found: ${FOUND_GNU_LINKER[*]}"
fi

# Test 7: Verify configure command uses --with-cc-opt with -Os -fPIC
# Requirement 5.5: WHEN 配置 Nginx 时 THE Alpine构建器 SHALL 使用 "--with-cc-opt=-Os -fPIC"
test_start "Configure command uses --with-cc-opt with -Os -fPIC"
if grep -q '\-\-with-cc-opt=.*-Os.*-fPIC' build-alpine.sh; then
    pass "Configure uses --with-cc-opt with -Os -fPIC"
else
    fail "Configure does not use --with-cc-opt with -Os -fPIC" "Expected '--with-cc-opt' with both -Os and -fPIC"
fi

# Test 8: Verify artifact naming includes "alpine"
# Requirement 6.4: THE 构建系统 SHALL 在 Alpine 构件名称中包含字符串 "alpine"
test_start "Build summary indicates Alpine OS type"
if grep -q '"os_type".*:.*"alpine"' build-alpine.sh; then
    pass "Build summary includes os_type: alpine"
else
    fail "Build summary does not indicate Alpine OS type" "Expected '\"os_type\": \"alpine\"' in build_summary.json"
fi

# Test 9: Verify build summary includes musl libc indicator
test_start "Build summary indicates musl libc"
if grep -q '"libc".*:.*"musl"' build-alpine.sh; then
    pass "Build summary includes libc: musl"
else
    fail "Build summary does not indicate musl libc" "Expected '\"libc\": \"musl\"' in build_summary.json"
fi

# Test 10: Verify LuaJIT is built with musl-compatible flags
# Requirement 5.1, 5.2: LuaJIT should use -Os -fPIC
test_start "LuaJIT build uses musl-compatible flags"
if grep -A 10 "Building LuaJIT" build-alpine.sh | grep -q 'CFLAGS="-Os -fPIC"'; then
    pass "LuaJIT build uses -Os -fPIC flags"
else
    fail "LuaJIT build does not use musl-compatible flags" "Expected CFLAGS=\"-Os -fPIC\" in LuaJIT build section"
fi

# Test 11: Verify script uses POSIX-compatible syntax (no bash-isms)
test_start "Uses POSIX-compatible syntax (basic check)"
BASHISMS=(
    "function "
    "\[\["
    "==\s"
    "^\s*source\s"
    "\$\(\("
)

FOUND_BASHISMS=()
for bashism in "${BASHISMS[@]}"; do
    if grep -E "$bashism" build-alpine.sh > /dev/null 2>&1; then
        FOUND_BASHISMS+=("$bashism")
    fi
done

if [ ${#FOUND_BASHISMS[@]} -eq 0 ]; then
    pass "No obvious bash-isms found (POSIX compatible)"
else
    fail "Found potential bash-isms" "Found: ${FOUND_BASHISMS[*]}"
fi

# Test 12: Verify script sources versions.env
test_start "Script sources versions.env"
if grep -q '\. .*versions\.env' build-alpine.sh || grep -q 'source.*versions\.env' build-alpine.sh; then
    pass "Script sources versions.env"
else
    fail "Script does not source versions.env" "Expected '. versions.env' or 'source versions.env'"
fi

# Test 13: Verify script validates required versions
test_start "Script validates required versions"
REQUIRED_VARS=(
    "NGINX_VERSION"
    "OPENSSL_VERSION"
    "PCRE2_VERSION"
    "ZLIB_VERSION"
)

MISSING_VALIDATION=()
for var in "${REQUIRED_VARS[@]}"; do
    if ! grep -q "$var" build-alpine.sh; then
        MISSING_VALIDATION+=("$var")
    fi
done

if [ ${#MISSING_VALIDATION[@]} -eq 0 ]; then
    pass "All required version variables are referenced"
else
    fail "Missing validation for version variables" "Missing: ${MISSING_VALIDATION[*]}"
fi

# Test 14: Verify script uses --with-ld-opt (musl-compatible)
test_start "Configure command uses musl-compatible --with-ld-opt"
if grep -q '\-\-with-ld-opt=' build-alpine.sh; then
    # Check it doesn't use GNU-specific flags
    if ! grep '\-\-with-ld-opt=' build-alpine.sh | grep -q '\-Wl,-z,relro\|\-Wl,-z,now\|\-pie'; then
        pass "Uses --with-ld-opt without GNU-specific flags"
    else
        fail "Uses --with-ld-opt with GNU-specific flags" "Should use musl-compatible linker options"
    fi
else
    fail "Does not use --with-ld-opt" "Expected '--with-ld-opt' in configure command"
fi

# Test 15: Verify script generates expected_modules.txt
test_start "Script generates expected_modules.txt"
if grep -q "expected_modules.txt" build-alpine.sh; then
    pass "Script generates expected_modules.txt"
else
    fail "Script does not generate expected_modules.txt" "Expected generation of expected_modules.txt for testing"
fi

# Test 16: Verify script customizes Server header
test_start "Script customizes Server header to nginx-mainline-mk"
if grep -q "nginx-mainline-mk" build-alpine.sh; then
    pass "Script customizes Server header to nginx-mainline-mk"
else
    fail "Script does not customize Server header" "Expected 'nginx-mainline-mk' in Server header customization"
fi

# Test 17: Verify script strips binary for size optimization
test_start "Script strips binary for size optimization"
if grep -q "strip" build-alpine.sh; then
    pass "Script strips binary"
else
    fail "Script does not strip binary" "Expected 'strip' command for size optimization"
fi

# Test 18: Verify script uses checksum verification
test_start "Script includes checksum verification"
if grep -q "sha256sum" build-alpine.sh || grep -q "verify_checksum" build-alpine.sh; then
    pass "Script includes checksum verification"
else
    fail "Script does not include checksum verification" "Expected sha256sum or verify_checksum function"
fi

# Print summary
echo ""
echo "=========================================="
echo "Test Summary"
echo "=========================================="
echo "Total tests run: $TESTS_RUN"
echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
if [ $TESTS_FAILED -gt 0 ]; then
    echo -e "${RED}Failed: $TESTS_FAILED${NC}"
else
    echo "Failed: $TESTS_FAILED"
fi
echo "=========================================="

# Exit with appropriate code
if [ $TESTS_FAILED -gt 0 ]; then
    exit 1
else
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
fi
