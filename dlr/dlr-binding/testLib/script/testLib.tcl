# this script sets up all metdata required to use the library "testLib".

# strtolWrap
#todo: upgrade with better passMethod's and scriptForm's.  native, int, float, list (for structs), dict (for structs).
::dlr::declareCallToNative  testLib  {long asInt}  strtolWrap  {
    {in     byPtr   char        str             asString}
    {out    byPtr   ptr         endP            asInt}
    {in     byVal   int         radix           asInt}
}
set path [file join $::dlr::bindingDir testLib auto strtolWrap.call.tcl]
::dlr::generateCallProc  testLib  strtolWrap  $path
source $path

# mulByValue
::dlr::declareStructType  testLib  mulByValueT  {
    {int a}
    {int b}
    {int c}
    {int d}
}
::dlr::declareCallToNative  testLib  {mulByValueT asList}  mulByValue  {
    {in     byVal   mulByValueT     st              asList}
    {in     byVal   int             factor          asInt}
}

proc ::dlr::lib::testLib::mulByValue::call {st  factor} {
    lassign $st memb_a  memb_b  memb_c  memb_d
    ::dlr::createBufferVar     ::dlr::lib::testLib::mulByValue::parm::st::native  \
        $::dlr::lib::testLib::struct::mulByValueT::size
    ::dlr::pack::int  ::dlr::lib::testLib::mulByValue::parm::st::native  $memb_a  \
        $::dlr::lib::testLib::struct::mulByValueT::member::a::offset
    ::dlr::pack::int  ::dlr::lib::testLib::mulByValue::parm::st::native  $memb_b  \
        $::dlr::lib::testLib::struct::mulByValueT::member::b::offset
    ::dlr::pack::int  ::dlr::lib::testLib::mulByValue::parm::st::native  $memb_c  \
        $::dlr::lib::testLib::struct::mulByValueT::member::c::offset
    ::dlr::pack::int  ::dlr::lib::testLib::mulByValue::parm::st::native  $memb_d  \
        $::dlr::lib::testLib::struct::mulByValueT::member::d::offset
    ::dlr::pack::int  ::dlr::lib::testLib::mulByValue::parm::factor::native  $factor
    set resultPacked [::dlr::callToNative  ::dlr::lib::testLib::mulByValue::meta]
    return [list  \
        [::dlr::unpack::int $resultPacked $::dlr::lib::testLib::struct::mulByValueT::member::a::offset]  \
        [::dlr::unpack::int $resultPacked $::dlr::lib::testLib::struct::mulByValueT::member::b::offset]  \
        [::dlr::unpack::int $resultPacked $::dlr::lib::testLib::struct::mulByValueT::member::c::offset]  \
        [::dlr::unpack::int $resultPacked $::dlr::lib::testLib::struct::mulByValueT::member::d::offset]  ]
}
