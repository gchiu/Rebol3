Rebol [
	file: %prot-smtp.r
	author: "Graham"
	date: 9-Jan-2010
	rights: 'BSD
]

auth-methods: copy []
alpha: charset [#"a" - #"z" #"A" - #"Z"]
ehlo-msg: "my-r3-developement-pc"
net-log: func [txt
	/C
	/S
] [
	if C [prin "C: "]
	if S [prin "S: "]
	print txt
	txt
]

email: myemail@localisp.com
recipient: myemail@gmail.com
myname: "Joe Bloggs"

message: rejoin [ {To: } recipient {
From: } myname { <} email {>
Date: Sat, 9 Jan 2010 14:51:07 +1300
Subject: testing from r3
X-REBOL: REBOL3 Alpha

testing from r3 2}]

make-scheme [
	name: 'smtp
	title: "SMTP Protocol"
	spec: make system/standard/port-spec-net [port-id: 25]
	awake: func [event /local client response state code] [
		print ["=== Client event:" event/type]
		client: event/port
		switch event/type [
			lookup [
				; print "DNS lookup"
				open client
			]
			connect [
				net-log "connected"
				; need to write to the client to trigger flow of data
				; write client to-binary net-log/C rejoin ["EHLO " ehlo-msg CRLF]
				; write client to-binary net-log/C rejoin [ "NOOP " crlf ]
				; now ready for the next state
				client/spec/state: 'EHLO
				system/contexts/system/read client
			]
			read [
				net-log/S response: enline to-string client/data
				code: copy/part response 3
				switch/default client/spec/state [
					INIT [
						if find/part response "220 " 4 [
							; wants me to send EHLO
							write client to-binary net-log/C rejoin ["EHLO " ehlo-msg CRLF]
							client/spec/state: 'AUTH
						]
					]
					EHLO [
						if find/part response "220 " 4 [
							; wants me to send EHLO
							write client to-binary net-log/C rejoin ["EHLO " ehlo-msg CRLF]
							client/spec/state: 'AUTH
						]
					]
					AUTH [
						if find/part response "220 " 4 [
							; wants me to send EHLO
							write client to-binary net-log/C rejoin ["EHLO " ehlo-msg CRLF]
						]
						; should get this massive string
						if code = "250" [
							parse/all response [
								some [
									copy test to CRLF (
										parse/all test [
											"250" ["-" | " " (client/spec/state: first any [find auth-methods 'plain find auth-methods 'login find auth-methods 'cram])]
											["AUTH" [" " | "="]
												[
													"CRAM-MD5" (append auth-methods 'cram) |
													"PLAIN LOGIN" (append auth-methods 'plain) |
													"LOGIN" (append auth-methods 'login) |
													some alpha
												] |
												copy unwanted some alpha
											]
											thru CRLF
										]
									) crlf
								]
							]
						]
						if client/spec/state != 'AUTH [
							switch client/spec/state [
								PLAIN [
									; not going to authenticate at present
									client/spec/state: 'FROM
									write client to-binary net-log/C rejoin ["MAIL FROM: <" email ">" CRLF]
								]
								LOGIN []
								CRAM []
							]
						]
					]
					FROM [
						either code = "250" [
							write client to-binary net-log/C rejoin ["RCPT TO: <" recipient ">" crlf]
							client/spec/state: 'TO
						] [
							net-log "rejected by server"
							return true
						]
					]
					TO [
						either code = "250" [
							client/spec/state: 'DATA
							write client to-binary net-log/C join "DATA" CRLF
						] [
							net-log "server rejects TO address"
							return true
						]
					]
					DATA [
						either code = "354" [
							replace/all message "^/." "^/.."
							write client to-binary net-log/C rejoin [ enline message crlf "." crlf ]
							client/spec/state: 'END
						] [
							net-log "Not allowing us to send ... quitting"

						]
					]
					END [
						either code = "250" [
							net-log "message successfully sent."
							client/spec/state: 'QUIT
							write client to-binary  net-log/C join "QUIT" crlf
							return true
						] [
							net-log "some error occurred on sending."
							return true
						]
					]
					QUIT [
						net-log "Should never get here"
					]
				] [net-log join "Unknown state " client/spec/state]
			]
			wrote [read client]
			close [net-log "Port closed on me"]
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
			]
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
	]
]