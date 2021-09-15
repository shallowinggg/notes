" basic config
set autoindent
set tabstop=4
set shiftwidth=4
set number
syntax on
set showcmd
set encoding=utf-8
set t_Co=256
set textwidth=80
set wrap
set linebreak
set  ruler
set laststatus=2
set showmatch
set hlsearch
"set spell spelllang=en_us
set autochdir
set clipboard=unnamed


call plug#begin('~/.vim/plugged')

" < Other Plugins, if they exist >
Plug 'Yggdroot/indentLine'
"Plug 'preservim/nerdtree'

" golang
Plug 'fatih/vim-go'
Plug 'neoclide/coc.nvim', {'branch': 'release'}

" erlang
Plug 'vim-erlang/vim-erlang-runtime'
Plug 'jimenezrick/vimerl'

" php
Plug '2072/PHP-Indenting-for-VIm'    " PHP indent script
Plug 'Yggdroot/indentLine'           " highlighting 4sp indenting
Plug 'chrisbra/Colorizer'            " colorize colors
Plug 'chriskempson/base16-vim'       " high quality colorschemes
Plug 'mhinz/vim-signify'             " show VCS changes
Plug 'sheerun/vim-polyglot'          " newer language support
Plug 'w0rp/ale'                      " realtime linting
" Code Analysis and Completion
Plug 'lvht/phpcd.vim', { 'for': 'php', 'do': 'composer install' }
Plug 'ternjs/tern_for_vim', { 'do': 'npm install' }
Plug 'Shougo/deoplete.nvim'          " async completion
Plug 'roxma/nvim-yarp'               " deoplete dependency
Plug 'roxma/vim-hug-neovim-rpc'      " deoplete dependency
" Other Features
Plug 'mileszs/ack.vim'               " ack/rg support
Plug 'mattn/emmet-vim'               " emmet support
Plug 'editorconfig/editorconfig-vim' " editorconfig support
Plug 'scrooloose/nerdtree'           " sidebar for browsing files

call plug#end()

" ----------
"  indentLine config
"  --------
let g:indent_guides_guide_size            = 1  " 指定对齐线的尺寸
let g:indent_guides_start_level           = 2  " 从第二层开始可视化显示缩进

let g:go_def_mode='gopls'
let g:go_info_mode='gopls'
autocmd BufWritePre *.go :call CocAction('runCommand', 'editor.action.organizeImport')

" -------------------------------------------------------------------------------------------------
" coc.nvim default settings
" -------------------------------------------------------------------------------------------------

" if hidden is not set, TextEdit might fail.
set hidden
" Better display for messages
set cmdheight=2
" Smaller updatetime for CursorHold & CursorHoldI
set updatetime=300
" don't give |ins-completion-menu| messages.
set shortmess+=c
" always show signcolumns
set signcolumn=yes

" Use tab for trigger completion with characters ahead and navigate.
" Use command ':verbose imap <tab>' to make sure tab is not mapped by other plugin.
inoremap <silent><expr> <TAB>
      \ pumvisible() ? "\<C-n>" :
      \ <SID>check_back_space() ? "\<TAB>" :
      \ coc#refresh()
inoremap <expr><S-TAB> pumvisible() ? "\<C-p>" : "\<C-h>"

function! s:check_back_space() abort
  let col = col('.') - 1
  return !col || getline('.')[col - 1]  =~# '\s'
endfunction

" Use <c-space> to trigger completion.
inoremap <silent><expr> <c-space> coc#refresh()

" Use `[c` and `]c` to navigate diagnostics
nmap <silent> [c <Plug>(coc-diagnostic-prev)
nmap <silent> ]c <Plug>(coc-diagnostic-next)

" Remap keys for gotos
nmap <silent> gd <Plug>(coc-definition)
nmap <silent> gy <Plug>(coc-type-definition)
nmap <silent> gi <Plug>(coc-implementation)
nmap <silent> gr <Plug>(coc-references)

" Use U to show documentation in preview window
nnoremap <silent> U :call <SID>show_documentation()<CR>

" Remap for rename current word
nmap <leader>rn <Plug>(coc-rename)

" Remap for format selected region
vmap <leader>f  <Plug>(coc-format-selected)
nmap <leader>f  <Plug>(coc-format-selected)
" Show all diagnostics
nnoremap <silent> <space>a  :<C-u>CocList diagnostics<cr>
" Manage extensions
nnoremap <silent> <space>e  :<C-u>CocList extensions<cr>
" Show commands
nnoremap <silent> <space>c  :<C-u>CocList commands<cr>
" Find symbol of current document
nnoremap <silent> <space>o  :<C-u>CocList outline<cr>
" Search workspace symbols
nnoremap <silent> <space>s  :<C-u>CocList -I symbols<cr>
" Do default action for next item.
nnoremap <silent> <space>j  :<C-u>CocNext<CR>
" Do default action for previous item.
nnoremap <silent> <space>k  :<C-u>CocPrev<CR>
" Resume latest coc list
nnoremap <silent> <space>p  :<C-u>CocListResume<CR>

" disable vim-go :GoDef short cut (gd)
" this is handled by LanguageClient [LC]
let g:go_def_mapping_enabled = 0

