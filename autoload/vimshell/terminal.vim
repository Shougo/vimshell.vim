"=============================================================================
" FILE: terminal.vim
" AUTHOR:  Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 28 Mar 2012.
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

function! vimshell#terminal#init()"{{{
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
        \ 'is_error' : 0,
        \ 'wrap' : &l:wrap,
        \}

  if s:use_conceal()
    syntax match vimshellEscapeSequenceConceal contained conceal    '\e\[[0-9;]*m'
    syntax match vimshellEscapeSequenceMarker conceal               '\e\[0\?m\|\e0m\['
  endif
endfunction"}}}
function! vimshell#terminal#print(string, is_error)"{{{
  if !has_key(b:interactive, 'terminal')
    call vimshell#terminal#init()
  endif

  setlocal modifiable
  if g:vimshell_enable_debug
    echomsg 'print string = ' . string(a:string)
  endif

  if &filetype ==# 'vimshell' &&
        \ empty(b:vimshell.continuation) && vimshell#check_prompt()
    " Move line.
    call append(line('.'), '')
    normal! j
  endif

  let current_line = getline('.')
  let cur_text = matchstr(getline('.'), '^.*\%' . col('.') . 'c')

  let s:virtual = {
        \ 'lines' : {},
        \ 'col' : 0,
        \ 'line' : 0,
        \ }
  let s:virtual.lines = {}
  let [s:virtual.line, s:virtual.col] = s:get_virtual_col(line('.'), col('.')-1)
  if g:vimshell_enable_debug
    echomsg '[s:virtual.line, s:virtual.col] = ' . string([s:virtual.line, s:virtual.col])
  endif
  let s:virtual.lines[s:virtual.line] = current_line

  if b:interactive.type !=# 'terminal' && a:string !~ '[\e\b]'
    call s:optimized_print(a:string, a:is_error)
    return
  endif

  let b:interactive.terminal.is_error = a:is_error

  let newstr = ''
  let pos = 0
  let max = len(a:string)

  while pos < max
    let char = a:string[pos]

    if char !~ '[[:cntrl:]]'"{{{
      let newstr .= char
      let pos += 1
      continue
      "}}}
    elseif char == "\<C-h>""{{{
      " Print rest string.
      call s:output_string(newstr)
      let newstr = ''

      if pos + 1 < max && a:string[pos+1] == "\<C-h>"
        " <C-h><C-h>
        call s:control.delete_multi_backword_char()
        let pos += 2
      else
        " <C-h>
        call s:control.delete_backword_char()
        let pos += 1
      endif

      continue
      "}}}
    elseif char == "\<ESC>""{{{
      " Check escape sequence.
      let checkstr = a:string[pos+1 :]
      if checkstr == ''
        break
      endif

      " Check CSI pattern.
      if checkstr =~ '^\[[0-9;]*.'
        let matchstr = matchstr(checkstr, '^\[[0-9;]*.')

        if has_key(s:escape_sequence_csi, matchstr[-1:])
          call s:output_string(newstr)
          let newstr = ''

          call call(s:escape_sequence_csi[matchstr[-1:]],
                \ [matchstr], s:escape)

          let pos += len(matchstr) + 1
          continue
        endif
      endif

      " Check simple pattern.
      let checkchar1 = checkstr[0]
      if has_key(s:escape_sequence_simple_char1, checkchar1)"{{{
        call s:output_string(newstr)
        let newstr = ''

        call call(s:escape_sequence_simple_char1[checkchar1], [''], s:escape)

        let pos += 2
        continue
      endif"}}}
      let checkchar2 = checkstr[: 1]
      if checkchar2 != '' && has_key(s:escape_sequence_simple_char2, checkchar2)"{{{
        call s:output_string(newstr)
        let newstr = ''

        call call(s:escape_sequence_simple_char2[checkchar2], [''], s:escape)

        let pos += 3
        continue
      endif"}}}

      let matched = 0
      " Check match pattern.
      for pattern in keys(s:escape_sequence_match)"{{{
        if checkstr =~ pattern
          let matched = 1

          " Print rest string.
          call s:output_string(newstr)
          let newstr = ''

          let matchstr = matchstr(checkstr, pattern)

          call call(s:escape_sequence_match[pattern], [matchstr], s:escape)

          let pos += len(matchstr) + 1
          break
        endif
      endfor"}}}

      if matched
        continue
      endif"}}}
    elseif has_key(s:control_sequence, char)"{{{
      " Check other pattern.
      " Print rest string.
      call s:output_string(newstr)
      let newstr = ''

      call call(s:control_sequence[char], [], s:control)

      let pos += 1
      continue
    endif"}}}

    let newstr .= char
    let pos += 1
  endwhile

  " Print rest string.
  call s:output_string(newstr)

  " Set lines.
  for linenr in sort(map(keys(s:virtual.lines), 'str2nr(v:val)'), 's:sortfunc')
    call setline(linenr, s:virtual.lines[linenr])
  endfor

  call s:set_cursor()
endfunction"}}}
function! vimshell#terminal#set_title()"{{{
  if !has_key(b:interactive, 'terminal')
    call vimshell#terminal#init()
  endif

  let &titlestring = b:interactive.terminal.titlestring
endfunction"}}}
function! vimshell#terminal#restore_title()"{{{
  if !has_key(b:interactive, 'terminal')
    call vimshell#terminal#init()
  endif

  let &titlestring = b:interactive.terminal.titlestring_save
endfunction"}}}
function! vimshell#terminal#clear_highlight()"{{{
  if !has_key(b:interactive, 'terminal')
    call vimshell#terminal#init()
  endif

  for syntax_names in values(b:interactive.terminal.syntax_names)
    if s:use_conceal()
      execute 'highlight clear' syntax_names
      execute 'syntax clear' syntax_names
    else
      for syntax_name in values(syntax_names)
        execute 'highlight clear' syntax_name
        execute 'syntax clear' syntax_name
      endfor
    endif
  endfor

  let b:interactive.terminal.syntax_names = {}

  if s:use_conceal()
    " Restore wrap.
    let &l:wrap = b:interactive.terminal.wrap
  endif
endfunction"}}}

function! s:optimized_print(string, is_error)"{{{
  " Strip <CR>.
  let string = substitute(substitute(a:string, "\<C-g>", '', 'g'),
        \ '\r\+\n', '\n', 'g')

  let lines = split(string, '\n', 1)

  if string =~ '\r'
    call s:print_with_redraw(a:is_error, lines)
  else
    call s:print_simple(a:is_error, lines)
  endif

  normal! $
  let [s:virtual.line, s:virtual.col] = s:get_virtual_col(line('.'), col('.')-1)
  call s:set_cursor()
endfunction"}}}
function! s:print_with_redraw(is_error, lines)"{{{
  let cnt = 1
  for line in a:lines
    if cnt != 1 ||
          \ (s:is_no_echoback() && getline('$') != '')
      call append('.', '')
      normal! j
    endif

    let ls = split(line, '\r', 1)

    if a:is_error
      call map(ls, '"!!!".v:val."!!!"')
    endif

    for l in ls
      call setline('.', l)
      redraw
    endfor

    let cnt += 1
  endfor
endfunction"}}}
function! s:print_simple(is_error, lines)"{{{
  let lines = a:lines

  if a:is_error
    call map(lines, '"!!!".v:val."!!!"')
  endif

  " Optimized print.
  if s:is_no_echoback()
    if line('$') == 1 && getline('$') == ''
      call setline('.', lines[0])
    else
      call append('.', lines[0])
    endif

    normal! j$
  elseif line('.') != b:interactive.echoback_linenr
    call setline('.', getline('.') . lines[0])
  endif

  let lines = lines[1:]

  call append('.', lines)
  execute 'normal!' (len(lines)).'j$'
endfunction"}}}
function! s:set_cursor()"{{{
  " Get real pos(0 origin).
  let [line, col] = s:get_real_pos(s:virtual.line, s:virtual.col)
  call s:set_screen_pos(line, col)

  " Convert to 1 origin.
  let col += 1

  if g:vimshell_enable_debug
    echomsg 'set cursor = ' . string([line, col])
  endif

  " Move pos.
  call cursor(line, col)

  if b:interactive.type ==# 'terminal'
    let b:interactive.save_cursor = getpos('.')
  endif

  redraw
endfunction"}}}
function! s:is_no_echoback()
  return b:interactive.type ==# 'interactive'
          \ && vimshell#util#is_windows()
          \ && has_key(b:interactive, 'command')
          \ && !get(g:vimshell_interactive_echoback_commands,
          \        b:interactive.command, 0)
endfunction

function! s:init_terminal()"{{{
endfunction"}}}
function! s:output_string(string)"{{{
  if s:virtual.line == b:interactive.echoback_linenr
    if s:is_no_echoback()
      " no echoback command.
      let s:virtual.line += 1
      let s:virtual.lines[s:virtual.line] = a:string
      let s:virtual.col = len(a:string)
    endif

    return
  endif

  if a:string == ''
    return
  endif

  let string = b:interactive.terminal.is_error ?
        \ '!!!' . a:string . '!!!' : a:string

  if b:interactive.terminal.current_character_set ==# 'Line Drawing'
    " Convert characters.
    let string = ''
    for c in split(a:string, '\zs')
      let string .= has_key(s:drawing_character_table, c)?
            \ s:drawing_character_table[c] : c
    endfor
  endif

  call s:set_screen_string(s:virtual.line, s:virtual.col, string)
endfunction"}}}
function! s:sortfunc(i1, i2)"{{{
  return a:i1 == a:i2 ? 0 : a:i1 > a:i2 ? 1 : -1
endfunction"}}}
function! s:scroll_up(number)"{{{
  let line = b:interactive.terminal.region_bottom
  let end = b:interactive.terminal.region_top - a:number
  while line >= end
    let s:virtual.lines[line] = has_key(s:virtual.lines, line - a:number) ?
          \ s:virtual.lines[line - a:number] : getline(line - a:number)

    let line -= 1
  endwhile

  let i = 0
  while i < a:number
    " Clear previous highlight.
    call s:clear_highlight_line(b:interactive.terminal.region_top + i)

    let s:virtual.lines[b:interactive.terminal.region_top + i] = ''
    let i += 1
  endwhile
endfunction"}}}
function! s:scroll_down(number)"{{{
  let line = b:interactive.terminal.region_top
  let end = b:interactive.terminal.region_bottom - a:number
  while line <= end
    let s:virtual.lines[line] = has_key(s:virtual.lines, line + a:number) ?
          \ s:virtual.lines[line + a:number] : getline(line + a:number)

    let line += 1
  endwhile

  let i = 0
  while i < a:number
    " Clear previous highlight.
    call s:clear_highlight_line(b:interactive.terminal.region_bottom - i)

    let s:virtual.lines[b:interactive.terminal.region_bottom - i] = ''
    let i += 1
  endwhile
endfunction"}}}
function! s:clear_highlight_line(linenr)"{{{
  if s:use_conceal()
    return
  endif

  if has_key(b:interactive.terminal.syntax_names, a:linenr)
    for [col, prev_syntax] in items(b:interactive.terminal.syntax_names[a:linenr])
      execute 'highlight clear' prev_syntax
      execute 'syntax clear' prev_syntax
    endfor
  endif
endfunction"}}}
function! s:use_conceal()"{{{
  return has('conceal') && b:interactive.type !=# 'terminal'
endfunction"}}}

" Note: Real pos is 0 origin.
function! s:get_real_pos(line, col)"{{{
  let current_line = get(s:virtual.lines, a:line, getline(a:line))
  if a:col <= 1 && current_line !~ '\e\[[0-9;]*m'
    return [a:line, 0]
  endif

  return s:get_col(a:line, a:col, 0)
endfunction"}}}
function! s:get_virtual_col(line, col)"{{{
  let current_line = get(s:virtual.lines, a:line, getline(a:line))
  if a:col <= 0 && current_line !~ '\e\[[0-9;]*m'
    return [a:line, 1]
  endif

  return s:get_col(a:line, a:col, 1)
endfunction"}}}
function! s:get_col(line, col, is_virtual)"{{{
  " is_virtual -> a:col : real col.
  " not -> a:col : virtual col.
  let col = 1
  let real_col = 0

  let current_line = get(s:virtual.lines, a:line, getline(a:line))
  if current_line =~ '^ \+'
    " Optimized.
    let spaces = len(matchstr(current_line, '^ \+'))
    let col += spaces
    let real_col += spaces

    let check_col = a:is_virtual ? real_col : col
    if check_col > a:col
      let col -= check_col - a:col
      let real_col -= check_col - a:col
    endif

    let current_line = current_line[real_col :]
  endif

  if current_line !~ '\e\[[0-9;]*m'
    " Optimized.
    for c in split(current_line[: a:col*3], '\zs')
      let real_col += len(c)
      let col += vimshell#util#wcswidth(c)

      let check_col = a:is_virtual ? real_col : col
      if check_col > a:col
        break
      endif
    endfor
  else
    let skip_cnt = 0
    for c in split(current_line, '\zs')
      if skip_cnt > 0
        let skip_cnt -= 1
        continue
      endif

      if c == "\<ESC>"
            \ && current_line[real_col :] =~ '^\e\[[0-9;]*m'
        " Skip.
        let sequence = matchstr(current_line, '^\e\[[0-9;]*m', real_col)
        let skip_cnt = len(sequence)-1
        let real_col += len(sequence)
      else
        let real_col += len(c)
        let col += vimshell#util#wcswidth(c)
      endif

      let check_col = a:is_virtual ? real_col : col
      if check_col > a:col
        break
      endif
    endfor
  endif

  let check_col = a:is_virtual ? real_col : col
  " current_line is too short.
  if check_col < a:col
    if a:is_virtual
      let col += a:col - real_col
    else
      let real_col += a:col - col
    endif
  endif

  return [a:line, (a:is_virtual ? col : real_col)]
endfunction"}}}
function! s:get_screen_character(line, col)"{{{
  let [line, col] = s:get_real_pos(a:line, a:col)
  return s:virtual.lines[line][col]
endfunction"}}}
function! s:get_virtual_wcswidth(string)"{{{
  return vimshell#util#wcswidth(
        \ substitute(a:string, '\e\[[0-9;]*m', '', 'g'))
endfunction"}}}
function! s:set_screen_string(line, col, string)"{{{
  let [line, col] = s:get_real_pos(a:line, a:col)
  call s:set_screen_pos(line, col)

  let current_line = s:virtual.lines[line]
  let len = vimshell#util#wcswidth(a:string)
  let s:virtual.lines[line] = current_line[ : col]  .  a:string
        \             . current_line[col+len :]
  let len2 = s:get_virtual_wcswidth(a:string)
  let s:virtual.col += len2

  " let [s:virtual.line, s:virtual.col] = s:get_virtual_col(line, col+len)
  if g:vimshell_enable_debug
    echomsg 'current_line = ' . current_line
    echomsg 'current_line[col:] = ' . current_line[col :]
    echomsg '[virt_col, real_col, string] = ' .
          \ string([a:col, col, s:virtual.col, a:string])
  endif
endfunction"}}}
function! s:set_screen_pos(line, col)"{{{
  if !has_key(s:virtual.lines, a:line)
    let s:virtual.lines[a:line] = ''
  endif
  if a:col > len(s:virtual.lines[a:line])
    let s:virtual.lines[a:line] .= repeat(' ', a:col - len(s:virtual.lines[a:line]))
  endif
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
      \ '0' : ' cterm=NONE ctermfg=NONE ctermbg=NONE gui=NONE guifg=NONE guibg=NONE',
      \ '1' : ' cterm=BOLD gui=BOLD',
      \ '3' : ' cterm=ITALIC gui=ITALIC',
      \ '4' : ' cterm=UNDERLINE gui=UNDERLINE',
      \ '7' : ' cterm=REVERSE gui=REVERSE',
      \ '8' : ' ctermfg=0 ctermbg=0 guifg=#000000 guibg=#000000',
      \ '9' : ' gui=UNDERCURL',
      \ '21' : ' cterm=UNDERLINE gui=UNDERLINE',
      \ '22' : ' gui=NONE',
      \ '23' : ' gui=NONE',
      \ '24' : ' gui=NONE',
      \ '25' : ' gui=NONE',
      \ '27' : ' gui=NONE',
      \ '28' : ' ctermfg=NONE ctermbg=NONE guifg=NONE guibg=NONE',
      \ '29' : ' gui=NONE',
      \ '39' : ' ctermfg=NONE guifg=NONE', 
      \ '49' : ' ctermbg=NONE guibg=NONE', 
      \}"}}}
function! s:escape.highlight(matchstr)"{{{
  if g:vimshell_disable_escape_highlight
        \ || (b:interactive.type == 'interactive' &&
        \     get(g:vimshell_interactive_monochrome_commands,
        \         b:interactive.command, 0))
        \ || b:interactive.terminal.is_error
    return
  endif

  if s:use_conceal()
    call s:output_string("\<ESC>" . a:matchstr)

    " Check cached highlight.
    if a:matchstr =~ '^\[0\?m$'
          \ || has_key(b:interactive.terminal.syntax_names, a:matchstr)
      return
    endif
  endif

  let highlight = ''
  let highlight_list =
        \ split(matchstr(a:matchstr, '^\[\zs[0-9;]\+'), ';')
  let cnt = 0
  if empty(highlight_list)
    " Default.
    let highlight_list = [ 0 ]
  endif
  for color_code in map(highlight_list, 'str2nr(v:val)')
    if has_key(s:highlight_table, color_code)"{{{
      " Use table.
      let highlight .= s:highlight_table[color_code]
    elseif 30 <= color_code && color_code <= 37
      " Foreground color.
      let highlight .= printf(' ctermfg=%d guifg=%s',
            \ color_code - 30, g:vimshell_escape_colors[color_code - 30])
    elseif color_code == 38
      if len(highlight_list) - cnt < 3
        " Error.
        break
      endif

      " Foreground 256 colors.
      let color = highlight_list[cnt + 2]
      if color >= 232
        " Grey scale.
        let gcolor = s:grey_table[(color - 232)]
        let highlight .= printf(' ctermfg=%d guifg=#%02x%02x%02x',
              \ color, gcolor, gcolor, gcolor)
      elseif color >= 16
        " RGB.
        let gcolor = color - 16
        let red = s:color_table[gcolor / 36]
        let green = s:color_table[(gcolor % 36) / 6]
        let blue = s:color_table[gcolor % 6]

        let highlight .= printf(' ctermfg=%d guifg=#%02x%02x%02x',
              \ color, red, green, blue)
      else
        let highlight .= printf(' ctermfg=%d guifg=%s',
              \ color, g:vimshell_escape_colors[color])
      endif
      break
    elseif 40 <= color_code && color_code <= 47
      " Background color.
      let highlight .= printf(' ctermbg=%d guibg=%s',
            \ color_code - 40, g:vimshell_escape_colors[color_code - 40])
    elseif color_code == 48
      if len(highlight_list) - cnt < 3
        " Error.
        break
      endif

      " Background 256 colors.
      let color = highlight_list[cnt + 2]
      if color >= 232
        " Grey scale.
        let gcolor = s:grey_table[(color - 232)]
        let highlight .= printf(' ctermbg=%d guibg=#%02x%02x%02x',
              \ color, gcolor, gcolor, gcolor)
      elseif color >= 16
        " RGB.
        let gcolor = color - 16
        let red = s:color_table[gcolor / 36]
        let green = s:color_table[(gcolor % 36) / 6]
        let blue = s:color_table[gcolor % 6]

        let highlight .= printf(' ctermbg=%d guibg=#%02x%02x%02x',
              \ color, red, green, blue)
      else
        let highlight .= printf(' ctermbg=%d guibg=%s',
              \ color, g:vimshell_escape_colors[color])
      endif
      break
    elseif 90 <= color_code && color_code <= 97
      " Foreground color(high intensity).
      let highlight .= printf(' ctermfg=%d guifg=%s',
            \ color_code - 82, g:vimshell_escape_colors[color_code - 82])
    elseif 100 <= color_code && color_code <= 107
      " Background color(high intensity).
      let highlight .= printf(' ctermbg=%d guibg=%s',
            \ color_code - 92, g:vimshell_escape_colors[color_code - 92])
    endif"}}}

    let cnt += 1
  endfor

  if highlight == ''
    return
  endif

  let [line, col] = s:get_real_pos(s:virtual.line, s:virtual.col)
  let col += 1
  if s:use_conceal()
    let syntax_name = 'EscapeSequenceAt_' . bufnr('%')
          \ . '_' . line . '_' . col
    let syntax_command = printf('start=+\e\%s+ end=+\e[\[0]+me=e-2 ' .
          \ 'contains=vimshellEscapeSequenceConceal', a:matchstr)

    execute 'syntax region' syntax_name syntax_command
    execute 'highlight' syntax_name highlight

    let b:interactive.terminal.syntax_names[a:matchstr] = syntax_name

    " Note: When use concealed text, wrapped text is wrong...
    setlocal nowrap
  else
    let syntax_name = 'EscapeSequenceAt_' . bufnr('%')
          \ . '_' . line . '_' . (col+1)
    let syntax_command = printf(
          \ 'start=+\%%%sl\%%%sc+ end=+.*+ contains=ALL', line, col)

    if !has_key(b:interactive.terminal.syntax_names, line)
      let b:interactive.terminal.syntax_names[line] = {}
    endif
    if has_key(b:interactive.terminal.syntax_names[line], col)
      " Clear previous highlight.
      let prev_syntax =
            \ b:interactive.terminal.syntax_names[line][col]
      execute 'highlight clear' prev_syntax
      execute 'syntax clear' prev_syntax
    endif
    let b:interactive.terminal.syntax_names[line][col] = syntax_name

    execute 'syntax region' syntax_name syntax_command
    execute 'highlight link' syntax_name 'Normal'
    execute 'highlight' syntax_name highlight
  endif
endfunction"}}}
function! s:escape.move_cursor(matchstr)"{{{
  let args = split(matchstr(a:matchstr, '[0-9;]\+'), ';')

  let s:virtual.line = get(args, 0, 1)
  let s:virtual.col = get(args, 1, 1)

  let [line, col] = s:get_real_pos(s:virtual.line, s:virtual.col)
  call s:set_screen_pos(line, col)
endfunction"}}}
function! s:escape.move_cursor_column(matchstr)"{{{
  let n = matchstr(a:matchstr, '\d\+')
  if n == ''
    let n = 1
  endif

  let s:virtual.col = n

  let [line, col] = s:get_real_pos(s:virtual.line, s:virtual.col)
  call s:set_screen_pos(line, col)
endfunction"}}}
function! s:escape.setup_scrolling_region(matchstr)"{{{
  let args = split(matchstr(a:matchstr, '[0-9;]\+'), ';')

  let top = empty(args) ? 0 : args[0]
  let bottom = empty(args) ? 0 : args[1]

  if top == 1
    if (vimshell#util#is_windows() && bottom == 25)
          \|| (!vimshell#util#is_windows() && bottom == b:interactive.height)
      " Clear scrolling region.
      let [top, bottom] = [0, 0]
    endif
  endif

  let b:interactive.terminal.region_top = top
  let b:interactive.terminal.region_bottom = bottom
endfunction"}}}
function! s:escape.clear_line(matchstr)"{{{
  " Clear previous highlight.
  call s:clear_highlight_line(s:virtual.line)

  let [line, col] = s:get_real_pos(s:virtual.line, s:virtual.col)
  call s:set_screen_pos(line, col)

  let param = matchstr(a:matchstr, '\d\+')
  if param == '' || param == '0'
    " Clear right line.
    let s:virtual.lines[line] = (col <= 0) ? '' : s:virtual.lines[line][ : col - 1]
  elseif param == '1'
    " Clear left line.
    let s:virtual.lines[line] = s:virtual.lines[line][col :]
    let s:virtual.col = 1
  elseif param == '2'
    " Clear whole line.
    let s:virtual.lines[line] = ''
    let s:virtual.col = 1
  endif
endfunction"}}}
function! s:escape.clear_screen(matchstr)"{{{
  let param = matchstr(a:matchstr, '\d\+')
  if param == '' || param == '0'
    " Clear screen from cursor down.
    call s:escape.clear_line(0)
    for linenr in filter(keys(s:virtual.lines), 'v:val > s:virtual.line')
      " Clear previous highlight.
      call s:clear_highlight_line(s:virtual.line)

      " Clear line.
      let s:virtual.lines[linenr] = ''
    endfor
  elseif param == '1'
    " Clear screen from cursor up.
    call s:escape.clear_line(1)
    for linenr in filter(keys(s:virtual.lines), 'v:val < s:virtual.line')
      " Clear previous highlight.
      call s:clear_highlight_line(s:virtual.line)

      " Clear line.
      let s:virtual.lines[linenr] = ''
    endfor
  elseif param == '2'
    " Clear entire screen.
    let reg = @x
    1,$ delete x
    let @x = reg

    let s:virtual.lines = {}
    let s:virtual.line = 1
    let s:virtual.col = 1

    call vimshell#terminal#clear_highlight()
  endif
endfunction"}}}
function! s:escape.move_up(matchstr)"{{{
  let n = matchstr(a:matchstr, '\d\+')
  if n == ''
    let n = 1
  endif

  if b:interactive.terminal.region_top <= s:virtual.line
        \ && s:virtual.line <= b:interactive.terminal.region_bottom
    " Scroll up n lines.
    call s:scroll_up(n)
  else
    let s:virtual.line -= n
    if s:virtual.line < 1
      let s:virtual.line = 1
    endif
  endif
endfunction"}}}
function! s:escape.move_down(matchstr)"{{{
  let n = matchstr(a:matchstr, '\d\+')
  if n == ''
    let n = 1
  endif

  if b:interactive.terminal.region_top <= s:virtual.line
        \ && s:virtual.line <= b:interactive.terminal.region_bottom
    " Scroll down n lines.
    call s:scroll_down(n)
  else
    let s:virtual.line += n
  endif
endfunction"}}}
function! s:escape.move_right(matchstr)"{{{
  let n = matchstr(a:matchstr, '\d\+')
  if n == ''
    let n = 1
  endif

  let s:virtual.col += n
endfunction"}}}
function! s:escape.move_left(matchstr)"{{{
  let n = matchstr(a:matchstr, '\d\+')
  if n == ''
    let n = 1
  endif

  let s:virtual.col -= n
  if s:virtual.col < 1
    let s:virtual.col = 1
  endif
endfunction"}}}
function! s:escape.move_down_head1(matchstr)"{{{
  call s:control.newline()
endfunction"}}}
function! s:escape.move_down_head(matchstr)"{{{
  call s:scroll_down(a:matchstr)
  let s:virtual.col = 1
endfunction"}}}
function! s:escape.move_up_head(matchstr)"{{{
  let param = matchstr(a:matchstr, '\d\+')
  if param != '0'
    call s:scroll_up(a:matchstr)
  endif
  let s:virtual.col = 1
endfunction"}}}
function! s:escape.scroll_up1(matchstr)"{{{
  call s:scroll_up(1)
endfunction"}}}
function! s:escape.scroll_down1(matchstr)"{{{
  call s:scroll_down(1)
endfunction"}}}
function! s:escape.move_col(matchstr)"{{{
  let num = matchstr(a:matchstr, '\d\+')
  let s:virtual.col = num
  if s:virtual.col < 1
    let s:virtual.col = 1
  endif
endfunction"}}}
function! s:escape.save_pos(matchstr)"{{{
  let b:interactive.terminal.save_pos = [s:virtual.line, s:virtual.col]
endfunction"}}}
function! s:escape.restore_pos(matchstr)"{{{
  let [s:virtual.line, s:virtual.col] = b:interactive.terminal.save_pos
endfunction"}}}
function! s:escape.change_title(matchstr)"{{{
  let title = matchstr(a:matchstr, '^k\zs.\{-}\ze\e\\')
  if empty(title)
    let title = matchstr(a:matchstr, '^][02];\zs.\{-}\ze'."\<C-g>")
  endif

  let &titlestring = title
  let b:interactive.terminal.titlestring = title
endfunction"}}}
function! s:escape.print_control_sequence(matchstr)"{{{
  call s:output_string("\<ESC>")
endfunction"}}}
function! s:escape.change_cursor_shape(matchstr)"{{{
  if !exists('+guicursor') || b:interactive.type !=# 'terminal'
    return
  endif

  let arg = matchstr(a:matchstr, '\d\+')

  if arg == 0 || arg == 1
    set guicursor=i:block-Cursor/lCursor
  elseif arg == 2
    set guicursor=i:block-Cursor/lCursor-blinkon0
  elseif arg == 3
    set guicursor=i:hor20-Cursor/lCursor
  elseif arg == 4
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
  call vimshell#terminal#init()
endfunction"}}}
function! s:escape.delete_chars(matchstr)"{{{
  let n = matchstr(a:matchstr, '\d\+')
  if n == ''
    let n = 1
  endif

  call s:escape.move_left(n)
  call s:output_string(repeat(' ', n))
endfunction"}}}

" Control sequence functions.
let s:control = {}
function! s:control.ignore()"{{{
endfunction"}}}
function! s:control.newline()"{{{
  let s:virtual.col = 1

  if b:interactive.type !=# 'terminal'
    " New line.
    call append(s:virtual.line, '')
  endif

  call s:escape.move_down(1)
endfunction"}}}
function! s:control.delete_backword_char()"{{{
  if s:virtual.line == b:interactive.echoback_linenr
    return
  endif

  if s:virtual.col == 1
    " Wrap above line.
    if s:virtual.line > 1
      let s:virtual.line -= 1
    endif

    if !has_key(s:virtual.lines, s:virtual.line)
      let s:virtual.lines[s:virtual.line] = getline(s:virtual.line)
    endif

    let [line, s:virtual.col] = s:get_virtual_col(s:virtual.line, len(s:virtual.lines[s:virtual.line]))
    return
  endif

  call s:escape.move_left(1)
endfunction"}}}
function! s:control.delete_multi_backword_char()"{{{
  if s:virtual.line == b:interactive.echoback_linenr
    return
  endif

  if s:virtual.col == 1
    " Wrap above line.
    if s:virtual.line > 1
      let s:virtual.line -= 1
    endif

    if !has_key(s:virtual.lines, s:virtual.line)
      let s:virtual.lines[s:virtual.line] = getline(s:virtual.line)
    endif

    let s:virtual.col = len(s:virtual.lines[s:virtual.line])
    return
  endif

  call s:escape.move_left(2)
endfunction"}}}
function! s:control.carriage_return()"{{{
  let s:virtual.col = 1
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
      \ 'P' : s:escape.delete_chars,
      \
      \ 'g' : s:escape.ignore,
      \ 'c' : s:escape.ignore,
      \ 'd' : s:escape.move_cursor_column,
      \ 'y' : s:escape.ignore,
      \ 'q' : s:escape.ignore,
      \}
let s:escape_sequence_match = {
      \ '^\[?\d\+[hl]' : s:escape.ignore,
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
      \ "\<C-a>" : s:control.ignore,
      \ "\<C-b>" : s:control.ignore,
      \}
"}}}

" vim: foldmethod=marker
