REBOL [
    title: "GUI http server"
    author: "Graham Chiu" 
    date: 12-July-2014
    file: %gui-server.reb
    notes: {
    http server was based on abolka's code

    Once the GUI comes up, click on the buttons and run the client %task-client.reb

    }
]

load-gui

digit: charset [ #"0" - #"9"]

code-map: make map! [200 "OK" 400 "Forbidden" 404 "Not Found"]
mime-map: make map! ["html" "text/html" "jpg" "image/jpeg" "r" "text/plain"]
error-template: {
    <html><head><title>$code $text</title></head><body><h1>$text</h1>
    <p>Requested URI: <code>$uri</code></p><hr><i>shttpd.r</i> on
    <a href="http://www.rebol.com/rebol3/">REBOL 3</a> $r3</body></html>
}

error-response: func [code uri /local values] [
    values: [code (code) text (code-map/:code) uri (uri) r3 (system/version)]
    reduce [code "text/html" reword error-template compose values]
]

send-response: func [port res /local code text type body] [
    set [code type body] res
    write port ajoin ["HTTP/1.0 " code " " code-map/:code crlf]
    write port ajoin ["Content-type: " type crlf crlf]
    write port body
]

handle-request: func [config req /local uri type file data t] [
    print ["Request is: " to string! req]
    default 'type "text/plain"
    default 'data "Notok"

    req: to string! req
    case [
        parse req [
            "get" space ["/" space 
            | 
            copy uri to space] to end
        ][ 
            ; get case is okay
        ]

        parse req [ 
            "post" space [ "/" space 
            |
            copy uri to " " (?? 0) thru "Content-length: " (?? "cl") copy length some digit (?? 1) thru "^/^/" copy payload to end (
                ; get the task-id
                parse uri [ "/answer-task/" copy task-id to end]
                uri: copy "/answer-task"
                print [ "Content-length: " length]
                print [ "Read: " length? payload]
            )
            ]
        ]
        true [ ; unrecognised verb
            print "failed parse of request, unrecognized verb?"
            ; need to return some type of error here
        ]
    ]

    ?? uri
    case [
        uri = "/request-task" [
            print "requested a task"
            if 0 < length? queue [
                print "checking for tasks to be done"
                forall queue [
                        if all [ none? queue/1/start none? queue/1/end][
                            ; found a task that needs doing
                            print "Got a task"
                            queue/1/start: now/precise
                            data: mold/all queue/1
                            ?? data
                            break
                        ]
                ]
            ]
        ]

        uri = "/answer-task" [
            print "got an answer"
            task-id: to integer! task-id
            ?? task-id
            data: copy "Notok"
            forall queue [
                t: queue/1
                if t/id = task-id [
                    t/end: now/precise
                    t/callback payload
                    data: copy "OK"
                    remove queue
                    break
                ]
            ]
        ]

        true [data: copy "Notok"]
    ]
    reduce [200 type data]
]

awake-client: func [event /local port res] [
    port: event/port
    print [ "event: " event/type ]
    switch event/type [
        read [
            either find port/data to-binary join crlf crlf [
                res: handle-request port/locals/config port/data
                send-response port res
            ] [
                read port
            ]
        ]
        wrote [close port]
        close [close port]
    ]
]

awake-server: func [event /local client] [
    if event/type = 'accept [
        client: first event/port
        client/awake: :awake-client
        read client
    ]
]

serve: func [web-port web-root /local listen-port] [
    listen-port: open join tcp://: web-port
    listen-port/locals: construct compose/deep [config: [root: (web-root)]]
    listen-port/awake: :awake-server
    wait listen-port
]

task: make object! [
    id: none
    callback: none
    created: none
    start: none
    end: none
    cancelled: false
    cmd: none
]

Queue: copy []
task-counter: 0

view/no-wait [
    vgroup [
        hgroup [
            vgroup [
                area1: area
                button "Task 1" on-action [
                    t: make task [
                        id: ++ task-counter
                        callback: func [data][set-face area1 data show-now area1]
                        created: now/precise
                        cmd: [read http://www.rebol.com]
                    ]
                    append queue t
                    set-face area1 ""
                    set-face tstatus "added task 1"
                    set-face tcount length? queue
                ]
            ]
            vgroup [
                area2: area
                button "Task 2" on-action [
                    t: make task [
                        id: ++ task-counter
                        callback: func [data][set-face area2 data  show-now area2]
                        created: now/precise
                        cmd: [read http://rheum.mooo.com/2014/06/08/a-cure-for-diabetes/]
                    ]
                    append queue t
                    set-face area2 ""
                    set-face tstatus "added task 2"
                    set-face tcount length? queue
                ]
            ]
        ]
        hgroup [
            vgroup [
                area3: area
                button "Task 3" on-action [
                    t: make task [
                        id: ++ task-counter
                        callback: func [data][set-face area3 data  show-now area3]
                        created: now/precise
                        cmd: [read http://www.rebol.net]
                    ]
                    append queue t
                    set-face area3 ""
                    set-face tstatus "added task 3"
                    set-face tcount length? queue
                ]
            ]
            vgroup [
                area4: area
                button "Task 4" on-action [
                    t: make task [
                        id: ++ task-counter
                        callback: func [data][set-face area4 data  show-now area4]
                        created: now/precise
                        cmd: [read http://www.rebolsource.net]
                    ]
                    append queue t
                    set-face area4 ""
                    set-face tstatus "added task 4"
                    set-face tcount length? queue
                ]
            ]
        ]
    ]
    hgroup [
        button "Halt" red on-action [unview/all halt]
        tstatus: field
        tcount: field
    ]
]

print "waiting on port 8080"
serve 8080 system/options/path