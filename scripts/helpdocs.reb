REBOL [
    System: "REBOL [R3] Language Interpreter and Run-time Environment"
    Title: "REBOL 3 Mezzanine: Help"
    Rights: {
        Copyright 2012 REBOL Technologies
        REBOL is a trademark of REBOL Technologies
    }
    License: {
        Licensed under the Apache License, Version 2.0
        See: http://www.apache.org/licenses/LICENSE-2.0
    }
    Date: 29-Mar-2017
    Notes: {An attempt to autogenerate web pages with help, and community help below the line}
]

buffer: copy ""

helpdocs: function [
    "Prints information about words and values (if no args, general help)."
    'word [<end> any-value!]
    /doc "Open web browser to related documentation."
][
    clear buffer
    print-newline: func [][append buffer LF]
    print: function [val
        /only
    ][
        either block? val [
            append buffer spaced val
        ][
            append buffer val
        ]
         if not only [
            append buffer LF
         ]
    ]

    if not set? 'word [
        ;
        ; Was just `>> help` or `do [help]` or similar.
        ; Print out generic help message.
        ;
        print trim/auto copy {
            Use HELP to see built-in info:

                help insert

            To search within the system, use quotes:

                help "insert"

            To browse online web documents:

                help/doc insert

            To view words and values of a context or object:

                help lib    - the runtime library
                help self   - your user context
                help system - the system object
                help system/options - special settings

            To see all words of a specific datatype:

                help object!
                help function!
                help datatype!

            Other debug functions:

                docs - open browser to web documentation
                ?? - display a variable and its value
                probe - print a value (molded)
                source func - show source code of func
                trace - trace evaluation steps
                what - show a list of known functions
                why? - explain more about last error (via web)

            Other information:

                chat - open DevBase developer forum/BBS
                docs - open DocBase document wiki website
                bugs - open CureCore bug database website
                demo - run demo launcher (from rebol.com)
                about - see general product info
                upgrade - check for newer versions
                changes - show changes for recent version
                install - install (when applicable)
                license - show user license
                usage - program cmd line options
        }
        leave
    ]

;           Word completion:
;
;               The command line can perform word
;               completion. Type a few chars and press TAB
;               to complete the word. If nothing happens,
;               there may be more than one word that
;               matches. Press TAB again to see choices.
;
;               Local filenames can also be completed.
;               Begin the filename with a %.
;
;           Other useful functions:
;
;               about - see general product info
;               usage - view program options
;               license - show terms of user license
;               source func - view source of a function
;               upgrade - updates your copy of REBOL
;
;           More information: http://www.rebol.com/docs.html

    ; If arg is an undefined word, just make it into a string:
    if all [word? :word | not set? :word] [word: mold :word]

    ; Open the web page for it?
    if all [
        doc
        word? :word
        any [function? get :word datatype? get :word]
    ][
        item: form :word
        either function? get :word [
            for-each [a b] [ ; need a better method !
                "!" "-ex"
                "?" "-q"
                "*" "-mul"
                "+" "-plu"
                "/" "-div"
                "=" "-eq"
                "<" "-lt"
                ">" "-gt"
                "|" "-bar"
            ][replace/all item a b]
            tmp: "functions"
        ][
            tmp: "datatypes"
            remove back tail item ; the !
        ]
        dump tmp
        dump item
        return reduce [tmp item]

        ; return join-of tmp [item ".html"]
    ]

    ; If arg is a string or datatype! word, search the system:
    if any [string? :word | all [word? :word | datatype? get :word]] [
        if all [word? :word | datatype? get :word] [
            typespec: spec-of get :word
            print [
                word {is a datatype}
                    |
                {It is defined as}
                    either find "aeiou" first typespec/title ["an"] ["a"]
                    typespec/title newline
                    |
                "It is of the general type" typespec/type
            ]
        ]
        if all [word? :word | not set? :word] [leave]
        types: dump-obj/match lib :word
        sort types
        if not empty? types [
            print ["Found these related words:" newline types]
            leave
        ]
        if all [word? :word datatype? get :word] [
            print ["No values defined for" word]
            leave
        ]
        print ["No information on" word]
        leave
    ]

    ; Print type name with proper singular article:
    type-name: func [value] [
        value: mold type-of :value
        clear back tail value
        spaced [(either find "aeiou" first value ["an"]["a"]) value]
    ]

    ; Print literal values:
    if not any [word? :word path? :word][
        print [mold :word "is" type-name :word]
        leave
    ]

    ; Functions are not infix in Ren-C, only bindings of words to infix, so
    ; we have to read the infixness off of the word before GETting it.

    ; Get value (may be a function, so handle with ":")
    either path? :word [
        print ["!!! NOTE: Infix testing not currently supported for paths !!!"]
        lookback: false
        if any [
            error? set/opt 'value trap [get :word] ;trap reduce [to-get-path word]
            not set? 'value
        ][
            print ["No information on" word "(path has no value)"]
            leave
        ]
    ][
        lookback: lookback? :word
        value: get :word
    ]

    unless function? :value [
        print/only spaced [
            (uppercase mold word) "is" (type-name :value) "of value:"
        ]
        print unspaced collect [
            either maybe [object! port!] value [
                keep newline
                keep dump-obj value
            ][
                keep mold value
            ]
        ]
        return _
    ]

    ; Must be a function...
    ; If it has refinements, strip them:
    ;if path? :word [word: first :word]

    space4: unspaced [space space space space] ;-- use instead of tab

    ;-- Print info about function:
    print "USAGE:"

    args: _ ;-- plain arguments
    refinements: _ ;-- refinements and refinement arguments

    parse words-of :value [
        copy args any [word! | get-word! | lit-word! | issue!]
        copy refinements any [
            refinement! | word! | get-word! | lit-word! | issue!
        ]
    ]

    ; Output exemplar calling string, e.g. LEFT + RIGHT or FOO A B C
    ; !!! Should refinement args be shown for lookback case??
    ;
    either lookback [
        print [space4 args/1 (uppercase mold word) next args]
    ][
        print [space4 (uppercase mold word) args refinements]
    ]

    ; Dig deeply, but try to inherit the most specific meta fields available
    ;
    fields: dig-function-meta-fields :value

    description: fields/description
    return-type: :fields/return-type
    return-note: fields/return-note
    types: fields/parameter-types
    notes: fields/parameter-notes

    ; For reporting what kind of function this is, don't dig at all--just
    ; look at the meta information of the function being asked about
    ;
    meta: meta-of :value
    all [
        original-name: maybe word! (
            any [
                select meta 'specializee-name
                select meta 'adaptee-name
                select meta 'hijackee-name
            ]
        )
        original-name: uppercase mold original-name
    ]

    specializee: maybe function! select meta 'specializee
    adaptee: maybe function! select meta 'adaptee
    chainees: maybe block! select meta 'chainees
    hijackee: maybe function! select meta 'hijackee

    classification: case [
        :specializee [
            either original-name [
                spaced [{a specialization of} original-name]
            ][
                {a specialized function}
            ]
        ]

        :adaptee [
            either original-name [
                spaced [{an adaptation of} original-name]
            ][
                {an adapted function}
            ]
        ]

        :chainees [
            {a chained function}
        ]

        :hijackee [
            either original-name [
                spaced [{a hijacking of} original-name]
            ][
                {a hijacked function}
            ]
        ]
    ] else {a function}

    print-newline

    print [
        "DESCRIPTION:"
            |
        space4 (any [description | "(undocumented)"])
            |
        space4 (uppercase mold word) {is} classification {.}
    ]

    print-args: procedure [list /indent-words] [
        for-each param list [
            note: maybe string! select notes to-word param
            type: maybe [block! any-word!] select types to-word param

            ;-- parameter name and type line
            either all [type | not refinement? param] [
                print/only [space4 param space "[" type "]" newline]
            ][
                print/only [space4 param newline]
            ]

            if note [
                print/only [space4 space4 note newline]
            ]
        ]
    ]

    either blank? :return-type [
        ; If it's a PROCEDURE, saying "RETURNS: void" would waste space
    ][
        ; For any return besides "always void", always say something about
        ; the return value...even if just to say it's undocumented.
        ;
        print-newline
        print ["RETURNS:" (if set? 'return-type [mold return-type])]
        either return-note [
            print/only [space4 return-note newline]
        ][
            if not set? 'return-type [
                print/only [space4 "(undocumented)" newline]
            ]
        ]
    ]

    unless empty? args [
        print-newline
        print "ARGUMENTS:"
        print-args args
    ]

    unless empty? refinements [
        print-newline
        print "REFINEMENTS:"
        print-args/indent-words refinements
    ]
]
; >> cnt: 0 for-each [key val] lib [++ cnt dump cnt if not find avoid cnt [if error? try [print key help :key][append avoid cnt] print-newline]


for-each [key val] lib [
    print ["Current key: " key]
    if error? try [
        help :key
        r: helpdocs/doc :key
        if r/1 = "functions" [
            filename: rejoin [%docs/functions/ r/2 %.MD]
            dump filename
            echo filename
            help :key
            echo _
            tmp: to string! read filename
            replace/all tmp "<" "&lt;"
            replace/all tmp ">" "&gt;"
            replace/all tmp " " "&nbsp;" 
            replace/all tmp newline join-of "  " newline
            attempt [
                info? link: rejoin [http://www.rebol.com/r3/docs/functions/ r/2 %.html]
                append tmp unspaced [newline "[Rebol.com docs](" link ")" newline]
            ]
            append tmp "___^/"
            append tmp "Above this line is autogenerated. Place user comments below."
            write filename tmp
        ]

    ][
        print "error with this one"
    ]

]
