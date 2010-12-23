"=============================================================================
" FILE: help.vim
" AUTHOR: Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 23 Dec 2010.
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

" For echodoc."{{{
let s:doc_dict = {
      \ 'name' : 'vimshell',
      \ 'rank' : 10,
      \ 'filetypes' : { 'vimshell' : 1 },
      \ }
function! s:doc_dict.search(cur_text)"{{{
  " Get command name.
  let l:args = vimshell#get_current_args()
  if empty(l:args)
    return []
  endif
  let l:command = fnamemodify(l:args[0], ':t:r')

  let l:commands = vimshell#available_commands()
  if l:command == '' || !has_key(l:commands, l:command)
        \ || !has_key(l:commands[l:command], 'description')
    return []
  endif

  if l:commands[l:command].description =~# l:command.'\s*'
    return [
          \ { 'text' : l:command, 'highlight' : 'Identifier' },
          \ { 'text' : l:commands[l:command].description[len(l:command) :] },
          \ ]
  else
    return [
          \ { 'text' : l:commands[l:command].description },
          \ ]
  endif
endfunction"}}}
"}}}

function! vimshell#help#init()"{{{
  if exists('g:loaded_echodoc') && g:loaded_echodoc
    call echodoc#register('vimshell', s:doc_dict)
  endif
endfunction"}}}

" vim: foldmethod=marker
