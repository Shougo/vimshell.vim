"=============================================================================
" FILE: hook.vim
" AUTHOR: Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 15 Jun 2010
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

function! vimshell#hook#call(hook_point, context, ...)"{{{
  if !a:context.is_interactive
    return
  endif
  
  let l:context = copy(a:context)
  let l:context.is_interactive = 0
  call vimshell#set_context(l:context)
  
  let l:args = (a:0 == 0)? {} : a:1
  
  " Call hook function.
  for l:func_name in b:vimshell.hook_functions_table[a:hook_point]
    call call(l:func_name, [l:args, l:context])
  endfor
endfunction"}}}
function! vimshell#hook#call_filter(hook_point, context, arg)"{{{
  if !a:context.is_interactive
    return a:arg
  endif

  let l:context = copy(a:context)
  let l:context.is_interactive = 0
  call vimshell#set_context(l:context)

  " Call hook function.
  let l:arg = a:arg
  for l:func_name in b:vimshell.hook_functions_table[a:hook_point]
    let l:arg = call(l:func_name, [l:arg, l:context])
  endfor

  return l:arg
endfunction"}}}
function! vimshell#hook#set(hook_point, func_list)"{{{
  if !has_key(b:vimshell.hook_functions_table, a:hook_point)
    throw 'Hook point "' . a:hook_point . '" is not supported.'
  endif
  
  let b:vimshell.hook_functions_table[a:hook_point] = a:func_list
endfunction"}}}
function! vimshell#hook#get(hook_point)"{{{
  if !has_key(b:vimshell.hook_functions_table, a:hook_point)
    throw 'Hook point "' . a:hook_point . '" is not supported.'
  endif
  
  return b:vimshell.hook_functions_table[a:hook_point]
endfunction"}}}

" vim: foldmethod=marker
