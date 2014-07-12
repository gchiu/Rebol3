#!/usr/local/bin/rebol3 -cs
Rebol [
	title: "WxC broadband usage"
	file: %loginxport.reb
	author: "gchiu"
	rights: 'bsd
	date: 12-July-2014
	notes: {needs rebol3 with https. prints WxC's data usage page to the browser}
	version: 0.0.2
]

;; need to make these your own
user: "yourWxCusername"
password: "yourWxCportalpassword"

loginpage: https://www.xport.co.nz

; we're going to fake the google analytics, may not even be neccesary
fixed-cookie: ajoin [
	space
	{usage_units=mb;} space 
	;; google analytic cookies
	{__utma=183813615.1685615688.1403992183.1405076746.1405109092.41;} space 
	{__utmc=183813615;} space 
	{__utmz=183813615.1403992183.1.1.utmcsr=(direct)|utmccn=(direct)|utmcmd=(none)}
]

; grab my custom http protocol
do https://raw.githubusercontent.com/gchiu/Rebol3/master/protocols/prot-http.r3

; returns a bunch of pairs from a form
parse-form: funct [txt][
	data: copy []
	quot: charset [ #"^""  #"'"]
	alpha: complement union quot charset space
	; get the form action and method
	tmp: copy []
	parse txt [
		thru "action" any space "=" any space any quot copy action some alpha (
			append tmp join loginpage action
			;?? tmp
			;print tmp/1
		)
	]
	parse txt [
		thru "method" any space "=" thru {"} copy method to {"} (
			append tmp method
			append/only data tmp
		)
	]
	; now get the input name vaue pairs
	html: decode 'markup to-binary txt
	foreach tagged html [
		parse tagged [
			any space "input" thru "name" thru "=" any space quot copy name  some alpha
			(
				repend/only data copy [name ""] value: none
			)
			thru "value" any space "=" any space quot copy value  some alpha to end
			(if tag? value [
					append remove back tail last data value
				]
			)
		]
	]
	; ?? data
	data
]

; using my debug mode to grab the headers, and cookies
loginobject: write loginpage [ headers GET /]

login: to string! loginobject/data
cookies: collect [ 
	foreach crumb loginobject/spec/debug/headers/set-cookie [ 
		keep append first parse crumb none ";"
	]
]

login-cookie: rejoin [ cookies fixed-cookie ]

; ?? login-cookie

; grab the form

if parse login [ thru "<form" copy form1 to </form> to end ][
	; print "got the form"
	replace/all form1: to string! form1 {'} {"}
	pairs:  parse-form form1
	; build the submit string
	target: first take pairs
	payload: copy ""
	foreach pair pairs [
		case [
			pair/1 = <username> [ append payload ajoin [ "username=" user "&"]]
			pair/1 = <password> [ append payload ajoin [ "password=" password "&"]]
			pair/1 = <next> []
			true [ append payload rejoin [to string! pair/1 "=" to string! pair/2 "&"]]
		]
	]
	;take/last payload
	append payload "next="
	;?? payload
	;?? target

	if error? err: try [
		result: to string! write target compose/deep [ 
			POST  
			[ 
				Accept: "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8"
				Origin: https://www.xport.co.nz
				Referer: https://www.xport.co.nz/
				Accept-Encoding: "gzip,deflate,sdch"
				Accept-Language: "en-GB,en-US;q=0.8,en;q=0.6"
				Content-Type: "application/x-www-form-urlencoded; charset=utf-8"
				cookie: (login-cookie)	
			]
			(payload)
		]
	][
		; we should now have the new sessionid, and redirect page
		redirect: to url! err/arg2/headers/location
		parse err/arg2/headers/set-cookie [ to "sessionid" copy sessionid thru ";"]
	]
]

;?? redirect
;?? sessionid
;?? cookies

forall cookies [
	if "sessionid" = copy/part cookies/1 9 [
		remove cookies
		; print "removed old sessionid"
		break
	]
]

append cookies sessionid

;?? cookies

session-cookie: reform [ cookies fixed-cookie ]

; we want broadband usage
broadband-data: to string! write rejoin [ redirect "/services/internet/broadband/" user "/" ] compose/deep [ GET [ cookie: (session-cookie) "/" ]]

; turn all relative urls into absolute
foreach [original final] [
	{src="/} {src="https://www.xport.co.nz/}
	{href="/} {href="https://www.xport.co.nz/}
][
	replace/all broadband-data original final
]

prin ["Content-type: text/html" crlf crlf]
print broadband-data

; for local testing, uncomment these next two lines
; write %broadband.html broadband-data
; browse %broadband.html
