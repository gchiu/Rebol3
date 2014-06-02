Rebol [
	Title: "Pubmed Reformatter"
	File: %pubmed.reb
	Date: 2-Jun-2014
	Author: "Graham Chiu"
	Purpose: {create a reference in markdown format suited for use by skeptics.stackexchange.com}
	version: 0.0.2
	notes: {
		Sample output
		Biesiekierski JR, Peters SL, Newnham ED, Rosella O, Muir JG, Gibson PR. [No effects of gluten in patients with self-reported non-celiac gluten sensitivity after dietary reduction of fermentable, poorly absorbed, short-chain carbohydrates.](http://www.ncbi.nlm.nih.gov/pubmed/23648697) Gastroenterology 2013 Aug;145(2):320-8.e1-3. doi: 10.1053/j.gastro.2013.04.051. PubMed PMID: 23648697.
	}
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
	/local result reference ref reb eloc
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
	reference/title: reb/path [* <ArticleTitle> ?]

	; get the authors
	ref: reference/authors: copy ""
	append ref form collect [
		foreach author reb/path [* <AuthorList> <Author>][
			keep join "" [
				author/path [<Author> <LastName> ?]
				" "
				author/path [<Author> <Initials> ?]
				","
			]
		]
	]
	take/last ref
	append ref "."

	reference/journal: reb/path [* <ISOAbbreviation> ?]

	ref: reference/publication: copy ""

	; get publication data

	eloc: reb/path [ * <ELocationID> 1 ]
	append ref ajoin [
		reb/path [* <JournalIssue> <pubdate> <year> ?]
		" "
		reb/path [* <JournalIssue> <pubdate> <month> ?]
		";"
		reb/path [* <JournalIssue> <volume> ?]
		"("
		reb/path [* <JournalIssue> <issue> ?]
		"):"
		reb/path [* <MedlinePgn> ?]
		". "
		reb/path  [ * <ELocationID> #EIdType 1 ? ]
		": "
		eloc/text
		". PubMed PMID: "
		id 
	]
	reference/url: join http://www.ncbi.nlm.nih.gov/pubmed/ id

	return ajoin [
		reference/authors
		" [" reference/title "](" reference/url ") " reference/journal " " reference/publication "."
	]
]

; probe create-reference 23648697

; halt
