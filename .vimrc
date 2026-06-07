" =============================================================================
" .vimrc — Sumit's vim config
" Symlinked from ~/Downloads/Claude/dotfiles/.vimrc
"
" After first install (or any time you change the plugin list below):
"   :PlugInstall      install / update missing plugins
"   :PlugUpdate       update all plugins
"   :PlugClean        remove unused
" =============================================================================

" -- Sensible defaults --------------------------------------------------------
set nocompatible                 " behave like vim, not vi
syntax on                        " syntax highlighting
filetype plugin indent on        " filetype detection + per-filetype indent/plugins
set encoding=utf-8

" -- Display ------------------------------------------------------------------
set number                       " absolute line numbers
" set relativenumber             " uncomment for hybrid mode (other lines show distance from cursor)
set cursorline                   " highlight current line
set showmatch                    " highlight matching brackets
set laststatus=2                 " always show status line
set ruler                        " show cursor position
set termguicolors                " 24-bit color
set background=dark
set scrolloff=8                  " keep 8 lines visible above/below cursor
set sidescrolloff=8
set signcolumn=yes               " always show sign column (no shift when gitgutter appears)
set list                         " show invisible characters
set listchars=tab:▸\ ,trail:·,extends:»,precedes:«,nbsp:␣

" -- Editing ------------------------------------------------------------------
set autoindent
set smartindent
set expandtab                    " spaces, not tabs
set tabstop=2
set softtabstop=2
set shiftwidth=2
set smarttab
set backspace=indent,eol,start
set hidden                       " allow unsaved buffers in background
set mouse=a
set clipboard=unnamed            " use system clipboard
set ttimeoutlen=50               " faster escape from insert mode

" -- Search -------------------------------------------------------------------
set incsearch                    " show match as you type
set hlsearch                     " highlight all matches
set ignorecase
set smartcase                    " case-sensitive if query has uppercase

" -- Completion ---------------------------------------------------------------
set wildmenu
set wildmode=longest:full,full
set completeopt=menuone,longest,noselect

" -- Files / undo -------------------------------------------------------------
set nobackup
set noswapfile
set undofile
set undodir=~/.vim/undo
if !isdirectory($HOME."/.vim/undo")
  call mkdir($HOME."/.vim/undo", "p", 0700)
endif

" -- Performance --------------------------------------------------------------
set updatetime=300
set lazyredraw

" =============================================================================
" Plugins (vim-plug) — install with :PlugInstall
" =============================================================================
" install.sh installs vim-plug to ~/.vim/autoload/plug.vim and runs :PlugInstall
" automatically. This block is guarded so vim still works if plug isn't there.

if filereadable(expand('~/.vim/autoload/plug.vim'))
  call plug#begin('~/.vim/plugged')

  " Saner defaults
  Plug 'tpope/vim-sensible'

  " Massive language pack — syntax + filetype for ~700 file types
  Plug 'sheerun/vim-polyglot'

  " Status line
  Plug 'vim-airline/vim-airline'
  Plug 'vim-airline/vim-airline-themes'

  " Git
  Plug 'tpope/vim-fugitive'        " :Git, :Gdiff, :Gblame, ...
  Plug 'airblade/vim-gitgutter'    " +/- markers in sign column

  " Editing helpers
  Plug 'tpope/vim-commentary'      " gcc to toggle line comment
  Plug 'tpope/vim-surround'        " cs"' to change "..." to '...'
  Plug 'tpope/vim-repeat'          " . works for the above
  Plug 'jiangmiao/auto-pairs'      " auto-close brackets/quotes

  " Indent visualization
  Plug 'Yggdroot/indentLine'

  " Color schemes
  Plug 'morhetz/gruvbox'
  Plug 'dracula/vim', { 'as': 'dracula' }

  call plug#end()
endif

" -- Color scheme -------------------------------------------------------------
silent! colorscheme gruvbox

" -- Airline ------------------------------------------------------------------
let g:airline_powerline_fonts = 1   " requires MesloLGS NF (you have it)
let g:airline_theme = 'gruvbox'
let g:airline#extensions#tabline#enabled = 1

" -- GitGutter ----------------------------------------------------------------
let g:gitgutter_max_signs = 500
set updatetime=300

" -- indentLine ---------------------------------------------------------------
let g:indentLine_char = '│'
let g:indentLine_color_term = 239

" =============================================================================
" Key mappings
" =============================================================================
let mapleader = ","

" Clear search highlight
nnoremap <silent> <leader><space> :nohlsearch<CR>

" Quick save / quit
nnoremap <leader>w :w<CR>
nnoremap <leader>q :q<CR>
nnoremap <leader>x :x<CR>

" Buffer navigation
nnoremap <C-h> :bprevious<CR>
nnoremap <C-l> :bnext<CR>
nnoremap <leader>bd :bdelete<CR>

" Reload .vimrc
nnoremap <leader>sv :source $MYVIMRC<CR>

" Window navigation
nnoremap <C-J> <C-W><C-J>
nnoremap <C-K> <C-W><C-K>

" Stay in visual mode after indent
vnoremap < <gv
vnoremap > >gv

" Yank to end of line (consistent with C, D)
nnoremap Y y$
