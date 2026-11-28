extends RefCounted
## One text found in a file: what it says, where it is by name ([member key]), and the
## span of the file that writes it.

## Where it is, in words that hold while the text changes. See the reader that found it.
var key := ""
var value := ""
## The span of the file's text that writes it: from [member start] up to [member end].
var start := 0
var end := 0
