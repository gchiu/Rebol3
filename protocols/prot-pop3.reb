Rebol [
    System: "REBOL [R3] Language Interpreter and Run-time Environment"
    title: "Synchronous POP3 protocol"
    file: %prot-pop3.reb
    author: ["Graham"]
    name: pop3
    type: module
    version: 0.0.2
    Date: [29-Mar-2017]
    Purpose: "R3 send and receive synchronous TCP"
    Description: {
    }
    History: {
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
            print "reading from port"
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

check+: procedure [s [string!]][
    print s
    if not find/part s "+OK" 3 [
        print "Error"
        halt
    ]
]

check+space: procedure [s [string!]][
    print s
    if not find/part s "+ " 2 [
        print "Error"
        halt
    ]
]

crlfbin: to binary! crlf

sys/make-scheme [
    name: 'pop3
    title: "Sync POP3 Protocol"
    spec: make system/standard/port-spec-net [port-id: 995 timeout: 30]

    actor: [
        open: func [
            port [port!]
            /local tcp-port w authstring
        ] [
            if port/state [return port]
            if blank? port/spec/host [make-synctcp-error "Missing host address"]
            port/state: context [
                tcp-port: _
            ]
            port/state/tcp-port: tcp-port: make port! [
                scheme: 'tls
                host: port/spec/host
                port-id: port/spec/port-id
                timeout: port/spec/timeout
                ref: rejoin [synctcp:// host ":" port-id]
                port-state: _
                data: _
            ]
            open tcp-port
            ; now open the actual port using username and password
            check+ w: to string! read port
            check+space w: to string! write port to binary! join-of "AUTH PLAIN" newline
            authstring: enbase ajoin ["^@" port/spec/user "^@" port/spec/pass]
            check+ w: to string! write port join-of to binary! authstring crlfbin
            check+ w: to string! write port join-of to binary! {STAT} crlfbin
            port
        ]
        open?: func [port [port!]] [
            port/state/tcp-port/spec/port-state
        ]
        pick: func [port [port!] n [integer!]][
            ; RETR message n
            print join-of "sending pick port " n
            write port join-of to binary! join-of "RETR " n crlfbin
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
