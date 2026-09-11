#!/bin/bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/immortalwrt.sh"

declare -A PLATFORMS=(
  ["x86_64"]="${IMMORTALWRT_PACKAGE_ROOT}/x86_64"
  ["aarch64_generic"]="${IMMORTALWRT_PACKAGE_ROOT}/aarch64_generic"
  ["aarch64_cortex-a53"]="${IMMORTALWRT_PACKAGE_ROOT}/aarch64_cortex-a53"
)

# 各类包对应的目录
declare -A PACKAGE_SOURCES=(
  ["luci-app-homeproxy"]="luci"
  ["luci-i18n-homeproxy-zh-cn"]="luci"
  ["sing-box"]="packages"
)

OUT_DIR=$(pwd)
TMP_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

for platform in "${!PLATFORMS[@]}"; do
  BASE_URL="${PLATFORMS[$platform]}"
  SAVE_DIR="${OUT_DIR}/${platform}"
  mkdir -p "$SAVE_DIR"

  echo "📦 正在处理平台: $platform"

  for keyword in "${!PACKAGE_SOURCES[@]}"; do
    subdir="${PACKAGE_SOURCES[$keyword]}"
    URL="${BASE_URL}/${subdir}"
    PKG_INDEX="${TMP_DIR}/${platform}_${subdir}_Packages"

    echo "🔍 从 Packages.gz 查找 $keyword"

    # 下载并解压 Packages.gz
    if ! curl -fsL "${URL}/Packages.gz" | gunzip -c > "$PKG_INDEX"; then
      echo "⚠️ 无法获取 ${URL}/Packages.gz"
      continue
    fi

    # 从 Filename 字段中匹配 ipk
    FILE=$(awk -v kw="$keyword" '
      $1=="Filename:" && $2 ~ "^"kw".*\\.ipk$" {
        print $2
      }
    ' "$PKG_INDEX" | sort -V | tail -n 1)

    if [ -n "$FILE" ]; then
      echo "⬇️ 正在下载: $FILE"
      curl -fsL -o "${SAVE_DIR}/${FILE##*/}" "${URL}/${FILE}"

      # 🚧 文件名中含 ~ 的修正
      if [[ "$FILE" == *"~"* ]]; then
        NEW_FILE=$(basename "$FILE" | tr '~' '-')
        mv "${SAVE_DIR}/$(basename "$FILE")" "${SAVE_DIR}/${NEW_FILE}"
        echo "🔧 已重命名为: $NEW_FILE"
      fi
    else
      echo "❌ 未找到匹配: $keyword"
      exit 1
    fi
  done
done

echo "✅ 下载完成，文件已分别存入 x86_64、aarch64_generic、aarch64_cortex-a53 目录中。"
