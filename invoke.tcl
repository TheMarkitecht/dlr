package provide invoke 0.1

package require invokeNative

# system data structures
set ::invoke::sizeOfPtrBits        $(8 * [::invoke::native::sizeOfPtr])
set ::invoke::ptrFmt               0x%0$($::invoke::sizeOfPtrBits / 4)X
pack ::invoke::nullPtr             0 -intle $::invoke::sizeOfPtrBits
set ::invoke::libs                 [dict create]

# aliases to pass through to native implementations.
alias  ::invoke::prepMetaBlob      ::invoke::native::prepMetaBlob
alias  ::invoke::callToNative      ::invoke::native::callToNative
alias  ::invoke::createBufferVar   ::invoke::native::createBufferVar
alias  ::invoke::addrOf            ::invoke::native::addrOf
alias  ::invoke::sizeOfPtr         ::invoke::native::sizeOfPtr
alias  ::invoke::sizeOfInt         ::invoke::native::sizeOfInt

proc ::invoke::loadLib {libAlias fileNamePath} {
    set handle [native::loadLib $fileNamePath]
    set ::invoke::libs($libAlias) $handle
    return {}
}

proc ::invoke::fnAddr {fnName libAlias} {
    return [native::fnAddr $fnName $::invoke::libs($libAlias)]
}

