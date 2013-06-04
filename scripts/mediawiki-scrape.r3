Rebol [
	title: "Mediawiki Port"
	Author: "Graham Chiu"
	Date: 3-June-2013
	File: %mediwiki-scrape.r3
	Purpose: {Grab all the main content off the rebol.net pages, and using pandoc convert to asciidoc}
	Version: 0.0.1
]

gui: none
;; comment out this next line if no gui
load-gui gui: true

save-dir: %rebol.net/
if not exists? save-dir [make-dir save-dir]
bad-links: copy []
error-log: %error.log
write error-log ""

log-error: func [txt] [
	write/append error-log join txt newline
]

; use this to pause the gui
pause: false

site-url: http://www.rebol.net/wiki/
all-pages-url: http://www.rebol.net/wiki/Special:Allpages
export-url: http://www.rebol.net/wiki/Special:Export/

print ["reading " all-pages-url]
; read the all pages page, and break into elements so that we can extract the links
tags: decode 'markup read all-pages-url

urls: copy []
foreach element tags [
	if tag! = type? element [
		if parse form element [{<a href="/wiki/} copy name to {"} thru {="} copy page to {">} to end] [
			if all [
				name
				page
				; remove special pages
				not parse name ["Special:" to end]
				not parse page ["a href=" to end]
				not parse page ["Docbase:" to end]
			] [
				repend/only urls [name page]
			]
		]
	]
]

if gui [
	view compose/only [
		vpanel [
			text-table ["Link Name" #1 250 "URL" #2 250] (urls) options [init-hint: 500x500]
			hpanel [
				button "Carry On" green on-action [close-window face]
				button "Stop" red on-action [close-window face halt]
			]
		]
	]
]

process-site: func [urls gui [logic!] prog [object! none!] name [object! none!] output [object! none!]
	/local cnt len percent wikifile asciifile script page
] [
	len: length? urls
	cnt: 0
	foreach link urls [
		wait .1
		percent: ++ cnt / len
		if pause [break]
		; read the export link and parse out the text including html entity formatted data
		if error? set/any 'err try [
			either gui [
				set-face prog percent
				set-face name link/2
			] [
				print rejoin ["completed " percent "%"]
			]
			page: to string! read newlink: join export-url link/1
			if parse page [thru <text xml:space="preserve"> copy content to </text> to end] [
				if gui [set-face output content]
				write wikifile: rejoin [save-dir link/2 %.wiki] content
				; now convert to asciidoc
				asciifile: append head clear find/last copy wikifile %.wiki %.txt
				script: rejoin [{pandoc -f mediawiki -t asciidoc -s "} wikifile {" -o "} asciifile {"}]
				if zero? call/wait script [
					; now remove extraneous internal edit links
					page: read asciifile
					replace/all page "[[]]" ""
					write asciifile page
				]
			]
		] [
			log-error rejoin ["Error with page link: " link/1 " named " link/2]
			log-error mold err
		]
	]
]


either gui [
	view [
		vpanel [
			hpanel 2 [
				label "Progress: " prog: progress
				label "Page name: " name: field
				label "Content: " contents: area
			]
			hpanel [
				button "Start" green on-action [
					process-site urls true prog name contents
				]
				button "Cancel" gold on-action [
					set 'pause true
				]
				button "Quit" red on-action [unview/all halt]
			]
		]
	]
] [
	process-site false none none none
]
