Rebol [
	file: %prot-jdbc.r
	author: "Graham"
	rights: 'LGPL
	date: 29-June-2010
]

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
				either string? cmd: client/spec/cmd [
					net-log/C client/spec/cmd
					write client to-binary join client/spec/cmd crlf
					wait client
				][
					if block? client/spec/cmd [
						; replace the place holders
						foreach var next cmd [
							either any [ string? var date? var ] [
								replace cmd/1 "(?)" rejoin [ "'" var "'" ]
							][
								replace cmd/1 "(?)" var
							]
						]
						write client to-binary net-log/C  join cmd/1 crlf
						wait client
					]
				]
			]
			read [
				net-log "read occurred"
				probe length? client/data
				append client/spec/data client/data
				clear client/data
				; a close event should now occur, but it's not!  So, we are replicating the code for the close event here.
				; this won't work for lots of data
				client/spec/data: load enline to-string client/spec/data
				client/spec/close?: true
				return true
			]
			wrote [	
				; query sent, let's get the response
				read client
				wait client
				return true
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
				state: 'INIT
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
				close port/state/connection
				port/state/connection/awake: none
				port/state: none
			]
			port
		]
		
		insert: func [ port [port!] data [string! block!]][
			if port/state/connection/spec/close? [
				; need to re-open the port using the existing structures
				; this doesn't seem to work
				open port/state/connection
				net-log "re-opened the port??"
			]
			; we might have opened the port but not yet waited on it
			port/state/connection/spec/cmd: copy data
			; now wait on the port and use the connect event to send our query
			wait port/state/connection
		]
		
		length?: func [ port [port!] index [integer!]][
			system/contexts/system/length? any [ port/state/connection/spec/data 0 ]
		]
		
		pick: funct [ port [port!] index [integer!]][
			either any [ index > length? port index <= 0 ][
				none
			][
				data: pick port/state/connection/spec/data index
				remove skip port/state/connection/spec/data index - 1
				data
			]
		]
		
		copy: funct [ port [port!] ][
			data: either source: port/state/connection/spec/data [
				copy source
			][ none ]
			data
		]
	]
]