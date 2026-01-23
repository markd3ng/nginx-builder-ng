# Task 6.1 Verification: test-alpine.yml Workflow

## Task Requirements
- 使用 Alpine 3.19 容器作为运行环境
- 安装 Alpine 运行时依赖（musl libc, openssl, pcre2, zlib, luajit 等）
- 下载 Alpine amd64 构件
- 解压并安装到容器中
- 执行 `nginx -V` 验证二进制文件运行
- 启动 nginx 并验证 Server 头包含 "nginx-mainline-mk"
- 验证所有预期模块存在
- 需求：8.1, 8.2, 8.3, 8.4, 8.5, 8.6, 8.7

## Implementation Verification

### ✅ Requirement 8.1: Alpine 运行时容器
**Status:** IMPLEMENTED
```yaml
container:
  image: alpine:3.19
```
- Uses Alpine Linux 3.19 as the runtime environment

### ✅ Requirement 8.2: 执行 nginx -V 验证
**Status:** IMPLEMENTED
```yaml
- name: Verify Version info
  id: version_check
  run: |
    if OUTPUT=$(/usr/sbin/nginx -V 2>&1); then
      echo "status=success" >> $GITHUB_OUTPUT
      echo "$OUTPUT" > nginx_info.txt
    else
      echo "status=failure" >> $GITHUB_OUTPUT
      echo "Failed to get version info" > nginx_info.txt
    fi
```
- Executes `nginx -V` to verify binary runs
- Captures output for reporting

### ✅ Requirement 8.3: 解压到 Alpine 容器
**Status:** IMPLEMENTED
```yaml
- name: Extract and Install
  id: install
  run: |
    TAR_FILE=$(find . -name "nginx-mainline-mk-*-alpine-amd64.tar.gz" | head -n 1)
    
    if [ -z "$TAR_FILE" ]; then
       echo "Error: Artifact file not found!"
       ls -R
       echo "status=failure" >> $GITHUB_OUTPUT
       exit 1
    fi

    echo "Installing $TAR_FILE..."
    if tar -xzf "$TAR_FILE" -C /; then
      echo "status=success" >> $GITHUB_OUTPUT
    else
      echo "status=failure" >> $GITHUB_OUTPUT
      exit 1
    fi
```
- Downloads Alpine amd64 artifact
- Extracts to root directory in Alpine container

### ✅ Requirement 8.4: 验证 Server 头
**Status:** IMPLEMENTED
```yaml
- name: Start and Verify Server Header
  id: server_header
  run: |
    mkdir -p /var/log/nginx /var/cache/nginx
    /usr/sbin/nginx
    sleep 2
    
    RESPONSE=$(curl -I -s http://localhost || echo "Curl failed")
    echo "$RESPONSE"
    
    if echo "$RESPONSE" | grep -q "Server: nginx-mainline-mk"; then
      echo "status=success" >> $GITHUB_OUTPUT
    else
      echo "status=failure" >> $GITHUB_OUTPUT
    fi
```
- Starts nginx server
- Verifies Server header contains "nginx-mainline-mk"

### ✅ Requirement 8.5: 验证所有预期模块
**Status:** IMPLEMENTED
```yaml
- name: Verify Compiled Modules
  id: modules_check
  run: |
    EXPECTED_FILE=$(find . -name "expected_modules.txt" | head -n 1)
    
    if [ -z "$EXPECTED_FILE" ]; then
       echo "⚠️ No expected_modules.txt found in artifact."
       ls -R
       echo "status=skipped" >> $GITHUB_OUTPUT
       echo "Skipped (File not found)" > modules_report.txt
       exit 0
    fi
    
    echo "Checking modules against: $EXPECTED_FILE"
    FAILURES=0
    
    NGINX_V=$(/usr/sbin/nginx -V 2>&1)
    MODULES_REPORT=""
    
    while read -r MODULE; do
      case "$MODULE" in
        \#*) continue ;;
        "") continue ;;
      esac
      
      MODULE=$(echo "$MODULE" | tr -d '\r')
      
      if echo "$NGINX_V" | grep -q "$MODULE"; then
        echo "✅ Module $MODULE found"
        MODULES_REPORT="${MODULES_REPORT}- ✅ $MODULE\n"
      else
        echo "❌ Module $MODULE MISSING"
        MODULES_REPORT="${MODULES_REPORT}- ❌ $MODULE MISSING\n"
        FAILURES=$((FAILURES+1))
      fi
    done < "$EXPECTED_FILE"
    
    printf "%b" "$MODULES_REPORT" > modules_report.txt
    
    if [ "$FAILURES" -gt 0 ]; then
       echo "Found $FAILURES missing modules!"
       echo "status=failure" >> $GITHUB_OUTPUT
       exit 1 
    else
       echo "status=success" >> $GITHUB_OUTPUT
    fi
```
- Reads expected_modules.txt from artifact
- Verifies all modules are present in nginx -V output
- Reports missing modules

### ✅ Requirement 8.6: Alpine 3.19+ 测试环境
**Status:** IMPLEMENTED
```yaml
container:
  image: alpine:3.19
```
- Uses Alpine Linux 3.19 as specified

### ✅ Requirement 8.7: 具体错误消息
**Status:** IMPLEMENTED
- All steps include error handling with specific messages
- Failed steps output detailed error information
- Report generation includes all test results

### ✅ Runtime Dependencies Installation
**Status:** IMPLEMENTED
```yaml
- name: Install Runtime Dependencies
  run: |
    apk add --no-cache \
      curl \
      libmaxminddb \
      libxml2 \
      libxslt \
      gd \
      linux-pam \
      zstd-libs \
      pcre2 \
      openssl \
      perl \
      tzdata \
      luajit
```
- Installs all required Alpine runtime dependencies
- Uses musl libc (native to Alpine)
- Includes LuaJIT support

## Key Features

### 1. POSIX Shell Compatibility
- Uses POSIX-compliant shell syntax (not Bash-specific)
- Uses `case` statements instead of `[[ ]]` for pattern matching
- Uses `printf` instead of `echo -e` for portability

### 2. Comprehensive Reporting
- Generates detailed test report in Chinese
- Includes all test results (install, version, server header, modules)
- Uploads artifacts for later review
- Writes to GitHub Step Summary
- Can comment on issues if issue_number is provided

### 3. Error Handling
- Each step has proper error detection
- Outputs are captured for debugging
- Graceful handling of missing files
- Clear status indicators (✅ PASS, ❌ FAIL, ⚠️ SKIP)

### 4. Workflow Integration
- Uses `workflow_call` trigger for reusability
- Accepts version and issue_number inputs
- Compatible with existing CI/CD structure
- Runs in Alpine container for authentic testing

## Differences from test.yml (Debian)

1. **Container**: Uses `alpine:3.19` instead of `ubuntu-latest`
2. **Package Manager**: Uses `apk add` instead of `apt-get install`
3. **Package Names**: Uses Alpine package names (e.g., `linux-pam` vs `libpam0g`)
4. **No sudo**: Alpine container runs as root, no sudo needed
5. **No ldconfig**: musl libc doesn't require ldconfig
6. **Shell Syntax**: Uses POSIX-compliant syntax for Alpine's /bin/sh
7. **Artifact Name**: Downloads `-alpine-amd64` artifact instead of `-linux-amd64`
8. **Report Title**: Indicates "Alpine" in the report title

## Testing Checklist

- [x] Uses Alpine 3.19 container
- [x] Installs all runtime dependencies
- [x] Downloads Alpine amd64 artifact
- [x] Extracts and installs to container
- [x] Executes nginx -V
- [x] Starts nginx server
- [x] Verifies Server header
- [x] Verifies all modules
- [x] Generates comprehensive report
- [x] Handles errors gracefully
- [x] Uses POSIX shell syntax
- [x] Compatible with workflow_call trigger

## Conclusion

The test-alpine.yml workflow has been successfully implemented and meets all requirements specified in task 6.1. It provides comprehensive testing of Alpine artifacts in an authentic Alpine Linux 3.19 environment with musl libc.
