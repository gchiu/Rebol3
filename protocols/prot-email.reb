REBOL [
	Title:  "REBOL Protocols: Email Processing"
	Version: 2.7.6
	Rights: "Copyright REBOL Technologies 2008. All rights reserved."
	Home: http://www.rebol.com
	Date: 14-Mar-2008

	; You are free to use, modify, and distribute this file as long as the
	; above header, copyright, and this entire comment remains intact.
	; This software is provided "as is" without warranties of any kind.
	; In no event shall REBOL Technologies or source contributors be liable
	; for any damages of any kind, even if advised of the possibility of such
	; damage. See license for more information.

	; Please help us to improve this software by contributing changes and
	; fixes. See http://www.rebol.com/support.html for details.
]
parse-header: func [
    {Returns a header object with header fields and their values}
    parent [object! none!] "Default header object"
    data [any-string!] "String to parse"
    /multiple "Obsolete. Here for compatibility only."
][
    clear invalid
    template: parent
    any [
        parse data message
        net-error "Headers not correctly parsed"
    ]
    make either parent [parent] [object!] head-list
]

mail-list-rules: make object! [
	"Rough draft.  Still needs some work."
	addr-list: 
	addr: _
	opt-cmt: ["(" thru ")" | _]
	mailbox: [
		opt-cmt thru "<" copy addr to ">" | ; normal method
	 ;  thru "(" addr: to ")" |         ; crazy old way
		copy addr [to "," | to ";" | to " " | to tab | to end]   ; anything we got will do
	]
	maillist: [
		mailbox (append addr-list to-email addr)
		[[thru "," | thru ";"] maillist | none]
	]
	parse-mail-list: func [data [string!]
	][
		addr-list: make block! 1
		parse data maillist
		addr-list
	]
]

parse-email-addrs: func [data [string! none!]] [
	if none? data [return _]
	Mail-List-Rules/parse-mail-list data
]

import-email: func [
	"Constructs an email object from an email message."
	data [string!] "The email message"
	/multiple "Collect multiple fields in header" parent [object!]
	/local content frm
][
	data: parse-header either multiple [parent][system/standard/email] content: data
	; check for blocks - fixes RAMBO #3771
	frm: func [val /local res] [
		either block? val [
			either empty? val [
				copy ""
			] [
				res: copy first val
				foreach addlst next val [
					insert insert tail res ", " addlst
				]
				res
			]
		] [
			val
		]
	]
	data/date: parse-header-date either block? data/date [first data/date] [data/date]
	data/from: parse-email-addrs frm data/from
	data/to: parse-email-addrs frm data/to
	all [multiple data/cc: parse-email-addrs frm data/cc]
	all [multiple data/bcc: parse-email-addrs frm data/bcc]
	data/reply-to: parse-email-addrs frm data/reply-to
	data/content: any [data/content tail content]
	data
]
