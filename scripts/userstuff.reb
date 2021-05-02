Rebol []

repo: lowercase ask "github/gitlab?"
user: ask "Userid?"
project: ask "Your project?"

if any [ empty? repo empty? user empty? project][quit]

file: _

case  [
  repo = "github" [file: to url!  unspaced [https://github.com/ user "/" project "/blob/master/index.reb"]]
  repo = "gitlab" [file: to url! unspaced [https://gitlab.com/ user "/" project "/-/blob/master/index.reb"]]
  true [print "repo not found" quit]
]

print ["Your userfile (file) is at: " file]

