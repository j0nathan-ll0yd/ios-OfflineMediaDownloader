#!/bin/bash
# validate-tca-patterns.sh
# Enforces TCA conventions (zero-tolerance rules)

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
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

    # Check if this is a TCA view file (contains StoreOf or @Bindable.*store)
    IS_TCA_VIEW=false
    if grep -qE 'StoreOf<|@Bindable.*store|@Bindable var store' "$file" 2>/dev/null; then
        IS_TCA_VIEW=true
    fi

    if [ "$IS_TCA_VIEW" = true ]; then
        # ZERO-TOLERANCE: No @State in TCA views
        # Exception: Lines containing "// non-tca" or in structs that don't use StoreOf
        # We check if @State appears between a struct definition and its @Bindable store
        STATE_VIOLATIONS=$(grep -nE '@State\s+(private\s+)?var' "$file" 2>/dev/null | grep -v "// non-tca" || true)
        if [ -n "$STATE_VIOLATIONS" ]; then
            # Additional check: see if the @State is in a non-TCA view (a struct without StoreOf)
            # For simplicity, we allow @State in separate helper views (no StoreOf in same struct)
            # This is a heuristic - flag only if @State is within 50 lines of @Bindable.*store
            HAS_CLOSE_STORE=false
            while IFS=: read -r line_num _; do
                NEARBY_STORE=$(sed -n "$((line_num-50)),$((line_num+50))p" "$file" 2>/dev/null | grep -c '@Bindable.*store' || true)
                if [ "$NEARBY_STORE" -gt 0 ]; then
                    HAS_CLOSE_STORE=true
                    break
                fi
            done <<< "$STATE_VIOLATIONS"

            if [ "$HAS_CLOSE_STORE" = true ]; then
                echo -e "${RED}VIOLATION: @State in TCA view${NC}"
                echo "   File: $file"
                echo "$STATE_VIOLATIONS" | head -3
                echo "   Rule: All state must be in the TCA reducer, not SwiftUI @State"
                echo "   Fix: Move this state to the feature's State struct"
                echo "   Note: Add '// non-tca' comment if this is intentionally a non-TCA helper view"
                echo ""
                VIOLATIONS=$((VIOLATIONS + 1))
            fi
        fi

        # ZERO-TOLERANCE: No @StateObject in TCA views
        if grep -nE '@StateObject' "$file" 2>/dev/null; then
            echo -e "${RED}VIOLATION: @StateObject in TCA view${NC}"
            echo "   File: $file"
            grep -nE '@StateObject' "$file" | head -3
            echo "   Rule: TCA views should not use @StateObject"
            echo "   Fix: Use the TCA store pattern instead"
            echo ""
            VIOLATIONS=$((VIOLATIONS + 1))
        fi

        # ZERO-TOLERANCE: No @ObservedObject in TCA views
        if grep -nE '@ObservedObject' "$file" 2>/dev/null; then
            echo -e "${RED}VIOLATION: @ObservedObject in TCA view${NC}"
            echo "   File: $file"
            grep -nE '@ObservedObject' "$file" | head -3
            echo "   Rule: TCA views should not use @ObservedObject"
            echo "   Fix: Use @Bindable var store: StoreOf<Feature>"
            echo ""
            VIOLATIONS=$((VIOLATIONS + 1))
        fi
    fi

    # Check if this is a dependency file (in Dependencies/ folder)
    if [[ "$file" == *"/Dependencies/"* ]]; then
        # Check for @DependencyClient macro
        if ! grep -qE '@DependencyClient' "$file" 2>/dev/null; then
            # Only warn if it looks like a client struct
            if grep -qE 'struct\s+\w+Client' "$file" 2>/dev/null; then
                echo -e "${YELLOW}WARNING: Dependency client may be missing @DependencyClient macro${NC}"
                echo "   File: $file"
                echo "   Rule: All dependency clients MUST use @DependencyClient macro"
                echo ""
            fi
        fi
    fi

    # Check if this is a reducer file
    if grep -qE '@Reducer' "$file" 2>/dev/null; then
        # ZERO-TOLERANCE: @ObservableState required on State struct
        if grep -qE 'struct\s+State' "$file" 2>/dev/null; then
            if ! grep -qE '@ObservableState' "$file" 2>/dev/null; then
                echo -e "${RED}VIOLATION: Reducer State missing @ObservableState${NC}"
                echo "   File: $file"
                echo "   Rule: All TCA State structs MUST have @ObservableState"
                echo "   Fix: Add @ObservableState before struct State"
                echo ""
                VIOLATIONS=$((VIOLATIONS + 1))
            fi
        fi
    fi
done

if [ $VIOLATIONS -eq 0 ]; then
    echo -e "${GREEN}TCA pattern check passed - no violations found${NC}"
    exit 0
else
    echo -e "${RED}Found $VIOLATIONS TCA pattern violation(s)${NC}"
    exit 1
fi
