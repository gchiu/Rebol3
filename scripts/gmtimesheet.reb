Rebol [
  date: 7-April-2019
  notes: {
    Docx templating test using JS and Rebol
  
    Ask a few questions, then generate a JS function which we push to the DOM.
    This should convert the template docx to be filled with our data which you download
    
    source: https://docxtemplater.com/
    docs: https://docxtemplater.readthedocs.io/en/latest/generate.html
    
  }
]

for-each site [
  https://cdnjs.cloudflare.com/ajax/libs/docxtemplater/3.9.1/docxtemplater.js
  https://cdnjs.cloudflare.com/ajax/libs/jszip/2.6.1/jszip.js
  https://cdnjs.cloudflare.com/ajax/libs/FileSaver.js/1.3.8/FileSaver.js
  https://cdnjs.cloudflare.com/ajax/libs/jszip-utils/0.0.2/jszip-utils.js
][
  js-do site
]

js-do {window.loadFile = function(url,callback){
        JSZipUtils.getBinaryContent(url,callback);
    };
}

definput: function [ description def][
    prin unspaced [Description " (" def "): "]
    temp: input
    if empty? temp [temp: def]
    return temp
]

GST: 1.15

;; get the week ending.  Calculate a default for this week
week_ending: 
if now/weekday = 1 [
    now
] else [
    now + 8 - now/weekday
]
week_ending: week_ending/date

cycle [
    prin unspaced ["Week Ending (" week_ending "): "]
    endofweek: input
    if empty? endofweek [break]
    attempt [
        endofweek: to date! endofweek
        week_ending: endofweek
        break
    ]
]

; get days worked {MTWHF}
daysworked: definput "Which days were worked?" "MTWHF"

if empty? daysworked [halt]

if find daysworked "M" [
    s2: "08:00" e2: "17:00"
] else [
    s2: "" e2: ""
]

if find daysworked "T" [
    s3: "08:00" e3: "17:00"
] else [
    s3: ""  e3: ""
]

if find daysworked "W" [
    s4: "08:00" e4: "17:00"
] else [
    s4: ""  e4: ""
]

if find daysworked "H" [
    s5: "08:00" e5: "17:00"
] else [
    s5: ""  e5: ""
]

if find daysworked "F" [
    s6: "08:00" e6: "17:00"
] else [
    s6: ""  e6: ""
]

if find daysworked "S" [
    s7: "08:00" e7: "17:00"
] else [
    s7: ""  e7: ""
]

if find daysworked "U" [
    s1: "08:00" e1: "17:00"
] else [
    s1: "" e1: ""
]

data: {window.generate = function() {
        loadFile("https://metaeducation.s3.amazonaws.com/invoices/GM_timesheet_NZ-form-31.docx",function(error,content){
            if (error) { throw error };
            var zip = new JSZip(content);
            var doc=new window.docxtemplater().loadZip(zip)
            doc.setData({
                Week_ending: '$week_ending',
                Hospital: '$hospital',
                Position: '$position',
                Name: '$name',
                
                S1: '$s1',
                E1: '$e1',
                S2: '$s2',
                E2: '$e2',
                S3: '$s3',
                E3: '$e3',
                S4: '$s4',
                E4: '$e4',
                S5: '$s5',
                E5: '$e5',
                S6: '$s6',
                E6: '$e6',
                S7: '$s7',
                E7: '$e7',
            });
            try {
                // render the document (replace all occurences of {first_name} by John, {last_name} by Doe, ...)
                doc.render()
            }
            catch (error) {
                var e = {
                    message: error.message,
                    name: error.name,
                    stack: error.stack,
                    properties: error.properties,
                }
                console.log(JSON.stringify({error: e}));
                // The error thrown here contains additional information when logged with JSON.stringify (it contains a property object).
                throw error;
            }
            var out=doc.getZip().generate({
                type:"blob",
                mimeType: "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
            }) //Output the document using Data-URI
            saveAs(out,"$week_ending.docx")
        })
    };
    generate()
}

name: "Graham Chiu"
position: "Rheumatologist"
hospital: "Tauranga Hospital"

template: reduce [
    'week_ending  week_ending
    'name   name
    'hospital   hospital
    'position   position
    's1 s1
    'e1 e1
    's2 s2
    'e2 e2
    's3 s3
    'e3 e3
    's4 s4
    'e4 e4
    's5 s5
    'e5 e5
    's6 s6
    'e6 e6
    's7 s7
    'e7 e7
]

; probe template

data: reword data template
; probe data

js-do data
