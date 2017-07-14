Rebol [
    file: %rebol-flick-forecast-api.reb
    author: "Graham"
    date: 14-July-2017
    notes: {api documentation obtained from https://github.com/madleech/FlickElectricApi
        Also see https://github.com/gchiu/Rebol3/wiki/Flick-API-and-Rebol    

        1. Download a rebol interpreter from here http://metaeducation.s3.amazonaws.com/index.html
        2. Rename it to r3 (or r3.exe if using windows )
        3. On linux - chmod +x ./r3
        4. Download this script, use the raw view https://raw.githubusercontent.com/gchiu/Rebol3/master/scripts/rebol-flick-forecast-api.reb
        5. Use an editor to change the last 3 values in this header
        6. From a shell, run the script like this c:\users\path\to\download\r3 rebol-flick-api.reb
    }
    ; NB: user details which do change!
    username: the-email-you-use-with-flick-goes-here@somewhere.com
    password: "your-password-goes-here"
    supply_node: "your-supply-node" ; Karori is "1791ac20-df64-4235-8d06-562cc24d22e6"
]

net-trace off

import <json>
import <webform>

infeasible: "Can not compute!" ; see https://news.flickelectric.co.nz/2017/05/18/forecast-to-final-prices/
infeasible-price: 50'000

; API endpoints
get-jwt: https://api.flick.energy/identity/oauth/token
; old api
; get-price: https://api.flick.energy/customer/mobile_provider/price
; current api
get-price: rejoin [https://api.flick.energy//rating/forecast_prices?supply_node=/network/nz/supply_nodes/ system/script/header/supply_node "&number_of_periods_ahead=1"]

form-vars: make object! [
    ; API vars - cient_id and secret are the OAUTH credentials for the Android client, and don't change
    grant_type: "password"
    client_id:  "le37iwi3qctbduh39fvnpevt1m2uuvz"
    client_secret: "ignwy9ztnst3azswww66y9vd9zt6qnt"
    username: system/script/header/username 
    password: system/script/header/password
]

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

; net-trace on

display-current-price: does [
    print spaced ["Using electricity supply node of" system/script/header/supply_node]
    forever [
        next-time: now + 0:10:00 ; default of 10 mins if can't get the flick credentials
        if flick-map/expires_in < now [
            print "Fetching id_token"
            flick-map: Get-flick-map
        ]
        if flick-map/expires_in > now [
            ; id_token still valid
            if error? err: trap [
                price: load-json to string! write get-price compose [
                    GET [Authorization: (join-of "Bearer " flick-map/id_token)]
                ]
                if (current-price: price/prices/1/price/value) = infeasible-price [current-price: infeasible]
                if (next-price: price/prices/2/price/value) = infeasible-price [next-price: infeasible]
                print spaced ["Current price at" jsdate2reboldate price/prices/1/start_at current-price price/prices/1/price/unit_code "per" price/prices/1/price/per]
                print spaced ["Next price at" next-time: jsdate2reboldate price/prices/2/start_at next-price price/prices/2/price/unit_code "per" price/prices/2/price/per]
            ][
                ; can't get price
                probe err
            ]
        ]
        ; next-time is when the price changes, so let's wait until then
        print spaced ["... sleeping for about" round divide to-integer (difference next-time now) 60 "mins"]
        wait/only difference next-time now ;60 * waitperiod
    ]
]

display-current-price
