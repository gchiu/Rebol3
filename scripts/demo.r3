REBOL [
	Title: "R3 GUI - Development Test Script"
	Version: 0.1.3
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
		group [
			button "Button"
		]
		bar
		group [
			button "Button"
			button "50x50" 50x50 180.0.0
		]
		bar
		group [
			button "50x50" 50x50 180.0.0
			button "maxsize 200x200" options [max-size: 200x200]
		]
		bar
		group 2 [
			button "A A"
			button "A B"
			button "B A"
			button "B B"
		]
		bar
		panel [
			text "Panel example"
			button "Button"
		]
		panel gray 0 [
			text "Gray panel example"
			button "Button"
			button "Button"
		]
	]

	"Progress"
	"Progress bar with various value set tests."
	[
		p1: progress
		group 4 [
			button "Set 0%"   set 'p1 0%
			button "Set 10%"  set 'p1 10%
			button "Set 50%"  set 'p1 50%
			button "Set 100%" set 'p1 100%

			toggle "Color" do [
				set-facet p1 'bar-fill span-colors pick1 value red green [1.0 1.5 .6]
				draw-face p1
			]
			button "Simulate" do [
				repeat n 100 [
					set-face p1 to percent! n / 100
					show p1/gob ; optimized
					wait .01 ; Temporary - REMOVE !!
				]
			]
			button "Lo limit" set 'p1 -10%
			button "Hi limit" set 'p1 150%
		]
		text "Bar of different color:"
		p2: progress gold
		button "Check color" set 'p2 50%
	]

	"Slider"
	"Numeric slider with attached progress to show actual value."
	[
		text "Drag this slider to see progress bar change:"
		var: slider attach 'prog
		prog: progress
		group [
			button "Set 0%"   set 'var 0%
			button "Set 10%"  set 'var 10%
			button "Set 50%"  set 'var 50%
			button "Set 100%" set 'var 100%
		]
		panel 2 [
			text "Within another offset..."
			slider green attach 'prog
		] options [max-size: 1000x50]
	]

	"Dragger"
	"Drag test of two kinds of boxes, one bounded the other unbounded."
	[
		doc {
			===Drag the boxes

			Blue boxes are unbounded.

			Red boxes are parent panel bounded.
		}
		d1: free-drag
		d4: lock-drag red
		panel 0 80.200.80.80 [
			d2: free-drag
			d3: lock-drag red
		]
	]

	"Scroller"
	"Scrollbar with readout of value, settings for delta and value. Example panel with controls."
	[
		group 1 [
			; Use a group here to avoid scroller changing all ON-SCROLL related faces
			sbar: scroller attach 'prog
			prog: progress
		]
		panel 80.200.180.80 [
			text "These attached faces SET the above scroller:"
			slider attach 'sbar
			scroller attach 'sbar
		]
		group 3 [
			radio "Delta 10%" on set 'sbar 'delta 10%
			radio "Delta 50%"  set 'sbar 'delta 50%
			radio "Delta 100%" set 'sbar 'delta 100%
			button "Set 0%"    set 'sbar 0%
			button "Set 10%"   set 'sbar 10%
			button "Set 50%"   set 'sbar 50%
			button "Set 90%"   set 'sbar 90%
			button "Set 100%"  set 'sbar 100%
			button "Set 150%"  set 'sbar 150%
		]
		tight 2 [
			bc: box-cross
			scroller attach 'bc 'valy
			scroller attach 'bc 'valx
		]
	]

	"Text View"
	"Variety of text outputs, including richtext and scrolling text within panels."
	[
		text "This is plain text - from a string"
		text ["This is " bold "bold rich-text" drop italic " - from a block"]
		text [red "This is red " bold "bold rich-text" drop drop black italic " - from a block"]
		tight [
			ts: text-box (form now)
			scroller
		]
		group 4 [
			button "Small"  set 'ts ["version is" system/version "on" now]
			button "Medium" set 'ts (form system/standard)
			button "Huge"   set 'ts (form system)
			button "reset"  reset 'ts
			button "Goto 0" do [set-face/field ts 0 'locate]
			button "Goto 500" do [set-face/field ts 500 'locate]
			button "Goto 5000" do [set-face/field ts 5000 'locate]
			button "Goto tail" do [set-face/field ts tail get-face ts 'locate]
		]
		info "Info text field."
	]

	"Text Edit"
	"Text edit fields and areas. Allows keyboard input and control."
	[
		field "text field"
		field "second field - reset on enter" reset
		area (form system/options)
		area (form system/standard)
		button "Get" do [probe get-face parent-face? face]
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
		group [
			drawing [
				pen black
				line-width 2.7
				fill-pen red
				circle 50x50 40
			] print "clicked!"
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
		group 2[
			image print 'image1
			image print 'image2
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
		group [ 
			t1: text-list (words-of system) do [
				if integer? value [
					section: select system face/facets/contents/:value
					either object? section [
						set-face/field t2 words-of section 'list
						set-face tb "(object)"
					][
						set-face tb mold section
					]
				]
			]
			t2: text-list do [
				all [
					integer? value
					integer? v: get-face t1
					object? s: select system pick words-of system v ;bogus!
					set-face tb mold select s pick words-of s value
				]
			]
			tb: text-box "(value)"
		]
	]

	"Sub-Panel"
	"Scrolling subpanel of fixed size. Can be scrolled vertically and horizontally."
	[
		group 2 [
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
			view-panel sub-pan test-sub-pan
			; Bug: something causes view to update before it's ready !!
			; (note that you see the panel, then the switch effect)
		]
	]

	"Forms"
	"Test of simple form, getting and setting fields too."
	[
		pan: group 2 [
			label "First name:"
			f1: field
			label "Last name:"
			field
			label "City:"
			field
			label "Email address:"
			field
			label "Platform:"
			group [
				radio "Windows" on
				radio "OS X"
				radio "Linux"
				radio "Amiga"
			]
			label "Status"
			check "First class reboler."
			label "Time stamp:"
			time: field silver
			label ""
			group 2 [
				button "Set All"
					set 'pan ["Roy" "Rebol" "Ukiah" "reb@example"]
					do [set-face time now]
				button "Clear All" clear 'pan
				button "Submit" submit 'pan
				button "Reset"  alert "Reset not yet defined."
				button "Set Time" do [set-face time now]
				button "Get Time" submit 'time
			]
			when [enter]
				clear 'pan
				do [set-face time now]
				focus 'f1
		]
	]

	"Document"
	"Simple document markup method that uses MakeDoc format."
	[
		group [
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
		panel coal 240x320 [
			clk: clock
			group 2 [
				button "10:20:30" do [set-face clk 10:20:30]
				button "Random" do [set-face clk random 12:00]
				button "Now"   do [set-face clk now]
				button "Spin" do [
					loop 60 [
						set-face clk 1:02:04 + get-face clk
						show-now
						wait 1 / 60
					]
				]
				button "Reset" reset 'clk
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

	"Reactors"
	"Tests that reactors do what they are supposed to."
	[
		panel 2 [
			button "Do" do [request "Got it!" "It worked."]
			button "Browse" browse http://www.rebol.com
			button "Run" run %explorer
			button "Alert" alert "This is an alert."
		]
		panel 2 [
			f1: field "Field 1"
			f2: field "Field 2"
			button "Focus on 1" focus 'f1
			button "Focus on 2" focus 'f2
		]
		panel 2 [
			button "Close" close
			button "Halt" halt
			button "Quit" quit
			button "?"
			button "Print" print "print this message"
			button "Dump" dump
		]
	]

	"Windows"
	"Test basic window options and actions. Note differences in event handling."
	[
		group 2 [
			button "simple view" do [
				view [title "Simple window with title" button "Close" close]
			]
			text "Really simple window"
			button "view/across" do [
				view/across [title "Layout across" button "Close" close]
			]
			text "Layout horizontally"
			button "view/options" do [
				view/options [
					title "View with options"
					text "Options: size, color, margin, offset"
					button "Close" close
				][
					size: 300x300
					area-color: silver
					margin: 10x50
					offset: 'top-left
				]
			]
			text "Tries special options"
			button "view/modal" do [
				view/modal [title "Modal popup" button "Close" close]
			]
			text "Block events to other windows"
		]
		bar
		group 2 [
			button "simple gob" do [
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
			button "options gob" do [
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
		group 2 [
			button "Ok" do [
				set-face r0 request "Command:" "Click OK to set checkmark."
			]
			r0: check "OK was clicked"
			button "Ask" do [
				set-face r1 request/ask "Question:" "Click yes to set the checkmark."
			]
			r1: check "YES was clicked"
		]
	]

	"Read HTTP"
	"Read via HTTP from a website and display HTTP source here."
	[
		when [load] do [
			read-site: funct [site] [
				set-face i1 dt [set-face t1 to-string read site] ; as UTF-8 !
			]
		]
		group [
			toggle "REBOL.com" of 'site do [read-site http://www.rebol.com]
			toggle "REBOL.net" of 'site do [read-site http://www.rebol.net]
			toggle "REBOL.org" of 'site do [read-site http://www.rebol.org]
		]
		t1: code-area ;!!BUG - size does not expand!!
		group [
			;!!NEED - auto-width text (expands to necessary size)
			text "Elapsed time:" 90x20
			i1: info
		]
		bar
		button "Run script from net" do [
			file: %web3works.r
			write file read join http://www.rebol.com/r3/ file
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
			][
				alert mold err
				return none
			]
			; pan: make-panel 'group pick test-blocks index [columns: 1]
			poke test-panels index pan
	]
	if error? set/any 'err try  [ switch-layout main-pan pan 'fly-right][
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
				check "Debug"  on-actin [ do [guie/debug: if value [[all]]] ]
				check "Remind" guie/remind on-action [ do [guie/remind: value] ]
			]
		]
	]
	when [enter] do [
		if quick-start [
			if spot: find test-sections quick-start [
				view-sub-panel index? spot main-pan desc  ; for faster testing
			]
		]
		;[request "Alert" instructions]
	]
]
;[reactors: [[moved [save %win-xy.r face/gob/offset]]]]
