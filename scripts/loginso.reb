Rebol [
	file: %loginso.reb
	author: "Graham Chiu"
	date: 12-April-2014
	version: 0.0.1
	notes: {
		parse rule will crash at times
	}
]

do https://raw.githubusercontent.com/gchiu/Rebol3/master/protocols/prot-http.r3

; <input id="fkey" name="fkey" type="hidden" value="7b20553b65f49a1ab4eba
; {usr=t=iIb1M83iCESX&s=

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
							text-table 200x200 ["Name" #1 250 "Value" #2 200] [(formdata)]
							vgroup [
								hgroup [label "Email: " emailfld: field ""]
								hgroup [label "Password: " passwordfld: field ""]
								button "Submit" on-action [
									postdata: copy []
									foreach f next [(formdata)] [
										append postdata to-word f/1
										case [
											f/1 = "email" [append postdata get-face emailfld]
											f/1 = "password" [append postdata get-face passwordfld]
											true [append postdata f/2]
										]
									]
									postdata: to-webform postdata

									if error? err: try [
										write to-url get-face sitefld postdata
									][

										;?? err
										info: err/arg2
										; print ["Redirecting to: " info/headers/location]
										cookies: info/headers/set-cookie
										cookiejar: copy ""
										foreach cookie cookies [
											append cookiejar join cookie ";"
										]

										; ?? cookiejar
										

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

