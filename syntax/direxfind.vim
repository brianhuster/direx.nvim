syntax match Directory ".*\/$"
exe 'syn match Conceal "^'..escape(b:from_dir, ' "\')..'" conceal'
