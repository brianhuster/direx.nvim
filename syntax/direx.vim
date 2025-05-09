syntax match Directory ".*\/$"
exe 'syn' 'match' 'Conceal' '"^\V'..escape(expand('%'), ' "\')..'"' 'conceal'
