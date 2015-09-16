Rebol [
	file: %calendar-google-api.reb
	title: "Access Google APIs"
	author: "Graham Chiu"
	date: 16-Sep-2015
	version: 0.0.1
	notes: {
		This script just uses the calendar api.  Others are similar.

		1. You need to be an authenticated user of the calendar.  See https://developers.google.com/google-apps/calendar/auth
		2. From the developers console https://console.developers.google.com/ you need to create a project
		3. Once you have a project, click on "Apis and Auth/APIs"
		4. Click on the blue button "Enable Api"
		5. Click on "Apis and Auth/Credentials", and then the blue button "Add Credentials"
		6. Select OAuth 2.0 Client ID
		7. Application type, choose other from the radio buttons
		8. Give your client a name
		9. You will now see your client name, Client ID and on the far right a down arrow to download the credentials. The credentials are a JSON file.
		10. Load-json on this file to give yourself the installed object, and replace mine with yours in the settings object.
		11. This file never changes so you can embed it in your script
		12. You now build a query with scope set to the calendar.  Use your own gmail account for the login_hint
		13. Send the system web browser to the authentication server
		14. You may have to login to your google account.  If already logged in you'll be asked if it's okay to allow your project access to you calendar
		15. Copy the generated access token and paste it into the view field that this script brings up ( or just copy it and change the value of settings/token with it ).  We don't need to keep it as it's just used once to get our long lasting refresh token
		16. We now form our query to exchange our access token for the refresh token. Bizzarely the redirect_uri parameter must not be URL encoded so we add it after we have formed the query
		17. We now post to the token-server to get our refresh_token 
		18. Shows a cURL script to get the same data, helpful if you get 400 errors
		19. The JSON object successfully returned
		20. We're going to immediately refresh the access token returned
		21. Call the token server using our refresh_token to get a new access_token
		22. Create a simple calendar event.  Note that currently the JSON returned can't be loaded by altjson's load-json function as it has self: something, and 'self is a protected word
	}
]

token-server: https://www.googleapis.com/oauth2/v3/token
calendar-api: https://www.googleapis.com/calendar/v3/calendars/primary/

u: self
  
settings: make object! [
    installed: make object! [
        client_id: {see-step-10-above}
        auth_uri: "https://accounts.google.com/o/oauth2/auth"
        token_uri: "https://accounts.google.com/o/oauth2/token"
        auth_provider_x509_cert_url: "https://www.googleapis.com/oauth2/v1/certs"
        client_secret: "see-step-10-above"
        redirect_uris: [
            "urn:ietf:wg:oauth:2.0:oob"
            "http://localhost"
        ]
    ]
    token: ""
    gmail: youraccount@gmail.com
]

authenication-server: to url! append settings/installed/auth_uri "?"

resources: [
    %prot-http.reb https://raw.githubusercontent.com/gchiu/Rebol3/master/protocols/prot-http.r3
    %combine.reb https://raw.githubusercontent.com/hostilefork/rebol-proposals/master/combine.reb
    %altjson.reb http://reb4.me/r3/altjson
    %altwebform.reb http://reb4.me/r3/altwebform
    %r3-gui.reb http://www.atronixengineering.com/r3/r3-gui.r3
    %form-date.reb http://reb4.me/r3/form-date
]

; one time download files we need
foreach [script location] resources [
    unless exists? script [write script read location]
    do script
]

; Step #12

query: to-webform compose [
	response_type: "code"
	client_id: (settings/installed/client_id)
	redirect_uri: (settings/installed/redirect_uris/1)
	scope: https://www.googleapis.com/auth/calendar
	state: "any"
	login_hint: (settings/gmail) 
	include_granted_scopes: "true"
	access_type: "offline"
	approval_prompt: "force"
]

; Step #13
browse join authentication-server query

; Step #15
view [
	vgroup [
		label "Enter Google Authorisation Code: " f: field ""
		button "Accept" on-action [ 
			u/settings/token: copy get-face f
			unview/all 
		]
	]
]

probe settings/token

; Step #16
query: to-webform compose [
	code: (settings/token)
	client_id: (settings/installed/client_id)
	client_secret: (settings/installed/client_secret)
	scope: ""
	grant_type: "authorization_code"
]

; some odd bug where it won't accept url-encoded redirect_uri
append query join "&redirect_uri=" settings/installed/redirect_uris/1

; Step #17
response: write token-server compose/deep [
	POST
	[
		Content-Type: "application/x-www-form-urlencoded"
	]
	(query)
]

; Step #18
; script: reform  ["curl -d" rejoin [ {"} query {"}] token-server]
; write %curl/script.cmd script

resp: load-json to string! response 

; Step #19
comment {
The object returned by exchanging the first token to get the refresh token looks like this:

resp: make object! [
    access_token: {ya29.7wHFAnZYm9QxSv2tmQnvlIe_Gj87v95O5OcOUnMNa94v6HpYLjTXDmodn3kpN7bLN_ct}
    token_type: "Bearer"
    expires_in: 859189296
    refresh_token: {1/long string of characters.  Do not lose this one!}
]

}

; Step #20
query: to-webform [
	client_id: (settings/installed/client_id)
	client_secret: (settings/installed/client_secret)
	refresh_token: (resp/refresh_token)
	grant_type: "refresh_token"
]

; Step 21
jtoken: load-json to string! write token-server compose/deep [
	POST
	[
		Content-Type: "application/x-www-form-urlencoded"
	]
	(query)
]

comment {
We get a JSON object back looking like this which expires in 60 mins

make object! [
    access_token: {ya29.7wGh6amVn5nEWZCZytOUYSioJYel9ZaTWSwTbwGjWGqg0-OS8sDPcZCAk4mmgd_WeySn42w}
    token_type: "Bearer"
    expires_in: 3600
]
}

; change the expires_in to an actual datetime so we can check it later on, and see if we have to get another one
jtoken/expires_in: now + jtoken/expires_in

Add-Calendar-Entry: function [{Add a basic entry to primary calendar}
	start-datetime [date!] end-datetime [date!] description [string!]
][
	start-datetime/zone: end-datetime/zone: now/zone
	api: join calendar-api "events"
	payload: make object! compose/deep [
		start: make object! [ 
			dateTime: (form-date start-datetime "%Y-%m-%dT%H:%M:%S%z")
		]
		end: make object! [ 
			dateTime: (form-date end-datetime "%Y-%m-%dT%H:%M:%S%z")
		]
		summary: (description)
	]

	;probe to-json payload

	response: write api compose/deep [
		POST
		[
			content-type: "application/json; charset=UTF-8"
			Authorization: (join "Bearer " jtoken/access_token) 
		]
		(to-json payload)
	]
]

; Step #22
example: to string! add-calendar-entry 16-09-2015/16:00 16-09-2015/17:00 "Call Hostilefork"
