Rebol [
	file: %prot-imap.r
	author: "Graham Chiu"
	rights: 'BSD
	version: 0.0.5
	date: [17-Jan-2010 .. 20-Jan-2010]
	notes: {
		see various scripts at end
	}
]

locals?: func [mbox] [
	probe mbox/state/connection/locals
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

alpha: charset [#"a" - #"z" #"A" - #"Z"]
digit: charset [#"0" - #"9"]
digits: [some digit]

; increment the token used to track messages
incr-generator: func [port /local stem num] [
	parse port/locals/generator [copy stem 1 alpha copy num to end]
	num: to-integer num
	num: 10001 + num
	port/locals/generator: join stem next form num
]

; writes data to the port by converting to binary and adding a crlf
cmd-write: funct [port [port!] data [string!]] [
	write port to-binary net-log/c join form data crlf
]

imap-do-cram-md5: func [server-data user pass /local send-data] [
	server-data: debase/base server-data 64
	send-data: reform [user
		lowercase enbase/base checksum/method/key server-data 'md5 pass 16]
	send-data: enbase/base send-data 64
]

parse-mailbox-response: func [response /local count recent t1 t2] [
	foreach line parse/all response CRLF [
		parse line ["* " [copy T1 to " EXISTS" (count: T1) | copy T2 to " RECENT" (recent: T2)]]
	]
	make object! compose [
		count: (count)
		recent: (recent)
	]
]

write-cmdport: funct [port
	/subport
	/only data
] [
	cmdport: port/state/connection
	if subport [cmdport: port]
	if only [
		append/only cmdport/locals/messages data
	]
	if all [not empty? cmdport/locals/messages 'ready = cmdport/spec/state] [
		; new state is that of the first word
		if 'SELECT = cmdport/spec/state: first data: first cmdport/locals/messages [
			cmdport/locals/mbox: form second data
		]
		cmd-write cmdport rejoin [incr-generator cmdport " " form data]
		remove cmdport/locals/messages
		; only need a 'read if this write occurs outside the awake handler?
		; read cmdport
	]
]

make-scheme [
	name: 'imap
	title: "IMAP4 Protocol"
	spec: make system/standard/port-spec-net [port-id: 143 timeout: 2]
	awake: funct [event /local client response state] [
		match-mark: funct [msg generator] [
			parse msg compose [ (generator) " OK" to end ]
			; join generator " OK" = copy/part msg 8
		]
		print ["=== Client event:" event/type]
		client: event/port
		switch event/type [
			lookup [
				; print "DNS lookup"
				open client
			]
			connect [
				net-log "connected"
				client/spec/state: 'NOTAUTH
				read client
			]
			read [
				net-log/S response: enline to-string client/data
				generator: client/locals/generator
				either any [
					msg: find/last join newline response join newline either client/spec/state = 'NOTAUTH ["* OK"] [generator] 
					client/spec/state = 'CRAM-MD5
				][
					; we enter the switch because we found the closing tag in the server response
					if msg [ trim/head/tail msg ]
					switch/default client/spec/state [
						NOTAUTH [
							case [
								find/part msg "* OK" 4 [
									net-log "switching to capability state"
									cmd-write client rejoin [incr-generator client " CAPABILITY"]
									client/spec/state: 'CAPABILITY
								]
								find/part msg "* PREAUTH" 9 [
									; preauthenticated, can bypass login
									net-log "pre-auth logged in okay"
									client/locals/mbox: "INBOX"
									cmd-write client rejoin [incr-generator client " SELECT " client/locals/mbox]
									client/spec/state: 'GET-STATUS								
								]
								true [
									; unknown server response - such as a bye or rejected login, throw a wobbly
									halt
								]
							]
						]
						
						CAPABILITY [
							; need to parse the multiline response
							foreach res parse/all response crlf [
								if all [res not empty? res] [
									either client/locals/capability [
										case [
											find client/locals/capability "AUTH=CRAM-MD5" [
												cmd-write client rejoin [incr-generator client " AUTHENTICATE CRAM-MD5"]
												client/spec/state: 'CRAM-MD5
											]
											find client/locals/capability "AUTH=PLAIN" [
												cmd-write client rejoin [incr-generator client reform [" LOGIN" client/spec/user client/spec/pass]]
												client/spec/state: 'LOGIN
											]
											;find client/locals/capability "AUTH=LOGIN" [
												; this is not correct.  To be shifted above Auth=plain when done
											;	cmd-write client rejoin [incr-generator client reform [" LOGIN" client/spec/user client/spec/pass]]
											;	client/spec/state: 'LOGIN
											;]
											;find client/locals/capability "AUTH=DIGEST-MD5" [
												; this to be done
											;]
										]
									] [
										net-log "saved capability"
										client/locals/capability: response
									]
								]
							]
						]

						LOGIN [
							either match-mark msg generator [
								net-log "Logged in okay"
								client/locals/mbox: "INBOX"
								cmd-write client rejoin [incr-generator client " SELECT " client/locals/mbox]
								client/spec/state: 'GET-STATUS
							] [
								net-log "failed login"
								; throw error
								halt
							]
						]

						GET-STATUS [
							; come here after selecting a mailbox
							either match-mark msg generator [ 
								obj: parse-mailbox-response response
								if parse obj/count digits [
									client/locals/count: to-integer obj/count
								]
								if parse obj/recent digits [
									client/locals/recent: to-integer obj/recent
								]
								client/spec/state: 'ready
								return true
							] [
								net-log "last command failed"
							]
						]

						STATUS [
							either match-mark msg generator [
								net-log "Status obtained"
								client/spec/state: 'ready
								return true
							] [
								net-log "Unable to get mailbox status"
							]
						]

						CRAM-MD5 [
							; get a response and then return the athentication string
							cmd-write client imap-do-cram-md5 skip response 2 client/spec/user client/spec/pass
							client/spec/state: 'LOGIN
						]

						SELECT [
							either match-mark msg generator [
								obj: parse-mailbox-response response
								if parse obj/count digits [
									client/locals/count: to-integer obj/count
								]
								if parse obj/recent digits [
									client/locals/recent: to-integer obj/recent
								]

								client/spec/state: 'ready
								return true
							] [
								net-log "last command failed"
							]
						]

						FETCH [
							; one continuous stream received ... look for the mark
							if match-mark msg generator [
								net-log "received mail okay"
								client/spec/state: 'ready
								return true
							]
						]

						LIST [
							if match-mark msg generator [
								net-log "recvd LIST"
								client/spec/state: 'ready
								return true
							]
						]

						READY [
							write-cmdport/subport client
						]

						LOGOUT [
							if match-mark msg generator [
								net-log "LOGOUT acked, closing port"
								client/spec/state: 'ready
								close client
								return true
							]
						]

					] [net-log join "Unknown state " client/spec/state]
				] [
					; we didn't find the closing tag, so we must be in the middle of an interrupted read, so get more data
					; shouldn't be here if responding to a challenge
					read client
				]	
			]
			wrote [read client]
			close [net-log "Port closed on me"]
			error [ net-log "error on port" return true ]
		]
		false
	]
	actor: [
		open: func [
			port [port!]
			/local conn
		] [
			if port/state [return port]
			if none? port/spec/host [http-error "Missing host address"]
			; set the port state
			port/state: context [
				state:
				connection:
				error: none
				awake: none ;:port/awake
				close?: no
			]
			; create the tcp port and set it to port/state/connection
			port/state/connection: conn: make port! [
				scheme: 'tcp
				host: port/spec/host
				port-id: port/spec/port-id
				state: 'INIT
				ref: rejoin [tcp:// host ":" port-id]
				user: either in port/spec 'user [port/spec/user] ["anonymous"]
				pass: either in port/spec 'pass [port/spec/pass] ["rebol@"]
			]
			conn/locals: context [generator: "A000" capability: mbox: count: unseen: recent: none messages: []]
			conn/awake: :awake
			open conn
			print "port opened ..."
			; return the newly created and open port
			port
		]
		open?: func [
			port [port!]
		] [
			all [port/state]
		]

		close: func [
			port [port!]
		] [
			if open? port [
				close port/state/connection
				port/state/connection/awake: none
				port/state: none
			]
			port
		]

		read: func [
			port [port!]
			/local conn
		] [
			either any-function? :port/awake [
				; unless open? port [cause-error 'Access 'not-open port/spec/ref]
				either not open? port [
					print "opening & waiting on port"
					wait open port/state/connection
				] [
					print "waiting on port"
					wait port/state/connection
				]
				port
			] [
				print "doing something sync"
				; do something synchronous here
			]
		]

		write: funct [port [port!] data [block!]] [
			write-cmdport/only port data
			read port/state/connection
		]

		length?: func [port [port!]] [
			return port/state/connection/locals/count
		]

		pick: funct [mbox [port!] n [integer!]] [
			if n > length? mbox [return none]
			write mbox compose [FETCH (n) " RFC822"]
			read mbox
			return find/tail to-string mbox/state/connection/data newline
		]
		
		cwd: funct [ dir [string!]][
			write mbox compose [ SELECT (dir) ]
			read mbox
		]

	]
]

cwd: func [ mbox [port!] dir [string!]][
	if in mbox/scheme/actor 'cwd [
		mbox/scheme/actor/cwd dir
	]
]

halt

mbox: open imap://user:pass@imapserver.com
read mbox

print ["Message count: " length? mbox]


	halt

write mbox [FETCH 1 RFC822]
read mbox
write mbox [FETCH 2 RFC822]
read mbox


write mbox [FETCH 3 RFC822]
read mbox

write mbox [LIST {"" "*"}]
read mbox

write mbox [SELECT inbox]
read mbox
e: pick mbox 1

;halt

;write mbox [SELECT gmail]
;read mbox
write mbox [STATUS {"inbox" (unseen)}]
read mbox
write mbox [STATUS {"inbox" (recent)}]
read mbox
write mbox [STATUS {"inbox" (messages)}]
read mbox
write mbox [SELECT inbox]
read mbox
e: pick mbox 1
print "test run completed"
