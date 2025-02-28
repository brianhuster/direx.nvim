exe "syntax match BufName" '"^'.fnameescape(expand('%')).'"' 'conceal'

hi link BufName Conceal
