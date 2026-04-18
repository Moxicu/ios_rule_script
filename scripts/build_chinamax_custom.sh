#!/usr/bin/env bash
set -euo pipefail

UPSTREAM_FILE="rule/Surge/ChinaMax/ChinaMax_All_No_Resolve.list"
REMOVE_FILE="rule/Surge/Custom/remove_rules.list"
ADD_FILE="rule/Surge/Custom/add_rules.list"
OUTPUT_FILE="rule/Surge/Custom/ChinaMax_All_No_Resolve_Custom.list"

mkdir -p "$(dirname "$OUTPUT_FILE")"

# 先复制上游文件
cp "$UPSTREAM_FILE" "$OUTPUT_FILE"

# 删除 remove_rules.list 中列出的规则
if [ -f "$REMOVE_FILE" ]; then
  while IFS= read -r rule || [ -n "$rule" ]; do
    # 跳过空行和注释
    [ -z "$rule" ] && continue
    [[ "$rule" =~ ^# ]] && continue

    awk -v target="$rule" '$0 != target' "$OUTPUT_FILE" > "${OUTPUT_FILE}.tmp"
    mv "${OUTPUT_FILE}.tmp" "$OUTPUT_FILE"
  done < "$REMOVE_FILE"
fi

# 追加 add_rules.list 中的规则
if [ -f "$ADD_FILE" ]; then
  printf '\n# ===== My custom added rules =====\n' >> "$OUTPUT_FILE"
  while IFS= read -r rule || [ -n "$rule" ]; do
    # 跳过空行和注释
    [ -z "$rule" ] && continue
    [[ "$rule" =~ ^# ]] && continue

    # 避免重复追加
    if ! grep -Fxq "$rule" "$OUTPUT_FILE"; then
      echo "$rule" >> "$OUTPUT_FILE"
    fi
  done < "$ADD_FILE"
fi

echo "Generated: $OUTPUT_FILE"
