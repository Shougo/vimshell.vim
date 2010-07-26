"=============================================================================
" FILE: interactive.vim
" AUTHOR:  Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 25 Jul 2010
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

let s:last_interactive_bufnr = 1

" Utility functions.

let s:password_regex = 
      \'\%(Enter \\|[Oo]ld \\|[Nn]ew \\|''s \\|login \\|'''  .
      \'Kerberos \|CVS \|UNIX \| SMB \|LDAP \|\[sudo] \|^\)' . 
      \'[Pp]assword\|\%(^\|\n\)[Pp]assword'
let s:character_regex = ''

augroup vimshell
  autocmd VimEnter * set vb t_vb=
  autocmd CursorHold * call s:check_all_output()
  autocmd BufWinEnter,WinEnter * call s:winenter(expand('<afile>'))
  autocmd BufWinLeave,WinLeave * call s:winleave(expand('<afile>'))
augroup END

command! -range -nargs=? VimShellSendString call s:send_region(<line1>, <line2>, <q-args>)
command! -complete=buffer -nargs=1 VimShellSendBuffer call vimshell#interactive#set_send_buffer(<q-args>)

" Dummy.
function! vimshell#interactive#init()"{{{
endfunction"}}}

function! vimshell#interactive#get_cur_text()"{{{
  " Get cursor text without prompt.
  return s:chomp_prompt(s:get_cur_text(), line('.'), b:interactive)
endfunction"}}}
function! vimshell#interactive#get_cur_line(line, ...)"{{{
  " Get cursor text without prompt.
  let l:interactive = a:0 > 0 ? a:1 : b:interactive
  return s:chomp_prompt(getline(a:line), a:line, l:interactive)
endfunction"}}}
function! vimshell#interactive#get_prompt(...)"{{{
  let l:line = a:0? a:1 : line('.')
  " Get prompt line.
  return !has_key(b:interactive.prompt_history, l:line) ? '' : b:interactive.prompt_history[l:line]
endfunction"}}}
function! s:get_cur_text()"{{{
  let l:pos = mode() ==# 'i' ? 2 : 1

  let l:cur_text = col('.') < l:pos ? '' : matchstr(getline('.'), '.*')[: col('.') - l:pos]
  
  return l:cur_text
endfunction"}}}
function! s:chomp_prompt(cur_text, line, interactive)"{{{
  let l:cur_text = a:cur_text
  
  if has_key(a:interactive.prompt_history, a:line)
    let l:cur_text = a:cur_text[len(a:interactive.prompt_history[a:line]) : ]
  endif

  return l:cur_text
endfunction"}}}

function! vimshell#interactive#execute_pty_inout(is_insert)"{{{
  if !b:interactive.process.is_valid
    return
  endif

  let l:in = vimshell#interactive#get_cur_line(line('.'))

  call vimshell#history#interactive_append(l:in)

  if b:interactive.encoding != '' && &encoding != b:interactive.encoding
    " Convert encoding.
    let l:in = iconv(l:in, &encoding, b:interactive.encoding)
  endif

  try
    let b:interactive.echoback_linenr = line('.')
    
    if l:in =~ "\<C-d>$"
      " EOF.
      call b:interactive.process.write(l:in[:-2] . (b:interactive.is_pty ? "\<C-z>" : "\<C-d>"))
      let b:interactive.skip_echoback = l:in[:-2]
      call vimshell#interactive#execute_pty_out(a:is_insert)

      call vimshell#interactive#exit()
      return
    else
      call b:interactive.process.write(l:in . "\<LF>")
    endif
  catch
    call vimshell#interactive#exit()
    return
  endtry

  call vimshell#interactive#execute_pty_out(a:is_insert)
  if !b:interactive.process.eof
    if a:is_insert
      startinsert!
    else
      normal! $
    endif
  endif
endfunction"}}}
function! vimshell#interactive#send_string(string)"{{{
  if !b:interactive.process.is_valid
    return
  endif

  setlocal modifiable
  
  let l:in = a:string

  if l:in != '' && b:interactive.type !=# 'terminal'
    call vimshell#history#interactive_append(l:in)
  endif

  if b:interactive.encoding != '' && &encoding != b:interactive.encoding
    " Convert encoding.
    let l:in = iconv(l:in, &encoding, b:interactive.encoding)
  endif

  try
    if l:in =~ "\<C-d>$"
      " EOF.
      call b:interactive.process.write(l:in[:-2] . (b:interactive.is_pty ? "\<C-z>" : "\<C-d>"))
      call vimshell#interactive#execute_pty_out(1)

      call vimshell#interactive#exit()
      return
    else
      call b:interactive.process.write(l:in)
    endif
  catch
    call vimshell#interactive#exit()
    return
  endtry

  call vimshell#interactive#execute_pty_out(1)
endfunction"}}}
function! vimshell#interactive#send_input()"{{{
  let l:input = input('Please input send string: ')
  call vimshell#imdisable()
  call vimshell#interactive#send_string(l:input)
endfunction"}}}
function! vimshell#interactive#send_char(char)"{{{
  if !b:interactive.process.is_valid
    return
  endif

  setlocal modifiable

  if type(a:char) != type([])
    let l:char = nr2char(a:char)
  else
    let l:char = ''
    for c in a:char
      let l:char .= nr2char(c)
    endfor
  endif
  
  call b:interactive.process.write(l:char)

  call vimshell#interactive#execute_pty_out(1)
endfunction"}}}
function! s:send_region(line1, line2, string)"{{{
  let l:winnr = bufwinnr(s:last_interactive_bufnr)
  if l:winnr <= 0
    return
  endif
  
  " Check alternate buffer.
  let l:type = getbufvar(winbufnr(l:winnr), 'interactive').type
  if l:type ==# 'interactive' || l:type ==# 'terminal'
    if a:string != ''
      let l:string = a:string . "\<LF>"
    else
      let l:string = join(getline(a:line1, a:line2), "\<LF>") . "\<LF>"
    endif
    let l:line = split(l:string, "\<LF>")[0]
    
    execute winnr('#') 'wincmd w'

    if l:type !=# 'terminal'
      " Save prompt.
      let l:prompt = vimshell#interactive#get_prompt(line('$'))
      let l:prompt_nr = line('$')
    endif
    
    " Send string.
    call vimshell#interactive#send_string(l:string)
    
    if l:type !=# 'terminal'
      call setline(l:prompt_nr, l:prompt . l:line)
    endif

    stopinsert
    wincmd p
  endif
endfunction"}}}
function! vimshell#interactive#set_send_buffer(bufname)"{{{
  let s:last_interactive_bufnr = bufnr(a:bufname)
  let l:winnr = bufwinnr(s:last_interactive_bufnr)
  if s:last_interactive_bufnr >= 0 && l:winnr <= 0
    " Open buffer.
    call vimshell#split_nicely()

    execute edit a:bufname
  endif
endfunction"}}}

function! vimshell#interactive#execute_pty_out(is_insert)"{{{
  if !b:interactive.process.is_valid
    return
  endif
  
  let l:outputed = 0

  " Check cache.
  if b:interactive.stdout_cache != ''
    let l:outputed = 1
    call s:print_buffer(b:interactive.fd, b:interactive.stdout_cache)
    let b:interactive.stdout_cache = ''
  endif
  
  if !b:interactive.process.eof
    let l:read = b:interactive.process.read(-1, 40)
    while l:read != ''
      let l:outputed = 1

      call s:print_buffer(b:interactive.fd, l:read)

      let l:read = b:interactive.process.read(-1, 40)
    endwhile
  endif

  if l:outputed && b:interactive.type !=# 'terminal'
    $
    if !b:interactive.process.eof
      if a:is_insert
        startinsert!
      else
        normal! $
      endif
    endif
  endif
  
  if b:interactive.process.eof
    call vimshell#interactive#exit()
  endif
endfunction"}}}

function! vimshell#interactive#execute_pipe_out()"{{{
  if !b:interactive.process.is_valid
    return
  endif

  " Check cache.
  if b:interactive.stdout_cache != ''
    call s:print_buffer(b:interactive.fd, b:interactive.stdout_cache)
    let b:interactive.stdout_cache = ''
  endif
  
  if !b:interactive.process.stdout.eof
    let l:read = b:interactive.process.stdout.read(-1, 40)
    while l:read != ''
      call s:print_buffer(b:interactive.fd, l:read)

      let l:read = b:interactive.process.stdout.read(-1, 40)
    endwhile
  endif

  " Check cache.
  if b:interactive.stderr_cache != ''
    call s:error_buffer(b:interactive.fd, b:interactive.stderr_cache)
    let b:interactive.stderr_cache = ''
  endif
  
  if !b:interactive.process.stderr.eof
    let l:read = b:interactive.process.stderr.read(-1, 40)
    while l:read != ''
      call s:error_buffer(b:interactive.fd, l:read)

      let l:read = b:interactive.process.stderr.read(-1, 40)
    endwhile
  endif
  
  if b:interactive.process.stdout.eof && b:interactive.process.stderr.eof
    call vimshell#interactive#exit()
  endif
endfunction"}}}

function! vimshell#interactive#exit()"{{{
  if !b:interactive.process.is_valid
    return
  endif

  " Get status.
  let [l:cond, l:status] = b:interactive.process.waitpid()
  if l:cond != 'exit'
    try
      " Kill process.
      " 15 == SIGTERM
      call sub.kill(15)
    catch
      " Ignore error.
    endtry
  endif

  let b:interactive.status = eval(l:status)
  if &filetype !=# 'vimshell'
    syn match   InteractiveMessage   '\*\%(Exit\|Killed\)\*'
    hi def link InteractiveMessage WarningMsg
    
    call append(line('$'), '*Exit*')
    
    $
    normal! $

    stopinsert
    setlocal nomodifiable
  endif
endfunction"}}}
function! vimshell#interactive#force_exit()"{{{
  if !b:interactive.process.is_valid
    return
  endif

  " Kill processes.
  try
    " 15 == SIGTERM
    call b:interactive.process.kill(15)
  catch
  endtry

  if &filetype !=# 'vimshell'
    syn match   InteractiveMessage   '\*\%(Exit\|Killed\)\*'
    hi def link InteractiveMessage WarningMsg
    
    setlocal modifiable
    
    call append(line('$'), '*Killed*')
    $
    normal! $
    
    stopinsert
    setlocal nomodifiable
  endif
endfunction"}}}
function! vimshell#interactive#hang_up(afile)"{{{
  if type(getbufvar(a:afile, 'interactive')) != type('')
    let l:vimproc = getbufvar(a:afile, 'interactive')
    if l:vimproc.process.is_valid
      " Kill process.
      try
        " 15 == SIGTERM
        call l:vimproc.process.kill(15)
      catch
      endtry
    endif
    
    if bufname('%') == a:afile && getbufvar(a:afile, '&filetype') !=# 'vimshell'
      syn match   InteractiveMessage   '\*\%(Exit\|Killed\)\*'
      hi def link InteractiveMessage WarningMsg
      
      setlocal modifiable
      
      call append(line('$'), '*Killed*')
      $
      normal! $

      stopinsert
      setlocal nomodifiable
    endif
  endif
endfunction"}}}

function! s:print_buffer(fd, string)"{{{
  if a:string == ''
    return
  endif

  if a:fd.stdout != ''
    if a:fd.stdout == '/dev/null'
      " Nothing.
    elseif a:fd.stdout == '/dev/clip'
      " Write to clipboard.
      let @+ .= a:string
    else
      " Write file.
      let l:file = extend(readfile(a:fd.stdout), split(a:string, '\r\n\|\n'))
      call writefile(l:file, a:fd.stdout)
    endif

    return
  endif

  " Convert encoding.
  let l:string = (b:interactive.encoding != '' && &encoding != b:interactive.encoding) ?
        \ iconv(a:string, b:interactive.encoding, &encoding) : a:string

  call vimshell#terminal#print(l:string)

  if getline('$') =~ s:password_regex
        \ && b:interactive.type == 'interactive'
    redraw

    " Password input.
    set imsearch=0
    let l:in = inputsecret('Input Secret : ')

    if b:interactive.encoding != '' && &encoding != b:interactive.encoding
      " Convert encoding.
      let l:in = iconv(l:in, &encoding, b:interactive.encoding)
    endif

    call b:interactive.process.write(l:in . "\<NL>")
  endif

  if has_key(b:interactive, 'prompt_history') && getline('$') != '' 
    let b:interactive.prompt_history[line('$')] = getline('$')
  endif
endfunction"}}}

function! s:error_buffer(fd, string)"{{{
  if a:string == ''
    return
  endif

  if a:fd.stderr != ''
    if a:fd.stderr == '/dev/null'
      " Nothing.
    elseif a:fd.stderr == '/dev/clip'
      " Write to clipboard.
      let @+ .= a:string
    else
      " Write file.
      let l:file = extend(readfile(a:fd.stderr), split(a:string, '\r\n\|\n'))
      call writefile(l:file, a:fd.stderr)
    endif

    return
  endif

  " Convert encoding.
  let l:string = (b:interactive.encoding != '' && &encoding != b:interactive.encoding) ?
        \ iconv(a:string, b:interactive.encoding, &encoding) : a:string

  " Print buffer.
  
  " Strip <CR>.
  let l:string = substitute(l:string, '\r\+\n', '\n', 'g')
  if l:string =~ '\r'
    for l:line in split(getline('$') . l:string, '\n', 1)
      call append('$', '')
      for l:l in split(l:line, '\r', 1)
        call setline('$', '!!!' . l:l . '!!!')
        redraw
      endfor
    endfor
  else
    let l:lines = split(l:string, '\n', 1)

    if l:lines[0] != ''
      let l:line = getline('$') =~ '!!!$' ?
            \ getline('$')[: -4] . l:lines[0] . '!!!' : getline('$') . '!!!' . l:lines[0] . '!!!'
      call setline('$', l:line)
    endif
    call append('$', map(l:lines[1:], 'v:val != "" ? "!!!" . v:val . "!!!" : v:val'))
  endif

  " Set cursor.
  $

  redraw
endfunction"}}}

" Autocmd functions.
function! vimshell#interactive#check_insert_output()"{{{
  if exists('b:interactive') && line('.') == line('$')
    call s:check_output(b:interactive, bufnr('%'), bufnr('%'))
    if exists('b:interactive') && !empty(b:interactive.process) && b:interactive.process.is_valid
      " Ignore key sequences.
      call feedkeys("\<C-r>\<ESC>", 'n')
    endif
  endif
endfunction"}}}
function! vimshell#interactive#check_moved_output()"{{{
  if exists('b:interactive') && line('.') == line('$')
    call s:check_output(b:interactive, bufnr('%'), bufnr('%'))
  endif
endfunction"}}}
function! s:check_all_output()"{{{
  let l:bufnr_save = bufnr('%')

  let l:bufnr = 1
  while l:bufnr <= bufnr('$')
    if bufexists(l:bufnr) && bufwinnr(l:bufnr) > 0 && type(getbufvar(l:bufnr, 'interactive')) != type('')
      " Check output.
      call s:check_output(getbufvar(l:bufnr, 'interactive'), l:bufnr, l:bufnr_save)
    endif

    let l:bufnr += 1
  endwhile
  
  if exists('b:interactive') && !empty(b:interactive.process) && b:interactive.process.is_valid
    " Ignore key sequences.
    call feedkeys("g\<ESC>", 'n')
  endif
endfunction"}}}
function! s:check_output(interactive, bufnr, bufnr_save)"{{{
  " Output cache.
  if !s:cache_output(a:interactive)
    return
  endif
  
  if a:bufnr != a:bufnr_save
    execute bufwinnr(a:bufnr) . 'wincmd w'
  endif

  if mode() !=# 'i'
    let l:intbuffer_pos = getpos('.')
    
    $
    normal! $
  endif

  let l:type = a:interactive.type
  if l:type ==# 'background'
    setlocal modifiable
    call vimshell#interactive#execute_pipe_out()
    setlocal nomodifiable
  elseif l:type ==# 'execute'
    call vimshell#parser#execute_continuation()
  else
    if l:type ==# 'terminal' && mode() !=# 'i'
      setlocal modifiable
    endif

    call vimshell#interactive#execute_pty_out(mode() ==# 'i')

    if l:type ==# 'terminal'
      setlocal nomodifiable
    elseif !a:interactive.process.eof && mode() ==# 'i'
      startinsert!
    endif
  endif

  if mode() !=# 'i'
    call setpos('.', l:intbuffer_pos)
  endif

  if a:bufnr != a:bufnr_save && bufexists(a:bufnr_save)
    execute bufwinnr(a:bufnr_save) . 'wincmd w'
  endif
endfunction"}}}
function! s:cache_output(interactive)"{{{
  if empty(a:interactive.process) || !a:interactive.process.is_valid
    return 0
  endif
  
  let l:outputed = 0
  if a:interactive.type ==# 'background' || a:interactive.type ==# 'execute'
    " Background.

    if a:interactive.process.stdout.eof
      let l:outputed = 1
    else
      let l:read = a:interactive.process.stdout.read(-1, 40)
      let a:interactive.stdout_cache = l:read
      while l:read != ''
        let l:outputed = 1

        let l:read = a:interactive.process.stdout.read(-1, 40)
        let a:interactive.stdout_cache .= l:read
      endwhile
    endif
    
    if a:interactive.process.stderr.eof
      let l:outputed = 1
    else
      let l:read = a:interactive.process.stderr.read(-1, 40)
      let a:interactive.stderr_cache = l:read
      while l:read != ''
        let l:outputed = 1
        
        let l:read = a:interactive.process.stderr.read(-1, 40)
        let a:interactive.stderr_cache .= l:read
      endwhile
    endif
  elseif a:interactive.type ==# 'terminal'
        \ || (a:interactive.type ==# 'interactive'
        \      && (line('.') == a:interactive.echoback_linenr
        \         || !has_key(a:interactive.prompt_history, line('.'))
        \         || vimshell#interactive#get_cur_line(line('.'), a:interactive) == ''))
    " Terminal or interactive.

    if a:interactive.process.eof
      let l:outputed = 1
    else
      let l:read = a:interactive.process.read(-1, 40)
      let a:interactive.stdout_cache = l:read
      while l:read != ''
        let l:outputed = 1

        let l:read = a:interactive.process.read(-1, 40)
        let a:interactive.stdout_cache .= l:read
      endwhile
    endif
  endif

  return l:outputed
endfunction"}}}

function! s:winenter(bufnr)"{{{
  if !exists('b:interactive')
    return
  endif
  
  call vimshell#terminal#set_title()
endfunction"}}}
function! s:winleave(bufnr)"{{{
  if !exists('b:interactive')
    return
  endif
  
  let s:last_interactive_bufnr = a:bufnr
  call vimshell#terminal#restore_title()
endfunction"}}}

" vim: foldmethod=marker
