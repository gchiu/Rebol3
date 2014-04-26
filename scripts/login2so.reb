Rebol [
	file: %login2so.reb
	date: 26-April-2014
	author: "Graham Chiu"
	purpose: {
		login to stackoverflow using your stackexchange credentials
		returns the usr cookie and fkey
		confirmed as working using the sochat client
	}
]

sx-email: stackexchange-email@somewhere.com  ; email!
sx-password: "-- password ---" ; string!
chat-page: http://chat.stackoverflow.com/rooms/291/rebol-and-red ; url!

; load modified http protocol to return the info object on failed http redirect
print "loading modified prot-http.r3"
do https://raw.githubusercontent.com/gchiu/Rebol3/master/protocols/prot-http.r3
print "loading altwebform.r" 
do http://reb4.me/r3/altwebform.r

login2so: func [email [email!] password [string!] chat-page [url!]
	/local fkey root loginpage cookiejar result err
][
	fkey: none
	root: https://stackoverflow.com
	; grab the first fkey from the login page
	print "reading login page"
	loginpage: to string! read https://stackoverflow.com/users/login

	either parse loginpage [thru "se-login-form" thru {action="} copy action to {"} thru "fkey" thru {value="} copy fkey to {"} thru {"submit-button"} thru {value="} copy login to {"} to end][
		postdata: to-webform reduce ['fkey fkey 'email email 'password password 'submit-button login]
		if error? err: try [
			result: to-string write join root action postdata
		][
			cookiejar: reform err/arg2/headers/set-cookie
			parse cookiejar [ to "usr=" copy cookiejar to ";" ]
			result: write chat-page compose/deep [GET [cookie: (cookiejar)]]
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
		return make object! compose [fkey: (fkey) cookie: (cookiejar)]

	][
		return make object! [fkey: none cookie: none]
	]
]

; example

print "reading ..."
result: login2so sx-email sx-password chat-page

?? result
write clipboard:// mold result
halt