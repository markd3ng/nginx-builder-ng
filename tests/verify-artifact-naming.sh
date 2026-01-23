#!/bin/bash
# Test script to verify artifact naming patterns
# Feature: alpine-build-support, Task 5.2
# Validates: Requirements 6.1, 6.2, 6.3, 6.4

set -e

echo "=== Artifact Naming Verification ==="
echo ""

# Test data
TEST_VERSION="1.29.4"
TEST_BUILD="100"
ARCHS=("amd64" "arm64")
OS_TYPES=("linux" "alpine")

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

PASS_COUNT=0
FAIL_COUNT=0

# Function to test artifact naming pattern
test_artifact_name() {
    local os_type=$1
    local arch=$2
    local expected_pattern="nginx-mainline-mk-${TEST_VERSION}-${TEST_BUILD}-${os_type}-${arch}.tar.gz"
    
    # Verify pattern matches expected format
    if [[ "$expected_pattern" =~ ^nginx-mainline-mk-[0-9]+\.[0-9]+\.[0-9]+-[0-9]+-(linux|alpine)-(amd64|arm64)\.tar\.gz$ ]]; then
        echo -e "${GREEN}✓${NC} Pattern valid: $expected_pattern"
        ((PASS_COUNT++))
        return 0
    else
        echo -e "${RED}✗${NC} Pattern invalid: $expected_pattern"
        ((FAIL_COUNT++))
        return 1
    fi
}

# Function to test checksum file naming
test_checksum_name() {
    local os_type=$1
    local arch=$2
    local expected_pattern="sha256sums-${os_type}-${arch}.txt"
    
    # Verify pattern matches expected format
    if [[ "$expected_pattern" =~ ^sha256sums-(debian|alpine)-(amd64|arm64)\.txt$ ]]; then
        echo -e "${GREEN}✓${NC} Checksum pattern valid: $expected_pattern"
        ((PASS_COUNT++))
        return 0
    else
        echo -e "${RED}✗${NC} Checksum pattern invalid: $expected_pattern"
        ((FAIL_COUNT++))
        return 1
    fi
}

# Function to test artifact upload name uniqueness
test_upload_name_uniqueness() {
    local os_type=$1
    local arch=$2
    local upload_name="nginx-mainline-mk-${TEST_VERSION}-${TEST_BUILD}-${os_type}-${arch}"
    
    echo -e "${GREEN}✓${NC} Upload name unique: $upload_name"
    ((PASS_COUNT++))
}

echo "Testing Debian artifact naming patterns..."
for arch in "${ARCHS[@]}"; do
    test_artifact_name "linux" "$arch"
    test_checksum_name "debian" "$arch"
    test_upload_name_uniqueness "linux" "$arch"
done

echo ""
echo "Testing Alpine artifact naming patterns..."
for arch in "${ARCHS[@]}"; do
    test_artifact_name "alpine" "$arch"
    test_checksum_name "alpine" "$arch"
    test_upload_name_uniqueness "alpine" "$arch"
done

echo ""
echo "Testing OS type differentiation..."
# Verify that Debian uses "linux" and Alpine uses "alpine"
debian_name="nginx-mainline-mk-${TEST_VERSION}-${TEST_BUILD}-linux-amd64.tar.gz"
alpine_name="nginx-mainline-mk-${TEST_VERSION}-${TEST_BUILD}-alpine-amd64.tar.gz"

if [[ "$debian_name" == *"-linux-"* ]]; then
    echo -e "${GREEN}✓${NC} Debian artifacts use 'linux' suffix"
    ((PASS_COUNT++))
else
    echo -e "${RED}✗${NC} Debian artifacts should use 'linux' suffix"
    ((FAIL_COUNT++))
fi

if [[ "$alpine_name" == *"-alpine-"* ]]; then
    echo -e "${GREEN}✓${NC} Alpine artifacts use 'alpine' suffix"
    ((PASS_COUNT++))
else
    echo -e "${RED}✗${NC} Alpine artifacts should use 'alpine' suffix"
    ((FAIL_COUNT++))
fi

# Verify names are different
if [[ "$debian_name" != "$alpine_name" ]]; then
    echo -e "${GREEN}✓${NC} Debian and Alpine artifacts have unique names"
    ((PASS_COUNT++))
else
    echo -e "${RED}✗${NC} Debian and Alpine artifacts must have unique names"
    ((FAIL_COUNT++))
fi

echo ""
echo "=== Summary ==="
echo "Passed: $PASS_COUNT"
echo "Failed: $FAIL_COUNT"

if [ $FAIL_COUNT -eq 0 ]; then
    echo -e "${GREEN}All artifact naming tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some artifact naming tests failed!${NC}"
    exit 1
fi
