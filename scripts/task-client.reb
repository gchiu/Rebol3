Rebol [
	title: "Task Client"
	file: task-client.reb
	Author: "Graham Chiu"
	Date: 12-July-2014
	Notes: {run the gui-server first and then run mulitple clients}
]

; read the task server to see if task available.
task-server: http://127.0.0.1:8080/

request-task: join task-server "request-task"
answer-task: join task-server "answer-task"

forever [
	print "Fetching request"
	r: to string! read request-task
	either any [ r = "notok" none? r ][
		; no task, so wait
		print "no tasks available"
		wait 2
	][
		either object? task: load r [
			print [ "Doing command " task/cmd]
			result: do task/cmd
			id: task/id
			response: write rejoin [ answer-task "/" id ] result
			wait 2
			print "Sent results"
		][
			probe type? task
			probe task
			wait 2
		]
	]
]