Rebol [
    title: "Flick Electric Scraper"
    file: %flick.reb
    author: "Graham Chiu"
    date: 6-Sep-2015
    purpose: {grab the flick electric power charges for a particular day}
    version: 0.0.3
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
    %altwebform.reb http://reb4.me/r3/altwebform
]

; one time download files we need
foreach [script location] resources [
    unless exists? script [write script read location]
    do script
]

; create a shortcut to user context
u: self 

format-date: func [ {formats date as yyyy-mm-dd}
	date [date!]
][
    combine/with [ date/year next form 100 + date/month next form 100 + date/day ] "-"
]

extract-named-cookie: function [ {extracts named cookie from cookie string as a block}
	set-cookie [string!] cookie [string!]
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

grab-json: function [ {extract json array from flick page}
	html [string!]
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

get-day-data: function [ {return json data for a particular day}
	d [string! date!] flick-daily [url!] cookie-jar [block!]
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

grab-flick-session-cookie: function [ {grab the initial cookies, and return only the session cookie}
    flick-signin [url!] flick-session-cookie-name [string!]
][
    if error? set/any 'err try [ 
        port: write flick-signin [ headers GET [] ]
        unless parse to string! port/data [ 
        	thru {name="authenticity_token"} thru {value="} copy token to {"} (set 'authenticity_token token) to end 
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

login-to-site: function [ {login to site and return a block containing redirect and cookie-jar}
    flick-signin [url!] cookie-jar [block!] data [string!] flick-session-cookie-name [string!]
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


flick-parser: function [ {processes a block of flick dialect commands}
    commands [block!]
][
    flick-rule: [
        some [
            'login set user email! set pass string! (
                cookie-jar: grab-flick-session-cookie flick-signin flick-session-cookie-name
                token: u/authenticity_token
                webdata: to-webform/ruby-style [
                	utf8: "^(2713)"
					authenticity_token: :token
					user: [
						email: :user
						password: :pass
						remember_me: 0
					]
					commit: "Log in"
				]	
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

flick: function [ {parses a block of flick commands surrounded by attempt blocks}
    commands [block!]
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