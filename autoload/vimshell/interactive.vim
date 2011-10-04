"=============================================================================
" FILE: interactive.vim
" AUTHOR:  Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 04 Oct 2011.
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
  if !exists('b:interactive')
    return vimshell#get_cur_line()
  endif

  " Get cursor text without prompt.
  return s:chomp_prompt(vimshell#get_cur_line(), line('.'), b:interactive)
endfunction"}}}
function! vimshell#interactive#get_cur_line(line, ...)"{{{
  " Get cursor text without prompt.
  let interactive = a:0 > 0 ? a:1 : b:interactive
  let cur_line = getline(a:line)

  return s:chomp_prompt(cur_line, a:line, interactive)
endfunction"}}}
function! vimshell#interactive#get_prompt(...)"{{{
  let line = a:0 ? a:1 : line('.')
  " Get prompt line.
  return !has_key(b:interactive.prompt_history, line) ?
        \ '' : b:interactive.prompt_history[line]
endfunction"}}}
function! s:chomp_prompt(cur_text, line, interactive)"{{{
  let cur_text = a:cur_text

  if has_key(a:interactive.prompt_history, a:line)
    let cur_text = cur_text[len(a:interactive.prompt_history[a:line]) : ]
  endif

  return cur_text
endfunction"}}}

function! vimshell#interactive#execute_pty_inout(is_insert)"{{{
  let in = vimshell#interactive#get_cur_line(line('.'))
  call vimshell#history#append(in)
  if in !~ "\<C-d>$"
    let in .= "\<LF>"
  endif

  call s:send_string(in, a:is_insert, line('.'))
endfunction"}}}
function! vimshell#interactive#send_string(string, is_insert)"{{{
  call s:send_string(a:string, 1, line('$'))
endfunction"}}}
function! vimshell#interactive#send_input()"{{{
  let input = input('Please input send string: ', vimshell#interactive#get_cur_line(line('.')))
  call vimshell#imdisable()
  call setline('.', vimshell#interactive#get_prompt() . ' ')

  normal! $h
  call vimshell#interactive#send_string(input, 1)
endfunction"}}}
function! vimshell#interactive#send_char(char)"{{{
  if !b:interactive.process.is_valid
    return
  endif

  setlocal modifiable

  if type(a:char) != type([])
    let char = nr2char(a:char)
  else
    let char = ''
    for c in a:char
      let char .= nr2char(c)
    endfor
  endif

  call b:interactive.process.stdin.write(char)

  call vimshell#interactive#execute_process_out(1)
endfunction"}}}
function! s:send_region(line1, line2, string)"{{{
  if s:last_interactive_bufnr <= 0 || vimshell#is_cmdwin()
    return
  endif

  let winnr = bufwinnr(s:last_interactive_bufnr)
  if winnr <= 0
    " Open buffer.
    let [new_pos, old_pos] = vimshell#split(g:vimshell_split_command)

    execute 'buffer' s:last_interactive_bufnr
  else
    let [new_pos, old_pos] = vimshell#split('')
    execute winnr 'wincmd w'
  endif

  let [new_pos[2], new_pos[3]] = [bufnr('%'), getpos('.')]

  " Check alternate buffer.
  let type = getbufvar(s:last_interactive_bufnr, 'interactive').type
  if type !=# 'interactive' && type !=# 'terminal'
        \ && type !=# 'vimshell'
    return
  endif

  let string = a:string
  if string == ''
    let string = join(getline(a:line1, a:line2), "\<LF>")
  endif
  let string .= "\<LF>"

  if type ==# 'interactive'
    " Save prompt.
    let prompt = vimshell#interactive#get_prompt(line('$'))
    let prompt_nr = line('$')
  endif

  " Send string.
  if type ==# 'vimshell'
    for line in split(string, "\<LF>")
      call vimshell#set_prompt_command(line)
      call vimshell#execute(line)
    endfor

    call vimshell#print_prompt()
  else
    call vimshell#interactive#send_string(string, mode() ==# 'i')
  endif

  if type ==# 'interactive'
        \ && b:interactive.process.is_valid
    call setline(prompt_nr, split(prompt . string, "\<LF>"))
  endif

  stopinsert
  call vimshell#restore_pos(old_pos)
endfunction"}}}
function! s:send_string(string, is_insert, linenr)"{{{
  if !b:interactive.process.is_valid
    return
  endif

  setlocal modifiable

  let in = a:string

  let context = vimshell#get_context()
  let context.is_interactive = 1

  let in = vimshell#hook#call_filter('preinput', context, in)

  if b:interactive.encoding != '' && &encoding != b:interactive.encoding
    " Convert encoding.
    let in = iconv(in, &encoding, b:interactive.encoding)
  endif

  try
    let b:interactive.echoback_linenr = a:linenr

    if in =~ "\<C-d>$"
      " EOF.
      let eof = (b:interactive.is_pty ? "\<C-d>" : "\<C-z>")

      call b:interactive.process.stdin.write(in[:-2] . eof)
    else
      call b:interactive.process.stdin.write(in)
    endif
  catch
    " Error.
    call vimshell#error_line({}, v:exception . ' ' . v:throwpoint)
    call vimshell#interactive#exit()
  endtry

  call vimshell#interactive#execute_process_out(a:is_insert)

  call s:set_output_pos(a:is_insert)

  " Call postinput hook.
  call vimshell#hook#call('postinput', context, in)
endfunction"}}}
function! vimshell#interactive#set_send_buffer(bufname)"{{{
  let bufname = a:bufname == '' ? bufname('%') : a:bufname
  let s:last_interactive_bufnr = bufnr(bufname)
endfunction"}}}

function! vimshell#interactive#execute_process_out(is_insert)"{{{
  if !b:interactive.process.is_valid
    return
  endif

  " Check cache.
  let read = b:interactive.stderr_cache
  if !b:interactive.process.stderr.eof
    let read .= b:interactive.process.stderr.read(10000, 0)
  endif
  call vimshell#interactive#error_buffer(b:interactive.fd, read)
  let b:interactive.stderr_cache = ''

  " Check cache.
  let read = b:interactive.stdout_cache
  if !b:interactive.process.stdout.eof
    let read .= b:interactive.process.stdout.read(10000, 0)
  endif
  call vimshell#interactive#print_buffer(b:interactive.fd, read)
  let b:interactive.stdout_cache = ''

  call s:set_output_pos(a:is_insert)

  if b:interactive.process.stdout.eof && b:interactive.process.stderr.eof
    call vimshell#interactive#exit()
  endif
endfunction"}}}
function! s:set_output_pos(is_insert)"{{{
  " There are cases when this variable doesn't exist
  " USE: 'b:interactive.is_close_immediately = 1' to replicate
  if !exists('b:interactive')
    return
  end

  if b:interactive.type !=# 'terminal' &&
        \ has_key(b:interactive.process, 'stdout')
        \ && (!b:interactive.process.stdout.eof ||
        \     !b:interactive.process.stderr.eof)
    if a:is_insert
      startinsert!
    else
      normal! $
    endif
    let b:interactive.output_pos = getpos('.')
  endif

  if a:is_insert && exists('*neocomplcache#is_enabled') && neocomplcache#is_enabled()
    " If response delays, so you have to close popup manually.
    call neocomplcache#close_popup()
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
  let [cond, status] = b:interactive.process.waitpid()
  if cond != 'exit'
    try
      " Kill process.
      " 15 == SIGTERM
      call b:interactive.process.kill(15)
      call b:interactive.process.waitpid()
    catch
      " Error.
      call vimshell#error_line({}, v:exception . ' ' . v:throwpoint)
      call vimshell#interactive#exit()
    endtry
  endif

  let b:interactive.status = str2nr(status)
  let b:interactive.cond = cond
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
    " Error.
    call vimshell#error_line({}, v:exception . ' ' . v:throwpoint)
    call vimshell#interactive#exit()
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
    let vimproc = getbufvar(a:afile, 'interactive')
    if vimproc.process.is_valid
      " Kill process.
      try
        " 15 == SIGTERM
        call vimproc.process.kill(15)
        call vimproc.process.waitpid()
      catch
        " Error.
        call vimshell#error_line({}, v:exception . ' ' . v:throwpoint)
        call vimshell#interactive#exit()
      endtry
    endif
    let vimproc.process.is_valid = 0

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
  let string =
        \ (b:interactive.encoding != '' && &encoding != b:interactive.encoding) ?
        \ iconv(a:string, b:interactive.encoding, &encoding) : a:string

  call vimshell#terminal#print(string, 0)

  if (getline('.') =~ s:password_regex
        \ || a:string =~ s:password_regex)
        \ && (b:interactive.type == 'interactive'
        \     || b:interactive.type == 'vimshell')
    redraw

    " Password input.
    set imsearch=0
    let in = inputsecret('Input Secret : ')

    if b:interactive.encoding != '' && &encoding != b:interactive.encoding
      " Convert encoding.
      let in = iconv(in, &encoding, b:interactive.encoding)
    endif

    call b:interactive.process.stdin.write(in . "\<NL>")
  endif

  let b:interactive.output_pos = getpos('.')

  if has_key(b:interactive, 'prompt_history')
        \ && line('.') != b:interactive.echoback_linenr && getline('.') != ''
    let b:interactive.prompt_history[line('.')] = getline('.')
  endif
endfunction"}}}
function! vimshell#interactive#error_buffer(fd, string)"{{{
  if a:string == ''
    return
  endif

  if !exists('b:interactive')
    echohl WarningMsg | echomsg a:string | echohl None
    return
  endif

  if !empty(a:fd) && a:fd.stderr != ''
    return vimproc#write(a:fd.stderr, a:string)
  endif

  " Convert encoding.
  let string =
        \ (b:interactive.encoding != '' && &encoding != b:interactive.encoding) ?
        \ iconv(a:string, b:interactive.encoding, &encoding) : a:string

  " Print buffer.
  call vimshell#terminal#print(string, 1)

  let b:interactive.output_pos = getpos('.')

  redraw

  if has_key(b:interactive, 'prompt_history')
        \ && line('.') != b:interactive.echoback_linenr && getline('.') != ''
    let b:interactive.prompt_history[line('.')] = getline('.')
  endif
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
  let bufnr_save = bufnr('%')

  let bufnr = 1
  while bufnr <= bufnr('$')
    if bufexists(bufnr) && bufwinnr(bufnr) > 0 && type(getbufvar(bufnr, 'interactive')) != type('')
      " Check output.
      call s:check_output(getbufvar(bufnr, 'interactive'), bufnr, bufnr_save)
    endif

    let bufnr += 1
  endwhile

  if exists('b:interactive') && !empty(b:interactive.process) && b:interactive.process.is_valid
    " Ignore key sequences.
    call feedkeys("g\<ESC>", 'n')
  endif
endfunction"}}}
function! s:check_output(interactive, bufnr, bufnr_save)"{{{
  " Output cache.
  if a:interactive.type ==# 'less' || !s:cache_output(a:interactive)
        \ || vimshell#is_cmdwin()
    return
  endif

  if a:bufnr != a:bufnr_save
    execute bufwinnr(a:bufnr) . 'wincmd w'
  endif

  let type = a:interactive.type

  if type ==# 'interactive' && (
        \ line('.') != a:interactive.echoback_linenr
        \ && vimshell#interactive#get_cur_line(line('.'), a:interactive) != ''
        \ )
    if a:bufnr != a:bufnr_save && bufexists(a:bufnr_save)
      execute bufwinnr(a:bufnr_save) . 'wincmd w'
    endif

    return
  endif

  if mode() !=# 'i' && type !=# 'vimshell'
    let intbuffer_pos = getpos('.')
  endif

  if has_key(a:interactive, 'output_pos')
    call setpos('.', a:interactive.output_pos)
  endif

  let is_insert = mode() ==# 'i'

  if type ==# 'background'
    setlocal modifiable
    call vimshell#interactive#execute_process_out(is_insert)
    setlocal nomodifiable
  elseif type ==# 'vimshell'
    try
      call vimshell#parser#execute_continuation(is_insert)
    catch
      " Error.
      call vimshell#error_line({}, v:exception . ' ' . v:throwpoint)
      let context = vimshell#get_context()
      let b:vimshell.continuation = {}
      call vimshell#print_prompt(context)
      call vimshell#start_insert(is_insert)
    endtry
  elseif type ==# 'interactive' || type ==# 'terminal'
    setlocal modifiable

    call vimshell#interactive#execute_process_out(is_insert)

    if type ==# 'terminal'
      setlocal nomodifiable
    elseif (!a:interactive.process.stdout.eof || !a:interactive.process.stderr.eof)
          \ && is_insert
      startinsert!
    endif
  endif

  if !is_insert && type !=# 'vimshell'
    call setpos('.', intbuffer_pos)
  endif

  if a:bufnr != a:bufnr_save && bufexists(a:bufnr_save)
    execute bufwinnr(a:bufnr_save) . 'wincmd w'
  endif
endfunction"}}}
function! s:cache_output(interactive)"{{{
  if empty(a:interactive.process) || !a:interactive.process.is_valid
    return 0
  endif

  let outputed = 0
  if a:interactive.process.stdout.eof
    let outputed = 1
  else
    let read = a:interactive.process.stdout.read(10000, 0)
    if read != ''
      let outputed = 1
    endif
    let a:interactive.stdout_cache = read
  endif

  if a:interactive.process.stderr.eof
    let outputed = 1
  else
    let read = a:interactive.process.stderr.read(10000, 0)
    if read != ''
      let outputed = 1
    endif
    let a:interactive.stderr_cache = read
  endif

  return outputed
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
