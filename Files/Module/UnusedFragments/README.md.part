

### 4.6 Connect

The subroutine **connect** connects a QtSignal to a QtSlot (or to another
QtSignal).

`sub connect(QtObject $src, Str $signal, QtObject $dst, Str $slot)`

The names of signal and slot are passed to connect in strings.

The signal and slot must have compatible signatures.

This means that every parameter in the slot signature must get a suitable value
from the signal capture.
    
The signal
<br>&nbsp;&nbsp;&nbsp;&nbsp;`signal( Int $a, Str $b )`
<br>is compatible with the slot
<br>&nbsp;&nbsp;&nbsp;&nbsp;`slot( Int $x, Str $y )` _(same arguments, same types)_
<br>and
<br>&nbsp;&nbsp;&nbsp;&nbsp;`slot( Int $x )` _(value $b is ignored)_
<br>and
<br>&nbsp;&nbsp;&nbsp;&nbsp;`slot( Int $x, Str $y, Int $z = 42 )` _($z has a default value)_
<br>but not with the slot
<br>&nbsp;&nbsp;&nbsp;&nbsp;`slot( Str $x, Str $y )` _(wrong types)_
<br>neither with
<br>&nbsp;&nbsp;&nbsp;&nbsp;`slot( Int $x, Str $y, Int $z )` _($z has no value)_




Example:

```
my $src = MyClass2.new;
my $dst = MyClass.new;
connect $src, "mySignal", $dst, "mySlot";
```

### 4.7 Disconnect


