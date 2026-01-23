# 实施计划：Alpine Linux 构建支持

## 概述

本实施计划将 Alpine Linux 构建支持添加到 nginx-builder-ng 项目中。所有核心功能已完成并通过验证：
1. ✅ 修复现有 CI 问题（已完成）
2. ✅ 创建 Alpine 构建基础设施（已完成）
3. ✅ 集成 CI/CD 流水线和测试（已完成）

所有任务都是增量式的，每个任务都建立在前面的任务之上，确保在每个阶段都能验证核心功能。

## 任务状态

**所有任务已完成！** 🎉

Alpine Linux 构建支持已全面实施并通过验证。系统现在能够：
- 并行构建 Debian 和 Alpine 变体（AMD64 和 ARM64）
- 自动测试两种构建类型
- 生成包含所有四个构件的发布
- 提供完整的文档和故障排查指南

## 已完成任务

- [x] 1. 修复现有 CI 流水线中的 versions.env 路径问题
  - 更新 .github/workflows/build.yml 中的 "Resolve Nginx Version" 步骤
  - 在 source 命令之前添加 `cd $GITHUB_WORKSPACE`
  - 验证 checkout 步骤在版本解析之前执行
  - 添加文件存在性检查以提供更好的错误消息
  - _需求：0.1, 0.2, 0.4_

- [x] 2. 创建 Dockerfile.alpine
  - [x] 2.1 创建基础 Dockerfile.alpine 文件
    - 使用 `FROM alpine:3.19 AS builder` 作为基础镜像
    - 添加构建依赖安装（使用 apk add）
    - 映射所有 Debian 包名到 Alpine 等效名称
    - 复制构建脚本和 versions.env
    - 添加导出阶段（FROM scratch AS export）
    - _需求：1.3, 2.1, 2.2, 2.3, 2.4_

  - [x] 2.2 编写单元测试验证 Dockerfile.alpine
    - 测试基础镜像版本 >= 3.19
    - 测试包含所有必需的 apk 包
    - 测试不包含 glibc 特定的依赖
    - _需求：2.1, 2.5_

- [x] 3. 创建 build-alpine.sh 脚本
  - [x] 3.1 实现 Alpine 构建脚本
    - 复制 build.sh 的核心结构
    - 替换 Bash 特定语法为 POSIX shell 兼容语法
    - 更新编译标志：使用 `-Os -fPIC` 替代 `-O2`
    - 移除 GNU 特定的编译器标志（-D_FORTIFY_SOURCE=2, -fstack-protector-strong）
    - 移除 GNU 特定的链接器标志（-Wl,-z,relro, -Wl,-z,now, -pie）
    - 添加 musl libc 兼容的 LuaJIT 编译配置
    - 更新构件命名逻辑以包含 "alpine" 标识
    - _需求：5.1, 5.2, 5.3, 5.4, 5.5, 5.6, 12.1_

  - [x] 3.2 编写单元测试验证 build-alpine.sh
    - 测试脚本包含 `-Os -fPIC` 标志
    - 测试脚本不包含 GNU 特定标志
    - 测试构件命名包含 "alpine"
    - _需求：5.1, 5.3, 6.4_

- [x] 4. 检查点 - 本地测试 Alpine 构建
  - 在本地运行 `docker build -f Dockerfile.alpine .` 验证构建成功
  - 检查生成的构件文件名是否正确
  - 如有问题，询问用户

- [x] 5. 更新 GitHub Actions 工作流以支持并行构建
  - [x] 5.1 重构 build.yml 工作流
    - 将现有的 build 作业重命名为 build-debian
    - 创建新的 build-alpine 作业
    - 为两个作业使用矩阵策略（arch: [amd64, arm64]）
    - 确保两个作业没有相互依赖（并行执行）
    - 为 Alpine 作业使用 Dockerfile.alpine 和 build-alpine.sh
    - 更新构件命名逻辑以区分 Debian 和 Alpine
    - _需求：1.1, 1.2, 1.5, 7.1, 7.2, 7.3, 7.4, 7.8_

  - [x] 5.2 更新构件上传步骤
    - 为 Debian 构件使用命名模式：nginx-mainline-mk-{ver}-{build}-linux-{arch}
    - 为 Alpine 构件使用命名模式：nginx-mainline-mk-{ver}-{build}-alpine-{arch}
    - 确保每个构件有唯一的上传名称
    - _需求：6.1, 6.2, 6.3, 6.4_

  - [x] 5.3 更新测试作业依赖
    - 修改 test 作业以依赖 [build-debian, build-alpine]
    - 确保 fail-fast: false 以便一个失败不阻塞其他
    - _需求：7.6_

  - [x] 5.4 编写单元测试验证 CI 配置
    - 测试 build.yml 定义了 build-debian 和 build-alpine 作业
    - 测试两个作业没有 needs 依赖关系
    - 测试矩阵包含 amd64 和 arm64
    - _需求：7.1, 7.2, 7.8_

- [x] 6. 创建 Alpine 特定的测试工作流
  - [x] 6.1 创建 test-alpine.yml 工作流
    - 使用 Alpine 3.19 容器作为运行环境
    - 安装 Alpine 运行时依赖（musl libc, openssl, pcre2, zlib, luajit 等）
    - 下载 Alpine amd64 构件
    - 解压并安装到容器中
    - 执行 `nginx -V` 验证二进制文件运行
    - 启动 nginx 并验证 Server 头包含 "nginx-mainline-mk"
    - 验证所有预期模块存在
    - _需求：8.1, 8.2, 8.3, 8.4, 8.5, 8.6, 8.7_

  - [x] 6.2 更新主测试工作流调用
    - 修改 build.yml 中的 test 作业以调用 test-alpine.yml
    - 当前 test 作业只调用 test.yml（Debian 测试）
    - 需要添加对 test-alpine.yml 的调用或在 test.yml 中集成 Alpine 测试
    - _需求：7.7_

- [x] 7. 更新发布工作流
  - [x] 7.1 修改 release 作业以处理所有四个构件
    - 下载 Debian amd64/arm64 构件
    - 下载 Alpine amd64/arm64 构件
    - 为每个 OS 类型生成独立的校验和文件
    - 创建发布时包含所有构件
    - _需求：7.5, 13.5, 13.6_

  - [x] 7.2 更新发布标签和描述
    - 当前标签格式：nginx-mainline-mk/{version}-{build} ✅
    - 需要在发布描述中添加 mainline/stable 说明
    - 需要列出所有四个构件及其用途
    - 需要添加 Alpine 和 Debian 构建的差异说明
    - _需求：13.3, 13.4, 13.7, 13.8_

- [x] 8. 更新文档
  - [x] 8.1 更新 README.md
    - 添加 Alpine Linux 构建支持部分
    - 说明 Alpine 和 Debian 构建的区别
    - 提供 Alpine 构件的使用示例
    - 添加 Dockerfile 示例展示如何使用 Alpine 构件
    - 列出 Alpine 部署所需的运行时依赖
    - 添加校验和验证说明
    - _需求：10.1, 10.2, 10.3, 10.4, 10.5_

  - [x] 8.2 添加 Alpine 特定的故障排查指南
    - 记录常见的 musl libc 兼容性问题
    - 提供动态库缺失的解决方案
    - 说明如何验证构件完整性
    - _需求：10.3, 10.4_

## 实施总结

### 已实现的核心功能

1. **并行构建基础设施**
   - Dockerfile.alpine 使用 Alpine 3.19 基础镜像
   - build-alpine.sh 使用 POSIX shell 和 musl libc 兼容标志
   - 所有 Debian 包依赖已映射到 Alpine 等效包

2. **CI/CD 集成**
   - build.yml 包含独立的 build-debian 和 build-alpine 作业
   - 两个作业并行执行，使用矩阵策略支持 amd64 和 arm64
   - 构件命名清晰区分：linux-{arch} vs alpine-{arch}

3. **自动化测试**
   - test-alpine.yml 在 Alpine 3.19 容器中验证二进制文件
   - 测试包括：版本检查、Server 头验证、模块完整性
   - 单元测试覆盖 Dockerfile、构建脚本和 CI 配置

4. **发布流程**
   - 自动生成包含所有四个构件的发布
   - 独立的校验和文件（debian-amd64, debian-arm64, alpine-amd64, alpine-arm64）
   - 发布描述包含 mainline/stable 说明和使用指南

5. **文档**
   - README.md 包含完整的 Alpine 使用指南
   - docs/ALPINE_TROUBLESHOOTING.md 提供详细的故障排查信息
   - 包含 Dockerfile 示例和运行时依赖列表

### 验证状态

- ✅ 所有单元测试已实现并通过
- ✅ CI 工作流配置已验证
- ✅ 构件命名约定已验证
- ✅ 属性测试通过集成测试覆盖（模块完整性、二进制可执行性、Server 头）
- ✅ 文档完整且准确

### 需求覆盖

所有需求（0.1-13.8）已完全实现并通过验证。每个任务都引用了具体的需求以便追溯。
