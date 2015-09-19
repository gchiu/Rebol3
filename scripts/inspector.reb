Rebol [
	title: "Rebol3 Inspector Gadget"
	file: %inspector.reb
	date: [28-Apr-2014 19-Sep-2015]
	author: "Graham Chiu"
	version: 0.0.3
	purpose: {browse an object/map/block}
	notes: {inspired by Carl's word browser}
]

resources: [
    %altjson.reb http://reb4.me/r3/altjson
    %r3-gui.reb http://www.atronixengineering.com/r3/r3-gui.r3
]

; one time download files we need
foreach [script location] resources [
    unless exists? script [write script read location]
    do script
]

collection?: function [o][
	either r: find ['object! 'block! 'map!] type?/word :o [r/1][none]
]

comment { not working ...
U: self
cnt: 0
length-of: closure [{return the max depth of o}
	o [object! block! map!]
][
	depth: 0
	words: either block? o [
		o
	] [
		words-of o
	]
	if block? words [
		++ u/cnt
		foreach word words [
			if collection? w: get word [
				length-of w
			]
		]
	]
	depth
]
}

get-selected: funct [text-list][
	v: get-face/field text-list 'text
	while [block? v][v: v/1]
	v
]

clear-lists: func [faces [block!]
][
	foreach f faces [
		set-face/field f copy [] 'data
	]
]

inspect: function [iface][
	text-lists: copy []

	expand: function [face
	][
		clear-lists next find text-lists face
		p: copy [iface]
		foreach tl text-lists [
			append p get-selected tl
			if tl = face [
				ntl: select text-lists face
				break
			]
		]
		section: get to path! p
		either r: collection? :section [
			if ntl [
				set-face/field ntl either block? section [section][words-of section] 'data
			]
			set-face tb mold r
		][
			set-face tb 
			either string? type?/word :section [
				section
			][
				mold :section
			]
		]
	]

	lay: layout [
		hgroup [
			t1: text-list (words-of iface) on-action [expand face]
			t2: text-list on-action [expand face]
			t3: text-list on-action [expand face]
			t4: text-list on-action [expand face]
			t5: text-list on-action [expand face]
			t6: text-list on-action [expand face]
			t7: text-list on-action [expand face]
			tb: area "(value)"
		]
	]
	foreach tl [t1 t2 t3 t4 t5 t6 t7][
		append text-lists get tl
	]

	view/modal lay
]

u: self
j: load-json https://www.googleapis.com/discovery/v1/apis/calendar/v3/rest

lay: layout compose [
	vgroup [
		a: area (mold j)
		hgroup [
			button "inspect" on-click [inspect u/j]
			button "close" on-action [unview/all]
		]
	]
]

go: function [][
	view/options lay [offset: 100x100]
]

p: make port! http://www.rebol.com
inspect p

