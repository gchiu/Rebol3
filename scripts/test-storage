Rebol []

import https://gist.githubusercontent.com/rgchris/8621b68fd54cf6750d8e4668c8c97004/raw/9884edfcd13a18ebd915d109c7a63064e74fbb51/storage-scheme.reb

print "create the port p"
p: make port! [scheme: 'storage host: "Foo"]

print "put data into the storage port which is in persistent storage on your drive"
insert p "test"

print "now retrieve the data"
copy p

