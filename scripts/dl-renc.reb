Rebol [
    file: %DL-renc.reb
    date: 6-May-2017
    author: "Graham"
    purpose: {allow download of a specific build from S3}
]

oses: copy []
builds: copy []
dates: copy []
files: copy [] ; os - date -name 

contents-rule: [
    thru <Contents> thru <Key> copy key: to </Key> thru <LastModified> copy date: to </LastModified> thru </Contents>
    (
        if parse key [thru "travis-builds/" copy os: to "/" "/" copy filename: to end][
            if parse filename [thru "r3-" [copy build: to "-" | copy build: to ".exe" | copy build: to end] to end][
                append oses os
                take/last date
                replace date "T" "/"
                append dates load date
                append builds build
                repend files [os filename date]
            ]
        ]

    )
]

DL-renc: func [][
    xml: to string! read http://metaeducation.s3.amazonaws.com  
    parse xml [some contents-rule]
    dates: sort unique dates
    oses: sort unique oses
    builds: sort unique builds
    files: sort/skip files 3
    os-specific: copy []

    default-os: find/tail find/tail form rebol/version "." "."
    cnt: 1
    print ["Available OSes: "]
    for-each os oses [print unspaced[++ cnt ": " os]]
    print newline
    forever [
        response: ask join-of default-os " Y/n/q "
        if response = "q" [halt]
        either any [empty? response find "Y yes" response][
            break
            ; accepted default OS
        ][
            forever [
                response: ask "enter OS by number: "
                if response = "q" [halt]
                if all [
                    attempt [response: to integer! response]
                    response > 0
                    response < cnt
                ][
                    default-os: pick oses response
                    break
                ]
            ]
            break
        ]
    ]
    for-each [os filename date] files [
        if os = default-os [
            repend os-specific [date filename]
        ]
    ]
    cnt: 1
    os-specific: sort/skip/reverse os-specific 2
    for-each [date filename] os-specific [
        print [++ cnt date filename]
    ]
    forever [
        response: ask "What filename by number? (1q)"
        if response = "q" [halt]
        if empty? response [response: 1]
        if not blank? attempt [response: to integer! response][
            if all [
                response > 0
                response < cnt
            ][
                break
            ]
        ]
    ]
    file: pick os-specific response * 2
    print ["Downloading ... " file]
    write to file! file read rejoin [http://metaeducation.s3.amazonaws.com/travis-builds/ default-os "/" file] ()
    print "Done."
]
