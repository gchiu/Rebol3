rebol [
	file: %test-smtp.reb
]

import %prot-smtp.reb

date2edate: func [ date ][
	unspaced [
		copy/part pick system/locale/days date/3 3
		", "
		date/3 space
		copy/part pick system/locale/months date/2 3 space
		date/1 space
		date/4 space
		either date/5 >= 0:00 ["+"]["-"]
		date/5
	]
]

message: rejoin [ {To: } me@gmail.com {
From: } "Graham Chiu" { <} me@clear.net.nz {>
Date: } date2edate now {
Subject: testing from renc
X-REBOL: Ren-C } rebol/commit {

where's my kibble?}]

net-trace on

write smtp://user:password@smtp.clear.net.nz compose [
    from: me@clear.net.nz
    to: me@gmail.com
    message: (message)
]
