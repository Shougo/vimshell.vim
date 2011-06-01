"=============================================================================
" FILE: hook.vim
" AUTHOR: Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 01 Jun 2011.
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

function! vimshell#hook#call(hook_point, context, args)"{{{
  if !a:context.is_interactive || &filetype !=# 'vimshell'
    return
  endif

  let l:context = copy(a:context)
  let l:context.is_interactive = 0
  call vimshell#set_context(l:context)

  " Call hook function.
  try
    for Func in b:interactive.hook_functions_table[a:hook_point]
      call call(Func, [a:args, l:context], {})
    endfor
  catch
    " Error.
    call vimshell#error_line(a:context.fd, v:exception . ' ' . v:throwpoint)
  endtry
endfunction"}}}
function! vimshell#hook#call_filter(hook_point, context, args)"{{{
  if !a:context.is_interactive || &filetype !=# 'vimshell'
    return a:args
  endif

  let l:context = copy(a:context)
  let l:context.is_interactive = 0
  call vimshell#set_context(l:context)

  " Call hook function.
  let l:args = a:args
  try
    for Func in b:interactive.hook_functions_table[a:hook_point]
      let l:args = call(Func, [l:args, l:context], {})
    endfor
  catch
    " Error.
    call vimshell#error_line(a:context.fd, v:exception . ' ' . v:throwpoint)
    return l:args
  endtry

  return l:args
endfunction"}}}
function! vimshell#hook#set(hook_point, func_list)"{{{
  if !has_key(b:interactive.hook_functions_table, a:hook_point)
    throw 'Hook point "' . a:hook_point . '" is not supported.'
  endif

  let b:interactive.hook_functions_table[a:hook_point] = a:func_list
endfunction"}}}
function! vimshell#hook#get(hook_point)"{{{
  if !has_key(b:interactive.hook_functions_table, a:hook_point)
    throw 'Hook point "' . a:hook_point . '" is not supported.'
  endif

  return b:interactive.hook_functions_table[a:hook_point]
endfunction"}}}

" vim: foldmethod=marker
