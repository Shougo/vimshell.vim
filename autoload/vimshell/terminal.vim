"=============================================================================
" FILE: terminal.vim
" AUTHOR:  Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 06 Mar 2011.
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

function! vimshell#terminal#print(string, is_error)"{{{
  setlocal modifiable

  let l:current_line = getline('.')
  let l:cur_text = matchstr(getline('.'), '^.*\%' . col('.') . 'c')

  if !a:is_error && b:interactive.type !=# 'terminal' && a:string !~ '[\e\b]'
    " Strip <CR>.
    let l:string = substitute(substitute(a:string, "\<C-g>", '', 'g'), '\r\+\n', '\n', 'g')

    if l:string =~ '\r'
      for l:line in split(getline('.') . l:string, '\n', 1)
        call append('.', '')
        normal! j

        for l:l in split(l:line, '\r', 1)
          call setline('.', l:l)
          redraw
        endfor
      endfor
    else
      " Optimized print.
      let l:lines = split(l:string, '\n', 1)
      if !b:interactive.is_pty
            \ && has_key(b:interactive, 'command')
            \ && has_key(g:vimshell_interactive_no_echoback_commands, b:interactive.command)
            \ && g:vimshell_interactive_no_echoback_commands[b:interactive.command]
        call append('.', l:lines)
      else
        if line('.') != b:interactive.echoback_linenr
          call setline('.', l:current_line . l:lines[0])
        endif

        call append('.', l:lines[1:])
      endif
      execute 'normal!' (len(l:lines)-1).'j$'
    endif

    return
  endif

  if !has_key(b:interactive, 'terminal')
    call s:init_terminal()
  endif

  let l:newstr = ''
  let l:pos = 0
  let l:max = len(a:string)
  let s:line = line('.')
  "let s:col = (mode() ==# 'i' && b:interactive.type !=# 'terminal' ? 
        "\ (col('.') < 1 ? 1 : col('.') - 1) : col('.'))
  let s:col = col('.')
  let s:lines = {}
  let s:lines[s:line] = l:current_line

  while l:pos < l:max
    let l:char = a:string[l:pos]

    if l:char !~ '[[:cntrl:]]'"{{{
      let l:newstr .= l:char
      let l:pos += 1
      continue
      "}}}
    elseif l:char == "\<C-h>""{{{
      " Print rest string.
      call s:output_string(l:newstr)
      let l:newstr = ''

      if l:pos + 1 < l:max && a:string[l:pos+1] == "\<C-h>"
        " <C-h><C-h>
        call s:control.delete_multi_backword_char()
        let l:pos += 2
      else
        " <C-h>
        call s:control.delete_backword_char()
        let l:pos += 1
      endif

      continue
      "}}}
    elseif l:char == "\<ESC>""{{{
      " Check escape sequence.
      let l:checkstr = a:string[l:pos+1 :]
      if l:checkstr == ''
        break
      endif

      " Check CSI pattern.
      if l:checkstr =~ '^\[[0-9;]*.'
        let l:matchstr = matchstr(l:checkstr, '^\[[0-9;]*.')

        if has_key(s:escape_sequence_csi, l:matchstr[-1:])
          call s:output_string(l:newstr)
          let l:newstr = ''

          call call(s:escape_sequence_csi[l:matchstr[-1:]], [l:matchstr], s:escape)

          let l:pos += len(l:matchstr) + 1
          continue
        endif
      endif

      " Check simple pattern.
      let l:checkchar1 = l:checkstr[0]
      if has_key(s:escape_sequence_simple_char1, l:checkchar1)"{{{
        call s:output_string(l:newstr)
        let l:newstr = ''

        call call(s:escape_sequence_simple_char1[l:checkchar1], [''], s:escape)

        let l:pos += 2
        continue
      endif"}}}
      let l:checkchar2 = l:checkstr[: 1]
      if l:checkchar2 != '' && has_key(s:escape_sequence_simple_char2, l:checkchar2)"{{{
        call s:output_string(l:newstr)
        let l:newstr = ''

        call call(s:escape_sequence_simple_char2[l:checkchar2], [''], s:escape)

        let l:pos += 3
        continue
      endif"}}}

      let l:matched = 0
      " Check match pattern.
      for l:pattern in keys(s:escape_sequence_match)"{{{
        if l:checkstr =~ l:pattern
          let l:matched = 1

          " Print rest string.
          call s:output_string(l:newstr)
          let l:newstr = ''

          let l:matchstr = matchstr(l:checkstr, l:pattern)

          call call(s:escape_sequence_match[l:pattern], [l:matchstr], s:escape)

          let l:pos += len(l:matchstr) + 1
          break
        endif
      endfor"}}}

      if l:matched
        continue
      endif"}}}
    elseif has_key(s:control_sequence, l:char)"{{{
      " Check other pattern.
      " Print rest string.
      call s:output_string(l:newstr)
      let l:newstr = ''

      call call(s:control_sequence[l:char], [], s:control)

      let l:pos += 1
      continue
    endif"}}}

    let l:newstr .= l:char
    let l:pos += 1
  endwhile

  " Print rest string.
  call s:output_string(l:newstr)

  " Set lines.
  for l:linenr in sort(map(keys(s:lines), 'str2nr(v:val)'), 's:sortfunc')
    call setline(l:linenr, a:is_error ?
          \ '!!!'.s:lines[l:linenr].'!!!' : s:lines[l:linenr])
  endfor
  let s:lines = {}

  let l:oldpos = getpos('.')
  let l:oldpos[1] = s:line
  let l:oldpos[2] = s:col

  if b:interactive.type ==# 'terminal'
    let b:interactive.save_cursor = l:oldpos

    if s:col >= len(getline(s:line))
      " Append space.
      call setline(s:line, getline(s:line) . ' ')
    endif
  endif

  " Move pos.
  call setpos('.', l:oldpos)

  redraw
endfunction"}}}
function! vimshell#terminal#set_title()"{{{
  if !has_key(b:interactive, 'terminal')
    call s:init_terminal()
  endif

  let &titlestring = b:interactive.terminal.titlestring
endfunction"}}}
function! vimshell#terminal#restore_title()"{{{
  if !has_key(b:interactive, 'terminal')
    call s:init_terminal()
  endif

  let &titlestring = b:interactive.terminal.titlestring_save
endfunction"}}}
function! vimshell#terminal#clear_highlight()"{{{
  if !has_key(b:interactive, 'terminal')
    call s:init_terminal()
  endif

  for l:syntax_names in values(b:interactive.terminal.syntax_names)
    if s:use_conceal()
      execute 'highlight clear' l:syntax_names
      execute 'syntax clear' l:syntax_names
    else
      for l:syntax_name in values(l:syntax_names)
        execute 'highlight clear' l:syntax_name
        execute 'syntax clear' l:syntax_name
      endfor
    endif
  endfor
endfunction"}}}

function! s:init_terminal()"{{{
  let b:interactive.terminal = {
        \ 'syntax_names' : {},
        \ 'titlestring' : &titlestring,
        \ 'titlestring_save' : &titlestring,
        \ 'save_pos' : getpos('.')[1 : 2],
        \ 'region_top' : 0,
        \ 'region_bottom' : 0,
        \ 'standard_character_set' : 'United States',
        \ 'alternate_character_set' : 'United States',
        \ 'current_character_set' : 'United States',
        \}

  if s:use_conceal()
    syntax match vimshellEscapeSequenceConceal contained conceal    '\e\[[0-9;]*m'
    syntax match vimshellEscapeSequenceMarker conceal               '\e\[0\?m'
  endif
endfunction"}}}
function! s:output_string(string)"{{{
  if s:line == b:interactive.echoback_linenr
    if !b:interactive.is_pty
          \ && has_key(b:interactive, 'command')
          \ && has_key(g:vimshell_interactive_no_echoback_commands, b:interactive.command)
          \ && g:vimshell_interactive_no_echoback_commands[b:interactive.command]
      let s:line += 1
      let s:lines[s:line] = a:string
      let s:col = len(a:string)
      return
    else
      return
    endif
  endif
  if a:string == ''
    return
  endif

  let l:string = a:string

  if b:interactive.terminal.current_character_set ==# 'Line Drawing'
    " Convert characters.
    let l:string = ''
    for c in split(a:string, '\zs')
      let l:string .= has_key(s:drawing_character_table, c)?
            \ s:drawing_character_table[c] : c
    endfor
  endif

  if !has_key(s:lines, s:line)
    let s:lines[s:line] = ''
  endif
  let l:left_line = matchstr(s:lines[s:line], '^.*\%' . s:col . 'c')
  let l:right_line = s:lines[s:line][len(l:left_line) :]

  let s:lines[s:line] = l:left_line . l:string . l:right_line

  let s:col += len(l:string)
endfunction"}}}
function! s:sortfunc(i1, i2)"{{{
  return a:i1 == a:i2 ? 0 : a:i1 > a:i2 ? 1 : -1
endfunction"}}}
function! s:scroll_up(number)"{{{
  let l:line = b:interactive.terminal.region_bottom
  let l:end = b:interactive.terminal.region_top - a:number
  while l:line >= l:end
    let s:lines[l:line] = has_key(s:lines, l:line - a:number) ?
          \ s:lines[l:line - a:number] : getline(l:line - a:number)

    let l:line -= 1
  endwhile

  let i = 0
  while i < a:number
    " Clear previous highlight.
    call s:clear_highlight_line(b:interactive.terminal.region_top + i)

    let s:lines[b:interactive.terminal.region_top + i] = ''
    let i += 1
  endwhile
endfunction"}}}
function! s:scroll_down(number)"{{{
  let l:line = b:interactive.terminal.region_top
  let l:end = b:interactive.terminal.region_bottom - a:number
  while l:line <= l:end
    let s:lines[l:line] = has_key(s:lines, l:line + a:number) ?
          \ s:lines[l:line + a:number] : getline(l:line + a:number)

    let l:line += 1
  endwhile

  let i = 0
  while i < a:number
    " Clear previous highlight.
    call s:clear_highlight_line(b:interactive.terminal.region_bottom - i)

    let s:lines[b:interactive.terminal.region_bottom - i] = ''
    let i += 1
  endwhile
endfunction"}}}
function! s:clear_highlight_line(linenr)"{{{
  if s:use_conceal()
    return
  endif

  if has_key(b:interactive.terminal.syntax_names, a:linenr)
    for [l:col, l:prev_syntax] in items(b:interactive.terminal.syntax_names[a:linenr])
      execute 'highlight clear' l:prev_syntax
      execute 'syntax clear' l:prev_syntax
    endfor
  endif
endfunction"}}}
function! s:use_conceal()"{{{
  return has('conceal') && b:interactive.type !=# 'terminal'
endfunction"}}}

" Escape sequence functions.
let s:escape = {}
function! s:escape.ignore(matchstr)"{{{
endfunction"}}}

" Color table."{{{
let s:color_table = [ 0x00, 0x5F, 0x87, 0xAF, 0xD7, 0xFF ]
let s:grey_table = [
      \0x08, 0x12, 0x1C, 0x26, 0x30, 0x3A, 0x44, 0x4E, 
      \0x58, 0x62, 0x6C, 0x76, 0x80, 0x8A, 0x94, 0x9E, 
      \0xA8, 0xB2, 0xBC, 0xC6, 0xD0, 0xDA, 0xE4, 0xEE
      \]
let s:highlight_table = {
      \ 0 : ' cterm=NONE ctermfg=NONE ctermbg=NONE gui=NONE guifg=NONE guibg=NONE', 
      \ 1 : ' cterm=BOLD gui=BOLD',
      \ 3 : ' cterm=ITALIC gui=ITALIC',
      \ 4 : ' cterm=UNDERLINE gui=UNDERLINE',
      \ 7 : ' cterm=REVERSE gui=REVERSE',
      \ 8 : ' ctermfg=0 ctermbg=0 guifg=#000000 guibg=#000000',
      \ 9 : ' gui=UNDERCURL',
      \ 21 : ' cterm=UNDERLINE gui=UNDERLINE',
      \ 22 : ' gui=NONE',
      \ 23 : ' gui=NONE',
      \ 24 : ' gui=NONE',
      \ 25 : ' gui=NONE',
      \ 27 : ' gui=NONE',
      \ 28 : ' ctermfg=NONE ctermbg=NONE guifg=NONE guibg=NONE',
      \ 29 : ' gui=NONE',
      \ 39 : ' ctermfg=NONE guifg=NONE', 
      \ 49 : ' ctermbg=NONE guibg=NONE', 
      \}"}}}
function! s:escape.highlight(matchstr)"{{{
  if s:use_conceal()
    call s:output_string("\<ESC>" . a:matchstr)

    " Check cached highlight.
    if a:matchstr =~ '^\[0m$'
          \ || has_key(b:interactive.terminal.syntax_names, a:matchstr)
      return
    endif
  endif

  let l:highlight = ''
  let l:highlight_list = split(matchstr(a:matchstr, '^\[\zs[0-9;]\+'), ';')
  let l:cnt = 0
  if empty(l:highlight_list)
    " Default.
    let l:highlight_list = [ 0 ]
  endif
  for l:color_code in l:highlight_list
    if has_key(s:highlight_table, l:color_code)"{{{
      " Use table.
      let l:highlight .= s:highlight_table[l:color_code]
    elseif 30 <= l:color_code && l:color_code <= 37
      " Foreground color.
      let l:highlight .= printf(' ctermfg=%d guifg=%s', l:color_code - 30, g:vimshell_escape_colors[l:color_code - 30])
    elseif l:color_code == 38
      if len(l:highlight_list) - l:cnt < 3
        " Error.
        break
      endif

      " Foreground 256 colors.
      let l:color = l:highlight_list[l:cnt + 2]
      if l:color >= 232
        " Grey scale.
        let l:gcolor = s:grey_table[(l:color - 232)]
        let highlight .= printf(' ctermfg=%d guifg=#%02x%02x%02x', l:color, l:gcolor, l:gcolor, l:gcolor)
      elseif l:color >= 16
        " RGB.
        let l:gcolor = l:color - 16
        let l:red = s:color_table[l:gcolor / 36]
        let l:green = s:color_table[(l:gcolor % 36) / 6]
        let l:blue = s:color_table[l:gcolor % 6]

        let l:highlight .= printf(' ctermfg=%d guifg=#%02x%02x%02x', l:color, l:red, l:green, l:blue)
      else
        let l:highlight .= printf(' ctermfg=%d guifg=%s', l:color, g:vimshell_escape_colors[l:color])
      endif
      break
    elseif 40 <= l:color_code && l:color_code <= 47 
      " Background color.
      let l:highlight .= printf(' ctermbg=%d guibg=%s', l:color_code - 40, g:vimshell_escape_colors[l:color_code - 40])
    elseif l:color_code == 48
      if len(l:highlight_list) - l:cnt < 3
        " Error.
        break
      endif

      " Background 256 colors.
      let l:color = l:highlight_list[l:cnt + 2]
      if l:color >= 232
        " Grey scale.
        let l:gcolor = s:grey_table[(l:color - 232)]
        let highlight .= printf(' ctermbg=%d guibg=#%02x%02x%02x', l:color, l:gcolor, l:gcolor, l:gcolor)
      elseif l:color >= 16
        " RGB.
        let l:gcolor = l:color - 16
        let l:red = s:color_table[l:gcolor / 36]
        let l:green = s:color_table[(l:gcolor % 36) / 6]
        let l:blue = s:color_table[l:gcolor % 6]

        let l:highlight .= printf(' ctermbg=%d guibg=#%02x%02x%02x', l:color, l:red, l:green, l:blue)
      else
        let l:highlight .= printf(' ctermbg=%d guibg=%s', l:color, g:vimshell_escape_colors[l:color])
      endif
      break
    elseif 90 <= l:color_code && l:color_code <= 97
      " Foreground color(high intensity).
      let l:highlight .= printf(' ctermfg=%d guifg=%s', l:color_code - 82, g:vimshell_escape_colors[l:color_code - 82])
    elseif 100 <= l:color_code && l:color_code <= 107
      " Background color(high intensity).
      let l:highlight .= printf(' ctermbg=%d guibg=%s', l:color_code - 92, g:vimshell_escape_colors[l:color_code - 92])
    endif"}}}

    let l:cnt += 1
  endfor

  if l:highlight == '' || g:vimshell_disable_escape_highlight
    return
  endif

  if s:use_conceal()
    let l:syntax_name = 'EscapeSequenceAt_' . bufnr('%') . '_' . s:line . '_' . s:col
    let l:syntax_command = printf('start=+\e\%s+ end=+\e\[+me=e-2 ' .
          \ 'contains=vimshellEscapeSequenceConceal oneline', a:matchstr)

    execute 'syntax region' l:syntax_name l:syntax_command
    execute 'highlight' l:syntax_name l:highlight

    let b:interactive.terminal.syntax_names[a:matchstr] = l:syntax_name

    " Note: When use concealed text, wrapped text is wrong...
    " setlocal nowrap
  else
    let l:syntax_name = 'EscapeSequenceAt_' . bufnr('%') . '_' . s:line . '_' . s:col
    let l:syntax_command = printf('start=+\%%%sl\%%%sc+ end=+.*+ contains=ALL oneline', s:line, s:col)

    if !has_key(b:interactive.terminal.syntax_names, s:line)
      let b:interactive.terminal.syntax_names[s:line] = {}
    endif
    if has_key(b:interactive.terminal.syntax_names[s:line], s:col)
      " Clear previous highlight.
      let l:prev_syntax = b:interactive.terminal.syntax_names[s:line][s:col]
      execute 'highlight clear' l:prev_syntax
      execute 'syntax clear' l:prev_syntax
    endif
    let b:interactive.terminal.syntax_names[s:line][s:col] = l:syntax_name

    execute 'syntax region' l:syntax_name l:syntax_command
    execute 'highlight link' l:syntax_name 'Normal'
    execute 'highlight' l:syntax_name l:highlight
  endif
endfunction"}}}
function! s:escape.move_cursor(matchstr)"{{{
  let l:args = split(matchstr(a:matchstr, '[0-9;]\+'), ';')

  let s:line = empty(l:args) ? 1 : l:args[0]
  if !has_key(s:lines, s:line)
    let s:lines[s:line] = ''
  endif

  let l:width = empty(l:args) ? 1 : l:args[1]
  if l:width > len(s:lines[s:line])+1
    let s:lines[s:line] .= repeat(' ', len(s:lines[s:line])+1 - l:width)
  endif
  let s:col = vimshell#util#strwidthpart_len(s:lines[s:line], l:width)
endfunction"}}}
function! s:escape.setup_scrolling_region(matchstr)"{{{
  let l:args = split(matchstr(a:matchstr, '[0-9;]\+'), ';')

  let l:top = empty(l:args) ? 0 : l:args[0]
  let l:bottom = empty(l:args) ? 0 : l:args[1]

  if l:top == 1
    if (vimshell#iswin() && l:bottom == 25)
          \|| (!vimshell#iswin() && l:bottom == b:interactive.height)
      " Clear scrolling region.
      let [l:top, l:bottom] = [0, 0]
    endif
  endif

  let b:interactive.terminal.region_top = l:top
  let b:interactive.terminal.region_bottom = l:bottom
endfunction"}}}
function! s:escape.clear_line(matchstr)"{{{
  " Clear previous highlight.
  call s:clear_highlight_line(s:line)

  let l:param = matchstr(a:matchstr, '\d\+')
  if l:param == '' || l:param == '0'
    " Clear right line.
    let s:lines[s:line] = s:col == 1 ? '' : s:lines[s:line][ : s:col - 2]
  elseif l:param == '1'
    " Clear left line.
    let s:lines[s:line] = s:lines[s:line][s:col - 1 :]
    let s:col = 1
  elseif l:param == '2'
    " Clear whole line.

    let s:lines[s:line] = ''
    let s:col = 1
  endif
endfunction"}}}
function! s:escape.clear_screen(matchstr)"{{{
  let l:param = matchstr(a:matchstr, '\d\+')
  if l:param == '' || l:param == '0'
    " Clear screen from cursor down.
    let s:lines[s:line] = s:col == 1 ? '' : s:lines[s:line][ : s:col - 2]
    for l:linenr in keys(s:lines)
      if l:linenr >= s:line
        " Clear previous highlight.
        call s:clear_highlight_line(s:line)

        " Clear line.
        let s:lines[l:linenr] = ''
      endif
    endfor

    let l:linenr = s:line
    let l:max_line = line('$')
    while l:linenr <= l:max_line
      " Clear previous highlight.
      call s:clear_highlight_line(s:line)

      " Clear line.
      let s:lines[l:linenr] = ''
      let l:linenr += 1
    endwhile

    let s:col = 1
  elseif l:param == '1'
    " Clear screen from cursor up.
    for l:linenr in keys(s:lines)
      if l:linenr <= s:line
        " Clear previous highlight.
        call s:clear_highlight_line(s:line)

        " Clear line.
        let s:lines[l:linenr] = ''
      endif
    endfor

    let l:linenr = 1
    let l:max_line = s:line
    while l:linenr <= l:max_line
      " Clear previous highlight.
      call s:clear_highlight_line(s:line)

      " Clear line.
      let s:lines[l:linenr] = ''
      let l:linenr += 1
    endwhile

    let s:col = 1
  elseif l:param == '2'
    " Clear entire screen.
    let l:reg = @x
    1,$ delete x
    let @x = l:reg

    let s:lines = {}
    let s:line = 1
    let s:col = 1

    call vimshell#terminal#clear_highlight()
  endif
endfunction"}}}
function! s:escape.move_up(matchstr)"{{{
  let n = matchstr(a:matchstr, '\d\+')
  if n == ''
    let n = 1
  endif

  if b:interactive.terminal.region_top <= s:line && s:line <= b:interactive.terminal.region_bottom
    " Scroll up n lines.
    call s:scroll_up(n)
  else
    let s:line -= n
    if s:line < 1
      let s:line = 1
    endif

    if !has_key(s:lines, s:line)
      let s:lines[s:line] = repeat(' ', s:col-1)
    endif
  endif
endfunction"}}}
function! s:escape.move_down(matchstr)"{{{
  let n = matchstr(a:matchstr, '\d\+')
  if n == ''
    let n = 1
  endif

  if b:interactive.terminal.region_top <= s:line && s:line <= b:interactive.terminal.region_bottom
    " Scroll down n lines.
    call s:scroll_down(n)
  else
    let s:line += n

    if !has_key(s:lines, s:line)
      let s:lines[s:line] = repeat(' ', s:col-1)
    endif
  endif
endfunction"}}}
function! s:escape.move_right(matchstr)"{{{
  let n = matchstr(a:matchstr, '\d\+')
  if n == ''
    let n = 1
  endif

  let l:line = s:lines[s:line]
  if s:col+n > len(l:line)+1
    let s:lines[s:line] .= repeat(' ', s:col+n - len(l:line)+1)
    let l:line = s:lines[s:line]
  endif

  let s:col += vimshell#util#strwidthpart_len(l:line[s:col - 1 :], n)
endfunction"}}}
function! s:escape.move_left(matchstr)"{{{
  let n = matchstr(a:matchstr, '\d\+')
  if n == ''
    let n = 1
  endif

  let l:line = s:lines[s:line]
  let s:col -= vimshell#util#strwidthpart_len_reverse(l:line[: s:col - 2], n)
  if s:col < 1
    let s:col = 1
  endif
endfunction"}}}
function! s:escape.move_down_head1(matchstr)"{{{
  call s:control.newline()
endfunction"}}}
function! s:escape.move_down_head(matchstr)"{{{
  call s:control.newline()
endfunction"}}}
function! s:escape.move_up_head(matchstr)"{{{
  let s:col = 1
endfunction"}}}
function! s:escape.scroll_up1(matchstr)"{{{
  call s:scroll_up(1)
endfunction"}}}
function! s:escape.scroll_down1(matchstr)"{{{
  call s:scroll_down(1)
endfunction"}}}
function! s:escape.move_col(matchstr)"{{{
  let s:col = matchstr(a:matchstr, '\d\+')
endfunction"}}}
function! s:escape.save_pos(matchstr)"{{{
  let b:interactive.terminal.save_pos = [s:line, s:col]
endfunction"}}}
function! s:escape.restore_pos(matchstr)"{{{
  let [s:line, s:col] = b:interactive.terminal.save_pos
endfunction"}}}
function! s:escape.change_title(matchstr)"{{{
  let l:title = matchstr(a:matchstr, '^k\zs.\{-}\ze\e\\')
  if empty(l:title)
    let l:title = matchstr(a:matchstr, '^][02];\zs.\{-}\ze'."\<C-g>")
  endif

  let &titlestring = l:title
  let b:interactive.terminal.titlestring = l:title
endfunction"}}}
function! s:escape.print_control_sequence(matchstr)"{{{
  call s:output_string("\<ESC>")
endfunction"}}}
function! s:escape.change_cursor_shape(matchstr)"{{{
  if !exists('+guicursor') || b:interactive.type !=# 'terminal'
    return
  endif

  let l:arg = matchstr(a:matchstr, '\d\+')

  if l:arg == 0 || l:arg == 1
    set guicursor=i:block-Cursor/lCursor
  elseif l:arg == 2
    set guicursor=i:block-Cursor/lCursor-blinkon0
  elseif l:arg == 3
    set guicursor=i:hor20-Cursor/lCursor
  elseif l:arg == 4
    set guicursor=i:hor20-Cursor/lCursor-blinkon0
  endif
endfunction"}}}
function! s:escape.change_character_set(matchstr)"{{{
  if a:matchstr =~ '^[()]0'
    " Line drawing set.
    if a:matchstr =~ '^('
      let b:interactive.terminal.standard_character_set = 'Line Drawing'
    else
      let b:interactive.terminal.alternate_character_set = 'Line Drawing'
    endif
  endif
endfunction"}}}
function! s:escape.reset(matchstr)"{{{
  call s:init_terminal()
endfunction"}}}

" Control sequence functions.
let s:control = {}
function! s:control.ignore()"{{{
endfunction"}}}
function! s:control.newline()"{{{
  let s:col = 1
  call s:escape.move_down(1)
endfunction"}}}
function! s:control.delete_backword_char()"{{{
  if s:line == b:interactive.echoback_linenr
    return
  endif

  if s:col == 1
    " Wrap above line.
    if s:line > 1
      let s:line -= 1
    endif

    if !has_key(s:lines, s:line)
      let s:lines[s:line] = getline(s:line)
    endif

    let s:col = len(s:lines[s:line])
    return
  endif

  call s:escape.move_left(1)
endfunction"}}}
function! s:control.delete_multi_backword_char()"{{{
  if s:line == b:interactive.echoback_linenr
    return
  endif

  if s:col == 1
    " Wrap above line.
    if s:line > 1
      let s:line -= 1
    endif

    if !has_key(s:lines, s:line)
      let s:lines[s:line] = getline(s:line)
    endif

    let s:col = len(s:lines[s:line])
    return
  endif

  call s:escape.move_left(2)
endfunction"}}}
function! s:control.carriage_return()"{{{
  let s:col = 1
endfunction"}}}
function! s:control.bell()"{{{
  echo 'Ring!'
endfunction"}}}
function! s:control.shift_in()"{{{
  let b:interactive.terminal.current_character_set = b:interactive.terminal.standard_character_set
endfunction"}}}
function! s:control.shift_out()"{{{
  let b:interactive.terminal.current_character_set = b:interactive.terminal.alternate_character_set
endfunction"}}}

let s:drawing_character_table = {
      \ 'j' : '+', 'k' : '+', 'l' : '+', 'm' : '+', 'n' : '+',
      \ 'o' : '-', 'p' : '-', 'q' : '-',
      \ 'r' : '_', 's' : '_',
      \ 't' : '+', 'u' : '+', 'v' : '+', 'w' : '+',
      \ 'x' : '|', 'a' : '#', '+' : '^', ',' : '<',
      \ '.' : 'v', 'I' : '0', '-' : '>', '''' : '*',
      \ 'h' : '#', '~' : 'O',
      \ }

" escape sequence list. {{{
" pattern: function
let s:escape_sequence_csi = {
      \ 'l' : s:escape.ignore,
      \ 'h' : s:escape.ignore,
      \
      \ 'm' : s:escape.highlight,
      \ 'r' : s:escape.setup_scrolling_region,
      \ 'A' : s:escape.move_up,
      \ 'B' : s:escape.move_down,
      \ 'C' : s:escape.move_right,
      \ 'D' : s:escape.move_left,
      \ 'E' : s:escape.move_down_head,
      \ 'F' : s:escape.move_up_head,
      \ 'G' : s:escape.move_col,
      \ 'H' : s:escape.move_cursor,
      \ 'f' : s:escape.move_cursor,
      \ 'J' : s:escape.clear_screen,
      \ 'K' : s:escape.clear_line,
      \
      \ 'g' : s:escape.ignore,
      \ 'c' : s:escape.ignore,
      \ 'y' : s:escape.ignore,
      \ 'q' : s:escape.ignore,
      \}
let s:escape_sequence_match = {
      \ '^\[?\d[hl]' : s:escape.ignore,
      \ '^[()][AB012UK]' : s:escape.change_character_set,
      \ '^k.\{-}\e\\' : s:escape.change_title,
      \ '^][02];.\{-}'."\<C-g>" : s:escape.change_title,
      \ '^#\d' : s:escape.ignore,
      \ '^\dn' : s:escape.ignore,
      \ '^\[?1;\d\+0c' : s:escape.ignore,
      \ '^\d q' : s:escape.change_cursor_shape,
      \}
let s:escape_sequence_simple_char1 = {
      \ 'N' : s:escape.ignore,
      \ 'O' : s:escape.ignore,
      \
      \ '7' : s:escape.save_pos,
      \ '8' : s:escape.restore_pos,
      \ '(' : s:escape.ignore,
      \
      \ 'c' : s:escape.reset,
      \
      \ '<' : s:escape.ignore,
      \ '=' : s:escape.ignore,
      \ '>' : s:escape.ignore,
      \
      \ 'E' : s:escape.move_down_head1,
      \ 'G' : s:escape.ignore,
      \ 'I' : s:escape.ignore,
      \ 'J' : s:escape.ignore,
      \ 'K' : s:escape.ignore,
      \ 'D' : s:escape.scroll_up1,
      \ 'M' : s:escape.scroll_down1,
      \
      \ 'Z' : s:escape.ignore,
      \ '%' : s:escape.ignore,
      \}
let s:escape_sequence_simple_char2 = {
      \ '/Z' : s:escape.ignore,
      \ '%@' : s:escape.ignore,
      \ '%G' : s:escape.ignore,
      \ '%8' : s:escape.ignore,
      \ '#8' : s:escape.ignore,
      \}
"}}}
" control sequence list. {{{
" pattern: function
let s:control_sequence = {
      \ "\<LF>" : s:control.newline,
      \ "\<CR>" : s:control.carriage_return,
      \ "\<C-h>" : s:control.delete_backword_char,
      \ "\<Del>" : s:control.ignore,
      \ "\<C-g>" : s:control.bell,
      \ "\<C-o>" : s:control.shift_in,
      \ "\<C-n>" : s:control.shift_out,
      \}
"}}}

" vim: foldmethod=marker
