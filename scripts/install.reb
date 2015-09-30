Rebol [
    title: "Ren garden pre-installer"
    author: "Graham"
    date: 30-Sep-2015
    version: 0.0.7
    purpose: "Downloads files to compile ren-c and ren garden"
    notes: {needs a version of ren-c that has Graham's prot-http.reb
        NB: this script downloads an unzip.exe until we have native unzip working again
    }
]

root: %/c/r4/

unless exists? %r3-gc.exe [
	print "Downloading r3-gc.exe"
    write %r3-gc.exe read http://www.compkarori.com/r3/r3.exe
    print "Run this script using gc.cmd with admin privs"
    write %gc.cmd "r3-gc install.reb"
    quit/now
]

if not value? 'for-each [
	do make error! "Needs r3-gc.exe.  Run gc.cmd from your windows shell with admin priviledges"
]

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

descend-path: function [{returns a path where p holds types decimal! string! or file!}
    start [file!] p [block!]
][
    for-each el p [
        for-each file read start [
            switch type? el [
                decimal! [
                    append start file
                    break
                ]
                string! [
                    if find file el [
                        append start file
                        break
                    ]
                ]
                file! [
                    if file = el [
                        append start file
                        break
                    ]
                ]
            ]
        ]
    ]
    start
]

; waiting for a working unzip
; download-file %unzip.reb https://raw.githubusercontent.com/gchiu/Rebol3/master/scripts/unzip.reb
; do %unzip.reb

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

download-file %unzip.exe http://stahlworks.com/dev/unzip.exe

for-each [target source] sources [
    download-file target source
    print ["Unzipping" target]
    call/wait join "unzip " target
    ; unzip %./ target
]

if error? set/any 'err try [rename %ren-c-master %rebol ][probe err]
if error? set/any 'err try [rename %ren-cpp-develop %ren-cpp][probe err]

binaries: [
    %rebol/make/r3-make.exe http://www.rebolsource.net/downloads/win32-x86/r3-g25033f8.exe
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

print "Make sure that mingw32-make is in your path when using the Qt 5.5 for Desktop console that is needed to run the compilers."
print "You can not use the command shell or powershell."
print "If Qt console path does not show something similar to this"
print "C:\Qt\5.5\mingw492_32\bin;C:\Qt\Tools\mingw492_32\bin; "
print "then you'll need to add it manually using the provided addpath.cmd file."
print ""

script: copy "set path=%path%;"

p: descend-path %/c/ [ %qt/ %tools/ "mingw" %bin/ ]
if exists? join p %mingw32-make.exe [
    append append script to-local-file p ";"
]
p: descend-path %/c/ [ %qt/ 5.5 "ming" %bin/ ]
append append script to-local-file p ";"

print ["writing out path script addpath.cmd" script]
write %addpath.cmd script

print "finished."