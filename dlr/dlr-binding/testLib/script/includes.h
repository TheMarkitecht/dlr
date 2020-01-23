
/*
    this file should #include all the required headers for a C app to
    use the native library, such as:

        #include <signal.h>
        #include <pthread.h>
        #include <libCrypt.h>
        #include <libCryptSupport.h>
        #include <libCryptKeys.h>
*/

/*
    normally this would be done by #include'ing one or more .h files,
    but in this test we include a .c file instead, and from a specific path.
*/

#include "[file join [file dirname [file dirname $::dlr::bindingDir]] testLib-src testLib.c]"

/*
    script-style substitutions are performed on this file, for feteching $ variables, and
    executing [] bracketed commands.  that can help with locating the right file paths etc.

    backslash escapes are not substituted; they're passed on to C as-is.

    some of the most helpful substitutions are:
        $headerFn
            = full path and filename of this header file.
        $::dlr::bindingDir
            = full path of the dlr-binding directory.
        $::dlr::scriptPkg
            = full path and filename of the dlr.tcl package script.
        $libAlias
            = alias of the current library.
        $::appDir
            = the directory where the script app is located.  this is set by test.tcl and
            is probably not present in other apps.
        $sQal
            = the namespace qualifier for metadata about the structure being examined.
*/
