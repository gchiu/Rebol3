Rebol [
    system: "Rebol [R3] Language interpreter"
    title: "Rebol 3 SMTP scheme"
    author: "Graham"
    date: [9-Jan-2010 20-Jan-2013 3-May-2017]
    rights: BSD
    name: smtp
    type: module
    version: 0.0.8
    file: %prot-smtp.reb
    notes: {
        0.0.1 original tested in 2010
        0.0.2 updated for the open source versions
        0.0.3 Changed to use a synchronous mode rather than async.  Authentication not yet supported
        0.0.4 Added LOGIN, PLAIN and CRAM-MD5 authentication.  Tested against CommunigatePro
        0.0.5 Changed to move credentials to the url or port specification
        0.0.6 Fixed some bugs in transferring email greater than the buffer size.
        0.0.7 Fixed to now work with Ren-C
        0.0.8 Added TLS support.  Note that if your password does not work for gmail then you need to 
        generate an app password.  See https://support.google.com/accounts/answer/185833
        
        synchronous mode
        write smtp://user:password@smtp.clear.net.nz [ 
            from:
            name:
            to: 
            subject:
            message: 
        ]

        name, and subject are not currently used and may be removed
        
        eg: write smtp://user:password@smtp.yourisp.com compose [
            from: me@somewhere.com
            to: recipient@other.com
            message: (message)
        ]

        message: rejoin [ {To: } recipient@other.com {
From: } "R3 User" { <} me@somewhere.com {>
Date: Mon, 21 Jan 2013 17:45:07 +1300
Subject: testing from r3
X-REBOL: REBOL3 Alpha

where's my kibble?}]
        
        write [ 
            scheme: 'smtp 
            host: "smtp.yourisp.com"
            user: "joe"
            pass: "password"
            ehlo: "FQDN" ; if you don't have one, then substitute your IP address
        ] compose [
            from: me@somewhere.com
            to: recipient@other.com
            message: (message)
        ]
        
        Where message is an email with all the appropriate headers.
        In Rebol2, this was constructed by the 'send function
        
        If you need to use smtp asynchronously, you supply your own awake handler
        
        p: open smtp://smtp.provider.com
        p/state/connection/awake: :my-async-handler
    }
]

bufsize: 32000 ;-- use a write buffer of 32k for sending large attachments

mail-obj: make object! [ 
    from: 
    to:
    name: 
    subject:
    message: _
]

make-smtp-error: func [
    message
][
    FAIL ["smtp protocol error: " message]
]

; auth-methods: copy []
alpha: charset [#"a" - #"z" #"A" - #"Z"]

sync-smtp-handler: func [ event 
        /local client response state code line-response auth-key auth-methods ptr
    ] [
        line-response: _
        auth-methods: copy []
        net-log ["=== Client event:" event/type]
        ; client is the real port ie. port/state/connection
        client: event/port
        switch event/type [
            error [
                net-log "Network error"
                close client
                return true
            ]
            lookup [
                net-log "DNS lookup"
                open client
                false
            ]
            connect [
                net-log "connected, sending EHLO"
                client/spec/state: 'EHLO
                read client
                false
            ]

            read [
                net-log/S response: enline to-string client/data
                code: copy/part response 3
                if code = "501" [
                    make-smtp-error join-of "Unknown server error " response
                ]
                switch/default client/spec/state [
                    INIT [
                        if find/part response "220 " 4 [
                            ; wants me to send EHLO
                            write client to-binary net-log/C rejoin ["EHLO " any [ client/spec/ehlo "Rebol-PC" ] CRLF]
                            client/spec/state: 'AUTH
                        ]
                    ]
                    EHLO [
                        if find/part response "220 " 4 [
                            ; wants me to send EHLO
                            write client to-binary net-log/C rejoin ["EHLO " any [ client/spec/ehlo "Rebol-PC" ] CRLF]
                            client/spec/state: 'AUTH
                        ]
                        if find/part response "5" 1 [
                            net-log join-of "Server error code: " response
                            client/spec/state: 'END
                            return true
                        ]
                        if find/part response "4" 1 [
                            net-log join-of  "Server error code: " response
                            client/spec/state: 'END
                            return true
                        ]
                    ]
                    LOGIN [
                        case [
                            find/part response "334 VXNlcm5hbWU6" 16 [
                                ; username being requested
                                write client to-binary net-log/C join-of enbase client/spec/user CRLF
                            ]
                            find/part response "334 UGFzc3dvcmQ6" 16 [
                                ; pass being requested
                                ; net-log client/spec/user
                                ; net-log client/spec/pass

                                write client to-binary net-log/C join-of enbase client/spec/pass CRLF
                                client/spec/state: 'PASSWORD
                            ]
                            true [
                                make-smtp-error join-of "Unknown response in AUTH LOGIN " response
                            ]
                        ]

                    ]
                    
                    CRAM-MD5 [
                        case [
                            find/part response "334 " 4 [
                                auth-key: skip response 4
                                auth-key: debase auth-key
                                ; compute challenge response
                                auth-key: checksum/method/key auth-key 'md5 client/spec/pass
                                write client to-binary net-log/C join-of 
                                enbase reform [client/spec/user lowercase enbase/base auth-key 16] CRLF
                                client/spec/state: 'PASSWORD
                            ]
                            true [ 
                                make-smtp-error join-of "Unknown response in AUTH CRAM-MD5 " response
                            ]
                        ]
                    ]
                    
                    PASSWORD [
                        either find/part response "235 " 4 [
                            client/spec/state: 'FROM
                            write client to-binary net-log/C rejoin ["MAIL FROM: <" client/spec/email/from ">" CRLF ]
                        ][
                            ;-- failed authentication so close
                            make-smtp-error "Failed authentication"
                        ]
                    ]
                                        
                    AUTH [
                        if find/part response "220 " 4 [
                            ; wants me to send EHLO
                            write client to-binary net-log/C rejoin ["EHLO " any [ client/spec/ehlo "Rebol-PC" ] CRLF]
                        ]
                        ; should get a long string with all the options including authentication methods.
                        if code = "250" [
                            clear head auth-methods
                            parse response [
                                some [
                                    copy line-response to CRLF (
                                        parse line-response [
                                            "250" 
                                            ["-" | " " ] 
                                            ["AUTH" [" " | "="]
                                            any
                                                [ 
                                                    "CRAM-MD5" (append auth-methods 'cram) |
                                                    "PLAIN" (append auth-methods 'plain) |
                                                    "LOGIN" (append auth-methods 'login) |
                                                    space |
                                                    some alpha
                                                ] 
                                            | some alpha thru CRLF 
                                        ]
                                    ]) crlf
                                ]
                            ]
                            if find auth-methods 'plain [ client/spec/state: 'PLAIN ]
                            if find auth-methods 'login [ client/spec/state: 'LOGIN ]
                            if find auth-methods 'cram [ client/spec/state: 'CRAM-MD5 ]
                        ]

                        ; should now have switched from AUTH to a type of authentication
                        if client/spec/state != 'AUTH [
                            ; some servers will let you send without authentication if you're hosted on their network
                            either all [
                                blank? client/spec/user
                                blank? client/spec/pass
                            ][
                                client/spec/state: 'FROM
                                write client to-binary net-log/C rejoin ["MAIL FROM: <" client/spec/email/from ">" CRLF]
                            ][
                                switch/default client/spec/state [
                                    PLAIN [
                                        write client to-binary net-log/C rejoin [ "AUTH PLAIN " enbase rejoin [client/spec/user #"^@" client/spec/user #"^@" client/spec/pass] CRLF  ]
                                        client/spec/state: 'PASSWORD
                                        ]
                                    LOGIN [
                                        ; tell the server we are going to use AUTH LOGIN
                                        write client to-binary net-log/C join-of "AUTH LOGIN" CRLF
                                        client/spec/state: 'LOGIN
                                    ]
                                    CRAM-MD5 [
                                        ; tell server we are using CRAM-MD5
                                        write client to-binary net-log/C join-of "AUTH CRAM-MD5" CRLF
                                        client/spec/state: 'CRAM-MD5    
                                    ]
                                ][
                                    make-smtp-error "No supported authentication method"
                                ]
                                ; authentication is now handled by the main state loop except for Plain
                            ]
                        ]
                    ]
                    FROM [
                        either code = "250" [
                            write client to-binary net-log/C rejoin ["RCPT TO: <" client/spec/email/to ">" crlf]
                            client/spec/state: 'TO
                        ] [
                            net-log "rejected by server"
                            return true
                        ]
                    ]
                    TO [
                        either code = "250" [
                            client/spec/state: 'DATA
                            write client to-binary net-log/C join-of "DATA" CRLF
                        ] [
                            net-log "server rejects TO address"
                            return true
                        ]
                    ]
                    DATA [
                        either code = "354" [
                            replace/all client/spec/email/message "^/." "^/.."
                            client/spec/email/message: ptr: rejoin [ enline client/spec/email/message ]
                            net-log/C "sending 32K"
                            write client copy/part ptr bufsize
                            remove/part ptr bufsize
                            client/spec/state: 'SENDING
                        ] [
                            net-log "Not allowing us to send ... quitting"
                        ]
                    ]
                    
                    END [
                        either code = "250" [
                            net-log "message successfully sent."
                            client/spec/state: 'QUIT
                            write client to-binary net-log/C join-of "QUIT" crlf
                            return true
                        ] [
                            net-log "some error occurred on sending."
                            return true
                        ]
                    ]
                    QUIT [
                        net-log "Should never get here"
                    ]
                ] [net-log join-of "Unknown state " client/spec/state]
            ]
            wrote [
                either client/spec/state = 'SENDING [
                    either not empty? ptr: client/spec/email/message [
                        net-log/C [ "sending " min bufsize length? ptr " bytes of " length? ptr ]
                        write client to-binary copy/part ptr bufsize
                        remove/part ptr bufsize
                    ][
                        write client to-binary net-log/C rejoin [ crlf "." crlf ]
                        client/spec/state: 'END
                    ]
                ][
                    read client
                ]
            ]
            close [net-log "Port closed on me"]
        ]
        false
    ]
    
sync-write: func [ port [port!] body
    /local state result
][
    unless port/state [open port port/state/close?: yes]
    state: port/state
    ; construct the email from the specs 
    port/state/connection/spec/email: construct mail-obj body
    
    port/state/connection/awake: :sync-smtp-handler
    if state/state = 'ready [ 
        ; the read gets the data from the smtp server and triggers the events that follow that is handled by our state engine in the sync-smtp-handler
        read port 
    ]
    unless port? wait [state/connection port/spec/timeout][make-smtp-error "SMTP timeout"]
    if state/close? [close port]
    true
]
    
sys/make-scheme [
    name: 'smtp
    title: "SMTP Protocol"
    spec: make system/standard/port-spec-net [
        port-id: 25
        timeout: 60
        email: ;-- object constructed from argument
        ehlo: 
        user:
        pass: _
    ]
    actor: [
        open: func [
            port [port!]
            /local conn
        ] [
            if port/state [return port]
            if blank? port/spec/host [
                make-smtp-error "Missing host address when opening smtp server"
            ]
            ; set the port state to hold the tcp port
            port/state: context [
                state:
                connection:
                error: 
                awake: _  ;-- so port/state/awake will hold the awake handler :port/awake
                close?: no   ;-- flag for us to decide whether to close the port eg in syn mode
            ]
            ; create the tcp port and set it to port/state/connection
            if blank? system/user/identity/fqdn [make-smtp-error "Need to provide a value for the system/user/identity/fqdn"]
            either find [465 587 2525] port/spec/port-id [
                port/state/connection: conn: make port! [
                    scheme: 'tls
                    host: port/spec/host
                    port-id: port/spec/port-id
                    state: 'INIT
                    ref: rejoin [tls:// host ":" port-id]
                    email: port/spec/email
                    user: port/spec/user
                    pass: port/spec/pass
                    ehlo: any [port/spec/ehlo system/user/identity/fqdn]
                ]
            ][
                port/state/connection: conn: make port! [
                    scheme: 'tcp
                    host: port/spec/host
                    port-id: port/spec/port-id
                    state: 'INIT
                    ref: rejoin [tcp:// host ":" port-id]
                    email: port/spec/email
                    user: port/spec/user
                    pass: port/spec/pass
                    ehlo: any [port/spec/ehlo system/user/identity/fqdn]
                ]
            ]

            open conn ;-- open the actual tcp port
            
            net-log "port opened ..."
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
                port/state/connection/awake: _
                port/state: _
            ]
            port
        ]

        read: func [
            port [port!]
        ] [
            either any-function? :port/awake [
                either not open? port [
                    net-log "opening & waiting on port"
                    unless port? wait [open port/state/connection port/spec/timeout] [make-smtp-error "Timeout"]
                    ; wait open port/state/connection
                ] [
                    net-log "waiting on port"
                    unless port? wait [port/state/connection port/spec/timeout] [make-smtp-error "Timeout"]
                ]
                port
            ] [
                make-smtp-error  "No read handler for the port exists yet"
                ; should this be used at all for smtp?
            ]
        ]

        write: func [
            port [port!] body [block!]
            /local conn email
        ][
            sync-write port body
        ]
    ]
]
