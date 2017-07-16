Rebol [
    title: "Flick Spot Price"
    file: %rebol-flick-api.reb
    author: "Graham"
    date: 14-July-2017
    version: 0.1.3
    notes: {api documentation obtained from https://github.com/madleech/FlickElectricApi
    HELP at https://forum.rebol.info/t/flickelectric-utilities/207    
    
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

import <modflick>

save2Db?: system/script/header/save2Db?
waitperiod: system/script/header/waitmins

form-vars: make object! [
    ; API vars - cient_id and secret are the OAUTH credentials for the Android client, and don't change
    grant_type: "password"
    client_id:  "le37iwi3qctbduh39fvnpevt1m2uuvz"
    client_secret: "ignwy9ztnst3azswww66y9vd9zt6qnt"
    username: system/script/header/username 
    password: system/script/header/password
]

flick-map: make object! [expires_in: now - 1]

display-current-price: does [
    forever [
        if flick-map/expires_in < now [
            print "Loading id_token"
            flick-map: Get-flick-map form-vars
        ]
        if flick-map/expires_in > now [
            ; current id_token still valid
            if error? err: trap [ ; trap the network read
                price: load-json to string! Get-current-price flick-map
                time-at: price-at-now price
                time-until: price-ends-at price
                print/only spaced ["At"
                    time-at/time
                    price-from price "cents"
                    price-type-from price
                    "valid until"
                    time-until/time 
                    "in about"
                    round divide to-integer difference time-until now 60 "mins"
                ]
                ; and if you want to save the data to an influxDb, here's sample code, wrapping it in an attempt in case the Db server isn't on
                if save2Db? [
                    print "trying to save db data"
                    if error? err: trap [
                        write http://127.0.0.1:8086/write?db=FlickUsage compose [POST (join-of "spotRate,location=home spotNow=" price-from price)]
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
        ; process/sleep 60 * waitperiod ; not using this as can't break out using Control-C
        wait/only 60 * waitperiod
    ]
]

display-current-price
