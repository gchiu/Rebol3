Rebol [
	file: %rebolbot.r3
	author: "Graham"
	date: 28-Feb-2013
	version: 0.0.5
	purpose: {post messages into the Rebol-red chat room on Stackoverflow}
	Notes: {You'll need to capture your own cookie and fkey using wireshark or similar.}
]
; load some utilities
if not value? 'load-json [
	do http://reb4.me/r3/altjson
]
if not value? 'decode-xml [
	do http://reb4.me/r3/altxml
]

bot-cookie: {-get-your-own-}
bot-fkey: "-get-your-own-"

pause-period: 5 ; 7 seconds
no-of-messages: 5 ; fetch 5 messages each time

expressions: %bot-expressions.r

; lastmessage-no:  7973980
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
	"help" [ "FAQ" http://rebolsource.net/go/chat-faq ]
	"tutorial" [ "Introduction to Rebol" http://www.rebol.com/rebolsteps.html ]
	"Devcon" [ "Red Video from Devcon 2013" https://www.youtube.com/watch?v=JjPKj0_HBTY ]
]
; save expressions bot-expressions

if exists? expressions [
	bot-expressions: load expressions
]

;- configuration urls
chat-target-url: http://chat.stackoverflow.com/chats/291/messages/new 
read-target-url: http://chat.stackoverflow.com/chats/291/events
referrer-url: "http://chat.stackoverflow.com/rooms/291/rebol-and-red"
remote-execution-url: http://somewhere.com/cgi/script ;;<<=== need your own

; config botname
botname: "@RebolBot"
bot-len: length? botname

space: charset #" "

; these users can remove keys
priviledged-users: [ "BrianH" "HostileFork" "Graham Chiu" "rgchris" "Adrian" ] 

url-encode: func [
    "URL-encode a string" 
    data "String to encode" 
    /local new-data
] [
    new-data: make string! "" 
    normal-char: charset [
        #"A" - #"Z" #"a" - #"z" 
        #"." #"*" #"-" #"_" 
        #"0" - #"9"
    ] 
    if not string? data [return new-data] 
    forall data [
        append new-data either find normal-char first data [
            first data
        ] [
			join "%" copy/part tail to string! to-hex to integer! first data -2
        ]
    ] 
    new-data
] 

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

speak: func [ message ][
	result: to string! write chat-target-url compose/deep  copy/deep [
		POST
		[ 	(header) ]
		(rejoin [ "text=" url-encode message "&fkey=" bot-fkey ])
	]	
]

read-messages: func [ cnt ][
	to string! write read-target-url compose/deep  copy/deep [
		POST
		[ 	(header) ]
		(rejoin [ "since=0&mode=Messages&msgCount=" cnt "&fkey=" bot-fkey ])
	]	
]

reply: func [ message-id  text [string! block!] ][
	if block? text [ text: ajoin text ]
	speak ajoin [ ":" message-id " " text ]
]

provide-help: func [ message-id ][
	reply message-id {I know these other commands: ^//k "returns known keys" ^//rm key "removes key (authorised user)" ^//s key [string!] description [string!] link [url!] "save key with description and link" ^//v "returns version of script" ^//x value "evaluates a Rebol value in a sandboxed interpreter"}
]
							
show-keys: func [ message-id /local tmp ][
	tmp: copy []
	foreach [ key data ] bot-expressions [
		append tmp key
	]
	sort tmp
	reply message-id compose [ "I know the following keys: " (form tmp)]
]

save-key: func [ message-id content /local exp err ][
	if error? set/any 'err try [
		exp: to block! content
		either all [
			string? exp/1
			3 <= length? exp/1 ; no keywords of 1 2 characters
			string? exp/2
			url? exp/3
		][
			print "okay to add"
			either not find bot-expressions exp/1 [
				print "adding"
				append bot-expressions exp/1 
				repend/only bot-expressions [ exp/2 exp/3 ]
				save expressions bot-expressions
				reply message-id  [ "added key: " exp/1 ]
			][
				reply message-id  [ exp/1 " is already a key" ]
			]
		][
			reply message-id  [ content " can not be saved as key" ]
		]
	][
		reply message-id mold disarm err 
	]
]

remove-key: func [ message-id person content users
	/local rec
][
	either find users person [
		; priviledged user
		either rec: find bot-expressions content [
			remove/part rec 2
			save expressions bot-expressions
			reply message-id   ["removed " content]
		][
			reply message-id   [ content " not found in my keys" ]					
		]		
	][
		reply message-id "Sorry, you don't have those priviledges yet."
	]
]

evaluate-expression: func [ message-id expression
	/local output html error-url		
][
	output: html: error-url: none
	print "attempting evaluation"
	html: to string! write remote-execution-url compose [ POST (expression) ]
	parse html [ thru <span> "Last result:" thru <pre> copy output to </pre> ]
	output: decode-xml output
	; if an error, remove part of the error string and parse out the help page
	if find output "*** ERROR" [
		replace output "try do either either either -apply-" ""
		parse html [ thru {<a href="} copy error-url to {"} ]
	]
	; indent 4 spaces ... needed for markup to be code
	replace/all output "^/" "^/    "
	speak ajoin [ 
		"    ; Brought to you by: " http://tryrebol.esperconsultancy.nl newline 
		"    " 
		either found? error-url [ 
			ajoin [ "; " error-url newline "    "]
		][""] 
		">> " trim expression newline 
		"    " output
	]
	?? expression
]	

process-bot-cmd: func [ person message-id cmd expression ][
	switch/default cmd [
		"?" "h" [ provide-help message-id ]
		"k" [ show-keys message-id ]
		"rm" [ remove-key message-id person expression priviledged-users ]
		"s" [ save-key message-id expression ]
		"v" [ reply message-id  form system/script/header/version ]
		"x" [ attempt [ evaluate-expression message-id expression ]]
	][  
		; unknown command - object
		reply message-id [ cmd " is not in my repertoire yet." ]
	]
]

process-key-search: func [ message-id expression 
	/local understood search-key person
][
	?? message-id
	?? expression
	understood: false
	set [ search-key person ] parse expression none
	unless all [
		person
		parse person [ "@" to end ]
	][ person: none ]
	?? person
	?? search-key
	; remove punctuation of ! and ?
	if find [ #"!" #"?" ] last search-key [ remove back tail search-key ]
	foreach [ key data ] bot-expressions [
		if find/part key search-key length? search-key [
			understood: true
			reply message-id [ "[" data/1 "](" data/2 ") " either found? person [ person]["" ] ]
			break
		]
	]
	if not understood [
		reply message-id [ "sorry {" expression "} is not in my current repertoire.  Try /h for help" ]
	]
]

non-space: complement charset #" "

; cmd is k, rm, s etc, and expression is either "" or something like "print 1 + 2"
bot-cmd-rule: [
	botname 
	some space 
	[
		"/" copy cmd some non-space [ 
			end (expression: copy "" ) | 
			some space copy expression to end (trim expression)
		] (
			process-bot-cmd person message-id cmd expression )
	|	; some keyword follows
		
		copy key to end (
			process-key-search message-id trim key
		)
	]
]

message-rule: [ 
	<event_type> quote 1  |
	<time_stamp> integer! |
	<content> set content string! |
	<id> integer! |
	<user_id> integer! |
	<user_name> set user-name string! |
	<room_id> integer! |
	<room_name> string! |
	<message_id> set message-no integer! |
	<parent_id> integer! |
	<show_parent> logic! |
	tag! skip |
	end 
]

result: messages: none
; lastmessage-no: 7999529

forever [
	attempt [
		result: load-json/flat read-messages no-of-messages
		messages: result/2
		; now skip thru each message and see if any unread
		foreach msg messages [
			content: user-name: none message-no: 0
			?? msg
			either parse msg [ some message-rule ][
				print "parsed"
			][ print "failed" ]
			message-id: message-no
			content: trim decode-xml content
			?? content
			?? user-name
			?? message-no
			?? lastmessage-no
			; new message?
			if message-no > lastmessage-no [
				print "New message"
				save last-message-file lastmessage-no: message-no
				if parse content bot-cmd-rule [
					print "message for me, we should have dealt with it in the parse rule"
				]
			]
		]
	]
	wait pause-period
]

halt


