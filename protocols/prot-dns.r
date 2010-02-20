REBOL [
	author: "Graham Chiu"
	date: 11-Jan-2010
	rights: 'BSD

]
make-scheme [
	name: 'dns2
	title: "DNS Protocol"
	spec: make system/standard/port-spec-net [port-id: 80]
	awake: funct [event ] [ true ]
	actor: [
		read: func [
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
				ref: rejoin [tcp:// host ":" port-id]
			]
			conn/awake: :awake
			open conn
			wait [  conn 5 ]
			attempt [ get in query conn 'remote-ip ]
		]
	]
]