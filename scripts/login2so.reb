Rebol [
	file: %login2so.reb
	date: 20-April-2014
	author: "Graham Chiu"
	purpose: {
		login to stackoverflow using your stackexchange credentials
		returns cookie and fkey
	}
]

sx-email: stackexchange-email@somewhere.com  ; email!
sx-password: "-- password ---" ; string!
chat-page: http://chat.stackoverflow.com/rooms/291/rebol-and-red ; url!

; load modified http protocol to return the info object on failed http redirect
do https://raw.githubusercontent.com/gchiu/Rebol3/master/protocols/prot-http.r3

do http://reb4.me/r3/altwebform.r

login2so: func [email [email!] password [string!] chat-page [url!]
	/local fkey root loginpage cookiejar result
][
	fkey: none
	root: https://stackoverflow.com
	; grab the first fkey from the login page
	loginpage: to string! read https://stackoverflow.com/users/login

	either parse loginpage [thru "se-login-form" thru {action="} copy action to {"} thru "fkey" thru {value="} copy fkey to {"} thru {"submit-button"} thru {value="} copy login to {"} to end][
		postdata: to-webform reduce ['fkey fkey 'email email 'password password 'submit-button login]
		if error? err: try [
			result: to-string write join root action postdata
		][
			cookiejar: err/arg2/headers/set-cookie
			result: read chat-page compose/deep [GET [cookie: (cookiejar)]]
			result: reverse decode 'markup result
			; now grab the new fkey for the chat pages
			foreach tag result [
				if tag? tag [
					if parse tag [thru "fkey" thru "hidden" thru "value" thru {"} copy fkey to {"} to end][
						fkey: to string! fkey
						break
					]
				]
			]
		]
		return compose [fkey: (fkey) cookie: (cookiejar)]

	][
		return [fkey: none cookie: none]
	]
]

; example

result: login2so sx-email sx-password chat-page

?? result
halt