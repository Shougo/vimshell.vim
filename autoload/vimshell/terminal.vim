"=============================================================================
" FILE: terminal.vim
" AUTHOR:  Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 12 Jul 2010
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

function! vimshell#terminal#print(string)"{{{
  setlocal modifiable
  
  "echomsg a:string
  if &filetype !=# 'vimshell-term' && a:string !~ '[\e\r\b]' && col('.') == col('$')
    " Optimized print.
    let l:lines = split(a:string, '\n', 1)
    if !exists('b:interactive') || line('.') != b:interactive.echoback_linenr
      call setline('.', getline('.') . l:lines[0])
    endif
    call append('.', l:lines[1:])
    execute 'normal!' (len(l:lines)-1).'j$'
    
    return
  endif

  if !has_key(b:interactive, 'terminal')
    call s:init_terminal()
  endif
  
  let l:newstr = ''
  let l:pos = 0
  let l:max = len(a:string)
  let s:line = line('.')
  let s:col = col('.')
  let s:lines = {}
  let s:lines[s:line] = getline('.')
  let s:save_pos = [s:line, s:col]
  let s:scrolls = 0
  
  while l:pos < l:max
    let l:char = a:string[l:pos]
    if l:char !~ '[[:cntrl:]]'"{{{
      let l:newstr .= l:char
      let l:pos += 1
      continue
      "}}}
    elseif l:char == "\<ESC>""{{{
      " Check escape sequence.
      let l:checkstr = a:string[l:pos+1 :]
      if l:checkstr == ''
        break
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
      let l:checkchar3 = l:checkstr[: 2]
      if l:checkchar3 != '' && has_key(s:escape_sequence_simple_char3, l:checkchar3)"{{{
        call s:output_string(l:newstr)
        let l:newstr = ''

        call call(s:escape_sequence_simple_char3[l:checkchar3], [''], s:escape)

        let l:pos += 4
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
  for [l:linenr, l:line] in items(s:lines)
    call setline(l:linenr, l:line)
  endfor
  let s:lines = {}
  
  " Scroll.
  if s:scrolls > 0
    execute 'normal' s:scrolls."\<C-e>"
  elseif s:scrolls < 0
    execute 'normal' (-s:scrolls)."\<C-y>"
  endif
  
  let l:oldpos = getpos('.')
  let l:oldpos[1] = s:line
  let l:oldpos[2] = s:col
  
  if &filetype ==# 'vimshell-term'
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
function! vimshell#terminal#filter(string)"{{{
  if a:string !~ '[[:cntrl:]]'
    return a:string
  endif
  
  let l:newstr = ''
  let l:pos = 0
  let l:max = len(a:string)
  while l:pos < l:max
    let l:matched = 0
    
    let l:char = a:string[l:pos]
    if l:char !~ '[[:cntrl:]]'"{{{
      let l:newstr .= l:char
      let l:pos += 1

      continue"}}}
    elseif l:char == "\<ESC>""{{{
      let l:checkstr = a:string[l:pos+1 :]
      if l:checkstr == ''
        break
      endif
      
      " Check simple pattern.
      let l:checkchar1 = l:checkstr[0]
      if has_key(s:escape_sequence_simple_char1, l:checkchar1)"{{{
        let l:pos += 2
        continue
      endif"}}}
      let l:checkchar2 = l:checkstr[: 1]
      if l:checkchar2 != '' && has_key(s:escape_sequence_simple_char2, l:checkchar2)"{{{
        let l:pos += 3
        continue
      endif"}}}
      let l:checkchar3 = l:checkstr[: 2]
      if l:checkchar3 != '' && has_key(s:escape_sequence_simple_char3, l:checkchar3)"{{{
        let l:pos += 4
        continue
      endif"}}}

      let l:matched = 0
      " Check match pattern.
      for l:pattern in keys(s:escape_sequence_match)"{{{
        if l:checkstr =~ l:pattern
          let l:matched = 1
          let l:pos += len(matchstr(l:checkstr, l:pattern)) + 1
          break
        endif
      endfor"}}}
      
      if l:matched
        continue
      endif"}}}
    elseif has_key(s:control_sequence, l:char)"{{{
      let l:pos += 1
      continue
    endif"}}}
    
    let l:newstr .= a:string[l:pos]
    let l:pos += 1
  endwhile

  return l:newstr
endfunction"}}}
function! vimshell#terminal#set_title()"{{{
  if !exists('b:interactive')
    return
  endif
  
  if !has_key(b:interactive, 'terminal')
    call s:init_terminal()
  endif

  let &titlestring = b:interactive.terminal.titlestring
endfunction"}}}
function! vimshell#terminal#restore_title()"{{{
  if !exists('b:interactive')
    return
  endif
  
  if !has_key(b:interactive, 'terminal')
    call s:init_terminal()
  endif

  let &titlestring = b:interactive.terminal.titlestring_save
endfunction"}}}
function! vimshell#terminal#clear_highlight()"{{{
  if !exists('b:interactive')
    return
  endif
  
  if !has_key(b:interactive, 'terminal')
    call s:init_terminal()
  endif
  
  for l:syntax_names in values(b:interactive.terminal.syntax_names)
    for l:syntax_name in values(l:syntax_names)
      execute 'highlight clear' l:syntax_name
      execute 'syntax clear' l:syntax_name
    endfor
  endfor
endfunction"}}}
function! s:init_terminal()"{{{
  let b:interactive.terminal = {
        \ 'syntax_names' : {},
        \ 'titlestring' : &titlestring,
        \ 'titlestring_save' : &titlestring,
        \}
  return
endfunction"}}}
function! s:output_string(string)"{{{
  if exists('b:interactive') && s:line == b:interactive.echoback_linenr
    if !b:interactive.is_pty && &filetype ==# 'int-gosh'
      " Note: MinGW gosh is no echoback. Why?
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
  
  if !has_key(s:lines, s:line)
    let s:lines[s:line] = ''
  endif
  let l:line = s:lines[s:line]
  let l:left_line = l:line[: s:col - 2]
  let l:right_line = l:line[s:col-1+len(a:string) :]

  let s:lines[s:line] = (s:col == 1)? a:string . l:right_line : l:left_line . a:string . l:right_line
  
  let s:col += len(a:string)
endfunction"}}}

" Escape sequence functions.
let s:escape = {}
function! s:escape.ignore(matchstr)"{{{
endfunction"}}}

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
      \}
function! s:escape.highlight(matchstr)"{{{
  let l:syntax_name = 'EscapeSequenceAt_' . bufnr('%') . '_' . s:line . '_' . s:col
  
  let l:syntax_command = printf('start=+\%%%sl\%%%sc+ end=+.*+ contains=ALL oneline', s:line, s:col)

  let l:highlight = ''
  let l:highlight_list = split(matchstr(a:matchstr, '^\[\zs[0-9;]\+'), ';')
  let l:cnt = 0
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
  
  if l:highlight != '' && !g:vimshell_disable_escape_highlight
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
function! s:escape.highlight_restore(matchstr)"{{{
  call s:escape.highlight('[0m')
endfunction"}}}
function! s:escape.move_cursor(matchstr)"{{{
  let l:args = split(matchstr(a:matchstr, '[0-9;]\+'), ';')
  
  let s:line = l:args[0]
  let s:col = l:args[1]
  if !has_key(s:lines, s:line)
    let s:lines[s:line] = ''
  endif
  if s:col > len(s:lines[s:line])+1
    let s:lines[s:line] .= repeat(' ', len(s:lines[s:line])+1 - s:col)
  endif
endfunction"}}}
function! s:escape.setup_window(matchstr)"{{{
  let l:args = split(matchstr(a:matchstr, '[0-9;]\+'), ';')
  
  let l:min_line = l:args[0]
  let l:max_line = l:args[1]
  let l:linenr = l:min_line
  while l:linenr <= l:max_line
    let s:lines[l:linenr] = ''
    let l:linenr += 1
  endwhile
  let s:line = l:min_line
endfunction"}}}
function! s:escape.delete_whole_line(matchstr)"{{{
  let s:lines[s:line] = ''
  let s:col = 1
endfunction"}}}
function! s:escape.delete_right_line(matchstr)"{{{
  let s:lines[s:line] = s:col == 1 ? '' : s:lines[s:line][ : s:col-2]
endfunction"}}}
function! s:escape.delete_left_line(matchstr)"{{{
  let s:lines[s:line] = s:lines[s:line][s:col-1 :]
  let s:col = 1
endfunction"}}}
function! s:escape.clear_entire_screen(matchstr)"{{{
  let l:reg = @x
  1,$ delete x
  let @x = l:reg

  let s:lines = {}
  let s:line = 1
  let s:col = 1
endfunction"}}}
function! s:escape.clear_screen_from_cursor_down(matchstr)"{{{
  for l:linenr in keys(s:lines)
    if l:linenr >= s:line
      " Clear line.
      let s:lines[l:linenr] = ''
    endif
  endfor

  let l:linenr = s:line
  let l:max_line = line('$')
  while l:linenr <= l:max_line
    " Clear line.
    let s:lines[l:linenr] = ''
    let l:linenr += 1
  endwhile
  
  let s:col = 1
endfunction"}}}
function! s:escape.clear_screen_from_cursor_up(matchstr)"{{{
  for l:linenr in keys(s:lines)
    if l:linenr <= s:line
      " Clear line.
      let s:lines[l:linenr] = ''
    endif
  endfor
  
  let l:linenr = 1
  let l:max_line = s:line
  while l:linenr <= l:max_line
    " Clear line.
    let s:lines[l:linenr] = ''
    let l:linenr += 1
  endwhile

  let s:col = 1
endfunction"}}}
function! s:escape.move_cursor_home(matchstr)"{{{
  let s:line = 1
  let s:col = 1
  if !has_key(s:lines, s:line)
    let s:lines[s:line] = ''
  endif
endfunction"}}}
function! s:escape.move_head(matchstr)"{{{
  let s:col = 1
endfunction"}}}
function! s:escape.move_up1(matchstr)"{{{
  let s:line -= 1
  if s:line < 1
    let s:line = 1
  endif

  if !has_key(s:lines, s:line)
    let s:lines[s:line] = repeat(' ', s:col)
  endif
endfunction"}}}
function! s:escape.move_up(matchstr)"{{{
  let n = matchstr(a:matchstr, '\d\+')
  if n == ''
    let n = 1
  endif
  
  let s:line -= n
  if s:line < 1
    let s:line = 1
  endif
  
  if !has_key(s:lines, s:line)
    let s:lines[s:line] = repeat(' ', s:col)
  endif
endfunction"}}}
function! s:escape.move_down1(matchstr)"{{{
  let s:line += 1

  if !has_key(s:lines, s:line)
    let s:lines[s:line] = repeat(' ', s:col)
  endif
endfunction"}}}
function! s:escape.move_down(matchstr)"{{{
  let n = matchstr(a:matchstr, '\d\+')
  if n == ''
    let n = 1
  endif
  
  let s:line += n

  if !has_key(s:lines, s:line)
    let s:lines[s:line] = repeat(' ', s:col)
  endif
endfunction"}}}
function! s:escape.move_right1(matchstr)"{{{
  let s:col += 1
  
  if s:col > len(s:lines[s:line])+1
    let s:lines[s:line] .= repeat(' ', len(s:lines[s:line])+1 - s:col)
  endif
endfunction"}}}
function! s:escape.move_right(matchstr)"{{{
  let n = matchstr(a:matchstr, '\d\+')
  if n == ''
    let n = 1
  endif
  
  let s:col += n
  
  if s:col > len(s:lines[s:line])+1
    let s:lines[s:line] .= repeat(' ', s:col - len(s:lines[s:line])+1)
  endif
endfunction"}}}
function! s:escape.move_left1(matchstr)"{{{
  let s:col -= 1
  if s:col < 1
    let s:col = 1
  endif
endfunction"}}}
function! s:escape.move_left(matchstr)"{{{
  let n = matchstr(a:matchstr, '\d\+')
  if n == ''
    let n = 1
  endif
  
  let s:col -= n
  if s:col < 1
    let s:col = 1
  endif
endfunction"}}}
function! s:escape.move_down_head1(matchstr)"{{{
  call s:escape.move_down1(a:matchstr)
  let s:col = 1
endfunction"}}}
function! s:escape.move_down_head(matchstr)"{{{
  call s:escape.move_down(a:matchstr)
  let s:col = 1
endfunction"}}}
function! s:escape.move_up_head1(matchstr)"{{{
  call s:escape.move_up1(a:matchstr)
  let s:col = 1
endfunction"}}}
function! s:escape.move_up_head(matchstr)"{{{
  let s:col = 1
endfunction"}}}
function! s:escape.scroll_up1(matchstr)"{{{
  let s:scrolls -= 1
endfunction"}}}
function! s:escape.scroll_down1(matchstr)"{{{
  let s:scrolls += 1
endfunction"}}}
function! s:escape.move_col(matchstr)"{{{
  let s:col = matchstr(a:matchstr, '\d\+')
endfunction"}}}
function! s:escape.save_pos(matchstr)"{{{
  let s:save_pos = [s:line, s:col]
endfunction"}}}
function! s:escape.restore_pos(matchstr)"{{{
  let [s:line, s:col] = s:save_pos
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

" Control sequence functions.
let s:control = {}
function! s:control.ignore()"{{{
endfunction"}}}
function! s:control.newline()"{{{
  if s:line == line('$')
    " Append new line.
    call append('$', '')
  endif
  
  let s:line += 1
  let s:col = 1
  let s:lines[s:line] = ''
endfunction"}}}
function! s:control.delete_backword_char()"{{{
  if exists('b:interactive') && s:line == b:interactive.echoback_linenr
        \ || s:col == 1
    return
  endif
  
  let l:line = s:lines[s:line]
  let l:len = len(matchstr(l:line[: s:col-1] , '.$'))
  "let s:lines[s:line] = l:line[: s:col-l:len-1] . l:line[s:col :]
  
  let s:col -= l:len
endfunction"}}}
function! s:control.carriage_return()"{{{
  let s:col = 1
endfunction"}}}
function! s:control.clear_entire_screen()"{{{
  let l:reg = @x
  1,$ delete x
  let @x = l:reg

  let s:lines = {}
endfunction"}}}
function! s:control.bell()"{{{
  echo 'Ring!'
endfunction"}}}

" escape sequence list. {{{
" pattern: function
let s:escape_sequence_match = {
      \ '^\[20[hl]' : s:escape.ignore,
      \ '^\[?\d[hl]' : s:escape.ignore,
      \ '^[()][AB012UK]' : s:escape.ignore,
      \
      \ '^\[[0-9;]\+m' : s:escape.highlight,
      \
      \ '^k.\{-}\e\\' : s:escape.change_title,
      \ '^][02];.\{-}'."\<C-g>" : s:escape.change_title,
      \ 
      \ '^\[\d\+;\d\+r' : s:escape.setup_window,
      \
      \ '^\[\d*A' : s:escape.move_up,
      \ '^\[\d*B' : s:escape.move_down,
      \ '^\[\d*C' : s:escape.move_right,
      \ '^\[\d*D' : s:escape.move_left,
      \ '^\[\d*E' : s:escape.move_down_head,
      \ '^\[\d\+F' : s:escape.move_up_head,
      \ '^\[\d\+G' : s:escape.move_col,
      \ '^\[\d\+;\d\+[Hf]' : s:escape.move_cursor,
      \
      \ '^[\dg' : s:escape.ignore,
      \
      \ '^#\d' : s:escape.ignore,
      \
      \ '^\dn' : s:escape.ignore,
      \ '^\d\+;\d\+R' : s:escape.ignore,
      \
      \ '^\[?1;\d\+0c' : s:escape.ignore,
      \
      \ '^\[2;\dy' : s:escape.ignore,
      \
      \ '^\[\dq' : s:escape.ignore,
      \
      \ '^\d\+;\d\+' : s:escape.ignore,
      \
      \}
let s:escape_sequence_simple_char1 = {
      \ 'N' : s:escape.ignore,
      \ 'O' : s:escape.ignore,
      \
      \ '7' : s:escape.save_pos,
      \ '8' : s:escape.restore_pos,
      \ '(' : s:escape.ignore,
      \
      \ 'c' : s:escape.ignore,
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
      \ '[m' : s:escape.highlight_restore,
      \
      \ '[D' : s:escape.move_down1,
      \ '[M' : s:escape.move_up1,
      \ '[H' : s:escape.move_cursor_home,
      \ '[f' : s:escape.move_cursor_home,
      \
      \ '[g' : s:escape.ignore,
      \
      \ '[K' : s:escape.delete_right_line,
      \
      \ '[J' : s:escape.clear_screen_from_cursor_down,
      \
      \ '[c' : s:escape.ignore,
      \
      \ '/Z' : s:escape.ignore,
      \ '%@' : s:escape.ignore,
      \ '%G' : s:escape.ignore,
      \ '%8' : s:escape.ignore,
      \ '#8' : s:escape.ignore,
      \}
let s:escape_sequence_simple_char3 = {
      \ '[;H' : s:escape.move_cursor_home,
      \ '[;f' : s:escape.move_cursor_home,
      \
      \ '[0K' : s:escape.delete_right_line,
      \ '[1K' : s:escape.delete_left_line,
      \ '[2K' : s:escape.delete_whole_line,
      \
      \ '[0J' : s:escape.ignore,
      \ '[1J' : s:escape.ignore,
      \ '[2J' : s:escape.clear_entire_screen,
      \
      \ '[0c' : s:escape.ignore,
      \ '[0G' : s:escape.ignore,
      \}
"}}}
" control sequence list. {{{
" pattern: function
let s:control_sequence = {
      \ "\<LF>" : s:control.newline,
      \ "\<CR>" : s:control.carriage_return,
      \ "\<C-h>" : s:control.delete_backword_char,
      \ "\<Del>" : s:control.ignore,
      \ "\<C-l>" : s:control.clear_entire_screen,
      \ "\<C-g>" : s:control.bell,
      \}
"}}}

" vim: foldmethod=marker
