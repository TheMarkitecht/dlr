#include <jim.h>
#include <string.h>
#include <stdlib.h>
#include <dstring.h>
#include <ffi.h>

// this function's name is based on the library's actual filename.  Jim requires that. 
extern int Jim_invokeInit(Jim_Interp* itp);

int callToNative(Jim_Interp *itp, int objc, Jim_Obj *const objv[]) {
// ffi_status  ffi_prep_cif(ffi_cif *cif, ffi_abi abi, unsigned int nargs,ffi_type *rtype, ffi_type **atypes);
// void  ffi_call(ffi_cif *cif, void (*fn)(void), void *rvalue, void **avalue);
    return JIM_OK;
}

int Jim_invokeInit(Jim_Interp* itp) {
    //ivkClientT* client = client_alloc(itp);

//todo: Jim_PackageRequire a specific Jim version.

    if (Jim_PackageProvide(itp, "invoke", "0.1", 0) != JIM_OK) {
        return JIM_ERR;
    }
    
    Jim_CreateCommand(itp,"invoke::callToNative", callToNative, NULL /* client */, NULL);
    
    return JIM_OK;
}

