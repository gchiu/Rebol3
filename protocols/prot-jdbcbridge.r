Rebol [
	file: %prot-jdbc.r
	author: "Graham Chiu"
	rights: 'LGPL
	date:  [ 29-June-2010 3-July-2010 ]
	version: 0.0.2
	notes: {
		sample session. 
		
		db: open jdbcbridge://www.compkarori.co.nz:8020
		insert db [{select * from employee where full_name = (?)} "Guckenheimer, Mark"]
		>> print length? db 
		1
		result: pick db 1
		>> print length? db
		0
		insert db [ 'tables ]
		insert db [ 'tables "MYTABLE" ]
		insert db [ 'columns "Employee" ]
		close db
	}
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

crlfbin: to-binary crlf

clear-data: func [ port ][
	port/state/connection/spec/data: make binary! 0
	port/state/connection/data: none
]

write-cmd: funct [client] [
	either string? cmd: client/spec/cmd [
		write client to-binary net-log/C join cmd crlf
		read client
	] [
		if block? cmd [
			; see if the first command is a word, eg: [ columns "TABLENAME" ] looking for metadata
			either any [word? cmd/1 lit-word? cmd/1] [
				net-log "command is a word"
				write client to-binary net-log/C join form reduce cmd crlf
			] [
				; replace the place holders
				foreach var next cmd [
					either any [string? var date? var word? var] [
						replace cmd/1 "?" rejoin ["'" var "'"]
					] [
						replace cmd/1 "?" var
					]
				]
				write client to-binary net-log/C join cmd/1 crlf
			]
			read client
		]
	]
]

make-scheme [
	name: 'jdbcbridge
	title: "JDBC Bridge Protocol"
	spec: make system/standard/port-spec-net [port-id: 8000]
	awake: func [event /local client response state code result cmd] [
		print ["=== Client event:" event/type]
		client: event/port
		switch event/type [
			lookup [
				net-log "DNS lookup"
				open client
			]
			connect [
				net-log "connected"
				; send the command and let the read event copy the data back
				write-cmd client
			]
			read [
				net-log "read occurred"
				probe length? client/data
				append client/spec/data client/data
				; net-log/S to-string client/data
				either find/last client/data crlfbin [
					client/spec/data: load enline to-string client/spec/data
					client/data: none ; make binary! 0
					net-log "received end of line marker"
					return true
				][
					read client
				]
			]
			wrote [	
				; query sent, let's get the response
				read client
			]
			close [
				net-log "Server closed the Port"
				; we should now have all the data, so it's now safe to load it
				client/spec/data: load enline to-string client/spec/data
				client/spec/close?: true
				return true
			]
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
				ref: rejoin [tcp:// host ":" port-id]
				cmd: none ; will hold the commands we send
				data: make binary! 0
				close?: no
			]
			conn/awake: :awake
			open conn
			print "port opened ..."
			probe port/state/connection/spec/port-id
			probe port/state/connection/spec/host
			probe port/state/connection/spec/scheme
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
				insert port "QUIT" ; to-binary join "QUIT" crlf
				close port/state/connection
				port/state/connection/awake: none
				port/state: none
			]
			port
		]
		
		insert: func [ port [port!] data [string! block!]][
			; since the data is a molded rebol value we need too make sure it doesn't get corrupted 
			clear-data port
			if port/state/connection/spec/close? [
				; need to re-open the port using the existing structures
				; this doesn't seem to work
				open port/state/connection
				net-log "re-opened the port??"
			]
			; we might have opened the port but not yet waited on it
			either none? port/state/connection/spec/cmd [
				; no commands sent yet, so use the connect event to send
				port/state/connection/spec/cmd: copy data
				; now wait on the port and use the connect event to send our query
				wait port/state/connection
			][
				port/state/connection/spec/cmd: copy data
				write-cmd port/state/connection
			]
			wait port/state/connection
		]
		
		length?: func [ port [port!] index [integer!]][
			system/contexts/system/length? any [ port/state/connection/spec/data 0 ]
		]
		
		pick: funct [ port [port!] index [integer!]][
			either open? port [
				either any [ index > length? port index <= 0 ][
					none
				][
					data: pick port/state/connection/spec/data index
					remove skip port/state/connection/spec/data index - 1
					data
				]
			][ none ]
		]
		
		copy: funct [ port [port!] ][
			either open? port [
				data: either source: port/state/connection/spec/data [
					copy source
				][ none ]
				clear-data port
				data
			][ none ]
		]
	]
]
