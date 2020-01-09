db -output /home/x/debug-dashboard
db source -output /home/x/debug-source

db -layout breaks threads stack source
db source -style context 20
db assembly -style context 5
db stack -style limit 5

file ./jimsh
set args test.tcl
set cwd .
set solib-search-path .:..

b jim-load.c:33
r

b prepMetaBlob
b callToNative
#b test_strtol
#b createBufferVar
#p *meta->cif.arg_types 
# during break at 191:  watch -l meta->cif.arg_types[0]
#   b Jim_GetString if objPtr==0x5555555d9000 && lenPtr==0x7fffffffdd44
# metablob at 0x5555555dbab0 .. 0x5555555dbae8
#   its arg_types at 0x7fffffffdd40
#       overlaps lenPtr in Jim_GetString on next script line.
#       that's in Jim stack space!!  HOW DID ffi_prep_cif GET POINTED TO THAT??
#       that's  &atypes in prepMetaBlob.
#display *((metaBlobT*)0x5555555dbab0)->cif.arg_types
#b Jim_FreeObj if objPtr == 0x5555555dbb00
#b dlrNative.c:119
#b dlrNative.c:191
#b dlrNative.c:214
#p script->linenr

c


db
db

