#!/bin/bash
# Unit tests for CI parallel build configuration
# Tests Requirements: 7.1, 7.2, 7.8
# Task: 5.4 编写单元测试验证 CI 配置

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

# Verify workflow file exists
WORKFLOW_FILE=".github/workflows/build.yml"
if [ ! -f "$WORKFLOW_FILE" ]; then
    echo -e "${RED}❌ ERROR${NC}: Workflow file not found: $WORKFLOW_FILE"
    exit 1
fi

echo "=========================================="
echo "CI Parallel Build Configuration Tests"
echo "=========================================="
echo "Testing file: $WORKFLOW_FILE"
echo ""

# Test 1: Verify build-debian job exists
# Requirement 7.1: THE CI流水线 SHALL 使用独立的 GitHub Actions 作业（job）分别构建 Debian 和 Alpine 变体
test_start "build-debian job is defined"
if grep -q "^  build-debian:" "$WORKFLOW_FILE"; then
    pass "build-debian job is defined in workflow"
else
    fail "build-debian job is not defined" "Expected 'build-debian:' job definition"
fi

# Test 2: Verify build-alpine job exists
# Requirement 7.1: THE CI流水线 SHALL 使用独立的 GitHub Actions 作业（job）分别构建 Debian 和 Alpine 变体
test_start "build-alpine job is defined"
if grep -q "^  build-alpine:" "$WORKFLOW_FILE"; then
    pass "build-alpine job is defined in workflow"
else
    fail "build-alpine job is not defined" "Expected 'build-alpine:' job definition"
fi

# Test 3: Verify build-debian has no needs dependency on build-alpine
# Requirement 7.2: THE CI流水线 SHALL 并行执行 Debian 和 Alpine 构建作业，而不是串行执行
test_start "build-debian has no needs dependency on build-alpine"
# Extract the build-debian job section and check for needs
DEBIAN_JOB=$(sed -n '/^  build-debian:/,/^  [a-z]/p' "$WORKFLOW_FILE")
if echo "$DEBIAN_JOB" | grep -q "needs:.*build-alpine"; then
    fail "build-debian has needs dependency on build-alpine" "Jobs should run in parallel, not serially"
else
    pass "build-debian has no needs dependency on build-alpine"
fi

# Test 4: Verify build-alpine has no needs dependency on build-debian
# Requirement 7.2: THE CI流水线 SHALL 并行执行 Debian 和 Alpine 构建作业，而不是串行执行
test_start "build-alpine has no needs dependency on build-debian"
# Extract the build-alpine job section and check for needs
ALPINE_JOB=$(sed -n '/^  build-alpine:/,/^  [a-z]/p' "$WORKFLOW_FILE")
if echo "$ALPINE_JOB" | grep -q "needs:.*build-debian"; then
    fail "build-alpine has needs dependency on build-debian" "Jobs should run in parallel, not serially"
else
    pass "build-alpine has no needs dependency on build-debian"
fi

# Test 5: Verify build-debian uses matrix strategy
# Requirement 7.8: THE CI流水线 SHALL 使用矩阵策略（matrix strategy）定义构建变体
test_start "build-debian uses matrix strategy"
if echo "$DEBIAN_JOB" | grep -q "strategy:"; then
    pass "build-debian uses matrix strategy"
else
    fail "build-debian does not use matrix strategy" "Expected 'strategy:' section in build-debian job"
fi

# Test 6: Verify build-alpine uses matrix strategy
# Requirement 7.8: THE CI流水线 SHALL 使用矩阵策略（matrix strategy）定义构建变体
test_start "build-alpine uses matrix strategy"
if echo "$ALPINE_JOB" | grep -q "strategy:"; then
    pass "build-alpine uses matrix strategy"
else
    fail "build-alpine does not use matrix strategy" "Expected 'strategy:' section in build-alpine job"
fi

# Test 7: Verify build-debian matrix includes amd64
# Requirement 7.3: WHEN CI流水线被触发时 THE Debian构建作业 SHALL 构建 AMD64 和 ARM64 两个架构
test_start "build-debian matrix includes amd64"
if echo "$DEBIAN_JOB" | grep -A 5 "matrix:" | grep -q "amd64"; then
    pass "build-debian matrix includes amd64"
else
    fail "build-debian matrix does not include amd64" "Expected 'amd64' in matrix.arch"
fi

# Test 8: Verify build-debian matrix includes arm64
# Requirement 7.3: WHEN CI流水线被触发时 THE Debian构建作业 SHALL 构建 AMD64 和 ARM64 两个架构
test_start "build-debian matrix includes arm64"
if echo "$DEBIAN_JOB" | grep -A 5 "matrix:" | grep -q "arm64"; then
    pass "build-debian matrix includes arm64"
else
    fail "build-debian matrix does not include arm64" "Expected 'arm64' in matrix.arch"
fi

# Test 9: Verify build-alpine matrix includes amd64
# Requirement 7.4: WHEN CI流水线被触发时 THE Alpine构建作业 SHALL 构建 AMD64 和 ARM64 两个架构
test_start "build-alpine matrix includes amd64"
if echo "$ALPINE_JOB" | grep -A 5 "matrix:" | grep -q "amd64"; then
    pass "build-alpine matrix includes amd64"
else
    fail "build-alpine matrix does not include amd64" "Expected 'amd64' in matrix.arch"
fi

# Test 10: Verify build-alpine matrix includes arm64
# Requirement 7.4: WHEN CI流水线被触发时 THE Alpine构建作业 SHALL 构建 AMD64 和 ARM64 两个架构
test_start "build-alpine matrix includes arm64"
if echo "$ALPINE_JOB" | grep -A 5 "matrix:" | grep -q "arm64"; then
    pass "build-alpine matrix includes arm64"
else
    fail "build-alpine matrix does not include arm64" "Expected 'arm64' in matrix.arch"
fi

# Test 11: Verify build-debian uses fail-fast: false
# Requirement 7.6: WHEN 任何构建变体失败时 THE CI流水线 SHALL 报告失败但不阻塞其他变体
test_start "build-debian uses fail-fast: false"
if echo "$DEBIAN_JOB" | grep -q "fail-fast: false"; then
    pass "build-debian uses fail-fast: false"
else
    fail "build-debian does not use fail-fast: false" "Expected 'fail-fast: false' to allow other builds to continue"
fi

# Test 12: Verify build-alpine uses fail-fast: false
# Requirement 7.6: WHEN 任何构建变体失败时 THE CI流水线 SHALL 报告失败但不阻塞其他变体
test_start "build-alpine uses fail-fast: false"
if echo "$ALPINE_JOB" | grep -q "fail-fast: false"; then
    pass "build-alpine uses fail-fast: false"
else
    fail "build-alpine does not use fail-fast: false" "Expected 'fail-fast: false' to allow other builds to continue"
fi

# Test 13: Verify test-debian job depends on both build-debian and build-alpine
# Requirement 7.7: THE CI流水线 SHALL 为 Alpine 和 Debian 构建生成独立的构建报告
test_start "test-debian job depends on both build-debian and build-alpine"
TEST_DEBIAN_JOB=$(sed -n '/^  test-debian:/,/^  [a-z]/p' "$WORKFLOW_FILE")
if echo "$TEST_DEBIAN_JOB" | grep -q "needs:.*\[build-debian, build-alpine\]"; then
    pass "test-debian job depends on both build-debian and build-alpine"
elif echo "$TEST_DEBIAN_JOB" | grep -q "needs:.*\[build-alpine, build-debian\]"; then
    pass "test-debian job depends on both build-alpine and build-debian"
else
    fail "test-debian job does not depend on both build jobs" "Expected 'needs: [build-debian, build-alpine]'"
fi

# Test 13.1: Verify test-alpine job depends on both build-debian and build-alpine
# Requirement 7.7: THE CI流水线 SHALL 为 Alpine 和 Debian 构建生成独立的构建报告
test_start "test-alpine job depends on both build-debian and build-alpine"
TEST_ALPINE_JOB=$(sed -n '/^  test-alpine:/,/^  [a-z]/p' "$WORKFLOW_FILE")
if echo "$TEST_ALPINE_JOB" | grep -q "needs:.*\[build-debian, build-alpine\]"; then
    pass "test-alpine job depends on both build-debian and build-alpine"
elif echo "$TEST_ALPINE_JOB" | grep -q "needs:.*\[build-alpine, build-debian\]"; then
    pass "test-alpine job depends on both build-alpine and build-debian"
else
    fail "test-alpine job does not depend on both build jobs" "Expected 'needs: [build-debian, build-alpine]'"
fi

# Test 13.2: Verify test-debian calls test.yml workflow
test_start "test-debian calls test.yml workflow"
if echo "$TEST_DEBIAN_JOB" | grep -q "uses:.*test.yml"; then
    pass "test-debian calls test.yml workflow"
else
    fail "test-debian does not call test.yml workflow" "Expected 'uses: ./.github/workflows/test.yml'"
fi

# Test 13.3: Verify test-alpine calls test-alpine.yml workflow
test_start "test-alpine calls test-alpine.yml workflow"
if echo "$TEST_ALPINE_JOB" | grep -q "uses:.*test-alpine.yml"; then
    pass "test-alpine calls test-alpine.yml workflow"
else
    fail "test-alpine does not call test-alpine.yml workflow" "Expected 'uses: ./.github/workflows/test-alpine.yml'"
fi

# Test 13.4: Verify release job depends on both test-debian and test-alpine
test_start "release job depends on both test-debian and test-alpine"
RELEASE_JOB=$(sed -n '/^  release:/,/^  [a-z]/p' "$WORKFLOW_FILE")
if echo "$RELEASE_JOB" | grep -q "needs:.*\[test-debian, test-alpine\]"; then
    pass "release job depends on both test-debian and test-alpine"
elif echo "$RELEASE_JOB" | grep -q "needs:.*\[test-alpine, test-debian\]"; then
    pass "release job depends on both test-alpine and test-debian"
else
    fail "release job does not depend on both test jobs" "Expected 'needs: [test-debian, test-alpine]'"
fi

# Test 14: Verify build-alpine uses Dockerfile.alpine
test_start "build-alpine uses Dockerfile.alpine"
if echo "$ALPINE_JOB" | grep -q "Dockerfile.alpine"; then
    pass "build-alpine uses Dockerfile.alpine"
else
    fail "build-alpine does not use Dockerfile.alpine" "Expected '--file Dockerfile.alpine' in build command"
fi

# Test 15: Verify build-debian does NOT use Dockerfile.alpine
test_start "build-debian does NOT use Dockerfile.alpine"
if echo "$DEBIAN_JOB" | grep -q "Dockerfile.alpine"; then
    fail "build-debian incorrectly uses Dockerfile.alpine" "Debian build should use default Dockerfile"
else
    pass "build-debian does not use Dockerfile.alpine (uses default Dockerfile)"
fi

# Test 16: Verify both jobs use matrix.arch variable
test_start "Both jobs use matrix.arch variable"
DEBIAN_USES_ARCH=$(echo "$DEBIAN_JOB" | grep -c '\${{ matrix.arch }}' || true)
ALPINE_USES_ARCH=$(echo "$ALPINE_JOB" | grep -c '\${{ matrix.arch }}' || true)

if [ "$DEBIAN_USES_ARCH" -gt 0 ] && [ "$ALPINE_USES_ARCH" -gt 0 ]; then
    pass "Both jobs use matrix.arch variable (Debian: $DEBIAN_USES_ARCH times, Alpine: $ALPINE_USES_ARCH times)"
else
    fail "Jobs do not properly use matrix.arch variable" "Debian: $DEBIAN_USES_ARCH, Alpine: $ALPINE_USES_ARCH"
fi

# Test 17: Verify both jobs set up QEMU for cross-platform builds
# Requirement 3.5: WHEN 在 AMD64 主机上为 ARM64 编译时 THE Alpine构建器 SHALL 使用 QEMU 模拟
test_start "Both jobs set up QEMU for cross-platform builds"
DEBIAN_HAS_QEMU=$(echo "$DEBIAN_JOB" | grep -c "setup-qemu-action" || true)
ALPINE_HAS_QEMU=$(echo "$ALPINE_JOB" | grep -c "setup-qemu-action" || true)

if [ "$DEBIAN_HAS_QEMU" -gt 0 ] && [ "$ALPINE_HAS_QEMU" -gt 0 ]; then
    pass "Both jobs set up QEMU for cross-platform builds"
else
    fail "Jobs do not set up QEMU" "Debian: $DEBIAN_HAS_QEMU, Alpine: $ALPINE_HAS_QEMU"
fi

# Test 18: Verify both jobs set up Docker Buildx
# Requirement 3.4: THE Alpine构建器 SHALL 使用 Docker Buildx 进行跨平台编译
test_start "Both jobs set up Docker Buildx"
DEBIAN_HAS_BUILDX=$(echo "$DEBIAN_JOB" | grep -c "setup-buildx-action" || true)
ALPINE_HAS_BUILDX=$(echo "$ALPINE_JOB" | grep -c "setup-buildx-action" || true)

if [ "$DEBIAN_HAS_BUILDX" -gt 0 ] && [ "$ALPINE_HAS_BUILDX" -gt 0 ]; then
    pass "Both jobs set up Docker Buildx"
else
    fail "Jobs do not set up Docker Buildx" "Debian: $DEBIAN_HAS_BUILDX, Alpine: $ALPINE_HAS_BUILDX"
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
