"=============================================================================
" FILE: int_mappings.vim
" AUTHOR: Shougo Matsushita <Shougo.Matsu@gmail.com>(Modified)
" Last Modified: 25 May 2010
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
function! vimshell#int_mappings#delete_backword_char(is_auto_select)"{{{
  let l:prefix = pumvisible() ? (a:is_auto_select? "\<C-e>" : "\<C-y>") : ""
  " Prevent backspace over prompt
  if !has_key(b:interactive.prompt_history, line('.')) || getline('.')[: col('.')-2] !=# b:interactive.prompt_history[line('.')]
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

  " Disable input method.
  if exists('*eskk#is_enabled') && eskk#is_enabled()
    call feedkeys(eskk#disable(), 'n')
  elseif exists('b:skk_on') && b:skk_on
    call feedkeys(SkkDisable(), 'n')
  elseif exists('&iminsert')
    let &l:iminsert = 0
  endif
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

  if &termencoding != '' && &encoding != &termencoding
    " Convert encoding.
    let l:filename = iconv(l:filename, &encoding, &termencoding)
  endif

  " Execute cursor file.
  if l:filename =~ '^\%(https\?\|ftp\)://'
    " Open uri.
    call vimshell#open(l:filename)
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
function! vimshell#int_mappings#restart_command()"{{{
  if exists('b:interactive') && b:interactive.process.is_valid
    " Delete zombee process.
    call vimshell#interactive#force_exit()
  endif
  
  set modifiable
  " Clean up the screen.
  % delete _
  call vimshell#terminal#clear_highlight()
  
  " Initialize.
  let l:sub = vimproc#ptyopen(b:interactive.args)
  
  call vimshell#internal#iexe#default_settings()

  " Set variables.
  call extend(b:interactive, {
        \ 'process' : l:sub, 
        \ 'is_secret': 0, 
        \ 'prompt_history' : {}, 
        \ 'command_history' : [], 
        \ 'cached_output' : '', 
        \}, 'force')

  call vimshell#interactive#execute_pty_out(1)
  if getline(line('$')) =~ '^\s*$'
    let b:interactive.prompt_history[line('$')] = ''
    call setline(line('$'), '...')
  endif

  startinsert!
endfunction"}}}

" vim: foldmethod=marker
