rebol [
	title: "editor"
	file: %editor.reb
	purpose: {Built in editor}
	author: [ "Based on the original Rebol2 editor, ported by Massimiliano Vessi" "Graham Chiu" ]
	version: 2.6
	date: [ 29-March-2014 8-April-2014 ]
]

if not value? 'to-text [
	either exists? %r3gui.r [do %r3gui.r][
		load-gui
	]
	; patch for caret handling in area face
	do https://raw.githubusercontent.com/saphirion/r3-gui/master/source/styles/text.r3
]

clear-face: func [ face ][set-face face copy "" ]

count-lines: funct [ text ][
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
		][ 	clear-face editingarea ]
	][
		clear-face editingarea
	]
	clear-face dirty-flag
]
	
editor: funct [
	"Rebol built-in editor"
	in-text [file! url! string! none!] "Input text, can be also a file or a url"
][
	file: none
	case [
		none? in-text [in-text: copy ""]
		all [file? in-text not exists? in-text] [write in-text ""]
		any [file? in-text url? in-text] [file: in-text in-text: to-string read file]
		true []
	]
	view/options [
		hgroup [
			openbtn: button "Open" on-action [
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
			newbtn: button "New" on-action [
				either save-changed-file dirty-flag editingarea editingarea-info [
					if none? file: request-file/title "New file name?" [exit]
					create-new-file file dirty-flag editingarea-info editingarea
				][
					if request/ask/resize "Really discard" "Lose edits?" [
						create-new-file default dirty-flag editingarea-info editingarea
					]
				]
			]
			savebtn: button "Save" on-action [
				if empty? file: get-face editingarea-info [
					if none? file: request-file/title "Choose file name and destination" [exit]
					set-face editingarea-info to-string file
				]
				either "clipboard://" = file [
					if error? try [
						write clipboard:// get-face editingarea
					] [alert "Error saving to clipboard://"]
				] [
					write to-file file get-face editingarea
				]
				clear-face dirty-flag
			]
			savenewbtn: button "Save-As" on-action [
				if none? file: request-file/title "Choose file name and destination" [file: default]
				set-face editingarea-info to-string file
				write to-file file get-face editingarea
				clear-face dirty-flag
			]
			button "Pretty" on-action [
				loc: count-lines get-face editingarea
				nloc: count-lines pretty: clean-script get-face editingarea
				either loc = nloc [
					set-face editingarea pretty
				][
					alert "Code has error and brackets do not match"
				]
			]
			button "Help" on-action [
				view [
					vgroup [
						title "Editor Shortcuts:"
						info-area {
F5 - to execute (do)^-^-^-^-^-
Ctrl-A - select all text
Ctrl-C - copy text
Crtl-N - Create a new file
Crtl-O - Open a new file
Ctrl-Q - quit
Ctrl-S - save text
Ctrl-Shift-S - save text as a new file
Ctrl-X - cut text / cut all
Ctrl-V - paste text
}
						button "Close" on-action [unview]
					]
				]
			]
			quitbtn: button "Quit" on-action [
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
			text "File:"
			editingarea-info: info (either none? file [""] [to-string file])
			dirty-flag:  text [" "]
		]
		editingarea: area in-text
		options [gob-size: 500x500 detab: true]
		on-key [
			do-actor/style face 'on-key arg 'area
			if arg/type = 'key [
				set-face dirty-flag [red "*"]
			]
		]
	] [
		shortcut-keys: [
			#"^N" [nn/actors/on-action nn none]
			#"^O" [oo/actors/on-action oo none]
			#"^S" [either (find arg/flags 'shift) [savenewbtn/actors/on-action savenewbtn none] [savebtn/actors/on-action savebtn none]]
			#"^Q" [quitbtn/actors/on-action quitbtn none]
			f5 [
				write %test.r (get-face editingarea)
				launch %test.r
			]
		]
	]
]