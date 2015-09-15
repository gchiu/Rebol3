Rebol [
    title: "Graham's Chinese Language Tutor"
    file: %lang.reb
    author: "Graham Chiu"
    date: 11-Sep-2015
    purpose: {display chinese text and its translation}
    version: 0.0.1
    needs: 3.0.99.3.3
	notes: {
		To use this script, you'll need your own client id, client secret, appid and client id:
		1. You'll need a Microsoft ID eg. hotmail etc to use Microsoft services
		2. You then need to subscribe to https://datamarket.azure.com/dataset/bing/microsofttranslator for the 2 million characters a month free
		3. You need also a speech output subscription https://datamarket.azure.com/dataset/bing/speechoutput
		4. From "My Account" https://datamarket.azure.com/account click on "Developers", and then click on "Register" to register this application.  This will give you the Client ID and Client Secret needed to make calls to the MS APIs.
		5. You then need to generate appid and client id which are hex encoded GUIDs.  I used this site http://www.somacon.com/p113.php and removed the leading Ox.
	}
]

random/seed to integer! difference now 1-Jan-2015

; file containing blocks of pairs of language equivalents
db: %language.db

soundir: %sounds-female
win-soundir: join form soundir "\"
append soundir "/"

dbdata: either exists? db [
	load db
][
	copy/deep [[ "现在下班回家" "Finished work now, coming home." ]]
]

; you can download a rebol3 binary from http://atronixengineering.com/downloads.html

settings: [
	client_id: "see note 4"
	client_secret: "see note 4"
	appid: "see note 5"
	clientid: "see note 5"
]

token-server: https://datamarket.accesscontrol.windows.net/v2/OAuth2-13/
end-point: https://speech.platform.bing.com/
recognize: join end-point "recognize"
synthesize: join end-point "synthesize"
translate-url: http://api.microsofttranslator.com/V2/Ajax.svc/Translate?

resources: [
    %prot-http.reb https://raw.githubusercontent.com/gchiu/Rebol3/master/protocols/prot-http.r3
    %combine.reb https://raw.githubusercontent.com/hostilefork/rebol-proposals/master/combine.reb
    %altjson.reb http://reb4.me/r3/altjson
    %altwebform.reb http://reb4.me/r3/altwebform
    %r3-gui.reb http://www.atronixengineering.com/r3/r3-gui.r3
]

; one time download files we need
foreach [script location] resources [
    unless exists? script [write script read location]
    do script
]

; create a shortcut to user context in case we need it later on
u: self 
voice: none
page: none

chtext: copy ""
entext: copy ""

; see here for more options https://cn.projectoxford.ai/doc/speech/REST/Output
; voice: "<speak version='1.0' xml:lang='en-us'><voice xml:lang='zh-CN' xml:gender='Female' name='Microsoft Server Speech Text to Speech Voice (zh-CN, HuihuiRUS)'>"
; voice: "<speak version='1.0' xml:lang='en-us'><voice xml:lang='zh-HK' xml:gender='Female' name='Microsoft Server Speech Text to Speech Voice (zh-HK, Tracy, Apollo)'>"
; voice: "<speak version='1.0' xml:lang='en-us'><voice xml:lang='zh-TW' xml:gender='Female' name='Microsoft Server Speech Text to Speech Voice (zh-TW, Yating, Apollo)'>"

use-voice: function [ locale voice-font gender][
	u/voice: combine [ "<speak version='1.0' xml:lang='en-us'><voice xml:lang='" locale "' xml:gender='" gender "' name='Microsoft Server Speech Text to Speech Voice (" locale ", " voice-font ")'>"]
] 

use-voice locale: "zh-CN" voice-font: "HuihuiRUS" gender: "Female"

; we need to use the windows library to play sounds
mci: make library! %Winmm.dll

mciSendString: make routine! compose/deep [
	[
		lpszCommand [pointer]
		lpszReturnString [pointer]
		cchReturn [int32]
		hwndCallback [pointer]
		return: [uint32]
	]
	(mci) "mciSendStringA"
]

buffer: make string! 128

mciSS: func [ command [string!] ][
	mciSendString command buffer 128 0
] 

create-credentials: function [{url encode the credentials needed to access the token server for the service you want}
	scope [string!]
][
	to-webform compose [
		client_id: (settings/client_id)
		client_secret: (settings/client_secret)
		scope: (scope)
		grant_type: "client_credentials"
	]
]

grab-access-token: function [
	{returns an object containing expiry time and token for the speech to text api}
	credentials
][
	page: write token-server compose [
		POST
		(credentials)
	]
	u/page: load-json to string! page
	make object! compose [
		expires: (now + 0:10)
		token: u/page/access_token
	]
]

ch-fnt: make system/standard/font [
    name: "SimSun"
    size: 32
]

par: make system/standard/para [wrap?: off]

display-chinese: function [ {display Chinese text in a new window}
	chtext
][
	win-size: 840x50

	append append win: make gob! [size: win-size] make gob! [size: win-size color: sky]
	tg: make gob! [size: win-size]

	tg/text: to-text compose [
	    anti-alias on
	    para par
	    font ch-fnt
	    (chtext)
	] copy []

	view/options win [offset: lay/facets/gob/offset - 0x90]
]

extract-named-cookie: func [ set-cookie [string!] cookie [string!]
	{extracts named cookie from cookie string as a block}
	/local len cookies cookie-jar
][
	len: length? cookie
	cookies: split set-cookie space
	cookie-jar: collect [
		forall cookies [
			if find/part cookies/1 cookie len [
				keep cookies/1
				break
			]
		]
	]
]

grab-session-cookie: func [ signin [url!] session-cookie-name
	{grab the initial cookies, and return only the session cookie}
	/local err cookie-jar port token
][
	if error? set/any 'err try [ 
		port: write signin [ headers GET [] ]
		cookie-jar: extract-named-cookie port/spec/debug/headers/set-cookie session-cookie-name
	][
		?? err
		print "An error has occurred as above"
		return none
	]
	either empty? cookie-jar [
		print [ session-cookie-name " cookie not found" ]
		none
	][
		; print [ "We have the initial session coookie named " session-cookie-name ]
		cookie-jar
	]
]

if not exists? soundir [
	make-dir soundir
]

; use chinese font for fields
guie/fonts/field/font/name: "SimSun"
guie/fonts/field/font/size: 15

stylize [
	fld: field [
		facets: [
			init-size: 800x30
			max-size: 800x48
			min-size: 24x34
			align: 'center
		]
	]

    ch-field: field [
        about: "Chinese font field"
		facets: [
			init-size: 800x30
			max-size: 800x48
			min-size: 24x34
			align: 'center
		]
	    draw-text: [
	       pen off
	       fill-pen 0.0.0
	       anti-alias off
	       text 0x0 none aliased [font make object! [
	               name: "SimSun"
	               style: 'bold
	               size: 20
	               color: 0.0.0
	               offset: 0x0
	               space: 0x0
	               shadow: none
	           ] para make object! [
	               origin: 0x0
	               margin: 0x0
	               indent: 0x0
	               tabs: 40
	               wrap?: false
	               scroll: 0x0
	               align: 'left
	               valign: 'top
	           ] anti-alias off
	           caret make object! [
	               caret: [[""] ""]
	               highlight-start: [[""] ""]
	               highlight-end: [[""] ""]
	           ] ""
	       ]
	   ]
    ]
]


lay: layout [
    title "Chinese Language Helper"
    vpanel [
    	hgroup [
    		label "Locale" text u/locale label "Gender" text u/gender label "Voice Font" text u/voice-font
    	]  
        hgroup [
        	label "Text" from: ch-field ""
        ]
		hgroup [
			label "Pinyin" pinyin: fld 
		]
        hgroup [
            label "Translation" translation: fld ""
        ]
        vgroup [
			hgroup [
	            button "Listen" on-action [
	            	if error? set/any 'err try [
		            	ch: pick u/dbdata u/r: random/secure length? u/dbdata
		            	u/chtext: ch/1
		            	set-face from ch/1 
		            	u/entext: any [ ch/2 copy "No translation"]
		            	set-face translation "" ; u/entext
		            	set-face pinyin ""
		            	wait 0.01
		            	unless exists? join soundir filename: to file! append form checksum to binary! u/chtext %.wav [
		            		unless all [
		            			value? 'OxfordAccessToken.o
		            			object? OxfordAccessToken.o
		            			OxfordAccessToken.o/expires > now
		            		][
		            			OxfordAccessToken.o: grab-access-token create-credentials "https://speech.platform.bing.com"
		            		]
							data: combine [
								u/voice
								u/chtext
								"</voice></speak>"
							]
							if none? u/voice [
								alert "No voice selected"
								exit
							]
			            	set-face translation "fetching sound file" ; u/entext
			            	wait 0.01
							result: write synthesize compose [
								POST
								[
									X-Search-AppId: (settings/appid)
									X-Search-ClientID: (settings/clientid)
									X-Microsoft-OutputFormat: "riff-16khz-16bit-mono-pcm"
									Authorization: (join "Bearer " OxfordAccessToken.o/token)
									User-Agent: "TTSRebol"
									Content-Type: "application/ssml+xml"
								]
								(data)
							]
							write  join soundir filename result
						]
						set-face translation ""
						wait 0.01
						mciSS reform [{open } join win-soundir filename {type waveaudio alias sfx} ]
						mciSS "play sfx wait"
						mciSS "close sfx"
						u/filename: filename
					][
						probe err
					]
	            ]
	            button "Listen Again" on-action [
	            	if all [ value? 'u/filename file? u/filename exists? join soundir u/filename][
						mciSS reform  [{open } join win-soundir filename {type waveaudio alias sfx} ]
						mciSS "play sfx wait"
						mciSS "close sfx"	            		
	            	]
	            ]
				button "Pinyin" on-action [
					attempt [
						unless empty? query: get-face from [
							cookie: grab-session-cookie http://www.pin1yin1.com "_pin1yin1_session"
							result: load-json to string! write join http://www.pin1yin1.com/pinyin/convert/?c= url-encode query compose/deep [
								GET
								[
									cookie: (cookie/1)
								]
							]
							set-face pinyin result/p
						]
					]
				]
	            button "Translate" on-action [
	            	attempt [
		            	set-face translation "translating ..." wait 0.01
		            	either all [
		            			 	value? 'u/entext 
		            				string? u/entext
		            				not equal? "No translation" u/entext
		            	][
			            	set-face translation entext
			            ][
			            	unless all [
			            		value? 'TranslatorToken.o
			            		object? TranslatorToken.o
			            		TranslatorToken.o/expires > now
			            	][
			            		TranslatorToken.o: grab-access-token create-credentials "http://api.microsofttranslator.com"
			            	]
			            	; send a get request
			            	request-str: to-webform compose [
			            		text: (u/chtext)
			            		from: "zh-CHS"
			            		to: "en"
			            		category: "general"
			            		appid: ""
			            	]
			            	if error? set/any 'err try [
				            	page: write join translate-url request-str [ 
				            		GET 
				            		[
				            			Authorization: (join "Bearer " TranslatorToken.o/token)
				            		]
				            	]
				            	page: load page
			            		set-face translation page/2
				            ][
				            	probe err
				            ]
				        ]
		            ]
	            ]
			]
			hgroup [
	            button "View" on-action [
	                display-chinese chtext
	            ]
	            button "Update Translation" on-action [
	            	if all [
						not empty? txt: get-face translation 
						u/r
					][
	            		bl: pick u/dbdata u/r
	            		if equal? 2 length? bl [ take/last bl] 
	            		insert tail bl copy txt
	            		save u/db append/only copy [] u/dbdata 
	            	]
	            ]
				button "Clear" on-action [
					u/r: none
					foreach f reduce [translation pinyin from][
						set-face f copy ""
					]
				]
;				button "Import" on-action [
;					lines: read/lines %chinese.txt
;					foreach line lines [
;						append/only dbdata reduce [ line]
;					]
;				]
	            button "Quit" on-action [ unview/all halt]
			]
        ]        
    ]
]

do tutor: function [][
	view lay 
]
