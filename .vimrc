" set leader to space
let mapleader = " "
let g:mapleader = " "
let g:maplocalleader = " "

" set vi nocompatible
set nocompatible

" Automatic installation of vim-plug
let data_dir = has('nvim') ? stdpath('data') . '/site' : '~/.vim'
if empty(glob(data_dir . '/autoload/plug.vim'))
  silent execute '!curl -fLo '.data_dir.'/autoload/plug.vim --create-dirs  https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'
  autocmd VimEnter * PlugInstall --sync | source $MYVIMRC
endif

" Plugins will be downloaded under the specified directory.
call plug#begin(has('nvim') ? stdpath('data') . '/plugged' : '~/.vim/plugged')

" Declare the list of plugins.
" -----COLORSCHEME-----
Plug 'catppuccin/vim', { 'as': 'catppuccin' }
Plug 'itchyny/lightline.vim'

" -----UltiSnips-----
Plug 'sirver/ultisnips'

" -----Terminus-----
Plug 'wincent/terminus' " make cursorline when entering insert mode

" -----VimTex-----
Plug 'lervag/vimtex'

" -----GitHubCopilot-----
Plug 'github/copilot.vim'

" -----coc.nvim-----
Plug 'neoclide/coc.nvim', {'branch': 'release'}

" -----vim-wayland-clipboard-----
Plug 'jasonccox/vim-wayland-clipboard' " clipboard support for wayland, disable if using X11

" List ends here. Plugins become visible to Vim after this call.
call plug#end()

colorscheme catppuccin_mocha
let g:lightline = {
  \ 'colorscheme': 'catppuccin_mocha',
  \ }

" Disable showmode since lightline will show the current mode.
set noshowmode

" set UTF8 character encoding
set encoding=utf8

" syntax highlight
syntax on

" Disable the default Vim startup message.
set shortmess+=I

" Show relative line numbers.
set number
" set relativenumber

" Always show the status line at the bottom, even if you only have one window open.
set laststatus=2

" The backspace key has slightly unintuitive behavior by default. For example,
" by default, you can't backspace before the insertion point set with 'i'.
" This configuration makes backspace behave more reasonably, in that you can
" backspace over anything.
set backspace=indent,eol,start

set ignorecase
set smartcase
set incsearch
set hlsearch
nnoremap <silent> <Esc> :nohlsearch<CR>

" 'Q' in normal mode enters Ex mode. You almost never want this.
nmap Q <Nop>

" enable mouse
set mouse+=a

" clip to system clipboard
set clipboard^=unnamed,unnamedplus

" show matching braces when text indicator is over them
set showmatch

" highlight current line, but only in active window
" augroup CursorLineOnlyInActiveWindow
"     autocmd!
"     autocmd VimEnter,WinEnter,BufWinEnter * setlocal cursorline
"     autocmd WinLeave * setlocal nocursorline
" augroup END

" enable file type detection
filetype on
filetype plugin indent on
filetype plugin plugin on

set autoindent

" disable startup message
set shortmess+=I

" set list to see tabs and non-breakable spaces
set listchars=tab:>>,nbsp:~

" line break
set linebreak

" break indent
set breakindent

" show lines above and below cursor (when possible)
set scrolloff=5

" fix slow O inserts
set timeout timeoutlen=1000 ttimeoutlen=100

" more history
set history=8192

set expandtab
set tabstop=4
set shiftwidth=4
set softtabstop=4

" tab completion for files/buffers
set wildmode=longest,list
set wildmenu

" map ctrl+a to select all
" nnoremap <C-a> ggVG<C-o>

" disable audible bell
set noerrorbells visualbell t_vb=

" open new split panes to right and bottom, which feels more natural
set splitbelow
set splitright

" quicker window movement
nnoremap <C-j> <C-w>j
nnoremap <C-k> <C-w>k
nnoremap <C-h> <C-w>h
nnoremap <C-l> <C-w>l

" show the status line at the bottom
set laststatus=2

" some plugins require fast updata time
set updatetime=100

" improve re-drawing
set ttyfast

" maintain undo history between sessions
set undofile
set undodir=~/.vim/undodir

" Jump to start and end of line using the home row keys
map H ^
map L $

" Search results centered please
nnoremap <silent> n nzz
nnoremap <silent> N Nzz
nnoremap <silent> * *zz
nnoremap <silent> # #zz
nnoremap <silent> g* g*zz
nnoremap <C-o> <C-o>zz
nnoremap <C-i> <C-i>zz

" Map j to gj and k to gk in normal mode and visual mode
nnoremap j gj
nnoremap k gk
vnoremap j gj
vnoremap k gk

" Jump to last edit position on opening file
if has("autocmd")
  " https://stackoverflow.com/questions/31449496/vim-ignore-specifc-file-in-autocommand
  au BufReadPost * if expand('%:p') !~# '\m/\.git/' && line("'\"") > 1 && line("'\"") <= line("$") | exe "normal! g'\"" | endif
endif

" Exit terminal mode with <Esc><Esc>
tnoremap <Esc><Esc> <C-\><C-n>

" Disable auto comment on 'o' or 'O' new line
autocmd FileType * setlocal formatoptions-=o

" Help filetype detection
autocmd BufRead *.plot set filetype=gnuplot
autocmd BufRead *.md set filetype=markdown
autocmd BufRead *.tex set filetype=tex
autocmd BufRead *.rss set filetype=xml

" set ultisnips
" let g:UltiSnipsExpandTrigger = '<tab>'
" let g:UltiSnipsJumpForwardTrigger = '<tab>'
" let g:UltiSnipsJumpBackwardTrigger = '<s-tab>'
" let g:UltiSnipsSnippetDirectories=[$HOME.'/.config/nvim/UltiSnips']
" nnoremap <leader>cu :call<space>UltiSnips#RefreshSnippets()<CR>

" start clientserver
" if empty(v:servername) && exists('*remote_startserver')
"   call remote_startserver('VIM')
" endif

" configure vimtex
" let g:tex_flavor='latex'
" let g:vimtex_view_method='zathura'
" let g:vimtex_quickfix_mode=0
" set conceallevel=1
" let g:tex_conceal='abdmgs'
" nnoremap <leader>lc :VimtexStop<CR>:VimtexClean<CR>

