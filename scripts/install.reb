Rebol [
	title: "Ren garden pre-installer"
	author: "Graham"
	date: 30-Sep-2015
	version: 0.0.5
	purpose: "Downloads files to compile ren-c and ren garden"
	notes: {needs a version of ren-c that has Graham's prot-http.reb}
]

root: %/c/r3/

download-file: function [ target [file!] source [url!]][
	if exists? target [exit]
	if error? set/any 'err try [
		write target read source
		source: none
	][
		either find err/arg1 "Redirect to other host - requires custom handling" [
			source: to url! err/arg3
		][fail err]
	]
	if source [
		write target read source
	]
]

unless exists? %r3-gc.exe [
	write %r3-gc.exe read http://www.compkarori.com/r3/r3.exe
	print "Run this script using r3-gc.exe"
	halt
]

download-file %unzip.reb https://raw.githubusercontent.com/gchiu/Rebol3/master/scripts/unzip.reb

do %unzip.reb

if not exists? root [ 
	print ["making" root ]
	make-dir root
]

print ["changing to" root ]
change-dir root

sources: [
	%master.zip https://github.com/metaeducation/ren-c/archive/master.zip
	%develop.zip https://github.com/metaeducation/ren-cpp/archive/develop.zip
]

for-each [target source] sources [
	download-file target source
	print ["Unzipping" target]
	unzip %./ target
]

if error? set/any 'err try [rename %ren-c-master %rebol ][probe err]
if error? set/any 'err try [rename %ren-cpp-develop %ren-cpp][probe err]

binaries: [
	%r3-make.exe http://www.rebolsource.net/downloads/win32-x86/r3-g25033f8.exe
	%cmake.exe https://cmake.org/files/v3.3/cmake-3.3.2-win32-x86.exe
	%qt.exe http://download.qt.io/official_releases/online_installers/qt-unified-windows-x86-online.exe
]

for-each [target source] binaries [
	print ["downloading" source "as" target]
	download-file target source
]

print "Finished downloads, starting installers"

for-each installer [ %cmake.exe %qt.exe ][
	call/wait form installer
]