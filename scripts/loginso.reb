Rebol [
	file: %loginso.reb
	author: "Graham Chiu"
	date: 21-April-2014
	version: 0.0.4
	notes: {
		1. Click on the "Fetch" button which grabs the web page and displays it in the area face.
		2. Cick on the "Count Forms" button which parses the page to see how many web forms are embedded.
		3. For Stackoverflow, click on "Form 2" button
		4. Click on "Extract Form Data" to extract the field names and data for that form
		5. Click on the empty cells and edit them using the keyboard "e"
		6. Click on the "Submit Form" button to get the cookies and Fkey for Stackoverflow

		parse rule will crash at times
	}
	history: {
		20-Apr-2014 allow editing of text table to enter form data ( click on the field, and enter "e" from keyboard to edit a field )
	}
]

do https://raw.githubusercontent.com/gchiu/Rebol3/master/protocols/prot-http.r3

if not value? 'url-decode [
	if not exists? %altwebform.r3 [
		write %altwebform.r3 read http://reb4.me/r3/altwebform.r
	]
	do %altwebform.r3
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

; returns a bunch of pairs from a form
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
						formdata: parse-form pick forms 2

						close-window face
						view/modal compose/deep [
							t: text-table 200x200 ["Name" #1 250 "Value" #2 200] [(formdata)]
							vgroup [
								button "Submit Form" on-action [
									postdata: copy []
									foreach f next get-face/field t 'data [
										repend postdata [to-word f/1 f/2]
									]
									postdata: to-webform postdata
									if error? err: try [
										; submit the form with the entered data
										page: write to-url get-face sitefld postdata
										print to-string page
									][
										info: err/arg2
										; print ["Redirecting to: " info/headers/location]
										cookies: info/headers/set-cookie
										cookiejar: copy ""
										foreach cookie cookies [
											append cookiejar join cookie ";"
										]
										page: to string! write http://chat.stackoverflow.com/rooms/291/rebol-and-red compose/deep [
											GET [Cookie: (cookiejar)]
										]
										comment { ; this doesn't work inside the script but works fine outside
page: find/last page "fkey"

										either parse page [thru {fkey"} any space thru "type" thru {value="} copy fkey to {"} to end][

										][fkey: copy ""]
}
										;; work round for the parse rule failing inside here
										page: find/last page "fkey"
										page: find/tail page {value="}
										fkey: copy/part page find page {"}
										view/modal reduce [
											'vgroup [
												'label "Cookies"
												'area cookiejar
												'hgroup [
													'label "Fkey" fkeyfld: 'field fkey
												]
											]
										]
									]
								]
							]
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

