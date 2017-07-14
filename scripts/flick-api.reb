Rebol [
    file: flick-api.reb
    author: "Graham"
    date: 14-July-2017
    notes: {api documentation obtained from https://github.com/madleech/FlickElectricApi}
    ; user details which do change!
    username: the-email-that-you-use-for-flick-goes-here@gmail.com
    password: "your-flick-password-here"
    waitmins: 1 ; maybe 30 minutes is better
]

import <json>
import <webform>

; API endpoints
get-jwt: https://api.flick.energy/identity/oauth/token
get-price: https://api.flick.energy/customer/mobile_provider/price

; API vars - cient_id and secret are the OAUTH credentials for the Android client, and don't change
grant_type: "password"
client_id:  "le37iwi3qctbduh39fvnpevt1m2uuvz"
client_secret: "ignwy9ztnst3azswww66y9vd9zt6qnt"

; user details which do change, and maintained in the script header
username: system/script/header/username 
password: system/script/header/password

; net-trace on

jsdate2reboldate: function [
    {convert JS date to rebol date value}
    jsdate [string!]
][
    replace jsdate "T" "/"
    replace jsdate "Z" ""
    load jsdate
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

Get-flick-map: func [ /local data err][
    ; let's get these into a form to POST to the API endpoint
    form-var: [grant_type client_id client_secret username password]
    form-values: reduce form-var
    data: collect [ 
        loop-until [
            keep form form-var/1
            keep "="
            keep url-encode form-values/1
            form-var: next form-var
            form-values: next form-values
            keep "&"
            tail? form-var
        ]
    ]
    take/last data
    data: unspaced data
    if error? err: trap [
        result: load-json to string! write get-jwt compose [POST (data)]
        result/expires_in: now + to time! result/expires_in
        save/all %flick-map.reb result
    ][
        print "Error obtaining map"
        probe err
        return blank-flick-map
    ]
    result
]

display-current-price: does [
    forever [
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
                print/only spaced ["At"
                    now/zone + jsdate2reboldate price/needle/now ; convert from zulu to local time
                    price/needle/charge_methods/2 
                    price/needle/price
                    price/needle/unit_code
                    "per"
                    price/needle/per
                ]
            ][
                ; can't get price
                probe err
            ]
        ]
        print spaced ["; sleeping for" waitperiod: system/script/header/waitmins "mins"]
        wait/only 60 * waitperiod
    ]
]

display-current-price
