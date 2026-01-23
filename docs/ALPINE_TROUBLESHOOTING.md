# Alpine Linux Build Troubleshooting Guide

This guide provides detailed troubleshooting information for Alpine Linux builds of nginx-builder-ng.

## Table of Contents

- [Understanding musl libc vs glibc](#understanding-musl-libc-vs-glibc)
- [Common Issues](#common-issues)
- [Runtime Dependency Problems](#runtime-dependency-problems)
- [Verification and Validation](#verification-and-validation)
- [Performance Considerations](#performance-considerations)

## Understanding musl libc vs glibc

Alpine Linux uses **musl libc**, a lightweight C standard library, while Debian/Ubuntu use **glibc** (GNU C Library). These are **binary incompatible**, meaning:

- Binaries compiled for glibc will NOT run on musl systems
- Binaries compiled for musl will NOT run on glibc systems
- You MUST use the correct artifact for your base image

### How to Identify Your System

```bash
# Check which libc your system uses
ldd --version

# musl output:
# musl libc (x86_64)
# Version 1.2.4

# glibc output:
# ldd (Debian GLIBC 2.36-9) 2.36
```

### Choosing the Right Artifact

| Base Image | Artifact to Use | Filename Pattern |
| :--- | :--- | :--- |
| `alpine:*` | Alpine build | `*-alpine-*.tar.gz` |
| `debian:*` | Debian build | `*-linux-*.tar.gz` |
| `ubuntu:*` | Debian build | `*-linux-*.tar.gz` |
| Distroless (Debian-based) | Debian build | `*-linux-*.tar.gz` |

## Common Issues

### Issue 1: "Error loading shared library"

**Full Error Message:**
```
Error loading shared library libluajit-5.1.so.2: No such file or directory (needed by /usr/sbin/nginx)
```

**Cause:** Missing runtime dependencies in the Alpine container.

**Solution:**

Install all required runtime dependencies:

```dockerfile
FROM alpine:3.19

RUN apk add --no-cache \
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

**Verification:**

```bash
# Check all dynamic library dependencies
ldd /usr/sbin/nginx

# All libraries should show a path, not "not found"
# Example output:
#   libluajit-5.1.so.2 => /usr/lib/libluajit-5.1.so.2
#   libssl.so.3 => /lib/libssl.so.3
```

### Issue 2: "No such file or directory" when binary exists

**Symptom:** Running `/usr/sbin/nginx` returns "No such file or directory" even though the file exists.

**Cause:** This cryptic error actually means the **dynamic linker** is missing or incompatible. You're likely trying to run a glibc binary on musl (or vice versa).

**Solution:**

1. Verify you downloaded the correct artifact:
   ```bash
   # Check filename - should contain "alpine"
   ls -l /tmp/nginx*.tar.gz
   # Should see: nginx-mainline-mk-X.X.X-XX-alpine-amd64.tar.gz
   ```

2. Verify your base image:
   ```bash
   cat /etc/os-release
   # Should show: Alpine Linux
   ```

3. If using wrong artifact, download the correct one:
   ```dockerfile
   # WRONG - using Debian artifact on Alpine
   ADD https://.../nginx-mainline-mk-1.29.4-40-linux-amd64.tar.gz /tmp/
   
   # CORRECT - using Alpine artifact on Alpine
   ADD https://.../nginx-mainline-mk-1.29.4-40-alpine-amd64.tar.gz /tmp/
   ```

### Issue 3: Segmentation Fault on Startup

**Symptom:** Nginx crashes immediately with segmentation fault.

**Possible Causes:**

1. **Wrong artifact type** (glibc binary on musl system)
2. **Incompatible Alpine version** (too old)
3. **Missing or incompatible library versions**

**Solution:**

```bash
# 1. Verify Alpine version (must be 3.19+)
cat /etc/alpine-release
# Should be: 3.19.0 or higher

# 2. Verify artifact is Alpine build
tar -tzf /tmp/nginx.tar.gz | head -5
# Check that it was built for Alpine

# 3. Check for library version mismatches
apk info | grep -E '(openssl|pcre2|luajit)'
# Ensure versions are compatible:
#   openssl >= 3.0
#   pcre2 >= 10.40
#   luajit >= 2.1

# 4. Update to latest Alpine packages
apk update && apk upgrade
```

### Issue 4: Module Not Found

**Symptom:** Nginx starts but specific module functionality doesn't work.

**Cause:** Module may not be compiled in, or module-specific dependencies are missing.

**Solution:**

```bash
# 1. List all compiled modules
/usr/sbin/nginx -V 2>&1 | grep -o 'with-[^ ]*' | sort

# 2. Download expected modules list
wget https://github.com/markd3ng/nginx-builder-ng/releases/download/nginx-mainline-mk%2F1.29.4-40/expected_modules.txt

# 3. Compare
/usr/sbin/nginx -V 2>&1 > /tmp/actual_modules.txt
diff expected_modules.txt /tmp/actual_modules.txt

# 4. If module is present but not working, check module-specific dependencies
# For example, GeoIP2 requires:
apk add libmaxminddb

# For Lua modules:
apk add luajit
```

## Runtime Dependency Problems

### Minimal Dependency Set

The absolute minimum packages required for Alpine builds:

```bash
apk add --no-cache \
    musl \
    pcre2 \
    openssl \
    zlib
```

### Full Dependency Set (Recommended)

For all modules to function correctly:

```bash
apk add --no-cache \
    libmaxminddb \      # GeoIP2 module
    libxml2 \           # XML processing
    libxslt \           # XSLT transformations
    gd \                # Image processing
    linux-pam \         # PAM authentication
    zstd-libs \         # Zstd compression
    pcre2 \             # Regex support
    openssl \           # TLS/SSL
    perl \              # Perl module
    tzdata \            # Timezone data
    luajit              # Lua scripting
```

### Debugging Missing Dependencies

```bash
# Method 1: Use ldd to find missing libraries
ldd /usr/sbin/nginx 2>&1 | grep "not found"

# Method 2: Try to run and capture error
/usr/sbin/nginx -t 2>&1 | grep -i "error"

# Method 3: Check which package provides a library
apk search -f libluajit-5.1.so.2
# Output: luajit-2.1.0_beta3-r7

# Method 4: Install package and verify
apk add luajit
ldd /usr/sbin/nginx | grep luajit
```

## Verification and Validation

### Complete Verification Checklist

```bash
#!/bin/sh
# Alpine Nginx Verification Script

echo "=== System Information ==="
cat /etc/alpine-release
uname -m

echo -e "\n=== Nginx Binary Check ==="
ls -lh /usr/sbin/nginx
file /usr/sbin/nginx

echo -e "\n=== Dynamic Library Dependencies ==="
ldd /usr/sbin/nginx

echo -e "\n=== Missing Libraries ==="
ldd /usr/sbin/nginx 2>&1 | grep "not found" || echo "None - All libraries found!"

echo -e "\n=== Nginx Version ==="
/usr/sbin/nginx -V

echo -e "\n=== Configuration Test ==="
/usr/sbin/nginx -t

echo -e "\n=== Module List ==="
/usr/sbin/nginx -V 2>&1 | grep -o 'with-[^ ]*' | sort

echo -e "\n=== Verification Complete ==="
```

### Checksum Verification

Always verify artifact integrity before deployment:

```bash
# Download artifact and checksum
wget https://github.com/markd3ng/nginx-builder-ng/releases/download/nginx-mainline-mk%2F1.29.4-40/nginx-mainline-mk-1.29.4-40-alpine-amd64.tar.gz
wget https://github.com/markd3ng/nginx-builder-ng/releases/download/nginx-mainline-mk%2F1.29.4-40/sha256sums-amd64.txt

# Verify (Alpine)
sha256sum -c sha256sums-amd64.txt 2>&1 | grep alpine

# Expected output:
# nginx-mainline-mk-1.29.4-40-alpine-amd64.tar.gz: OK

# If checksum fails:
# 1. Re-download the artifact
# 2. Check network connection
# 3. Verify you're using the correct checksum file for your architecture
```

### Runtime Testing

```bash
# Create minimal test configuration
cat > /tmp/nginx-test.conf << 'EOF'
daemon off;
error_log /dev/stderr info;
pid /tmp/nginx.pid;

events {
    worker_connections 1024;
}

http {
    access_log /dev/stdout;
    server {
        listen 8080;
        location / {
            return 200 "nginx-mainline-mk OK\n";
            add_header Content-Type text/plain;
        }
    }
}
EOF

# Start nginx with test config
/usr/sbin/nginx -c /tmp/nginx-test.conf &
NGINX_PID=$!

# Wait for startup
sleep 2

# Test HTTP request
wget -q -O- http://localhost:8080
# Expected: nginx-mainline-mk OK

# Check Server header
wget -S -O- http://localhost:8080 2>&1 | grep Server
# Expected: Server: nginx-mainline-mk/X.X.X

# Cleanup
kill $NGINX_PID
```

## Performance Considerations

### Alpine vs Debian Performance

| Aspect | Alpine (musl) | Debian (glibc) |
| :--- | :--- | :--- |
| **Binary Size** | Smaller (~12-15 MB) | Larger (~15-20 MB) |
| **Memory Usage** | Lower (~5-10% less) | Higher |
| **Startup Time** | Faster (~10-15% faster) | Slower |
| **Throughput** | Comparable | Comparable |
| **Optimization** | Size (`-Os`) | Performance (`-O2`) |

### When to Use Alpine

✅ **Use Alpine builds when:**
- Container image size is critical
- Running in resource-constrained environments
- Deploying many instances (lower memory footprint)
- Security is paramount (smaller attack surface)

❌ **Avoid Alpine builds when:**
- Maximum throughput is critical (use Debian with `-O2`)
- Using third-party binaries that require glibc
- Team is unfamiliar with musl libc differences

### Optimization Tips

```dockerfile
# Multi-stage build for minimal image size
FROM alpine:3.19 AS runtime

# Install only runtime dependencies (no build tools)
RUN apk add --no-cache \
    libmaxminddb libxml2 libxslt gd \
    linux-pam zstd-libs pcre2 openssl \
    perl tzdata luajit

# Add nginx artifact
ADD https://github.com/markd3ng/nginx-builder-ng/releases/download/nginx-mainline-mk%2F1.29.4-40/nginx-mainline-mk-1.29.4-40-alpine-amd64.tar.gz /tmp/
RUN tar -xzf /tmp/nginx-mainline-mk-*.tar.gz -C / && rm /tmp/nginx-mainline-mk-*.tar.gz

# Remove unnecessary files to reduce size
RUN rm -rf /usr/share/man/* /usr/share/doc/* /var/cache/apk/*

# Result: Minimal image with only runtime essentials
```

## Getting Help

If you encounter issues not covered in this guide:

1. **Check the main README**: [README.md](../README.md)
2. **Review build logs**: Check GitHub Actions logs for build-time issues
3. **Open an issue**: [GitHub Issues](https://github.com/markd3ng/nginx-builder-ng/issues)
4. **Provide details**:
   - Alpine version (`cat /etc/alpine-release`)
   - Architecture (`uname -m`)
   - Artifact filename
   - Full error message
   - Output of `ldd /usr/sbin/nginx`
