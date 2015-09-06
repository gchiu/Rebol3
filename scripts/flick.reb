Rebol [
    title: "Flick Electric Scraper"
    file: %flick.reb
    author: "Graham Chiu"
    date: 6-Sep-2015
    purpose: {grab the flick electric power charges for a particular day}
    version: 0.0.2
    notes: {dialected usage example is at the end of this file}
]

; you can download a rebol3 binary from http://www.rebolsource.net/

; urls for flick
flick-root: https://myflick.flickelectric.co.nz/
flick-signin: join flick-root "users/sign_in"
flick-daily: join flick-root "dashboard/day/"

; important cookies/values
flick-session-cookie-name: "_flick-customer-app_session"
authenticity_token: none

resources: [
    %prot-http.reb https://raw.githubusercontent.com/gchiu/Rebol3/master/protocols/prot-http.r3
    %combine.reb https://raw.githubusercontent.com/hostilefork/rebol-proposals/master/combine.reb
    %altjson.reb http://reb4.me/r3/altjson
]

; one time download files we need
foreach [script location] resources [
    unless exists? script [write script read location]
    do script
]

percent-encode: func [char [char!]] [
    char: enbase/base to-binary char 16
    parse char [
        copy char some [char: 2 skip (insert char "%") skip]
    ]
    char
]

url-encode: use [ch mk] [
    ch: charset ["_-." #"0" - #"9" #"A" - #"Z" #"-" #"a" - #"z" #"~"]
    func [text [any-string!]] [
        either parse/all text: form text [
            any [
                some ch | end | change " " "+" |
                mk: (mk: percent-encode mk/1)
                change skip mk
            ]
        ] [to-string text] [""]
    ]
]

to-webform: function [ pairs [block!]
    {web encodes a block of pair values}
][
    data: collect [
        foreach [var val] pairs [
            keep combine [url-encode var "=" url-encode val]
        ]
    ]
    combine/with data "&"
]

format-date: func [ date [date!]
    {formats date as yyyy-mm-dd}
][
    combine/with [ date/year next form 100 + date/month next form 100 + date/day ] "-"
]

extract-named-cookie: function [ set-cookie [string!] cookie [string!]
    {extracts named cookie from cookie string as a block}
][
    cookies: split set-cookie space
    cookie-jar: collect [
        forall cookies compose [
            if find/part cookies/1 cookie (length? cookie) [
                keep cookies/1
                break
            ]
        ]
    ]
]

grab-json: function [ html [string!]
    {extract json array from flick page}
][
    parse html [some [ to "<script" copy segment to "/script" thru ">" (
        if find segment "#day-chart" [
            parse segment [ thru "var" thru "data" thru "=" copy json thru "]}" 
                (if json [ return json])
            ]
        ]
    )]]
    none
]

get-day-data: function [ d [string! date!] flick-daily [url!] cookie-jar [block!]
    {return json data for a particular day}
][
    if string? d [ d: load d]
    either error? set/any 'err try [
        page: write join flick-daily format-date d compose/deep [ 
            GET [Cookie: (cookie-jar/1)]
        ]
    ][
        print "Error on accessing date data"
        ? err
        none
    ][
        load-json grab-json to string! page
    ]
]

grab-flick-session-cookie: function [ flick-signin [url!] flick-session-cookie-name [string!]
    {grab the initial cookies, and return only the session cookie}
][
    if error? set/any 'err try [ 
        port: write flick-signin [ headers GET [] ]
        unless parse to string! port/data [ thru {name="authenticity_token"} thru {value="} copy token to {"} (
            set 'authenticity_token token)
            to end
        ][
            print "unable to get authenticity token"
            return none
        ]
        cookie-jar: extract-named-cookie port/spec/debug/headers/set-cookie flick-session-cookie-name
    ][
        ?? err
        print "An error has occurred as above"
        return none
    ]
    either empty? cookie-jar [
        print [flick-session-cookie-name" cookie not found" ]
        none
    ][
        print ["We have the initial session coookie named" flick-session-cookie-name ]
        cookie-jar
    ]
]

login-to-site: function [ flick-signin [url!] cookie-jar [block!] data [string!] flick-session-cookie-name [string!]
    {login to site and return a block containing redirect and cookie-jar}
][
    either error? set/any 'err2 try [
        page: write flick-signin compose/deep [ 
            post [
                Referer: (flick-signin)
                Cookie: (cookie-jar/1)
            ]
            (data)
        ]
    ][
        either err2/arg2/response-parsed = 'redirect [
            ; this is correct, let's get the new session cookie
            clear cookie-jar
            if empty? cookie-jar: extract-named-cookie err2/arg2/headers/set-cookie flick-session-cookie-name [
                print ["Failed to get on attempted login" flick-session-cookie-name ]
                return none
            ]
            print ["We got the logged in cookie named" flick-session-cookie-name ]
        ][
            print "Something wrong, expected redirect on correct login.  Are credentials correct?"
            return none
        ]
        reduce [err2/arg2/headers/location cookie-jar]
    ][
        print "Redirect to dasboard expected here"
        print "You may have wrong username or password."
        none
    ]
]


flick-parser: function [ commands [block!]
    {processes a block of flick dialect commands}
][
    flick-rule: [
        some [
            'login set user email! set pass string! (
                cookie-jar: grab-flick-session-cookie flick-signin flick-session-cookie-name
                webdata: to-webform reduce ["authenticity_token" authenticity_token "user[email]" user "user[password]" pass "user[remember_me]" "0" "commit" "Log in"] 
                insert head webdata "utf8=%E2%9C%93&"
                
                if none? data: login-to-site flick-signin cookie-jar webdata flick-session-cookie-name [
                    throw "Unable to login - check userid and passsword.  Run aborted"
                ]
                ; print [ "redirecting to" data/1]
                redirect-page: data/1
                cookie-jar: data/2

                ; go to the redirect page i.e. the dashboard view
                port: write to url! redirect-page compose/deep [ 
                    headers
                    GET [ Cookie: (cookie-jar/1)]
                ]

                page-data: to string! port/data

                unless find page-data "So far this billing period you've spent:" [
                    print "Failed to get dashboard page"
                    write %error.html page-data
                    throw "Not redirected to dashboard.  New user with no data?  HTML page saved as %error.html.  Run aborted."
                ]
                print "We have the dashboard!"

            )
            any [
                'scrape 'day set chosen-date date! (
                    ; grab the chosen-date
                    if not json: get-day-data chosen-date flick-daily cookie-jar [
                        throw "No JSON data returned. Aborted."
                    ]
                    replace json/start_date "T" "/"
                    json/start_date: load json/start_date
                    unless equal? json/start_date/date chosen-date [
                        throw rejoin ["Unable to get data for this date of " chosen-date ]
                    ] 
                    periods: length? json/prices
                    out: join "Date, Price, Consumption, Cost" newline
                    total-cost: 0
                    total-units: 0
                    for time 1 periods 1 [
                        append out combine/with [
                            json/start_date
                            json/prices/:time
                            units: json/consumption/:time
                            charge: divide json/prices/:time * json/consumption/:time 100
                        ] ","
                        append out newline
                        json/start_date: json/start_date + 00:30
                        total-cost: total-cost + charge
                        total-units: total-units + units
                    ]
                    print ["Daily charge was" to money! total-cost newline "Daily consumption was" total-units "units"]
                )
                'save 'day set filename file! (
                    if out [
                        write filename out
                        print ["Daily data saved to file" filename ]
                        out: none
                    ]
                )
            ]
        ]
    ]

    catch [
        either parse commands flick-rule [
            print "Understood all your last commands"
        ][
            print "dialect error in your Flick commands"
        ]
    ]
]

flick: function [ commands [block!]
    {parses a block of flick commands surrounded by attempt blocks}
][
    runs: copy []
    parse commands [ some [
        'attempt set command block! (unless empty? command [append/only runs command])
    ]]
    either zero? len: length? runs [
        print "No runs scheduled"
    ][
        len: 1
        foreach run runs [
            print ["In run" ++ len ]        
            flick-parser run
        ]
    ]
]

; demonstration of dialect use
flick [
    attempt [
        login user@email1.co.nz "password1"
        scrape day 1-Aug-2015 save day %1-aug-2015.csv
        scrape day 2-Aug-2015 save day %2-Aug-2015.csv
    ]
    attempt [
        login user2@anotherplace.co.nz "password2"
        scrape day 3-Aug-2015 save day %3-aug-2015.csv
    ]
]