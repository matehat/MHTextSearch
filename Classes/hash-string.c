/*

Copyright (c) 2005-2008, Simon Howard

Permission to use, copy, modify, and/or distribute this software 
for any purpose with or without fee is hereby granted, provided 
that the above copyright notice and this permission notice appear 
in all copies. 

THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL 
WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED 
WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE 
AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT, INDIRECT, OR 
CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM 
LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, 
NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN      
CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE. 

 */

#include <ctype.h>

#include "hash-string.h"

/* String hash function */

unsigned long string_hash(void *string, unsigned long length)
{
	/* This is the djb2 string hash function */

	unsigned long result = 5381;
    unsigned long acc = 0;
	unsigned char *p;

	p = (unsigned char *) string;
    
	while (*p != '\0' && acc < length) {
		result = ((result << 5) ^ result ) ^ (*p);
		++p;
        ++acc;
	}

	return result;
}

unsigned long jenkins_hash(void *string, unsigned long length)
{
    unsigned char *p;
    unsigned long acc = 0;
    p = (unsigned char *) string;
    
    unsigned long hash = 0;
    
    while (*p != '\0' && acc < length) {
        hash += *p;
        hash += (hash << 10);
        hash ^= (hash >> 6);
        ++p;
        ++acc;
    }
    
    hash += (hash << 3);
    hash ^= (hash >> 11);
    hash += (hash << 15);
    
    return hash;
}

/* The same function, with a tolower on every character so that 
 * case is ignored.  This code is duplicated for performance. */

unsigned long string_nocase_hash(void *string, unsigned long length)
{
	unsigned long result = 5381;
    unsigned long acc = 0;
	unsigned char *p;

	p = (unsigned char *) string;

	while (*p != '\0' && acc < length) {
		result = ((result << 5) ^ result ) ^ tolower(*p);
		++p;
        ++acc;
	}
	
	return result;
}

unsigned long jenkins_nocase_hash(void *string, unsigned long length)
{
    unsigned char *p;
    p = (unsigned char *) string;
    
    unsigned long hash = 0;
    unsigned long acc = 0;
    
    while (*p != '\0' && acc < length) {
        hash += tolower(*p);
        hash += (hash << 10);
        hash ^= (hash >> 6);
        ++p;
        ++acc;
    }
    
    hash += (hash << 3);
    hash ^= (hash >> 11);
    hash += (hash << 15);
    
    return hash;
}
