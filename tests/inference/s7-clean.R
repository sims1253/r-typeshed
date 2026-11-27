# Complete S7 stub resolves class_* values and injects self/private/super in new_class().
library(S7)
Range <- new_class(
  "Range",
  properties = list(
    start = class_double,
    end = class_double
  ),
  validator = function(self) {
    if (self@end < self@start) "end must be >= start"
  }
)
S7_inherits(Range(1, 2), Range)
