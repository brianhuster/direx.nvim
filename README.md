# dir.nvim

A simple file explorer for Neovim, inspired by [vim-dirvish](https://github.com/justinmk/vim-dirvish) and [vim-drvo](https://github.com/matveyt/vim-drvo).

# Features

- Small: ~700 LOC
- Simple and minimal UI: Every Direx buffer is just a list of absolute paths, in which parent directory names are hidden by `conceal`.
- Supports preview, hover info, cut, copy, paste, delete, rename files
- Find files using `:DirexFind`, grep using `:DirexGrep`
- LSP integration
- Use `:Shdo` to script your actions
- Integration with external fuzzy finders like [fzf](https://github.com/junegunn/fzf), [fzy](https://github.com/jhawthorn/fzy), [skim](https://github.com/lotabout/skim) and [fd](https://github.com/sharkdp/fd)

# Installation

You can install the plugin using your favorite plugin manager, for example `vim-plug`:

```vim
Plug 'brianhuster/direx.nvim'
```

Or you can install it using native `packages` feature
```sh
git clone https://github.com/brianhuster/direx.nvim.git ~/.local/share/nvim/site/pack/plugins/start/direx.nvim
```

See [`:h direx`](https://github.com/brianhuster/direx.nvim/blob/main/doc/direx.txt) for information about configuration and usage.
