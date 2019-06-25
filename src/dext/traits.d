/**
Provides functionality for manipulating types or gathering information about types and other language elements.

Supplemental to [std.traits] and [__traits];

Authors: Tony J. Hudgins
Copyright: Copyright © 2019, Tony J. Hudgins
License: MIT
*/
module dext.traits;

/++
Given any type [T], turn it into a pointer such that [asPointer!T] == [T*].

Authors: Tony J. Hudgins
Copyright: Copyright © 2019, Tony J. Hudgins
License: MIT
+/
alias asPointer( T ) = T*;
