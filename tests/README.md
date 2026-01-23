# Tests for Alpine Build Support

This directory contains unit tests for the Alpine Linux build support implementation.

## Test Files

### test-dockerfile-alpine.sh / test-dockerfile-alpine.ps1
Unit tests for validating the Dockerfile.alpine configuration.

**Tests Requirements:** 2.1, 2.5

**What it tests:**
1. Dockerfile.alpine file exists
2. Base image is Alpine 3.19 or higher (Requirement 2.1)
3. All required apk packages are present (Requirements 2.2, 2.3)
4. Uses apk package manager (Requirement 2.2)
5. No glibc-specific dependencies (Requirement 2.5)
6. Uses Alpine's luajit-dev package (Requirement 2.4)
7. Build script is copied
8. versions.env is copied
9. Export stage exists
10. Uses POSIX shell (/bin/sh)
11. No Debian-specific package names in RUN commands
12. NGINX_VERSION ARG is defined

### test-build-alpine.sh / test-build-alpine.ps1
Unit tests for validating the build-alpine.sh script.

**Tests Requirements:** 5.1, 5.3, 6.4

**What it tests:**
1. build-alpine.sh file exists
2. Uses POSIX shell shebang (#!/bin/sh)
3. Contains -Os flag for size optimization (Requirement 5.1)
4. Contains -fPIC flag for position-independent code (Requirement 5.2)
5. Does NOT contain GNU-specific compiler flags (Requirement 5.3)
6. Does NOT contain GNU-specific linker flags (Requirement 5.4)
7. Configure command uses --with-cc-opt with -Os -fPIC (Requirement 5.5)
8. Build summary indicates Alpine OS type (Requirement 6.4)
9. Build summary indicates musl libc
10. LuaJIT build uses musl-compatible flags (Requirements 5.1, 5.2)
11. Uses POSIX-compatible syntax (no bash-isms)
12. Script sources versions.env
13. Script validates required versions
14. Configure command uses musl-compatible --with-ld-opt
15. Script generates expected_modules.txt
16. Script customizes Server header to nginx-mainline-mk
17. Script strips binary for size optimization
18. Script includes checksum verification

## Running the Tests

### On Linux/macOS:
```bash
# Test Dockerfile.alpine
bash tests/test-dockerfile-alpine.sh

# Test build-alpine.sh
bash tests/test-build-alpine.sh
```

### On Windows (PowerShell):
```powershell
# Test Dockerfile.alpine
powershell -ExecutionPolicy Bypass -File tests/test-dockerfile-alpine.ps1

# Test build-alpine.sh
powershell -ExecutionPolicy Bypass -File tests/test-build-alpine.ps1
```

### On Windows (Git Bash):
```bash
# Test Dockerfile.alpine
bash tests/test-dockerfile-alpine.sh

# Test build-alpine.sh
bash tests/test-build-alpine.sh
```

## Test Output

The tests will output:
- ✅ PASS for successful tests
- ❌ FAIL for failed tests with details
- A summary showing total tests run, passed, and failed

Example output:
```
Test 1: Dockerfile.alpine exists
✅ PASS: Dockerfile.alpine file exists

Test 2: Base image is Alpine 3.19 or higher
✅ PASS: Base image uses Alpine 3.19+: FROM alpine:3.19 AS builder

...

==========================================
Test Summary
==========================================
Total tests run: 12
Passed: 12
Failed: 0
==========================================
All tests passed!
```

## Exit Codes

- `0`: All tests passed
- `1`: One or more tests failed

## Adding New Tests

When adding new tests:
1. Update both `.sh` and `.ps1` versions to maintain cross-platform compatibility
2. Reference the specific requirement(s) being tested in comments
3. Use descriptive test names
4. Provide clear failure messages with details
5. Update this README with the new test description
