"=============================================================================
" FILE: int_mappings.vim
" AUTHOR: Shougo Matsushita <Shougo.Matsu@gmail.com>(Modified)
" Last Modified: 26 Apr 2010
" License: MIT license  {{{
"     Permission is hereby granted, free of charge, to any person obtaining
"     a copy of this software and associated documentation files (the
"     "Software"), to deal in the Software without restriction, including
"     without limitation the rights to use, copy, modify, merge, publish,
"     distribute, sublicense, and/or sell copies of the Software, and to
"     permit persons to whom the Software is furnished to do so, subject to
"     the following conditionvimshell#int_mappings#
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

" vimshell interactive key-mappings functions.
function! vimshell#int_mappings#delete_backword_char()"{{{
  let l:prefix = pumvisible() ? "\<C-y>" : ""
  " Prevent backspace over prompt
  if !has_key(b:interactive.prompt_history, line('.')) || getline(line('.')) != b:interactive.prompt_history[line('.')]
    return l:prefix . "\<BS>"
  else
    return l:prefix
  endif
endfunction"}}}
function! vimshell#int_mappings#execute_history(is_insert)"{{{
  " Search prompt.
  if !has_key(b:interactive.prompt_history, line('.'))
    return
  endif

  let l:command = strpart(getline('.'), len(b:interactive.prompt_history[line('.')]))

  if !has_key(b:interactive.prompt_history, line('$'))
    " Insert prompt line.
    call append(line('$'), l:command)
  else
    " Set prompt line.
    call setline(line('$'), b:interactive.prompt_history[line('$')] . l:command)
  endif

  $

  call vimshell#interactive#execute_pty_inout(a:is_insert)
endfunction"}}}
function! vimshell#int_mappings#previous_prompt()"{{{
  let l:prompts = sort(filter(map(keys(b:interactive.prompt_history), 'str2nr(v:val)'), 'v:val < line(".")'), 'vimshell#compare_number')
  if !empty(l:prompts)
    execute ':'.l:prompts[-1]
  endif
endfunction"}}}
function! vimshell#int_mappings#next_prompt()"{{{
  let l:prompts = sort(filter(map(keys(b:interactive.prompt_history), 'str2nr(v:val)'), 'v:val > line(".")'), 'vimshell#compare_number')
  if !empty(l:prompts)
    execute ':'.l:prompts[0]
  endif
endfunction"}}}
function! vimshell#int_mappings#move_head()"{{{
  if !has_key(b:interactive.prompt_history, line('.'))
    return
  endif
  call search(vimshell#escape_match(b:interactive.prompt_history[line('.')]), 'be', line('.'))
  startinsert
endfunction"}}}
function! vimshell#int_mappings#delete_line()"{{{
  if !has_key(b:interactive.prompt_history, line('.'))
    return
  endif

  let l:col = col('.')
  let l:mcol = col('$')
  call setline(line('.'), b:interactive.prompt_history[line('.')] . getline('.')[l:col :])
  call vimshell#int_mappings#move_head()

  if l:col == l:mcol-1
    startinsert!
  endif
endfunction"}}}
function! vimshell#int_mappings#execute_line(is_insert)"{{{
  if has_key(b:interactive.prompt_history, line('.'))
    " Execute history.
    call vimshell#int_mappings#execute_history(a:is_insert)
    return
  endif

  " Search cursor file.
  let l:filename = substitute(substitute(expand('<cfile>'), ' ', '\\ ', 'g'), '\\', '/', 'g')
  if l:filename == ''
    return
  endif

  " Execute cursor file.
  if l:filename =~ '^\%(https\?\|ftp\)://'
    " Open uri.

    " Detect desktop environment.
    if vimshell#iswin()
      execute printf('silent ! start "" "%s"', l:filename)
    elseif has('mac')
      call system('open ' . l:filename . '&')
    elseif exists('$KDE_FULL_SESSION') && $KDE_FULL_SESSION ==# 'true'
      " KDE.
      call system('kfmclient exec ' . l:filename . '&')
    elseif exists('$GNOME_DESKTOP_SESSION_ID')
      " GNOME.
      call system('gnome-open ' . l:filename . '&')
    elseif executable(vimshell#getfilename('exo-open'))
      " Xfce.
      call system('exo-open ' . l:filename . '&')
    else
      throw 'Not supported.'
    endif
  endif
endfunction"}}}
function! vimshell#int_mappings#paste_prompt()"{{{
  if !has_key(b:interactive.prompt_history, line('.'))
    return
  endif

  " Set prompt line.
  let l:cur_text = vimshell#interactive#get_cur_line(line('.'))
  call setline(line('$'), vimshell#interactive#get_prompt(line('$')) . l:cur_text)
  $
endfunction"}}}
function! vimshell#int_mappings#close_popup()"{{{
  if !pumvisible()
    return ''
  endif

  if !exists('*neocomplcache#close_popup')
    let l:ret = neocomplcache#close_popup()
  else
    let l:ret = "\<C-y>"
  endif
  let l:ret .= "\<C-l>\<BS>"

  return l:ret
endfunction"}}}

" vim: foldmethod=marker
