# sprintf() yields character(0) when fmt or any value is zero-length,
# like file.path(); the old longest_arg spec claimed one element.
z <- sprintf("%s", character(0))
