Rebol [
    file: %base32.reb
    date: 17-Sep-2015
    author: "Graham Chiu"
    version: 0.0.1
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
    result: copy ""
    either not decode [
        ; turn st to be encoded into a binary string
        b2: enbase/base st 2
        ; convert each block of 5 into a char from the accepted list
        while [not empty? b2][
            five: take/part b2 5
            ; convert this "binary" into decimal, and look at blocks of 5 eg. "01111"
            offset: 0
            for i 1 5 1 [
                if #"1" = take five [
                    offset: offset + base2/:i
                ]
            ]
            append result pick accepted offset + 1
        ]
    ][
        ; find each character in the string, and and form a 5 bit binary representation
        str: copy st ; so as not to affect the original
        result2: copy ""
        while [not empty? st][
            tmp: copy ""
            index: -1 + index? find accepted form take st 
            for i 1 5 1 [
                append tmp either positive? index and base2/:i ["1"]["0"]
            ]
            append result2 tmp
        ]
        ; we now have a very long string of binary. We need to take it in blocks of 8 and convert back to characters
        while [not empty? result2][
            attempt [
                append result to-char debase/base take/part result2 8 2
            ]
        ]
    ]
    result
]
