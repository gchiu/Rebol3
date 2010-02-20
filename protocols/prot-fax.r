Rebol [
	file: %prot-fax.r
	author: [ "Graham Chiu"  ]
	date: [14-Jan-2010]
	version: 0.0.1
	rights: 'BSD
	notes: {
		To support the HylaFAX ftp protocol
		See script at end
		Needs to have actor abstractions written ...
		http://cr.yp.to/ftp.html
		And HylaFAX specific commands
		http://linux.die.net/man/8/hfaxd
		http://www.hylafax.org/content/Handbook:Server_Operation:Understanding_Your_Server#The_HylaFAX_Daemon_.28hfaxd.29
	}
]

; import mod-net-utils

alpha: charset [#"a" - #"z" #"A" - #"Z"]
digit: charset [#"0" - #"9"]
non-digit: complement digit
non-digits: [some non-digit]
pasv-rule: [1 3 digit "," 1 3 digit "," 1 3 digit "," 1 3 digit "," opt ["-"] 1 3 digit "," opt ["-"] 1 3 digit]
within?: func [low hi code] [
	all [code >= low code <= hi]
]

print-string: func [ txt ][
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
		
comment {
 Codes between 100 and 199 indicate marks; codes between 200 and 399 indicate acceptance; codes between 400 and 599 indicate rejection.
}

process-code: func [code client [port!]] [
	case [
		within? "100" "199" code [
			net-log rejoin ["received mark code " code]
		]
		within? "200" "399" code [
			net-log rejoin ["received unknown acceptance code " code]
			client/spec/ready: true
		]
		within? "400" "599" code [
			net-log rejoin ["received rejection code " code]
			client/spec/ready: true
		]
		true [
			net-log rejoin ["Unknown response: " code]
			client/spec/ready: true
		]
	]
]

; writes data to the port by converting to binary and adding a crlf
cmd-write: funct [port [port!] data [block!]] [
	write port to-binary net-log/c join form data crlf
]

; checks to see if there are any messages queued, if the port is ready.  Sends top message in queue.

write-cmdport: funct [cmdport
	/only data
] [
	if only [
		append/only cmdport/spec/messages data
	]
	if all [not empty? cmdport/spec/messages cmdport/spec/ready] [
		; changed so that the message - first is a word
		cmdport/spec/state: first data: first cmdport/spec/messages
		; if last is a file ... stream to file etc.
		
		; net-log rejoin [ "write-cmdport: " probe type? last data ]
		
		case [
			file? m: last data [
				net-log rejoin ["set to using file: " m]
				cmdport/spec/dataport/spec/method: m
				remove back tail data
			]
			any-function? :m [
				net-log "set to using callback"
				cmdport/spec/dataport/spec/method: :m
				remove back tail data			
			]
			binary? m [
				net-log "set to using buffer"
				cmdport/spec/dataport/spec/method: m
				remove back tail data
			]
			true [ 
				net-log "not using a command in data block"
			]
		]

		; port is now no longer ready to accept a new command until this one has completed
		cmdport/spec/ready: false
		net-log rejoin ["state is now " cmdport/spec/state " and ready is " cmdport/spec/ready]
		cmd-write cmdport data
		remove cmdport/spec/messages
		; re-activate the port handler
		read cmdport
	]
]

make-scheme [
	name: 'fax
	title: "hylaFAX Protocol"
	spec: make system/standard/port-spec-net [port-id: 4559]


	awake: funct [event /local client response state code] [
		print ["=== Client event:" event/type]
		client: event/port
		switch event/type [
			lookup [
				; print "DNS lookup"
				client/scheme/info/remote-ip: get in query client 'remote-ip
				client/scheme/info/remote-port: get in query client 'remote-port
				probe query client
				open client
			]
			connect [
				client/spec/state: 'AUTH
				client/spec/ready: false
				net-log "connected, state now AUTH"
				; schedule a read so that we get the welcome message from the ftp server
				read client
			]
			read [
				net-log/S response: enline to-string client/data
				clear client/data
				code: copy/part response 4
				net-log code
				net-log client/spec/state

				switch/default client/spec/state [
					INIT [
						net-log "should never be here"
					]
					AUTH [
						switch/default code [
							"220 " [
								print "asking for user .."
								cmd-write client reduce ['USER client/spec/user]
							]
							"331 " [
								print "asking for pass ..."
								cmd-write client reduce ['PASS client/spec/pass]
							]
							"230 " [
								print "logged in okay"
								cmd-write client [ TZONE "LOCAL" ]
							]
							"200 " [
								net-log "timezone set"
								client/spec/ready: true
							]
							

						] [process-code code client]
					]
					JPARM [
						switch/default code [
							"200 " [ net-log "Fax job submitted" 
								client/spec/ready: true
							]
							"213 " [ net-log "Hylafax parameter accepted" 
								client/spec/ready: true
							]
							
							"214-" [net-log "HylaFAX parameter accepted, more data coming"]
							"214 " [net-log "HylaFAX parameter accepted"
								client/spec/ready: true
							]
						] [process-code code client]					
					]
					JNEW [
						switch/default code [
							"200 " [net-log "New Fax Job created"
								; capture the jobid
								parse response [ thru "jobid: " copy jobid to "groupid" to end ]
								if jobid [
									trim jobid
									client/locals/jobid: jobid
								]
								client/spec/ready: true
							]
						] [process-code code client]
					]
					JSUBM [
						switch/default code [
							"200 " [net-log "New Fax Job submitted "
								client/spec/ready: true
							]
						] [process-code code client]
					]
					
					SYST [
						switch/default code [
							"215 " [net-log "useless system information"
								client/spec/ready: true
							]
						] [process-code code client]
					]
					PWD [
						switch/default code [
							"257 " [net-log "working directory received"
								client/spec/ready: true
							]
						] [process-code code client]
					]
					TYPE [
						switch/default code [
							"200 " [net-log "set transfer mode"
								client/spec/ready: true
							]
						] [process-code code client]
					]
					MKD XMKD [
						switch/default code [
							"257 " [net-log "ok, will create new directory" ]
							"250 " [
								net-log "new directory created"
								client/spec/ready: true
							]
						] [process-code code client]
					]
					RMD XRMD [
						switch/default code [
							"250 " [
								net-log "directory removed"
								client/spec/ready: true
							]
							"550 " [net-log "failed to remove directory" 
								client/spec/ready: true
							]
						] [process-code code client]
					]
					RNFR [
						switch/default code [
							"350 " [
								net-log "file ready to be renamed, waiting for RNTO command"
								client/spec/ready: true
							]
							"550 " "450 " [net-log "file does not exist" 
								client/spec/ready: true
							]
						] [process-code code client]
					]
					RNTO [
						switch/default code [
							"250 " [
								net-log "file renamed"
								client/spec/ready: true
							]
							"503 " [ net-log "No RNFR command received first" 
								client/spec/ready: true
							]
							"550 " "553 " [net-log "failed to rename file/directory" 
								client/spec/ready: true
							]
						] [process-code code client]
					]
					DELE [
						switch/default code [
							"250 " [net-log "file deleted"
								client/spec/ready: true
							]
							"450 " "550 " [ 
								net-log "File deletion failed"
								client/spec/ready: true
							]
						] [process-code code client]					
					]
					LIST NLST RETR STOR STOU APPE STOT [
						switch/default code [
							"150 " [net-log "ready to send/receive directory/file"
								; we should now send the file if this is using the STOR ...
								if find [ STOR STOU APPE STOT] client/spec/state [
									case [
										file? client/spec/dataport/spec/method [
											; method becomes port! so that we can read from it
											; the port tracks where we are inside it ...no need to maintain a seek position
											client/spec/dataport/spec/method: open client/spec/dataport/spec/method
											write client/spec/dataport read/part client/spec/dataport/spec/method 32000
										]
										binary? client/spec/dataport/spec/method [
											write client/spec/dataport client/spec/dataport/spec/method
											client/spec/dataport/spec/method: none
											return true
										]
										port? client/spec/dataport/spec/method [
											; sending file
										]
										true [
											; write clipboard:// mold client
											net-log [ "file transfer method not set: " client/spec/dataport/spec/method ]
											return true
										]
									]
								]
							]
							"226 " [net-log "directory/file transmitted"
								net-log "waiting now on dataport"
								client/spec/ready: true
								parse response [ thru "FILE: " to "/tmp" copy tmp to ")" to end ]
								if tmp [
									client/locals/tmpfile: tmp
								]
								return true
							]
							"425 " [net-log "No TCP data connection established" client/spec/ready: true]
							"426 " [net-log "Broken TCP data connection" client/spec/ready: true]
							"451 " "452 " "552 " [net-log "Server read error" client/spec/ready: true]
						] [process-code code client]
					]
					CWD [
						switch/default code [
							"250 " [net-log "changed directory" client/spec/ready: true]
							"200 " [net-log "changed directory" client/spec/ready: true]
							"550 " [net-log "this directory does not exist" client/spec/ready: true]
						] [process-code code client]
					]
					PASV [
						switch/default code [
							"227 " [net-log "Switched to passive mode"
								if parse response [3 digit non-digits copy ip pasv-rule to end] [
									; if we get a valid address from the server, we will create another port to be used for data transmission
									;write clipboard:// mold client
									use [tmp] [
										tmp: parse ip ","
										data-address: client/scheme/info/remote-ip ; to-tuple to-block form copy/part tmp 4
										; data-address: rejoin [tmp/1 "." tmp/2 "." tmp/3 "." tmp/4]
										data-port: 256 * (to-integer tmp/5) + to-integer tmp/6
										net-log rejoin ["Data IP address is " data-address " and port is " data-port]

										; create the dataport
										client/spec/dataport: make port! compose [
											scheme: 'tcp
											host: (data-address)
											port-id: (data-port)
											state: 'INIT
											timeout: 5
											closed?: false
											method: none
										]
										; create the awake handler for the dataport 
										client/spec/dataport/awake: func [event /local port] [
											port: event/port
											print ["==TCP-event on dataport:" event/type]
											switch/default event/type [
												read [print ["^\read:" length? port/data]
													switch type? :port/spec/method reduce [
														file! [
															write/append port/spec/method port/data
															clear port/data

														]
														binary! [
															append port/spec/method port/data
															clear port/data

														]
													]
													read port
												]
												wrote [
													either port? port/spec/method [
														either not empty? port/spec/method [
															write port read/part port/spec/method 32000
														][ 
															close port
															return true
														]
													][
														net-log [ "wrote: " port/spec/method ]
														read port
													]
												]
												lookup [print query port open port]
												connect [read port]
												close [
													port/spec/closed?: true
													switch/default type? :port/spec/method reduce [
														function! native! [
															port/spec/method port/data
														]
														binary! []
														file! []
													] [print to-string port/data]
													close port
													return true
												]
											] [true]
										]

										open client/spec/dataport
										net-log rejoin ["opened dataport on " data-address ":" data-port]
									]
									client/spec/ready: true
								]
							]
						] [process-code code client]
					]
					QUIT [
					]
				] [net-log join "Unknown state " client/spec/state]
				; we've completed a read, now ask for another one
				unless client/spec/ready [read client]
			]
			wrote [
				net-log "wrote to port, now read from it"
				read client
			]
			close [net-log "Port closed on me"]
		]
		write-cmdport client
		client/spec/ready
	]
	actor: [
		open: func [
			port [port!]
			/local conn
		] [
			if port/state [return port]
			if none? port/spec/host [
				make error! [
					type: 'Access
					id: 'Protocol
					arg1: "Missing host address"
				]
			]
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
				dataport: none
				ready: false ; another state flag
				timeout: 10
				messages: [] ; holds the queue of messages being sent to the port
				user: either in port/spec 'user [port/spec/user] ["anonymous"]
				pass: either in port/spec 'pass [port/spec/pass] ["rebol@"]
				ref: rejoin [tcp:// host ":" port-id]
			]
			conn/locals: context [ tmpfile: jobid: none ]
			conn/awake: :awake
			open conn
			net-log "port opened ..."
			port
		]

		write: funct [port [port!] data [block!]] [
			; set up the state machine so that we know how to deal with the response
			; cmdport: port/state/connection
			; append/only cmdport/spec/messages data
			write-cmdport/only port/state/connection data
		]


		open?: func [
			port [port!]
		] [
			all [port/state]
		]

		close: funct [
			port [port!]
		] [
			;write clipboard:// mold port
			
			if 	all [ dataport: port/state/connection/spec/dataport  open? dataport ][
				close dataport
				dataport/awake: none
				dataport: none
			]

			if open? port [
				close port/state/connection
				port/state/connection/awake: none
				port/state: none
			]
			port
		]

		read: func [port [port!]] [
			wait port/state/connection
		]
	]
]


comment {
cmd: open fax://user:password@192.168.1.120
read cmd

write cmd [ PASV ]
read cmd

write cmd [ TYPE "A" ]
read cmd

write cmd compose [ LIST "recvq" (:print-string)]
read cmd

halt

write cmd [ TYPE "I" ]
read cmd
write cmd [ PASV ]
read cmd
write cmd [ STOT %prot-fax.r ]
read cmd
write cmd [ JNEW ]
read cmd

halt
}