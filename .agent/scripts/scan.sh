#!/usr/bin/env bash
# Scans the Java source tree and emits raw symbol locations for agent processing.
# Usage: bash .agent/scripts/scan.sh
set -uo pipefail

JAVA_ROOT="src/main/java"

if [ ! -d "$JAVA_ROOT" ]; then
    echo "ERROR: $JAVA_ROOT not found. Run from project root." >&2
    exit 1
fi

echo "# SCAN — $(date +%Y-%m-%d)"
echo ""

echo "## FILES"
find "$JAVA_ROOT" -name "*.java" | sort | while read -r f; do
    hash=$(git log --follow -1 --format="%h" -- "$f" 2>/dev/null || echo "unknown")
    date=$(git log --follow -1 --format="%ad" --date=format:"%Y-%m-%d" -- "$f" 2>/dev/null || echo "unknown")
    echo "  $f COMMIT=$hash DATE=$date"
done
echo ""

echo "## CLASSES"
find "$JAVA_ROOT" -name "*.java" | sort | while read -r f; do
    total=$(wc -l < "$f")
    hash=$(git log --follow -1 --format="%h" -- "$f" 2>/dev/null || echo "unknown")
    grep -n "^public class \|^public interface \|^public enum \|^public record \|^  public class \|^  public record " "$f" 2>/dev/null \
    | while IFS=: read -r lineno rest; do
        ann=$(awk "NR>=$((lineno-3)) && NR<$lineno && /^@/" "$f" | tr '\n' ',' | sed 's/,$//')
        echo "  FILE=$f COMMIT=$hash LINE=$lineno TOTAL=$total ANN='$ann' DEF='$(echo "$rest" | sed "s/^ //")'"
    done
done
echo ""

echo "## ENDPOINTS"
find "$JAVA_ROOT" -name "*.java" | sort | while read -r f; do
    hash=$(git log --follow -1 --format="%h" -- "$f" 2>/dev/null || echo "unknown")
    grep -n "@GetMapping\|@PostMapping\|@PutMapping\|@DeleteMapping\|@PatchMapping\|@RequestMapping" "$f" 2>/dev/null \
    | while IFS=: read -r lineno rest; do
        method=$(awk "NR>$lineno && NR<=$((lineno+3)) && /public/" "$f" | grep -o '[a-zA-Z][a-zA-Z0-9]*(' | head -1 | tr -d '(')
        echo "  FILE=$f COMMIT=$hash LINE=$lineno METHOD='$method' MAPPING='$(echo "$rest" | sed "s/^ //")'"
    done
done
echo ""

echo "## METHODS"
find "$JAVA_ROOT" -name "*.java" | sort | while read -r f; do
    hash=$(git log --follow -1 --format="%h" -- "$f" 2>/dev/null || echo "unknown")
    grep -n "    public [a-zA-Z<@]" "$f" 2>/dev/null \
    | grep -v "class \|interface \|enum \|record \|get[A-Z]\|set[A-Z]\|is[A-Z]\|equals\|hashCode\|toString\|Builder" \
    | while IFS=: read -r lineno rest; do
        echo "  FILE=$f COMMIT=$hash LINE=$lineno SIG='$(echo "$rest" | sed "s/^ //")'"
    done
done
echo ""

echo "## CONFIG"
find "$JAVA_ROOT" -name "*.java" | sort | while read -r f; do
    hash=$(git log --follow -1 --format="%h" -- "$f" 2>/dev/null || echo "unknown")
    grep -n "@ConfigurationProperties" "$f" 2>/dev/null \
    | while IFS=: read -r lineno rest; do
        total=$(wc -l < "$f")
        echo "  FILE=$f COMMIT=$hash LINE=$lineno TOTAL=$total DEF='$(echo "$rest" | sed "s/^ //")'"
    done
done
