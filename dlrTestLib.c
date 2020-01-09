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

extern long int test_strtol(const char *nptr, char **endptr, int base);

long int test_strtol(const char *nptr, char **endptr, int base) {
    // wrapper to help debugging.
    return strtol(nptr, endptr, base);
}

