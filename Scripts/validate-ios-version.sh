#!/bin/bash
# validate-ios-version.sh
# Ensures no backwards compatibility code for iOS versions below 26

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Files to check (passed as arguments or find all Swift files)
if [ $# -eq 0 ]; then
    FILES=()
    while IFS= read -r -d '' file; do
        FILES+=("$file")
    done < <(find . -name "*.swift" -not -path "*/.*" -not -path "*/DerivedData/*" -print0)
else
    FILES=("$@")
fi

VIOLATIONS=0

for file in "${FILES[@]}"; do
    # Skip non-Swift files
    [[ "$file" != *.swift ]] && continue
    # Skip if file doesn't exist
    [ ! -f "$file" ] && continue

    # Check for @available with iOS < 26
    # Matches: @available(iOS 10-25, ...) or @available(*, iOS 10-25, ...)
    if grep -nE '@available\s*\([^)]*iOS\s+(1[0-9]|2[0-5])[^0-9]' "$file" 2>/dev/null; then
        echo -e "${RED}VIOLATION: @available for iOS < 26${NC}"
        echo "   File: $file"
        echo "   Rule: iOS 26+ only - no availability annotations for older versions"
        echo ""
        VIOLATIONS=$((VIOLATIONS + 1))
    fi

    # Check for #available with iOS < 26
    if grep -nE '#available\s*\([^)]*iOS\s+(1[0-9]|2[0-5])[^0-9]' "$file" 2>/dev/null; then
        echo -e "${RED}VIOLATION: #available for iOS < 26${NC}"
        echo "   File: $file"
        echo "   Rule: iOS 26+ only - no runtime availability checks for older versions"
        echo ""
        VIOLATIONS=$((VIOLATIONS + 1))
    fi

    # Check for #unavailable (almost always indicates backwards compat)
    if grep -nE '#unavailable\s*\(' "$file" 2>/dev/null; then
        echo -e "${RED}VIOLATION: #unavailable usage detected${NC}"
        echo "   File: $file"
        echo "   Rule: iOS 26+ only - no unavailability checks needed"
        echo ""
        VIOLATIONS=$((VIOLATIONS + 1))
    fi

    # Check for deprecated API markers targeting old iOS
    if grep -nE '@available\s*\(\s*\*\s*,\s*deprecated' "$file" 2>/dev/null; then
        echo -e "${RED}WARNING: Deprecated API marker found${NC}"
        echo "   File: $file"
        echo "   Note: Review if this is for iOS < 26 compatibility"
        echo ""
    fi
done

if [ $VIOLATIONS -eq 0 ]; then
    echo -e "${GREEN}iOS version check passed - no backwards compatibility code found${NC}"
    exit 0
else
    echo -e "${RED}Found $VIOLATIONS iOS version violation(s)${NC}"
    exit 1
fi
