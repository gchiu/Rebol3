Rebol [
	System: "REBOL [R3] Language Interpreter and Run-time Environment"
    title: "R3 SL4A"
    file: %prot-sl4a.r3
    author: ["Graham" ]
	name: 'sl4a
	type: 'module
	version: 0.0.1
    Date: [ 14-Mar-2013 ]
    Purpose: "R3 send and receive from Scripting Layer 4 Android"
    Note: ""
    Description: {
		A synchronous protocol to send and receive messages from the SL4A server
		Needs JSON utils loaded first
		
		if not value? 'load-json [
			do http://reb4.me/r3/altjson
		]
		
		p: open sl4a://localhost
		result: write p  to-json [ params: [ "Hello, Android" ] id: 1 method: "makeToast" ]
		>> ?? result
			result: make object! [
			error: none
			id: 1
			result: none
		]
    }
	History: {
		0.0.1 first version
	}
]

make-sl4a-error: func [
    message
][
    do make error! [
        type: 'Access
        id: 'Protocol
        arg1: message
    ]
]

; android-request: {{"params": ["Hello, Android!"], "id":1, "method": "makeToast"}}

sl4a-awake: func [event /local port] [
        print ["=== Client event:" event/type]
        port: event/port
        switch/default event/type [
			error [
				print "error event received"
				return true
			]
            lookup [
                print "DNS lookup for Android, so opening port"
				open port
				print "port opened"
				port/spec/state: 'ready
            ]
            connect [
                print "connected "
            ]
            read [
				print "reading port"
				; print ["^\read:" length? port/data]
				port/spec/json: load-json to string! port/data
				return true
            ]
            wrote [
				print "written, so read port"
				read port
			]
        ][ true ]
        false
    ]
	
sync-write: func [ port [port!] body
	/local state result
][
	unless port/state [ open port port/state/close?: yes ]
	state: port/state
	state/connection/awake: :sl4a-awake
	lib/write port/state/connection to binary! join body newline
	unless port? wait [ state/connection port/spec/timeout ] [ make-sl4a-error "SL4A timeout" ]
	true
]	

sys/make-scheme [
    name: 'sl4a
    title: "SL4A Protocol"
    spec: make system/standard/port-spec-net [port-id: 4321 timeout: 15 ]

    actor: [

        open: func [
            port [port!]
            /local conn url
        ] [
            if port/state [return port]
            if none? port/spec/host [make-sl4a-error "Missing host address"]
			port/state: context [
				connection:
				error: none
				awake: none  
				close?: no  
				json: none
			]
			print "creating the port"
            port/state/connection: 
				conn: make port!  [
                scheme: 'tcp
                host: port/spec/host
                port-id: port/spec/port-id
				timeout: port/spec/timeout
                ref: rejoin [tcp:// host ":" port-id]
				json: none
				state: 'init
            ]
            conn/awake: :sl4a-awake
            open conn
            port
        ]

        open?: func [port [port!]][
            all [ port/state ]
        ]

        close: func [ port [port!]] [
            if open? port [ close port/state/connection ]
        ]

		write: func [
			port [port!]
			obj 
            /local conn 	
		][
			if port/state/connection/spec/state = 'init [
				wait [ port 2 ]
			]
			sync-write port obj		
			port/state/connection/spec/json
		]
    ]
]
