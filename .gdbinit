db -output /home/x/debug-dashboard
db source -output /home/x/debug-source

db -layout breaks threads stack source
db source -style context 20
db assembly -style context 5
db stack -style limit 8

file ./jimsh
set args bench.tcl
set cwd .
set solib-search-path .:..

b jim-load.c:33
r

#b Jim_GenHashFunction
#commands 
#    c
#end

#b prepMetaBlob
b callToNative
#b strtolWrap
#b createBufferVar
#p *meta->cif.arg_types 
# during break at 191:  watch -l meta->cif.arg_types[0]
#display *((metaBlobT*)0x5555555dbab0)->cif.arg_types
#b Jim_FreeObj if objPtr == 0x5555555dbb00
#b dlrNative.c:349
#p script->linenr

c


db
db

