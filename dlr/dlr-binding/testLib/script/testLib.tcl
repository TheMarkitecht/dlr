# this script sets up all metdata required to use the library "testLib".

::dlr::loadAutoStructTypes  testLib

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
#todo: merge in here the extracted struct layout metadata.
::dlr::prepStructType  ::dlr::lib::testLib::mulByValueT  [list  \
    ::dlr::type::int  ::dlr::type::int  ::dlr::type::int  ::dlr::type::int]
set ::dlr::lib::testLib::mulByValue::parmOrder {
    ::dlr::lib::testLib::mulByValue::parm::st
    ::dlr::lib::testLib::mulByValue::parm::factor
}
::dlr::prepMetaBlob  ::dlr::lib::testLib::mulByValue::meta  \
    [::dlr::fnAddr  mulByValue  testLib]  \
    ::dlr::lib::testLib::mulByValue::result  ::dlr::lib::testLib::mulByValueT  \
    $::dlr::lib::testLib::mulByValue::parmOrder  \
    [list  ::dlr::lib::testLib::mulByValueT  ::dlr::type::int]

proc ::dlr::lib::testLib::mulByValue::call {st  factor} {
    #todo: fetch sizeof arbitrary type, and offsetof, to allow for padding here.  for now it just allocates oversize.
    set offsetsMeta {0 4 8 12}
    lassign $st memb_a  memb_b  memb_c  memb_d
    lassign $offsetsMeta ofs_a  ofs_b  ofs_c  ofs_d
    ::dlr::createBufferVar     ::dlr::lib::testLib::mulByValue::parm::st  32    
    ::dlr::pack::int  ::dlr::lib::testLib::mulByValue::parm::st  $memb_a  $ofs_a
    ::dlr::pack::int  ::dlr::lib::testLib::mulByValue::parm::st  $memb_b  $ofs_b
    ::dlr::pack::int  ::dlr::lib::testLib::mulByValue::parm::st  $memb_c  $ofs_c
    ::dlr::pack::int  ::dlr::lib::testLib::mulByValue::parm::st  $memb_d  $ofs_d
    ::dlr::pack::int  ::dlr::lib::testLib::mulByValue::parm::factor  $factor
    set resultPacked [::dlr::callToNative  ::dlr::lib::testLib::mulByValue::meta]
    return [list  \
        [::dlr::unpack::int $resultPacked $ofs_a]  \
        [::dlr::unpack::int $resultPacked $ofs_b]  \
        [::dlr::unpack::int $resultPacked $ofs_c]  \
        [::dlr::unpack::int $resultPacked $ofs_d]  ]
}
