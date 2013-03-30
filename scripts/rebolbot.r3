Rebol [
	file: %rebolbot.r3
	author: "Graham"
	date: [28-Feb-2013 30-Mar-2013] ; leave this as a block plz!  It's used by version command
	version: 0.0.27
	purpose: {post messages into the Rebol-red chat room on Stackoverflow}
	Notes: {You'll need to capture your own cookie and fkey using wireshark or similar.}
	License: 'Apache2
]
;-- optionally load my patched version of prot-http.r
; do %prot-my-http.r

; load some utilities
if not value? 'load-json [
	do http://reb4.me/r3/altjson
]
if not value? 'decode-xml [
	do http://reb4.me/r3/altxml
]

if not value? 'shrink [
	shrink: load http://www.rebol.org/download-a-script.r?script-name=shrink.r
	eliza: make object! shrink/4
	eliza/rules: shrink/6
]

chat-length-limit: 500 ; SO chat limits to 500 chars if a message contains a link

greet-message: " Welcome to the Rebol and Red room.  See our [FAQ](https://github.com/hostilefork/r3-hf/wiki/StackOverflow-Chat-FAQ)"
bot-cookie: {-get-your-own-}
bot-fkey: "-get-your-own-"
; ideone API details
ideone-user: "rebolbot"
ideone-pass: "-get-your-own-"

pause-period: 5 ; 5 seconds between each poll of the chat
no-of-messages: 5 ; fetch 5 messages each time
max-scan-messages: 200 ; max to fetch to scan for links by a user

; these users can remove keys - uses userids, the names are there just so that you know who they are!
privileged-users: ["BrianH" 2016426 "HostileFork" 211160 "Graham Chiu" 76852 "GrahamChiu" 76852 "rgchris" 292969 "Adrian" 1792095 "dockimbel" 2026582 "earl" 135724]

expressions: %bot-expressions.r
notable-persons-file: %known-users.r

visitors-file: %visitors.r
visitors: copy []

lastmessage-no: 7973980
last-message-file: %lastmessage-no.r

if exists? last-message-file [
	attempt [
		lastmessage-no: load last-message-file
	]
]

?? lastmessage-no

; save/all %bot-config.r make object! compose [ bot-fkey: (bot-fkey) bot-cookie: (bot-cookie) ]
if exists? %bot-config.r [
	bot-config: load %bot-config.r
	bot-cookie: bot-config/bot-cookie
	bot-fkey: bot-config/bot-fkey
]

bot-expressions: [
	"help" ["FAQ" http://rebolsource.net/go/chat-faq]
	"tutorial" ["Introduction to Rebol" http://www.rebol.com/rebolsteps.html]
	"Devcon" ["Red Video from Devcon 2013" https://www.youtube.com/watch?v=JjPKj0_HBTY]
]
; save expressions bot-expressions

if exists? expressions [
	bot-expressions: load expressions
]

;- configuration urls
remote-execution-url: http://tryrebol.esperconsultancy.nl/do/REBOL
;remote-execution2-url: http://tryrebol.esperconsultancy.nl/do/REBOL-2
remote-execution-url: [
	rebol3 http://tryrebol.esperconsultancy.nl/do/REBOL
	rebol2 http://tryrebol.esperconsultancy.nl/do/REBOL-2
	boron http://tryrebol.esperconsultancy.nl/do/Boron
	red http://tryrebol.esperconsultancy.nl/do/Red
]

room-id: 291 room-descriptor: "rebol-and-red"

id-rule: charset [#"0" - #"9"]

so-chat-url: http://chat.stackoverflow.com/
chat-target-url: rejoin write-chat-block: [so-chat-url 'chats "/" room-id "/" 'messages/new]
referrer-url: rejoin [so-chat-url 'rooms "/" room-id "/" room-descriptor]
html-url: rejoin [referrer-url "?highlights=false"]
read-target-url: rejoin [so-chat-url 'chats "/" room-id "/" 'events]
delete-url: [so-chat-url 'messages "/" (parent-id) "/" 'delete]
; POST /messages/8034726/delete HTTP/1.1

ideone-url: http://ideone.com:80/api/1/service

; config botname
botname: "@RebolBot"

non-space: complement space: charset #" "

percent-encode: func [char [char!]] [
	char: enbase/base to-binary char 16
	parse char [
		copy char some [char: 2 skip (insert char "%") skip]
	]
	char
]

url-encode: use [ch mk] [
	ch: charset ["-." #"0" - #"9" #"A" - #"Z" #"-" #"a" - #"z" #"~"]
	func [text [any-string!]] [
		either parse/all text: form text [
			any [
				some ch | end | change " " "+" |
				mk: (mk: percent-encode mk/1)
				change skip mk
			]
		] [to-string text] [""]
	]
]

; updated to remove the /local pad
to-itime: func [
	{Returns a standard internet time string (two digits for each segment)}
	time [time! number! block! none!]
] [
	time: make time! time
	rejoin [
		next form 100 + time/hour ":"
		next form 100 + time/minute ":"
		next form 100 + round/down time/second
	]
]

to-idate: func [
	"Returns a standard Internet date string."
	date [date!]
	/local str
] [
	str: form date/zone
	remove find str ":"
	if (first str) <> #"-" [insert str #"+"]
	if (length? str) <= 4 [insert next str #"0"]
	reform [
		pick ["Mon," "Tue," "Wed," "Thu," "Fri," "Sat," "Sun,"] date/weekday
		date/day
		pick ["Jan" "Feb" "Mar" "Apr" "May" "Jun" "Jul" "Aug" "Sep" "Oct" "Nov" "Dec"] date/month
		date/year
		to-itime any [date/time 0:00]
		str
	]
]

; perhaps not all of this header is required
header: compose [
	Host: "chat.stackoverflow.com"
	Origin: "http://chat.stackoverflow.com"
	Accept: "application/json, text/javascript, */*; q=0.01"
	X-Requested-With: "XMLHttpRequest"
	Referer: (referrer-url)
	Accept-Encoding: "gzip,deflate"
	Accept-Language: "en-US"
	Accept-Charset: "ISO-8859-1,utf-8;q=0.7,*;q=0.3"
	Content-Type: "application/x-www-form-urlencoded"
	cookie: (bot-cookie)
]

soap-execute-template: {<?xml version="1.0" encoding="UTF-8" standalone="no"?><SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" xmlns:tns="http://ideone.com:80/api/1/service" xmlns:soap="http://schemas.xmlsoap.org/wsdl/soap/" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:wsdl="http://schemas.xmlsoap.org/wsdl/" xmlns:soap-enc="http://schemas.xmlsoap.org/soap/encoding/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" ><SOAP-ENV:Body><mns:createSubmission xmlns:mns="http://ideone.com:80/api/1/service" SOAP-ENV:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/"><user xsi:type="xsd:string">$a</user><pass xsi:type="xsd:string">$b</pass><sourceCode xsi:type="xsd:string">$c</sourceCode><language xsi:type="xsd:int">$d</language><input xsi:type="xsd:string">$e</input><run xsi:type="xsd:boolean">$f</run><private xsi:type="xsd:boolean">$g</private></mns:createSubmission></SOAP-ENV:Body></SOAP-ENV:Envelope>}

soap-response-template: {<?xml version="1.0" encoding="UTF-8" standalone="no"?><SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" xmlns:tns="http://ideone.com:80/api/1/service" xmlns:soap="http://schemas.xmlsoap.org/wsdl/soap/" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:wsdl="http://schemas.xmlsoap.org/wsdl/" xmlns:soap-enc="http://schemas.xmlsoap.org/soap/encoding/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" ><SOAP-ENV:Body><mns:getSubmissionDetails xmlns:mns="http://ideone.com:80/api/1/service" SOAP-ENV:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/"><user xsi:type="xsd:string">$user</user><pass xsi:type="xsd:string">$pass</pass><link xsi:type="xsd:string">$link</link><withSource xsi:type="xsd:boolean">1</withSource><withInput xsi:type="xsd:boolean">1</withInput><withOutput xsi:type="xsd:boolean">1</withOutput><withStderr xsi:type="xsd:boolean">1</withStderr><withCmpinfo xsi:type="xsd:boolean">1</withCmpinfo></mns:getSubmissionDetails></SOAP-ENV:Body></SOAP-ENV:Envelope>
}

evaluate-by-ideone: func [message-id user pass source [string!] language [word! string! integer!] inpt [string!]
	/local result result2 error status link inputs output
] [
	error: status: link: none
	;print "in eval ideone"

	;?? source
	source: head remove source head remove back tail source
	;?? source

	if not integer? language [
		language: select [
			"forth" 107
			"ruby" 17
			"javascript" 35
			"scheme" 33
			"python" 4
			"perl" 3
		] to string! language
	]
	if none? language [
		reply message-id "Unsupported language"
		return
	]
	;?? user ?? pass ?? source ?? language ?? inpt
	print reword soap-execute-template reduce [
		'a user
		'b pass
		'c source
		'd language
		'e inpt
		'f "1"
		'g "1"
	]
	result: write ideone-url reduce ['SOAP (
			reword soap-execute-template reduce [
				'a user
				'b pass
				'c source
				'd language
				'e inpt
				'f "1"
				'g "1"
			]
		)
	]
	; should get an error code
	probe decode 'markup result
	if parse decode 'markup result [
		thru <item> <key xsi:type="xsd:string"> copy error to </key>
		thru <value xsi:type="xsd:string"> copy status to </value>
		thru <item> <key xsi:type="xsd:string"> "link" </key>
		<value xsi:type="xsd:string"> copy link to </value>
		to end] [
		;?? error
		;?? status
		;?? link
		if all [
			error/1 = "error"
			status/1 = "OK"
		] [
			; we have a link value to get the result
			probe reword soap-response-template reduce [
				'user user
				'password pass
				'link link/1
			]
			; wait before picking up the result
			wait 2

			result2: write ideone-url reduce ['SOAP (
					reword soap-response-template reduce [
						'user user
						'pass pass
						'link link/1
					]
				)
			]
			;print "reached result2"
			;probe decode 'markup result2
			if result2 [
				if parse decode 'markup result2 [
					thru "source" </key>
					thru <value xsi:type="xsd:string"> copy inputs to </value>
					thru "output" </key>
					thru <value xsi:type="xsd:string"> copy output to </value> to end
				] [
					?? inputs
					?? output
					reply message-id rejoin [
						"    RebolBot uses http://ideone.com (c) http://sphere-research.com" newline
						"    " decode-xml inputs/1 newline
						"    " decode-xml output/1
					]
				]
			]
		]
	]
]


speak-private: func [message room-id] [
	bind write-chat-block 'room-id
	probe rejoin compose copy write-chat-block
	to string! write rejoin compose copy write-chat-block compose/deep copy/deep [
		POST
		[(header)]
		(rejoin ["text=" url-encode message "&fkey=" bot-fkey])
	]
]

speak: func [message /local err] [
	if error? set/any 'err try [
		to string! write chat-target-url compose/deep copy/deep [
			POST
			[(header)]
			(rejoin ["text=" url-encode message "&fkey=" bot-fkey])
		]
	] [
		mold err
	]
]

read-messages: func [cnt] [
	to string! write read-target-url compose/deep copy/deep [
		POST
		[(header)]
		(rejoin ["since=0&mode=Messages&msgCount=" cnt "&fkey=" bot-fkey])
	]
]

reply: func [message-id text [string! block!]] [
	if block? text [text: ajoin text]
	speak ajoin [":" message-id " " text]
]

provide-help: func [message-id] [
	reply message-id {I respond to these commands:
delete [ silent ] "in reply to a bot message will delete if in time"
do expression "evaluates Rebol expression in a sandboxed interpreter (/x)"	
find descript [string! word!] "shows links with description containing descript"
help "this help (/? and /h)"
keys "returns known keys (/k)"
present[?] "prints users currently online"
remove key "removes key (authorized user) (/rm)"
save my details url! [ timezone [time!]] "saves your details with url +/- timezone"
save key [string! word!] description [string!] link [url!] "save key with description and link (/s)"
show [all ][ recent ] links by user "shows links posted in messages by user"
show links [ like url ] "shows saved links"
show me your youtube videos "shows saved youtube videos"
who is user "returns user details and page"
whom do you know "returns a list of all known users"
? key [ for user | @user ] "Returns link and description"
version "version of bot (/v)"
}
]

show-keys: func [message-id /local tmp out] [
	tmp: copy [] out: copy ""
	foreach [key data] bot-expressions [
		repend tmp [key data/1]
	]
	sort/skip tmp 2
	foreach [key description] tmp [
		repend out ajoin [key { "} description {"^/}]
	]
	reply message-id compose ["I know the following keys: ^/" (out)]
]

save-key: func [message-id content [string! block!] /local exp err] [
	if error? err: try [
		exp: to block! content
		?? exp
		either all [
			any [string? exp/1 word? exp/1]
			exp/1: trim to string! exp/1
			3 <= length? exp/1 ; no keywords of 1 2 characters
			string? exp/2
			url? exp/3
		] [
			print "okay to add"
			either not find bot-expressions exp/1 [
				print "adding"
				append bot-expressions exp/1
				repend/only bot-expressions [exp/2 exp/3]
				save expressions bot-expressions
				reply message-id ["added key: " exp/1]
			] [
				reply message-id [exp/1 " is already a key"]
			]
		] [
			reply message-id [content " can not be saved as key"]
		]
	] [
		probe mold err
		reply message-id mold err
	]
]

remove-key: func [message-id person person-id [integer!] content users [block!]
	/local rec
] [
	either find users person-id [
		; privileged user
		either rec: find bot-expressions content [
			remove/part rec 2
			save expressions bot-expressions
			reply message-id ["removed " content]
		] [
			reply message-id [content " not found in my keys"]
		]
	] [
		reply message-id ["Sorry, " person " you don't have the privileges yet to remove the key " content]
	]
]

evaluate-expression: func [message-id expression
	/r2 "rebol2"
	/boron "boron"
	/red "RED"
	/local output html error-url exp execute-url
] [
	output: html: error-url: none
	execute-url: select remote-execution-url
	case [
		r2 ['rebol2]
		boron ['boron]
		red ['red]
		true ['rebol3]
	]

	print ["attempting evaluation at: " execute-url]
	html: to string! write execute-url compose [POST (expression)]
	parse html [thru <span> thru <pre> copy output to </pre>]
	output: decode-xml output
	; if an error, remove part of the error string and parse out the help page
	if find output "*** ERROR" [
		replace output "try do either either either -apply-" ""
		parse html [thru {<a href="} copy error-url to {"}]
	]
	; indent 4 spaces ... needed for markup to be code
	replace/all output "^/" "^/    "
	speak ajoin [
		"    ; Brought to you by: " http://tryrebol.esperconsultancy.nl newline
		"    "
		either found? error-url [
			ajoin ["; " error-url newline "    "]
		] [""]
		">> " trim expression newline
		"    " output
	]
	?? expression
]

was-about-users: [
	earl [https://github.com/earl 1:00]
	graham [https://github.com/gchiu/ 13:00]
	ladislav [https://github.com/ladislav 1:00]
	rgchris [http://reb4.me/ none]
	hostilefork [http://hostilefork.com/ -5:00]
	brianH [https://github.com/BrianHawley -5:00]
	dockimbel [https://github.com/dockimbel 1:00]
	cyphre [https://github.com/cyphre 1:00]
]

either exists? notable-persons-file [
	about-users: load notable-persons-file
	; check for old style file
	if url! = type? about-users/2 [
		use [tmp tz rec] [
			tmp: copy about-users
			clear head about-users
			foreach [user url] tmp [
				append about-users user
				tz: either rec: select was-about-users user [
					rec/2
				] [none]
				repend/only about-users [url tz]
			]
			save notable-persons-file about-users
		]
	]
] [
	about-users: copy was-about-users
]

;; -- compile a list of known people
either not exists? visitors-file [
	visitors: copy []
	foreach [user data] about-users [
		append visitors form user
	]
	save visitors-file visitors
] [
	visitors: load visitors-file
]

; pass the message to delete
; delete-url: [ so-chat-url 'messages "/" (message-id) 'delete ] 
delete-message: func [parent-id message-id /silent
	/local result mess
] [
	mess: rejoin compose copy delete-url
	?? mess
	result: to string! write mess: rejoin compose copy delete-url compose/deep copy/deep [
		POST
		[(header)]
		(rejoin ["fkey=" bot-fkey])
	]
	if not silent [
		switch/default result [
			{"It is too late to delete this message"} [reply message-id ["sorry, it's too late to do this now.  Be quicker next time"]]
			{"ok"} [reply message-id ["done"]]
		] [
			reply message-id ["SO says: " result]
		]
	]
]

add-user-details: func [message-id person user-url timezone [time! none!]
	/local rec
] [
	attempt [
		person: to word! person
		if rec: find about-users person [
			remove/part rec 2
		]
		repend about-users person
		repend/only about-users [user-url timezone]
		save notable-persons-file about-users
		reply message-id ajoin ["Added " person "'s details"]
	]
]

; silent is used by the forever loop to update the users online
who-is-online: func [message-id
	/silent
	/local out page username userid len newbies addressees
] [
	addressees: copy ""
	len: length? visitors
	out: copy []
	newbies: copy []
	page: to string! read html-url
	parse page [
		some [
			thru "chat.sidebar.loadUser(" copy userid some id-rule thru {("} copy username to {")}
			(trim/all username
				username: decode-xml username
				append out username
				if not find visitors username [
					append visitors username
					append newbies username
				]
			)
		]
		to end
	]
	either empty? out [
		reply message-id "can not parse the page for users"
	] [
		either not silent [
			reply message-id form out
		] [
			; silent scan has detected new users - so let's greet them
			if not empty? newbies [
				foreach person newbies [
					append addressees ajoin ["@" person " "]
				]
				speak ajoin [addressees " " greet-message]
			]
		]
		if len < length? visitors [
			save visitors-file visitors
		]
	]
]

show-all-users: func [message-id
	/local tmp
] [
	tmp: copy []
	foreach [user address] about-users [
		append tmp user
	]
	reply message-id join "I know something of the following people: " form sort tmp
]

; person is the one asking the question
show-user-page: func [message-id user person /local data known timezone gmt err] [
	gmt: now
	gmt/zone: 0:00
	gmt: gmt - now/zone
	known: false
	user: to string! user
	attempt [trim/all person known: find about-users to word! person]
	if #"?" = last user [remove back tail user]
	if error? set/any 'err try [
		either data: select about-users to word! user [
			reply message-id ajoin [
				"I know this about [" user "](" data/1 ") and their local time is "
				either time? timezone: data/2 [gmt + timezone] [
					"unknown."
				]
			]
		] [
			reply message-id ["Sorry, I don't know anything about " user " yet."]
		]
		if not known [
			reply message-id ["I'd like to know about you!  Use the 'save my details' command"]
		]
	] [
		probe err
	]
]

; find-in-links message-id form findstring
find-in-links: func [message-id findstring
	/local out used link
] [
	either 3 > length? findstring [
		reply message-id "Find string needs to be at least 3 characters"
	] [
		out: copy ""
		used: copy []
		foreach [key data] bot-expressions [
			if all [
				not find used data/2
				find data/1 findstring
			] [
				link: ajoin ["[" data/1 "](" data/2 "); "]
				either chat-length-limit < add length? out length? link [
					reply message-id out
					wait 2
					out: copy link
				] [
					append out link
				]
				append used data/2
			]
		]
		if empty? out [out: copy "nothing found"]
		reply message-id out
	]
]

; SO chat has a 500 character limit for messages with active links
; so let's send in 500 ( chat-length-limit ) char chunks
; this should be a refinement of show-similar-links
show-all-links: func [message-id /local out link used] [
	out: copy ""
	used: copy []
	foreach [key data] bot-expressions [
		if not find used data/2 [
			link: ajoin ["[" data/1 "](" data/2 "); "]
			either chat-length-limit < add length? out length? link [
				; over chat-length-limit so send what we have
				reply message-id out
				wait 2
				out: copy link
			] [append out link]
			append used data/2
		]
	]
	wait 2
	if empty? out [out: copy "nothing found"]
	reply message-id out
]

show-similar-links: func [message-id links /local out link tot used] [
	print "in the simlar links function now"
	out: copy ""
	used: copy []
	foreach [key data] bot-expressions [
		if not find used data/2 [
			if find/part data/2 links length? links [
				link: ajoin ["[" data/1 "](" data/2 "); "]
				; if adding a new link exceeds allowed, then send current
				either chat-length-limit < tot: add length? out length? link [
					reply message-id out
					wait 2
					; and reset out to the new link
					out: copy link
				] [
					append out link
				]
				append used data/2
			]
		]
	]
	wait 2
	;?? out
	if empty? out [out: copy "nothing found"]
	reply message-id out
]

reply-time: func [message-id] [
	reply message-id to-idate now
]

process-dialect: funct [message-id person person-id expression
] [
	show-rule: [
		'show any ['me | 'all]
		[
			'links (show-urls: true) opt ['like set links url! (similar: true)] |
			'your 'youtube 'videos (youtube: true)
		]
	]
	whois-rule: [
		[some ['who 'is | 'whois | 'who 'the 'dickens 'is] copy user to end
		] (if found? user [show-user-page message-id user/1 person] done: true)
	]
	whom-rule: ['whom 'do 'you ['know | 'know?] (show-all-users message-id done: true)]
	save-rule: [
		(print "save rule"
			trim/all person
		)
		'save 'my 'details set user-url url! (
			?? user-url
			add-user-details message-id person user-url none
			done: true
		) set user-timezone time! (
			add-user-details message-id person user-url user-timezone
		)
	]
	save-key-rule: ['save copy expression to end (done: true save-key message-id expression)]
	do-rule: ['do copy expression to end
		(done: true
			attempt [
				evaluate-expression message-id mold/only expression
			]
		)
	]
	do2-rule: [['do/2 | 'do/rebol2] copy expression to end
		(done: true
			attempt [
				evaluate-expression/r2 message-id mold/only expression
			]
		)
	]
	do-boron-rule: ['do/boron copy expression to end
		(done: true
			attempt [
				evaluate-expression/boron message-id mold/only expression
			]
		)
	]
	do-red-rule: ['do/red copy expression to end
		(done: true
			attempt [
				evaluate-expression/red message-id mold/only expression
			]
		)
	]
	do-ideone-rule: ['do/ideone [set language word! | set language string! | set language integer!] copy expression to end
		(done: true
			attempt [
				probe mold/only expression
				evaluate-by-ideone message-id ideone-user ideone-pass mold/only expression language ""
			]
		)
	]
	version-rule: [
		'version (done: true reply message-id ajoin [system/script/header/version " " last system/script/header/date])
	]
	help-rule: ['help (done: true provide-help message-id)]
	key-rule: ['keys (done: true show-keys message-id)]
	remove-key-rule: [; remove-key message-id person person-id expression privileged-users
		'remove copy expression to end (
			done: true
			?? message-id
			?? person
			?? person-id
			?? expression
			remove-key message-id person person-id form expression privileged-users
		)
	]
	greet-rule: [copy greeting ['hello | 'goodbye | 'morning] (reply message-id [greeting " to you too"] done: true)]
	default-rule: [
		; default .. checks for a word and sends it to the check-keys
		[set search-key word! | set search-key string!] opt ['for set recipient word!] (
			done: true
			?? search-key
			?? recipient
			either found? recipient [
				recipient: ajoin ["@" recipient]
			] [
				recipient: copy ""
			]
			process-key-search message-id trim ajoin [search-key " " recipient]
		)
	]
	search-key-rule: [
		'? default-rule
	]
	delete-rule: [
		'delete (done: true silent: false)
		opt [copy silent word!] (
			either all [block? silent silent/1 = 'silent] [
				delete-message/silent parent-id message-id
			] [
				print "not calling silent"
				delete-message parent-id message-id
			]
		)
	]
	time-rule: [
		'what 'is 'the ['time | 'time?] opt ['now? | 'now | 'in 'GMT]
		(done: true reply-time message-id)
	]

	life-rule: [
		'what 'is 'the 'meaning 'of ['life | 'life?] (done: true
			reply message-id "42"
		)
	]

	show-links-by-rule: [
		opt 'show opt 'me opt 'recent 'links ['by | 'from] [set username word! | set username string!] (
			done: true
			find-links-by message-id max-scan-messages username
		)
	]

	private-session-rule: [
		'private 'session 'in set private-room integer! (
			done: true
			attempt [
				reply message-id "OK, coming"
				wait 2
				speak-private "hello" private-room
			]
		)
	]

	find-rule: [
		'find [set findstring string! | set findstring word!] (
			done: true
			find-in-links message-id form findstring
		)
	]

	who-is-online-rule: [
		['present | 'present?] (
			done: true
			who-is-online message-id
		)
	]

	dialect-rule: [
		(recipient: none)
		show-links-by-rule |
		show-rule |
		whois-rule |
		whom-rule |
		save-rule |
		save-key-rule |
		search-key-rule |
		do-rule | do2-rule | do-boron-rule | do-red-rule | do-ideone-rule |
		version-rule |
		help-rule |
		key-rule |
		remove-key-rule |
		greet-rule |
		delete-rule |
		time-rule |
		life-rule |
		private-session-rule |
		find-rule |
		who-is-online-rule |
		default-rule
	]

	show-urls: similar: links: youtube: done: false
	tmp: copy ""
	if error? err: try [
		; what to do about illegal rebol values eg @Graham
		if error? err2: try [
			to block! expression
		] [
			if find mold err2 {arg1: "email"} [
				replace/all expression "@" "for "
			]
		]
		parse expression: to block! expression dialect-rule
		;?? expression
		;?? similar
		;?? show-urls
		case [
			similar [
				show-similar-links message-id links
			]
			show-urls [
				show-all-links message-id
			]
			youtube [
				show-similar-links message-id https://www.youtube.com
				wait 2
				show-similar-links message-id http://www.youtube.com
			]
			done []
			; true [ reply message-id [ "Sorry, don't understand " expression ]]
			; replace by using Eliza
			true [
				reply message-id eliza/match mold expression
			]
		]
	] [
		; sends error
		; reply message-id mold err
		; now uses Eliza
		reply message-id eliza/match mold expression
	]
]

process-bot-cmd: func [person person-id message-id cmd expression] [
	switch/default cmd [
		"?" "h" [provide-help message-id]
		"d" [process-dialect message-id person person-id expression]
		"k" [show-keys message-id]
		"rm" [remove-key message-id person person-id expression privileged-users]
		"s" [save-key message-id expression]
		"v" [reply message-id form system/script/header/version]
		"x" [attempt [evaluate-expression message-id expression]]
	] [
		; unknown command - object
		; reply message-id [ cmd " is not in my repertoire yet." ]
		reply message-id eliza/match mold expression
	]
]

process-key-search: func [message-id expression
	/local understood search-key person
] [
	understood: false
	set [search-key person] parse expression none
	unless all [
		person
		parse person ["@" to end]
	] [person: none]
	; remove punctuation of ! and ?
	if find [#"!" #"?"] last search-key [remove back tail search-key]
	foreach [key data] bot-expressions [
		if find/part key search-key length? search-key [
			understood: true
			reply message-id ["[" data/1 "](" data/2 ") " either found? person [person] [""]]
			break
		]
	]
	if not understood [
		;reply message-id [ {sorry "} expression {" is not in my current repertoire.  Try /h for help} ]
		reply message-id eliza/match mold expression
	]
]

; cmd is k, rm, s etc, and expression is either "" or something like "print 1 + 2"
bot-cmd-rule: [
	botname
	some space
	[
		"/" copy cmd some non-space [
			end (expression: copy "") |
			some space copy expression to end (trim expression)
		] (
			process-bot-cmd user-name person-id message-id cmd expression)
		| ; some keyword or dialected command follows
		copy key to end (
			; process-key-search message-id trim key
			process-dialect message-id user-name person-id key
		)
	]
]

message-rule: [
	<event_type> quote 1 |
	<time_stamp> integer! |
	<content> set content string! |
	<id> integer! |
	<user_id> set person-id integer! |
	<user_name> set user-name string! |
	<room_id> integer! |
	<room_name> string! |
	<message_id> set message-no integer! |
	<parent_id> set parent-id integer! |
	<show_parent> logic! |
	tag! skip |
	end
]

result: messages: parent-id: none
; lastmessage-no: 7999529

read-messages-by: func [n username
	/local result messages wanted user
] [
	wanted: copy []
	username: form username
	result: load-json/flat read-messages n
	messages: result/2
	foreach msg messages [
		if parse msg [some [thru <content> copy content string! | thru <user_name> copy user string! to end]] [
			if user/1 = username [
				; found a message we want
				append wanted content
			]
		]
	]
	wanted
]

find-links-by: func [message-id n username
	/local result links link ilink text payload
] [
	links: copy []
	result: read-messages-by n username
	; now have a block of messages by username
	; {this is a link <a href="http://www.rebol.com" rel="nofollow">rebol tech</a> that I want to see}
	;["this is a link " <a href="http://www.rebol.com" rel="nofollow"> "rebol tech" </a> " that I want to see"]
	;{<a href="http://www.rebol.com">text</a>}
	;  [<a href="http://www.rebol.com"> "text" </a>]
	foreach content result [
		; grab all links from the message
		parse decode 'markup to binary! decode-xml content [
			some [
				opt string!
				set link tag!
				set text string!
				</a> (
					if parse form link [thru {a href="} copy ilink to {"} to end] [
						repend links [text ilink]
					]
				)
				opt string!
			]
		]
	]

	; we have all the links
	either empty? links [
		reply message-id ["No links found in the last " n " messages."]
	] [
		payload: rejoin [username " in the last " n " messages wrote the following links: "]
		foreach [text link] links [
			link: rejoin ["[" text "](" link "); "]
			either chat-length-limit < add length? payload length? link [
				reply message-id payload
				wait 2
				payload: copy link
			] [
				append payload link
			]
		]
		reply message-id payload
	]
]

cnt: 0 ; rescan for new users every 10 iterations ( for 5 seconds, that's 50 seconds )
forever [
	++ cnt
	if error? set/any 'errmain try [
		result: load-json/flat read-messages no-of-messages
		messages: result/2
		; now skip thru each message and see if any unread
		foreach msg messages [
			content: user-name: none message-no: 0
			?? msg
			either parse msg [some message-rule] [
				print "parsed"
				?? parent-id
			] [print "failed"]
			message-id: message-no
			content: trim decode-xml content
			?? content
			?? user-name
			?? person-id
			?? message-no
			?? lastmessage-no
			; new message?
			if message-no > lastmessage-no [
				print "New message"
				save last-message-file lastmessage-no: message-no
				; {<div class='full'>@RebolBot /x a: "Hello" <br> print a</div>}
				; <content> {<div class='full'>@rebolbot <br> print &quot;ehll&quot;</div>}
				parse content [
					<div class='full'> opt space copy content to </div>
					(
						if parse content [botname #" " <br> to end] [
							; treat a newline after botname as a do-rule
							replace content <br> "do "
						]
						replace/all content <br> " " trim content
					)
				]
				if parse content bot-cmd-rule [
					print "message for me, we should have dealt with it in the parse rule"
				]
			]
		]
	] [
		probe mold errmain
	]
	if cnt >= 10 [
		cnt: 0
		; scan the html page, check to see who is here, and send a greet message to new users
		who-is-online/silent 0
	]
	wait pause-period
]

halt


