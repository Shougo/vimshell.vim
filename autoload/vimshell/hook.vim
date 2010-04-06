"=============================================================================
" FILE: hook.vim
" AUTHOR: Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 06 Apr 2010
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

function! vimshell#hook#add(hook_point, func_name)"{{{
  if !has_key(b:vimshell.hook_functions_table, a:hook_point)
    throw 'Hook point "' . a:hook_point . '" is not supported.'
  endif
  
  let b:vimshell.hook_functions_table[a:hook_point][a:func_name] = a:func_name
endfunction"}}}
function! vimshell#hook#del(hook_point, func_name)"{{{
  if !has_key(b:vimshell.hook_functions_table, a:hook_point)
    throw 'Hook point "' . a:hook_point . '" is not supported.'
  endif
  if !has_key(b:vimshell.hook_functions_table[a:hook_point], a:func_name)
    throw 'Hook function "' . a:func_name . '" is not found.'
  endif
  
  call remove(b:vimshell.hook_functions_table[a:hook_point], a:func_name)
endfunction"}}}

" vim: foldmethod=marker
