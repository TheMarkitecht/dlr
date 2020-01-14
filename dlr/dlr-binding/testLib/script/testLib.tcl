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
    
alias  ::dlr::lib::testLib::mulByValue::call  \
    ::dlr::callToNative  ::dlr::lib::testLib::mulByValue::meta
