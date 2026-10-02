#!/usr/bin/env bash
#
# Reproducible HarmonyOS NEXT / OpenHarmony (aarch64-linux-ohos) build of
# the Rebol3 "Base" product.
#
# This regenerates the gitignored headers/boot material (via make/pre-make.r3
# and make/spec-ohos-base.reb) and then compiles and links:
#     build-ohos/librebol-core-ohos.so   (REB_API shared library)
#     build-ohos/rebol3-ohos             (REB_EXE host executable)
#
# Environment assumptions / required toolchain paths
# --------------------------------------------------
# Runs under WSL so that the Windows DevEco Studio native toolchain can be
# executed directly. The exact toolchain that DevEco Studio uses (from the
# generated CMake cache of the D:\R3OHOS project):
#
#   compiler : <DEVECO_WIN>/hms/native/BiSheng/bin/clang.exe   (BiSheng clang)
#   sysroot  : <DEVECO_WIN>/openharmony/native/sysroot
#   target   : --target=aarch64-linux-ohos  (+ -D__MUSL__)
#
# A Rebol3 interpreter (3.6+, e.g. Oldes/Rebol3) is required only to run
# pre-make.r3. Point HOST_R3 at it (e.g. a Windows r3.exe runnable from WSL).
#
# Overridable environment variables:
#   HOST_R3     Rebol3 executable for pre-make   (default: r3)
#   DEVECO_WSL  DevEco SDK dir, WSL path         (default: /mnt/d/DevEco Studio/sdk/default)
#   DEVECO_WIN  DevEco SDK dir, Windows path     (default: D:/DevEco Studio/sdk/default)
#   WINREPO     Repo path, Windows/forward slash (default: derived via wslpath)
#   R3ROOT      Repo path in R3 absolute form    (default: derived from WINREPO)
#
# Usage:  make/ohos-build.sh
#
set -euo pipefail

HOST_R3="${HOST_R3:-r3}"
DEVECO_WSL="${DEVECO_WSL:-/mnt/d/DevEco Studio/sdk/default}"
DEVECO_WIN="${DEVECO_WIN:-D:/DevEco Studio/sdk/default}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$SCRIPT_DIR/.." && pwd)"

# Windows-side, forward-slash path of the repo (D:/repos/rebol3) and the
# R3 absolute form used inside the spec (/D/repos/rebol3).
if [ -z "${WINREPO:-}" ]; then
  command -v wslpath >/dev/null || { echo "wslpath not found; set WINREPO/R3ROOT manually" >&2; exit 1; }
  WINREPO="$(wslpath -w "$REPO" | sed 's|\\|/|g')"
fi
R3ROOT="${R3ROOT:-/${WINREPO/:/}}"

CLANG="$DEVECO_WSL/hms/native/BiSheng/bin/clang.exe"
SYSROOT="$DEVECO_WIN/openharmony/native/sysroot"

GEN_DIR="$REPO/src/generated"
OBJ_DIR="$REPO/build-ohos/obj"
OUT_DIR="$REPO/build-ohos"
SPEC_SRC="$SCRIPT_DIR/spec-ohos-base.reb"
SPEC="$GEN_DIR/spec-ohos-base.reb"

[ -x "$CLANG" ] || { echo "OHOS clang not found: $CLANG" >&2; exit 1; }
[ -f "$SPEC_SRC" ] || { echo "spec not found: $SPEC_SRC" >&2; exit 1; }

mkdir -p "$GEN_DIR" "$OBJ_DIR"

#--------------------------------------------------------------------------
# 1. Generate headers/boot (gitignored) for the Base product
#--------------------------------------------------------------------------
echo "== Regenerating Rebol headers/boot (Base/OHOS) =="
sed "s|@REPO_ROOT@|$R3ROOT|" "$SPEC_SRC" > "$SPEC"
"$HOST_R3" -qs "$WINREPO/make/pre-make.r3" "$WINREPO/src/generated/spec-ohos-base.reb"

#--------------------------------------------------------------------------
# 2. Compile every Base translation unit for aarch64-linux-ohos
#--------------------------------------------------------------------------
COMMON=(
  --target=aarch64-linux-ohos
  "--sysroot=$SYSROOT"
  -DTO_OHOS -DREB_API -DUNICODE -DENDIAN_LITTLE -D_FILE_OFFSET_BITS=64
  '-DREBOL_OPTIONS_FILE="gen-config.h"'
  "-I$WINREPO/src/include"
  -fdata-sections -ffunction-sections -funwind-tables -fstack-protector-strong
  -no-canonical-prefixes -fno-addrsig -Wa,--noexecstack -Wformat -Werror=format-security
  -Wno-pointer-sign
  -D__MUSL__ -O0 -g -fno-limit-debug-info -fPIC
)

mapfile -t FILES < <(grep -oE '%[A-Za-z0-9_./-]+\.c' "$SPEC_SRC" | tr -d '%' | sort -u)

echo "== Compiling ${#FILES[@]} Base translation units =="
for f in "${FILES[@]}"; do
  obj="${f//\//_}"
  "$CLANG" "${COMMON[@]}" -c "$WINREPO/src/$f" -o "$WINREPO/build-ohos/obj/${obj%.c}.o"
done

#--------------------------------------------------------------------------
# 3. Link the REB_API shared library from the Base objects
#--------------------------------------------------------------------------
echo "== Linking librebol-core-ohos.so =="
"$CLANG" --target=aarch64-linux-ohos --sysroot="$SYSROOT" -shared -fuse-ld=lld \
  -Wl,--no-undefined -o "$WINREPO/build-ohos/librebol-core-ohos.so" \
  "$WINREPO"/build-ohos/obj/*.o

#--------------------------------------------------------------------------
# 4. Link the REB_EXE host executable (adds os/host-main.c)
#--------------------------------------------------------------------------
echo "== Linking rebol3-ohos =="
"$CLANG" "${COMMON[@]}" -DREB_EXE -c "$WINREPO/src/os/host-main.c" \
  -o "$WINREPO/build-ohos/obj/host-main.o"
"$CLANG" --target=aarch64-linux-ohos --sysroot="$SYSROOT" -fuse-ld=lld \
  -Wl,--no-undefined -o "$WINREPO/build-ohos/rebol3-ohos" \
  "$WINREPO"/build-ohos/obj/*.o

echo "== Done =="
ls -l "$OUT_DIR/librebol-core-ohos.so" "$OUT_DIR/rebol3-ohos"
