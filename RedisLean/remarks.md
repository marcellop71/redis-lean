## Remarks about *Redis*

### Data types

The TYPE command in Redis returns a string describing the type of the value pointed by a key.
"none" is the string returned if the key doesn't exist.
Possible strings are: "string", "list", "set", "zset", "hash", "stream", "vectorset".
"string" means a general byte array and could be used to host UTF8 strings or integers.
A numeric (integer) value is so a "string" (i.e. a byte array) that could be parsed as an integer.
For example, the INCR command operates on "string"s but it assumes that the value is a byte array that can be parsed (as a string) to an integer.

### Return values

cosa torna GET (NIL) e perche' in questo client
GET non torna Option ma keyNotFound e' un Error
