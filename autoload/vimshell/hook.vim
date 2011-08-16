"=============================================================================
" FILE: hook.vim
" AUTHOR: Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 04 Jun 2011.
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
  " There are cases when this variable doesn't 
  " exist 
  " USE: 'b:interactive.is_close_immediately = 1' to replicate
  if !exists('b:interactive')
    return
  end

  if !a:context.is_interactive
        \ || !has_key(b:interactive, 'hook_functions_table')
        \ || !has_key(b:interactive.hook_functions_table, a:hook_point)
    return
  endif

  let l:context = copy(a:context)
  let l:context.is_interactive = 0
  call vimshell#set_context(l:context)

  " Call hook function.
  let l:table = b:interactive.hook_functions_table[a:hook_point]
  for key in sort(keys(l:table))
    call call(l:table[key], [a:args, l:context], {})
  endfor
endfunction"}}}
function! vimshell#hook#call_filter(hook_point, context, args)"{{{
  if !a:context.is_interactive
        \ || !has_key(b:interactive.hook_functions_table, a:hook_point)
    return a:args
  endif

  let l:context = copy(a:context)
  let l:context.is_interactive = 0
  call vimshell#set_context(l:context)

  " Call hook function.
  let l:args = a:args
  let l:table = b:interactive.hook_functions_table[a:hook_point]
  for key in sort(keys(l:table))
    let l:args = call(l:table[key], [l:args, l:context], {})
  endfor

  return l:args
endfunction"}}}
function! vimshell#hook#set(hook_point, func_list)"{{{
  if !has_key(b:interactive.hook_functions_table, a:hook_point)
    let b:interactive.hook_functions_table[a:hook_point] = {}
  endif

  let l:cnt = 1
  let b:interactive.hook_functions_table[a:hook_point] = {}
  for Func in a:func_list
    let b:interactive.hook_functions_table[a:hook_point][l:cnt] = Func

    let l:cnt += 1
  endfor
endfunction"}}}
function! vimshell#hook#get(hook_point)"{{{
  return get(b:interactive.hook_functions_table, a:hook_point, {})
endfunction"}}}
function! vimshell#hook#add(hook_point, hook_name, func)"{{{
  if !has_key(b:interactive.hook_functions_table, a:hook_point)
    let b:interactive.hook_functions_table[a:hook_point] = {}
  endif

  let b:interactive.hook_functions_table[a:hook_point][a:hook_name] = a:func
endfunction"}}}
function! vimshell#hook#remove(hook_point, hook_name)"{{{
  if !has_key(b:interactive.hook_functions_table, a:hook_point)
    let b:interactive.hook_functions_table[a:hook_point] = {}
  endif

  if has_key(b:interactive.hook_functions_table[a:hook_point], a:hook_name)
    call remove(b:interactive.hook_functions_table[a:hook_point], a:hook_name)
  endif
endfunction"}}}

" vim: foldmethod=marker
