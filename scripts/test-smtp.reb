Rebol [
	file: %test-smtp.reb
    notes: {needs a build newer than 5-May-2017}
]

system/user/identity/fqdn: "ihug.co.nz" ; this needs to be done before importing the protocol, preferably in user.r
import %prot-smtp.reb

to-itime: func [
    {Returns a standard internet time string (two digits for each segment)}
    time [time! number!]
][
    time: make time! time
	rejoin [
		next form 100 + time/hour ":"
		next form 100 + time/minute ":"
		next form 100 + round/down time/second
	]
]

date2edate: func [ date ][
	unspaced [
		copy/part pick system/locale/days date/3 3
		", "
		date/3 space
		copy/part pick system/locale/months date/2 3 space
		date/1 space
		to-itime date/4 space
		either date/5 >= 0:00 ["+"]["-"]
		date/5
	]
]

; ==
; this should be setup in user.r 
system/user/identity/fqdn: "ihug.co.nz"

; bring in the protocol now
import %prot-smtp.reb ; or import <smtp>

; construct a valid email message
message: ajoin [{To: } me@gmail.com {
From: } "Graham Chiu" { <} drme@clear.net.nz {>
Date: } date2edate now {
Subject: testing from renc
X-REBOL: Ren-C } rebol/commit {

where's my kibble?}]

net-trace on

write smtp://me@gmail.com:gmail-application-password@smtp.gmail.com:465 compose [
    from: me@gmail.com
    to: drme@clear.net.nz
    message: (message)
]
