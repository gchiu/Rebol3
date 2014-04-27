Rebol [
	file: %inspector.reb
	date: 28-Apr-2014
	author: "Graham Chiu"
	notes: {inspired by Carl's word browser}
]

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


if not value? 'to-text [
	do funct [] [
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

view [
	a: area (to string! read %r3-gui.r3)
	button "inspect" on-click [inspect a]
]