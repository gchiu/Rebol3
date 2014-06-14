#!/usr/local/bin/rebol -cs
Rebol [
	Title: "Pubmed Reformatter"
	File: %pubmed.reb
	Date: 2-Jun-2014
	Author: "Graham Chiu"
	Purpose: {create a reference in markdown format suited for use by skeptics.stackexchange.com}
	version: 0.0.3
	notes: {
		14-Jun-2014 rewritten as CGI,and using Brian's combine function
	
		Sample output
		Biesiekierski JR, Peters SL, Newnham ED, Rosella O, Muir JG, Gibson PR. [No effects of gluten in patients with self-reported non-celiac gluten sensitivity after dietary reduction of fermentable, poorly absorbed, short-chain carbohydrates.](http://www.ncbi.nlm.nih.gov/pubmed/23648697) Gastroenterology 2013 Aug;145(2):320-8.e1-3. doi: 10.1053/j.gastro.2013.04.051. PubMed PMID: 23648697.
	}
]


altxml: http://reb4.me/r3/altxml
;altxml: %/var/www/bot-site/html/assets/altxml.reb
;if not exists? altxml [
;	write altxml read http://reb4.me/r3/altxml
;]
do altxml

digits: charset [ #"0" - #"9" ]
not-digits: complement digits

combine: func [
    block [block!]
    /with "Add delimiter between values (will be COMBINEd if a block)"
        delimiter [block! any-string! char!]
    /into
    	out [any-string!]
    /local
    	needs-delimiter pre-delimit value
] [
	;-- No good heuristic for string size yet
	unless into [
		out: make string! 10
	]

	if block? delimiter [
		delimiter: combine delimiter
	]

	needs-delimiter: false
	pre-delimit: does [
		either needs-delimiter [
			out: append out delimiter
		] [
			needs-delimiter: true? with
		]
	]

	;-- Do evaluation of the block until a non-none evaluation result
	;-- is found... or the end of the input is reached.
	while [not tail? block] [
		value: do/next block 'block

		;-- Blocks are substituted in evaluation, like the recursive nature
		;-- of parse rules.

		case [
			any [
				function? :value
				closure? :value
			] [
				throw make error! "Evaluation in COMBINE gave function/closure"
			]

			block? value [
				pre-delimit
				out: combine/into value out
			]

			any-block? value [
				;-- all other block types as *results* of evaluations throw
				;-- errors for the moment.  (It's legal to use PAREN! in the
				;-- COMBINE, but a function invocation that returns a PAREN!
				;-- will not recursively iterate the way BLOCK! does) 
				throw make error! "Evaluation in COMBINE gave non-block! block"
			]

			any-word? value [
				;-- currently we throw errors on words if that's what an
				;-- evaluation produces.  Theoretically these could be
				;-- given behaviors in the dialect, but the potential for
				;-- bugs probably outweighs the value (of converting implicitly
				;-- to a string or trying to run an evaluation of a non-block)
				throw make error! "Evaluation in COMBINE gave symbolic word"
			]

			none? value [
				;-- Skip all nones
			]

			true [
				pre-delimit
				out: append out (form :value)
			]
		]
	]
    either into [out] [head out]
]

; define months rather than use system/locale/months since might be in a foreign country
months: [ "01" "Jan" "02" "Feb" "03" "Mar" "04" "Apr" "05" "May" "06" "Jun" "07" "Jul" "08" "Aug" "09" "Sep" "10" "Oct" "11" "Nov" "12" "Dec"]

reference: make object! [
	title:
	authors:
	url:
	journal:
	publication:
	none
]

pubmed: http://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=pubmed&retmode=xml&id=

create-reference: func [id
	/limit cnt 
	/local result reference ref reb eloc month day
][
	reference: make object! [
		title:
		authors:
		url:
		journal:
		publication:
		none
	]
	; read the xml
	if error? try [
		reb: load-xml/dom to string! read join pubmed id
	][
		return "Network error, or, invalid PMID"
	]
	; get the title
	reference/title: reb/path [* <ArticleTitle> ?]

	; get the authors
	ref: reference/authors: copy ""
	counter: 0
	append ref form collect [
		foreach author reb/path [* <AuthorList> <Author>][
			++ counter
			keep join "" [
				author/path [<Author> <LastName> ?]
				" "
				author/path [<Author> <Initials> ?]
				","
			]
			if all [limit counter >= cnt][ keep " et al " break]
		]
	]
	take/last ref
	append ref "."

	reference/journal: reb/path [* <ISOAbbreviation> ?]

	if #"." <> last trim first reference/journal [ 
		append reference/journal "."
	]

	ref: reference/publication: copy ""

	; get publication data

	result: reb/path [ * <ArticleIDList> <ArticleID>  #IdType ? ]
	
	either find result "doi" [
		doi: true
		index: index? find result "doi"
		 result: reb/path compose [ * <ArticleIDList> <ArticleID> (index)  ? ]
	][
		doi: false ; return "Can't find doi"
	]

	case [
		all [
			not empty? reb/path [* <JournalIssue> <pubdate> <year> ?]
			not empty? reb/path [* <JournalIssue> <pubdate> <month> ?]
		][
			append ref combine [
				reb/path [* <JournalIssue> <pubdate> <year> ?]
				" "
				either parse month: first reb/path [* <JournalIssue> <pubdate> <month> ?] [ some digits ][
					select months month
				][
					month
				]
				if not empty? day: reb/path [* <JournalIssue> <pubdate> <day> ?] [
					day: first day
					if #"0" = first day [ remove day]
					combine [ " " day ]
				]
				if not empty? reb/path [* <JournalIssue> <volume> ?] [
					combine [
						";"
						reb/path [* <JournalIssue> <volume> ?]
						"("
						reb/path [* <JournalIssue> <issue> ?]
						"):"
					]
				]
				reb/path [* <MedlinePgn> ?]
			]
		]

		all [
			not empty? reb/path [* <ArticleDate>  <year> ?]
			not empty? reb/path [* <ArticleDate> <month> ?]
			not empty? reb/path [* <ArticleDate> <day> ?]
		][
			append ref combine [
				reb/path [* <ArticleDate>  <year> ?]
				" "
				select months first reb/path [* <ArticleDate> <month> ?]
				if not empty? day: reb/path [*  <ArticleDate> <day> ?][
					day: first day
					if #"0" = first day [ remove day]
					combine [ " " day ]
				]
				";"
				reb/path [* <JournalIssue> <volume> ?]
				"("
				reb/path [* <JournalIssue> <issue> ?]
				"):"
				reb/path [* <MedlinePgn> ?]
			]
		]

		true [
			append ref combine [
				reb/path [ * <DateCreated> <year> ?] ";"
				if not empty? reb/path [* <JournalIssue> <volume> ?] [
					combine [
						reb/path [* <JournalIssue> <volume> ?]
						"("
						reb/path [* <JournalIssue> <issue> ?]
						"):"
					]
				]
				reb/path [* <MedlinePgn> ?]
			]
		]
	]

	append ref combine [
			if doi [
				combine [
					". doi: "
					"[" select result %.txt "](" http://dx.doi.org/ select result %.txt ")"
				]
			]
			". PubMed PMID: "
			id
	]

	replace/all ref "()" ""
	reference/url: join http://www.ncbi.nlm.nih.gov/pubmed/ id

	return combine [
		reference/authors
		" [" reference/title "](" reference/url ") " reference/journal " " reference/publication "."
	]
]


handle-get: func [] [
    prin [
        "Content-type: text/html" crlf
        crlf
        <!doctype html>
        <title> "PubMed Citation Formatted as Markdown" </title>
		<h1> "PubMed Citation Formatted as Markdown" </h1>
        <form method="POST">
            "PubMed ID"
            <input type="text" size="40" name="pmid">
            <input type="submit">
        </form>
    ]   
]

handle-post: func [] [
    data: to string! read system/ports/input
    fields: parse data "&="
    value: dehex select fields "pmid"

    either parse value [ any not-digits copy pmid some digits to end ][
    	prin [
        	"Content-type: text/html" crlf
        	crlf
        	<!doctype html>
        	<head>
        	<title> "PubMed: Citation" </title>
        	newline
        	<script type="text/javascript" src="http://ajax.googleapis.com/ajax/libs/jquery/1.10.2/jquery.min.js"></script>
        	newline
        	<script type="text/javascript" src="/assets/jquery-zclip.min.js"></script>
        	newline
{<script type="text/javascript">
	$(document).ready(function(){

    $('a#copy-description').zclip({
        path:'/assets/ZeroClipboard.swf',
        copy:$('p#description').text()
    });
    $('a#copy-description2').zclip({
        path:'/assets/ZeroClipboard.swf',
        copy:$('p#description2').text()
    });

    // The link with ID "copy-description" will copy
    // the text of the paragraph with ID "description"
});
</script>
}
			<br/>

        	</head>
        	newline
        	<body>
        	newline
        	<h2> "Citation" </h2>
        	<p id="description">
        	create-reference pmid
        	</p>
        	{<a href="#" id="copy-description">Click here to copy the above markdown formatted citation</a>}

        	<hr>
        	<p id="description2">
        	create-reference/limit pmid 3
        	</p>
        	{<a href="#" id="copy-description2">Click here to copy the above markdown formatted citation</a>}
        ]
    ][
    	prin "<strong>No valid PMID found</strong>"
    ]
    prin [
        <hr>
		<h1> "PubMed Citation Formatted as Markdown" </h1>
        <form method="POST">
            "PubMed ID"
            <input type="text" size="40" name="pmid">
            <input type="submit">
        </form>
    ]

    prin [
    	</body> </html>
    ]
]

main: does [
    switch get-env "REQUEST_METHOD" [
        "GET" [handle-get]
        "POST" [handle-post]
    ]
]

main