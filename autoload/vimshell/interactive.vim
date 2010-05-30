"=============================================================================
" FILE: interactive.vim
" AUTHOR:  Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 30 May 2010
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

" Utility functions.

function! s:SID_PREFIX()
  return matchstr(expand('<sfile>'), '<SNR>\d\+_\zeSID_PREFIX$')
endfunction

let s:password_regex = 
      \'\%(Enter \\|[Oo]ld \\|[Nn]ew \\|''s \\|login \\|'''  .
      \'Kerberos \|CVS \|UNIX \| SMB \|LDAP \|\[sudo] \|^\)' . 
      \'[Pp]assword\|\%(^\|\n\)[Pp]assword'
let s:character_regex = ''

augroup VimShellInteractive
  autocmd!
  autocmd CursorHold * call s:check_all_output()
augroup END

function! vimshell#interactive#get_cur_text()"{{{
  " Get cursor text without prompt.
  return s:chomp_prompt(s:get_cur_text(), line('.'))
endfunction"}}}
function! vimshell#interactive#get_cur_line(line)"{{{
  " Get cursor text without prompt.
  return s:chomp_prompt(getline(a:line), a:line)
endfunction"}}}
function! vimshell#interactive#get_prompt(line)"{{{
  " Get prompt line.
  return !has_key(b:interactive.prompt_history, a:line) ? '' : b:interactive.prompt_history[a:line]
endfunction"}}}
function! s:get_cur_text()"{{{
  let l:pos = mode() ==# 'i' ? 2 : 1

  let l:cur_text = col('.') < l:pos ? '' : getline('.')[: col('.') - l:pos]

  if l:cur_text != '' && char2nr(l:cur_text[-1:]) >= 0x80
    let l:len = len(getline('.'))

    " Skip multibyte
    let l:pos -= 1
    let l:cur_text = getline('.')[: col('.') - l:pos]
    let l:fchar = char2nr(l:cur_text[-1:])
    while col('.')-l:pos+1 < l:len && l:fchar >= 0x80
      let l:pos -= 1

      let l:cur_text = getline('.')[: col('.') - l:pos]
      let l:fchar = char2nr(l:cur_text[-1:])
    endwhile
  endif
  
  return l:cur_text
endfunction"}}}
function! s:chomp_prompt(cur_text, line)"{{{
  let l:cur_text = a:cur_text
  
  if has_key(b:interactive.prompt_history, a:line)
    let l:cur_text = l:cur_text[len(b:interactive.prompt_history[a:line]) : ]
  elseif !empty(b:interactive.prompt_history)
    " Maybe a multi-line command was pasted in.
    let l:max_prompt = max(keys(b:interactive.prompt_history)) " Only count once.
    if l:max_prompt < line('$')
      let l:cur_text = getline(l:max_prompt)[len(b:interactive.prompt_history[l:max_prompt]) : ]
      for i in range(l:max_prompt+1, line('$'))
        let l:cur_text .=  "\<LF>".getline(i)
      endfor
    else
      " Still nothing? We give up.
      echohl WarningMsg | echo "Invalid input." | echohl None
    endif
  else
    " Still nothing? We give up.
    echohl WarningMsg | echo "Invalid input." | echohl None
  endif

  return l:cur_text
endfunction"}}}
function! s:delete_input(in)"{{{
  if has_key(b:interactive.prompt_history, line('.'))
    call setline('.', b:interactive.prompt_history[line('.')])
  elseif !empty(b:interactive.prompt_history)
    " Maybe a multi-line command was pasted in.
    let l:max_prompt = max(keys(b:interactive.prompt_history)) " Only count once.
    if l:max_prompt < line('$')
      call setline(l:max_prompt, b:interactive.prompt_history[l:max_prompt])
      for i in range(l:max_prompt+1, line('$'))
        delete
      endfor
    else
      " Still nothing? We give up.
      call setline('.', '')
    endif
  else
    " Still nothing? We give up.
    call setline('.', '')
  endif
endfunction"}}}

function! vimshell#interactive#execute_pty_inout(is_insert)"{{{
  if !b:interactive.process.is_valid
    return
  endif

  let l:in = vimshell#interactive#get_cur_line(line('.'))

  if l:in != ''
    call s:append_history(l:in)
  endif

  if b:interactive.encoding != '' && &encoding != b:interactive.encoding
    " Convert encoding.
    let l:in = iconv(l:in, &encoding, b:interactive.encoding)
  endif

  try
    " Delete input text.
    call s:delete_input(l:in)
    
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

  if b:interactive.process.is_valid
    if b:interactive.process.eof
      call vimshell#interactive#exit()
    elseif a:is_insert
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

  let l:in = vimshell#interactive#get_cur_line(line('.')) . a:string

  if l:in != ''
    call s:append_history(l:in)
  endif

  if b:interactive.encoding != '' && &encoding != b:interactive.encoding
    " Convert encoding.
    let l:in = iconv(l:in, &encoding, b:interactive.encoding)
  endif

  try
    " Delete input text.
    call s:delete_input(l:in)
    
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

  if !b:interactive.process.eof
    startinsert!
  endif
endfunction"}}}

function! vimshell#interactive#execute_pty_out(is_insert)"{{{
  if !b:interactive.process.is_valid
    return
  endif

  let l:outputed = 0
  if b:interactive.cached_output != ''
    " Use cache.
    let l:read = b:interactive.cached_output
    let l:outputed = 1
    let b:interactive.cached_output = ''

    call s:print_buffer(b:interactive.fd, l:read)
    redraw
  else
    let l:read = b:interactive.process.read(-1, 40)
    while l:read != ''
      let l:outputed = 1

      call s:print_buffer(b:interactive.fd, l:read)
      redraw

      let l:read = b:interactive.process.read(-1, 40)
    endwhile
  endif

  if l:outputed
    let b:interactive.prompt_history[line('$')] = getline('$')
    $
    
    if !b:interactive.process.eof && a:is_insert
      startinsert!
    else
      normal! $
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

  if has_key(b:interactive, 'cached_output') && b:interactive.cached_output != ''
    " Use cache.
    let l:read = b:interactive.cached_output
    let b:interactive.cached_output = ''

    call s:print_buffer(b:interactive.fd, l:read)
    redraw
  else
    if !b:interactive.process.stdout.eof
      let l:read = b:interactive.process.stdout.read(-1, 40)
      while l:read != ''
        call s:print_buffer(b:interactive.fd, l:read)
        redraw

        let l:read = b:interactive.process.stdout.read(-1, 40)
      endwhile
    endif

    if !b:interactive.process.stderr.eof
      let l:read = b:interactive.process.stderr.read(-1, 40)
      while l:read != ''
        call s:error_buffer(b:interactive.fd, l:read)
        redraw

        let l:read = b:interactive.process.stderr.read(-1, 40)
      endwhile
    endif
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
  if &filetype != 'vimshell'
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

  if &filetype != 'vimshell'
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
      catch /No such process/
      endtry
    endif
    
    if bufname('%') == a:afile && getbufvar(a:afile, '&filetype') != 'vimshell'
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

  " Strip <CR>.
  let l:string = substitute(l:string, '\r\+\n', '\n', 'g')
  if l:string =~ '\r'
    for l:line in split(getline('$') . l:string, '\n', 1)
      call append('$', '')
      for l:l in split(l:line, '\r', 1)
        call setline('$', l:l)
        redraw
      endfor
    endfor
  else
    let l:lines = split(getline('$') . l:string, '\n', 1)

    call setline('$', l:lines[0])
    call append('$', l:lines[1:])
  endif

  if getline('$') =~ s:password_regex
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

  call vimshell#terminal#interpret_escape_sequence()
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

    if getline('$') =~ '!!!$'
      call setline('$', getline('$')[: -4] . l:lines[0] . '!!!')
    else
      call setline('$', getline('$') . '!!!' . l:lines[0] . '!!!')
    endif
    call append('$', map(l:lines[1:], '"!!!" . v:val . "!!!"'))
  endif

  call vimshell#terminal#interpret_escape_sequence()

  " Set cursor.
  $
endfunction"}}}

function! vimshell#interactive#load_history()"{{{
  let l:history_dir = g:vimshell_temporary_directory . '/int-history'
  if !isdirectory(fnamemodify(l:history_dir, ':p'))
    call mkdir(fnamemodify(l:history_dir, ':p'), 'p')
  endif

  let l:path = l:history_dir . '/'.&filetype
  if filereadable(l:path)
    return readfile(l:path)
  else
    return []
  endif
endfunction"}}}
function! s:append_history(command)"{{{
  if has_key(g:vimshell_no_save_history_programs, &filetype[4:])
        \ && g:vimshell_no_save_history_programs[&filetype[4:]]
    return
  endif
  " Reduce blanks.
  let l:command = substitute(a:command, '\s\+', ' ', 'g')
  " Filtering.
  call insert(filter(b:interactive.command_history, 'v:val != '.string(substitute(l:command, "'", "''", 'g'))), l:command)

  " Trunk.
  let b:interactive.command_history = b:interactive.command_history[: g:vimshell_history_max_size-1]

  let l:history_dir = g:vimshell_temporary_directory . '/int-history'
  if !isdirectory(fnamemodify(l:history_dir, ':p'))
    call mkdir(fnamemodify(l:history_dir, ':p'), 'p')
  endif
  call writefile(b:interactive.command_history, l:history_dir . '/'.&filetype)
endfunction"}}}

" Autocmd functions.
function! s:check_all_output()"{{{
  let l:bufnr_save = bufnr('%')

  let l:bufnr = 1
  while l:bufnr <= bufnr('$')
    if buflisted(l:bufnr) && bufwinnr(l:bufnr) > 0 && type(getbufvar(l:bufnr, 'interactive')) != type('')
      let l:filetype = getbufvar(l:bufnr, '&filetype')
      let l:interactive = getbufvar(l:bufnr, 'interactive')
      if l:interactive.is_background || l:filetype =~ '^int-'
        " Check output.
        call vimshell#interactive#check_output(l:interactive, l:bufnr, l:bufnr_save)
      endif
    endif

    let l:bufnr += 1
  endwhile
  
  if exists('b:interactive') && b:interactive.process.is_valid
    call feedkeys("g\<ESC>", 'n')
  endif
endfunction"}}}
function! vimshell#interactive#check_output(interactive, bufnr, bufnr_save)"{{{
  let l:read = ''
  
  if a:interactive.is_background
    " Background execute.
    
    if a:interactive.process.stdout.eof && a:interactive.process.stderr.eof
      call vimshell#interactive#exit()
      return
    endif

    " Check pipe output.
    if !a:interactive.process.stdout.eof
      let l:output = a:interactive.process.stdout.read(-1, 40)
      while l:output != ''
        let l:read .= l:output
        let l:output = a:interactive.process.stdout.read(-1, 40)
      endwhile
      let l:read .= l:output
    endif
  else
    " Interactive execute.
    
    if a:interactive.process.is_valid && a:interactive.process.eof
      call vimshell#interactive#exit()
      return
    endif

    " Check pty output.
    let l:output = a:interactive.process.read(-1, 40)
    while l:output != ''
      let l:read .= l:output
      let l:output = a:interactive.process.read(-1, 40)
    endwhile
    let l:read .= l:output
  endif

  if l:read != ''
    let a:interactive.cached_output = l:read
    
    if a:bufnr != a:bufnr_save
      let l:pos = getpos('.')
      execute bufwinnr(a:bufnr) . 'wincmd w'
    endif

    if mode() !=# 'i'
      let l:intbuffer_pos = getpos('.')
    endif
    
    if a:interactive.is_background
      setlocal modifiable
      call vimshell#interactive#execute_pipe_out()
      setlocal nomodifiable
    else
      " Check input.
      if has_key(b:interactive.prompt_history, line('.'))
            \&& vimshell#interactive#get_cur_line(line('.')) != ''
        return
      endif

      call vimshell#interactive#execute_pty_out(mode() ==# 'i')
    endif

    if !a:interactive.process.eof && mode() ==# 'i'
      startinsert!
    endif
    
    if mode() !=# 'i'
      call setpos('.', l:intbuffer_pos)
    endif
    
    if a:bufnr != a:bufnr_save && bufexists(a:bufnr_save)
      call setpos('.', l:pos)
      execute bufwinnr(a:bufnr_save) . 'wincmd w'
    endif
  endif
endfunction"}}}

" vim: foldmethod=marker
