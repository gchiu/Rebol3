Rebol []

repo: lowercase ask "github/gitlab?"
user: ask "Userid?"
project: ask "Your project?"

if any [ empty? repo empty? user empty? project][quit]

file: _

case  [
  repo = "github" [file:  unspaced [https://github.com/" user "/" project "/-/blob/master/index.reb"]
  repo = "gitlab: [file: unspaced [https://gitlab.com/" user "/" project "/-/blob/master/index.reb"]
]

print ["Your userfile is at: " file]
