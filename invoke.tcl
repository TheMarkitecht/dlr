package provide invoke 0.1

package require invokeNative

# system data structures
set ::invoke::sizeOfPtrBits     $(8 * [::invoke::sizeOfPtr])
set ::invoke::ptrFmt            0x%0$($::invoke::sizeOfPtrBits / 4)X
pack nullPtr 0 -intle $::invoke::sizeOfPtrBits
set ::invoke::libs              [dict create]

proc ::invoke::loadLib {libAlias fileNamePath} {
    puts $::invoke::libs
    return [loadLibNative $fileNamePath]
}
