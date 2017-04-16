Rebol [
    System: "REBOL [R3] Language Interpreter and Run-time Environment"
    title: "Synchronous POP3 protocol"
    file: %prot-pop3.reb
    author: ["Graham"]
    name: pop3
    type: module
    exports: [UIDL RSET DELETE-POP TOP STAT LIST]
    version: 0.0.3
    Date: [29-Mar-2017 14-Apr-2017]
    Purpose: "R3 send and receive synchronous TCP"
    Description: {
        mbox: open pop3://user:pass@pop.server.com:110

        or

        mbox: open pop3://user@gmail.com:pass@pop.gmail.com:995

        then;

        email: pick mbox 1
        length mbox
        close mbox
    }
    History: {
        14-Apr-2017 working version that uses either TLS or TCP depending on port number
        16-Apr-2017 now able to download multimegabyte email
    }
]


UIDL: func [port [port!]][
    port/actor/UIDL port
]
DELETE-POP: func [port [port!] n][
    port/actor/DELETE port n
]
RSET: func [port [port!]][
    port/actor/RSET port
]
TOP: func [port [port!] n len][
    port/actor/TOP port n len
]
STAT: func [port [port!]][
    port/actor/STAT port
]
LIST: func [port [port!]][
    port/actor/LIST port
]

crlfbin: to binary! crlf
digit: charset [#"0" - #"9"]
digits: [some digit]

make-pop3-error: func [
    message
][
    FAIL ["POP3 protocol error: " message]
]

write-nlb: func [port [port!] data][
    write port join-of to binary! data crlfbin
]

; tcp-port/data is used to hold the read/write buffer by the C code
; tcp-port/spec/data is used by the actor and handlers to store the incoming data

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
            append tcp-port/spec/data copy tcp-port/data
            ; print ["Read: " probe join-of copy/part to string! tcp-port/data 100 "..."]
            clear tcp-port/data
            ; now decide if we need to exit the write-awake-handler
            case [
                tcp-port/spec/cmd = 'RETR 
                [
                    either findeofpop tcp-port/spec/data [
                        tcp-port/spec/cmd: _
                        true
                    ][
                        read tcp-port
                        false
                    ]
                ]
                true [true]
            ]
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
            FAIL "timeout on tcp-port"
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
        ; FAIL "unable to open POP3 port"
    ]
    unless port? wait [tcp-port port/spec/timeout] [
        make-pop3-error "timeout on tcp-port"
    ]
]

check+: procedure [s [string!]][
    print s
    if not find/part s "+OK" 3 [
        FAIL "Error when checking for +OK"
    ]
]

check+space: procedure [s [string!]][
    print s
    if not find/part s "+ " 2 [
        FAIL "Error when checking for +n&bsp;"
    ]
]

findeofpop: function [data [binary!]][
    equal? marker: to binary! ajoin [crlf "." crlf]
    find skip data -5 + length data marker
]

sys/make-scheme [
    name: 'pop3
    title: "Sync POP3 Protocol"
    spec: make system/standard/port-spec-net [port-id: 995 timeout: 30]

    actor: [
        open: func [
            port [port!]
            /local tcp-port w authstring method sasl-methods
        ] [
            if port/state [return port]
            if blank? port/spec/host [make-pop3-error "Missing host address"]
            port/state: context [
                tcp-port: _
            ]
            either find [465 587 993 995] port/spec/port-id [
                port/state/tcp-port: tcp-port: make port! [
                    scheme: 'tls
                    host: port/spec/host
                    port-id: port/spec/port-id
                    timeout: port/spec/timeout
                    ref: rejoin [tls:// host ":" port-id]
                    port-state: _
                    data: _
                    cmd: _
                    authentication: copy []
                ]
            ][
                port/state/tcp-port: tcp-port: make port! [
                    scheme: 'tcp
                    host: port/spec/host
                    port-id: port/spec/port-id
                    timeout: port/spec/timeout
                    ref: rejoin [tcp:// host ":" port-id]
                    port-state: _
                    data: _
                    cmd: _
                    authentication: copy []
                ]
            ]
            if any [
                not something? in port/spec 'user
                not something? in port/spec 'pass
            ][
                make-pop3-error "credentials were not supplied when opening the pop3 port"
            ]
            open tcp-port
            ; now authenticate using username and password.  we need to first parse out the authentication methods
            check+ w: to string! read port
            check+ w: to string! write-nlb port "CAPA"
            if parse w [thru "USER" to end][
                append port/state/tcp-port/spec/authentication "USER"
            ]
            parse w [thru "SASL" space copy sasl-methods: to newline (
                append port/state/tcp-port/spec/authentication split sasl-methods space
            )]
            ; by default we use the strongest method we have to authenticate
            case [
                find port/state/tcp-port/spec/authentication "PLAIN" [
                    check+space w: to string! write-nlb port "AUTH PLAIN"
                    authstring: enbase ajoin ["^@" port/spec/user "^@" port/spec/pass]
                    check+ w: to string! write-nlb port authstring
                ]
                find port/state/tcp-port/spec/authentication "USER" [
                    check+ w: to string! write-nlb port join-of "USER " port/spec/user 
                    check+ w: to string! write-nlb port join-of "PASS " port/spec/pass 
                ]
                true [FAIL "no suppported authentication methods found"]
            ]
            check+ w: to string! write-nlb port {STAT}
            port
        ]
        open?: func [port [port!]] [
            port/state/tcp-port/spec/port-state
        ]
        pick*: func [port [port!] n [integer!]][
            ; RETR message n
            ; signal to the READ actor that will need to keep reading and not exit the event handler
            port/state/tcp-port/spec/cmd: 'RETR
            write-nlb port join-of "RETR " n
        ]
        length: func [port [port!]
        ][
            port/state/tcp-port/spec/cmd: 'length
            write-nlb port "STAT"
        ]
        remove: func [port [port!]][
            return "Remove Not implemented Yet"
        ]
        write: func [port [port!] data
            <local> len
        ][
            if not open? port [
                print "Port not open, attempting to reopen"
                open port
            ]
            port/state/tcp-port/awake: default [:write-awake-handler]
            clear port/state/tcp-port/spec/data

            sync-write port data
            switch/default port/state/tcp-port/spec/cmd [
                'length [
                    either parse to string! port/state/tcp-port/spec/data ["+OK " copy len: digits to end][
                        port/state/tcp-port/spec/cmd: _
                        to integer! len
                    ][copy port/state/tcp-port/spec/data]
                ]
            ][
                copy port/state/tcp-port/spec/data
            ]
        ]
        read: func [port [port!]] [
            unless open? port [
                print "Port not open, attempting to reopen"
                open port
            ]
            port/state/tcp-port/awake: default [:read-awake-handler]
            sync-read port
            copy port/state/tcp-port/spec/data
        ]
        close: func [port [port!]] [
            write-nlb port "QUIT"
            close port/state/tcp-port
            port/state/tcp-port/spec/port-state: _
        ] 
        query: func [
            port [port!]
            /local error state
        ][
            query port/state/tcp-port
        ]
        LIST: func [port [port!]][
            to string! write-nlb port "LIST"
        ]
        UIDL: func [port [port!]][
            to string! write-nlb port "UIDL"
        ]
        DELETE: func [port [port!] n][
            to string! write-nlb port join-of "DELE " n
        ]
        RSET: func [port [port!]][
            to string! write-nlb port "RSET"
        ]
        TOP: func [port [port!] n len][
            to string! write-nlb port reform ["TOP" n len]
        ]
        STAT: func [port [port!]][
            to string! write-nlb port {STAT}
        ]
    ]
]
