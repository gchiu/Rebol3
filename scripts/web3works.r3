REBOL [Title: "First Web 3.0 Script"]

load-gui

msg: compose [
	"This program was downloaded from the Internet! "
	"It is " bold "leaner, meaner, and a whole lot cleaner." drop
	newline newline
	"Its size is: " (form size? %web3works.r3) " bytes."
	newline newline
	"Click source to view source code."
]

view  [
	title "Web 3.0 works!"
	text-area msg
	vgroup [
		button "Source" on-action [
			view compose [code-area (to string! read %web3works.r3)]
		]
		button "Close" on-action [ close-window face ]
	]
]