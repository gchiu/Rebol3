Rebol [
	System: "REBOL [R3] Language Interpreter and Run-time Environment"
    title: "R3 time scheme"
    file: %prot-time.r
    author: [ "Pavel" "Graham" ]
	module: 'time
    Date: [ 30-Dec-2010  16-Jan-2013 ]
    Purpose: "R3 read time from RFC868 time server"
    Note: "Based on Graham's example daytime scheme for R3"
    Description: {
        create Rebol3 time:// scheme, 
        read time://time.server returns number of UTC seconds from 1-jan-1900,
        read/lines time://time.server returns well formated local time
		
		write time://time.nist.gov [ GMT | days | seconds | local | stamp ]
    }
	History: {
		0.0.1 first version
		0.0.2 added write options, removed lines option  - Graham
	}
]

sys/make-scheme [
    name: 'time
    title: "Time Protocol"
    spec: make system/standard/port-spec-net [port-id: 37 timeout: 15 ]
    awake: func [event /local port] [
        ;print ["=== Client event:" event/type]
        port: event/port
        switch event/type [
            lookup [
                ;print "DNS lookup"
                open port
            ]
            connect [
                ;print "connected"
                read port
            ]
            read [
				port/locals: to-integer port/data
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
            conn
        ]

        open?: func [port [port!]][
            all [ port/state ]
        ]

        close: func [ port [port!]] [
            if open? port [ close port ]
        ]

		write: func [
			port [port!]
			options [block!]
            /local con stamp days seconds timeout date	
		][
			timeout: port/spec/timeout
			con: open rejoin [tcp:// port/spec/host ":" port/spec/port-id]
			; replace the default tcp awake handler with our own
			con/awake: :awake
			wait [ con timeout]
			if none? con/locals [ 
				return none
			]
			stamp: con/locals 
			days: round/down stamp / 86400 
			seconds: stamp // 86400 
			date: to date! rejoin [1-Jan-1900 + days + to-time seconds + now/zone ]
			parse options [
				[ 'GMT (
					date: date - now/zone
					date/zone: 0
				) ] |
				'Local |
				'Seconds ( date: seconds ) |
				'Stamp ( date: stamp ) |
				'Days ( date: days ) 
			]
			date
		]
		
        read: func [
            port [port!]
            /local con stamp days seconds timeout
        ] [
			timeout: port/spec/timeout
			con: open rejoin [tcp:// port/spec/host ":" port/spec/port-id]
			; replace the default tcp awake handler with our own
			con/awake: :awake
			wait [ con timeout]
			
			stamp: con/locals 
			either none? stamp [
				none
			][
				days: round/down stamp / 86400 
				seconds: stamp // 86400 
				rejoin [1-Jan-1900 + days + to-time seconds + now/zone ]
			]
        ]
    ]
]
