"=============================================================================
" FILE: interactive.vim
" AUTHOR:  Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 02 Jun 2011.
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
      \'\%(Enter \|[Oo]ld \|[Nn]ew \|login '  .
      \'\|Kerberos \|CVS \|UNIX \| SMB \|LDAP \|\[sudo] ' .
      \'\|^\|\n\|''s \)[Pp]assword'
let s:character_regex = ''

augroup vimshell
  autocmd VimEnter * set vb t_vb=
  autocmd CursorHold * call s:check_all_output()
  autocmd BufWinEnter,WinEnter * call s:winenter()
  autocmd BufWinLeave,WinLeave * call s:winleave(expand('<afile>'))
augroup END

command! -range -nargs=? VimShellSendString call s:send_region(<line1>, <line2>, <q-args>)
command! -complete=buffer -nargs=1 VimShellSendBuffer call vimshell#interactive#set_send_buffer(<q-args>)

" Dummy.
function! vimshell#interactive#init()"{{{
endfunction"}}}

function! vimshell#interactive#get_cur_text()"{{{
  " Get cursor text without prompt.
  return s:chomp_prompt(vimshell#get_cur_line(), line('.'), b:interactive)
endfunction"}}}
function! vimshell#interactive#get_cur_line(line, ...)"{{{
  " Get cursor text without prompt.
  let l:interactive = a:0 > 0 ? a:1 : b:interactive
  return s:chomp_prompt(getline(a:line), a:line, l:interactive)
endfunction"}}}
function! vimshell#interactive#get_prompt(...)"{{{
  let l:line = a:0 ? a:1 : line('.')
  " Get prompt line.
  return !has_key(b:interactive.prompt_history, l:line) ? '' : b:interactive.prompt_history[l:line]
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

  call vimshell#history#append(l:in)
  let l:context = vimshell#get_context()
  let l:context.is_interactive = 1
  let l:in = vimshell#hook#call_filter('preinput', l:context, l:in)

  if b:interactive.encoding != '' && &encoding != b:interactive.encoding
    " Convert encoding.
    let l:in = iconv(l:in, &encoding, b:interactive.encoding)
  endif

  try
    let b:interactive.echoback_linenr = line('.')

    if l:in =~ "\<C-d>$"
      " EOF.
      let l:eof = (b:interactive.is_pty ? "\<C-d>" : "\<C-z>")

      call b:interactive.process.write(l:in[:-2] . l:eof)
      return
    else
      call b:interactive.process.write(l:in . "\<LF>")
    endif
  catch
    call vimshell#interactive#exit()
    return
  endtry

  call vimshell#interactive#execute_pty_out(a:is_insert)

  if has_key(b:interactive.process, 'eof') && !b:interactive.process.eof
    if a:is_insert
      startinsert!
    else
      normal! $
    endif

    let b:interactive.output_pos = getpos('.')
  endif

  " Call postinput hook.
  call vimshell#hook#call('postinput', l:context, l:in)
endfunction"}}}
function! vimshell#interactive#send_string(string)"{{{
  if !b:interactive.process.is_valid
    return
  endif

  setlocal modifiable

  let l:in = a:string

  if b:interactive.encoding != '' && &encoding != b:interactive.encoding
    " Convert encoding.
    let l:in = iconv(l:in, &encoding, b:interactive.encoding)
  endif

  try
    let b:interactive.echoback_linenr = line('$')

    if l:in =~ "\<C-d>$"
      " EOF.
      let l:eof = (b:interactive.is_pty ? "\<C-d>" : "\<C-z>")

      call b:interactive.process.write(l:in[:-2] . l:eof)
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
  let l:input = input('Please input send string: ', vimshell#interactive#get_cur_line(line('.')))
  call vimshell#imdisable()
  call setline('.', vimshell#interactive#get_prompt() . ' ')

  normal! $h
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
  if s:last_interactive_bufnr <= 0
    return
  endif

  let l:winnr = bufwinnr(s:last_interactive_bufnr)
  if l:winnr <= 0
    " Open buffer.
    call vimshell#split_nicely()

    edit `=a:bufname`
  endif

  " Check alternate buffer.
  let l:type = getbufvar(s:last_interactive_bufnr, 'interactive').type
  if l:type !=# 'interactive' && l:type !=# 'terminal'
        \ && l:type !=# 'vimshell'
    return
  endif

  let l:string = a:string
  if l:string == ''
    let l:string = join(getline(a:line1, a:line2), "\<LF>")
  endif
  let l:string .= "\<LF>"

  let l:save_winnr = winnr()
  execute l:winnr 'wincmd w'

  if l:type ==# 'interactive'
    " Save prompt.
    let l:prompt = vimshell#interactive#get_prompt(line('$'))
    let l:prompt_nr = line('$')
  endif

  " Send string.
  if l:type ==# 'vimshell'
    for l:line in split(l:string, "\<LF>")
      call vimshell#set_prompt_command(l:line)
      call vimshell#execute(l:line)
    endfor

    call vimshell#print_prompt()
  else
    call vimshell#interactive#send_string(l:string)
  endif

  if l:type ==# 'interactive'
        \ && b:interactive.process.is_valid
    call setline(l:prompt_nr, split(l:prompt . l:string, "\<LF>"))
  endif

  stopinsert
  execute l:save_winnr 'wincmd w'
endfunction"}}}
function! vimshell#interactive#set_send_buffer(bufname)"{{{
  let l:bufname = a:bufname == '' ? bufname('%') : a:bufname
  let s:last_interactive_bufnr = bufnr(l:bufname)
endfunction"}}}

function! vimshell#interactive#execute_pty_out(is_insert)"{{{
  if !b:interactive.process.is_valid
    return
  endif

  let l:outputed = 0

  " Check cache.
  if b:interactive.stdout_cache != ''
    let l:outputed = 1
    call vimshell#interactive#print_buffer(b:interactive.fd, b:interactive.stdout_cache)
    let b:interactive.stdout_cache = ''
  endif

  if !b:interactive.process.eof
    let l:read = b:interactive.process.read(1000, 40)
    while l:read != ''
      let l:outputed = 1

      call vimshell#interactive#print_buffer(b:interactive.fd, l:read)

      let l:read = b:interactive.process.read(1000, 40)
    endwhile
  endif

  if l:outputed && b:interactive.type !=# 'terminal'
    if !b:interactive.process.eof
      if a:is_insert
        startinsert!
      else
        normal! $
      endif
    endif

    let b:interactive.output_pos = getpos('.')
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
    call vimshell#interactive#print_buffer(b:interactive.fd, b:interactive.stdout_cache)
    let b:interactive.stdout_cache = ''
  endif

  if !b:interactive.process.stdout.eof
    let l:read = b:interactive.process.stdout.read(1000, 40)
    while l:read != ''
      call vimshell#interactive#print_buffer(b:interactive.fd, l:read)

      let l:read = b:interactive.process.stdout.read(1000, 40)
    endwhile
  endif

  " Check cache.
  if b:interactive.stderr_cache != ''
    call vimshell#interactive#error_buffer(b:interactive.fd, b:interactive.stderr_cache)
    let b:interactive.stderr_cache = ''
  endif

  if !b:interactive.process.stderr.eof
    let l:read = b:interactive.process.stderr.read(1000, 40)
    while l:read != ''
      call vimshell#interactive#error_buffer(b:interactive.fd, l:read)

      let l:read = b:interactive.process.stderr.read(1000, 40)
    endwhile
  endif

  if b:interactive.process.stdout.eof && b:interactive.process.stderr.eof
    call vimshell#interactive#exit()
  endif
endfunction"}}}

function! vimshell#interactive#quit_buffer()"{{{
  if !b:interactive.process.is_valid
    bdelete
  else
    call vimshell#echo_error('Process is running. Press <C-c> to kill process.')
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
      call sub.waitpid()
    catch
      " Ignore error.
    endtry
  endif

  let b:interactive.status = str2nr(l:status)
  let b:interactive.cond = l:cond
  if &filetype !=# 'vimshell'
    stopinsert

    if exists("b:interactive.is_close_immediately") && b:interactive.is_close_immediately
      " Close buffer immediately.
      bdelete
    else
      syn match   InteractiveMessage   '\*\%(Exit\|Killed\)\*'
      hi def link InteractiveMessage WarningMsg

      setlocal modifiable
      call append('$', '*Exit*')

      $
      normal! $

      setlocal nomodifiable
    endif
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
    call b:interactive.process.waitpid()
  catch
  endtry

  if &filetype !=# 'vimshell'
    syn match   InteractiveMessage   '\*\%(Exit\|Killed\)\*'
    hi def link InteractiveMessage WarningMsg

    setlocal modifiable

    call append('$', '*Killed*')
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
        call l:vimproc.process.waitpid()
      catch
      endtry
    endif
    let l:vimproc.process.is_valid = 0

    if bufname('%') == a:afile && getbufvar(a:afile, '&filetype') !=# 'vimshell'
      syn match   InteractiveMessage   '\*\%(Exit\|Killed\)\*'
      hi def link InteractiveMessage WarningMsg

      setlocal modifiable

      call append('$', '*Killed*')
      $
      normal! $

      stopinsert
      setlocal nomodifiable
    endif
  endif
endfunction"}}}
function! vimshell#interactive#decode_signal(signal)"{{{
  if a:signal == 2
    return 'SIGINT'
  elseif a:signal == 3
    return 'SIGQUIT'
  elseif a:signal == 4
    return 'SIGILL'
  elseif a:signal == 6
    return 'SIGABRT'
  elseif a:signal == 8
    return 'SIGFPE'
  elseif a:signal == 9
    return 'SIGKILL'
  elseif a:signal == 11
    return 'SIGSEGV'
  elseif a:signal == 13
    return 'SIGPIPE'
  elseif a:signal == 14
    return 'SIGALRM'
  elseif a:signal == 15
    return 'SIGTERM'
  elseif a:signal == 10
    return 'SIGUSR1'
  elseif a:signal == 12
    return 'SIGUSR2'
  elseif a:signal == 17
    return 'SIGCHLD'
  elseif a:signal == 18
    return 'SIGCONT'
  elseif a:signal == 19
    return 'SIGSTOP'
  elseif a:signal == 20
    return 'SIGTSTP'
  elseif a:signal == 21
    return 'SIGTTIN'
  elseif a:signal == 22
    return 'SIGTTOU'
  else
    return 'UNKNOWN'
  endif
endfunction"}}}

function! vimshell#interactive#print_buffer(fd, string)"{{{
  if a:string == '' || !exists('b:interactive')
    return
  endif

  if !empty(a:fd) && a:fd.stdout != ''
    return vimproc#write(a:fd.stdout, a:string, 'a')
  endif

  " Convert encoding.
  let l:string =
        \ (b:interactive.encoding != '' && &encoding != b:interactive.encoding) ?
        \ iconv(a:string, b:interactive.encoding, &encoding) : a:string

  call vimshell#terminal#print(l:string, 0)

  if getline('.') =~ s:password_regex
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

  let b:interactive.output_pos = getpos('.')

  if has_key(b:interactive, 'prompt_history') && line('.') != b:interactive.echoback_linenr && getline('.') != ''
    let b:interactive.prompt_history[line('.')] = getline('.')
  endif
endfunction"}}}
function! vimshell#interactive#error_buffer(fd, string)"{{{
  if a:string == '' || !exists('b:interactive')
    return
  endif

  if !empty(a:fd) && a:fd.stderr != ''
    return vimproc#write(a:fd.stderr, a:string)
  endif

  " Convert encoding.
  let l:string =
        \ (b:interactive.encoding != '' && &encoding != b:interactive.encoding) ?
        \ iconv(a:string, b:interactive.encoding, &encoding) : a:string

  " Print buffer.
  call vimshell#terminal#print(l:string, 1)

  let b:interactive.output_pos = getpos('.')

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
  if a:interactive.type ==# 'less' || !s:cache_output(a:interactive)
    return
  endif

  if a:bufnr != a:bufnr_save
    execute bufwinnr(a:bufnr) . 'wincmd w'
  endif

  let l:type = a:interactive.type

  if l:type ==# 'interactive' && (
        \ line('.') != a:interactive.echoback_linenr
        \ && vimshell#interactive#get_cur_line(line('.'), a:interactive) != ''
        \ )
    if a:bufnr != a:bufnr_save && bufexists(a:bufnr_save)
      execute bufwinnr(a:bufnr_save) . 'wincmd w'
    endif

    return
  endif

  if mode() !=# 'i' && l:type !=# 'vimshell'
    let l:intbuffer_pos = getpos('.')
  endif

  if has_key(a:interactive, 'output_pos')
    call setpos('.', a:interactive.output_pos)
  endif

  if l:type ==# 'background'
    setlocal modifiable
    call vimshell#interactive#execute_pipe_out()
    setlocal nomodifiable
  elseif l:type ==# 'vimshell'
    try
      call vimshell#parser#execute_continuation(mode() ==# 'i')
    catch
      " Error.
      call vimshell#error_line({}, v:exception . ' ' . v:throwpoint)
      let l:context = b:vimshell.continuation.context
      let b:vimshell.continuation = {}
      call vimshell#print_prompt(l:context)
      call vimshell#start_insert(mode() ==# 'i')
    endtry
  elseif l:type ==# 'interactive' || l:type ==# 'terminal'
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

  if mode() !=# 'i' && l:type !=# 'vimshell'
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
  if a:interactive.type ==# 'background' || a:interactive.type ==# 'vimshell'
    " Background.

    if a:interactive.process.stdout.eof
      let l:outputed = 1
    else
      let l:read = a:interactive.process.stdout.read(1000, 40)
      let a:interactive.stdout_cache = l:read
      while l:read != ''
        let l:outputed = 1

        let l:read = a:interactive.process.stdout.read(1000, 40)
        let a:interactive.stdout_cache .= l:read
      endwhile
    endif

    if a:interactive.process.stderr.eof
      let l:outputed = 1
    else
      let l:read = a:interactive.process.stderr.read(1000, 40)
      let a:interactive.stderr_cache = l:read
      while l:read != ''
        let l:outputed = 1

        let l:read = a:interactive.process.stderr.read(1000, 40)
        let a:interactive.stderr_cache .= l:read
      endwhile
    endif
  elseif a:interactive.type ==# 'terminal' || a:interactive.type ==# 'interactive'
    " Terminal or interactive.

    if a:interactive.process.eof
      let l:outputed = 1
    else
      let l:read = a:interactive.process.read(1000, 40)
      let a:interactive.stdout_cache = l:read
      while l:read != ''
        let l:outputed = 1

        let l:read = a:interactive.process.read(1000, 40)
        let a:interactive.stdout_cache .= l:read
      endwhile
    endif
  endif

  return l:outputed
endfunction"}}}

function! s:winenter()"{{{
  if !exists('b:interactive')
    return
  endif

  call vimshell#terminal#set_title()
endfunction"}}}
function! s:winleave(bufname)"{{{
  if !exists('b:interactive')
    return
  endif

  let s:last_interactive_bufnr = bufnr(a:bufname)
  call vimshell#terminal#restore_title()
endfunction"}}}

" vim: foldmethod=marker
