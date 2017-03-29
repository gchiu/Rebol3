Rebol [
    System: "REBOL [R3] Language Interpreter and Run-time Environment"
    title: "Synchronous TCP"
    file: %prot-synctcp.reb
    author: ["Graham" ]
    name: synctcp
    type: module
    version: 0.0.1
    Date: [ 29-Mar-2017 ]
    Purpose: "R3 send and receive synchronous TCP"
    Note: ""
    Description: {
        an early work at seeing if we can get simple open, write, read, and close on a tcp port
    }
    History: {
        0.0.1 first version, not working :(
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

awake-handler: func [event /local tcp-port] [
    print ["=== Client event:" event/type]
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
            print "connected "
            tcp-port/spec/port-state: 'ready
            write tcp-port tcp-port/locals
            ; do we ever get here since the wrote event takes us elsewhere
            false
        ]
        read [
            print ["^\read:" length? tcp-port/data]
            tcp-port/spec/data: copy tcp-port/data
            clear tcp-port/data
            true
        ]
        wrote [
            print "written, so read port"
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
    tcp-port/awake: :awake-handler
    either tcp-port/spec/port-state = 'ready [
            write tcp-port data
    ] [
            tcp-port/locals: copy data
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
            tcp-port/awake: _
            open tcp-port
            port
        ]
        open?: func [port [port!]] [
            port/state/tcp-port/spec/port-state
        ]
        write: func [port [port!] data] [
            print "Writing to port"
            if not open? port [
                print "Port not open, attempting to reopen"
                open port
            ]
            sync-write port data
            port/state/tcp-port/spec/data
        ]
        read: func [port [port!]] [
            print "actor read"
            read port/state/tcp-port
            unless port? wait [port/state/tcp-port port/spec/timeout] [
                make-synctcp-error "timeout on tcp-port"
            ]
            return port/state/tcp-port/spec/data
        ]
        close: func [port [port!]] [
            close port/state/tcp-port
            port/state: _
        ] 
        query: func [
            port [port!]
            /local error state
        ][
            query port/state/tcp-port
        ]
    ]
]
