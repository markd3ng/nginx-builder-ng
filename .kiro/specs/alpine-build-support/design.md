# 设计文档：Alpine Linux 构建支持

## 概述

本设计文档描述了为 nginx-builder-ng 项目添加 Alpine Linux 构建支持的技术实现方案。该设计采用并行构建架构，允许 Debian 和 Alpine 构建独立运行，同时共享核心版本配置和构建逻辑。

设计目标：
- 修复现有 CI 流水线中的 versions.env 文件路径问题
- 创建独立的 Alpine 构建基础设施（Dockerfile.alpine 和 build-alpine.sh）
- 实现并行 CI/CD 流水线，同时构建 Debian 和 Alpine 变体
- 确保所有第三方模块与 musl libc 兼容
- 生成独立的 Alpine 构件，命名清晰且易于识别
- 支持 Nginx mainline 和 stable 版本的发布策略

## 架构

### 系统架构图

```mermaid
graph TB
    subgraph "源代码仓库"
        VE[versions.env]
        DF_DEB[Dockerfile]
        DF_ALP[Dockerfile.alpine]
        BS_DEB[build.sh]
        BS_ALP[build-alpine.sh]
    end
    
    subgraph "GitHub Actions CI"
        TRIGGER[触发器: push/schedule]
        
        subgraph "并行构建作业"
            JOB_DEB[Debian 构建作业]
            JOB_ALP[Alpine 构建作业]
        end
        
        subgraph "Debian 构建矩阵"
            DEB_AMD64[Debian AMD64]
            DEB_ARM64[Debian ARM64]
        end
        
        subgraph "Alpine 构建矩阵"
            ALP_AMD64[Alpine AMD64]
            ALP_ARM64[Alpine ARM64]
        end
        
        TEST[测试作业]
        RELEASE[发布作业]
    end
    
    subgraph "构建输出"
        ART_DEB_AMD[nginx-mainline-mk-{ver}-{build}-linux-amd64.tar.gz]
        ART_DEB_ARM[nginx-mainline-mk-{ver}-{build}-linux-arm64.tar.gz]
        ART_ALP_AMD[nginx-mainline-mk-{ver}-{build}-alpine-amd64.tar.gz]
        ART_ALP_ARM[nginx-mainline-mk-{ver}-{build}-alpine-arm64.tar.gz]
        CHECKSUMS[sha256sums-*.txt]
        MODULES[expected_modules.txt]
    end
    
    TRIGGER --> JOB_DEB
    TRIGGER --> JOB_ALP
    
    VE --> JOB_DEB
    VE --> JOB_ALP
    
    JOB_DEB --> DEB_AMD64
    JOB_DEB --> DEB_ARM64
    JOB_ALP --> ALP_AMD64
    JOB_ALP --> ALP_ARM64
    
    DF_DEB --> DEB_AMD64
    DF_DEB --> DEB_ARM64
    BS_DEB --> DEB_AMD64
    BS_DEB --> DEB_ARM64
    
    DF_ALP --> ALP_AMD64
    DF_ALP --> ALP_ARM64
    BS_ALP --> ALP_AMD64
    BS_ALP --> ALP_ARM64
    
    DEB_AMD64 --> ART_DEB_AMD
    DEB_ARM64 --> ART_DEB_ARM
    ALP_AMD64 --> ART_ALP_AMD
    ALP_ARM64 --> ART_ALP_ARM
    
    ART_DEB_AMD --> TEST
    ART_ALP_AMD --> TEST
    
    TEST --> RELEASE
    
    RELEASE --> CHECKSUMS
    RELEASE --> MODULES
```

### 构建流程

1. **触发阶段**：Git push 或定时任务触发 CI 流水线
2. **并行构建阶段**：
   - Debian 构建作业和 Alpine 构建作业并行启动
   - 每个作业使用矩阵策略构建 AMD64 和 ARM64 架构
3. **测试阶段**：对 AMD64 构件进行运行时验证
4. **发布阶段**：将所有构件打包并发布到 GitHub Releases

## 组件和接口

### 1. Dockerfile.alpine

Alpine 构建容器的定义文件。

**职责**：
- 使用 Alpine Linux 3.19+ 作为基础镜像
- 安装 musl libc 兼容的构建依赖
- 执行 build-alpine.sh 脚本
- 导出构建产物

**关键配置**：
```dockerfile
FROM alpine:3.19 AS builder

# 安装构建依赖（Alpine 包名）
RUN apk add --no-cache \
    build-base \
    git \
    curl \
    wget \
    ca-certificates \
    autoconf \
    automake \
    libtool \
    pkgconfig \
    gd-dev \
    libxslt-dev \
    libmaxminddb-dev \
    linux-pam-dev \
    perl-dev \
    readline-dev \
    ncurses-dev \
    pcre2-dev \
    openssl-dev \
    zlib-dev \
    zstd-dev \
    libxml2-dev \
    luajit-dev \
    dos2unix

# 复制构建脚本
COPY build-alpine.sh /build-alpine.sh
COPY versions.env /build/versions.env
COPY downloads /build/downloads/

# 执行构建
ARG NGINX_VERSION
ENV NGINX_VERSION=${NGINX_VERSION}
RUN /bin/sh /build-alpine.sh

# 导出阶段
FROM scratch AS export
COPY --from=builder /build/output /
```

**与 Debian Dockerfile 的差异**：
- 基础镜像：`alpine:3.19` vs `debian:trixie-slim`
- 包管理器：`apk add` vs `apt-get install`
- 包名称映射（见下表）
- Shell：`/bin/sh` vs `/bin/bash`

### 2. build-alpine.sh

Alpine 特定的构建脚本。

**职责**：
- 加载 versions.env 配置
- 下载 Nginx 核心和第三方模块源代码
- 使用 musl 兼容的编译标志编译 LuaJIT
- 配置和编译 Nginx
- 打包构建产物

**关键编译标志**：
```bash
# musl libc 优化标志
CFLAGS="-Os -fPIC -Wno-error"

# Nginx 配置标志
./configure \
    --with-cc-opt="-Os -fPIC -Wno-error" \
    --with-ld-opt="-Wl,--as-needed" \
    # ... 其他配置选项
```

**与 build.sh 的差异**：
- 移除 GNU 特定的编译标志（`-D_FORTIFY_SOURCE=2`, `-fstack-protector-strong`）
- 移除 GNU 特定的链接器标志（`-Wl,-z,relro`, `-Wl,-z,now`, `-pie`）
- 使用 `-Os` 替代 `-O2` 进行大小优化
- 简化的 POSIX shell 语法（避免 Bash 特性）

### 3. GitHub Actions 工作流

#### 主构建工作流（.github/workflows/build.yml）

**修复 versions.env 路径问题**：
```yaml
- name: Checkout
  uses: actions/checkout@v4

- name: Resolve Nginx Version
  id: nginx_version
  run: |
    # 确保在正确的目录中
    cd $GITHUB_WORKSPACE
    source versions.env
    echo "VERSION=$NGINX_VERSION" >> $GITHUB_ENV
    echo "version=$NGINX_VERSION" >> $GITHUB_OUTPUT
```

**并行构建策略**：
```yaml
jobs:
  build-debian:
    runs-on: ubuntu-latest
    strategy:
      fail-fast: false
      matrix:
        arch: [amd64, arm64]
    steps:
      # Debian 构建步骤
      
  build-alpine:
    runs-on: ubuntu-latest
    strategy:
      fail-fast: false
      matrix:
        arch: [amd64, arm64]
    steps:
      # Alpine 构建步骤
      
  test:
    needs: [build-debian, build-alpine]
    # 测试步骤
    
  release:
    needs: test
    if: github.ref == 'refs/heads/master'
    # 发布步骤
```

**构件命名逻辑**：
```yaml
- name: Rename Artifact (Debian)
  run: |
    mv ./output/nginx-custom.tar.gz \
       ./output/nginx-mainline-mk-${{ env.VERSION }}-${{ github.run_number }}-linux-${{ matrix.arch }}.tar.gz

- name: Rename Artifact (Alpine)
  run: |
    mv ./output/nginx-custom.tar.gz \
       ./output/nginx-mainline-mk-${{ env.VERSION }}-${{ github.run_number }}-alpine-${{ matrix.arch }}.tar.gz
```

#### 测试工作流（.github/workflows/test.yml 和 test-alpine.yml）

**Debian 测试**（现有）：
- 使用 Ubuntu 运行器
- 安装 glibc 运行时依赖
- 验证二进制文件运行

**Alpine 测试**（新增）：
- 使用 Alpine Docker 容器
- 安装 musl libc 运行时依赖
- 验证二进制文件运行

```yaml
jobs:
  test-alpine-binary:
    runs-on: ubuntu-latest
    container:
      image: alpine:3.19
    steps:
      - name: Install Runtime Dependencies
        run: |
          apk add --no-cache \
            libmaxminddb libxml2 libxslt gd \
            linux-pam zstd-libs pcre2 openssl \
            perl tzdata luajit
      
      - name: Download Artifact
        uses: actions/download-artifact@v4
        with:
          name: nginx-mainline-mk-${{ inputs.version }}-alpine-amd64
      
      - name: Extract and Test
        run: |
          tar -xzf nginx-mainline-mk-*-alpine-amd64.tar.gz -C /
          /usr/sbin/nginx -V
          /usr/sbin/nginx
          wget -O- http://localhost | grep "nginx-mainline-mk"
```

### 4. 包名称映射表

| Debian 包名 | Alpine 包名 | 用途 |
|------------|------------|------|
| build-essential | build-base | 基础编译工具链 |
| libssl-dev | openssl-dev | OpenSSL 开发文件 |
| libpcre2-dev | pcre2-dev | PCRE2 开发文件 |
| zlib1g-dev | zlib-dev | Zlib 开发文件 |
| libzstd-dev | zstd-dev | Zstd 开发文件 |
| libgd-dev | gd-dev | GD 图形库 |
| libxslt1-dev | libxslt-dev | XSLT 库 |
| libmaxminddb-dev | libmaxminddb-dev | GeoIP2 数据库 |
| libpam0g-dev | linux-pam-dev | PAM 认证 |
| libperl-dev | perl-dev | Perl 嵌入 |
| libreadline-dev | readline-dev | Readline 库 |
| libncurses5-dev | ncurses-dev | Ncurses 库 |
| libxml2-dev | libxml2-dev | XML 解析库 |
| - | luajit-dev | LuaJIT（Alpine 原生包）|

## 数据模型

### 版本配置（versions.env）

```bash
# Nginx 版本（mainline 或 stable）
NGINX_VERSION="1.29.4"
NGINX_SHA256="5a7d37eee505866fbab5810fa9f78247d6d5d9157a595c4e7a72043141ddab25"

# 依赖库版本
OPENSSL_VERSION="3.5.0"
OPENSSL_SHA256="344d0a79f1a9b08029b0744e2cc401a43f9c90acd1044d09a530b4885a8e9fc0"

PCRE2_VERSION="10.42"
PCRE2_SHA256="c33b418e3b936ee3153de2c61cc638e7e4fe3156022a5c77d0711bcbb9d64f1f"

ZLIB_VERSION="1.3.1"
ZLIB_SHA256="9a93b2b7dfdac77ceba5a558a580e74667dd6fede4585b91eefb60f03b72df23"
```

### 构建产物结构

```
output/
├── nginx-mainline-mk-{version}-{build}-linux-amd64.tar.gz
├── nginx-mainline-mk-{version}-{build}-linux-arm64.tar.gz
├── nginx-mainline-mk-{version}-{build}-alpine-amd64.tar.gz
├── nginx-mainline-mk-{version}-{build}-alpine-arm64.tar.gz
├── sha256sums-amd64.txt
├── sha256sums-arm64.txt
├── expected_modules.txt
└── build_summary.json
```

### 构建摘要（build_summary.json）

```json
{
  "nginx_version": "1.29.4",
  "openssl_version": "3.5.0",
  "pcre2_version": "10.42",
  "zlib_version": "1.3.1",
  "os_type": "alpine",
  "libc": "musl",
  "size_before_strip": 45678901,
  "size_after_strip": 12345678,
  "checksum_verified": true,
  "build_date": "2025-01-15T10:30:00Z"
}
```

### 发布标签格式

```
nginx-mainline-mk/{version}-{build_number}

示例：
- nginx-mainline-mk/1.29.4-40  (mainline 版本)
- nginx-mainline-mk/1.28.2-15  (stable 版本)
```

## 正确性属性

*属性是一种特征或行为，应该在系统的所有有效执行中保持为真——本质上是关于系统应该做什么的正式陈述。属性作为人类可读规范和机器可验证正确性保证之间的桥梁。*


### 属性 1：构件命名一致性

*对于任何* Nginx 版本、构建号、操作系统类型（debian/alpine）和架构（amd64/arm64），生成的构件文件名应该匹配模式 `nginx-mainline-mk-{version}-{build}-{os_suffix}-{arch}.tar.gz`，其中 os_suffix 对于 Debian 是 "linux"，对于 Alpine 是 "alpine"

**验证：需求 6.1, 6.2**

### 属性 2：模块完整性

*对于任何* 成功构建的 Nginx 二进制文件（Debian 或 Alpine），执行 `nginx -V` 的输出应该包含 expected_modules.txt 文件中列出的所有模块名称

**验证：需求 4.1, 4.2, 4.3, 4.4, 4.5, 4.6, 8.5**

### 属性 3：版本一致性

*对于任何* 给定的构建运行，所有四个构件（Debian amd64/arm64, Alpine amd64/arm64）的 build_summary.json 文件应该包含相同的 nginx_version、openssl_version、pcre2_version 和 zlib_version 值

**验证：需求 11.1, 11.2, 11.3, 11.4**

### 属性 4：Alpine 二进制可执行性

*对于任何* 在 Alpine Linux 3.19+ 容器中解压的 Alpine 构件，执行 `/usr/sbin/nginx -V` 应该成功返回（退出码 0）并输出版本信息

**验证：需求 8.2**

### 属性 5：Server 头验证

*对于任何* 成功启动的 Nginx 实例（Debian 或 Alpine），向 localhost 发送 HTTP 请求应该返回包含 "nginx-mainline-mk" 字符串的 Server 响应头

**验证：需求 8.4**

### 属性 6：发布完整性

*对于任何* 发布到 GitHub Releases 的版本，应该包含恰好 4 个 tar.gz 构件文件：一个 Debian amd64、一个 Debian arm64、一个 Alpine amd64 和一个 Alpine arm64

**验证：需求 13.6**

## 错误处理

### 构建时错误

1. **versions.env 文件缺失**
   - 检测：在 CI 工作流的早期步骤验证文件存在
   - 处理：立即失败并显示清晰的错误消息
   - 恢复：确保 checkout 步骤正确执行

2. **模块编译失败**
   - 检测：监控 make 命令的退出码
   - 处理：记录完整的编译错误输出
   - 恢复：检查模块与 musl libc 的兼容性，调整编译标志

3. **依赖包缺失**
   - 检测：apk add 或 apt-get install 失败
   - 处理：报告缺失的包名称
   - 恢复：更新 Dockerfile 中的包列表

4. **架构不匹配**
   - 检测：QEMU 模拟失败或二进制文件无法在目标架构上运行
   - 处理：记录架构信息和错误详情
   - 恢复：验证 Docker Buildx 配置和 QEMU 设置

### 运行时错误

1. **动态库缺失**
   - 检测：nginx 启动时报告 "error while loading shared libraries"
   - 处理：使用 ldd 命令列出缺失的依赖
   - 恢复：在 Dockerfile 或文档中添加运行时依赖

2. **权限错误**
   - 检测：nginx 无法创建 pid 文件或日志文件
   - 处理：检查文件系统权限
   - 恢复：在测试脚本中创建必要的目录

3. **端口冲突**
   - 检测：nginx 无法绑定到端口 80
   - 处理：检查端口是否已被占用
   - 恢复：在测试中使用非特权端口或停止冲突的服务

### CI/CD 错误

1. **并行构建冲突**
   - 检测：资源竞争或缓存冲突
   - 处理：使用独立的缓存键和工作目录
   - 恢复：确保每个作业有隔离的环境

2. **构件上传失败**
   - 检测：upload-artifact 步骤失败
   - 处理：重试上传或使用备用存储
   - 恢复：验证构件路径和权限

3. **发布创建失败**
   - 检测：GitHub API 返回错误
   - 处理：记录 API 响应详情
   - 恢复：检查权限和标签格式

## 测试策略

### 双重测试方法

本项目采用单元测试和属性测试相结合的方法：

- **单元测试**：验证特定示例、边缘情况和错误条件
- **属性测试**：通过随机化验证所有输入的通用属性
- 两者互补且都是全面覆盖所必需的

### 单元测试

单元测试专注于：
- 特定的配置示例（例如，验证 Dockerfile.alpine 使用 Alpine 3.19）
- 文件存在性检查（例如，versions.env 在正确位置）
- 脚本内容验证（例如，build-alpine.sh 包含 "apk add"）
- CI 工作流结构（例如，并行作业配置）

**示例单元测试**：
```bash
# 测试 1：验证 Dockerfile.alpine 使用正确的基础镜像
test_alpine_base_image() {
    grep -q "FROM alpine:3.19" Dockerfile.alpine
    assert_equals $? 0 "Dockerfile.alpine should use Alpine 3.19"
}

# 测试 2：验证 versions.env 文件存在
test_versions_env_exists() {
    assert_file_exists "versions.env"
}

# 测试 3：验证 Alpine 构建脚本使用 apk
test_alpine_uses_apk() {
    grep -q "apk add" build-alpine.sh
    assert_equals $? 0 "build-alpine.sh should use apk package manager"
}

# 测试 4：验证 CI 工作流定义了并行作业
test_ci_parallel_jobs() {
    yq eval '.jobs | has("build-debian") and has("build-alpine")' .github/workflows/build.yml
    assert_equals $? 0 "CI should define separate Debian and Alpine jobs"
}
```

### 属性测试

属性测试专注于：
- 通用的正确性属性（例如，所有构件都包含所有模块）
- 命名约定（例如，文件名匹配模式）
- 版本一致性（例如，所有变体使用相同版本）
- 运行时行为（例如，二进制文件可执行）

**属性测试配置**：
- 使用 Bash 脚本和循环实现属性测试
- 每个属性测试至少运行 10 次迭代（针对不同的构建）
- 每个测试必须引用其设计文档属性
- 标签格式：**Feature: alpine-build-support, Property {number}: {property_text}**

**示例属性测试**：
```bash
# Feature: alpine-build-support, Property 1: 构件命名一致性
test_artifact_naming_consistency() {
    local versions=("1.29.4" "1.28.2" "1.27.1")
    local builds=("40" "41" "42")
    local os_types=("linux" "alpine")
    local archs=("amd64" "arm64")
    
    for version in "${versions[@]}"; do
        for build in "${builds[@]}"; do
            for os_type in "${os_types[@]}"; do
                for arch in "${archs[@]}"; do
                    expected="nginx-mainline-mk-${version}-${build}-${os_type}-${arch}.tar.gz"
                    # 验证命名模式
                    assert_matches_pattern "$expected" "nginx-mainline-mk-.*-.*-.*-.*\.tar\.gz"
                done
            done
        done
    done
}

# Feature: alpine-build-support, Property 2: 模块完整性
test_module_completeness() {
    local artifacts=(
        "nginx-mainline-mk-1.29.4-40-linux-amd64.tar.gz"
        "nginx-mainline-mk-1.29.4-40-alpine-amd64.tar.gz"
    )
    
    for artifact in "${artifacts[@]}"; do
        # 解压构件
        tar -xzf "$artifact" -C /tmp/test
        
        # 获取模块列表
        /tmp/test/usr/sbin/nginx -V 2>&1 > /tmp/nginx_modules.txt
        
        # 验证所有预期模块存在
        while read -r module; do
            grep -q "$module" /tmp/nginx_modules.txt
            assert_equals $? 0 "Module $module should be present in $artifact"
        done < expected_modules.txt
        
        # 清理
        rm -rf /tmp/test
    done
}

# Feature: alpine-build-support, Property 3: 版本一致性
test_version_consistency() {
    local artifacts=(
        "output/build_summary_debian_amd64.json"
        "output/build_summary_debian_arm64.json"
        "output/build_summary_alpine_amd64.json"
        "output/build_summary_alpine_arm64.json"
    )
    
    # 读取第一个构件的版本
    local nginx_ver=$(jq -r '.nginx_version' "${artifacts[0]}")
    local openssl_ver=$(jq -r '.openssl_version' "${artifacts[0]}")
    local pcre2_ver=$(jq -r '.pcre2_version' "${artifacts[0]}")
    local zlib_ver=$(jq -r '.zlib_version' "${artifacts[0]}")
    
    # 验证所有其他构件使用相同版本
    for artifact in "${artifacts[@]:1}"; do
        assert_equals "$(jq -r '.nginx_version' "$artifact")" "$nginx_ver"
        assert_equals "$(jq -r '.openssl_version' "$artifact")" "$openssl_ver"
        assert_equals "$(jq -r '.pcre2_version' "$artifact")" "$pcre2_ver"
        assert_equals "$(jq -r '.zlib_version' "$artifact")" "$zlib_ver"
    done
}
```

### 集成测试

集成测试在 CI 环境中运行，验证：
1. 完整的构建流程（从源代码到构件）
2. 跨架构兼容性（AMD64 和 ARM64）
3. 运行时环境兼容性（Debian 和 Alpine）
4. 发布流程（构件上传和标签创建）

### 测试覆盖率目标

- 所有正确性属性必须有对应的属性测试
- 所有错误处理路径必须有单元测试
- CI 工作流的所有分支必须被测试覆盖
- 目标：90% 以上的代码覆盖率（对于脚本和配置文件）
