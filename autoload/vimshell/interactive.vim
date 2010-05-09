"=============================================================================
" FILE: interactive.vim
" AUTHOR:  Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 09 May 2010
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

command! -range -nargs=? VimShellSendString call s:send_string(<line1>, <line2>, <q-args>)

function! vimshell#interactive#get_cur_text()"{{{
  if getline('.') == '...'
    " Skip input.
    return ''
  endif

  " Get cursor text without prompt.
  let l:pos = mode() ==# 'i' ? 2 : 1

  let l:cur_text = col('.') < l:pos ? '' : getline('.')[: col('.') - l:pos]
  if l:cur_text =~ '^-> '
    let l:cur_text = l:cur_text[3:]
  endif
  
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

  if has_key(b:interactive.prompt_history, line('.'))
    let l:cur_text = l:cur_text[len(b:interactive.prompt_history[line('.')]) : ]
  else
    " Maybe line numbering got disrupted, search for a matching prompt.
    let l:prompt_search = 0
    for pnr in reverse(sort(keys(b:interactive.prompt_history)))
      let l:prompt_length = len(b:interactive.prompt_history[pnr])
      " In theory 0 length or ' ' prompt shouldn't exist, but still...
      if l:prompt_length > 0 && b:interactive.prompt_history[pnr] != ' '
        " Does the current line have this prompt?
        if l:cur_text[: l:prompt_length - 1] == b:interactive.prompt_history[pnr]
          let l:cur_text = l:cur_text[l:prompt_length : ]
          let l:prompt_search = pnr
        endif
      endif
    endfor

    " Still nothing? Maybe a multi-line command was pasted in.
    let l:max_prompt = max(keys(b:interactive.prompt_history)) " Only count once.
    if l:prompt_search == 0 && l:max_prompt < line('$')
      for i in range(l:max_prompt, line('$'))
        if i == l:max_prompt && has_key(b:interactive.prompt_history, i)
          let l:cur_text = getline(i)
          let l:cur_text = l:cur_text[len(b:interactive.prompt_history[i]) : ]
        else
          let l:cur_text = l:cur_text . getline(i)
        endif
      endfor
      let l:prompt_search = l:max_prompt
    endif

    " Still nothing? We give up.
    if l:prompt_search == 0
      echohl WarningMsg | echo "Invalid input." | echohl None
    endif
  endif

  return l:cur_text
endfunction"}}}
function! vimshell#interactive#get_cur_line(line)"{{{
  if getline('.') == '...'
    " Skip input.
    return ''
  endif

  " Get cursor text without prompt.
  let l:cur_text = getline(a:line)

  if has_key(b:interactive.prompt_history, line('.'))
    let l:cur_text = l:cur_text[len(b:interactive.prompt_history[a:line]) : ]
  else
    " Maybe line numbering got disrupted, search for a matching prompt.
    let l:prompt_search = 0
    for pnr in reverse(sort(keys(b:interactive.prompt_history)))
      let l:prompt_length = len(b:interactive.prompt_history[pnr])
      " In theory 0 length or ' ' prompt shouldn't exist, but still...
      if l:prompt_length > 0 && b:interactive.prompt_history[pnr] != ' '
        " Does the current line have this prompt?
        if l:cur_text[: l:prompt_length - 1] == b:interactive.prompt_history[pnr]
          let l:cur_text = l:cur_text[l:prompt_length : ]
          let l:prompt_search = pnr
        endif
      endif
    endfor

    " Still nothing? Maybe a multi-line command was pasted in.
    let l:max_prompt = max(keys(b:interactive.prompt_history)) " Only count once.
    if l:prompt_search == 0 && l:max_prompt < line('$')
      for i in range(l:max_prompt, line('$'))
        if i == l:max_prompt && has_key(b:interactive.prompt_history, i)
          let l:cur_text = getline(i)
          let l:cur_text = l:cur_text[len(b:interactive.prompt_history[i]) : ]
        else
          let l:cur_text = l:cur_text . getline(i)
        endif
      endfor
      let l:prompt_search = l:max_prompt
    endif

    " Still nothing? We give up.
    if l:prompt_search == 0
      echohl WarningMsg | echo "Invalid input." | echohl None
    endif
  endif

  return l:cur_text
endfunction"}}}
function! vimshell#interactive#get_prompt(line)"{{{
  " Get prompt line.

  if getline('.') == '...' || !has_key(b:interactive.prompt_history, a:line)
    return ''
  elseif getline('.') =~ '^-> '
    return '-> '
  endif

  return b:interactive.prompt_history[a:line]
endfunction"}}}

function! vimshell#interactive#execute_pty_inout(is_insert)"{{{
  if !b:interactive.process.is_valid
    return
  endif

  if b:interactive.process.eof
    call vimshell#interactive#exit()
    return
  endif

  let l:in = vimshell#interactive#get_cur_line(line('.'))

  if l:in != ''
    call add(b:interactive.command_history, l:in)
  endif

  if b:interactive.encoding != '' && &encoding != b:interactive.encoding
    " Convert encoding.
    let l:in = iconv(l:in, &encoding, b:interactive.encoding)
  endif

  try
    if l:in =~ "\<C-d>$"
      " EOF.
      call b:interactive.process.write(l:in[:-2] . (b:interactive.is_pty ? "\<C-z>" : "\<C-d>"))
      let b:interactive.skip_echoback = l:in[:-2]
      call vimshell#interactive#execute_pty_out(a:is_insert)

      call vimshell#interactive#exit()
      return
    elseif getline('.') != '...'
      if l:in =~ '^-> '
        " Delete ...
        let l:in = l:in[3:]
      endif

      call b:interactive.process.write(l:in . "\<LF>")
      let b:interactive.skip_echoback = l:in
    endif
  catch
    call vimshell#interactive#exit()
    return
  endtry

  if getline('$') != '...'
    call append('$', '...')
    $
  endif

  call vimshell#interactive#execute_pty_out(a:is_insert)

  if getline('$') =~ '^\s*$'
    call setline('$', '...')
  endif

  if b:interactive.process.is_valid && b:interactive.process.eof
    call vimshell#interactive#exit()
  elseif a:is_insert
    startinsert!
  else
    normal! $
  endif
endfunction"}}}
function! vimshell#interactive#send_string(string)"{{{
  if !b:interactive.process.is_valid
    return
  endif

  if b:interactive.process.eof
    call vimshell#interactive#exit()
    return
  endif

  let l:in = vimshell#interactive#get_cur_line(line('.')) . a:string

  if l:in != ''
    call add(b:interactive.command_history, l:in)
  endif

  if b:interactive.encoding != '' && &encoding != b:interactive.encoding
    " Convert encoding.
    let l:in = iconv(l:in, &encoding, b:interactive.encoding)
  endif

  try
    let b:interactive.skip_echoback = l:in[: -2]
    
    if l:in =~ "\<C-d>$"
      " EOF.
      call b:interactive.process.write(l:in[:-2] . (b:interactive.is_pty ? "\<C-z>" : "\<C-d>"))
      call vimshell#interactive#execute_pty_out(1)

      call vimshell#interactive#exit()
      return
    elseif getline('.') != '...'
      if l:in =~ '^-> '
        " Delete ...
        let l:in = l:in[3:]
      endif

      call b:interactive.process.write(l:in)
    endif
  catch
    call vimshell#interactive#exit()
    return
  endtry

  if getline('$') != '...'
    call append('$', '...')
    $
  endif

  call vimshell#interactive#execute_pty_out(1)

  if getline('$') =~ '^\s*$'
    call setline('$', '...')
  endif

  if b:interactive.process.is_valid && b:interactive.process.eof
    call vimshell#interactive#exit()
  else
    startinsert!
  endif
endfunction"}}}

function! vimshell#interactive#execute_pty_out(is_insert)"{{{
  if !b:interactive.process.is_valid
    return
  endif

  if b:interactive.process.eof
    call vimshell#interactive#exit()
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
    if has_key(b:interactive, 'skip_echoback') && b:interactive.skip_echoback ==# getline(line('.'))
      delete
      redraw
    endif
    
    let b:interactive.prompt_history[line('$')] = getline('$')
    $
    
    if a:is_insert
      startinsert!
    else
      normal! $
    endif
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

  if getline('$') == '...'
    call setline('$', '')
  endif

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
  if getline('$') == '...'
    call setline('$', '')
  endif

  " Strip <CR>.
  let l:string = substitute(l:string, '\r\+\n', '\n', 'g')
  if l:string =~ '\r'
    for l:line in split(getline('$') . l:string, '\n', 1)
      call append('$', '')
      for l:l in split(l:line, '\r', 1)
        call setline('$', '!!! ' . l:l . ' !!!')
        redraw
      endfor
    endfor
  else
    let l:lines = map(split(getline('$') . l:string, '\n', 1), '"!!! " . v:val . " !!!"')

    call setline('$', l:lines[0])
    call append('$', l:lines[1:])
  endif

  call vimshell#terminal#interpret_escape_sequence()

  " Set cursor.
  $
endfunction"}}}

" Command functions.
function! s:send_string(line1, line2, string)"{{{
  " Check alternate buffer.
  let l:filetype = getwinvar(winnr('#'), '&filetype')
  if l:filetype =~ '^int-'
    if a:string != ''
      let l:string = a:string . "\<LF>"
    else
      let l:string = join(getline(a:line1, a:line2), "\<LF>") . "\<LF>"
    endif
    let l:line = split(l:string, "\<LF>")[0]
    
    execute winnr('#') 'wincmd w'

    " Save prompt.
    let l:prompt = vimshell#interactive#get_prompt(line('$'))
    let l:prompt_nr = line('$')
    
    " Send string.
    call vimshell#interactive#send_string(l:string)
    
    call setline(l:prompt_nr, l:prompt . l:line)
  endif
endfunction"}}}

" Autocmd functions.
function! s:check_all_output()"{{{
  let l:bufnr_save = bufnr('%')

  let l:bufnr = 1
  while l:bufnr <= bufnr('$')
    if l:bufnr != bufnr('%') && buflisted(l:bufnr) && bufwinnr(l:bufnr) >= 0 && type(getbufvar(l:bufnr, 'interactive')) != type('')
      let l:filetype = getbufvar(l:bufnr, '&filetype')
      let l:interactive = getbufvar(l:bufnr, 'interactive')
      if l:interactive.is_background || l:filetype =~ '^int-'
        " Check output.
        call vimshell#interactive#check_output(l:interactive, l:bufnr, l:bufnr_save)
      endif
    endif

    let l:bufnr += 1
  endwhile
endfunction"}}}
function! vimshell#interactive#check_output(interactive, bufnr, bufnr_save)"{{{
  let l:read = ''
  
  if a:interactive.is_background
    " Background execute.

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
      execute a:bufnr_save . 'wincmd w'
    endif

    if mode() !=# 'i'
      let l:intbuffer_pos = getpos('.')
    endif
    
    if a:interactive.is_background
      call vimshell#interactive#execute_pipe_out()
    else
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
      wincmd p
    endif
  endif
endfunction"}}}

" vim: foldmethod=marker
