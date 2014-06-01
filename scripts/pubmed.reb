Rebol [
	Title: "Pubmed Reformatter"
	File: %pubmed.reb
	Date: 1-Jun-2014
	Author: "Graham Chiu"
	Purpose: {create a reference in markdown format suited for use by skeptics.stackexchange.com}
]

reference: make object! [
	title:
	authors:
	url:
	journal:
	publication:
	none
]

do http://reb4.me/r3/altxml
pubmed: http://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=pubmed&retmode=xml&id=

create-reference: func [id
	/local result reference ref reb
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
	reb: load-xml/dom to string! read join pubmed id
	; get the title
	result: reb/get-by-tag <ArticleTitle>
	reference/title: result/1/value
	; get the authors
	ref: reference/authors: copy ""

	result: reb/get-by-tag <Author>
	foreach author result [
		author: load mold/all author/value
		append ref ajoin [author/<LastName> " " author/<Initials> ", "]
	]
	take/last ref
	take/last ref
	append ref "."
	; get the journal


	result: reb/get-by-tag <ISOAbbreviation>
	reference/journal: result/1/value

	ref: reference/publication: copy ""

	; get publication data

	result: reb/get-by-tag <JournalIssue>
	result: load mold/all result/1/value
	append ref ajoin [result/<pubdate>/<year> " " result/<pubdate>/<month> ";" result/<volume> "(" result/<issue> "):"]

	result: reb/get-by-tag <MedlinePgn>
	append ref rejoin [result/1/value ". "]
	result: reb/get-by-tag <ELocationID>

	result: load mold/all result/1/value

	append ref ajoin [result/#EIdType ": " result/%.txt ". "]

	result: reb/get-by-tag <PMID>
	append ref ajoin ["PubMed PMID: " result/1/value/%.txt]

	reference/url: join http://www.ncbi.nlm.nih.gov/pubmed/ result/1/value/%.txt

	return ajoin [
		reference/authors
		" [" reference/title "](" reference/url ") " reference/journal " " reference/publication "."
	]
]

; probe create-reference 19109384

; halt
