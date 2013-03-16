Rebol [
	System: "REBOL [R3] Language Interpreter and Run-time Environment"
    title: "R3 SL4A"
    file: %prot-sl4a.r3
    author: ["Graham" ]
	name: 'sl4a
	type: 'module
	version: 0.0.2
    Date: [ 14-Mar-2013 16-Mar-2013 ]
    Purpose: "R3 send and receive from Scripting Layer 4 Android"
    Note: ""
    Description: {
		A synchronous protocol to send and receive messages from the SL4A server
		Needs JSON utils loaded first
		
		if not value? 'load-json [
			do http://reb4.me/r3/altjson
		]
		
		p: open sl4a://localhost
		result: write p  [ makeToast "hello, world" ]
		>> ?? result
			result: make object! [
			error: none
			id: 1
			result: none
		]
		these are all valid blocks, order is not important
		[ makeToast "hello, world" ]
		[ 2 makeToast ["hello, world" ]]
		[ dialogCreateAlert [{"title", "message"}] 3]
		[ dialogShow ]
		[ [ dialogCreateAlert ["title" "message" ] 3] [ dialogShow 4]]
    }
	History: {
		0.0.1 first version
		0.0.2 use a dialected block as the parameter for 'write
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

; if params is absent, then it's an empty JSON array
; if params is a string!, then it's a single element in a JSON array
; if params is a block!, then it needs to be converted to a JSON array

parse-request: funct/with [ data [block!]
	/local params method id template
][
	params: method: id: none
	parse data [ 
		some [
			set params block! | 
			set params string! |
			set method word! |
			set id integer!
		]
	]
	template: copy {{"method":"$method","params":$params,"id":$id}}
	id: either none? id [ ++ cnt ][ cnt: id id ]
	params: switch type?/word params [
		string! [ mold append copy [] params ]
		block! [ to-json copy params ]
		none! [ mold [] ]
	][ mold []]
	
	reword template reduce [
		'method method
		'params params
		'id id
	]
][ cnt: 1 ]

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
			close [
				print "closed on us!"
				return true
			]
        ][ true ]
        false
    ]
	
sync-write: func [ port [port!] body
	/local state
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
    spec: make system/standard/port-spec-net [port-id: 4321 timeout: 60 ]

    actor: [

        open: func [
            port [port!]
            /local conn
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
			obj [block!]
            /local result 
		][
			if port/state/connection/spec/state = 'init [
				wait [ port 2 ]
			]
			either all [ block? obj/1 block? obj/2 ][
				result: copy []
				foreach cmd obj [
					sync-write port parse-request cmd
					append result port/state/connection/spec/json
				]
				result
			][
				sync-write port parse-request obj		
				port/state/connection/spec/json
			]
		]
    ]
]
