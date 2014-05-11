Rebol [
	Title: "Rebol Editor"
	Name: Rebol3Editor
	File: %editor.reb
	Purpose: {Built in editor}
	Author: ["Based on the original Rebol2 editor, ported by Massimiliano Vessi" "Graham Chiu"]
	Date: [29-March-2014 27-April-2014]
	Version: 0.2.91
	Type: module/mixin
	Exports: [editor ed ee de home]
]

home-dir: what-dir
history-file: join home-dir %history.reb
if not exists? history-file [write history-file ""]

rebol-header: {Rebol [
	Title: "--here--"
	File: %$file
	Date: $date 
	Author: "Graham Chiu"
]

do load-r3gui: funct [] [
	if not value? 'to-text [
		either exists? %r3-gui.r3 [
			do %r3-gui.r3
		][
			url: body-of :load-gui
			either parse url [thru 'try set url block! to end][
				parse url [word! set url url!]
				write %r3-gui.r3 read url
                do %r3-gui.r3
			][
				load-gui
			]
		]
	]
]

}

make-rebol-header: funct [editingarea editingarea-info][
	header: reword rebol-header reduce copy [
		'file last split-path to-file get-face editingarea-info
		'date now/date
	]
	set-face editingarea join header get-face editingarea
]

findstring: copy ""
last-findindex: 0

do load-r3gui: funct [] [
	if not value? 'to-text [
		either exists? %r3-gui.r3 [
			do %r3-gui.r3
		][
			url: body-of :load-gui
			either parse url [thru 'try set url block! to end][
				parse url [word! set url url!]
				write %r3-gui.r3 read url
				do %r3-gui.r3
			][
				load-gui
			]
		]
	]
]

select-word: funct [
	"Select and mark words face"
	face
	selection
][
	face/state/mark-head: head face/state/cursor
	face/state/cursor: face/state/mark-tail: tail face/state/cursor
	; update-selection face
	update-text-caret face
	update-face face
]

clear-face: func [face][set-face face copy ""]

count-lines: funct [text][
	i: 1
	parse text [any [thru newline (++ i)]]
	i
]
;; Carl and Chris

clean-script: use [out spaced indent emit-line emit-space emit load-next][
	out: none ; output text
	spaced: off ; add extra bracket spacing
	indent: "" ; holds indentation tabs

	emit-line: func [] [append out newline]

	emit-space: func [pos] [
		append out either newline = last out [indent] [
			pick [#" " ""] found? any [
				spaced
				not any [find "[(" last out find ")]" first pos]
			]
		]
	]

	emit: func [from to] [emit-space from append out copy/part from to]

	load-next: func [string [string!] /local out][
		out: transcode/next to binary! string
		out/2: skip string subtract length? string length? to string! out/2
		out
	]

	func [
		"Returns new script text with standard spacing (pretty printed)."
		script "Original Script text"
		/spacey "Optional spaces near brackets and parens"
		/gaps "Force space between two blocks"
		/local str new
	] [
		spaced: found? spacey
		gaps: either found? gaps [
			[fail]
		][
			["][" new: (remove indent emit str new append indent tab)]
		]
		clear indent
		out: append clear copy script newline
		parse script blk-rule: [
			some [
				str:
				newline (emit-line) |
				" " | "^-" |
				#";" [thru newline | to end] new: (emit str new) |
				gaps |
				[#"[" | #"("] (emit str 1 append indent tab) blk-rule |
				[#"]" | #")"] (remove indent emit str 1) break |
				skip (set [value new] load-next str emit str new) :new
			]
		]
		remove out ; remove first char
	]
]

changed-status: [red "*"]
default: %backup.reb

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

inspect: funct [iface][
	view/modal [
		hgroup [
			t1: text-list (words-of iface) on-action [
				clear-lists reduce [t2 t3 t4]
				if integer? value: :arg [
					section: get-selected face
					if word? section [
						section: iface/:section
						either object? section [
							set-face/field t2 words-of section 'data
							set-face tb "(object)"
						][
							set-face tb mold section
						]
					]
				]
			]

			t2: text-list on-action [
				clear-lists reduce [t3 t4]
				section1: get-selected t1
				section2: get-selected face
				section: iface/:section1/:section2
				either object? section [
					set-face/field t3 words-of section 'data
					set-face tb "(object)"
				][
					set-face tb mold section
				]
			]
			t3: text-list on-action [
				clear-lists reduce [t4]
				section1: get-selected t1
				section2: get-selected t2
				section3: get-selected t3
				section: iface/:section1/:section2/:section3
				either object? section [
					set-face/field t4 words-of section 'data
					set-face tb "(object)"
				][
					set-face tb mold section
				]
			]
			t4: text-list on-action [
				section1: get-selected t1
				section2: get-selected t2
				section3: get-selected t3
				section4: get-selected t4
				section: iface/:section1/:section2/:section3/:section4
				set-face tb mold section
			]
			tb: area "(value)"
		]
	]
]

; either has saved the changed file or not necessary, returning true, or false if not saved
save-changed-file: funct [dirty-flag editingarea editingarea-info][
	val: true
	if equal? changed-status get-face dirty-flag [
		view/modal [
			title "Alert! File not saved, do you want save it?"
			hpanel [
				button green "Save" on-action [
					if empty? file: get-face editingarea-info [
						either file: request-file/title "Choose file name and destination" [
							set-face editingarea-info (to-string file)
						][alert "Not saved" close-window face set 'val false]
					]
					either "clipboard://" = file [
						write clipboard:// get-face editingarea
					][
						write to-file file get-face editingarea
					]
					close-window face set 'val true
				]
				button red "No" on-action [
					set 'val false
					close-window face
				]
			]
		]
	]
	val
]

; inits fields for the new file
create-new-file: funct [file dirty-flag editingarea-info editingarea][
	if %"" = file [
		alert "Ooops .. file name is empty!"
		return
	]
	set-face editingarea-info (to-string file)
	either file? file [
		either exists? file [
			set-face editingarea to-string read file
		][clear-face editingarea]
	][
		clear-face editingarea
	]
	clear-face dirty-flag
]

goto: funct [areaface][
	view/modal [
		hpanel [
			label "Line: "
			f: field 80 on-action [
				attempt [
					nloc: to integer! get-face f
					loc: count-lines source: get-face areaface
					set-face areaface/names/scroller to-percent divide nloc loc
				]
				close-window face
			]
		]
		button "Close" on-action [close-window face]
		when [enter] on-action [focus f]
	]
]

find-next: funct [areaface] [
	either all [
		zero? last-findindex
		empty? findstring
	][
		find-text areaface
	][
		loc: count-lines source: get-face areaface
		; get the current cursor position
		if not integer? last-findindex [
			alert last-findindex
			exit
		]
		if none? at: find/tail skip source last-findindex findstring [alert join findstring " Not found" exit]
		; found the target, so calculate which line it is on
		set 'last-findindex index? at
		nloc: count-lines copy/part source at
		set-face areaface/names/scroller to-percent divide nloc loc
	]
]


comment {
text-box/state object!
make object! [
	mode: 'up
	over: false
	value: {all-text-text}
	cursor: {-the-text-after-the-cursor}
	mark-head: none
	mark-tail: none
	caret: make object! [
		caret: [[""] ""]
		highlight-start: [[""] ""]
		highlight-end: [[""] ""]
	]
	xpos: none
	validity: none
]
}


; find text from caret and set scroller to that position
find-text: funct [areaface][
	view/modal [
		hpanel [
			label "Find text" ftxt: field findstring on-action [
				do-face findbtn
			]
		]
		hgroup [
			findbtn: button "Find from Cursor" on-action [
				if error? err: try [
					select-none areaface/names/text-box/state
				][
					; probe areaface/names/text-box/state
					probe err
				]
				if empty? target: get-face ftxt [return]
				close-window face
				set 'findstring target
				loc: count-lines source: get-face areaface
				; get the current cursor position
				set 'last-findindex any [
					index? find areaface/names/text-box/state/value any [
						areaface/names/text-box/state/cursor
						areaface/names/text-box/state/value
					]
					0
				]

				if not integer? last-findindex [
					alert last-findindex
					exit
				]
				if none? at: find skip source last-findindex target [alert "Not found" exit]
				; found the target, so calculate which line it is on
				set 'last-findindex index? skip at length? target
				nloc: count-lines copy/part source at
				set-face areaface/names/scroller to-percent divide nloc loc

				areaface/names/text-box/state/mark-head: at
				areaface/names/text-box/state/cursor: areaface/names/text-box/state/mark-tail: find/tail at target
				; update-selection face
				update-text-caret areaface/names/text-box
				update-face areaface

			]

			button "Find From Top" on-action [
				if empty? target: get-face ftxt [return]
				close-window face
				set 'findstring target
				loc: count-lines source: get-face areaface
				if none? at: find/tail skip source set 'last-findindex 0 target [alert "Not found" exit]
				; found the target, so calculate which line it is on
				nloc: count-lines copy/part source set 'last-findindex at
				set-face areaface/names/scroller to-percent divide nloc loc
			]
		]
		when [enter] on-action [focus ftxt]
	]
]

editor: closure [
	"Rebol built-in editor"
	in-text [file! url! string! none!] "Input text, can be also a file or a url"
][
	case [
		url? in-text [write/append history-file join form in-text newline]
		file? in-text [
			if %./ = first split-path in-text [in-text: join home-dir in-text]
			write/append history-file rejoin ["%" in-text newline]
		]
	]

	file: none
	case [
		none? in-text [in-text: copy ""]
		all [file? in-text not exists? in-text] [write in-text copy "" file: in-text in-text: copy ""]
		any [file? in-text url? in-text] [file: in-text in-text: to-string read file]
		true []
	]
	view/options [
		hgroup [
			openbtn: button "Open" 80x10 on-action [
				either save-changed-file dirty-flag editingarea editingarea-info [
					if file: request-file [
						if none? file [file: default]
						create-new-file file dirty-flag editingarea-info editingarea
					]
				][
					if none? file: request-file/title "New file name?" [file: default]
					create-new-file file dirty-flag editingarea-info editingarea
				]
			]
			newbtn: button "New" 80x10 on-action [
				either save-changed-file dirty-flag editingarea editingarea-info [
					if none? file: request-file/title "New file name?" [exit]
					create-new-file file dirty-flag editingarea-info editingarea
				][
					if request/ask/resize "Really discard" "Lose edits?" [
						create-new-file default dirty-flag editingarea-info editingarea
					]
				]
			]
			savebtn: button "Save" 80x10 on-action [
				if empty? file: get-face editingarea-info [
					if none? file: request-file/title "Choose file name and destination" [exit]
					set-face editingarea-info to-string file
				]
				either "clipboard://" = file [
					if error? try [
						write clipboard:// get-face editingarea
					] [alert "Error saving to clipboard://"]
				] [
					write file: to-file file get-face editingarea
					;; save to dropbox
					file: last split-path file
					write join %"/c/leodata/My Dropbox/rebolsource/" file get-face editingarea
				]
				clear-face dirty-flag
			]
			savenewbtn: button "Save-As" 90x10 on-action [
				if none? file: request-file/title "Choose file name and destination" [file: default]
				set-face editingarea-info to-string file
				write to-file file get-face editingarea
				clear-face dirty-flag
			]
			prettybtn: button "Pretty" 90x10 on-action [
				scroll: get-face editingarea/names/scroller
				loc: count-lines get-face editingarea
				if error? err: try [
					nloc: count-lines pretty: clean-script get-face editingarea
					either loc = nloc [
						set-face editingarea pretty
						set-face editingarea/names/scroller scroll
					][
						alert "Code has error and brackets do not match"
					]
				][
					alert mold err
				]
			]
			runbtn: button "F5 Run" 90x10 Green on-action [
				attempt [change-dir first split-path to-file get-face editingarea-info]
				write %test.r (get-face editingarea)
				launch %test.r
			]
			button "Help" 70x10 on-action [
				view [
					vgroup [
						title "Editor Shortcuts:"
						info-area {
F3 - Find Next
F5 - to execute (do)
F6 - Run GUI demo from web
F7 - Display R3-GUI github
F8 - Insert Rebol header^-^-^-^-^-
Ctrl-A - select all text
Ctrl-C - copy text
Ctrl-F - find text
Crtl-N - Create a new file
Crtl-O - Open a new file
Ctrl-P - Prettify
Ctrl-Q - quit
Ctrl-S - save text
Ctrl-T - Top of file
Ctrl-Shift-S - save text as a new file
Ctrl-X - cut text / cut all
Ctrl-V - paste text
}
						button "Close" on-action [unview]
					]
				]
			]
			topbtn: button "Top" 60x10 on-action [set-face editingarea/names/scroller 0%]
			cdbtn: button "CD file" 70x10 on-action [
				if error? err: try [
					change-dir first split-path to-file get-face editingarea-info
					alert join "Current directory: " what-dir
				][
					alert mold err
				]
			]
			button "Home" 60x10 on-action [change-dir home-dir]
			demobtn: button "F6 Demo" 90x10 on-action [
				write %demo.r3 read https://raw.githubusercontent.com/gchiu/Rebol3/master/scripts/demo.r3
				launch %demo.r3
			]
			sourcebtn: button "F7 R3-GUI Source" on-action [browse https://github.com/saphirion/r3-gui/tree/master/source]
			quitbtn: button "Quit" 80x10 red on-action [
				either not save-changed-file dirty-flag editingarea editingarea-info [
					if request/ask/resize "Really discard" "Lose edits?" [
						unview/all
					]
				][
					unview/all
				]
			]
		]
		hgroup [
			button "cli>>" on-action [write %cli.reb "rebol [] attempt [ do %r3-gui.r3  do %editor.reb ] halt" launch %cli.reb]
			button "Clear" on-action [select-none editingarea/names/text-box/state update-face editingarea]
			button "Inspector" on-action [
				inspect editingarea
			]
			button "History" on-action [
				view/modal [
					vgroup [
						hist: text-list 300x300 on-action [

						]
						hgroup [
							button "Cancel" red on-action [close-window face]
							button "Open New" on-action [
								v: get-face hist
								if integer? :v [
									file: pick get-face/field hist 'data v
									editor load file
								]
								close-window face
							]
						]
					]
					when [enter] on-action [
						if exists? history-file [
							attempt [
								data: unique read/lines history-file
								set-face/field hist data 'data
							]
						]
					]
				]
			]
			button "Count" on-action [
				alert join "length of ciipboard:// " length? read clipboard://
			]
		]
		hgroup [
			text "File:"
			editingarea-info: info (either none? file [""] [to-string file])
			dirty-flag: text [" "]
		]
		editingarea: area in-text
		options [gob-size: 500x500 detab: true]
		on-key [
			do-actor/style face 'on-key arg 'area
			if arg/type = 'key [
				set-face dirty-flag [red "*"]
			]
		]
		info
	] [
		shortcut-keys: [
			#"^F" [find-text editingarea none]
			#"^G" [goto editingarea none]
			#"^N" [do-face newbtn]
			#"^O" [do-face openbtn]
			#"^P" [do-face prettybtn]
			#"^R" [
				if request/ask "Reload Source" "Reload Source From Disk" [
					; attempt [
					create-new-file to-file get-face editingarea-info dirty-flag editingarea-info editingarea
					;]
				]
			]
			#"^S" [do-face either find arg/flags 'shift [savenewbtn][savebtn]]
			#"^T" [do-face topbtn]
			#"^Q" [do-face quitbtn]
			f3 [
				find-next editingarea]
			f5 [
				write %test.r (get-face editingarea)
				launch %test.r
			]
			f6 [do-face demobtn]
			f7 [do-face sourcebtn]
			f8 [make-rebol-header editingarea editingarea-info]
		]
	]
]

ed: :editor
ee: does [ed %editor.reb]
de: does [do %editor.reb]
home: does [change-dir home-dir]