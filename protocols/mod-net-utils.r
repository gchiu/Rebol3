REBOL [ ]


net-utils: module [
	Title: "Network Module"
	Name: net-utils
	Version: 0.0.2
	Type: module
	Date: 25-Jan-2001
	Author: "Graham Chiu"
	Rights: 'BSD
	Exports: [
		alpha
		digit
		non-digit
		pasv-rule
		within?
		print-string?
		net-log
		as-utc
		to-ISO8601-date
		to-ISO8601-UTC
		hmac-sha1
		url-encode
		enclose-tag
	]
] [

	alpha: charset [#"a" - #"z" #"A" - #"Z"]
	digit: charset [#"0" - #"9"]
	non-digit: complement digit
	non-digits: [some non-digit]
	pasv-rule: [1 3 digit "," 1 3 digit "," 1 3 digit "," 1 3 digit "," opt ["-"] 1 3 digit "," opt ["-"] 1 3 digit]

	within?: func [low hi code] [
		all [code >= low code <= hi]
	]

	print-string: func [txt] [
		print to-string txt
	]

	net-log: func [txt
		/C
		/S
	] [
		if C [prin "C: "]
		if S [prin "S: "]
		print txt
		txt
	]
	
	;; url stuff
	url-encode: func [
		"URL-encode a string"
		data "String to encode"
		/local new-data
	] [
		new-data: make string! ""
		normal-char: charset [
			#"A" - #"Z" #"a" - #"z"
			#"@" #"." #"*" #"-" #"_"
			#"0" - #"9"
		]
		if not string? data [return new-data]
		forall data [
			append new-data either find normal-char first data [
				first data
			] [
				rejoin ["%" to-string skip tail (to-hex to-integer first data) -2]
			]
		]
		new-data
	]

	;; email stuff

	email: make object! [
		To: none
		CC: none
		BCC: none
		From: none
		Reply-To: none
		Date: none
		Subject: none
		Return-Path: none
		Organization: none
		Message-Id: none
		Comment: none
		X-REBOL: form rebol/version
		MIME-Version: none
		Content-Type: none
		Content: none
	]

	export: func [
		{Export an object to something that looks like a header}
		object [object!] "Object to export"
		/local words values result word
	] [
		words: next first object
		values: next second object
		result: make string! (20 * length? words)
		foreach word words [
			if found? first values [
				insert tail result reduce [word ": " first values newline]
			]
			values: next values
		]
		result
	]

	;; amazon stuff

	format-10: func [d [integer! decimal!]
	] [
		next form 100 + d
	]

	as-utc: func [date] [
		if all [date/zone 0:00 <> date/zone] [
			date: date - date/zone
		]
		date/zone: none
		if none? date/time [date/time: 0:0:0.000]
		date
	]

	to-ISO8601-date: func [d [date!]
	] [
		rejoin [
			d/year "-"
			format-10 d/month "-"
			format-10 d/day "T"
			format-10 d/time/1 ":"
			format-10 d/time/2 ":"
			format-10 round/to d/time/3 .1 "00Z"
		]
	]

	to-ISO8601-UTC: func [date [date!]
	] [
		to-ISO8601-date as-utc date
	]

	today-http-date: func [
		/local d
	] [
		d: now-gmt
		rejoin [
			copy/part pick system/locale/days d/weekday 3
			", " next form 100 + d/day " "
			copy/part pick system/locale/months d/month 3
			" " d/year " "
			next form 100:00 + d/time " +0000"
		]
	]
	hmac-sha1: func [val [binary!] key [string!]] [checksum/method/key val 'sha1 key]
	
	;; XML 
	
	; enclose-tag 'action 'createdomain
	; <action>createdomain</action>

comment {	
	enclose-tag: func [ tag name ][ 
		either all [ string? name empty? name ][
			append to-tag tag "/"
		][
			ajoin [ to-tag tag name to-tag join "/" first parse form tag " " ]
		]
	]
}
	
	enclose-tag: func [ tag name ][
		either all [ string? name empty? name ][
			append to-tag tag "/"
		][
			if block? name [ name: ajoin name ]
			ajoin [ to-tag tag name to-tag join "/" first parse form tag " " ]
		]
	]
	
]