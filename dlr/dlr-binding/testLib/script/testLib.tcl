# this script sets up all metdata required to use the library "testLib".

# strtolWrap
set ::dlr::lib::testLib::strtolWrap::parmOrder {
    ::dlr::lib::testLib::strtolWrap::parm::strP
    ::dlr::lib::testLib::strtolWrap::parm::endPP
    ::dlr::lib::testLib::strtolWrap::parm::radix
}
::dlr::prepMetaBlob  ::dlr::lib::testLib::strtolWrap::meta  \
    [::dlr::fnAddr  strtolWrap  testLib]  \
    ::dlr::lib::testLib::strtolWrap::result  ::dlr::type::long  \
    $::dlr::lib::testLib::strtolWrap::parmOrder  \
    [list  ::dlr::type::ptr  ::dlr::type::ptr  ::dlr::type::int]

proc ::dlr::lib::testLib::strtolWrap::call {str  &endPVar  radix} {
    ::dlr::pack::ptr  ::dlr::lib::testLib::strtolWrap::parm::strP  [::dlr::addrOf str]
    ::dlr::pack::ptr  ::dlr::lib::testLib::strtolWrap::parm::endP  [::dlr::addrOf endPVar]
    ::dlr::pack::ptr  ::dlr::lib::testLib::strtolWrap::parm::endPP [::dlr::addrOf ::dlr::lib::testLib::strtolWrap::parm::endP]
    ::dlr::pack::int  ::dlr::lib::testLib::strtolWrap::parm::radix  $radix
    set resultPacked [::dlr::callToNative  ::dlr::lib::testLib::strtolWrap::meta]
    set endPVar [::dlr::unpack::ptr  $::dlr::lib::testLib::strtolWrap::parm::endP]
    return [::dlr::unpack::int $resultPacked]
}

# mulByValueT
::dlr::declareStructType  testLib  mulByValueT  {
    {int a}
    {int b}
    {int c}
    {int d}
}
set ::dlr::lib::testLib::mulByValue::parmOrder {
    ::dlr::lib::testLib::mulByValue::parm::st
    ::dlr::lib::testLib::mulByValue::parm::factor
}
::dlr::prepMetaBlob  ::dlr::lib::testLib::mulByValue::meta  \
    [::dlr::fnAddr  mulByValue  testLib]  \
    ::dlr::lib::testLib::mulByValue::result  ::dlr::lib::testLib::struct::mulByValueT::meta  \
    $::dlr::lib::testLib::mulByValue::parmOrder  \
    [list  ::dlr::lib::testLib::struct::mulByValueT::meta  ::dlr::type::int]

proc ::dlr::lib::testLib::mulByValue::call {st  factor} {
    lassign $st memb_a  memb_b  memb_c  memb_d
    ::dlr::createBufferVar     ::dlr::lib::testLib::mulByValue::parm::st  \
        $::dlr::lib::testLib::struct::mulByValueT::size
    ::dlr::pack::int  ::dlr::lib::testLib::mulByValue::parm::st  $memb_a  \
        $::dlr::lib::testLib::struct::mulByValueT::member::a::offset
    ::dlr::pack::int  ::dlr::lib::testLib::mulByValue::parm::st  $memb_b  \
        $::dlr::lib::testLib::struct::mulByValueT::member::b::offset
    ::dlr::pack::int  ::dlr::lib::testLib::mulByValue::parm::st  $memb_c  \
        $::dlr::lib::testLib::struct::mulByValueT::member::c::offset
    ::dlr::pack::int  ::dlr::lib::testLib::mulByValue::parm::st  $memb_d  \
        $::dlr::lib::testLib::struct::mulByValueT::member::d::offset
    ::dlr::pack::int  ::dlr::lib::testLib::mulByValue::parm::factor  $factor
    set resultPacked [::dlr::callToNative  ::dlr::lib::testLib::mulByValue::meta]
    return [list  \
        [::dlr::unpack::int $resultPacked $::dlr::lib::testLib::struct::mulByValueT::member::a::offset]  \
        [::dlr::unpack::int $resultPacked $::dlr::lib::testLib::struct::mulByValueT::member::b::offset]  \
        [::dlr::unpack::int $resultPacked $::dlr::lib::testLib::struct::mulByValueT::member::c::offset]  \
        [::dlr::unpack::int $resultPacked $::dlr::lib::testLib::struct::mulByValueT::member::d::offset]  ]
}
