Rebol [
    file: %base32.reb
    date: 17-Sep-2015
    author: "Graham Chiu"
    version: 0.0.2
    notes: {
        encodes string to base32 or base32hex
        padding to 5 characters is not required in this method

        >> to-base32/decode/hex to-base32/hex "yessir"
        == "yessir"
    }
]

to-base32: function [ st [string!]
    /hex {output base32hex}
    /decode {returns decoded base32/hex string}
][
    accepted: either hex 
    ["0123456789abcdefghijklmnopqrstuv"]; base32hex
    ["abcdefghijklmnopqrstuvwxyz234567"]; base32
    base2: [16 8 4 2 1]
    either not decode [
        ; turn st, to be encoded, into a "binary" string
        b2: enbase/base st 2
        ; convert each block of 5 into a char from the accepted list
        ajoin collect [
            while [not empty? b2][
                five: take/part b2 5
                ; convert this "binary" into decimal, and look at blocks of 5 eg. "01111"
                offset: 0
                for i 1 5 1 [
                    if #"1" = take five [
                        offset: offset + base2/:i
                    ]
                ]
                keep pick accepted offset + 1
            ]
        ]
    ][
        ; find each character in the string, and form a 5 bit binary representation
        str: copy st ; so as not to affect the original
        result: ajoin collect [
            while [not empty? st][
                keep ajoin collect [
                    index: -1 + index? find accepted form take st 
                    for i 1 5 1 [
                        keep either positive? index AND base2/:i ["1"]["0"]
                    ]
                ]
            ]
        ]
        ; we now have a very long string of "binary". We need to take it in blocks of 8 and convert back to characters
        ajoin collect [
            while [not empty? result][
                attempt [
                    keep to-char debase/base take/part result 8 2
                ]
            ]
        ]
    ]
]
