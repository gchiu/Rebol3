rebol [
    file: %prot-spop3.reb
    notes: {
        using Gabriele's FSM to write the pop3 async handler
    }
    date: 28-jan-2013
    author: "Graham"
    version: 0.0.1
          notes: {
                see script at end for use ..
                most actors not iplemented yet

          }

]

; no longer needed - use the core with tls
; do %prot-tls.r
; http://www.rebol.it/power-mezz/dialects/fsm.html
do %fsm2.r ; get this from above

digit: charset [#"0" - #"9" ]
alphanum: union digit charset [ #"a" - #"z" #"A" - #"Z" #"-" ]

make-pop3-error: func [
    message
][
    do make error! [
        type: 'Access
        id: 'Protocol
        arg1: message
    ]
]
net-log: func [txt
    /C
    /S
] [
    if C [prin "C: "]
    if S [prin "S: "]
    print txt
    txt
]

; this would be some user object somewhere
user: make object! [
	name: "Graham Chiu" ; string!
	email: yours-goes-here@gmail.com ; email!
	smtp:  "smtp.gmail.com" ; ip address or name
	pop3: "pop.gmail.com" ; ip address or name
	user: "yours-goes-here@gmail.com" ; or esmtp-user
	pass: "...yours goes here ...." ; or esmtp-pass
	ehlo: "Rebol-PC"
]

; the finite state machine to handle the pop3 dialog
pop3-fsm: make-fsm [
        initial-state: [
            init: capa
            +OK: (
                print "we got an +OK from the server so can move to the capa state"
                write data/1 net-log/C "CAPA^/"
            ) capa
                 -ERR: quitstate

                  ; use the initial-state for a jump table by resetting the fsm, and then process-event with the one you need to then jump to another state
            ; move to the RETR state
            retr: override retr-n retr
            default: (print ["event: " data/2]) quitstate
        ]

        capa: [
            ; need to process the incoming text until we receive a "." alone on aline
            ; SASL LOGIN PLAIN CRAM-MD5 DIGEST-MD5 GSSAPI MSN NTLM
            +OK: (print "getting capa list" read data/1)
                  -ERR: quitstate
            .: (print "end of the capa"
                probe data/1/spec/auth-methods
            ) override auth authenticate
            default: (
                parse/all data/2 [
                    some [
                        "SASL" (append data/1/spec/auth-methods 'SASL) |
                        "PLAIN" (append data/1/spec/auth-methods 'PLAIN) |
                        "LOGIN" (append data/1/spec/auth-methods 'LOGIN) |
                        "CRAM-MD5" (append data/1/spec/auth-methods 'CRAM-MD5) |
                        "DIGEST-MD5" (append data/1/spec/auth-methods 'DIGEST-MD5) |
                        "ANONYMOUS" (append data/1/spec/auth-methods 'ANONYMOUS) |
                        "SASL" (append data/1/spec/auth-methods 'SASL) |
                        "GSSAPI" (append data/1/spec/auth-methods 'GSSAPI) |
                        space |
                        copy capability some alphanum ( append data/1/spec/capa capability ) |
                        to end
                    ]
                ]
            )
        ]		

        authenticate: [
            auth: (
                ; we now need to authenticate ourselves
				?? data/1/spec/auth-methods
comment {
                if find data/1/spec/auth-methods 'PLAIN [
                    write data/1 net-log/C rejoin ["User " user/user crlf]
                    ; write data/1 net-log/C "AUTH PLAIN^/"
                    ;write data/1 net-log/C rejoin [ "AUTH PLAIN " enbase rejoin [#"^@" data/1/spec/user #"^@" data/1/spec/pass] crlf]
                ]
}
				;if find/data/1/spec/auth-methods 'LOGIN [
					write data/1 net-log/C rejoin [ "USER " user/email crlf ]
				;]
            )
            +OK: (
                ; accepted the USER
                write data/1 net-log/C rejoin ["PASS " user/pass crlf]
            ) transaction
                  -ERR: quitstate
        ]

        transaction: [
            +OK: (
                print ["logged in: " data/2]
                write data/1 net-log/C "UIDL 1^/"
            ) stat
                -ERR: quitstate

            .: [print "end of list"]
        ]

        stat: [
            default: (
                print ["In Stat: " data/2]
				data/1/spec/return?: true
            )
            +OK: (
                print "end of stat list"
				; data/1/spec/return?: true
                write data/1 net-log/C "LIST 1^/"
            ) 
                 -ERR: quitstate
        ]

        RETR: [
            ; let's just get the first message and store it in data field in the port spec
            retr-n: (print "In initial retr state")
            +OK: (print "message should now come"
                        clear head data/1/spec/email
                        read data/1
            )
                  -ERR: quitstate
            default: (
                ; prin reform ["Appending data of amout: " length? data/2 " "]
                append data/1/spec/email join data/2 newline
            )
            .: (
                print "got the email"
                            data/1/spec/return?: true
            ) 
        ]

        list: [
            .: (print "end of list cmd"
                data/1/spec/return?: true

            ) ; override retr1 retr
            +OK: (print "list is now coming"
            )
            ; should grab all the details and store in port/spec
            default: (
                ; print [ "default: " form data/2 ] 
                parse to-block data/2 [set num integer! (append data/1/spec/messages num) set size integer! (append data/1/spec/messages form size)]
                probe data/1/spec/messages
            )
        ]

        QUITSTATE: [
            default: (
                net-log "closing port"
                close data/1
                data/1/spec/close?: true
            )
        ]

]

pop3-awake: func [event /local response ] [
    print ["Awake-event:" event/type]
    switch/default event/type [
        lookup [open event/port]
					lookup [
						print "DNS lookup finished"
					]
                    connect [
						;write event/port  net-log/C "CAPA^/"
                        read event/port
                    ]

                    wrote [
                        read event/port
                    ]

                    read [
                              len: length? response: to string! copy event/port/data
                        print ["Read" len: length? response "bytes"]
                              ; prin "."
                              remove/part event/port/data len
                              probe copy/part response 200
                        ; each line needs to be examined for a code: +OK, -ERR, . or .. for termination.  Everything else is data and goes to the default event for the current state      
                        foreach line parse/all response "^/" [
                            code: copy/part line 3
                            case [
                                all [code/1 = #"." code/2 = #"^/"] [code: copy "."]
                                ".." = copy/part line 2 [remove line code: none]
                            ]
                            switch/default code [
                                "+OK" [process-event pop3-fsm '+OK reduce [event/port line]]
                                "-ERR" [process-event pop3-fsm '-ERR reduce [event/port line]]
                                "." [process-event pop3-fsm '. reduce [event/port line]]
                            ] [
                                                 code: 'default
                                process-event pop3-fsm 'default reduce [event/port line]
                            ]
                        ]
                              if code = 'default [
                                ; print "Not at end of data, so read more" 
                                read event/port 
                            ]
                            if event/port/spec/return? [
                                        print "return? is true"
                            event/port/spec/return?: false
                            return true
                        ]
                        if event/port/spec/close? [
                                       print "close? is true"
                            return true
                        ]
                              if code = 'default [
                                ; print "Not at end of data, so read more" 
                                read event/port 
                            ]
                    ]
                    close [
                        print "got close event, so close and return "
                        close event/port
                        return true   
                    ]

    ] [
        print ["Unexpected event:" event/type]
        close event/port
        return true
    ]
    false
]

sys/make-scheme [
    name: 'pop3
    title: "Rebol3 POP3"
    spec: make system/standard/port-spec-net [
        timeout: 60
        port-id: 995
    ]
    actor: [
                open: func [
                    port [port!]
                    /local conn
                ] [
                    if port/state [return port]
                    if none? port/spec/host [make-pop3-error "Missing host address"]
                    port/state: context [
                        connection: none
                    ]
                    port/state/connection: conn: make port! compose [
                        scheme: 'tls
                        host: port/spec/host
                        port-id: port/spec/port-id
                        ref: rejoin [tls:// host ":" port-id]
                        user: port/spec/user
                        pass: port/spec/pass
                        capa: copy []
                        auth-methods: copy []
                        messages: copy []
                        data: copy ""
                                    email: copy ""
                        close?: false
                        return?: false
                    ]
                    conn/awake: :pop3-awake
                    conn/locals: port
                    open conn
                    port
                ]

                close: func [
                    port [port!]
                ] [
                    close port/state/connection
                ]

                length?: func [port [port!] /local len] [
                    either 0 < len: length? port/state/connection/spec/messages [
                        len / 2
                    ] [
                        0
                    ]
                ]

                pick: func [port [port!] n [integer!]] [
                    n: max n 1
                    either not find port/state/connection/spec/messages n [
                        return none
                    ] [
                        ; found the email to retrive
                        write port/state/connection net-log/C rejoin ["RETR " n crlf]
                        ; just initiate a change of state but don't do anything
                        reset-fsm pop3-fsm
                        process-event pop3-fsm 'retr []
                                    ; now get the response
                        read port
                        return port/state/connection/spec/email
                    ]
                ]

                query: func [port [port!]
                    /local out
                ] [
                    out: copy [ ]
                    append out reform port/state/connection/spec/capa
                    append/only out port/state/connection/spec/messages
                    return out
                ]

                remove: func [port [port!]] [
                    print "you removed something"
                ]

                insert: func [port [port!] val] [
                    print "not supported on the pop3 mbox"
                ]

                read: func [
                    port [port!]
                ] [
                    open port
                    unless port? wait [port/state/connection port/spec/timeout] [
                        print "Timeout"
                        close port/state/connection
                    ]
                ]

    ]
]

print ""

pop3-fsm/tracing: false

; setup the user object and the message at the top of this script before running it
mbox: open compose [
    scheme: 'pop3
    user: (user/user)
    pass: (user/pass)
    host: (user/pop3) 
          timeout: 120
]

halt
read mbox

email: pick mbox 10
email: pick mbox 5
print query mbox


halt

