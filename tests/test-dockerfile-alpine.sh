#!/bin/bash
# Unit tests for Dockerfile.alpine
# Tests Requirements: 2.1, 2.5

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

# Test 1: Verify Dockerfile.alpine exists
test_start "Dockerfile.alpine exists"
if [ -f "Dockerfile.alpine" ]; then
    pass "Dockerfile.alpine file exists"
else
    fail "Dockerfile.alpine file not found" "Expected file at ./Dockerfile.alpine"
    exit 1
fi

# Test 2: Verify base image is Alpine 3.19 or higher
# Requirement 2.1: THE Alpine构建器 SHALL 使用 Alpine Linux 3.19 或更高版本作为基础镜像
test_start "Base image is Alpine 3.19 or higher"
if grep -q "FROM alpine:3\.19" Dockerfile.alpine || \
   grep -q "FROM alpine:3\.[2-9][0-9]" Dockerfile.alpine || \
   grep -q "FROM alpine:[4-9]\." Dockerfile.alpine; then
    BASE_IMAGE=$(grep "FROM alpine:" Dockerfile.alpine | head -n 1)
    pass "Base image uses Alpine 3.19+: $BASE_IMAGE"
else
    BASE_IMAGE=$(grep "FROM alpine:" Dockerfile.alpine | head -n 1 || echo "Not found")
    fail "Base image version is not 3.19 or higher" "Found: $BASE_IMAGE"
fi

# Test 3: Verify all required apk packages are present
# Requirement 2.2: THE Alpine构建器 SHALL 使用 apk 包管理器安装构建依赖项
# Requirement 2.3: THE Alpine构建器 SHALL 为所有 Debian 构建依赖项安装 Alpine 等效包
test_start "All required apk packages are present"
REQUIRED_PACKAGES=(
    "build-base"
    "git"
    "curl"
    "wget"
    "ca-certificates"
    "autoconf"
    "automake"
    "libtool"
    "pkgconfig"
    "gd-dev"
    "libxslt-dev"
    "libmaxminddb-dev"
    "linux-pam-dev"
    "perl-dev"
    "readline-dev"
    "ncurses-dev"
    "pcre2-dev"
    "openssl-dev"
    "zlib-dev"
    "zstd-dev"
    "libxml2-dev"
    "luajit-dev"
)

MISSING_PACKAGES=()
for package in "${REQUIRED_PACKAGES[@]}"; do
    if ! grep -q "$package" Dockerfile.alpine; then
        MISSING_PACKAGES+=("$package")
    fi
done

if [ ${#MISSING_PACKAGES[@]} -eq 0 ]; then
    pass "All ${#REQUIRED_PACKAGES[@]} required packages are present"
else
    fail "Missing ${#MISSING_PACKAGES[@]} required packages" "Missing: ${MISSING_PACKAGES[*]}"
fi

# Test 4: Verify apk add command is used (not apt-get)
# Requirement 2.2: THE Alpine构建器 SHALL 使用 apk 包管理器安装构建依赖项
test_start "Uses apk package manager (not apt-get)"
if grep -q "apk add" Dockerfile.alpine; then
    pass "Uses apk package manager"
else
    fail "Does not use apk package manager" "Expected 'apk add' command"
fi

# Test 5: Verify no glibc-specific dependencies
# Requirement 2.5: THE Alpine构建器 SHALL NOT 包含任何 glibc 特定的依赖项
test_start "No glibc-specific dependencies present"
GLIBC_PACKAGES=(
    "libc6"
    "libc6-dev"
    "glibc"
    "apt-get"
    "dpkg"
    "libc-dev"
)

FOUND_GLIBC=()
for package in "${GLIBC_PACKAGES[@]}"; do
    if grep -q "$package" Dockerfile.alpine; then
        FOUND_GLIBC+=("$package")
    fi
done

if [ ${#FOUND_GLIBC[@]} -eq 0 ]; then
    pass "No glibc-specific dependencies found"
else
    fail "Found glibc-specific dependencies" "Found: ${FOUND_GLIBC[*]}"
fi

# Test 6: Verify LuaJIT Alpine package is used
# Requirement 2.4: WHEN 安装 LuaJIT 时 THE Alpine构建器 SHALL 使用 Alpine 仓库中的 luajit-dev 包
test_start "Uses Alpine's luajit-dev package"
if grep -q "luajit-dev" Dockerfile.alpine; then
    pass "Uses Alpine's luajit-dev package"
else
    fail "Does not use Alpine's luajit-dev package" "Expected 'luajit-dev' in package list"
fi

# Test 7: Verify build script is copied
test_start "Build script is copied"
if grep -q "COPY build-alpine.sh" Dockerfile.alpine; then
    pass "build-alpine.sh is copied"
else
    fail "build-alpine.sh is not copied" "Expected 'COPY build-alpine.sh' command"
fi

# Test 8: Verify versions.env is copied
test_start "versions.env is copied"
if grep -q "COPY versions.env" Dockerfile.alpine; then
    pass "versions.env is copied"
else
    fail "versions.env is not copied" "Expected 'COPY versions.env' command"
fi

# Test 9: Verify export stage exists
test_start "Export stage exists"
if grep -q "FROM scratch AS export" Dockerfile.alpine; then
    pass "Export stage is defined"
else
    fail "Export stage is not defined" "Expected 'FROM scratch AS export'"
fi

# Test 10: Verify shell is /bin/sh (not /bin/bash)
test_start "Uses POSIX shell (/bin/sh)"
if grep -q "/bin/sh" Dockerfile.alpine; then
    pass "Uses /bin/sh for POSIX compatibility"
else
    fail "Does not explicitly use /bin/sh" "Alpine uses /bin/sh by default, but explicit usage is recommended"
fi

# Test 11: Verify no Debian-specific package names in RUN commands
test_start "No Debian-specific package names in RUN commands"
DEBIAN_PACKAGES=(
    "libssl-dev"
    "libpcre2-dev"
    "zlib1g-dev"
    "libzstd-dev"
    "libgd-dev"
    "libxslt1-dev"
    "libpam0g-dev"
    "libperl-dev"
    "libreadline-dev"
    "libncurses5-dev"
    "build-essential"
)

# Extract only RUN commands (not comments)
RUN_COMMANDS=$(grep -v "^\s*#" Dockerfile.alpine | grep -A 50 "RUN" | tr '\n' ' ')

FOUND_DEBIAN=()
for package in "${DEBIAN_PACKAGES[@]}"; do
    if echo "$RUN_COMMANDS" | grep -q "$package"; then
        FOUND_DEBIAN+=("$package")
    fi
done

if [ ${#FOUND_DEBIAN[@]} -eq 0 ]; then
    pass "No Debian-specific package names found in RUN commands"
else
    fail "Found Debian-specific package names in RUN commands" "Found: ${FOUND_DEBIAN[*]}"
fi

# Test 12: Verify NGINX_VERSION ARG is defined
test_start "NGINX_VERSION ARG is defined"
if grep -q "ARG NGINX_VERSION" Dockerfile.alpine; then
    pass "NGINX_VERSION ARG is defined"
else
    fail "NGINX_VERSION ARG is not defined" "Expected 'ARG NGINX_VERSION'"
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
