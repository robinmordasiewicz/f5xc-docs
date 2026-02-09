#!/usr/bin/env bash
set -euo pipefail

# Aggregates llms.txt from child Astro documentation sites into federated files.
# Discovers repos by listing all robinmordasiewicz/f5xc-* repos, then attempts
# to fetch llms.txt from each repo's GitHub Pages site.

OWNER="robinmordasiewicz"
BASE_URL="https://robinmordasiewicz.github.io"
OUTPUT_DIR="${1:-.}"

# Repos to skip (not Astro doc sites)
SKIP_REPOS="f5xc-docs f5xc-docs-builder f5xc-docs-theme f5xc-template f5xc-mkdocs f5xc-api-enriched f5xc-api-fixed f5xc-api-mcp f5xc-cloudstatus-mcp f5xc-console f5xc-xcsh"

echo "Discovering f5xc-* repos..."
REPOS=$(gh repo list "$OWNER" --json name --limit 100 -q '.[].name' | grep '^f5xc-' | sort)

FEDERATED_INDEX="# F5 Distributed Cloud Documentation

> Combined documentation index for LLM consumption.
> Source: ${BASE_URL}/f5xc-docs/

## Documentation Sites
"

FEDERATED_FULL="# F5 Distributed Cloud Documentation (Full)

> Complete documentation content from all F5 XC sites.
> Source: ${BASE_URL}/f5xc-docs/
"

FOUND=0

for REPO in $REPOS; do
  # Skip non-doc repos
  if echo "$SKIP_REPOS" | grep -qw "$REPO"; then
    echo "Skipping $REPO (not a doc site)"
    continue
  fi

  SITE_URL="${BASE_URL}/${REPO}"
  LLMS_URL="${SITE_URL}/llms.txt"
  LLMS_FULL_URL="${SITE_URL}/llms-full.txt"

  echo "Checking $LLMS_URL ..."
  HTTP_CODE=$(curl -s -o /dev/null -w '%{http_code}' "$LLMS_URL" || echo "000")

  if [ "$HTTP_CODE" = "200" ]; then
    echo "  Found llms.txt for $REPO"
    FOUND=$((FOUND + 1))

    # Add to index
    LLMS_CONTENT=$(curl -sL "$LLMS_URL")
    TITLE=$(echo "$LLMS_CONTENT" | head -1 | sed 's/^# //')
    FEDERATED_INDEX="${FEDERATED_INDEX}
- [${TITLE}](${LLMS_FULL_URL}): ${SITE_URL}"

    # Add to full content
    FULL_CONTENT=$(curl -sL "$LLMS_FULL_URL" 2>/dev/null || echo "")
    if [ -n "$FULL_CONTENT" ]; then
      FEDERATED_FULL="${FEDERATED_FULL}

---

## ${TITLE}

> Source: ${SITE_URL}

${FULL_CONTENT}
"
    fi
  else
    echo "  No llms.txt for $REPO (HTTP $HTTP_CODE)"
  fi
done

echo ""
echo "Found llms.txt in $FOUND repos."

if [ "$FOUND" -gt 0 ]; then
  echo "$FEDERATED_INDEX" > "${OUTPUT_DIR}/llms.txt"
  echo "$FEDERATED_FULL" > "${OUTPUT_DIR}/llms-full.txt"
  echo "Written ${OUTPUT_DIR}/llms.txt and ${OUTPUT_DIR}/llms-full.txt"
else
  echo "No child sites have llms.txt yet. Skipping file generation."
fi
