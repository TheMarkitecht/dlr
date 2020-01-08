#include <jim.h>
#include <string.h>
#include <stdlib.h>
#include <dstring.h>
#include <ffi.h>

#define MAX_ARGS 20

typedef unsigned char u8;
typedef void (*ffiFnP)(void);

typedef struct {
    // library-wide data structures.
    ffi_cif cif;
    void* argPtrs[MAX_ARGS];
} ivkClientT;
typedef ivkClientT* ivkClientP;
ivkClientT clientStorage; //todo: move to a Jim_Malloc'd area.  and clear it.
ivkClientP client = &clientStorage;

// map type ID codes to type metadata structs.
// to prevent confusion, the order here corresponds exactly to the indices given by
// FFI_TYPE_* define's in ffi.h line 459.
ffi_type * const ffiTypes[] = {
    &ffi_type_void,
    NULL, // FFI_TYPE_INT unusable; not specific enough.
    &ffi_type_float,
    &ffi_type_double,
    &ffi_type_longdouble,
    &ffi_type_uint8,
    &ffi_type_sint8,
    &ffi_type_uint16,
    &ffi_type_sint16,
    &ffi_type_uint32,
    &ffi_type_sint32,
    &ffi_type_uint64,
    &ffi_type_sint64,
    NULL, // FFI_TYPE_STRUCT unusable; length unknown.
    &ffi_type_pointer,
    NULL, // FFI_TYPE_COMPLEX unusable; not specific enough.
};

#define FFI_TYPE_FINAL  FFI_TYPE_COMPLEX

// this function's name is based on the library's actual filename.  Jim requires that. 
extern int Jim_invokeInit(Jim_Interp* itp);

/* **********************  EXECUTABLE CODE BELOW  ***************************** */

long int test_strtol(const char *nptr, char **endptr, int base) {
    // wrapper to help debugging.
    return strtol(nptr, endptr, base);
}

int varToType(Jim_Interp* itp, const char* varName, ffi_type** typ) {
    Jim_Obj* v = Jim_GetGlobalVariableStr(itp, varName, JIM_NONE);
    if (v == NULL) {
        Jim_SetResultString(itp, "The variable designating a data type is not found.", -1);
        return JIM_ERR;
    }
    jim_wide code = 0;
    if (Jim_GetWide(itp, v, &code) != JIM_OK || code < 0 || code > FFI_TYPE_FINAL || ffiTypes[code] == NULL) {
        Jim_SetResultString(itp, "Expected type ID code but got other data.", -1);
        return JIM_ERR;
    }
    *typ = ffiTypes[code];
    return JIM_OK;
}

int getFnAddr(Jim_Interp* itp, int objc, Jim_Obj * const objv[]) {
    Jim_SetResultInt(itp, (jim_wide)test_strtol);
    return JIM_OK;
}

int sizeOfInt(Jim_Interp* itp, int objc, Jim_Obj * const objv[]) {
    Jim_SetResultInt(itp, (jim_wide)sizeof(int));
    return JIM_OK;
}

int sizeOfPtr(Jim_Interp* itp, int objc, Jim_Obj * const objv[]) {
    Jim_SetResultInt(itp, (jim_wide)sizeof(void*));
    return JIM_OK;
}

int addressOfContent(Jim_Interp* itp, int objc, Jim_Obj * const objv[]) {
    enum { 
        cmdIX = 0,
        varNameIX,
        argCount
    };
    
    if (objc != argCount) {
        Jim_SetResultString(itp, "Wrong # args.", -1);
        return JIM_ERR;
    }

    Jim_Obj* v = Jim_GetVariable(itp, objv[varNameIX], JIM_NONE);
    if (v == NULL) {
        Jim_SetResultString(itp, "Variable not found.", -1);
        return JIM_ERR;
    }
    Jim_SetResultInt(itp, (jim_wide)v->bytes);
    return JIM_OK;
}

int callToNative(Jim_Interp* itp, int objc, Jim_Obj * const objv[]) {
    enum { 
        cmdIX = 0,
        fnIX,
        argCount
    };
    
    if (objc != argCount) {
        Jim_SetResultString(itp, "Wrong # args.", -1);
        return JIM_ERR;
    }
    
    jim_wide w = 0;
    if (Jim_GetWide(itp, objv[fnIX], &w) != JIM_OK) {
        Jim_SetResultString(itp, "Expected function pointer but got other data.", -1);
        return JIM_ERR;
    }
    ffiFnP fn = (ffiFnP)w;
    if (fn == NULL) {
        Jim_SetResultString(itp, "Null function pointer.", -1);
        return JIM_ERR;
    }  

    //todo: move to metaBlob.
    // gather parm metadata.
    Jim_Obj* parmsList = Jim_GetGlobalVariableStr(itp, "invoke::parms", JIM_NONE);
    if (parmsList == NULL) {
        Jim_SetResultString(itp, "Parms list variable not found.", -1);
        return JIM_ERR;
    }
    int nArgs = Jim_ListLength(itp, parmsList);
    ffi_type* rtype = NULL;
    if (varToType(itp, "invoke::rtype", &rtype) != JIM_OK) return JIM_ERR;
    ffi_type* atypes[nArgs];
    
    // fill argPtrs with pointers to the content of designated script vars.
    // those vars are the buffers for the content during this native call.
    char buf[20];
    Jim_Obj* o; 
    Jim_ListIter iter;
    int n = 0;
    for (JimListIterInit(&iter, parmsList); (o = JimListIterNext(itp, &iter)) != NULL; n++) {
        //todo: make this compute names of more metadata vars from the prefix in the list.
        Jim_Obj* v = Jim_GetGlobalVariable(itp, o, JIM_NONE);
        if (v == NULL) {
            Jim_SetResultString(itp, "Argument variable not found.", -1);
            return JIM_ERR;
        }
        client->argPtrs[n] = v->bytes;
        
        snprintf(buf, 20, "invoke::atype%d", n);
        if (varToType(itp, buf, &atypes[n]) != JIM_OK) return JIM_ERR;
    }  
    
    // verify sufficient return value buffer in the designated script var.
    
    // prep CIF.
// ffi_status  ffi_prep_cif(ffi_cif *cif, ffi_abi abi, unsigned int nargs,ffi_type *rtype, ffi_type **atypes);
    ffi_status err = ffi_prep_cif(&client->cif, FFI_DEFAULT_ABI, (unsigned int)nArgs, rtype, atypes);
    if (err != FFI_OK) {
        Jim_SetResultString(itp, "Failed to prep FFI CIF for call.", -1);
        return JIM_ERR;
    }  

    // arrange space for return value.
    int resultLen = (int)rtype->size; 
    char* resultBuf = Jim_Alloc(resultLen + 1); // extra 1 for null terminator is not needed for invoke, but may be needed by any further script operations on the object.
    if (resultBuf == NULL) {
        Jim_SetResultString(itp, "Out of memory while allocating result buffer.", -1);
        return JIM_ERR;
    }  
    resultBuf[resultLen] = 0; // last-ditch safety for any further script operations on the object.
    Jim_Obj* resultValueObj = Jim_NewStringObjNoAlloc(itp, resultBuf, resultLen);
    if (Jim_SetGlobalVariableStr(itp, "::invoke::result", resultValueObj) != JIM_OK) {
        Jim_SetResultString(itp, "Failed to set variable for result buffer.", -1);
        return JIM_ERR;
    }    
    
    // execute call.
    ffi_call(&client->cif, fn, (void*)resultBuf, (void**)client->argPtrs);
    
    return JIM_OK;
}

int Jim_invokeInit(Jim_Interp* itp) {
    //ivkClientT* client = client_alloc(itp);

//todo: Jim_PackageRequire a specific Jim version.

    if (Jim_PackageProvide(itp, "invoke", "0.1", 0) != JIM_OK) {
        return JIM_ERR;
    }
    
    Jim_CreateCommand(itp,"invoke::callToNative", callToNative, NULL /* client */, NULL);
    Jim_CreateCommand(itp,"invoke::getFnAddr", getFnAddr, NULL /* client */, NULL);
    Jim_CreateCommand(itp,"invoke::sizeOfInt", sizeOfInt, NULL /* client */, NULL);
    Jim_CreateCommand(itp,"invoke::sizeOfPtr", sizeOfPtr, NULL /* client */, NULL);
    Jim_CreateCommand(itp,"invoke::addressOfContent", addressOfContent, NULL /* client */, NULL);
    
    return JIM_OK;
}

