/*
"dlr" - Dynamic Library Redux
Copyright 2020 Mark Hubbard, a.k.a. "TheMarkitecht"
http://www.TheMarkitecht.com

Project home:  http://github.com/TheMarkitecht/dlr
dlr is an extension for Jim Tcl (http://jim.tcl.tk/)
dlr may be easily pronounced as "dealer".

This file is part of dlr.

dlr is free software: you can redistribute it and/or modify
it under the terms of the GNU Lesser General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

dlr is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Lesser General Public License for more details.

You should have received a copy of the GNU Lesser General Public License
along with dlr.  If not, see <https://www.gnu.org/licenses/>.
*/

#include <string.h>
#include <stdlib.h>
#include <stdint.h>

typedef uint8_t u8;
typedef uint32_t u32;

/* **********************  EXECUTABLE CODE BELOW  ***************************** */

// wrapper of a simple libc function, to help debugging and smoke testing.
extern long int strtolTest(const char *nptr, char **endptr, int base);
long int strtolTest(const char *nptr, char **endptr, int base) {
    return strtol(nptr, endptr, base);
}

// pass a struct or array by value.  return a different version of that.
typedef struct {int a, b, c, d; } quadT;
extern quadT mulByValue(const quadT st, const int factor);
quadT mulByValue(const quadT st, const int factor) {
    quadT r = {st.a * factor, st.b * factor, st.c * factor, st.d * factor};
    return r;
}

// define another type.
typedef u32 dataHandleT;
extern dataHandleT dataHandler(dataHandleT handle);
dataHandleT dataHandler(dataHandleT handle) {
    return handle << 4;
}

extern dataHandleT dataHandlerPtr(dataHandleT* handleP);
dataHandleT dataHandlerPtr(dataHandleT* handleP) {
    *handleP = *handleP << 4;
    return *handleP;
}

extern void dataHandlerVoid(dataHandleT* handleP);
void dataHandlerVoid(dataHandleT* handleP) {
    *handleP = *handleP << 4;
}

// floating point.
extern float floatSquare(double stuff, long double longStuff);
float floatSquare(double stuff, long double longStuff) {
    return (float)(stuff * longStuff);
}

extern void floatSquarePtr(double* stuff);
void floatSquarePtr(double* stuff) {
    *stuff = *stuff * *stuff;
}
