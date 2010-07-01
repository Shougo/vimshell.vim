"=============================================================================
" FILE: term_mappings.vim
" AUTHOR: Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 01 Jul 2010
" License: MIT license  {{{
"     Permission is hereby granted, free of charge, to any person obtaining
"     a copy of this software and associated documentation files (the
"     "Software"), to deal in the Software without restriction, including
"     without limitation the rights to use, copy, modify, merge, publish,
"     distribute, sublicense, and/or sell copies of the Software, and to
"     permit persons to whom the Software is furnished to do so, subject to
"     the following conditions:
"
"     The above copyright notice and this permission notice shall be included
"     in all copies or substantial portions of the Software.
"
"     THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
"     OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
"     MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
"     IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
"     CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
"     TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
"     SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
" }}}
"=============================================================================

" Plugin key-mappings."{{{
nnoremap <silent> <Plug>(vimshell_term_interrupt)       :<C-u>call vimshell#interactive#hang_up(bufname('%'))<CR>
nnoremap <silent> <Plug>(vimshell_term_exit)       :<C-u>call <SID>exit()<CR>
inoremap <silent> <Plug>(vimshell_term_send_escape)       <C-o>:call vimshell#interactive#send_char(char2nr("\<ESC>"))<CR>
inoremap <silent> <Plug>(vimshell_term_send_string)       <C-o>:call <SID>send_string()<CR>
"}}}

function! vimshell#term_mappings#define_default_mappings()"{{{
  for l:lhs in [
        \ 'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm', 'n',
        \ 'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z',
        \ 'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 'N',
        \ 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z',
        \ '1', '2', '3', '4', '5', '6', '7', '8', '9', '0', 
        \ '!', '@', '#', '$', '^', '&', '*', '(', ')', '-', '_', '=', '+', '\', '`', '~', 
        \ '[', ']', '{', '}', ':', ';', '''', '"', ',', '<', '.', '>', '/', '?',
        \ ]

    execute 'inoremap <buffer><silent>' l:lhs printf('<ESC>:call vimshell#interactive#send_char(%s)<CR>', char2nr(l:lhs))
  endfor
  
  for [l:key, l:value] in items({
        \ '<C-a>' : "\<C-a>", '<C-b>' : "\<C-b>", '<C-c>' : "\<C-c>", '<C-d>' : "\<C-d>", '<C-e>' : "\<C-e>", '<C-f>' : "\<C-f>", '<C-g>' : "\<C-g>",
        \ '<C-h>' : "\<C-h>", '<C-i>' : "\<C-i>", '<C-j>' : "\<C-j>", '<C-k>' : "\<C-k>", '<C-l>' : "\<C-l>", '<C-m>' : "\<LF>", '<C-n>' : "\<C-n>",
        \ '<C-o>' : "\<C-o>", '<C-p>' : "\<C-p>", '<C-q>' : "\<C-q>", '<C-r>' : "\<C-r>", '<C-s>' : "\<C-s>", '<C-t>' : "\<C-t>", '<C-u>' : "\<C-u>",
        \ '<C-v>' : "\<C-v>", '<C-w>' : "\<C-w>", '<C-x>' : "\<C-x>", '<C-y>' : "\<C-y>", '<C-z>' : "\<C-z>",
        \ '<Home>' : "\<Home>", '<End>' : "\<End>", '<Del>' : "\<Del>", '<BS>' : "\<C-h>",
        \ '<Up>' : "\<ESC>[A", '<Down>' : "\<ESC>[B", '<Left>' : "\<ESC>[D", '<Right>' : "\<ESC>[C",
        \ '<Bar>' : '|', '<Space>' : ' ',
        \ })
    
    execute 'inoremap <buffer><silent>' l:key printf('<ESC>:call vimshell#interactive#send_char(%s)<CR>', char2nr(l:value))
  endfor
  
  if (exists('g:vimshell_no_default_keymappings') && g:vimshell_no_default_keymappings)
    return
  endif

  " Normal mode key-mappings.
  nmap <buffer> <C-c>     <Plug>(vimshell_term_interrupt)
  nmap <buffer> q         <Plug>(vimshell_term_exit)

  " Insert mode key-mappings.
  imap <buffer> <ESC><ESC>         <Plug>(vimshell_term_send_escape)
  imap <buffer> <C-Space>  <C-@>
  imap <buffer> <C-@>              <Plug>(vimshell_term_send_string)
endfunction"}}}

" vimshell interactive key-mappings functions.
function! s:exit()"{{{
  if !b:interactive.process.is_valid
    bdelete
  endif  
endfunction "}}}
function! s:send_string()"{{{
  let l:input = input('Please input send string: ')
  call vimshell#imdisable()
  if l:input != ''
    call vimshell#interactive#send_string(l:input)
  endif
endfunction "}}}

" vim: foldmethod=marker
