Rebol [
    file: %change-log.reb
    notes: {Creates a change log on discourse site for the commits}
]

system/options/dump-size: 1000

import <json>
import <xml>

s3files: http://metaeducation.s3.amazonaws.com
commits: https://api.github.com/repos/metaeducation/ren-c/commits

; get all the unique commit values still available for download
dom: load-xml/dom to string! read s3files
result: dom/get <Contents>

comment {
value: => [
    <Key> "travis-builds/0.4.40/r3-fbe5237-debug-cpp"
    <LastModified> "2017-05-13T15:54:38.000Z"
    <ETag> {"97b151cc9bda7c325828d499efb15332"}
    <Size> "4085984"
    <StorageClass> "STANDARD"
]
}

files: copy []

for-each [key value] result/position [
    r: copy value
    if parse value [
        path! set keyvalue string!
        path! set datestring string!
        to end
    ][
        if parse keyvalue ["travis-builds/" copy os: to "/" "/" copy filename to end][
            if parse filename ["r3-" [copy hash: to "-" to end | copy hash: to end]][
                append files hash
                repend/only files [os filename]
            ]
        ]
    ]
]

if empty? files [quit]

; now read the commits
json: reverse load-json to-string read commits ;=> block

for-each committed json [ ; map!
    if something? hash: select committed 'sha [
        ; we have a block of shortened hashes
        print newline
        print/only "Date: " probe select select select committed 'commit 'author 'date
        print/only "Author: " probe select select select committed 'commit 'author 'name
        print/only "Message: " probe select select committed 'commit 'message
        dump hash
        print "^/Binaries available?"

        for-each [h block] files [
            if find hash h [
                probe block
            ]
        ]
    ]
]
