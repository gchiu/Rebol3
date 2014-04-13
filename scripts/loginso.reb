Rebol [
	file: %loginso.reb
	author: "Graham Chiu"
	date: 12-April-2014
	version: 0.0.1
	notes: {
		parse rule will crash at times
	}
]


if not value? 'to-text [
	if not exists? %r3-gui.r3 [
		write %r3-gui.r3 read http://development.saphirion.com/resources/r3-gui.r3
	]
	do %r3-gui.r3
]

forms: copy []


;remove quotes
remove-quotes: func [txt [string!]][
	remove head remove back tail txt
]

; returns a bunch of pairs
parse-form: funct [txt][
	data: copy []
	alpha: complement charset space
	; get the form action and method
	parse txt [
		(tmp: copy [])
		thru "action" any space "=" any space copy action some alpha (
			remove-quotes action
			append tmp join get-face sitefld action
		)
		thru "method" any space "=" thru {"} copy method to {"} (
			append tmp method
			append/only data tmp
		)
	]
	; now get the input name vaue pairs
	html: decode 'markup to-binary txt
	foreach tagged html [
		trim/head/tail tagged
		parse form tagged [
			"<" any space "input" thru "name" thru "=" thru {"} copy name to {"}
			(repend/only data copy [name ""] value: none)
			thru "value" any space "=" thru {"} copy value to {"} to end
			(if string? value [
					append remove back tail last data value
				]
			)
		]
	]
	data
]

view [
	vgroup [
		hgroup [
			label "Site:" sitefld: field "https://stackoverflow.com/users/login"
		]
		button "Fetch" on-action [
			if error? try [
				set 'forms copy []
				page: read to-url get-face sitefld
				set-face htmldata to-string page
			][
				alert "Page read error"
			]
		]
	]
	vgroup [
		label "Page Data"
		htmldata: area
	]
	hgroup [
		button "Count forms" on-action [
			set 'forms copy []
			if not empty? page: get-face htmldata [
				cnt: 0
				alert either parse page [
					some [
						to "<form" copy tmp to "</form" (
							++ cnt
							append tmp "</form>"
							append forms tmp
						)
					] to end
				][
					reform ["Found " cnt "forms"]
				]["No forms found"]

			]
		]
		button "Form 1" on-action [
			view/modal compose [
				area (pick forms 1)
				button "Extract Form Data" on-action [
					if forms/1 [
						data: parse-form pick forms 1
						close-window face
						view/modal compose/deep [
							text-table 200x200 ["Name" #1 250 "Value" #2 200] [(data)]
						]
					]
				]
			]
		]

		button "Form 2" on-action [
			view/modal compose [
				area (pick forms 2)
				button "Extract Form Data" on-action [
					if forms/2 [
						data: parse-form pick forms 2
						close-window face
						view/modal compose/deep [
							text-table 200x200 ["Name" #1 250 "Value" #2 200] [(data)]
						]
					]
				]
			]
		]


		button "Form 3" on-action [
			view/modal compose [
				area (pick forms 3)
				button "Extract Form Data" on-action [
					if forms/3 [
						data: parse-form pick forms 3
						close-window face
						view/modal compose/deep [
							text-table 200x200 ["Name" #1 250 "Value" #2 200] [(data)]
						]
					]
				]
			]
		]

		button "Form 4" on-action [
			view/modal compose [
				area (pick forms 4)
				button "Extract Form Data" on-action [
					if forms/4 [
						data: parse-form pick forms 4
						close-window face
						view/modal compose/deep [
							text-table 200x200 ["Name" #1 250 "Value" #2 200] [(data)]
						]
					]
				]
			]
		]
		button "Form 5" on-action [
			view/modal compose [
				area (pick forms 5)
				button "Extract Form Data" on-action [
					if forms/5 [
						data: parse-form pick forms 5
						close-window face
						view/modal compose/deep [
							text-table 200x200 ["Name" #1 250 "Value" #2 200] [(data)]
						]
					]
				]
			]
		]
	]
]

