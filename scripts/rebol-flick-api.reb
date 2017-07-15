Rebol [
    file: %rebol-flick-api.reb
    author: "Graham"
    date: 14-July-2017
    version: 0.1.1
    notes: {api documentation obtained from https://github.com/madleech/FlickElectricApi
    NB: Help at https://forum.rebol.info/t/flickelectric-utilities/207
    
    1. Download a rebol interpreter from here http://metaeducation.s3.amazonaws.com/index.html
    2. Rename it to r3 (or r3.exe if using windows )
    3. On linux - chmod +x ./r3
    4. Download this script, use the raw view https://raw.githubusercontent.com/gchiu/Rebol3/master/scripts/rebol-flick-api.reb
    5. Use an editor to change the last 4 values in this header
    6. From a shell, run the script like this c:\users\path\to\download\r3 rebol-flick-api.reb

    }
    ; user details which do change!
    username: the-email-you-use-with-flick-goes-here@somewhere.com
    password: "your-password-goes-here"
    waitmins: 10 ; maybe 30 is better
    save2Db?: #[false] ; #[true]
]

import <json>
import <webform>
process: import 'process

save2Db?: system/script/header/save2Db?
waitperiod: system/script/header/waitmins

; API endpoints
get-jwt: https://api.flick.energy/identity/oauth/token
get-price: https://api.flick.energy/customer/mobile_provider/price

form-vars: make object! [
    ; API vars - cient_id and secret are the OAUTH credentials for the Android client, and don't change
    grant_type: "password"
    client_id:  "le37iwi3qctbduh39fvnpevt1m2uuvz"
    client_secret: "ignwy9ztnst3azswww66y9vd9zt6qnt"
    username: system/script/header/username 
    password: system/script/header/password
]

; net-trace on

jsdate2reboldate: function [
    {convert JS zulu date to rebol local date value}
    jsdate [string!]
][
    replace jsdate "T" "/"
    replace jsdate "Z" ""
    d: now/zone + load jsdate
    d/zone: now/zone
    d
]

blank-flick-map: make map! compose [
    access_token _
    expires_in (now - 1)
    id_token _
    token_type "bearer"
]

flick-map: either exists? %flick-map.reb [
    load %flick-map.reb
][
    blank-flick-map
]

; probe flick-map

Get-flick-map: func [ /local result err][
    if error? err: trap [
        result: load-json to string! write get-jwt compose [POST (to-webform form-vars)]
        result/expires_in: now + to time! result/expires_in
        save/all %flick-map.reb result
    ][
        print "Error obtaining map"
        probe err
        return blank-flick-map
    ]
    result
]

Get-current-price: function [
    {reads price data which is returned as a JSON string}
    flick-map [map!]
][
    write get-price compose [
        GET [Authorization: (join-of "Bearer " flick-map/id_token)]
    ]
]

display-current-price: does [
    forever [
        if flick-map/expires_in < now [
            print "Fetching id_token"
            flick-map: Get-flick-map
        ]
        if flick-map/expires_in > now [
            ; current id_token still valid
            if error? err: trap [ ; trap the network read
                price: load-json to string! Get-current-price flick-map
                print/only spaced ["At"
                    jsdate2reboldate price/needle/now ; convert from zulu to local time
                    price/needle/charge_methods/2 
                    price/needle/price
                    price/needle/unit_code
                    "per"
                    price/needle/per
                ]
                ; and if you want to save the data to an influxDb, here's sample code, wrapping it in an attempt in case the Db server isn't on
                if save2Db? [
                    print "trying to save db data"
                    if error? err: trap [
                        write http://127.0.0.1:8086/write?db=FlickUsage compose [POST (join-of "spotRate,location=home spotNow=" price/needle/price)]
                    ][
                        print "*** Unable to save to DB"
                        probe err
                    ]
                ]
            ][
                ; can't get price
                print "*** Unable to fetch pricing data"
                probe err
            ]
        ]
        print spaced ["; sleeping for" waitperiod "mins"]
        process/sleep 60 * waitperiod ; Control-C will break out of the script at the end of the 10 min period
    ]
]

display-current-price
