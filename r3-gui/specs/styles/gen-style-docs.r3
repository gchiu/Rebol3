REBOL [
	Title: "REBOL 3 GUI - Style Tree"
	Author: ["Didier Cadieu" "Henrik Mikael Kristensen"]
]

; Find some way to run this regularly and automatically.

; use our GUI version
do %../../original-vid34-patches/gui-load.r3

styles: words-of guie/styles

out: ""

emit: func [o] [append out reform o append out newline]

emit ["VID3.4 Style List" newline]
emit ["Generated on" now "using REBOL 3 version" system/version newline]

foreach st styles [

	emit ["===" guie/styles/:st/name newline]
	emit ["Parent:" guie/styles/:st/parent newline]
	emit ["Description:" guie/styles/:st/about newline]
	emit ["Options:" mold words-of guie/styles/:st/options newline]

]

write %style-list.rmd to-binary out
if exists? %../../../r3-alpha [
	write %../../../r3-alpha/files/Users/Henrik/style-list.rmd to-binary out
]

tree: [] ; hold a pairs of : style, block of style's childs

; fill the block of style, childs
foreach s styles [
	p: guie/styles/:s/parent
	if not find tree p [repend tree [p copy []]]
	append tree/:p s
]

; simple stack of pair values
pile: []
push: func [level value] [append pile level append pile value] ;probe pile]
pop: func [] [take/part/last pile 2]

; now build a block of : title level, style
level: 0
style: none

clear out

emit "VID3.4 Style Tree"
emit ""
emit ["Generated on" now "using REBOL 3 version" system/version newline]

forever [
	b: tree/:style
	if block? b [
		foreach style reverse b [push (level + 1) style]
	]
	set [level style] pop
	if none? level [break]
	emit [array/initial level "  " style]
]

write %style-tree.rmd to-binary out
if exists? %../../../r3-alpha [
	write %../../../r3-alpha/files/Users/Henrik/style-tree.rmd to-binary out
]