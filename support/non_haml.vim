" Tidy up for debugging:
syntax clear
set ft=c
call clearmatches()

call TextEnableCodeSnip('ruby', '#{', '}')
call TextEnableCodeSnip('ruby', '^\s*-', '$')
call TextEnableCodeSnip('ruby', '^\s*=', '$')
