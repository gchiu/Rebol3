Rebol [
	file: %rebolbot.r3
	author: "Graham"
	date: [ 28-Feb-2013 4-Mar-2013 ]
	version: 0.0.13
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

chat-length-limit: 500 ; SO chat limits to 500 chars if a message contains a link

bot-cookie: {-get-your-own-}
bot-fkey: "-get-your-own-"

pause-period: 5 ; 7 seconds
no-of-messages: 5 ; fetch 5 messages each time

; these users can remove keys - should at some stage be changed to using userids which are guaranteed to be unique
privileged-users: [ "BrianH" "HostileFork" "Graham Chiu" "GrahamChiu" "rgchris" "Adrian" ] 

; data files we keep
expressions: %bot-expressions.r
notable-persons-file: %known-users.r
last-message-file: %lastmessage-no.r
bot-config-file: %bot-config.r 

;- configuration urls
remote-execution-url: http://--use--your-own--here--

lastmessage-no:  7973980 ; or 0 if you wish

if exists? last-message-file [
	attempt [
		lastmessage-no: load last-message-file
	]
]

?? lastmessage-no

; save/all %bot-config.r make object! compose [ bot-fkey: (bot-fkey) bot-cookie: (bot-cookie) ]
if exists? bot-config-file [
	bot-config: load bot-config-file
	bot-cookie: bot-config/bot-cookie
	bot-fkey: bot-config/bot-fkey
]

; some defaults - overwrite these when we read the saved ones
bot-expressions: [
	"help" [ "FAQ" http://rebolsource.net/go/chat-faq ]
	"tutorial" [ "Introduction to Rebol" http://www.rebol.com/rebolsteps.html ]
	"Devcon" [ "Red Video from Devcon 2013" https://www.youtube.com/watch?v=JjPKj0_HBTY ]
]
; save expressions bot-expressions

if exists? expressions [
	bot-expressions: load expressions
]

; set these to the room you're in
room-id: 291
room-descriptor: "rebol-and-red"

so-chat-url: http://chat.stackoverflow.com/ 
chat-target-url: rejoin [ so-chat-url 'chats "/" room-id "/" 'messages/new  ]
referrer-url: rejoin [ so-chat-url 'rooms "/" room-id "/" room-descriptor ]
read-target-url: rejoin [ so-chat-url 'chats "/" room-id "/" 'events ]
delete-url: [ so-chat-url 'messages "/" (parent-id) "/" 'delete ] 

; config botname
botname: "@RebolBot"

non-space: complement space: charset #" "

percent-encode: func [char [char!]][
        char: enbase/base to-binary char 16
        parse char [
            copy char some [char: 2 skip (insert char "%") skip]
        ]
        char
    ]

url-encode: use [ch mk][
    ch: charset ["-." #"0" - #"9" #"A" - #"Z" #"-" #"a" - #"z" #"~"]
     func [text [any-string!]][
        either parse/all text: form text [
            any [
                some ch | end | change " " "+" |
                mk: (mk: percent-encode mk/1)
                change skip mk
            ]
       ][to-string text][""]
    ]
]

; updated to remove the /local pad
to-itime: func [
    {Returns a standard internet time string (two digits for each segment)}
		time [time! number! block! none!]
	][
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
][
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

speak: func [ message ][
	to string! write chat-target-url compose/deep  copy/deep [
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
	reply message-id {I respond to these commands:
delete "removes replied to message"
do expression "evaluates Rebol expression in a sandboxed interpreter (/x)"	
help "this help (/? and /h)"
keys "returns known keys (/k)"
remove key "removes key (authorised user) (/rm)"
save my details url! "saves your details with url"
save key [string! word!] description [string!] link [url!] "save key with description and link (/s)"
show links [ like url ] "shows saved links"
show me your youtube videos "shows saved youtube videos"
who is user "returns user details and page"
whom do you know "returns a list of all known users"
? key [ for user | @user ] "Returns link and description"
version "version of bot (/v)"
what is the time "returns bot's local time"
}
]
	
show-keys: func [ message-id /local tmp ][
	tmp: copy []
	foreach [ key data ] bot-expressions [
		append tmp key
	]
	sort tmp
	reply message-id compose [ "I know the following keys: " (form tmp)]
]

save-key: func [ message-id content [string! block!] /local exp err ][
	if error? err: try [
		exp: to block! content
		either all [
			any [ string? exp/1 word? exp/1 ]
			exp/1: to string! exp/1
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
		probe mold err
		reply message-id mold err 
	]
]

remove-key: func [ message-id person content users
	/local rec
][
	either find users person [
		; privileged user
		either rec: find bot-expressions content [
			remove/part rec 2
			save expressions bot-expressions
			reply message-id   ["removed " content]
		][
			reply message-id   [ content " not found in my keys" ]					
		]		
	][
		reply message-id "Sorry, you don't have those privileges yet."
	]
]

evaluate-expression: func [ message-id expression
	/local output html error-url exp
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

; can put your own here
about-users: [
	earl https://github.com/earl
	graham https://github.com/gchiu/
	ladislav https://github.com/ladislav
	rgchris http://reb4.me/
	hostilefork http://hostilefork.com/
	brianH https://github.com/BrianHawley
	dockimbel https://github.com/dockimbel
	cyphre https://github.com/cyphre
]

if exists? notable-persons-file [
	about-users: load notable-persons-file
]

; pass the message to delete
delete-message: func [ parent-id message-id
	/local result mess
][
	mess: rejoin compose copy delete-url 
	result: to string! write mess: rejoin compose copy delete-url compose/deep copy/deep [
		POST
		[ 	(header) ]
		(rejoin [ "fkey=" bot-fkey ])
	]	
	switch/default result [
		{"It is too late to delete this message"} [ reply message-id ["sorry, it's too late to do this now.  Be quicker next time" ] ]
		{"ok"} [ reply message-id [ "done" ]]
	][
		reply message-id [ "SO says: " result ]
	]
]

add-user-details: func [ message-id person user-url
	/local rec
][
	attempt [
		person: to word! person
		if rec: find about-users person [
			remove/part rec 2
		]
		repend about-users [ person user-url ]
		save notable-persons-file about-users
		reply message-id ajoin [ "Added " person "'s details" ]
	]
]

show-all-users: func [ message-id 
	/local tmp
][
	tmp: copy [ ]
	foreach [ user address ] about-users [
		append tmp user
	]
	reply message-id join "I know something of the following people: " form sort tmp
]

; person is the one asking the question
show-user-page: func [ message-id user person /local link known ][
	known: false
	user: to string! user
	attempt [ trim/all person known: find about-users to word! person ]
	if #"?" = last user [ remove back tail user ]
	attempt [
		either link: select about-users to word! user [
			reply message-id ajoin [ "I know this about [" user "](" link ")" ]
		][
			reply message-id [ "Sorry, I don't know anything about " user " yet." ]
		]
		if not known [
			reply message-id [ "I'd like to know about you!  Use the 'save my details' command" ]
		]
	]
]

; SO chat has a 500 character limit for messages with active links
; so let's send in 500 ( chat-length-limit ) char chunks
; this should be a refinement of show-similar-links
show-all-links: func [ message-id /local out link used ][
	print "in the show all links function"
	out: copy ""
	used: copy []
	foreach [ key data ] bot-expressions [
	  if not find used data/2 [
		link: ajoin [ "[" data/1 "](" data/2 "); " ]
		either chat-length-limit < add length? out length? link  [
			; over chat-length-limit so send what we have
			reply message-id out
			wait 2
			out: copy link
		][ append out link ]
		append used data/2
	  ]
	]
	wait 2
	if empty? out [ out: copy "nothing found" ]
	reply message-id out			
]

show-similar-links: func [ message-id links /local out link tot used][
	out: copy ""
	used: copy [ ]
	foreach [ key data ] bot-expressions [
		if not find used data/2 [
			if find/part data/2 links length? links [
				link: ajoin [ "[" data/1 "](" data/2 "); " ]
				; if adding a new link exceeds allowed, then send current
				either chat-length-limit < tot: add length? out length? link [
					reply message-id out
					wait 2
					; and reset out to the new link
					out: copy link
				][
					append out link
				]
				append used data/2
			]
		]
	]
	wait 2
	if empty? out [ out: copy "nothing found" ]
	reply message-id out
]

reply-time: func [ message-id ][
	reply message-id to-idate now
]

process-dialect: funct [ message-id person expression
][
	show-rule: [ 
		'show any [ 'me | 'all ]
		[
			'links ( show-urls: true) opt [ 'like set links url! ( similar: true ) ] |
			'your 'youtube 'videos ( youtube: true )
		]
	]
	whois-rule: [
		[	some [ 'who 'is | 'whois | 'who 'the 'dickens 'is ] copy user to end
		] 	( if found? user [ show-user-page message-id user/1 person] done: true)	
	]
	whom-rule: [ 'whom 'do 'you 'know ( show-all-users message-id done: true) ]
	save-rule: [   
			(
				trim/all person
			)
			'save 'my 'details set user-url url! (
				add-user-details message-id person user-url
				done: true
			)
	] 
	save-key-rule: [ 'save copy expression to end ( done: true save-key message-id expression)  ] 
	do-rule: [ 'do copy expression to end 
			(  	done: true
				attempt [ 
					evaluate-expression message-id mold/only expression 
				] 
			)		
	] 
	version-rule: [
			'version ( done: true  reply message-id  form system/script/header/version )
	]
	help-rule: [ 'help ( done: true provide-help message-id ) ] 
	key-rule: [	'keys ( done: true show-keys message-id ) ] 
	remove-key-rule: [ ; remove-key message-id person expression privileged-users
		'remove copy expression to end ( done: true remove-key message-id person form expression privileged-users )
	]
	greet-rule: [ copy greeting [ 'hello | 'goodbye | 'morning ] ( reply message-id [ greeting " to you too" ] done: true )] 
	default-rule:  [
			; default .. checks for a word and sends it to the check-keys
			set search-key word! opt [ 'for set recipient word! ] (
				done: true
				either found? recipient [ 
					recipient: append "@" recipient
				][
					recipient: copy ""
				]
				process-key-search message-id trim ajoin [ search-key " " recipient ]
			)
	]
	search-key-rule: [	
		'? default-rule
	] 
	delete-rule: [
		'delete (done: true delete-message parent-id message-id )
	]
	time-rule: [ 
		'what 'is 'the [ 'time | 'time? ] opt [ 'now? | 'now | 'in 'GMT ]
		( done: true reply-time message-id )
	]
	
	dialect-rule: [
		( recipient: none )
		show-rule | 
		whois-rule |
		whom-rule |
		save-rule |
		save-key-rule |
		search-key-rule |
		do-rule |
		version-rule |
		help-rule |
		key-rule |
		remove-key-rule |
		greet-rule |
		delete-rule |
		time-rule |
		default-rule
	]

	show-urls: similar: links: youtube: done: false
	tmp: copy ""
	if error? err: try [
		; what to do about illegal rebol values eg @Graham
		if error? err2: try [
			to block! expression
		][
			if find mold err2 {arg1: "email"} [
				replace/all expression "@" "for " 
			]
		]
		
		parse expression: to block! expression dialect-rule
		?? expression
		?? similar
		?? show-urls
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
			done [ ]
			true [ reply message-id "Sorry, don't understand what you said to me" ]
		]
	][
		reply message-id mold err
	]
]

process-bot-cmd: func [ person message-id cmd expression ][
	switch/default cmd [
		"?" "h" [ provide-help message-id ]
		"d" [ process-dialect message-id person expression ]
		"k" [ show-keys message-id ]
		"rm" [ remove-key message-id person expression privileged-users ]
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
	understood: false
	set [ search-key person ] parse expression none
	unless all [
		person
		parse person [ "@" to end ]
	][ person: none ]
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
		reply message-id [ {sorry "} expression {" is not in my current repertoire.  Try /h for help} ]
	]
]

; cmd is k, rm, s etc, and expression is either "" or something like "print 1 + 2"
bot-cmd-rule: [
	botname
	some space 
	[
		"/" copy cmd some non-space [ 
			end (expression: copy "" ) | 
			some space copy expression to end (trim expression)
		] (  
			process-bot-cmd user-name message-id cmd expression )
	|	; some keyword or dialected command follows
		copy key to end (
			; process-key-search message-id trim key
			process-dialect message-id user-name key
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
	<parent_id> set parent-id integer! |
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
				?? parent-id
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
				; {<div class='full'>@RebolBot /x a: "Hello" <br> print a</div>}
				parse content [ 
					<div class='full'> opt space copy content to </div>
					( replace/all content <br> " " trim content)
				]
				if parse content bot-cmd-rule [
					print "message for me, we should have dealt with it in the parse rule"
				]
			]
		]
	]
	wait pause-period
]

halt


