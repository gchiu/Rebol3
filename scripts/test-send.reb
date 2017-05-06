Rebol [
    file: %test-send.reb
    notes: {testing prot-send}
    date: 6-May-2017
    author: "Graham"
    contact: http://chat.stackoverflow.com/rooms/291/rebol
]

import %prot-smtp.reb
do %prot-send.reb

set-net: procedure [bl [block!]
][
    if (length-of bl) <> 6 [fail "Needs all 6 parameters for set-net"]
    set words-of system/user/identity bl
]

set-net data: [me@gmail.com "smtp.gmail.com:465" "pop.gmail.com:995" "me@gmail.com" "gmail-application-password" "ihug.net"]

probe system/user/identity

net-trace on

send me@gmail.com "testing from gmail"
