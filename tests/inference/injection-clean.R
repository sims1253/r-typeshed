# Eval/injection metadata control: data() introduces unknown bindings, so
# a name it may provide must not warn RY010 ...
data(mtcars)
print(mpg)
