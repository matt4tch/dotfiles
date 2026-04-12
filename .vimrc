syntax on
set tabstop=4
set clipboard=unnamed,unnamedplus
set number
set tabstop=2
set shiftwidth=2
set hlsearch
set hidden
set nocp
filetype plugin on
" Line cursor within insert mode, block cursor everywhere else
let &t_SI = "\e[6 q"
let &t_EI = "\e[2 q"
