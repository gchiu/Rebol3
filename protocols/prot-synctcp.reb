Rebol [
    System: "REBOL [R3] Language Interpreter and Run-time Environment"
    title: "Synchronous TCP"
    file: %prot-synctcp.reb
    author: ["Graham"]
    name: synctcp
    type: module
    version: 0.0.2
    Date: [29-Mar-2017]
    Purpose: "R3 send and receive synchronous TCP"
    Description: {
        an early work at seeing if we can get simple open, write, read, and close on a tcp port

        Examples:

        1. Login to pop3 server and get status
        pop: open synctcp://pop.clear.net.nz:110
        read pop ; fetch the ready message from the server
        print to string! write pop to binary! join-of {USER *****} newline
        print to string! write pop to binary! join-of {PASS *****} newline
        print to string! write pop to binary! join-of {STAT} newline
        print string! write pop to binary! join-of {QUIT} newline

        2. Get head from a web server
        head: to binary! {HEAD / HTTP/1.1^/Accept: */*^/Accept-Charset: utf-8^/Host: www.rebol.com^/User-Agent: Ren-C^/^/}
        port: open synctcp://www.rebol.com
        print to string! write port head
    }
    History: {
        0.0.1 first version, not working :(
        0.0.2 second version, can now do some successful interaction with pop3 server and http server
    }
]

make-synctcp-error: func [
    message
][
    do make error! [
        type: 'Access
        id: 'Protocol
        arg1: message
    ]
]

; port/state/tcp-port [
;    spec [object!] 
;                title: "TCP Networking"
;                scheme: 'tcp
;                ref: tcp://www.rebol.com:80
;                path: _
;                host: "www.rebol.com"
;                port-id: 80
;                timeout: 30
;                port-state: ready
;                data: binary! - saved by port actor
;    scheme [object! - template] 
;    actor [handle!] 
;    awake [current handler in use] 
;    state [used by query] 
;    data locals[free]
; ]
read-awake-handler: func [event /local tcp-port] [
    print ["=== RH Client event:" event/type]
    tcp-port: event/port
    switch/default event/type [
        error [
            print "error event received"
            tcp-port/spec/port-state: 'error
            true
        ]
        lookup [
            open tcp-port
            false
        ]
        connect [
            tcp-port/spec/port-state: 'ready
            read tcp-port
            false
        ]
        read [
            print ["^\Read Handler read:" length tcp-port/data]
            tcp-port/spec/data: copy tcp-port/data
            clear tcp-port/data
            true
        ]
        wrote [
            read tcp-port
            false
        ]
        close [
            print "closed on us!"
            tcp-port/spec/port-state: _
            close tcp-port
            true
        ]
    ] [true]
]    

write-awake-handler: func [event /local tcp-port] [
    print ["=== WH Client event:" event/type]
    tcp-port: event/port
    switch/default event/type [
        error [
            print "error event received"
            tcp-port/spec/port-state: 'error
            true
        ]
        lookup [
            open tcp-port
            print "tcp-port opened in lookup"
            false
        ]
        connect [
            print "connected to tcp-port in write handler"
            tcp-port/spec/port-state: 'ready
            print/only "Writing TCP port locals: "
            probe to string! tcp-port/locals
            write tcp-port tcp-port/locals
            ; do we ever get here since the wrote event takes us elsewhere
            false
        ]
        read [
            print ["^\Write Handler read:" length tcp-port/data]
            tcp-port/spec/data: copy tcp-port/data
            print ["Read: " probe to string! tcp-port/data ]
            clear tcp-port/data
            true
        ]
        wrote [
            read tcp-port
            false
        ]
        close [
            print "closed on us!"
            tcp-port/spec/port-state: _
            close tcp-port
            true
        ]
    ] [true]
]    
 
sync-write: procedure [port [port!] data
        /local tcp-port
] [
    unless open? port [
            open port
    ]
    tcp-port: port/state/tcp-port
    tcp-port/awake: :write-awake-handler
    either tcp-port/spec/port-state = 'ready [
            write tcp-port data
    ] [
            tcp-port/locals: copy data
    ]
    unless port? wait [tcp-port port/spec/timeout] [
            make-synctcp-error "timeout on tcp-port"
    ]
]

sync-read: procedure [port [port!] 
        /local tcp-port
] [
    unless open? port [
            open port
    ]
    tcp-port: port/state/tcp-port
    tcp-port/awake: :read-awake-handler
    either tcp-port/spec/port-state = 'ready [
            read tcp-port
    ] [
            ; tcp-port/locals: copy data
    ]
    unless port? wait [tcp-port port/spec/timeout] [
            make-synctcp-error "timeout on tcp-port"
    ]
]

sys/make-scheme [
    name: 'synctcp
    title: "Sync TCP Protocol"
    spec: make system/standard/port-spec-net [port-id: 80 timeout: 30]

    actor: [
        open: func [
            port [port!]
            /local tcp-port
        ] [
            if port/state [return port]
            if blank? port/spec/host [make-synctcp-error "Missing host address"]
            port/state: context [
                tcp-port: _
            ]
            port/state/tcp-port: tcp-port: make port! [
                scheme: 'tcp
                host: port/spec/host
                port-id: port/spec/port-id
                timeout: port/spec/timeout
                ref: rejoin [tcp:// host ":" port-id]
                port-state: _
                data: _
            ]
            open tcp-port
            port
        ]
        open?: func [port [port!]] [
            port/state/tcp-port/spec/port-state
        ]
        write: func [port [port!] data] [
            if not open? port [
                print "Port not open, attempting to reopen"
                open port
            ]
            port/state/tcp-port/awake: default [:write-awake-handler]
            sync-write port data
            port/state/tcp-port/spec/data
        ]
        read: func [port [port!]] [
            if not open? port [
                print "Port not open, attempting to reopen"
                open port
            ]
            port/state/tcp-port/awake: default [:read-awake-handler]
            sync-read port
            return port/state/tcp-port/spec/data
        ]
        close: func [port [port!]] [
            close port/state/tcp-port
            port/state/tcp-port/spec/port-state: _
        ] 
        query: func [
            port [port!]
            /local error state
        ][
            query port/state/tcp-port
        ]
    ]
]
