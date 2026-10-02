REBOL [
	Title: "Base product spec for HarmonyOS/OHOS header/boot generation"
	Note: {
		Driven by make/ohos-build.sh, which replaces the @REPO_ROOT@
		placeholder below with the absolute checkout path before passing
		this file to make/pre-make.r3. Mirrors the Base product defined
		in make/rebol3.nest.
	}
]

root:     %@REPO_ROOT@/
source:   %src/
version:  3.22.5
product:  Base
platform: OHOS
os:       ohos
sys:      linux
arch:     arm64
vendor:   ohos
abi:      elf
compiler: clang
stack-size: 4194304
remove-docstrings: off

config: [
	INCLUDE_MBEDTLS
	COLOR_CONSOLE
	DEBUG_HASH_COLLISIONS
	INCLUDE_TASK
	INCLUDE_DEFLATE
]

core-files: [
	%core/a-constants.c
	%core/a-globals.c
	%core/a-lib.c
	%core/b-boot.c
	%core/b-init.c
	%core/c-do.c
	%core/c-error.c
	%core/c-frame.c
	%core/c-function.c
	%core/c-handle.c
	%core/c-port.c
	%core/c-task.c
	%core/c-word.c
	%core/d-crash.c
	%core/d-dump.c
	%core/d-print.c
	%core/f-blocks.c
	%core/f-deci.c
	%core/f-dtoa.c
	%core/f-enbase.c
	%core/f-extension.c
	%core/f-int.c
	%core/f-math.c
	%core/f-modify.c
	%core/f-stablemerge-sort.c
	%core/f-adp-symmetry-psort.c
	%core/f-random.c
	%core/f-round.c
	%core/f-series.c
	%core/f-stubs.c
	%core/l-scan.c
	%core/l-types.c
	%core/m-gc.c
	%core/m-pools.c
	%core/m-series.c
	%core/n-control.c
	%core/n-data.c
	%core/n-hash.c
	%core/n-io.c
	%core/n-loop.c
	%core/n-math.c
	%core/n-sets.c
	%core/n-strings.c
	%core/n-system.c
	%core/p-checksum.c
	%core/p-console.c
	%core/p-dir.c
	%core/p-dns.c
	%core/p-event.c
	%core/p-file.c
	%core/p-net.c
	%core/s-cases.c
	%core/s-crc.c
	%core/s-file.c
	%core/s-find.c
	%core/s-make.c
	%core/s-mold.c
	%core/s-ops.c
	%core/s-trim.c
	%core/s-unicode.c
	%core/t-bitset.c
	%core/t-block.c
	%core/t-char.c
	%core/t-datatype.c
	%core/t-date.c
	%core/t-decimal.c
	%core/t-event.c
	%core/t-function.c
	%core/t-gob.c
	%core/t-handle.c
	%core/t-image.c
	%core/t-integer.c
	%core/t-logic.c
	%core/t-map.c
	%core/t-money.c
	%core/t-none.c
	%core/t-object.c
	%core/t-pair.c
	%core/t-port.c
	%core/t-string.c
	%core/t-struct.c
	%core/t-time.c
	%core/t-tuple.c
	%core/t-typeset.c
	%core/t-utype.c
	%core/t-vector.c
	%core/t-word.c
	%core/u-compress.c
	%core/u-parse.c
	%core/u-mbedtls.c
	%core/mbedtls/platform.c
	%core/mbedtls/platform_util.c
	%core/mbedtls/sha1.c
	%core/mbedtls/sha256.c
	%core/mbedtls/sha512.c
	%core/mbedtls/md5.c
	%core/deflate/lib/adler32.c
	%core/deflate/lib/crc32.c
	%core/deflate/lib/deflate_compress.c
	%core/deflate/lib/deflate_decompress.c
	%core/deflate/lib/gzip_compress.c
	%core/deflate/lib/gzip_decompress.c
	%core/deflate/lib/utils.c
	%core/deflate/lib/zlib_compress.c
	%core/deflate/lib/zlib_decompress.c
	%core/deflate/lib/x86/cpu_features.c
	%core/deflate/lib/arm/cpu_features_arm.c
]

host-files: [
	%os/host-args.c
	%os/host-device.c
	%os/host-stdio.c
	%os/dev-net.c
	%os/dev-dns.c
	%os/posix/host-lib.c
	%os/posix/host-readline.c
	%os/posix/dev-file.c
	%os/posix/dev-stdio.c
	%os/posix/dev-event.c
]

mezz-base-files: [
	%mezz/base-constants.reb
	%mezz/base-funcs.reb
	%mezz/base-series.reb
	%mezz/base-files.reb
	%mezz/base-debug.reb
	%mezz/base-defs.reb
	%mezz/base-collected.reb
]

mezz-sys-files: [
	%mezz/sys-base.reb
	%mezz/sys-ports.reb
	%mezz/sys-codec.reb
	%mezz/sys-load.reb
	%mezz/sys-start.reb
]

mezz-lib-files: [
	%mezz/mezz-ansi.reb
	%mezz/mezz-secure.reb
	%mezz/mezz-types.reb
	%mezz/mezz-func.reb
	%mezz/mezz-debug.reb
	%mezz/mezz-logger.reb
	%mezz/mezz-control.reb
	%mezz/mezz-save.reb
	%mezz/mezz-series.reb
	%mezz/mezz-files.reb
	%mezz/mezz-shell.reb
	%mezz/mezz-math.reb
	%mezz/mezz-help.reb
	%mezz/mezz-banner.reb
	%mezz/mezz-tail.reb
]

mezz-prot-files: []

boot-host-files: []
