package provide dlr 0.1

package require dlrNative

# system data structures
set ::dlr::sizeOfPtrBits        $(8 * [::dlr::native::sizeOfPtr])
set ::dlr::ptrFmt               0x%0$($::dlr::sizeOfPtrBits / 4)X
pack ::dlr::nullPtr             0 -intle $::dlr::sizeOfPtrBits
set ::dlr::libs                 [dict create]

# aliases to pass through to native implementations.
alias  ::dlr::prepMetaBlob      ::dlr::native::prepMetaBlob
alias  ::dlr::callToNative      ::dlr::native::callToNative
alias  ::dlr::createBufferVar   ::dlr::native::createBufferVar
alias  ::dlr::addrOf            ::dlr::native::addrOf
alias  ::dlr::sizeOfPtr         ::dlr::native::sizeOfPtr
alias  ::dlr::sizeOfInt         ::dlr::native::sizeOfInt

proc ::dlr::loadLib {libAlias fileNamePath} {
    set handle [native::loadLib $fileNamePath]
    set ::dlr::libs($libAlias) $handle
    return {}
}

proc ::dlr::fnAddr {fnName libAlias} {
    return [native::fnAddr $fnName $::dlr::libs($libAlias)]
}

