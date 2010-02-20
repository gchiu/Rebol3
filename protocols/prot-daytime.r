Rebol [
	file: %prot-daytime.r
	author: "Graham"
	rights: 'BSD
	date: 8-Jan-2010
]

make-scheme [
	name: 'daytime
	title: "Daytime Protocol"
	spec: make system/standard/port-spec-net [port-id: 13 ]
	awake: func [event /local port] [
		; print ["=== Client event:" event/type]
		port: event/port
		switch event/type [
			lookup [
				; print "DNS lookup"
				open port
			]
			connect [ 
				print "connected"
				read port
				; print to-string port/data
			]
			read [
				; print ["    " to-string port/data]
				close port
				return true ; quits the awake
			]
			wrote [read port]
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
			port/state: context [
				state: 'ready
				connection:
				error: none
				awake: :port/awake
				close?: yes
			]
			port/state/connection: conn: make port! [
				scheme: 'tcp 
				host: port/spec/host 
				port-id: port/spec/port-id 
				ref: rejoin [tcp:// host ":" port-id]
			] 
			conn/awake: :awake 
			open conn
			port
		]
        open?: func [
            port [port!]
        ][
            all [ port/state ]
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
				unless open? port [
					wait open port
				]
				port
			] [
				; do something synchronous here
			]
		]
	]
]