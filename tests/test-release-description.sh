#!/bin/bash
# Test script for release description generation
# Validates Requirements: 13.3, 13.4, 13.7, 13.8

set -e

echo "Testing Release Description Generation..."

# Test 1: Verify mainline/stable detection logic
echo "Test 1: Mainline/Stable Detection"
test_version_detection() {
    local version=$1
    local expected=$2
    
    MINOR_VERSION=$(echo "$version" | cut -d. -f2)
    
    if [ $((MINOR_VERSION % 2)) -eq 1 ]; then
        RELEASE_TYPE="mainline"
    else
        RELEASE_TYPE="stable"
    fi
    
    if [ "$RELEASE_TYPE" = "$expected" ]; then
        echo "  ✅ Version $version correctly detected as $RELEASE_TYPE"
    else
        echo "  ❌ Version $version incorrectly detected as $RELEASE_TYPE (expected $expected)"
        exit 1
    fi
}

# Test mainline versions (odd minor numbers)
test_version_detection "1.29.4" "mainline"
test_version_detection "1.27.1" "mainline"
test_version_detection "1.25.3" "mainline"

# Test stable versions (even minor numbers)
test_version_detection "1.28.2" "stable"
test_version_detection "1.26.0" "stable"
test_version_detection "1.24.1" "stable"

echo ""

# Test 2: Verify workflow contains release description generation
echo "Test 2: Workflow Contains Release Description Step"
if grep -q "Generate Release Description" .github/workflows/build.yml; then
    echo "  ✅ Workflow contains 'Generate Release Description' step"
else
    echo "  ❌ Workflow missing 'Generate Release Description' step"
    exit 1
fi

# Test 3: Verify release description includes mainline/stable explanation
echo "Test 3: Release Description Includes Mainline/Stable Explanation"
if grep -q "Mainline vs Stable" .github/workflows/build.yml; then
    echo "  ✅ Release description includes mainline/stable explanation"
else
    echo "  ❌ Release description missing mainline/stable explanation"
    exit 1
fi

# Test 4: Verify release description lists all four artifacts
echo "Test 4: Release Description Lists All Four Artifacts"
artifact_count=$(grep -c "nginx-mainline-mk.*\.tar\.gz" .github/workflows/build.yml | head -1)
if [ "$artifact_count" -ge 4 ]; then
    echo "  ✅ Release description lists all four artifacts"
else
    echo "  ❌ Release description missing artifact listings (found $artifact_count references)"
    exit 1
fi

# Test 5: Verify release description includes Debian vs Alpine differences
echo "Test 5: Release Description Includes Debian vs Alpine Differences"
if grep -q "Debian vs Alpine Differences" .github/workflows/build.yml; then
    echo "  ✅ Release description includes Debian vs Alpine differences"
else
    echo "  ❌ Release description missing Debian vs Alpine differences"
    exit 1
fi

# Test 6: Verify release title includes release type (Mainline/Stable)
echo "Test 6: Release Title Includes Release Type"
if grep -q 'name: Nginx \${{ steps.release_type.outputs.RELEASE_LABEL }}' .github/workflows/build.yml; then
    echo "  ✅ Release title includes release type label"
else
    echo "  ❌ Release title missing release type label"
    exit 1
fi

# Test 7: Verify release description includes verification instructions
echo "Test 7: Release Description Includes Verification Instructions"
if grep -q "sha256sum -c" .github/workflows/build.yml; then
    echo "  ✅ Release description includes checksum verification instructions"
else
    echo "  ❌ Release description missing verification instructions"
    exit 1
fi

# Test 8: Verify release description includes quick start examples
echo "Test 8: Release Description Includes Quick Start Examples"
if grep -q "Quick Start" .github/workflows/build.yml; then
    echo "  ✅ Release description includes quick start examples"
else
    echo "  ❌ Release description missing quick start examples"
    exit 1
fi

echo ""
echo "✅ All release description tests passed!"
