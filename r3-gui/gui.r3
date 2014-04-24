REBOL [
	Title: "R3 GUI"
	Version: 0.2.1
	Date: 15-October-2009
	About: "Developer test GUI theme"
	Author: "Carl Sassenrath et al"
]

sum-pair: func [pair] [pair/x + pair/y]

pick1: func [cond a b] [either cond [:a] [:b]]

append2: func [list a b] [append append list a b]

merge-values: func [
	{Merge a source object's defined values into a target object.}
	obj [object!] "Target"
	src [object!] "Source"
	/force {Even if destination has a value, set it from source.}
] [
	foreach word words-of obj [
		if all [
			val: select src word
			any [force none? select obj word]
		] [
			obj/:word: src/:word
		]
	]
]
--- "R3 GUI - Debug related functions"
debug-gui: func [
	"GUI debugging function. Allows selective enabling."
	tag [word!] "Debug category"
	args [block! string!] "Values to print."
] [
	if any [find guie/debug tag find guie/debug 'all] [
		args: reduce args
		if object? args/1 [args/1: args/1/style]
		print ['-- tag args]
	]
	true
]
fail-gui: func [msg] [
	print ["^/** GUI ERROR:" reform msg]
	halt
]
warn-gui: func [msg] [
	print ["^/** GUI WARNING:" reform msg]
	none
]
assert-gui: func [cond msg] [
	unless cond [fail-gui msg]
]
remind-gui: func [body /when cond] [
	if all [
		guie/remind
		any [not when cond]
	] [
		print ["-- remind:" reform body]
	]
]
debug-face: func [
	face
	word
	block
	/local flags style
] [
	if all [
		any [
			flags: select face 'debug
			all [
				style: select guie/styles face/style
				flags: select style 'debug
			]
		]
		any [
			not block? flags
			find flags word
		]
	] [
		print ajoin ["-- debug-face[" face/style ":" word "]: " remold block]
	]
]
dump-face: func [face /indent d] [
	print [
		any [d ""]
		to-set-word face/style
		face/gob/offset
		"size:" face/gob/size
		any [select face 'name "*"]
		mold any [select face/facets 'text-body "*"]
	]
]
dump-panel: func [panel /indent d] [
	unless d [d: copy ""]
	dump-face/indent panel d
	insert d "  "
	foreach f select panel 'faces [
		either find [panel group] f/style [
			dump-panel/indent f d
		] [
			dump-face/indent f d
		]
	]
	remove/part d 2
]
--- "R3 GUI - GUI system object"
guie: context [
	debug: []
	remind: off
	styles: make map! 30
	fonts: make map! 20
	dialect: make object! 50
	actions: make object! 20
	shows: make block! 20
	drawing: make block! 40
	focal-face:
	drag:
	style:
	face:
	face-state:
	font:
	char-space:
	char-valid:
	none
	handler: none
]
guie/style: object [
	name:
	facets:
	draw:
	actors:
	options:
	parent:
	state:
	content:
	none
	faced:
	object [
		area-size: 0x0
	]
	about: "Not documented."
]
guie/face: object [
	style:
	facets:
	state:
	gob:
	options:
]
guie/face-state: object [
	mode: 'up
	over: no
	value: none
]
guie/drag: context [
	face:
	active:
	event:
	start:
	delta:
	base:
	gob:
	none
]
append guie/dialect [
	default: [set-word!]
	options: [block!]
	debug: [block!]
]
system-cursors: context [
	app-start: 32650
	hand: 32649
	help: 32651
	hourglass: 32650
	arrow: 32512
	cross: 32515
	i-shape: 32513
	no: 32648
	size-all: 32646
	size-nesw: 32643
	size-ns: 32645
	size-nwse: 32642
	size-we: 32644
	up-arrow: 32516
	wait: 32514
]
--- "R3 GUI - Style: make"
stylize: func [
	{Create one or more styles (with simple style dialect).}
	list [block!] "Format: name: [def], name: parent [def]"
	/local name parent spec style spot
] [
	assert-gui parse list [
		some [
			spot:
			set name set-word!
			set parent opt word!
			set spec block!
			(make-style to-word name parent spec)
		]
	] ["Invalid style syntax:" spot]
	debug-gui 'dialect [name]
]
make-style: funct [
	"GUI API function for creating a style."
	name [word!]
	parent [word! none!]
	spec [block! none!]
] [
	debug-gui 'make-style [name]
	parname: parent
	parent: either parent [guie/styles/:parent] [guie/style]
	assert-gui parent ["Unknown parent style for:" name]
	style: copy parent
	style/name: name
	if name <> parname [style/parent: parname]
	foreach [field code] [
		facets [make any [parent/facets object!] any [val []]]
		options [append-dialect name parent/name val]
		faced [if val [append val none] make make parent/faced style/options val]
		actors [if val [make-actors parent val]]
		draw [val]
		state [val]
		content [val]
		about [val]
		debug [extend style 'debug val val]
	] [
		val: select spec to-set-word field
		unless any [none? :val block? :val string? :val] [
			print ["Invalid style field:" field "with" mold :val]
		]
		if result: do code [style/:field: result]
	]
	merge-values style/faced style/facets
	if find select style 'debug 'style [
		print ajoin ["-- debug-style [" name "]: " mold style]
	]
	repend guie/styles [name style]
]
append-dialect: func [
	style-name [word!]
	parent [word! none!]
	block
	/local name types init options type-list
] [
	options: clear []
	type-list: clear []
	either block? :block [
		parse block [
			some [
				set name set-word!
				set types block!
				opt string!
				set init opt block!
				(
					repend options [name init]
					append type-list to-typeset types
				)
			]
		]
		type-list: copy type-list
	] [
		type-list: select guie/dialect parent
		all [
			parent
			name: select guie/styles parent
			options: name/options
		]
	]
	extend guie/dialect style-name any [type-list copy []]
	either block? options [context options] [copy options]
]
--- "R3 GUI - Style: action"
do-style: funct [
	"Call a style actor function."
	face [object!]
	act [word!] "Actor identifier"
	data {Argument to the actor (use block for multiple args).}
] [
	all [
		style: select guie/styles face/style
		actors: style/actors
		debug-gui 'do-style [act face/style select face/facets 'name]
		actor: select actors act
		actor face :data
	]
]
has-actor?: funct [
	"Return true if face's style has this actor."
	face [object!]
	act [word!] "Actor identifier"
] [
	true? select select select guie/styles face/style 'actors act
]
do-related: funct [
	{Find related faces and call their specified actor id.}
	face
	related [word! block!]
] [
	if word? related [
		if parent: parent-face? face [
			foreach fac parent/faces [do-style fac related face]
		]
	]
]
find-face-actor: funct [
	{Find the next (or prior) face that responds to the given actor.}
	face [object!]
	act [word!]
	/reverse
] [
	dir: pick [-1 1] true? reverse
	if all [
		parent: parent-face? face
		faces: find parent/faces face
	] [
		faces: skip faces dir
		forskip faces dir [
			if has-actor? first faces act [return first faces]
		]
	]
]
make-actors: funct [
	parent
	actors
] [
	map: either parent [copy parent/actors] [make map! 4]
	unless parse actors [
		any [
			here:
			set-word! block! (repend map [here/1 funct [face arg] here/2])
		]
	] [
		fail-gui ["Bad style actor:" here]
	]
	map
]
guie/style/actors: make-actors none [
	locate: [
		arg/offset
	]
	on-resize: [
		face/gob/size: arg
		face/facets/area-size: arg - 2x2
	]
	on-over: [
		face/state/mode: pick [over up] face/state/over: not not arg
		draw-face face
		none
	]
	on-get: [
		select face/state arg
	]
	on-key: [arg]
	on-scroll-event: [arg]
]
--- "R3 GUI - Face: make"
make-face: func [
	{Returns a new face based on the style with various attributes.}
	style [word!] "Name of style"
	opts [object! block! map! none!] "Optional variations of style"
	/local face styl feel tmp
] [
	styl: guie/styles/:style
	opts: make object! opts
	face: make guie/face [
		options: opts
		facets: make styl/faced opts
		state: make guie/face-state select styl 'state
	]
	face/style: style
	face/gob: make gob! reduce/no-set [data: face]
	face
]
make-options: funct [
	style [word!]
	values [block!]
] [
	assert-gui styl: guie/styles/:style ["Unknown style:" style]
	options: clear []
	foreach word words-of styl/options [
		if first values [repend options [to-set-word word first values]]
		values: next values
	]
	options
]
--- "R3 GUI - Face: misc. functions"
extend-face: func [
	face [object!]
	field [word!]
	value
] [
	append/only any [
		select face field
		extend face field make block! 1
	] value
]
sub-gob?: func [face] [face/gob/pane/1]
parent-face?: func [face] [face/gob/parent/data]
window-face?: funct [face] [
	all [
		gob: map-gob-offset/reverse face/gob 1x1
		gob: first gob
		gob/data
	]
]
focus: func [face] [
	if all [guie/focal-face guie/focal-face <> face] [
		do-style guie/focal-face 'on-focus false
		guie/focal-face: none
	]
	if face [
		do-style face 'on-focus true
		guie/focal-face: face
	]
]
unfocus: does [focus none]
next-focus: funct [face] [
	focus find-face-actor face 'on-focus
]
tall-face?: funct [
	{Returns TRUE if the face is taller than it is wide.}
	face
] [
	s: get-facet face 'size
	s/y > s/x
]
face-axis?: funct [
	"Returns face major axis as 'x or 'y."
	face
] [
	size: get-facet face 'size
	pick [x y] size/x > size/y
]
find-title-text: func [
	"Finds the title text of a panel."
	panel [object!]
] [
	foreach face panel/faces [
		if face/style = 'title [
			return get-facet face 'text-body
		]
	]
	none
]
span-colors: func [
	"Build a gradient color span based on multipliers."
	color [tuple!]
	muls [block!]
	/local out
] [
	out: make block! length? muls
	foreach v muls [
		repend out [color * v]
	]
	out
]
make-fill: funct [
	{Make a standard fill gradient to pass to DRAW GRAD-PEN.}
	base-color
	mode
] [
	span-colors base-color any [
		select [
			over [1.6 1.2]
			down [0.75 1.5]
		] mode
		[1.5 0.75]
	]
]
--- "R3 GUI - Face: access"
get-face: func [
	"Get a variable from the face state"
	face [object!]
	/field
	word [word! none!]
] [
	do-style face 'on-get any [word 'value]
]
set-face: func [
	"Set a variable in the face state, redraw the face."
	face [object!]
	value
	/no-draw "Do not redraw the face at this time"
	/field "Set only specific field"
	word [word! none!]
	/list "Value is a tagged list already"
] [
	unless list [value: reduce [any [word 'value] :value]]
	do-style face 'on-set value
	unless no-draw [draw-face face]
	if get-facet face 'relay [do-face face]
]
set-facet: func [
	{Set a named facet in face/facets. Creates it if needed.}
	face [object!]
	word [word!]
	value
] [
	extend face/facets word :value
]
get-facet: funct [
	"Get a named facet(s) from the face or style."
	face [object!]
	field [word! block!] "A word or block of words (set-words allowed)."
] [
	either word? field [
		any [
			select face/facets field
			all [
				style: select guie/styles face/style
				select style/facets field
			]
		]
	] [
		foreach word field [
			if any-word? :word [
				set :word any [
					select face/facets to-word word
					all [
						style: select guie/styles face/style
						select style/facets to-word word
					]
				]
			]
		]
	]
]
--- "R3 GUI - Face: action"
do-face: funct [
	{Evaluates the reactors (result actions) for a specific face.}
	face [object!]
	/only "Only do a specific kind of reactor"
	kind [word!]
] [
	if rel: get-facet face 'related [do-related face rel]
	if select face 'reactors [
		foreach cmd face/reactors [
			if any [not only kind = cmd/1] [
				apply/only select guie/actions cmd/1 append reduce [face get-face face] next cmd
			]
		]
	]
]
make-face-actions: func [
	reactors
] [
	foreach [name spec code] reactors [
		typesets: clear []
		foreach t spec [
			if block? t [append typesets to typeset! t]
		]
		repend guie/dialect [name copy typesets]
		repend guie/actions [name funct append copy [face value] spec code]
	]
]
append-face-act: funct [
	face
	blk
] [
	extend-face face 'reactors copy/deep blk
]
find-act: func [
	face action name
] [
	if select face 'reactors [
		foreach act face/reactors [
			if all [act/1 = action act/2 = name] [return act]
		]
	]
	none
]
exclude-faces: funct [
	sel-face name
] [
	panel: parent-face? sel-face
	foreach face panel/faces [
		if all [
			sel-face/style = face/style
			act: find-act face 'of name
		] [
			if all [
				face <> sel-face
				get-face face
			] [
				set-face face off
			]
		]
	]
]
close-win-face: func [
	"Close the parent window of a face."
	face
	/result value "Set result value (for requestors)"
] [
	if face: window-face? face [
		if result [set-face face value]
		unview face
	]
]
--- "R3 GUI - Face: draw"
draw-face: funct [
	"Given a face, generate its DRAW block."
	face [object!]
	/no-show "Do not queue it for refresh"
] [
	debug-gui 'draw [face/style]
	draw-buf: guie/drawing
	if tmp: select face 'faces [
		forall tmp [draw-face/no-show first tmp]
	]
	clear draw-buf
	style: select guie/styles face/style
	drw: any [select face 'draw select style 'draw]
	if word? d: get-facet face 'draw-mode [
		if block? d: select drw to-set-word d [drw: d]
	]
	drw: any [do-style face 'on-draw drw drw]
	if drw [
		if select face 'debug [
			insert drw: copy drw [pen red line-width 1 box]
		]
		bind drw style/facets
		bind drw face/facets
		delect/all system/dialects/draw drw draw-buf
	]
	if get-facet face 'text-style [
		repend draw-buf ['text make-text face get-facet face 'text-body]
	]
	if empty? draw-buf [exit]
	drw: copy draw-buf
	debug-face face 'redraw [drw]
	either drw/1 = 'text [
		face/gob/text: drw/2
	] [
		face/gob/draw: drw
	]
	unless no-show [show-later face]
]
--- "R3 GUI - Face: reactors"
make-face-actions [
	do: ["Evaluate in REBOL a block or file." arg [block! file! url! word!]] [
		switch type?/word arg [
			block! [do bind arg 'arg]
			word! [do-face get arg]
			file! url! [do arg]
		]
	]
	browse: ["Open web browser." arg [url! file!]] [browse arg]
	run: [{Run external program (or default app for file type).} file [file!]] [
		call to-local-file file
	]
	launch: ["Launch a script" arg [url! file!]] [
		launch arg
	]
	view: ["Change the contents of a panel." what [word!] where [word!]] [
		switch-panel get where get what none
	]
	alert: ["Popup an alert message." msg [string!] title [string! none!]] [
		request any [title "Alert"] msg
	]
	close: ["Close the current window." status [word! logic! block! none!]] [
		if block? status [status: do bind status 'status]
		close-win-face/result face :status
	]
	halt: ["Exit to console."] [halt]
	quit: ["Exit REBOL."] [quit/now]
	set: [
		"Set state of a face. Default field is VALUE."
		name [word!] field [word! none!] val [any-type!]
	] [
		set-face/field get name val field
	]
	of: ["Reset state of related faces (mutex)." name [word!]] [exclude-faces face name]
	attach: ["Set state of a face to our face's value." name [word!] field [word! none!]] [
		set-face/field get name get-face face field
	]
	submit: [
		"Submit contents to a URL or other receiver."
		dest [url! file! function! none!]
		args [block! word! none!]
	] [
		blk: get-parent-panel face
		if args [insert blk reduce/no-set args]
		switch type?/word :dest [
			function! [dest face blk]
			url! file! [
				probe to-string write dest to-binary probe mold/all blk
			]
			none! [print mold/all blk]
		]
	]
	reset: ["Reset contents to original value(s)." name [word! none!]] [
		do-style either name [get name] [face] 'on-reset none
	]
	clear: ["Clear the contents of a face." name [word! none!]] [
		do-style either name [get name] [parent-face? face] 'on-clear none
	]
	focus: ["Focus key input to a given face." name [word! none!]] [
		either name [focus get name] []
	]
	scroll: ["Tell a face to scroll based on our value." name [word! object!]] [
		if word? name [name: get name]
		do-style name 'on-scroll face
	]
	print: ["Print a value to console." data [any-type!]] [print data]
	dump: ["Print the face object on the console."] [probe face]
	moved: ["Called when face has moved (for windows)." arg [block!]] [do bind arg 'arg]
	signal: ["Send a signal to another face." id [word! integer!] who [word! none!]] [
		unless who [face: parent-face? face]
		do-style face 'on-signal id
	]
]
--- "R3 GUI - Panel: make"
make-panel: funct [
	{Create a panel from layout dialect block and options block.}
	style [word! none!]
	content [block! none!] "Contents of the panel"
	options [object! block! map! none!] "Options of the panel"
] [
	if content [
		unless options [options: copy []]
		extend options 'content content
	]
	face: make-face style options
	init-panel face
	bind-faces face
	foreach face face/faces [do-style face 'on-init none]
	foreach [t face] select face 'triggers [do-style face 'on-init none]
	do-triggers face 'load
	face
]
make-panel2: func [
	face
] [
	init-panel face
	if get-facet face 'names [bind-faces face]
	foreach face face/faces [do-style face 'on-init none]
	foreach [t face] select face 'triggers [do-style face 'on-init none]
	do-triggers face 'load
]
init-panel: funct [
	{Initialize a panel face object. Init subfaces and set size.}
	panel [object!]
] [
	no-grid: not get-facet panel 'grid
	unless block: select panel/options 'content [
		if all [
			style: select guie/styles panel/style
			block: select style 'content
			block: copy block
		] [
			foreach [d: c] block [
				if get-word? :c [
					change/only d get-facet panel to-word c
				]
			]
		]
	]
	faces: parse-panel block
	trigs: none
	remove-each face faces [
		if t: get-facet face 'triggers [
			unless trigs [trigs: make block! 2]
			repend trigs [t face]
			true
		]
	]
	if empty? faces [no-grid: true]
	extend panel 'faces faces
	extend panel 'triggers trigs
	unless no-grid [extend panel 'grid make-panel-grid panel]
	foreach face faces [
		do-style face 'on-make none
		append panel/gob face/gob
	]
	either no-grid [
		size: any [get-facet panel 'size 100x100]
	] [
		collect-sizes panel
		size: any [
			select panel/options 'size
			panel/grid/tot-sizes/1 + total-spacing? panel
		]
	]
	do-style panel 'on-resize size
	panel
]
--- "R3 GUI - Panel: access methods"
set-panel: func [
	"Set panel input face values from a block of values"
	panel [object!]
	values [block!]
] [
	foreach face select panel 'faces [
		if get-facet face 'input [
			set-face face first+ values
		]
	]
]
get-panel: funct [
	"Get panel input face values as a block."
	panel [object!]
] [
	out: make block! 4
	foreach face select panel 'faces [
		if get-facet face 'input [
			append out get-face face
		]
		if faces: select face 'faces [
			append out get-panel face
		]
	]
	foreach [trig face] select panel 'triggers [
		if get-facet face 'input [
			append out get-face face
		]
	]
	out
]
clear-panel: func [
	"Clear panel input face values."
	panel [object!]
] [
	foreach face select panel 'faces [
		if get-facet face 'input [
			do-style face 'on-clear none
		]
	]
]
get-parent-panel: funct [
	{Get panel input faces for the contextual parent panel.}
	face
] [
	while [not select face 'names] [
		unless f: parent-face? face [break]
		face: f
	]
	get-panel face
]
get-panel-var: funct [
	{Get the value of a top level panel/names local variable.}
	panel [gob!] "The window gob"
	name [word!]
] [
	all [
		p: panel/data
		p: p/faces/1
		p: p/names
		p/:name
	]
]
--- "R3 GUI - Panel: layout dialect"
parse-panel: funct [
	{Parses the panel dialect and returns a block of faces/commands.}
	block [block! none!]
] [
	unless block [return copy []]
	pane: make block! length? block
	dial: block
	opts: make block! 10
	trigs: make block! 2
	last-face: none
	forever [
		if error? err: try [
			dial: delect guie/dialect dial opts
		] [
			fail-gui ["Cannot parse the GUI dialect at:" copy/part dial 5]
		]
		unless dial [break]
		if word: first opts [
			arg: second opts
			case [
				word = 'face [
					last-face: arg
					if name [extend last-face 'name name name: none]
					append pane last-face
				]
				select guie/styles word [
					last-face: make-face word make-options word next opts
					if name [extend last-face 'name name name: none]
					append pane last-face
				]
				word = 'default [
					name: to-word arg
				]
				last-face [
					switch/default word [
						options [
							if arg [
								arg: reduce/no-set arg
								append last-face/facets arg
							]
						]
						debug [
							extend last-face 'debug any [arg [make]]
							debug-face last-face 'make last-face
						]
					] [
						append-face-act last-face opts
					]
				]
			]
		]
	]
	pane
]
--- "R3 GUI - Panel: layout"
layout-panel: funct [
	"Layout a panel by setting faces sizes and offsets."
	panel [object!] "Panel face"
] [
	unless grid: select panel 'grid [return get-facet panel 'size]
	faces: panel/faces
	row: grid/row-sizes
	col: grid/col-sizes
	margin: get-facet panel 'margin
	spacer: get-facet panel 'spacer
	packed: get-facet panel 'packed
	spacing: (margin * 2) + as-pair (grid/cols - 1 * spacer/x) (grid/rows - 1 * spacer/y)
	psize: any [
		panel/facets/size
		grid/tot-sizes/1 + spacing
	]
	extra: max 0x0 psize - grid/tot-sizes/1 - spacing
	most: max 1x1 grid/tot-sizes/3 - grid/tot-sizes/1
	ratio: extra * 100000 / most
	y: margin/y
	max-x: 0
	x: 0
	forskip faces 0 [
		if empty? row [break]
		x: margin/x
		max-y: 0
		rsize: row/3 - row/1 * ratio + 50000 / 100000 + row/1 * 0x1
		if row/2 [rsize: max rsize row/2]
		row-faces: faces
		forskip col 3 [
			unless face: first+ faces [break]
			cell-size: either fourth col [
				col/3 - col/1 * ratio / 100000 + col/1
			] [
				psize - x - margin
			]
			if col/2 [cell-size: max cell-size col/2]
			cell-size/y: rsize/y
			max-size: min-size: none
			unless size: select face/options 'size [
				size: cell-size
				max-size: get-facet face 'max-size
				min-size: get-facet face 'min-size
			]
			either any [max-size min-size] [
				if all [max-size not negative? max-size] [
					size: min max-size size
				]
				if min-size [size: max min-size size]
			] [
				size: get-facet face 'size
			]
			align: x
			switch get-facet face 'align [
				right [align: cell-size/x - size/x + x]
				center [align: cell-size/x - size/x / 2 + x]
			]
			face/gob/offset: as-pair align y
			if size/x > cell-size/x [
				print "Problem???"
			]
			do-style face 'on-resize size
			max-y: max max-y face/gob/size/y
			x: x + spacer/x + either packed [size/x] [cell-size/x]
			max-x: max x max-x
		]
		unless fourth row [
			max-y: max max-y psize/y - y - margin/y
		]
		loop offset? row-faces faces [
			face: first+ row-faces
			if x: get-facet face 'valign [
				align: 0
				switch x [
					bottom [align: max-y - face/gob/size/y]
					middle [align: max-y - face/gob/size/y / 2]
				]
				face/gob/offset/y: face/gob/offset/y + align
			]
		]
		y: y + max-y + spacer/y
		row: skip row 3
	]
	margin - spacer + as-pair max-x y
]
--- "R3 GUI - Panel: sizing"
make-panel-grid: func [
	{Create a new panel grid object. Used for row/column layout.}
	panel [object!]
] [
	make object! [
		cols: get-facet panel 'columns
		if zero? cols [cols: length? panel/faces]
		if none? cols [cols: 1]
		rows: 0
		col-sizes: copy []
		row-sizes: copy []
		tot-sizes: none
	]
]
collect-sizes: funct [
	{Calculate size limits for rows and columns. Store them in panel/grid fields.}
	panel [object!]
] [
	grid: panel/grid
	faces: panel/faces
	row: grid/row-sizes
	col: grid/col-sizes
	unless positive? grid/cols [exit]
	n: round/ceiling (length? faces) / grid/cols
	append/dup clear row 0x0 n * 3
	append/dup clear col 0x0 grid/cols * 3
	forskip faces 0 [
		forskip col 3 [
			unless face: first+ faces [break]
			nat-size: any [get-facet face 'size 0x0]
			min-size: any [get-facet face 'min-size nat-size]
			max-size: any [get-facet face 'max-size nat-size]
			row/1: max row/1 nat-size
			row/2: max row/2 min-size
			row/3: max row/3 max-size
			col/1: max col/1 nat-size
			col/2: max col/2 min-size
			col/3: max col/3 max-size
		]
		row: skip row 3
		grid/rows: grid/rows + 1
	]
	nat-size: min-size: max-size: 0x0
	forskip col 3 [
		nat-size/x: nat-size/x + col/1/x
		min-size/x: min-size/x + col/2/x
		max-size/x: max-size/x + col/3/x
	]
	row: grid/row-sizes
	forskip row 3 [
		nat-size/y: nat-size/y + row/1/y
		min-size/y: min-size/y + row/2/y
		max-size/y: max-size/y + row/3/y
	]
	grid/tot-sizes: reduce [nat-size min-size max-size]
]
resize-panel: funct [
	{Resize a panel face, layout its subfaces, render it.}
	panel [object!]
	size [pair!]
	/do-actor "Call the panel on-resize actor (for API usage)."
] [
	debug-gui 'resize-panel [panel/style select panel 'name "to" size]
	panel/gob/size: size
	panel/facets/size: size
	panel/facets/area-size: size - 2x2
	size: layout-panel panel
	if get-facet panel 'trim-size [
		panel/gob/size: size
		panel/facets/size: size
		panel/facets/area-size: size - 2x2
	]
	if do-actor [do-style panel 'on-resize size]
	draw-face/no-show panel
]
total-spacing?: funct [
	panel
] [
	margin: any [get-facet panel 'margin 0x0]
	spacer: any [get-facet panel 'spacer 0x0]
	(margin * 2) + as-pair (panel/grid/cols - 1 * spacer/x)
	(panel/grid/rows - 1 * spacer/y)
]
--- "R3 GUI - Panel: triggers"
bind-faces: funct [
	panel
] [
	names: make object! 4
	find-panel-names panel names
	extend panel 'names names
	bind-panel-acts panel names
]
find-panel-names: funct [
	panel [object!]
	names [object!]
] [
	foreach field [faces triggers] [
		foreach face select panel field [
			if item: select face 'name [
				repend names [item face]
			]
		]
	]
	foreach face panel/faces [
		if all [
			select face 'faces
			not get-facet face 'names
		] [
			find-panel-names face names
		]
	]
]
bind-panel-acts: funct [
	panel
	names [object!]
] [
	foreach field [faces triggers] [
		foreach face select panel field [
			if item: select face 'reactors [bind item names]
		]
	]
	foreach face panel/faces [
		if all [
			select face 'faces
			not get-facet face 'names
		] [
			bind-panel-acts face names
		]
	]
]
do-triggers: funct [
	"Process all WHEN panel triggers of a given type."
	panel [object!]
	id [word!] "Type of trigger"
] [
	changes: none
	foreach [trigs face] select panel 'triggers [
		if find trigs id [
			changes: true
			do-face face
		]
	]
	foreach face select panel 'faces [
		if select face 'faces [
			do-triggers face id
		]
	]
]
--- "R3 GUI - Panel: transition effects"
init-effect-fly: funct [
	panel
	effect
] [
	faces: panel/faces
	dests: make block! length? faces
	foreach face faces [
		append dests face/gob/offset
		switch effect [
			fly-right
			fly-down [face/gob/offset: negate face/gob/size]
			fly-left
			fly-up [face/gob/offset: panel/gob/size + 2]
		]
	]
	dests
]
anim-effect-fly: funct [
	panel
	effect
	dests
] [
	foreach face panel/faces [
		dest: first+ dests
		size: face/gob/size
		inc: max 1x1 dest + size / 6
		xy: face/gob/offset
		switch effect [
			fly-right [xy/y: dest/y]
			fly-left [xy/y: dest/y inc: negate inc]
			fly-down [xy/x: dest/x]
			fly-up [xy/x: dest/x inc: negate inc]
		]
		op: get pick [max min] negative? inc
		while [xy <> dest] [
			face/gob/offset: xy
			show face/gob
			wait 0.01
			xy: op dest xy + inc
		]
		face/gob/offset: dest
		show face/gob
	]
]
effect-panel: funct [
	"Display a panel transition effect."
	panel [object!] "Panel face"
	effect [word! none!] "Effect word"
] [
	switch effect [
		fly-right
		fly-left
		fly-up
		fly-down
		[dests: init-effect-fly panel effect]
	]
	draw-face/no-show panel
	switch effect [
		fly-right
		fly-left
		fly-up
		fly-down
		[anim-effect-fly panel effect dests]
	]
]
--- "R3 GUI - Panel: viewing"
view-panel: func [
	panel
	child
] [
	extend panel 'faces reduce [child]
	append clear panel/gob child/gob
	show-later panel
]
switch-panel: funct [
	"Switch contents (faces) of a panel."
	top-panel [object!] "target"
	new-panel [object!] "source"
	effect [word! none!]
] [
	size: top-panel/gob/size
	margin: get-facet top-panel 'margin
	show clear top-panel/gob
	extend top-panel 'faces reduce [new-panel]
	append top-panel/gob new-panel/gob
	new-panel/gob/offset: margin
	s: size - margin - margin
	new-panel/gob/size: new-panel/facets/size: s
	new-panel/facets/area-size: s - 2x2
	collect-sizes top-panel
	do-style top-panel 'on-resize size
	do-triggers new-panel 'enter
	effect-panel new-panel effect
]
--- "R3 GUI - Text: fonts"
guie/font: context [
	name:
	parent:
	font:
	para:
	anti-alias:
	char-size:
	none
]
fontize: funct [
	"Define text styles (from dialect)."
	spec [block!]
] [
	assert-gui parse spec [
		some [
			spot:
			set name set-word!
			set parent opt word!
			set spec block!
			(make-text-style to-word name parent spec)
		]
	] ["Invalid font syntax:" spot]
]
make-text-style: funct [
	{Define a new font style (used for text face styles).}
	font-name [word!]
	font-parent [word! none!]
	spec [block! none!]
] [
	proto: either font-parent [guie/fonts/:font-parent] [guie/font]
	unless proto [warn-gui ["Unknown parent:" font-parent "- for font:" font-name]]
	style: make proto [
		name: font-name
		parent: font-parent
		font: make any [proto/font system/standard/font] select spec to-set-word 'font
		para: make any [proto/para system/standard/para] select spec to-set-word 'para
		anti-alias: any [select spec to-set-word 'anti-alias proto/anti-alias]
		char-size: font-char-size? self
	]
	repend guie/fonts [font-name style]
]
what-font?: funct [
	{Given a name, return gui font object defined earlier. (helper)}
	name
] [
	any [
		guie/fonts/:name
		warn-gui ["missing font:" name]
		guie/fonts/base
	]
]
face-font?: funct [
	{Given a face, return gui font object defined earlier. (helper)}
	face
] [
	what-font? any [get-facet face 'text-style 'base]
]
font-font?: func [name] [select what-font? name 'font]
face-char-size?: funct [
	"Returns font char-size field. (helper)"
	face
] [
	style: face-font? face
	style/char-size
]
--- "R3 GUI - Text: key handling"
text-key-map: context [
	face: none
	key: none
	shift?: none
	chars: [
		#"^H" [remove-text-face face -1]
		#"^X" [remove-text-face face 1]
		#"^C" [copy-text-face face]
		#"^V" [insert-text-face face load-clip-text]
		#"^-"
		#"^M" [
			either get-facet face 'lines [
				insert-text-face face pick [#"^-" #"^/"] key = tab
			] [
				next-focus face
				do-face face
			]
		]
		#"^A" [select-all face]
		#"^[" [unfocus]
		#"^Q" [quit]
	]
	control: [
		home head
		end tail
		up back-para
		down next-para
		left back-word
		right next-word
		delete delete-end
	]
	words: [
		left right
		up down
		home end
		page-down page-up
		back-word next-word
		back-para next-para
		head tail [move-cursor face key 1 shift?]
		delete [remove-text-face face 1]
		delete-end [remove-text-face face 'end-line]
		deselect [select-none face/state]
		ignore [none]
	]
	no-edit: [
		#"^H" left
		#"^X" #"^C"
		#"^V" ignore
		#"^M" ignore
		delete deslect
		delete-end deselect
	]
]
do-text-key: funct [
	"Process text face keyboard events."
	face [object!]
	event [event!]
	key
] [
	text-key-map/face: face
	text-key-map/shift?: find event/flags 'shift
	if no-edit: get-facet face 'no-edit [
		key: any [select/skip text-key-map/no-edit key 2 key]
	]
	either char? key [
		text-key-map/key: key
		switch/default key text-key-map/chars [
			unless no-edit [insert-text-face face key]
		]
	] [
		if find event/flags 'control [
			key: any [select text-key-map/control key key]
		]
		text-key-map/key: key
		switch/default key text-key-map/words [return event]
	]
	none
]
--- "R3 GUI - Text: draw"
make-text: funct [
	{Make a text draw command block, with all necessary attributes.}
	face
	body
] [
	remind-gui ["making text:" face/style]
	style: face-font? face
	out: make block! 6
	foreach field [font para anti-alias] [
		if style/:field [repend out [field style/:field]]
	]
	if val: select face/state 'scroll [
		cs: negate max 0x0 face/facets/content-size - face/facets/area-size
		repend out ['scroll as-pair val/x * cs/x val/y * cs/y]
	]
	if val: select face/state 'caret [
		repend out ['caret val]
	]
	append out body
]
make-text-gob: funct [face gsize text-data] [
	gob: make gob! [offset: 0x0 size: gsize data: face]
	fstyle: face-font? face
	gob/text: append reduce [
		'font fstyle/font
		'para fstyle/para
		'anti-alias fstyle/anti-alias
		'scroll 0x0
		'caret select face/state 'caret
	] text-data
	gob
]
size-text-face: funct [face limit-size] [
	gob: make gob! [offset: 0x0 size: limit-size]
	fstyle: face-font? face
	gob/text: reduce [
		'font fstyle/font
		'para fstyle/para
		'anti-alias fstyle/anti-alias
		face/facets/text-body
	]
	size-text gob
]
font-char-size?: funct [fstyle] [
	gob: make gob! [offset: 0x0 size: 300x100]
	gob/text: reduce [
		'font fstyle/font
		'para make fstyle/para [wrap?: off]
		'anti-alias fstyle/anti-alias
		"M"
	]
	size-text gob
]
resize-text-face: funct [
	face
] [
	face/state/xpos: none
	all [
		tgob: first face/gob
		size: size-text tgob
		tgob/size/y: size/y
	]
]
--- "R3 GUI - Text: caret handling"
init-text-caret: func [face] [
	face/state/caret: context [
		caret: copy [0 0]
		start: copy [0 0]
		end: copy [0 0]
	]
]
clear-text-caret: funct [face] [
	car: face/state/caret
	car/caret/1: car/start/1: car/end/1: 0
	car/caret/2: car/start/2: car/end/2: 0
]
update-text-caret: funct [face] [
	txt: face/gob/pane/1/text
	car: select txt 'caret
	txt: back tail txt
	car/caret/1: car/start/1: car/end/1: txt
	car/caret/2: face/state/cursor
	car/start/2: face/state/mark-head
	car/end/2: face/state/mark-tail
]
goto-caret: funct [
	"Set text caret to a specific position."
	face
	pos [string! integer! none!]
] [
	unless pos [exit]
	if string? pos [pos: index? pos]
	gob: first face/gob
	car: select gob/text 'caret
	txt: back tail gob/text
	car/caret/1: car/start/1: car/end/1: txt
	car/caret/2: face/state/cursor: at face/facets/text-edit pos
	car/start/2: none
	car/end/2: none
]
caret-xy?: funct [
	"Return cursor caret offset from text gob."
	gob
] [
	any [
		all [
			car: select gob/text 'caret
			car/caret/1
			car/caret/2
			caret-to-offset gob car/caret/1 car/caret/2
		]
		0x0
	]
]
see-caret: funct [
	"Force window to scroll for caret to be seen."
	face
] [
	vgob: face/gob
	tgob: first vgob
	rowh: second face-char-size? face
	pos: caret-xy? tgob
	pos: pos - 0x2
	top: rowh - tgob/offset/y + (rowh / 2)
	bot: vgob/size/y - tgob/offset/y - (rowh / 2)
	case [
		lesser? pos/y top [
			tgob/offset: min 0x0 (pos - rowh * 0x-1)
			true
		]
		greater? pos/y bot [
			tgob/offset: min 0x0 (pos - vgob/size + rowh * 0x-1)
			true
		]
	]
]
move-caret: funct [
	"Move caret vertically. Return cursor string index."
	face
	action [word!]
] [
	tgob: sub-gob? face
	xy: caret-xy? tgob
	unless xy [return face/state/cursor]
	rowh: second face-char-size? face
	x: face/state/xpos: any [face/state/xpos xy/x]
	v: switch action [
		up [negate rowh]
		down [rowh]
		page-up [negate face/gob/size/y]
		right [face/gob/size/y]
	]
	y: xy/y + (rowh / 2) + v
	caret: offset-to-caret tgob as-pair x y
	first caret
]
--- "R3 GUI - Text: cursor movement"
guie/char-space: charset { ^-
^M/[](){}"}
guie/char-valid: complement guie/char-space
move-cursor: funct [
	{Move cursor up, down, left, right, home, end, or to a position.}
	face [object!]
	action [word!]
	count
	select? "Add to marked text (selection)"
] [
	state: face/state
	cursor: state/cursor
	sc: any [state/mark-head cursor]
	tc: none
	reset-x: true
	cursor: switch action [
		left [skip cursor negate count]
		right [skip cursor count]
		down up
		page-down page-up [
			reset-x: false
			move-caret face action
		]
		head [head cursor]
		tail [tail cursor]
		end [
			loop count [
				unless tc: find cursor newline [break]
				cursor: next tc
			]
			any [tc tail cursor]
		]
		home [
			loop count [
				unless tc: find/reverse/tail cursor newline [break]
				cursor: back tc
			]
			any [tc head cursor]
		]
		back-word [
			tc: cursor
			loop count [
				all [
					tc
					tc: find/reverse tc guie/char-valid
					tc: find/reverse tc guie/char-space
					tc: next tc
				]
			]
			any [tc head cursor]
		]
		next-word [
			tc: next cursor
			loop count [
				all [
					tc
					tc: find tc guie/char-space
					tc: find tc guie/char-valid
				]
			]
			any [tc tail cursor]
		]
		back-para [
			tc: back cursor
			loop count [
				all [
					tc
					tc: find/reverse cursor newline
					tc: find/reverse tc guie/char-space
					tc: find/reverse/tail tc newline
				]
			]
			any [tc head cursor]
		]
		next-para [
			tc: cursor
			loop count [
				all [
					tc
					tc: find cursor newline
					tc: find tc guie/char-valid
				]
			]
			any [tc tail cursor]
		]
		full-word [
			select?: true
			tc: cursor
			sc: any [
				find/reverse/tail tc guie/char-space
				head cursor
			]
			cursor: any [
				find tc guie/char-space
				tail cursor
			]
		]
	]
	if reset-x [state/xpos: none]
	either select? [
		state/mark-head: sc
		state/mark-tail: cursor
	] [
		select-none state
	]
	state/cursor: cursor
]
--- "R3 GUI - Text: editing"
insert-text-face: funct [
	{Insert text into field or area at cursor/mark position.}
	face [object!]
	text
] [
	state: face/state
	if mhead: state/mark-head [
		state/cursor: mhead
		remove/part mhead state/mark-tail
		select-none state
	]
	state/cursor: insert state/cursor text
	resize-text-face face
]
remove-text-face: funct [
	{Remove text from a field or area at cursor/mark position.}
	face [object!]
	len
	/clip
] [
	state: face/state
	either mhead: state/mark-head [
		mtail: state/mark-tail
		state/cursor: either positive? offset? mhead mtail [mhead] [mtail]
		select-none state
	] [
		mhead: state/cursor
		mtail: len
		case [
			len = 'end-line [mtail: any [find mhead newline tail mhead]]
			negative? len [state/cursor: skip mhead len]
		]
	]
	text: take/part mhead mtail
	if clip [save-clip-text text]
	resize-text-face face
]
copy-text-face: funct [
	{Copy text from a field or area at cursor/mark position.}
	face
] [
	state: face/state
	either mhead: state/mark-head [
		save-clip-text copy/part mhead state/mark-tail
	] [
		if get-facet face 'quick-copy [save-clip-text head face/cursor]
	]
]
select-all: func [
	face
] [
	face/state/mark-head: head face/state/cursor
	face/state/cursor: face/state/mark-tail: tail face/state/cursor
]
select-none: func [state] [
	state/mark-head: state/mark-tail: none
]
click-text-face: funct [
	"Make text face the focus and setup cursor."
	face
	cursor
	event
] [
	if block? cursor [cursor: first cursor]
	clear-text-caret face
	face/state/cursor: cursor
	face/state/xpos: none
	if event [
		case [
			find event/flags 'double [
				move-cursor face 'full-word 1 true
			]
			all [
				find event/flags 'shift
				face/state/mark-head
			] [
				face/state/mark-tail: cursor
			]
			true [select-none face/state]
		]
	]
	focus face
]
save-clip-text: func [txt] [
	write clipboard:// enline to-binary txt
]
load-clip-text: does [
	to-string deline read clipboard://
]
--- "R3 GUI - Event: event funcs"
base-handler: context [
	do-event: func [event] [
		print "(Missing event handler)"
		event
	]
	win-gob: none
	status: 'made
	name: 'no-name
	priority: 0
	about: "Main template for VIEW event handlers."
]
handle-events: func [
	"Adds a handler to the view event system."
	handler [block!]
	/local sys-hand
] [
	handler: make base-handler handler
	sys-hand: system/view/event-port/locals/handlers
	unless foreach [here: hand] sys-hand [
		if handler/priority > hand/priority [
			insert here handler
			break/return true
		]
	] [
		append sys-hand handler
	]
	handler/status: 'init
	debug-gui 'handler ["added for:" handler/name]
	handler
]
unhandle-events: func [
	"Removes a handler from the view event system."
	handler [object!]
] [
	remove find system/view/event-port/locals/handlers handler
	exit
]
handled-events?: func [
	{Returns event handler object matching a given name.}
	name
] [
	foreach hand system/view/event-port/locals/handlers [
		if hand/name = name [return hand]
	]
	none
]
wake-events: funct [
	"Awake the prior DO-EVENTS WAIT call."
	handler
] [
	handler/status: 'wake
]
do-events: func [
	{Waits for window events. Returns when all windows are closed.}
] [
	debug-gui 'wait "entered"
	wait system/view/event-port
	debug-gui 'wait "exited"
]
init-view-system: func [
	"Initialize the View event subsystem."
	/local ep
] [
	if system/view/event-port [exit]
	ep: open [scheme: 'event]
	system/view/event-port: ep
	ep/locals: context [handlers: copy []]
	ep/awake: funct [event] [
		either all [
			obj: event/window/data
			obj: select obj 'handler
		] [
			event: obj/do-event event
		] [
			print "A mystery GUI event?"
			halt
		]
		if obj/status = 'wake [
			obj/status: 'awake
			unhandle-events obj
			debug-gui 'handler ["Awake from WAIT:" obj/name]
			return true
		]
		tail? system/view/screen-gob
	]
]
--- "R3 GUI - Event: main handler"
gui-events: context [
	handlers: none
	over-face:
	over-where:
	drag:
	none
	handlers: context [
		down: up: context [
			down-face: none
			do-event: func [event] [
				down-face: handler/(event/type)/do-event event down-face
			]
			handler: context [
				down:
				alt-down:
				aux-down: context [
					do-event: func [event face /local where] [
						where: event/offset
						event: map-event event
						face: event/gob/data
						until [
							not all [
								event? event: do-style face 'on-click event
								face: parent-face? face
							]
						]
						if object? event [
							drag: event
							drag/start: where
						]
						face
					]
				]
				up:
				alt-up:
				aux-up: context [
					do-event: func [event down-face /local face] [
						if all [drag drag/gob] [
							show drag/gob
							remove find/last event/window drag/gob
							cursor system-cursors/arrow
						]
						event: map-event event
						face: event/gob/data
						event/offset: do-style face 'locate event
						if down-face = face [do-style down-face 'on-click event]
						if drag [
							drag/event: event
							do-style face 'on-drop drag
							drag: none
						]
						none
					]
				]
			]
		]
		alt-down: alt-up: make down []
		aux-down: aux-up: make down []
		move: context [
			do-event: func [event /local face where window] [
				either drag [
					either not drag/gob [
						drag/delta: event/offset - drag/start
						if any [drag/active not zero? drag/delta] [
							drag/active: true
							drag/event: map-event event
							do-style drag/face 'on-drag drag
						]
					] [
						if any [drag/active greater? sum-pair abs drag/start - event/offset 2] [
							drag/active: true
							window: event/window
							drag/gob/offset: drag/gob/size / -2 + event/offset
							remove find/last event/window drag/gob
							event: map-event event
							face: event/gob/data
							append window drag/gob
							show-later drag/gob
							where: do-style face 'locate event
							if all [
								any [
									face <> over-face
									where <> over-where
								]
								any [
									do-feel face 'on-drag-over [where drag/face drag/gob/data/1]
									(
										cursor system-cursors/no
										false
									)
								]
							] [
								cursor system-cursors/arrow
								if over-face [
									do-style over-face 'on-drag-over reduce [over-where no]
								]
								do-style face 'on-drag-over reduce [where yes]
							]
							over-face: face
							over-where: where
						]
					]
				] [
					event: map-event event
					face: event/gob/data
					do-style face 'on-move event
					either over-face <> face [
						if over-face [do-style over-face 'on-over none]
						over-face: face
						do-style face 'on-over event/offset
					] [
						if get-facet face 'all-over [
							do-style face 'on-over event/offset
						]
					]
				]
			]
		]
		resize: context [
			do-event: func [event] [
				do-style event/window/data 'on-resize event/offset
				show-later event/window
			]
		]
		key: key-up: context [
			do-event: func [event /local win face] [
				if face: guie/focal-face [
					until [
						event: do-style face 'on-key event
						not all [face: parent-face? face event? event]
					]
				]
			]
		]
		close: context [
			do-event: func [event] [
				do-style event/window/data 'on-close event
				unview event/window
			]
		]
		restore: offset: minimize: maximize: context [
			do-event: func [event] [
				do-style event/window/data 'on-window event
			]
		]
		scroll-line: scroll-page: context [
			do-event: func [event /local face] [
				if over-face [
					face: over-face
					until [
						event: do-style face 'on-scroll-event event
						not all [face: parent-face? face event? event]
					]
				]
			]
		]
		drop-file: context [
			do-event: func [event /local gob ofs face where] [
				event: map-event event
				face: event/gob/data
				event/offset: do-style face 'locate event
				do-feel face 'on-drop event
			]
		]
	]
	guie/handler: [
		name: 'gui
		priority: 0
		print "handler added"
		do-event: func [event] [
			debug-gui 'events [event/type event/offset]
			handlers/(event/type)/do-event event
			show-now
			none
		]
	]
]
--- "R3 GUI - View: standard Colors"
black: 0.0.0
coal: 64.64.64
gray: 128.128.128
pewter: 170.170.170
silver: 192.192.192
snow: 240.240.240
white: 255.255.255
blue: 0.0.255
green: 0.255.0
cyan: 0.255.255
red: 255.0.0
yellow: 255.255.0
magenta: 255.0.255
navy: 0.0.128
leaf: 0.128.0
teal: 0.128.128
maroon: 128.0.0
olive: 128.128.0
purple: 128.0.128
orange: 255.150.10
oldrab: 72.72.16
brown: 139.69.19
coffee: 76.26.0
sienna: 160.82.45
crimson: 220.20.60
violet: 72.0.90
brick: 178.34.34
pink: 255.164.200
gold: 255.205.40
tan: 222.184.135
beige: 255.228.196
ivory: 255.255.240
linen: 250.240.230
khaki: 179.179.126
rebolor: 142.128.110
wheat: 245.222.129
aqua: 40.100.130
forest: 0.48.0
water: 80.108.142
papaya: 255.80.37
sky: 164.200.255
mint: 100.136.116
lime: 40.200.40
reblue: 38.58.108
base-color: 200.200.200
yello: 255.240.120
--- "R3 GUI - View: popups"
request: funct [
	{Open a requestor modal dialog box. Returns result: true false none}
	title [string!]
	message [string!]
	/warn "Important message to user"
	/ask "Ask user a question (yes/no)"
	/cancel "Add a cancel button (returns as false)"
] [
	btns: make block! 4
	if ask [append btns [button "Yes" close true button "No" close false]]
	if any [warn not ask] [append btns [button "Ok" close true]]
	if cancel [append btns [button "Cancel" close false]]
	win-gob: view/modal/options compose/deep/only [
		panel 240.100.80 [title (title)]
		group [
			doc (message)
			scroller
		] options [margin: 5x5]
		group (btns)
	] [margin: 0x0 area-color: silver]
	get-face win-gob/data
]
alert: func [
	"Open an alert reqeustor."
	message [string! block!]
] [
	request/warn "Alert" reform message
]
locate-popup: funct [
	{Return the absolute coordinates for a popup below the given face.}
	face [object!]
] [
	set [gob: xy:] map-gob-offset/reverse face/gob 0x0
	face/gob/size * 0x1 + gob/offset + xy
]
--- "R3 GUI - View: show"
show-later: funct [
	item [gob! object! block! none!]
] [
	if object? item [item: select item 'gob]
	if item [
		remind-gui/when ["dup-show:" mold item] find guie/shows item
		append guie/shows item
	]
]
show-now: has [list] [
	unless empty? list: guie/shows [
		remind-gui/when ["show queue length:" length? list] (length? list) > 2
		show list
		clear list
	]
]
--- "R3 GUI - View: show"
view: funct [
	{Displays a window view from a layout block, face (panel), or low level graphics object (gob).}
	spec [block! object! gob!] "Layout block, face object, or gob type"
	/options opts [block!] "Optional features, in name: value format"
	/modal "Display a modal window (pop-up)"
	/no-wait "Return immediately - do not wait"
	/across {Use horizontal layout for top panel (rather than vertical)}
	/as-is {Use GOB exactly as passed - do not add a parent gob}
] [
	unless screen: system/view/screen-gob [return none]
	opts: make map! reduce/no-set any [opts 6]
	if modal [opts/modal: true]
	if no-wait [opts/no-wait: true]
	if across [opts/columns: 0]
	if as-is [opts/as-is: true]
	case [
		block? spec [
			win-face: make-window-panel spec opts
			win-gob: win-face/gob
		]
		object? spec []
		gob? spec [
			either as-is [win-gob: spec] [
				win-gob: make-window-gob spec opts
			]
		]
	]
	win-gob/text: any [opts/title win-gob/text "REBOL: untitled"]
	ds: screen/size - win-gob/size
	pos: any [
		opts/offset
		if last-win: last screen [
			max 0x0 last-win/size - win-gob/size / 2 + last-win/offset
		]
		'center
	]
	win-gob/offset: case [
		pair? pos [pos]
		word? pos [
			max 5x5 switch pos [
				top-left [0x0]
				top-right [ds * 1x0]
				bottom-left [ds * 0x1]
				bottom-right [ds]
				center [ds / 2]
			]
		]
		true [0x0]
	]
	opts/flags: any [opts/flags copy [resize]]
	if opts/no-resize [
		alter opts/flags 'resize
	]
	if opts/modal [
		if last screen [
			win-gob/owner: last screen
			append opts/flags [modal popup on-top no-title]
		]
		if win-face [win-face/state/value: none]
	]
	if opts/owner [
		win-gob/owner: opts/owner
	]
	if opts/handler [
		handler: handle-events opts/handler
		handler/win-gob: win-gob
		win-gob/data/handler: handler
	]
	if opts/reactors [
		if win-face [extend win-face 'reactors opts/reactors]
	]
	win-gob/flags: opts/flags
	unless win-gob = screen [append screen win-gob]
	show win-gob
	wait-now: all [
		any [modal 1 = length? screen]
		not opts/no-wait
	]
	if win-face [do-triggers win-face 'enter]
	show-now
	if wait-now [
		if handler [handler/status: 'active]
		do-events
	]
	win-gob
]
unview: funct [
	{Closes a window view. Wakes up a prior WAIT if necessary.}
	window [object! gob! word! none!] "Window face or GOB. 'all for all. none for last"
] [
	screen: system/view/screen-gob
	case [
		gob? window [win-gob: window]
		object? window [win-gob: window/gob]
		window = 'all [show clear screen exit]
		none? window [win-gob: last screen]
	]
	remove find screen win-gob
	show win-gob
	if all [
		window: win-gob/data
		handler: select window 'handler
		handler/status = 'active
	] [
		wake-events handler
	]
]
make-window-panel: funct [
	content
	opts
] [
	panel: make-panel 'backdrop content opts
	win-face: make-face 'window [size: get-facet panel 'size]
	win-face/gob/text: find-title-text panel
	win-face/gob/size: panel/facets/size
	repend win-face [
		'handler none
		'faces reduce [panel]
	]
	append win-face/gob panel/gob
	unless opts/handler [opts/handler: guie/handler]
	win-face
]
make-window-gob: funct [
	spec [gob!]
	opts [map!]
] [
	either opts/as-is [
		window: spec
	] [
		spec/offset: 0x0
		window: make gob! [size: spec/size text: "Window"]
		append window spec
	]
	if any [
		opts/color
		opts/draw
	] [
		spec: copy [
			size: window/size
			offset: 0x0
		]
		if opts/color [append spec [color: opts/color]]
		if opts/draw [append spec [draw: opts/draw]]
		insert window make gob! spec
	]
	unless opts/handler [opts/handler: gob-handler]
	window/data: make object! [
		handler: none
		options: opts
	]
	window
]
gob-handler: [
	name: 'gob
	about: "Low level handler for VIEW of simple GOBs."
	priority: 50
	do-event: func [event] [
		print ["view-event:" event/type event/offset]
		either switch event/type [
			close [true]
			key [event/key = escape]
		] [
			unview event/window
		] [
			show event/window
		]
		none
	]
]
--- "REBOL 3 GUI - Text font definitions"
fontize [
	base: [
		font: [
			color: black
			size: 12
			name: "Arial"
		]
		anti-alias: off
	]
	bold: base [
		font: [
			style: 'bold
		]
	]
	field: base [
		para: [
			wrap?: false
			valign: 'middle
		]
		anti-alias: off
	]
	area: base [
		para: [
			wrap?: true
		]
	]
	info: field [
		para: [
			valign: 'top
		]
		anti-alias: on
	]
	info-area: info [
		para: [
			wrap?: true
		]
	]
	head-bar: [
		font: [
			color: black
			size: 12
			style: 'bold
			name: "Arial"
		]
		para: [
			origin: 4x0
			valign: 'middle
		]
		anti-alias: on
	]
	centered: base [
		para: [
			margin: 0x0
			origin: 0x0
			align: 'center
			valign: 'middle
		]
	]
	button: centered [
		font: [
			color: snow
			style: 'bold
			size: 14
			shadow: 2x2
		]
		para: [
			wrap?: false
		]
		anti-alias: on
	]
	title: base [
		font: [
			size: 16
			style: 'bold
		]
		para: [
			origin: 0x0
			wrap?: false
			align: 'left
			valign: 'top
		]
		anti-alias: on
	]
	label: base [
		font: [
			style: 'bold
			align: 'right
		]
		para: [
			origin: 4x2
		]
		anti-alias: on
	]
	radio: base [
		para: [
			origin: 18x0
			valign: 'middle
		]
	]
	list-item: base [
		para: [
			wrap?: false
		]
		anti-alias: off
	]
	code: base [
		font: [
			name: "courier new"
		]
		anti-alias: off
	]
]
--- "REBOL 3 GUI Styles - Panels and groups"
stylize [
	window: [
		about: "A special style used by system for window panels."
		facets: [
			area-size: 1x2
		]
		actors: [
			on-resize: [
				if face/gob/1 [
					resize-panel face/gob/1/data arg
				]
			]
			on-window: [
				if arg/type = 'offset [do-face/only face 'moved]
			]
			on-set: [face/state/value: arg/2]
			on-get: [face/state/value]
		]
	]
	face: [
		about: "A special style used passing pre-built faces."
		options: [
			content: [object!]
			size: [pair!]
		]
	]
	when: [
		about: "A special style for defining panel triggers."
		options: [
			triggers: [block!] "Trigger words"
		]
	]
	data: when [
		about: "A special style for storing data."
		options: [
			block: [block!] "Block will REDUCE immediately"
		]
		faced: [
			triggers: [load]
		]
		actors: [
			on-init: [
				face/state/value: reduce face/options/block
			]
		]
	]
	embed: data [
		about: {A special style for including data values in SUBMIT.}
		facets: [
			input: true
		]
	]
	plane: [
		about: {A lean sub-panel used as a scroll frame. No internal resizing.}
		facets: [
			size: 400x200
			max-size: 4000x3000
			min-size: 30x30
		]
		options: [
			size: [pair!]
			panel: [object!]
		]
		actors: [
			on-make: [
				if panel: get-facet face 'panel [
					view-panel face panel
				]
			]
			on-attach: [
				extend-face face 'attached arg
			]
			on-over: [none]
			on-scroll: [
				pgob: face/gob
				unless gob: sub-gob? face [exit]
				size: negate max 0x0 gob/size - 0x0
				offset: size * get-face arg
				axis: face-axis? arg
				xy: gob/offset
				xy/:axis: offset/:axis
				gob/offset: xy
				show-later face
				true
			]
			on-scroll-event: [
				dy: none
				switch arg/type [
					scroll-line [dy: arg/offset/y / -30]
					scroll-page [dy: negate arg/offset/y]
				]
				if all [dy bars: select face 'attached] [
					bump-scroll first bars dy
				]
				none
			]
		]
	]
	group: [
		about: {For spaced groups. No background or borders. Default horizontal.}
		facets: [
			size: 400x200
			max-size: none
			min-size: 30x30
			margin: 0x0
			spacer: 5x5
			columns: 0
			grid: true
			trim-size: true
		]
		options: [
			content: [block!]
			columns: [integer!]
			size: [pair!]
		]
		actors: [
			on-make: [
				make-panel2 face
			]
			on-over: [none]
			on-attach: [
				extend-face face 'attached arg
				update-scrollers face face/gob
			]
			on-scroll: [
				gob: face/gob
				pgob: face/gob/parent
				size: negate max 0x0 gob/size - 0x0
				offset: size * get-face arg
				axis: face-axis? arg
				xy: gob/offset
				xy/:axis: offset/:axis
				gob/offset: xy
				show-later face
				true
			]
			on-set: [
				if arg/1 = 'value [set-panel face arg/2]
			]
			on-get: [
				get-panel face
			]
			on-clear: [
				clear-panel face
			]
			on-resize: [
				resize-panel face arg
				update-scrollers face face/gob
			]
		]
	]
	tight: group [
		about: {Tightly spaced and packed group. No background or borders. Horizontal default.}
		facets: [
			spacer: 0x0
			packed: true
		]
	]
	panel: group [
		about: "For grouping faces with a background and borders."
		facets: [
			area-color: gold
			edge-color: coal
			margin: 10x10
			spacer: 5x5
			columns: 1
			trim-size: false
		]
		options: [
			content: [block! object!]
			columns: [integer!]
			size: [pair!]
			area-color: [tuple!]
		]
		faced: [
			area-fill:
		]
		draw: [
			pen edge-color
			line-width 1.8
			grad-pen cubic 1x1 0 200 area-fill
			box 1x1 area-size 3
		]
		actors: [
			on-draw: [
				face/facets/area-fill: span-colors get-facet face 'area-color [1 2.0 0.9]
				arg
			]
		]
	]
	backdrop: panel [
		draw: [
			pen false
			grad-pen cubic 1x1 0 200 area-fill
			box 0x0 size
		]
	]
	pad: [
		about: "Padding for blank spaces."
		facets: [
			size: 10x10
			min-size: 1x1
			max-size: 1000x1000
		]
		options: [
			size: [pair!]
		]
	]
]
--- "REBOL 3 GUI Styles - Primary types of buttons"
stylize [
	clicker: [
		about: {Single-action button without text. Basis of other styles.}
		facets: [
			size: 28x28
			area-color: 60.70.150
			edge-color: 96.96.96
		]
		options: [
			size: [pair!]
			area-color: [tuple!]
		]
		faced: [
			area-size:
			pen-color:
			area-fill:
		]
		draw: [
			pen pen-color
			line-width 1.5
			grad-pen cubic 1x1 0 40 area-fill
			box 1x1 area-size 3
		]
		actors: [
			on-draw: [
				face/facets/area-fill: make-fill face/facets/area-color face/state/mode
				color: get-facet face 'edge-color
				if face/state/mode = 'over [color: color / 2]
				face/facets/pen-color: color
				arg
			]
			on-click: [
				face/state/mode: arg/type
				draw-face face
				if arg/type = 'up [do-face face]
				none
			]
		]
	]
	button: clicker [
		about: "Single action button with text."
		facets: [
			size: 100x28
			max-size: 200x28
			min-size: 50x24
			text-body: "Button"
			text-style: 'button
		]
		options: [
			text-body: [string! block!]
			area-color: [tuple!]
			size: [pair!]
			wide: [percent!]
		]
	]
	toggle: button [
		about: "Dual action button with text and LED indicator."
		facets: [
			led-colors: reduce [green coal]
			text-body: "Toggle"
		]
		options: [
			text-body: [string! block!]
			area-color: [tuple!]
			orig-state: [logic!]
			size: [pair!]
			wide: [percent!]
		]
		faced: [
			led-color: none
		]
		draw: [
			pen pen-color
			line-width 1.5
			grad-pen cubic 1x1 0 40 area-fill
			box 1x1 area-size 3
			line-width 0.4
			fill-pen led-color
			box 7x7 (area-size - 5 * 0x1 + 12x0) 2.5
		]
		actors: [
			on-init: [
				face/state/value: true? get-facet face 'orig-state
			]
			on-set: [
				if arg/1 = 'value [face/state/value: true? arg/2]
			]
			on-draw: [
				face/facets/area-fill: make-fill face/facets/area-color face/state/mode
				color: get-facet face 'edge-color
				if face/state/mode = 'over [color: color / 2]
				face/facets/pen-color: color
				face/facets/led-color: pick get-facet face 'led-colors not not face/state/value
				arg
			]
			on-click: [
				if arg/type = 'down [
					set-face face not face/state/value
					do-face face
				]
				none
			]
		]
	]
	check: toggle [
		facets: [
			size: 300x10
			max-size: 2000x22
			led-colors: reduce [leaf 50.50.50.200]
			text-style: 'radio
			auto-wide: 20x4
			text-body: "Check"
		]
		draw: [
			pen pen-color
			line-width 1.5
			fill-pen snow
			translate (as-pair 3 area-size/y - 11 / 2)
			box 0x0 11x11
			line-width 2
			pen led-color
			fill-pen led-color
			polygon 1x4 5x10 12x-1 5x6 1x3
			reset-matrix
		]
		actors: [
			on-make: [
				if all [
					s: get-facet face 'auto-wide
					not select face/options 'size
				] [
					set-facet face 'size s + size-text-face face 2000x100
				]
			]
		]
	]
	radio: check [
		facets: [
			related: 'on-mutex
			text-body: "Radio"
		]
		draw: [
			pen pen-color
			line-width 1.5
			fill-pen snow
			translate (as-pair 3 area-size/y - 10 / 2)
			circle 5x5 5.6
			line-width 0.1
			fill-pen led-color
			circle 5x5 2.5
			reset-matrix
		]
		actors: [
			on-click: [
				if arg/type = 'down [
					set-face face true
					do-face face
				]
				none
			]
			on-mutex: [
				if all [
					face <> arg
					face/state/value
					all [
						not find select face 'reactors 'of
					]
				] [
					set-face face false
				]
			]
		]
	]
	arrow-button: clicker [
		about: "Single action button with arrow (but no text)."
		facets: [
			size: 22x22
			arrow-color: snow
		]
		options: [
			size: [pair!]
			area-color: [tuple!]
			angle: [integer!]
		]
		faced: [
			angle: 0
			center-point:
		]
		draw: [
			pen pen-color
			line-width 1.5
			grad-pen cubic 1x1 0 40 area-fill
			box 1x1 area-size 3
			transform angle 0.7 0.7 0x0 center-point
			pen arrow-color
			line-width 2.7
			line-cap rounded
			line -6x5 0x-5 6x5 0x-1 -6x5
		]
		actors: [
			on-resize: [
				set-facet face 'area-size arg - 2
				face/facets/center-point: arg - 2 / 2
			]
		]
	]
]
--- "REBOL 3 GUI Styles - Bars of various kinds"
clip-face-val: funct [face] [
	v: face/state/value
	face/state/value: either percent? v [min 100% max 0% v] [
		to percent! any [v 0]
	]
]
set-knob: funct [face] [
	v: clip-face-val face
	size: get-facet face 'area-size
	unless pair? size [fail-gui ["area-size not set for" face/style]]
	xxis: pick [x y] size/y > size/x
	btn-size: get-facet face 'btn-size
	d: face/state/delta
	face/state/delta: d: either percent? d [min 100% max 0% d] [10%]
	ksize: max 10x10 size - (2 * btn-size) - 2 * d
	ksize/:xxis: size/:xxis - 2
	face/facets/knob-size: ksize
	xy: size - (2 * btn-size) - 2 - ksize * v + btn-size
	xy/:xxis: 0
	face/facets/knob-xy: xy
]
sense-scroll: funct [
	{Map scroller offset to sub-part index (1: knob 2: btn1 3: btn2)}
	face offset
] [
	get-facet face [area-size: btn-size: knob-size: knob-xy:]
	axis: face-axis? face
	n: offset/:axis
	k: knob-xy/:axis
	case [
		n < btn-size/:axis [2]
		n > (area-size/:axis - btn-size/:axis) [3]
		n < k [4]
		n > (k + knob-size/:axis) [5]
		true [1]
	]
]
bump-scroll: funct [
	{Increment or decrement the face value by the face delta.}
	face
	num [number!] "Delta multiplier"
] [
	d: face/state/delta * num
	set-face face max 0% min 100% face/state/value + d
	do-face face
]
init-drag: func [
	{Initialize drag operation, reusing a common drag object.}
	face
	spot "Initial condition (initial value, offset, etc)."
] [
	guie/drag/face: face
	guie/drag/base: any [spot face/gob/offset]
	guie/drag/gob: none
	guie/drag/delta: 0x0
	draw-face face
	guie/drag
]
calc-scroll: funct [
	{Return scroll or delta percentages from a face and its sub-gob.}
	face
	gob [gob!]
	axis [word!] "Scroll direction"
	/delta "return the scroller delta (page size)"
] [
	visible: face/gob/size/:axis
	full: gob/size/:axis
	to-percent min 1 either delta [
		visible / max 1 full
	] [
		abs gob/offset/:axis / max 1 full - visible
	]
]
update-scrollers: funct [
	face
	gob
	/reset
] [
	data: reduce [
		calc-scroll/delta face gob 'x
		calc-scroll/delta face gob 'y
	]
	if faces: select face 'attached [
		if bar: first faces [
			do-style bar 'on-delta data
			set-face bar calc-scroll face gob 'y
		]
		if bar: second faces [
			do-style bar 'on-delta data
			set-face bar calc-scroll face gob 'x
		]
	]
]
stylize [
	box: [
		about: "Simple rectangular box."
		facets: [
			size: 100x100
			max-size: 1000x1000
			area-color: snow
		]
		options: [
			size: [pair!]
			area-color: [tuple!]
		]
		draw: [
			pen (area-color - 16)
			line-width 1.5
			fill-pen area-color
			box 1x1 area-size 3
		]
	]
	bar: box [
		about: "Simple horizontal divider bar."
		facets: [
			size: 20x5
			max-size: 1000x5
			area-color: 0.0.0.200
		]
	]
	div: bar [
		about: "Simple vertical divider bar."
		facets: [
			size: 5x20
			max-size: 5x1000
		]
	]
	progress: [
		about: "Progress bar."
		facets: [
			size: 200x22
			max-size: 1000x22
			edge-color: 96.96.96
			area-color: 80.80.80.128
			area-fill: span-colors area-color [0.3 0.5 1]
		]
		options: [
			bar-color: [tuple!]
			size: [pair!]
		]
		faced: [
			bar-color: teal
			bar-size: 1x1
			bar-fill:
		]
		draw: [
			pen edge-color
			line-width 1.5
			grad-pen 1x1 0 20 90 area-fill
			box 1x1 area-size 3
			grad-pen 1x1 0 20 90 bar-fill
			box 1x1 bar-size 3
		]
		actors: [
			on-make: [
				face/facets/bar-fill: span-colors get-facet face 'bar-color [1.0 1.5 0.6]
			]
			on-set: [
				face/state/value: arg/2
				v: clip-face-val face
				remind-gui "change above line to take the arg value"
				size: get-facet face 'area-size
				face/facets/bar-size: as-pair v * size/x size/y
			]
		]
	]
	slider: [
		about: "Slide-bar for numeric input (0% - 100%)"
		facets: [
			size: 200x22
			max-size: 1000x22
			edge-color: 96.96.96
			area-color: 80.80.80
			area-fill: span-colors area-color [0.5 2.0]
			relay: true
			input: true
		]
		options: [
			size: [pair!]
			knob-color: [tuple!]
		]
		faced: [
			area-size: none
			knob-color: red
			knob-xy:
			bias-xy: 6x0
		]
		draw: [
			pen edge-color
			line-width 0.4
			grad-pen 1x1 0 4 90 area-fill
			box 1x1 area-size 3
			line-width 1.5
			fill-pen knob-color
			translate knob-xy
			triangle -6x16 0x2 6x16
		]
		actors: [
			on-resize: [
				face/gob/size: arg
				face/facets/area-size: arg - 2 * 1x0 + 0x6
				do-style face 'on-update none
			]
			on-update: [
				val: clip-face-val face
				bias: face/facets/bias-xy
				size: face/facets/area-size - bias - bias
				face/facets/knob-xy: val * size * 1x0 + bias
			]
			on-offset: [
				bias: face/facets/bias-xy
				arg: max 0x0 arg - bias
				size: face/facets/area-size - bias - bias
				axis: face-axis? face
				face/state/value: val: min 100% max 0% to-percent arg/:axis / size/:axis
				face/facets/knob-xy: val * size * 1x0 + bias
			]
			on-click: [
				if arg/type = 'down [drag: init-drag face arg/offset]
				do-style face 'on-offset arg/offset
				if arg/type = 'down [
					draw-face face
					return drag
				]
				do-face face
				none
			]
			on-drag: [
				do-style face 'on-offset arg/delta + arg/base
				draw-face face
				do-face face
			]
			on-get: [
				if arg = 'value [face/state/value]
			]
			on-set: [
				if all [
					'value = first arg
					number? second arg
				] [face/state/value: second arg]
				do-style face 'on-update none
			]
		]
	]
	scroller: [
		about: "Scroll bar with end arrows."
		facets: [
			size: 22x22
			max-size: -1x-1
			min-size: 22x22
			btn-size: 18x18
			all-over: true
			relay: true
			back-color: 0.0.0.128
			area-color: 200.0.0
			edge-color: black
			arrow-color: snow
			area-fill: span-colors area-color [1.0 0.5]
			over-fill: span-colors area-color [2.0 1.0]
			down-fill: span-colors area-color [0.5 1.0]
			btn-fill: reduce [area-fill area-fill area-fill]
		]
		options: [
			size: [pair!]
		]
		state: [
			value: 0%
			delta: 10%
		]
		faced: [
			max-size:
			area-size:
			knob-xy:
			knob-size:
			knob-base:
			btn-xy:
			btn-fill:
			angles:
			none
		]
		draw: [
			line-width 0.01
			fill-pen back-color
			box 0x0 (area-size - 1) 3
			pen edge-color
			line-width 1.5
			grad-pen cubic (knob-xy - 1) 0 btn-size/x btn-fill/1
			box (knob-xy + 1) (knob-xy + knob-size) 3
			grad-pen cubic 1x1 0 btn-size/x btn-fill/2
			box 1x1 btn-size 3
			grad-pen cubic (btn-xy - 1) 0 btn-size/x btn-fill/3
			box (btn-xy - 1) (btn-xy + btn-size - 2) 3
			transform angles/1 0.6 0.6 0x0 9x9
			pen arrow-color
			line-width 2.7
			line-cap rounded
			line -6x5 0x-5 6x5 0x-1 -6x5
			reset-matrix
			transform angles/2 0.6 0.6 0x0 (btn-xy - 2 + 9x9)
			pen arrow-color
			line-width 2.7
			line-cap rounded
			line -6x5 0x-5 6x5 0x-1 -6x5
		]
		actors: [
			on-init: [
				if target: find-face-actor/reverse face 'on-scroll [
					append-face-act face reduce ['scroll target]
					do-style target 'on-attach face
				]
			]
			on-resize: [
				size: arg
				z: pick [x y] size/y > size/x
				size/:z: 22
				face/gob/size: size
				face/facets/angles: pick [[0 180] [270 90]] size/y > size/x
				btn-size: get-facet face 'btn-size
				face/facets/size: size
				face/facets/area-size: size - 2
				face/facets/btn-xy: size - 2 - btn-size
				set-knob face
			]
			on-over: [
				face/state/over: not not arg
				area-fill: get-facet face 'area-fill
				fills: reduce [area-fill area-fill area-fill]
				all [
					arg
					n: sense-scroll face arg
					n < 4
					fills/:n: get-facet face 'over-fill
				]
				face/facets/btn-fill: fills
				draw-face face
			]
			on-set: [
				foreach [word val] arg [
					switch word [
						value [face/state/value: val]
						delta [face/state/delta: val]
					]
				]
				set-knob face
			]
			on-reset: [
				face/state/value: 0%
				face/state/delta: 10%
				set-knob face
			]
			on-click: [
				if arg/type = 'down [
					switch sense-scroll face arg/offset [
						1 [return init-drag face face/state/value]
						2 4 [bump-scroll face -1]
						3 5 [bump-scroll face 1]
					]
				]
				none
			]
			on-drag: [
				span: max 1x1 face/facets/btn-xy - face/facets/knob-size - get-facet face 'btn-size
				axis: face-axis? face
				face/state/value: max 0% min 100% arg/base + to-percent arg/delta/:axis / span/:axis
				set-knob face
				draw-face face
				do-face face
			]
			on-delta: [
				face/state/delta: pick arg 'x = face-axis? face
				if get-facet face 'area-size [
					set-knob face
					draw-face face
				]
			]
			on-scroll-event: [
				dy: none
				switch arg/type [
					scroll-line [dy: arg/offset/y / -30]
					scroll-page [dy: negate arg/offset/y]
				]
				if dy [bump-scroll face dy]
				none
			]
		]
	]
]
--- "REBOL 3 GUI Styles - Text fields and areas"
stylize [
	text: [
		about: "Simple text without background."
		facets: [
			size: 200x20
			max-size: 2000x20
			text-body: ""
			text-style: 'base
		]
		options: [
			text-body: [string! block!]
			text-color: [tuple!]
			size: [pair!]
		]
	]
	title: text [
		about: "Title text style without background."
		facets: [
			text-style: 'title
		]
	]
	head-bar: text [
		about: "Boxed text bar for headings."
		facets: [
			size: 100x24
			max-size: 2000x24
			area-color: 255.255.255.100
			edge-color: 80.80.80.100
			text-style: 'head-bar
		]
		options: [
			text-body: [string! block!]
			area-color: [tuple!]
			size: [pair!]
		]
		draw: [
			pen edge-color
			line-width 1.6
			fill-pen area-color
			box 1x1 (area-size - 1) 2
		]
		actors: [
			on-set: [
				face/facets/text-body: form any [arg/2 ""]
				show-later face
			]
		]
	]
	label: text [
		about: "Label text without background."
		facets: [
			size: 100x20
			max-size: size
			text-style: 'label
		]
	]
	text-area: [
		about: {General text input area, editable, scrollable, without background.}
		facets: [
			size: 300x200
			max-size: 2000x2000
			min-size: 100x12
			text-edit: ""
			lines: true
			text-style: 'area
		]
		options: [
			size: [pair!]
			text-edit: [string! block!]
		]
		state: [
			cursor:
			mark-head:
			mark-tail:
			caret: none
			xpos: none
		]
		actors: [
			on-make: [
				face/state/value: face/facets/text-edit: copy face/facets/text-edit
				init-text-caret face
				append face/gob gob: make-text-gob face face/facets/size - 2 "empty"
				face/gob/size: gob/size
				do-style face 'on-update none
			]
			on-attach: [
				extend-face face 'attached arg
				update-scrollers face sub-gob? face
			]
			on-update: [
				gob: sub-gob? face
				change back tail gob/text face/facets/text-edit
			]
			on-resize: [
				face/gob/size: arg
				face/facets/area-size: arg - 2
				gob: sub-gob? face
				size: arg - 2
				unless get-facet face 'lines [size/x: 10000]
				gob/size: size
				gob/size: max size size-text gob
			]
			on-set: [
				switch arg/1 [
					value [
						face/facets/text-edit: reform any [face/state/value: arg/2 ""]
						clear-text-caret face
						do-style face 'on-update none
						do-style face 'on-resize face/gob/size
					]
					locate [
						goto-caret face arg/2
						see-caret face
						show-later face
					]
				]
				update-scrollers face sub-gob? face
			]
			on-get: [
				if arg = 'value [
					face/facets/text-edit
				]
			]
			on-clear: [
				clear face/facets/text-edit
				show-later face
			]
			on-scroll: [
				gob: sub-gob? face
				size: negate max 0x0 gob/size - face/gob/size
				offset: size * arg/state/value
				axis: face-axis? arg
				xy: gob/offset
				xy/:axis: offset/:axis
				gob/offset: xy
				show-later face
				true
			]
			on-key: [
				if arg/type = 'key [
					do-text-key face arg arg/key
					update-text-caret face
					see-caret face
					update-scrollers face sub-gob? face
					show-later face
				]
			]
			on-scroll-event: [
				dy: none
				switch arg/type [
					scroll-line [dy: arg/offset/y / -30]
					scroll-page [dy: negate arg/offset/y]
				]
				if all [dy bars: select face 'attached] [
					bump-scroll first bars dy
				]
				none
			]
			on-click: [
				either arg/type = 'down [
					if cur: offset-to-caret sub-gob? face arg/offset [
						click-text-face face cur arg
						return init-drag face arg/offset
					]
					none
				] [arg]
			]
			on-drag: [
				if all [
					arg/event/gob = sub-gob? face
					cur: offset-to-caret sub-gob? face arg/event/offset
				] [
					state: face/state
					unless state/mark-head [state/mark-head: state/cursor]
					state/mark-tail: state/cursor: first cur
					update-text-caret face
					see-caret face
					update-scrollers face sub-gob? face
					show-later face
				]
			]
			on-focus: [
				either arg [
					unless face/state/cursor [face/state/cursor: face/facets/text-edit]
					update-text-caret face
				] [
					face/state/cursor: none
					clear-text-caret face
				]
				show-later face
				none
			]
			on-reset: [
				txt: face/gob/pane/1/text
				clear last txt
				show-later face
				none
			]
		]
	]
	text-box: text-area [
		about: "Text area with background box."
		facets: [
			area-color: snow
		]
		options: [
			size: [pair!]
			text-edit: [string! block!]
			area-color: [tuple!]
		]
		draw: [
			pen (area-color - 48)
			line-width 1.5
			fill-pen area-color
			box 0x0 area-size 2
		]
	]
	field: text-box [
		about: {Single line text input, editable, with background box.}
		facets: [
			size: 100x24
			max-size: 2000x24
			min-size: 20x12
			area-size: none
			area-color: snow
			lines: false
			text-style: 'field
			input: true
		]
	]
	area: tight [
		about: {Multi-line text input, editable, scrollable, with background and scrollbars.}
		facets: [
			size: 300x200
			spacer: -2x-2
			input: true
		]
		options: [
			text-edit: [string! block!]
			area-color: [tuple!]
			size: [pair!]
		]
		content: [
			text-box :text-edit :area-color
			scroller
		]
		actors: [
			on-set: [
				do-style face/faces/1 'on-set arg
				if arg/1 = 'value [
					set-face face/faces/2 0%
				]
			]
			on-get: [
				get-face face/faces/1
			]
		]
	]
	code-area: area [
		about: {Multi-line code input, editable, scrollable, with background and scrollbars.}
		content: [
			text-box :text-edit :area-color options [text-style: 'code]
			scroller
		]
	]
	info: text-area [
		about: "Text information fields, non-editable."
		facets: [
			size: 100x20
			max-size: 2000x20
			min-size: 20x12
			lines: false
			no-edit: true
			text-style: 'info
			edge-color: 100.100.100.200
			area-color: 240.240.240.150
		]
		options: [
			size: [pair!]
			text-edit: [string! block!]
		]
		draw: [
			pen edge-color
			line-width 1.5
			fill-pen area-color
			box 1x1 (area-size - 0) 1
		]
	]
	info-area: tight [
		about: {Multi-line text info, non-editable, scrollable, scrollbars.}
		facets: [
			size: 300x100
			spacer: -2x-2
			text-style: 'info-area
		]
		options: [
			text-edit: [string! block!]
			area-color: [tuple!]
			size: [pair!]
		]
		content: [
			info :text-edit options [
				size: 300x100
				max-size: 2000x2000
			]
			scroller
		]
		actors: [
			on-set: [
				do-style face/faces/1 'on-set arg
				if arg/1 = 'value [
					set-face face/faces/2 0%
				]
			]
			on-get: [
				get-face face/faces/1
			]
		]
	]
]
--- "REBOL 3 GUI Styles - Text fields and areas"
temp-ctx-doc: context [
	space: charset " ^-"
	nochar: charset " ^-^/"
	para-start: charset [#"!" - #"~"]
	emit-para: funct [
		"Emit a paragraph with minor markup."
		out [block!] "A richtext block"
		para "marked-up string"
	] [
		while [all [para not tail? para]] [
			either spot: find para #"<" [
				append out copy/part para spot
				para: either end: find/tail spot #">" [
					switch copy/part spot end [
						"<b>" [append out 'bold]
						"</b>" [append out [bold off]]
						"<i>" [append out 'italic]
						"</i>" [append out [italic off]]
						"<em>" [append out [bold italic]]
						"</em>" [append out [bold off italic off]]
					]
					end
				] [
					next spot
				]
			] [
				append out copy/part para tail para
				para: none
			]
		]
		append out [newline newline]
	]
	set 'parse-doc funct [
		{Parse the doc string input. Return rich-text output.}
		text [string!]
	] [
		text: trim/auto detab text
		if newline <> last text [append text newline]
		out: make block! (length? text) / 20 + 1
		emit: func [data] [repend out data]
		s: none
		para: make string! 20
		ft: what-font? 'title
		fb: what-font? 'base
		fc: what-font? 'code
		emit [
			'font fb/font
			'para fb/para
			'anti-alias ft/anti-alias
		]
		parse/all text [
			some [
				"###" break
				|
				"===" copy s to newline skip (
					emit [
						'font ft/font
						s
						'drop
						'font fb/font
						'newline 'newline
					]
				)
				|
				some [copy s [para-start to newline] (repend para [s " "]) skip]
				(emit-para out para clear para)
				|
				some [copy s [space thru newline] (append para s)] (
					emit [
						'font fc/font
						copy para
						'drop 1
						'font fb/font
						'newline 'newline
					]
					clear para
				)
				|
				newline
				opt [newline (emit 'newline)]
			]
		]
		out
	]
]
stylize [
	doc: text-area [
		about: {A tiny document markup method for embedded docs, notes, messages.}
		facets: [
			no-edit: true
		]
		options: [
			text-edit: [string! block!]
		]
		actors: [
			on-make: [
				face/state/value: face/facets/text-edit: parse-doc face/facets/text-edit
				init-text-caret face
				append face/gob gob: make-text-gob face face/facets/size - 2 "empty"
				face/gob/size: gob/size
				do-style face 'on-update none
			]
		]
	]
]
--- "REBOL 3 GUI Styles - Images and drawings"
stylize [
	sensor: [
		about: "Has no graphics, but can be clicked."
		facets: [
			size: 100x100
		]
		options: [
			size: [pair!]
		]
		actors: [
			on-click: [
				if arg/type = 'up [do-face face 'hit]
				none
			]
		]
	]
	drawing: sensor [
		about: "Simple scalar vector draw block. Can be clicked."
		facets: [
			size: 100x100
		]
		options: [
			drawing: [block!]
			size: [pair!]
		]
		actors: [
			on-make: [
				if block? drw: face/facets/drawing [
					bind face/gob/draw: copy drw face/facets
				]
			]
		]
	]
	image: sensor [
		about: "Simple image with optional border. Can be clicked."
		facets: [
			size: 100x100
			edge-size: 2.7
			edge-color: coal
		]
		options: [
			src: [image! file! url!]
			size: [pair!]
			edge-size: [number!]
		]
		faced: [
			img: make image! 50x50
		]
		draw: [
			pen edge-color
			line-width edge-size
			box 1x1 area-size 3
			image img
		]
	]
	icon: image [
		about: "Icon image with optional text below."
	]
]
--- "REBOL 3 GUI Styles - Lists"
draw-list-cell: func [
	xy [pair!]
	size [pair!]
	area-color
	fstyle [object!]
	contents [string!]
] [
	reduce [
		'translate xy
		'fill-pen area-color
		'box 0x0 size
		'text
		reduce [
			'font fstyle/font
			'para fstyle/para
			'anti-alias fstyle/anti-alias
			contents
		]
		'reset-matrix
	]
]
draw-list-column: funct [
	face
	list
	xy
] [
	gob: sub-gob? face
	out: gob/draw
	color: get-facet face 'area-color
	fstyle: face-font? face
	size: face/facets/row-size
	foreach item list [
		append out draw-list-cell xy size color fstyle form item
		xy: size * 0x1 + xy
	]
	gob/size: as-pair size/x xy/y
]
find-list-cell: funct [
	face
	y
] [
	num: 0
	dy: face/facets/row-size/y
	gob: sub-gob? face
	out: find gob/draw 'translate
	forskip out face/facets/skip-len [
		++ num
		if all [
			pos: second out
			pos/y <= y (pos/y + dy) > y
		] [return num]
	]
	return none
]
mark-list-cell: funct [
	face
	n
	color
] [
	gob: sub-gob? face
	out: find gob/draw 'translate
	out: skip out n - 1 * face/facets/skip-len + 3
	change out color
]
color-list-cell: funct [
	face
	n
	over
] [
	color: case [
		find face/state/selected n 'mark-color
		over 'over-color
		true 'area-color
	]
	mark-list-cell face n get-facet face color
]
stylize [
	text-list-box: box [
		about: "List of selectable text lines (no scrollbar)."
		facets: [
			size: 100x100
			min-size: 64x64
			area-color: snow
			over-color: snow - 32
			mark-color: sky
			text-style: 'list-item
			all-over: true
			contents: []
		]
		options: [
			contents: [block!]
			area-color: [tuple!]
		]
		state: [
			value: none
			list: none
			selected: copy []
		]
		faced: [
			row-size: 0x0
			skip-len: 0
		]
		actors: [
			on-make: [
				append face/gob gob: make gob! [
					size: face/facets/size
					data: face
				]
				gob/draw: out: make block! 10 * length? face/facets/contents
				face/facets/row-size: 3 + face-char-size? face
				face/facets/skip-len: length? draw-list-cell 0x0 10x10 0.0.0 face-font? face ""
				do-style face 'on-update none
			]
			on-attach: [
				extend-face face 'attached arg
				update-scrollers face sub-gob? face
			]
			on-update: [
				gob: sub-gob? face
				clear out: gob/draw
				append out [pen false]
				draw-list-column face face/facets/contents 2x2
				foreach n face/state/selected [
					color-list-cell face n false
				]
				show-later face
			]
			on-resize: [
				face/facets/area-size: arg - 2x2
				face/facets/row-size/x: arg/x - 2
				face/gob/size: arg
				do-style face 'on-update none
				update-scrollers face sub-gob? face
			]
			on-scroll: [
				gob: sub-gob? face
				size: max 0x0 gob/size - face/gob/size
				gob/offset: arg/state/value * size * 0x-1
				show-later face
				true
			]
			on-over: [
				n: if arg [find-list-cell face arg/y]
				prior: face/state/over
				if prior <> n [
					if face/state/over: n [color-list-cell face n on]
					if prior [color-list-cell face prior off]
					show-later face
				]
			]
			on-click: [
				n: find-list-cell face arg/offset/y
				act: none
				if arg/type = 'down [
					v: face/state/value
					if v [
						remove find face/state/selected v
						color-list-cell face v false
					]
					face/state/value: n
					if n [
						append face/state/selected n
						act: true
					]
				]
				if n [color-list-cell face n false]
				show-later face
				if act [do-face face]
				false
			]
			on-scroll-event: [
				dy: none
				switch arg/type [
					scroll-line [dy: arg/offset/y / -30]
					scroll-page [dy: negate arg/offset/y]
				]
				if all [dy bars: select face 'attached] [
					bump-scroll first bars dy
				]
				none
			]
			on-set: [
				clear face/state/selected
				face/state/value: none
				foreach [word val] arg [
					switch word [
						value [
							if integer? val [face/state/value: val]
							do-style face 'on-update none
							update-scrollers face sub-gob? face
						]
						list [
							face/facets/contents: either block? val [copy val] [form val]
							do-style face 'on-update none
							update-scrollers/reset face sub-gob? face
						]
					]
				]
			]
		]
	]
	text-list: tight [
		about: "List of selectable text lines with scrollbar."
		facets: [
			max-size: 150x3000
		]
		options: [
			list-data: [block!]
		]
		content: [
			text-list-box :list-data :area-color
			scroller
		]
		actors: [
			on-init: [
				if select face 'reactors [
					extend face/faces/1 'reactors face/reactors
				]
			]
			on-set: [
				set-face/list face/faces/1 arg
			]
			on-get: [
				get-face face/faces/1
			]
		]
	]
]
init-view-system
