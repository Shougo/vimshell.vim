"=============================================================================
" FILE: int_mappings.vim
" AUTHOR: Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 28 Jun 2010
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
inoremap <silent> <Plug>(vimshell_int_previous_history)  <ESC>:<C-u>call <SID>previous_command()<CR>
inoremap <silent> <Plug>(vimshell_int_next_history)  <ESC>:<C-u>call <SID>next_command()<CR>
inoremap <silent> <Plug>(vimshell_int_move_head)  <ESC>:<C-u>call <SID>move_head()<CR>
inoremap <silent> <Plug>(vimshell_int_delete_line)  <ESC>:<C-u>call <SID>delete_line()<CR>
inoremap <expr> <Plug>(vimshell_int_delete_word)  <SID>delete_word()
inoremap <silent> <Plug>(vimshell_int_execute_line)       <C-g>u<ESC>:<C-u>call <SID>execute_line(1)<CR>
inoremap <silent> <Plug>(vimshell_int_interrupt)       <C-o>:<C-u>call vimshell#interactive#hang_up(bufname('%'))<CR>
inoremap <expr> <Plug>(vimshell_int_delete_backword_char)  <SID>delete_backword_char(0)
inoremap <expr> <Plug>(vimshell_int_another_delete_backword_char)  <SID>delete_backword_char(1)
inoremap <expr> <Plug>(vimshell_int_history_complete)  vimshell#complete#interactive_history_complete#complete()
inoremap <expr> <SID>(bs-ctrl-])    getline('.')[col('.') - 2] ==# "\<C-]>" ? "\<BS>" : ''

nnoremap <silent> <Plug>(vimshell_int_previous_prompt)  :<C-u>call <SID>previous_prompt()<CR>
nnoremap <silent> <Plug>(vimshell_int_next_prompt)  :<C-u>call <SID>next_prompt()<CR>
nnoremap <silent> <Plug>(vimshell_int_execute_line)  i<C-g>u<ESC>:<C-u>call <SID>execute_line(0)<CR><ESC>
nnoremap <silent> <Plug>(vimshell_int_paste_prompt)  :<C-u>call <SID>paste_prompt()<CR>
nnoremap <silent> <Plug>(vimshell_int_interrupt)       :<C-u>call vimshell#interactive#hang_up(bufname('%'))<CR>
nnoremap <silent> <Plug>(vimshell_int_exit)       :<C-u>call <SID>exit()<CR>
nnoremap <silent> <Plug>(vimshell_int_restart_command)       :<C-u>call <SID>restart_command()<CR>
nnoremap <expr> <Plug>(vimshell_int_change_line) printf('0%dlc$', strlen(vimshell#interactive#get_prompt()))
nmap  <Plug>(vimshell_int_delete_line) <Plug>(vimshell_int_change_line)<ESC>
"}}}

function! vimshell#int_mappings#define_default_mappings()"{{{
  if (exists('g:vimshell_no_default_keymappings') && g:vimshell_no_default_keymappings)
    return
  endif
  
  " Normal mode key-mappings.
  nmap <buffer> <C-p>     <Plug>(vimshell_int_previous_prompt)
  nmap <buffer> <C-n>     <Plug>(vimshell_int_next_prompt)
  nmap <buffer> <CR>      <Plug>(vimshell_int_execute_line)
  nmap <buffer> <C-y>     <Plug>(vimshell_int_paste_prompt)
  nmap <buffer> <C-z>     <Plug>(vimshell_int_restart_command)
  nmap <buffer> <C-c>     <Plug>(vimshell_int_interrupt)
  nmap <buffer> q         <Plug>(vimshell_int_exit)
  nmap <buffer> cc         <Plug>(vimshell_int_change_line)
  nmap <buffer> dd         <Plug>(vimshell_int_delete_line)
  nmap <buffer> I         <Plug>(vimshell_insert_head)
  nnoremap <buffer><silent> <Plug>(vimshell_insert_head)  :<C-u>call <SID>move_head()<CR>

  " Insert mode key-mappings.
  imap <buffer> <C-h>     <Plug>(vimshell_int_delete_backword_char)
  imap <buffer> <BS>     <Plug>(vimshell_int_delete_backword_char)
  imap <buffer><expr> <TAB>   pumvisible() ? "\<C-n>" : vimshell#complete#interactive_command_complete#complete()
  imap <buffer> <C-a>     <Plug>(vimshell_int_move_head)
  imap <buffer> <C-u>     <Plug>(vimshell_int_delete_line)
  imap <buffer> <C-w>     <Plug>(vimshell_int_delete_word)
  imap <buffer> <C-]>               <C-]><SID>(bs-ctrl-])
  imap <buffer> <CR>      <C-]><Plug>(vimshell_int_execute_line)
  imap <buffer> <C-c>     <Plug>(vimshell_int_interrupt)
  imap <buffer> <C-k>  <Plug>(vimshell_int_history_complete)
endfunction"}}}

" vimshell interactive key-mappings functions.
function! s:delete_backword_char(is_auto_select)"{{{
  let l:prefix = pumvisible() ? (a:is_auto_select? (
        \ exists('*neocomplcache#cancel_popup')? neocomplcache#cancel_popup() : "\<C-e>")
        \ : "\<C-y>") : ""
  " Prevent backspace over prompt
  if !has_key(b:interactive.prompt_history, line('.')) || getline('.')[: col('.')-2] !=# b:interactive.prompt_history[line('.')]
    return l:prefix . "\<BS>"
  else
    return l:prefix
  endif
endfunction"}}}
function! s:execute_history(is_insert)"{{{
  if !has_key(b:interactive.prompt_history, line('.'))
    " Do update.
    call vimshell#interactive#execute_pty_out(a:is_insert)
    return
  endif
  
  " Search prompt.
  let l:command = vimshell#interactive#get_cur_line(line('.'))

  if line('.') != line('$')
    if !has_key(b:interactive.prompt_history, line('$'))
      " Insert prompt line.
      call append(line('$'), l:command)
    else
      " Set prompt line.
      call setline(line('$'), b:interactive.prompt_history[line('$')] . l:command)
    endif
  endif

  $

  call vimshell#interactive#execute_pty_inout(a:is_insert)

  call vimshell#imdisable()
endfunction"}}}
function! s:previous_prompt()"{{{
  let l:prompts = sort(filter(map(keys(b:interactive.prompt_history), 'str2nr(v:val)'), 'v:val < line(".")'), 'vimshell#compare_number')
  if !empty(l:prompts)
    execute ':'.l:prompts[-1]
  endif
endfunction"}}}
function! s:next_prompt()"{{{
  let l:prompts = sort(filter(map(keys(b:interactive.prompt_history), 'str2nr(v:val)'), 'v:val > line(".")'), 'vimshell#compare_number')
  if !empty(l:prompts)
    execute ':'.l:prompts[0]
  endif
endfunction"}}}
function! s:move_head()"{{{
  if !has_key(b:interactive.prompt_history, line('.'))
    return
  endif
  
  call search(vimshell#escape_match(b:interactive.prompt_history[line('.')]), 'be', line('.'))
  if col('.') != col('$')-1
    normal! l
  endif
  
  startinsert
endfunction"}}}
function! s:delete_line()"{{{
  if !has_key(b:interactive.prompt_history, line('.'))
    return
  endif

  let l:col = col('.')
  let l:mcol = col('$')
  call setline(line('.'), b:interactive.prompt_history[line('.')] . getline('.')[l:col :])
  call s:move_head()

  if l:col == l:mcol-1
    startinsert!
  endif
endfunction"}}}
function! s:delete_word()"{{{
  return vimshell#interactive#get_cur_text()  == '' ? '' : "\<C-w>"
endfunction"}}}
function! s:execute_line(is_insert)"{{{
  " Search cursor file.
  let l:filename = substitute(substitute(expand('<cfile>'), ' ', '\\ ', 'g'), '\\', '/', 'g')

  if &termencoding != '' && &encoding != &termencoding
    " Convert encoding.
    let l:filename = iconv(l:filename, &encoding, &termencoding)
  endif

  " Execute cursor file.
  if l:filename =~ '^\%(https\?\|ftp\)://'
    " Open uri.
    call vimshell#open(l:filename)
  else
    " Execute history.
    call s:execute_history(a:is_insert)
  endif
endfunction"}}}
function! s:paste_prompt()"{{{
  if !has_key(b:interactive.prompt_history, line('.'))
    return
  endif

  " Set prompt line.
  let l:cur_text = vimshell#interactive#get_cur_line(line('.'))
  call setline(line('$'), vimshell#interactive#get_prompt(line('$')) . l:cur_text)
  $
endfunction"}}}
function! s:restart_command()"{{{
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
        \ 'echoback_linenr' : 0
        \}, 'force')

  call vimshell#interactive#execute_pty_out(1)

  startinsert!
endfunction"}}}
function! s:exit()"{{{
  if !b:interactive.process.is_valid
    bdelete
  endif  
endfunction "}}}

" vim: foldmethod=marker
