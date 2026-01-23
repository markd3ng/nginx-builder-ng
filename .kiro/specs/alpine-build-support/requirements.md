# 需求文档：Alpine Linux 构建支持

## 简介

本规范定义了为 nginx-builder-ng 项目添加 Alpine Linux（musl libc）构建支持的需求。该项目目前在 AMD64 和 ARM64 架构上为 Debian/glibc 环境构建带有大量第三方模块的 Nginx。此增强功能将添加并行的 Alpine Linux 构建基础设施，使用原生 Alpine 编译和动态链接，生成独立的 Alpine 特定构件，同时保持所有现有的 Debian 构建功能。

## 术语表

- **构建系统（Build_System）**: nginx-builder-ng 基于 Docker 的编译基础设施
- **Alpine构建器（Alpine_Builder）**: 新的 Alpine Linux 特定构建容器和脚本
- **Debian构建器（Debian_Builder）**: 现有的基于 Debian 的构建容器和脚本
- **构件（Artifact）**: 包含编译后的 Nginx 二进制文件和依赖项的压缩包
- **musl_libc**: Alpine Linux 使用的轻量级 C 标准库
- **glibc**: Debian 和大多数 Linux 发行版使用的 GNU C 库
- **多架构构建（Multi_Arch_Build）**: 支持 AMD64 和 ARM64 架构的编译过程
- **模块（Module）**: 提供额外功能的第三方 Nginx 扩展
- **CI流水线（CI_Pipeline）**: 自动化构建和发布的 GitHub Actions 工作流
- **运行时容器（Runtime_Container）**: 将部署编译后二进制文件的目标 Alpine 容器

## 需求

### 需求 0：修复现有构建问题（最高优先级）

**用户故事：** 作为构建工程师，我希望修复当前 CI 流水线中 versions.env 文件找不到的问题，以便构建可以正常运行。

#### 验收标准

1. WHEN CI流水线执行 "source versions.env" 命令时 THEN 构建系统 SHALL 成功找到并加载 versions.env 文件
2. THE 构建系统 SHALL 确保 versions.env 文件在执行构建脚本之前被正确签出到工作目录
3. WHEN 构建失败时 THE 构建系统 SHALL 提供清晰的错误消息指示缺失的文件
4. THE 构建系统 SHALL 在所有构建步骤中使用正确的工作目录路径
5. THE 构建系统 SHALL 验证所有必需的文件（versions.env、build.sh、Dockerfile）在构建开始前存在

### 需求 1：并行构建基础设施

**用户故事：** 作为构建工程师，我希望在现有 Debian 构建的基础上创建 Alpine 构建基础设施，以便两种构建变体可以共存而不互相干扰。

#### 验收标准

1. WHEN 使用 Alpine 配置调用构建系统 THEN Alpine构建器 SHALL 使用 Alpine Linux 基础镜像编译 Nginx
2. WHEN 使用 Debian 配置调用构建系统 THEN Debian构建器 SHALL 继续正常运行不受影响
3. THE 构建系统 SHALL 为 Alpine 和 Debian 构建维护独立的 Dockerfile
4. THE 构建系统 SHALL 为 Alpine 和 Debian 构建维护独立的构建脚本
5. WHEN 执行两种构建类型时 THEN 构建系统 SHALL 生成具有不同命名约定的独立构件

### 需求 2：Alpine 基础镜像和依赖项

**用户故事：** 作为构建工程师，我希望使用 Alpine 3.19+ 和 musl libc，以便编译的二进制文件与 Alpine 运行时环境兼容。

#### 验收标准

1. THE Alpine构建器 SHALL 使用 Alpine Linux 3.19 或更高版本作为基础镜像
2. THE Alpine构建器 SHALL 使用 apk 包管理器安装构建依赖项
3. THE Alpine构建器 SHALL 为所有 Debian 构建依赖项安装 Alpine 等效包
4. WHEN 安装 LuaJIT 时 THE Alpine构建器 SHALL 使用 Alpine 仓库中的 luajit-dev 包
5. THE Alpine构建器 SHALL NOT 包含任何 glibc 特定的依赖项

### 需求 3：多架构支持

**用户故事：** 作为部署工程师，我希望为 AMD64 和 ARM64 架构构建 Alpine 版本，以便可以在各种硬件平台上部署。

#### 验收标准

1. THE Alpine构建器 SHALL 为 linux/amd64 平台编译 Nginx
2. THE Alpine构建器 SHALL 为 linux/arm64 平台编译 Nginx
3. WHEN 为每个架构构建时 THE Alpine构建器 SHALL 生成特定于架构的构件
4. THE Alpine构建器 SHALL 使用 Docker Buildx 进行跨平台编译
5. WHEN 在 AMD64 主机上为 ARM64 编译时 THE Alpine构建器 SHALL 使用 QEMU 模拟

### 需求 4：模块兼容性

**用户故事：** 作为功能维护者，我希望所有现有的 Nginx 模块都能使用 musl libc 编译，以便 Alpine 构建与 Debian 构建具有功能对等性。

#### 验收标准

1. THE Alpine构建器 SHALL 使用 ngx_brotli 模块编译 Nginx
2. THE Alpine构建器 SHALL 使用 zstd-nginx-module 编译 Nginx
3. THE Alpine构建器 SHALL 使用 lua-nginx-module 和 LuaJIT 支持编译 Nginx
4. THE Alpine构建器 SHALL 使用 ngx_http_geoip2_module 编译 Nginx
5. THE Alpine构建器 SHALL 使用 nginx-rtmp-module 编译 Nginx
6. THE Alpine构建器 SHALL 使用现有 Debian 构建配置中列出的所有模块编译 Nginx
7. WHEN 模块无法使用 musl 编译时 THE Alpine构建器 SHALL 报告具体的编译错误
8. THE Alpine构建器 SHALL 使用 musl 兼容的标志编译 LuaJIT

### 需求 5：编译标志和优化

**用户故事：** 作为性能工程师，我希望使用 musl 兼容的编译标志，以便二进制文件针对 Alpine 环境进行优化。

#### 验收标准

1. THE Alpine构建器 SHALL 使用编译器标志 "-Os" 进行大小优化
2. THE Alpine构建器 SHALL 使用编译器标志 "-fPIC" 生成位置无关代码
3. THE Alpine构建器 SHALL NOT 使用 GNU 特定的编译器标志，如 "-D_FORTIFY_SOURCE=2"
4. THE Alpine构建器 SHALL NOT 使用 GNU 特定的链接器标志，如 "-Wl,-z,relro"
5. WHEN 配置 Nginx 时 THE Alpine构建器 SHALL 使用 "--with-cc-opt=-Os -fPIC"
6. THE Alpine构建器 SHALL 移除任何与 musl libc 不兼容的加固标志

### 需求 6：构件命名和打包

**用户故事：** 作为发布管理员，我希望 Alpine 构建有独特的构件名称，以便用户可以轻松识别和下载正确的变体。

#### 验收标准

1. WHEN 打包 Alpine AMD64 构建时 THE 构建系统 SHALL 将构件命名为 "nginx-mainline-mk-{version}-{build}-alpine-amd64.tar.gz"
2. WHEN 打包 Alpine ARM64 构建时 THE 构建系统 SHALL 将构件命名为 "nginx-mainline-mk-{version}-{build}-alpine-arm64.tar.gz"
3. WHEN 打包 Debian AMD64 构建时 THE 构建系统 SHALL 继续将构件命名为 "nginx-mainline-mk-{version}-{build}-linux-amd64.tar.gz"
4. THE 构建系统 SHALL 在 Alpine 构件名称中包含字符串 "alpine"
5. THE 构建系统 SHALL 为 Alpine 构件生成独立的校验和文件

### 需求 7：CI/CD 集成

**用户故事：** 作为 DevOps 工程师，我希望 GitHub Actions 并行构建 Debian 和 Alpine 两种变体，以便加快构建速度并且发布包含所有支持的平台。

#### 验收标准

1. THE CI流水线 SHALL 使用独立的 GitHub Actions 作业（job）分别构建 Debian 和 Alpine 变体
2. THE CI流水线 SHALL 并行执行 Debian 和 Alpine 构建作业，而不是串行执行
3. WHEN CI流水线被触发时 THE Debian构建作业 SHALL 构建 AMD64 和 ARM64 两个架构
4. WHEN CI流水线被触发时 THE Alpine构建作业 SHALL 构建 AMD64 和 ARM64 两个架构
5. THE CI流水线 SHALL 将所有四个构件（Debian amd64/arm64, Alpine amd64/arm64）上传到 GitHub 发布
6. WHEN 任何构建变体失败时 THE CI流水线 SHALL 报告失败但不阻塞其他变体
7. THE CI流水线 SHALL 为 Alpine 和 Debian 构建生成独立的构建报告
8. THE CI流水线 SHALL 使用矩阵策略（matrix strategy）定义构建变体（os-type: debian/alpine, arch: amd64/arm64）

### 需求 8：Alpine 运行时测试

**用户故事：** 作为质量保证工程师，我希望自动化测试验证 Alpine 二进制文件在 Alpine 运行时容器中工作，以便在发布前捕获兼容性问题。

#### 验收标准

1. WHEN 测试 Alpine 构件时 THE 构建系统 SHALL 将其解压到 Alpine Linux 运行时容器中
2. WHEN 测试 Alpine 构件时 THE 构建系统 SHALL 执行 "nginx -V" 以验证二进制文件运行
3. WHEN 测试 Alpine 构件时 THE 构建系统 SHALL 启动 Nginx 服务器并验证它接受连接
4. WHEN 测试 Alpine 构件时 THE 构建系统 SHALL 验证 Server 头包含 "nginx-mainline-mk"
5. WHEN 测试 Alpine 构件时 THE 构建系统 SHALL 验证二进制文件中存在所有预期的模块
6. THE 构建系统 SHALL 使用 Alpine Linux 3.19+ 作为测试运行时环境
7. IF Alpine 二进制文件无法运行 THEN 构建系统 SHALL 报告具体的错误消息

### 需求 9：动态链接和依赖项

**用户故事：** 作为系统管理员，我希望 Alpine 构建对系统库使用动态链接，以便 Alpine 包的安全更新自动应用。

#### 验收标准

1. THE Alpine构建器 SHALL 动态链接到 musl libc
2. THE Alpine构建器 SHALL 动态链接到 Alpine 的 OpenSSL 库
3. THE Alpine构建器 SHALL 动态链接到 Alpine 的 PCRE2 库
4. THE Alpine构建器 SHALL 动态链接到 Alpine 的 Zlib 库
5. WHEN 打包构件时 THE Alpine构建器 SHALL 包含所需运行时依赖项的列表
6. THE Alpine构建器 SHALL 从源代码静态编译 OpenSSL、PCRE2 和 Zlib（不使用 Alpine 包）

### 需求 10：文档和使用

**用户故事：** 作为用户，我希望有关于如何使用 Alpine 构件的清晰文档，以便可以在我的 Alpine 容器中成功部署它们。

#### 验收标准

1. THE 构建系统 SHALL 提供记录 Alpine 构建支持的 README 部分
2. THE 构建系统 SHALL 提供使用 Alpine 构件的示例 Dockerfile 片段
3. THE 构建系统 SHALL 记录 Alpine 和 Debian 构建之间的差异
4. THE 构建系统 SHALL 记录 Alpine 部署所需的运行时依赖项
5. THE 构建系统 SHALL 记录如何使用校验和验证 Alpine 构件完整性

### 需求 11：版本一致性

**用户故事：** 作为发布管理员，我希望 Alpine 和 Debian 构建使用相同的组件版本，以便两种变体具有一致的行为。

#### 验收标准

1. WHEN 构建 Alpine 和 Debian 变体时 THE 构建系统 SHALL 使用 versions.env 中的相同 Nginx 版本
2. WHEN 构建 Alpine 和 Debian 变体时 THE 构建系统 SHALL 使用 versions.env 中的相同 OpenSSL 版本
3. WHEN 构建 Alpine 和 Debian 变体时 THE 构建系统 SHALL 使用 versions.env 中的相同 PCRE2 版本
4. WHEN 构建 Alpine 和 Debian 变体时 THE 构建系统 SHALL 使用 versions.env 中的相同 Zlib 版本
5. THE 构建系统 SHALL 对两种构建类型使用相同的 versions.env 文件

### 需求 13：发布策略和版本管理

**用户故事：** 作为发布管理员，我希望发布策略与 Nginx 的 mainline/stable 分支模型保持一致，以便用户可以根据需求选择合适的构建版本。

#### 验收标准

1. THE 构建系统 SHALL 支持构建 Nginx mainline 版本（奇数次版本号，如 1.29.x）
2. THE 构建系统 SHALL 支持构建 Nginx stable 版本（偶数次版本号，如 1.28.x）
3. WHEN 发布 mainline 构建时 THE 构建系统 SHALL 在发布标签中标注 "mainline"
4. WHEN 发布 stable 构建时 THE 构建系统 SHALL 在发布标签中标注 "stable"
5. THE 构建系统 SHALL 为每个 Nginx 版本创建独立的 GitHub Release
6. WHEN 创建 Release 时 THE 构建系统 SHALL 包含所有四个构件（Debian amd64/arm64, Alpine amd64/arm64）
7. THE 构建系统 SHALL 在 Release 描述中说明 mainline 和 stable 版本的区别
8. THE 构建系统 SHALL 允许用户通过 Release 标签轻松识别和下载特定版本和平台的构件


### 需求 13：发布策略和版本管理

**用户故事：** 作为发布管理员，我希望发布策略与 Nginx 的 mainline/stable 分支模型保持一致，以便用户可以根据需求选择合适的构建版本。

#### 验收标准

1. THE 构建系统 SHALL 支持构建 Nginx mainline 版本（奇数次版本号，如 1.29.x）
2. THE 构建系统 SHALL 支持构建 Nginx stable 版本（偶数次版本号，如 1.28.x）
3. WHEN 发布 mainline 构建时 THE 构建系统 SHALL 在发布标签中标注 "mainline"
4. WHEN 发布 stable 构建时 THE 构建系统 SHALL 在发布标签中标注 "stable"
5. THE 构建系统 SHALL 为每个 Nginx 版本创建独立的 GitHub Release
6. WHEN 创建 Release 时 THE 构建系统 SHALL 包含所有四个构件（Debian amd64/arm64, Alpine amd64/arm64）
7. THE 构建系统 SHALL 在 Release 描述中说明 mainline 和 stable 版本的区别
8. THE 构建系统 SHALL 允许用户通过 Release 标签轻松识别和下载特定版本和平台的构件
