Rebol [
	system: "Rebol [R3] Language interpreter"
	title: "Rebol 3 SMTP scheme"
	author: "Graham"
	date: [ 9-Jan-2010 20-Jan-2013 ]
	rights: 'BSD
	name: 'smtp
	type: 'module
	version: 0.0.1
	file: %prot-smtp.r
	notes: {
		0.0.1 original tested in 2010
		0.0.2 updated for the open source versions
		0.0.3 Changed to use a synchronous mode rather than async.  Authentication not yet supported
		
		synchronous mode
		write smtp://smtp.clear.net.nz [ 
			esmtp-user: 
			esmtp-pass: 
			ehlo: ; defaults to "Rebol PC" if a FQDN is not supplied
			from:
			name:
			to: 
			subject:
			message: 
		]

		eg: write smtp://smtp.yourisp.com compose [
			from: me@somewhere.com
			to: recipient@wher.com
			ehlo: "my-rebol-development-pc or fqdn"
			message: (message)
		]
		
		Where message is an email with all the appropriate headers.
		In Rebol2, this was constructed by the 'send function
		
		If you need to use smtp asynchronously, you supply your own awake handler
		
		p: open smtp://smtp.provider.com
		p/state/connection/awake: :my-async-handler
	}
]

mail-obj: make object! [ 
			esmtp-user: 
			esmtp-pass: 
			from:
			name:
			to: 
			subject:
			ehlo:
			message: none
]

make-smtp-error: func [
	message
][
	do make error! [
		type: 'Access
		id: 'Protocol
		arg1: message
	]
]


auth-methods: copy []
alpha: charset [#"a" - #"z" #"A" - #"Z"]
net-log: func [txt
	/C
	/S
] [
	if C [prin "C: "]
	if S [prin "S: "]
	print txt
	txt
]

sync-smtp-handler: func [ event 
		/local client response state code line-response
	] [
		line-response: none
		print ["=== Client event:" event/type]
		client: event/port
		switch event/type [
			lookup [
				; print "DNS lookup"
				open client
			]
			connect [
				net-log "connected"
				client/spec/state: 'EHLO
				read client
			]

			read [
				net-log/S response: enline to-string client/data
				code: copy/part response 3
				switch/default client/spec/state [
					INIT [
						if find/part response "220 " 4 [
							; wants me to send EHLO
							write client to-binary net-log/C rejoin ["EHLO " any [ client/spec/email/ehlo "Rebol-PC" ] CRLF]
							client/spec/state: 'AUTH
						]
					]
					EHLO [
						if find/part response "220 " 4 [
							; wants me to send EHLO
							write client to-binary net-log/C rejoin ["EHLO " any [ client/spec/email/ehlo "Rebol-PC" ] CRLF]
							client/spec/state: 'AUTH
						]
					]
					AUTH [
						if find/part response "220 " 4 [
							; wants me to send EHLO
							write client to-binary net-log/C rejoin ["EHLO " any [ client/spec/email/ehlo "Rebol-PC" ] CRLF]
						]
						; should get this massive string
						if code = "250" [
							parse/all response [
								some [
									copy line-response to CRLF (
										parse/all line-response [
											"250" ["-" | " " ( print "1" client/spec/state: first any [find auth-methods 'plain find auth-methods 'login find auth-methods 'cram])]
											["AUTH" [" " | "="]
												[
													"CRAM-MD5" (append auth-methods 'cram) |
													"PLAIN LOGIN" (append auth-methods 'plain) |
													"LOGIN" (append auth-methods 'login) |
													some alpha
												] |
												some alpha
											]
											thru CRLF
										]
									) crlf
								]
							]
						]
						if client/spec/state != 'AUTH [
							; authentication methods not supported yet .. need to find a server to test with
							switch client/spec/state [
								PLAIN [
									; not going to authenticate at present
									client/spec/state: 'FROM
									write client to-binary net-log/C rejoin ["MAIL FROM: <" client/spec/email/from ">" CRLF]
								]
								LOGIN []
								CRAM []
							]
						]
					]
					FROM [
						either code = "250" [
							write client to-binary net-log/C rejoin ["RCPT TO: <" client/spec/email/to ">" crlf]
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
							replace/all client/spec/email/message "^/." "^/.."
							write client to-binary net-log/C rejoin [ enline client/spec/email/message crlf "." crlf ]
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

sync-write: func [ port [port!] body
	/local state result
][
	unless port/state [ open port port/state/close?: yes ]
	state: port/state
	; construct the email from the specs 
	port/state/connection/spec/email: construct/with body mail-obj
	port/state/connection/awake: :sync-smtp-handler
	if state/state = 'ready [ 
		; the read gets the data from the smtp server and triggers the events that follow that is handled by our state engine in the sync-smtp-handler
		read port 
	]
	unless port? wait [ state/connection port/spec/timeout ] [ make error! "SMTP timeout" ]
	if state/close? [ close port ]
	true
]
	
sys/make-scheme [
	name: 'smtp
	title: "SMTP Protocol"
	spec: make system/standard/port-spec-net [
		port-id: 25
		timeout: 60
		email: none ;-- object constructed from argument
	]
	actor: [
		open: func [
			port [port!]
			/local conn
		] [
			if port/state [return port]
			if none? port/spec/host [
				make-smtp-error "Missing host address when opening smtp server"
			]
			; set the port state to hold the tcp port
			port/state: context [
				state:
				connection:
				error: none
				awake: none  ;-- so port/state/awake will hold the awake handler :port/awake
				close?: no   ;-- flag for us to decide whether to close the port eg in syn mode
			]
			; create the tcp port and set it to port/state/connection
			port/state/connection: conn: make port! [
				scheme: 'tcp
				host: port/spec/host
				port-id: port/spec/port-id
				state: 'INIT
				ref: rejoin [tcp:// host ":" port-id]
				email: port/spec/email
			]
			open conn ;-- open the actual tcp port
;			conn/awake: :async-smtp-handler 	
;			port/awake: :async-smtp-handler		
			
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
		] [
			either any-function? :port/awake [
				either not open? port [
					print "opening & waiting on port"
					unless port? wait [open port/state/connection port/spec/timeout] [make-smtp-error "Timeout"]
					; wait open port/state/connection
				] [
					print "waiting on port"
					unless port? wait [ port/state/connection port/spec/timeout] [make-smtp-error "Timeout"]
				]
				port
			] [
				print "No handler for the port exists yet"
				; should this be used at all for smtp?
			]
		]

		write: func [
			port [port!] body [block!]
			/local conn email
		][
			sync-write port body
		]
	]
]