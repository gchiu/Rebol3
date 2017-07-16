Rebol [
    Title: "Flick API Utilities"
    Author: "Graham Chiu"
    Date: 15-Jul-2017
    Home: https://forum.rebol.info/t/flickelectric-utilities/207
    File: %modflick.reb
    Version: 0.1.0
    Purpose: "Implement Flick API"
    Type: module
    Name: modflick
    Exports: [
        Get-flick-map     ; object! => map!
        Get-current-price ; flick-map [map!] => price [map!]
        price-from        ; price [map!] => decimal!
        price-type-from   ; price [map!] => string!
        price-starts-at   ; price [map!] => date!
        price-ends-at     ; price [map!] => date!
    ]
    History: [
        16-July-2017 "first pass at moving code to a module"
    ]
    Example: [
        https://github.com/gchiu/Rebol3/blob/master/scripts/rebol-flick-api.reb
    ]
]

webform: import <webform>
to-webform: :webform/to-webform

import <json>

; API endpoints
get-jwt: https://api.flick.energy/identity/oauth/token
get-price: https://api.flick.energy/customer/mobile_provider/price

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

Get-flick-map: function [
    {returns a map! of flick credentials when passed an object containing password etc}
    form-vars [object!]
][
    fm: flick-map ; load saved map if it exists
    either fm/expires_in < now [
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
    ][
        fm
    ]
]

Get-current-price: function [
    {reads price data which is returned as a JSON string}
    flick-map [map!]
][
    write get-price compose [
        GET [Authorization: (join-of "Bearer " flick-map/id_token)]
    ]
]

price-from: function [
    {shortcut to return value from map, returns decimal value}
    price [map!]
][
    to decimal! price/needle/price
]

price-type-from: function [
    {shortcut to return the price type as string}
    price [map!]
][
    spaced [price/needle/charge_methods/2 "per" price/needle/per]
]

price-starts-at: function [
    {shortcut to return the start time of price}
    price [map!]
][
    jsdate2reboldate price/needle/start_at
]

price-ends-at: function [
    {shortcut to return the end time of price}
    price [map!]
][
    jsdate2reboldate price/needle/end_at
]

comment {
; sample JSON map! returned by get-current-price after turned into a Rebol map!

make map! [
    kind "mobile_provider_price"
    customer_state "active"
    needle make map! [
        price "21.004"
        status "urn:flick:market:price:forecast"
        unit_code "cents"
        per "kwh"
        start_at "2017-07-15T23:30:00Z"
        end_at "2017-07-15T23:59:59Z"
        now "2017-07-15T23:30:45.580Z"
        type "rated"
        charge_methods [
            "kwh"
            "spot_price"
        ]
        components [
            make map! [
                charge_method "kwh"
                value "0.113"
            ]
            make map! [
                charge_method "kwh"
                value "1.5"
            ]
            make map! [
                charge_method "kwh"
                value "7.25"
            ]
            make map! [
                charge_method "spot_price"
                value "12.141"
            ]
        ]
    ]
]
}
