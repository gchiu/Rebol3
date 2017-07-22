Rebol [
    title: "Flick Electric Scraper"
    file: %flick-price-scraper.reb
    author: "Graham Chiu"
    date: [6-Sep-2015 22-July-2017]
    purpose: {grab the flick electric power charges for a particular day}
    version: 0.1.0
    needs: [
    	<json>
    	<webform>
    	<xml>
    ]
    help: https://forum.rebol.info/t/flickelectric-utilities/207/2
    notes: {usage example is at the end of this file}
    username: your-flick-login-email@goes-here.com
	password: "your-flick-password-goes-here"
]

; you can download a rebol3 binary from http://www.rebolsource.net/

; urls for flick
flick-dashboard: https://myflick.flickelectric.co.nz/dashboard?_ga=2.251743488.820465368.1500584817-1588233765.1497340737

flick-root: https://myflick.flickelectric.co.nz/
flick-signin: join-of flick-root "users/sign_in"
flick-daily: join-of flick-root "dashboard/day/"

username: system/script/header/username 
password: system/script/header/password

net-trace off
??: :dump

; import %prot-http-test.reb

format-date: func [{formats date as yyyy-mm-dd}
	date [date!]
][
    delimit [ date/year next form 100 + date/month next form 100 + date/day ] "-"
]

cookie-jar: copy make map! []

find-all-cookies: function [
	{given a cookie string or block, all cookies are returned}
	cookie-string [string! block!]
][
    cookies: copy []
    if string? cookie-string [
        tmp: copy []
        append tmp cookie-string
        cookie-string: tmp
    ]
    for-each cookie cookie-string [
        for-each element split cookie ";" [
            trim/head/tail element
            if all [
                find element "=" 
                not find element "path="
                not find element "MAX-AGE="
            ][
                append cookies element
            ]
        ]
    ]
    cookies
]

read-http: function [{Read a page, capture cookies, send cookies and follow redirects}
    url [url!]
][
    cnt: 1
    forever [
        site: sys/decode-url url
        if find cookie-jar site/host [
            cookies: cookie-jar/(site/host)
        ]
        cookies: default [""]
        either empty? cookies [
            result.o: trap [write url [headers no-redirect GET []]]
        ][
            result.o: trap [write url compose/deep [headers no-redirect GET [cookie: (cookies)]]]
        ]
        ; got the headers I hope
        headers: result.o/spec/debug/headers
        ; save the cookies
        if find headers 'set-cookie [
            cookies: find-all-cookies headers/set-cookie
            if not empty? cookies [
                either find? cookie-jar site/host [
                    repend cookie-jar [lock site/host cookies]
                ][
                    lock site/host
                    cookie-jar/(site/host): cookies
                ]
            ]
        ]
        if not find headers 'location [
            break
        ]
        ; get the redirect
        url: to url! headers/location
    ]
    ; return the url body and url
    return make object! compose [
        url: (url)
        body: (to string! result.o/data)
    ]
]

; flick-dashboard
login-to-flick: function [
	url [url!]
][
	; keep reading and following redirects until we reach the login page
	html.o: read-http url
	html: html.o/body
	; site will hold the decoded url so we can create the POST url
	site: sys/decode-url html.o/url

	; extract the webform
	parse html [to "<form" copy wform: to "</form" to end]
	form-rule: ["<form" thru {action="} copy form-action: to {"} thru {method="} copy form-method: to {"} thru ">"]

	; grab the action and method for the form-
	parse wform form-rule
	; convert the extract webform to xml so that we can parse it	
	webform: load mold load-xml wform

	; now parse the webform to extract all the variables
	inputs: collect [
	    use [rule hit][
	        parse webform rule: [
	            some [
	                opt [
	                    hit: [<input> | <button>] block! (
	                        tmp1: keep select hit/2 #name
	                        tmp2: select hit/2 #value
	                        case [
	                            "user[email]" = form tmp1 [keep username]
	                            "user[password]" = form tmp1 [keep password]
	                            "user[remember_me]" = form tmp1 [keep 0]
	                            true [keep tmp2]
	                        ]
	                    ) :hit
	                ]
	                skip [and block! into rule | skip]
	            ]
	        ]
	    ]
	]

	; collect all the variable pairs into a single block
	form-object: copy []

	for-each [name value] inputs [
	    append form-object reduce [to-word name value]
	]
	; and now url encode it and pack it ready for POSTing
	data: to-webform/ruby-style form-object

	; get the URL for the POST
	post-url: to url! remove unspaced [site/scheme "://" site/host]
	append post-url form-action

	; extract the cookie from the cookie-jar
	cookie: delimit cookie-jar/(site/host) "; "

	; now post the form data to the POST url, and disallow redirects
	result: trap [write post-url compose/deep [headers no-redirect POST [cookie: (cookie)] (data)]]

	; we now have the headers in our debug object
	headers: result/spec/debug/headers

	; grab the new cookies from id.flickelectric
	site: sys/decode-url post-url

	if find headers 'set-cookie [
	    cookies: find-all-cookies headers/set-cookie
	    if not empty? cookies [
	        either find? cookie-jar site/host [
	            repend cookie-jar [lock site/host cookies]
	        ][
	            lock site/host
	            cookie-jar/(site/host): cookies
	        ]
	    ]
	]

	dump cookie-jar
	headers
]

save-csv-data: procedure [
	{Given a date for which we have data, save it as a CSV file %date.csv.  Uses "," unless specified otherwise}
	date [date!]
	/delimiter char 
][
	if not delimiter [char: ","]
	daily-total: 0

	; format to string needed for the flick url
	d: format-date date
	; read the data
	html.o: read-http join-of flick-daily d
	; if we have json data, let's save it.  Assumes whole day of data at present
	if parse html.o/body [thru "var data =" copy json: thru "}" to end ][
		rebol-values: load-json json
		; dump rebol-values
		time: 0:00:00 - 00:30:00
		data: copy []
		cnt: 1
		loop 48 [
			repend data [
				time: time + 00:30:00
				rebol-values/prices/:cnt
				rebol-values/consumption/:cnt
			]
			; time: time + 00:30:00
			++ cnt
		]
		d: rebol-values/start_date
		replace d "T" "/"
		d: load d
		d: d/date
		; if the date for the data is not returned, then we're too far in the future and so flick returns
		; the last date it has data
		either d = date [
			csv: delimit ["time" "cent" "units" "cost"] char
			append csv newline

			for-skip data 3 [
				append csv delimit reduce [data/1 data/2 data/3 daily: round/to (data/2 * data/3) .01 |] char 
				daily-total: daily-total + daily
			]
			write to file! unspaced [d %.csv] csv ()
			print ["Daily total:" to money! round/to daily-total / 100 .01]
		][ print ["No data for" date]]
	]
]

;; ======example of capturing all the daily use from 1-July-2017 - 20-July-2017

; authenticate and grab all the necessary cookies
login-to-flick flick-dashboard

; we're going to save it in a flick directory
cd %flick/

; let's grab the data for what we have of July 2017
start_date: 1-July-2017
end_date: 21-July-2017

; step thru each date until you read the end_date
while [start_date < end_date][
	print ["Collecting data for" start_date]
	save-csv-data/delimiter ++ start_date ";"
]
