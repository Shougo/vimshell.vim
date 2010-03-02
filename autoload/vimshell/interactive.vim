"=============================================================================
" FILE: interactive.vim
" AUTHOR:  Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 18 Feb 2010
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

let s:is_win = has('win32') || has('win64')

augroup VimShellInteractive
  autocmd!
  autocmd CursorHold * call s:check_output()
augroup END

command! -range VimShellSendString call s:send_string(<line1>, <line2>)

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
      call b:interactive.process.write(l:in[:-2] . (s:is_win ? "\<C-z>" : "\<C-d>"))
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
    if l:in =~ "\<C-d>$"
      " EOF.
      call b:interactive.process.write(l:in[:-2] . (s:is_win ? "\<C-z>" : "\<C-d>"))
      let b:interactive.skip_echoback = l:in[:-2]
      call vimshell#interactive#execute_pty_out(1)

      call vimshell#interactive#exit()
      return
    elseif getline('.') != '...'
      if l:in =~ '^-> '
        " Delete ...
        let l:in = l:in[3:]
      endif

      call b:interactive.process.write(l:in)
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
  let l:read = b:interactive.process.read(-1, 40)
  while l:read != ''
    let l:outputed = 1

    call s:print_buffer(b:interactive.fd, l:read)
    redraw

    let l:read = b:interactive.process.read(-1, 40)
  endwhile

  if l:outputed
    if has_key(b:interactive, 'skip_echoback') && line('.') < line('$') && b:interactive.skip_echoback ==# getline(line('.'))
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

  try
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
  catch
    call vimshell#interactive#exit()
    return
  endtry

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
  endif
endfunction"}}}
function! vimshell#interactive#force_exit()"{{{
  if !b:interactive.process.is_valid
    return
  endif

  " Kill processes.
  try
    " 15 == SIGTERM
    call b:interactive.process.vp_kill(15)
  catch
  endtry

  if &filetype != 'vimshell'
    call append(line('$'), '*Killed*')
    $
  endif
endfunction"}}}
function! vimshell#interactive#hang_up()"{{{
  let l:bufnr = 1
  while l:bufnr <= bufnr('$')
    if !buflisted(l:bufnr) && type(getbufvar(l:bufnr, 'vimproc')) != type('')
      let l:vimproc = getbufvar(l:bufnr, 'b:interactive')
      if b:interactive.process.is_valid
        " Kill processes.
        for sub in l:vimproc.process
          try
            " 15 == SIGTERM
            call sub.kill(15)
            echomsg 'Killed'
          catch /No such process/
          endtry
        endfor
      endif
    endif

    let l:bufnr += 1
  endwhile
endfunction"}}}

function! vimshell#interactive#interrupt()"{{{
  if !b:interactive.process.is_valid
    return
  endif

  " Kill processes.
  for sub in b:interactive.process
    try
      " 1 == SIGINT
      call sub.kill(1)
    catch /No such process/
    endtry
  endfor

  call vimshell#interactive#execute_pty_out(1)
endfunction"}}}

function! vimshell#interactive#highlight_escape_sequence()"{{{
  let l:pos = getpos('.')

  let l:register_save = @"
  let l:color_table = [ 0x00, 0x5F, 0x87, 0xAF, 0xD7, 0xFF ]
  let l:grey_table = [
        \0x08, 0x12, 0x1C, 0x26, 0x30, 0x3A, 0x44, 0x4E, 
        \0x58, 0x62, 0x6C, 0x76, 0x80, 0x8A, 0x94, 0x9E, 
        \0xA8, 0xB2, 0xBC, 0xC6, 0xD0, 0xDA, 0xE4, 0xEE
        \]

  while search("\<ESC>\\[[0-9;]*m", 'c')
    normal! dfm

    let [lnum, col] = getpos('.')[1:2]
    if len(getline('.')) == col
      let col += 1
    endif
    let syntax_name = 'EscapeSequenceAt_' . bufnr('%') . '_' . lnum . '_' . col
    execute 'syntax region' syntax_name 'start=+\%' . lnum . 'l\%' . col . 'c+ end=+\%$+' 'contains=ALL'

    let highlight = ''
    for color_code in split(matchstr(@", '[0-9;]\+'), ';')
      if color_code == 0"{{{
        let highlight .= ' cterm=NONE ctermfg=NONE ctermbg=NONE gui=NONE guifg=NONE guibg=NONE'
      elseif color_code == 1
        let highlight .= ' cterm=BOLD gui=BOLD'
      elseif color_code == 4
        let highlight .= ' cterm=UNDERLINE gui=UNDERLINE'
      elseif color_code == 7
        let highlight .= ' cterm=REVERSE gui=REVERSE'
      elseif color_code == 8
        let highlight .= ' ctermfg=0 ctermbg=0 guifg=#000000 guibg=#000000'
      elseif 30 <= color_code && color_code <= 37 
        " Foreground color.
        let highlight .= printf(' ctermfg=%d guifg=%s', color_code - 30, g:VimShell_EscapeColors[color_code - 30])
      elseif color_code == 38
        " Foreground 256 colors.
        let l:color = split(matchstr(@", '[0-9;]\+'), ';')[2]
        if l:color >= 232
          " Grey scale.
          let l:gcolor = l:grey_table[(l:color - 232)]
          let highlight .= printf(' ctermfg=%d guifg=#%02x%02x%02x', l:color, l:gcolor, l:gcolor, l:gcolor)
        elseif l:color >= 16
          " RGB.
          let l:gcolor = l:color - 16
          let l:red = l:color_table[l:gcolor / 36]
          let l:green = l:color_table[(l:gcolor % 36) / 6]
          let l:blue = l:color_table[l:gcolor % 6]

          let highlight .= printf(' ctermfg=%d guifg=#%02x%02x%02x', l:color, l:red, l:green, l:blue)
        else
          let highlight .= printf(' ctermfg=%d guifg=%s', l:color, g:VimShell_EscapeColors[l:color])
        endif
        break
      elseif color_code == 39
        " TODO
      elseif 40 <= color_code && color_code <= 47 
        " Background color.
        let highlight .= printf(' ctermbg=%d guibg=%s', color_code - 40, g:VimShell_EscapeColors[color_code - 40])
      elseif color_code == 48
        " Background 256 colors.
        let l:color = split(matchstr(@", '[0-9;]\+'), ';')[2]
        if l:color >= 232
          " Grey scale.
          let l:gcolor = l:grey_table[(l:color - 232)]
          let highlight .= printf(' ctermbg=%d guibg=#%02x%02x%02x', l:color, l:gcolor, l:gcolor, l:gcolor)
        elseif l:color >= 16
          " RGB.
          let l:gcolor = l:color - 16
          let l:red = l:color_table[l:gcolor / 36]
          let l:green = l:color_table[(l:gcolor % 36) / 6]
          let l:blue = l:color_table[l:gcolor % 6]

          let highlight .= printf(' ctermbg=%d guibg=#%02x%02x%02x', l:color, l:red, l:green, l:blue)
        else
          let highlight .= printf(' ctermbg=%d guibg=%s', l:color, g:VimShell_EscapeColors[l:color])
        endif
        break
      elseif color_code == 49
        " TODO
      endif"}}}
    endfor
    if highlight != ''
      execute 'highlight link' syntax_name 'Normal'
      execute 'highlight' syntax_name highlight
    endif
  endwhile
  let @" = l:register_save

  call setpos('.', l:pos)
endfunction"}}}

function! s:print_buffer(fd, string)"{{{
  if a:string == ''
    return
  endif

  if a:fd.stdout != ''
    echomsg a:fd.stdout
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
  let l:string = substitute(l:string, '\r\n', '\n', 'g')
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

  call vimshell#interactive#highlight_escape_sequence()
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
  let l:string = substitute(l:string, '\r\n', '\n', 'g')
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

  call vimshell#interactive#highlight_escape_sequence()

  " Set cursor.
  $
endfunction"}}}

" Command functions.
function! s:send_string(line1, line2)"{{{
  " Check alternate buffer.
  let l:filetype = getwinvar(winnr('#'), '&filetype')
  echomsg l:filetype
  if l:filetype == 'background' || l:filetype =~ '^int_'
    let l:line = getline(a:line1)
    let l:string = join(getline(a:line1, a:line2), "\<LF>") . "\<LF>"
    execute winnr('#') 'wincmd w'

    " Save prompt.
    let l:prompt = vimshell#interactive#get_prompt(line('$'))
    let l:prompt_nr = line('$')
    
    " Send string.
    call vimshell#interactive#send_string(l:string)
    
    call setline(l:prompt_nr, l:prompt . l:line)
  endif
endfunction"}}}

function! s:on_exit()"{{{
  augroup interactive
    autocmd! * <buffer>
  augroup END

  call vimshell#interactive#exit()
endfunction"}}}

" Autocmd functions.
function! s:check_output()"{{{
  let l:bufnr = 1
  while l:bufnr <= bufnr('$')
    if l:bufnr != bufnr('%') && buflisted(l:bufnr) && bufwinnr(l:bufnr) >= 0 && type(getbufvar(l:bufnr, 'vimproc')) != type('')
      " Check output.
      let l:filetype = getbufvar(l:bufnr, '&filetype')
      if l:filetype == 'background' || l:filetype =~ '^int_'
        let l:pos = getpos('.')

        execute 'buffer' l:bufnr

        if l:filetype  == 'background'
          " Background execute.
          call vimshell#interactive#execute_pipe_out()
        else
          " Interactive execute.
          call vimshell#interactive#execute_pty_out(0)
        endif

        buffer #
      endif
    endif

    let l:bufnr += 1
  endwhile
endfunction"}}}

" vim: foldmethod=marker
