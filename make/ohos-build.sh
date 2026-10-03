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
# Two supported toolchain modes
# -----------------------------
# 1. Windows/WSL + DevEco Studio (defaults). The Windows clang.exe is driven
#    through WSL interop, so paths are converted with wslpath:
#      CC      <DEVECO_WSL>/hms/native/BiSheng/bin/clang.exe   (BiSheng clang)
#      SYSROOT <DEVECO_WIN>/openharmony/native/sysroot
#    HOST_R3 should be an r3.exe runnable from WSL.
#
# 2. Native Linux with an OpenHarmony SDK "native" component:
#      CC      <sdk>/native/llvm/bin/clang
#      SYSROOT <sdk>/native/sysroot          (derived from CC if omitted)
#      HOST_R3 /path/to/linux/r3
#
# target: --target=aarch64-linux-ohos (+ -D__MUSL__), -Wl,--no-undefined
#
# A Rebol3 interpreter (3.6+, e.g. Oldes/Rebol3) is required only to run
# pre-make.r3. Point HOST_R3 at it.
#
# Overridable environment variables:
#   CC          C compiler/driver   (default: DevEco BiSheng clang.exe)
#   SYSROOT     OHOS sysroot        (default: DevEco OpenHarmony sysroot)
#   HOST_R3     Rebol3 executable for pre-make   (default: r3)
#   DEVECO_WSL  DevEco SDK dir, WSL path         (default: /mnt/d/DevEco Studio/sdk/default)
#   DEVECO_WIN  DevEco SDK dir, Windows path     (default: D:/DevEco Studio/sdk/default)
#   WINREPO     Repo path, Windows/forward slash (default: derived via wslpath)
#   R3ROOT      Repo path in R3 absolute form    (default: derived)
#
# Usage:  make/ohos-build.sh
#
set -euo pipefail

HOST_R3="${HOST_R3:-r3}"
DEVECO_WSL="${DEVECO_WSL:-/mnt/d/DevEco Studio/sdk/default}"
DEVECO_WIN="${DEVECO_WIN:-D:/DevEco Studio/sdk/default}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$SCRIPT_DIR/.." && pwd)"

CC="${CC:-$DEVECO_WSL/hms/native/BiSheng/bin/clang.exe}"

# Windows .exe drivers (the WSL/DevEco case) need Windows-style path arguments;
# a native Linux driver needs Linux paths.
case "$CC" in
  *.exe|*.EXE)
    command -v wslpath >/dev/null || { echo "wslpath not found; set WINREPO/R3ROOT manually" >&2; exit 1; }
    WINREPO="${WINREPO:-$(wslpath -w "$REPO" | sed 's|\\|/|g')}"
    PREPO="$WINREPO"
    R3ROOT="${R3ROOT:-/${WINREPO/:/}}"
    SYSROOT="${SYSROOT:-$DEVECO_WIN/openharmony/native/sysroot}"
    ;;
  *)
    [ -n "${CC:-}" ] || { echo "native Linux mode requires CC=<clang> and SYSROOT=<sysroot>" >&2; exit 1; }
    if [ -z "${SYSROOT:-}" ]; then
      SYSROOT="$(cd "$(dirname "$CC")/../.." && pwd)/sysroot"
    fi
    [ -d "$SYSROOT" ] || { echo "SYSROOT not found: $SYSROOT (set CC and SYSROOT)" >&2; exit 1; }
    PREPO="$REPO"
    R3ROOT="${R3ROOT:-$REPO}"
    ;;
esac

GEN_DIR="$REPO/src/generated"
OBJ_DIR="$REPO/build-ohos/obj"
OUT_DIR="$REPO/build-ohos"
SPEC_SRC="$SCRIPT_DIR/spec-ohos-base.reb"
SPEC="$GEN_DIR/spec-ohos-base.reb"

[ -x "$CC" ] || { echo "OHOS clang not found: $CC" >&2; exit 1; }
[ -f "$SPEC_SRC" ] || { echo "spec not found: $SPEC_SRC" >&2; exit 1; }

mkdir -p "$GEN_DIR" "$OBJ_DIR"

#--------------------------------------------------------------------------
# 1. Generate headers/boot (gitignored) for the Base product
#--------------------------------------------------------------------------
echo "== Regenerating Rebol headers/boot (Base/OHOS) =="
sed "s|@REPO_ROOT@|$R3ROOT|" "$SPEC_SRC" > "$SPEC"
"$HOST_R3" -qs "$PREPO/make/pre-make.r3" "$PREPO/src/generated/spec-ohos-base.reb"

#--------------------------------------------------------------------------
# 2. Compile every Base translation unit for aarch64-linux-ohos
#--------------------------------------------------------------------------
COMMON=(
  --target=aarch64-linux-ohos
  "--sysroot=$SYSROOT"
  -DTO_OHOS -DREB_API -DUNICODE -DENDIAN_LITTLE -D_FILE_OFFSET_BITS=64
  '-DREBOL_OPTIONS_FILE="gen-config.h"'
  "-I$PREPO/src/include"
  -fdata-sections -ffunction-sections -funwind-tables -fstack-protector-strong
  -no-canonical-prefixes -fno-addrsig -Wa,--noexecstack -Wformat -Werror=format-security
  -Wno-pointer-sign
  -D__MUSL__ -O0 -g -fno-limit-debug-info -fPIC
)

mapfile -t FILES < <(grep -oE '%[A-Za-z0-9_./-]+\.c' "$SPEC_SRC" | tr -d '%' | sort -u)

echo "== Compiling ${#FILES[@]} Base translation units =="
for f in "${FILES[@]}"; do
  obj="${f//\//_}"
  "$CC" "${COMMON[@]}" -c "$PREPO/src/$f" -o "$PREPO/build-ohos/obj/${obj%.c}.o"
done

#--------------------------------------------------------------------------
# 3. Link the REB_API shared library from the Base objects
#--------------------------------------------------------------------------
echo "== Linking librebol-core-ohos.so =="
"$CC" --target=aarch64-linux-ohos --sysroot="$SYSROOT" -shared -fuse-ld=lld \
  -Wl,--no-undefined -o "$PREPO/build-ohos/librebol-core-ohos.so" \
  "$PREPO"/build-ohos/obj/*.o

#--------------------------------------------------------------------------
# 4. Link the REB_EXE host executable (adds os/host-main.c)
#--------------------------------------------------------------------------
echo "== Linking rebol3-ohos =="
"$CC" "${COMMON[@]}" -DREB_EXE -c "$PREPO/src/os/host-main.c" \
  -o "$PREPO/build-ohos/obj/host-main.o"
"$CC" --target=aarch64-linux-ohos --sysroot="$SYSROOT" -fuse-ld=lld \
  -Wl,--no-undefined -o "$PREPO/build-ohos/rebol3-ohos" \
  "$PREPO"/build-ohos/obj/*.o

echo "== Done =="
ls -l "$OUT_DIR/librebol-core-ohos.so" "$OUT_DIR/rebol3-ohos"
