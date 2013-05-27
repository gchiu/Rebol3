REBOL [
	Title: "R3 GUI - Development Test Script"
	Version: 0.1.5
	Date: 27-May-2013
]

errout: func [msg] [if msg [print msg print "The demo cannot be shown." halt]]

;do %load-gui.r
errout case [
	not value? 'size-text ["This R3 release does not provide a graphics system."]
	; load-gui <> 0.2.1 ["Wrong GUI version for this test script."]
	true [none]
]

; how to check gui version?
either exists? %r3-gui.r3 [
	do %r3-gui.r3
][ load-gui ]

quick-start: none ; For specific section on start, eg. "Forms"

; some functions from old R3
pick1: make function! [[cond a b][either cond [:a] [:b]]]

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

;== end of imported functions

view [
	title "R3 Demo is pending..."
	vpanel [
	ia: info-area {
		A demo is not currently available.

		However, you can run the GUI test script which shows
		various examples, and you can easily examine the source
		code to get a quick idea of how it works.

		Note that we are using the development theme GUI,
		not the default skin.
	} options [ min-size: 480x200 ]
	hgroup [
		button "Run Test" on-action [ close-window face ]
		button "Quit" on-action [ 
			probe ia/gob/size
			close-window face quit 
		]
	]
	]
]

instructions: {
	===GUI Prototype

	This is a <b>development test version</b> of the GUI. It has not
	been finalized because we have a bit more to do.
	
	Note that the skin you are seeing is the development theme,
	<i>not the final skin</i>.

	===Try This Test

	Click on test categories on the left to view them in this
	panel. Click or drag the various test objects to see what
	happens. Resize the window.

	To see the source code for any of these test panels, click
	on the source button below.

	===Bugs and Optimizations

	There are still bugs in the GUI, and we need a few more
	features too. But, the GUI code works fairly well, although
	it <b>has yet to be optimized.</b>

}

view-code: func [text][
	view [code-area 600x400 (text)]
]

calc-radius: func [p] [square-root add p/x ** 2 p/y ** 2]

polar-to-rect: func [
	"Convert radius and angle to x and y."
	radius angle
][
	as-pair radius * sine angle radius * negate cosine angle
]

clock-obj: context [

	radius: 800
	center: 1000x1000

	blk:
	hour-hand:
	min-hand:
	sec-hand: none

	make-clock: has [xy1 xy2 r][

		blk: make block! 220
		area-fill: span-colors white [.3 1.2]

		; Draw background circle:
		append blk compose [
			scale 1 1
			pen black
			line-width 30
			fill-pen white
			circle center (radius + 100)
			line-width 20
		]

		; Draw minute tick marks:
		for angle 0 359 6 [
			xy1: center + polar-to-rect radius + 8 angle
			r: radius + pick [100 60] zero? mod angle 30
			xy2: center + polar-to-rect r angle
			repend blk ['line xy1 xy2]
		]

		; Setup hour hand:
		append blk [
			pen black
			line-cap rounded
			line-width 60
		]
		hour-hand: tail blk
		draw-hand hour-hand 0

		; Setup minute hand:
		append blk [line-width 40]
		min-hand: tail blk
		draw-hand min-hand 0

		; Setup second hand:
		append blk [
			line-width 25
			pen maroon
			fill-pen maroon
			circle center 30
			arrow 10x0
		] 
		sec-hand: tail blk
		draw-hand sec-hand 0

		; Lame surface reflection:
		append blk [
			grad-pen radial 1000x400 800 1100 0 1.2 [255.255.255.240 100.100.100.200]
			pen off
			circle center (radius + 100)
		]

		blk
	]

	draw-hand: funct [hand angle /short /local r][
		r: either short [radius * .75] [radius]
		change hand reduce ['line center center + polar-to-rect r angle * 6]
	]

	set-clock: funct [time] [
		draw-hand/short hour-hand to-integer 5 * ((mod time/1 12) + (time/2 / 60))
		draw-hand min-hand time/2
		draw-hand sec-hand time/3
	]
]

stylize [ ;-- special styles for testing

clock: [

	about: "Analog clock with second hand. Resizable."

	facets: [
		size: 200x200
		max-size: 2000x2000
	]

	options: [
		size: [pair!]
	]

	faced: [
		clock: none
	]

	actors: [
		on-make: [
			face/facets/clock: clk: copy clock-obj
			face/gob/draw: clk/make-clock
			face/state/value: 0:00
		]

		on-resize: [
			face/gob/size: face/facets/area-size: arg
			b: find/tail face/gob/draw 'scale
			b/1: arg/x / 2000
			b/2: arg/y / 2000
			show-later face
		]

		on-set: [
			if arg/1 = 'value [
				if date? time: arg/2 [time: time/time]
				face/state/value: time
				face/facets/clock/set-clock time
				show-later face
			]
		]

		on-get: [face/state/value]

		on-reset: [
			set-face face 0:00
		]
	]
]

draw-box: [

	about: "Box for drawing shapes."

	facets: [
		size: 200x200
		max-size: 2000x2000
	]

	faced: [
		drawing: copy [
			pen coal
			line-width 2
			fill-pen snow
			box 3
		]
		undo: copy []
		marker: none
		line-color: black
		area-color: leaf
		line-size: 2
		corner: 3
		mode: 'box
	]

	actors: [
		on-draw: [face/facets/drawing]

		on-click: [ ; arg: event
			switch arg/type [
				down [
					if m: face/facets/marker [
						; See note at top:
						append/only face/facets/undo m
						delect/all system/dialects/draw m b: []
						append clear m b
					]
					face/facets/marker: tail face/facets/drawing
					return init-drag face arg/offset
				]
			]
			none
		]

		on-drag: [
			append clear d: face/facets/marker [
				pen line-color
				line-width line-size
				fill-pen area-color
			]
			append d mode: face/facets/mode
			repend d select [
				line [arg/base arg/base + arg/delta]
				box [arg/base arg/base + arg/delta 'corner]
				circle [arg/base calc-radius arg/delta]
			] mode
			draw-face face
		]

		on-undo: [
			clear face/facets/marker
			face/facets/marker: take/last face/facets/undo
			draw-face face
		]
	]
]

color-chip: clicker [

	about: "Shows a color. Clicking on it will bring up color requestor."

	facets: [
		size: 18x18
	]
]

free-drag: clicker [

	about: "Box that can be dragged in a panel and past its borders."

	facets: [size: 50x50]

	actors: [
		on-click: [ ; arg: event
			if arg/type = 'down [return init-drag face none]
			none
		]

		on-drag: [
			; arg: drag
			face/gob/offset: arg/delta + arg/base
			draw-face face
		]
	]
]

lock-drag: free-drag [

	about: "Box that can be dragged within a panel, but stops at borders."

	actors: [
		on-drag: [ ; arg: drag
			do-style parent-face? face 'on-offset face/gob/offset:
				min face/gob/parent/size - face/gob/size max 0x0 arg/delta + arg/base
			draw-face face
			do-face parent-face? face
		]
	]
]

box-cross: box [

	about: "Test box for horizontal and vertical scrollers."

	facets: [
		size: 280x140
		max-size: 1000x1000
	]

	state: [
		valx: 0
		valy: 0
	]

	faced: [
		cross-xy: 5x5
	]

	draw: [
		pen 30.30.30
		line-width 1.5
		fill-pen snow
		box 1x1 area-size 3
		fill-pen yellow
		circle cross-xy 5
		line (cross-xy - 8x0) (cross-xy + 8x0)
		line (cross-xy - 0x8) (cross-xy + 0x8)
	]

	actors: [
		on-set: [ ; arg: [word value]
			word: value: none
			set [word value] arg ; change SET !!
			unless find [valx valy] word [exit]
			face/state/:word: value
			set-facet face 'cross-xy 5x5 + as-pair
				face/facets/area-size/x - 10 * face/state/valx
				face/facets/area-size/y - 10 * face/state/valy
		]

		on-reset: [
			set-facet face 'cross-xy 5x5
			draw-face face
		]
	]
]

]

tests: [

	"Buttons"
	"Single-state buttons and dual-state toggle buttons. Layout in a simple panel that has no groups or panels."
	[
		when [load] on-action [print "Load trigger!"]
		button "Do" on-action [request "Alert" "Button pressed!"]
		button "Big Quit Button" maroon options [max-size: 2000x50] on-action [quit]
		bar
		text "Toggle button..."
		t1: toggle "Toggle" ;of 'tog
		button "Set above Toggle False" on-action [set-face t1 false]
		button "Set above Toggle True"  on-action [set-face t1 true]
		toggle "Toggle Mirror" attach 't1
		toggle "Mutex with Toggle" ;of 'tog
		bar
		text "Radios and check boxes"
		radio "Set above Toggle on" on-action [set-face t1 true]
		radio "Set above Toggle off" on-action [set-face t1 false]
		bar
		check "Checkbox attached to above toggle" attach 't1
	]

	"Groups"
	"Group and panel layouts with simple contents (buttons) and tests for auto-sizing. Includes sub-panels."
	[
		hgroup [
			button "Button"
		]
		bar
		hgroup [
			button "Button"
			button "50x50" 50x50 180.0.0
		]
		bar
		hgroup [
			button "50x50" 50x50 180.0.0
			button "maxsize 200x200" options [max-size: 200x200]
		]
		bar
		hgroup [
			button "A A"
			button "A B" return
			button "B A"
			button "B B"
		]
		bar
		hpanel [
			text "Panel example"
			button "Button"
		]
		hpanel gray 0 [
			text "Gray panel example"
			button "Button"
			button "Button"
		]
	]

	"Progress"
	"Progress bar with various value set tests."
	[
		p1: progress
		hgroup [
			button "Set 0%"  on-action [ set-face p1 0% ]
			button "Set 10%"  on-action [ set-face p1 10% ]
			button "Set 50%"  on-action [ set-face p1 50% ]
			button "Set 100%" on-action [ set-face p1 100% ]
			return

			toggle "Color" on-action [
				; not working, supposed to change the color of the progress p1
				; the current code passes a block of 3 RGB values presumably for a gradient fill
				; but progress now uses materials
				set-facet p1 'bar-fill 
				pick [ true none ] ; value returned true or none, face/state/value now returns true or false
				face/state/value red green [1.0 1.5 .6]
				draw-face p1
			]
			button "Simulate" on-action [
				repeat n 100 [
					set-face p1 to percent! n / 100
					show p1/gob ; optimized
					wait .01 ; Temporary - REMOVE !!
				]
			]
			button "Lo limit" on-action [ set-face  p1 -10%]
			button "Hi limit" on-action [ set-face p1 150% ]
		]
		text "Bar of different color:"
		p2: progress gold
		button "Check color" on-action [ set-face  p2 50% ]
	]

	"Slider"
	"Numeric slider with attached progress to show actual value."
	[
		text "Drag this slider to see progress bar change:"
		var: slider attach 'prog
		prog: progress
		hgroup [
			button "Set 0%"   on-action [ set-face var 0% ]
			button "Set 10%"  on-action [ set-face var 10% ]
			button "Set 50%"  on-action [ set-face var 50% ]
			button "Set 100%" on-action [ set-face var 100% ]
		]
		hpanel [
			text "Within another offset..."
			slider green attach 'prog
		] options [max-size: 1000x50 black border-size: [1x1 1x1]]
	]

	"Dragger"
	"Drag test of two kinds of boxes, one bounded the other unbounded."
	[
		; not working - free-drag and lock-drag are not implemented
		doc {
			===Drag the boxes

			Blue boxes are unbounded.

			Red boxes are parent panel bounded.
		}
		d1: on-action [ free-drag ]
		d4: on-action [ lock-drag red ]
		hpanel 0 80.200.80.80 [
			d2: on-action [ free-drag ]
			d3: on-action [ lock-drag red ]
		]
	]

	"Scroller"
	"Scrollbar with readout of value, settings for delta and value. Example panel with controls."
	[
		vgroup [
			; Use a group here to avoid scroller changing all ON-SCROLL related faces
			sbar: scroller attach 'prog
			prog: progress
		]
		vpanel 80.200.180.80 [
			text "These attached faces SET the above scroller:"
			slider attach 'sbar
			scroller attach 'sbar
		] options [ black border-size: [1x1 1x1]]
		hgroup [
			radio "Delta 10%" on-action [ set-face sbar 'delta 10%]
			radio "Delta 50%"  on-action [ set-face sbar 'delta 50% ]
			radio "Delta 100%" on-action [ set-face sbar 'delta 100%]
			return
			button "Set 0%"    on-action [ set-face sbar 0%]
			button "Set 10%"   on-action [ set-face sbar 10%]
			button "Set 50%"   on-action [ set-face sbar 50%]
			return
			button "Set 90%"   on-action [ set-face sbar 90% ]
			button "Set 100%"  on-action [ set-face sbar 100% ]
			button "Set 150%"  on-action [ set-face sbar 150% ]
		]
		scroll-panel [
;		tight 2 [
;			bc: box-cross
;			scroller attach 'bc 'valy
;			scroller attach 'bc 'valx
;		]
			bc: box options [ max-size: 20x20 ] ;box-cross
			; pad 200x200		
			text "Supposed to be two scrollers moving a target"
		] options [ max-size: 100x100 ]
	]

	"Text View"
	"Variety of text outputs, including richtext and scrolling text within panels."
	[
		text "This is plain text - from a string"
		text ["This is " bold "bold rich-text" drop italic " - from a block"]
		text [red "This is red " bold "bold rich-text" drop drop black italic " - from a block"]
		htight [
			ts: text-box (form now)
			scroller
		]
		hgroup [
			button "Small"  on-action [ set-face ts ["version is" system/version "on" now]]
			button "Medium" on-action [ set-face  ts (form system/standard)]
			button "Huge"   on-action [ set-face ts (form system)]
			button "reset"  on-action [ do-actor ts 'on-reset none ]
			return
			button "Goto 0" on-action [set-face/field ts 0 'locate]
			button "Goto 500" on-action  [set-face/field ts 500 'locate]
			button "Goto 5000" on-action  [set-face/field ts 5000 'locate]
			button "Goto tail" on-action  [set-face/field ts tail get-face ts 'locate]
		]	
		info "Info text field."
	]

	"Text Edit"
	"Text edit fields and areas. Allows keyboard input and control."
	[
		field "text field"
		field "second field - reset on enter" on-action [ do-actor face 'on-reset none ] 
		area (form system/options)
		area (form system/standard)
		button "Get" on-action [probe get-face parent-face? face]
	]

	"Drawing"
	"Scalar vector drawings and pixel-based images."
	[
		drawing 200x200 [
			pen silver
			line-width 4
			grad-pen radial 0 200 [0.0.100 100.0.0]
			box 3x3 190x190 5
			scale .5 .5
			pen snow
			line-width 4
			fill-pen red
			arc 204x204 150x150   0  90 closed
			fill-pen green
			arc 196x204 150x150  90  30 closed
			fill-pen blue
			arc 180x190 150x150 120 150 closed
			fill-pen yellow
			arc 204x196 150x150 270  90 closed
		]
		vgroup [
			drawing [
				pen black
				line-width 2.7
				fill-pen red
				circle 50x50 40
			] on-action [ print "clicked!" ]
			drawing 200x100 [
				pen black
				;box
				line-width 2.7
				fill-pen lime
				circle 50x50 40
				fill-pen red
				grad-pen radial 150x50 0 50 [255.0.0 0.255.0]
				circle 150x50 40
				pen snow
				line-width 4
				arrow 1x2 snow
				fill-pen off
				curve 60x40 100x0 150x50
			]
		]
		text "Note: below requires image loaders"
		hgroup [
			image on-action [ print 'image1 ]
			image on-action [ print 'image2]
		]
	]

	"Draw It"
	"Tests interactive drawing. Click and drag to draw new shapes."
	[
		group [
			group 1 [
				radio "Box" on do [set-facet pb 'mode 'box]
				radio "Circle" do [set-facet pb 'mode 'circle]
				radio "Line" do [set-facet pb 'mode 'line]
				bar
				group 2 [
					;<-need color-chip style
					color-chip black alert "Need color requestor"
					text "Line color"
					color-chip leaf alert "Need color requestor"
					text "Fill color"
				]
				text "Line width:" 100x16
				slider 100x20 do [set-facet pb 'line-size 30 * value draw-face pb]
				text "Box rounding:" 100x16
				slider 100x20 do [set-facet pb 'corner 30 * value draw-face pb]
				pad
				button "Undo" do [do-style pb 'on-undo none]
				button "Help" browse http://www.rebol.net/wiki/R3_GUI
			] options [max-size: 100x1000]
			pb: draw-box
		]
	]

	"Text-List"
	"A mini system browser using text lists."
	[
		hgroup [ 
			t1: text-list (words-of system) on-action [
				if integer? value: face/state/value [
					section: select system face/facets/list-data/:value
					either object? section [
						set-face/field t2 words-of section 'data
						set-face tb "(object)"
					][
						set-face tb mold section
					]
				]
			]
			t2: text-list on-action  [
				all [
					integer? value: face/state/value
					integer? v: get-face t1
					object? s: select system pick words-of system v ;bogus!
					set-face tb mold select s pick words-of s value
				]
			]
			tb: area "(value)"
		]
	]

	"Sub-Panel"
	"Scrolling subpanel of fixed size. Can be scrolled vertically and horizontally."
	[
		hgroup [
			sub-pan: plane
			scroller
			scroller
		]
		when [enter] do [
			blk: make block! 10
			fields: system/catalog/datatypes
			repeat n 60 [
				append2 blk 'label ajoin ["Field " n]
				append2 blk 'field form first+ fields
				append2 blk 'button "Change"
			]
			test-sub-pan: make-panel 'group blk [
				size: 800x2000
				margin: 10x10
				columns: 3
			]
			view-layout sub-pan test-sub-pan
			; Bug: something causes view to update before it's ready !!
			; (note that you see the panel, then the switch effect)
		]
	]

	"Forms"
	"Test of simple form, getting and setting fields too."
	[
		pan: hgroup [
			label "First name:"
			f1: field
			return
			label "Last name:"
			field
			return
			label "City:"
			field
			return
			label "Email address:"
			field
			return
			label "Platform:"
			hgroup [
				radio "Windows" on
				radio "OS X"
				radio "Linux"
				radio "Amiga"
			]
			label "Status"
			check "First class reboler."
			return
			label "Time stamp:"
			time: field silver
			return
			label ""
			hgroup [
				button "Set All"
					on-action [
						set-layout pan ["Roy" "Rebol" "Ukiah" "reb@example"]
						set-face time now
					]
				button "Clear All" on-action [ clear-layout pan ]
				return
				button "Submit" on-action [ submit 'pan ]
				button "Reset"  on-action [ alert "Reset not yet defined." ]
				return
				button "Set Time" on-action [set-face time now]
				button "Get Time" on-action [ submit 'time ]
			]
			when [enter]
				; clear 'pan
				clear-layout face
				do [set-face time now]
				; focus f1
		]
	]

	"Document"
	"Simple document markup method that uses MakeDoc format."
	[
		hgroup [
			doc {
				===About the DOC style:

				This is an example of the DOC style. It is a <b>simple
				rich-text document markup method</b> to easily format
				and display notes, instructions, and comments within
				your GUIs.

				===Basic usage:

				The DOC style uses the same basic rules as <b>MakeDoc</b>.

				This is a line of paragraph text.
				Its source lines are automatically combined and wrapped.

				A blank line starts a new paragraph.
				(This is good method, because it allows paragraphs to
				be independent of line length and wrapping. It also
				makes the source text more clear.)

				===Other features:

				You can use <b>bold</b> and <i>italic</i> markup just
				like in HTML (with tags).

				A line that begins with === is a title:

					===New Heading

				To show code, just indent it.

					Code is not wrapped.
					It is shown in a fixed-width font [
						so that
						its indentation
						is preserved
					]

				The DOC style will be expanded in the future.
				But, not to the extreme.

				<em>Click the source button below to see the source
				for this test.</em>
			}
			scroller
		]
	]

	"Clock"
	"Here is an example of a custom style that draws an analog clock face."
	[
		hpanel coal 240x320 [
			clk: clock
			hgroup [
				button "10:20:30" do [set-face clk 10:20:30]
				button "Random" do [set-face clk random 12:00]
				return
				button "Now"   do [set-face clk now]
				button "Spin" do [
					loop 60 [
						set-face clk 1:02:04 + get-face clk
						show-now
						wait 1 / 60
					]
				]
				return
				button "Reset" on-action [ do-actor clk 'on-reset none ]
			]
		]
	]

;	"Charts"
;	"Bar charts and pie charts."
;	[
;		text "Pending"
;		; graph [], chart, diagram []
;	]

	"Triggers"
	"Tests various triggers. Special testing required."
	[
		text "Triggers (When events):"
		trig1: check "Triggered on load"
		when [load] set 'trig1 true

		trig2: check "Triggered on view"
		when [enter] set 'trig2 true

		trig3: check "Triggered on exit"
		when [exit] set 'trig3 true
	]

	"Windows"
	"Test basic window options and actions. Note differences in event handling."
	[
		hgroup [
			button "simple view" on-action [
				view [title "Simple window with title" button "Close" on-action [ close-window face ]]
			]
			text "Really simple window"
			return
			button "view/across" on-action [
				; view/across [title "Layout across" button "Close" on-action [ close-window face ]]
				alert "not working yet"
			]
			text "Layout horizontally"
			return
			button "view/options" on-action [
				view/options [
					title "View with options"
					text "Options: size, color, margin, offset"
					button "Close" on-action [ close-window face ]
				][
					size: 300x300
					area-color: silver
					margin: 10x50
					offset: 'top-left
				]
			]
			text "Tries special options"
			return
			button "view/modal" on-action [
				view/modal [title "Modal popup" button "Close" on-action [ close-window face ]]
			]
			text "Block events to other windows"
		]
		bar
		hgroup [
			button "simple gob" on-action [
				alert "not working yet"
				return none
				view make gob! [
					size: 300x300
					draw: [
						pen white
						fill-pen red
						circle 150x150 100
						text ["Simple GOB - no background"]
					]
				]
			]
			text "A raw GOB with DRAW block"
			return
			button "options gob" on-action [
				alert "not working yet"
				return none
				view/options make gob! [
					size: 300x300
					draw: [
						pen white
						fill-pen red
						circle 150x150 100
						text [white "Simple GOB w/background"]
					]
				][
					offset: 'top-right
					color: navy
				]
			]
			text "Raw gob with a few options"
		]
	]

	"Requestors"
	"Requestor functions and results."
	[
		hgroup [
			button "Ok" on-action [
				set-face r0 request "Command:" "Click OK to set checkmark."
			]
			r0: check "OK was clicked"
			return
			button "Ask" on-action [
				set-face r1 request/ask "Question:" "Click yes to set the checkmark."
			]
			r1: check "YES was clicked"
		]
	]

	"Read HTTP"
	"Read via HTTP from a website and display HTTP source here."
	[
		when [load] on-action [
			; Carl's demo doesn't use 'set and works
			set 'read-site funct [site] [
				set-face i1 dt [set-face t1 to-string read site] ; as UTF-8 !
			]
			; this wasn't needed either
			read-site http://www.rebol.com
			set-face t01 true
		]
		hgroup [
			t01: toggle "REBOL.com" on-action [
				set-face t02 false
				set-face t03 false
				if error? set/any 'err try [
					read-site http://www.rebol.com
				][
					alert mold err
				]
			]
			t02: toggle "REBOL.net" on-action [
				set-face t03 false
				set-face t01 false
				attempt [
					read-site http://www.rebol.net
				]
			]
			t03: toggle "REBOL.org" on-action [
				set-face t02 false
				set-face t01 false
				attempt [
					read-site http://www.rebol.org
				]
			]
		]
		t1: code-area ;!!BUG - size does not expand!!
		hgroup [
			;!!NEED - auto-width text (expands to necessary size)
			text "Elapsed time:" 90x20
			i1: info
		]
		bar
		button "Run script from net" on-action [
			file: %web3works.r3
			write file read join https://raw.github.com/gchiu/Rebol3/master/scripts/ file
			launch file
		]
		text [italic "Requires a direct Internet connection."]
	]
]


; Use above TEST block to generate the GUI and buttons:

test-sections: []
test-notes: []
test-blocks: []

foreach [title notes content] tests [
	if title = 'end [break]
	append/only test-blocks content
	append test-notes notes
	append test-sections title
]
test-panels: array length? test-blocks

current-panel: none

view-sub-panel: funct [
	index
	main-pan
	desc
][
	set 'current-panel index
	set-face desc form pick test-notes index
	pan: pick test-panels index
	unless pan [
			probe pick test-blocks index
			if error? set/any 'err try [
				pan: layout/only pick test-blocks index [columns: 1]
				; pan: pick test-blocks index
			][
				alert mold err
				return none
			]
			; pan: make-panel 'group pick test-blocks index [columns: 1]
			poke test-panels index pan
	]
	if error? set/any 'err try  [ 
		; switch-layout is currently not working
		;switch-layout main-pan pan 'fly-right
		set-content main-pan pan
	][
		alert mold err
	]
]

view [
	title "R3 GUI Tests"
	text (reform ["R3 V" system/version "of" system/build])
	bar
	hpanel 3 [

		; List of test sections:
		text-list test-sections on-action [
			view-sub-panel face/state/value	main-pan desc
		]

		; Panel for showing test results:
		vpanel [
			desc: text-area "Please read the instructions below."
			options [
				max-size: 2000x40
				text-style: 'bold
			]

			main-pan: hpanel [
				doc instructions
			] options [min-size: 300x500 max-size: 1000x1000]

			hgroup [
				button "Source" on-action [
					either current-panel [
						view-code trim/head mold/only pick test-blocks current-panel
					][
						request "Note:" "Pick a test first."
					]
				]
				button "Halt" leaf on-action [ unview/all halt ]
				button "Quit" maroon on-action [ quit ]
				check "Debug"  on-action [ do [guie/debug: if value [[all]]] ]
				check "Remind" guie/remind on-action [ do [guie/remind: value] ]
			]
		]
	]
	when [enter] on-action [
		if quick-start [
			if spot: find test-sections quick-start [
				view-sub-panel index? spot main-pan desc  ; for faster testing
			]
		]
		;[request "Alert" instructions]
	]
]
;[reactors: [[moved [save %win-xy.r face/gob/offset]]]]
