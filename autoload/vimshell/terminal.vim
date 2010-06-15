"=============================================================================
" FILE: terminal.vim
" AUTHOR:  Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 14 Jun 2010
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

let s:terminal_info = {}

function! vimshell#terminal#print(string)"{{{
  let l:string = substitute(a:string, '\r\n', '\n', 'g')
  
  if l:string !~ '[\e\r\b]' && col('.') == col('$')
    " Optimized print.
    let l:lines = split(l:string, '\n', 1)
    call setline('.', getline('.') . l:lines[0])
    call append('.', l:lines[1:])
    execute 'normal!' (len(l:lines)-1).'j$'
    
    return
  endif
  
  let l:newstr = ''
  let l:pos = 0
  let l:max = len(l:string)
  let s:col = col('.')
  let s:line = line('.')
  let s:lines = {}
  let s:lines[s:line] = getline('.')
  
  while l:pos < l:max
    let l:char = l:string[l:pos]
    if l:char !~ '[[:cntrl:]]'
      let l:newstr .= l:char
      let l:pos += 1

      continue
    endif

    if l:char == "\<ESC>""{{{
      " Check escape sequence.
      let l:checkstr = l:string[l:pos+1 :]
      let l:matched = 0
      
      " Check simple pattern.
      for l:pattern in keys(s:escape_sequence_simple)
        if neocomplcache#head_match(l:checkstr, l:pattern)
          let l:matched = 1
          break
        endif
      endfor

      if !l:matched
        " Check match pattern.
        for l:pattern in keys(s:escape_sequence_match)
          if l:checkstr =~ l:pattern
            let l:matched = 1
            break
          endif
        endfor
      endif
      
      if l:matched
        " Print rest string.
        call s:output_string(l:newstr)
        let l:newstr = ''

        let l:matchstr = matchstr(l:checkstr, l:pattern)

        call call(s:escape_sequence_match[l:pattern], [l:matchstr], s:escape)

        let l:pos += len(l:matchstr) + 1
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
  "echomsg string(s:lines)
  let s:lines = {}
  
  " Move pos.
  let l:oldpos = getpos('.')
  let l:oldpos[1] = s:line
  let l:oldpos[2] = s:col
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
    if l:char == "\<ESC>"
      " Check escape sequence.
      for l:pattern in keys(s:escape_sequence)
        let l:matchstr = matchstr(a:string, '^'.l:pattern, l:pos)
        if l:matchstr != ''
          let l:matched = 1
          let l:pos += len(l:matchstr)
          break
        endif
      endfor
    elseif has_key(s:control_sequence, l:char)
      continue
    endif
    
    if !l:matched
      let l:newstr .= a:string[l:pos]
      let l:pos += 1
    endif
  endwhile

  return l:newstr
endfunction"}}}
function! vimshell#terminal#clear_highlight()"{{{
  if !has_key(s:terminal_info, bufnr('%'))
    let s:terminal_info[bufnr('%')] = {
          \ 'syntax_names' : []
          \}
    return
  endif
  
  for l:syntax_name in s:terminal_info[bufnr('%')].syntax_names
    execute 'highlight clear' l:syntax_name
    execute 'syntax clear' l:syntax_name
  endfor
endfunction"}}}
function! s:output_string(string)"{{{
  if a:string == ''
    return
  endif
  
  let l:line = s:lines[s:line]
  let l:left_line = l:line[: s:col - 1]
  let l:right_line = l:line[s:col+len(a:string) :]

  let s:lines[s:line] = (s:col == 1)? a:string . l:right_line : l:left_line . a:string . l:right_line
  
  let s:col += len(a:string)
endfunction"}}}

" Escape sequence functions.
let s:escape = {}
function! s:escape.ignore(matchstr)"{{{
endfunction"}}}
function! s:escape.highlight(matchstr)"{{{
  let l:color_table = [ 0x00, 0x5F, 0x87, 0xAF, 0xD7, 0xFF ]
  let l:grey_table = [
        \0x08, 0x12, 0x1C, 0x26, 0x30, 0x3A, 0x44, 0x4E, 
        \0x58, 0x62, 0x6C, 0x76, 0x80, 0x8A, 0x94, 0x9E, 
        \0xA8, 0xB2, 0xBC, 0xC6, 0xD0, 0xDA, 0xE4, 0xEE
        \]

  let [l:lnum, l:col] = [s:line, s:col]
  let l:syntax_name = 'EscapeSequenceAt_' . bufnr('%') . '_' . l:lnum . '_' . l:col
  execute 'syntax region' l:syntax_name 'start=+\%' . l:lnum . 'l\%' . l:col . 'c+ end=+\%$+' 'contains=ALL'

  if !has_key(s:terminal_info, bufnr('%'))
    let s:terminal_info[bufnr('%')] = {
          \ 'syntax_names' : []
          \}
    return
  endif
  call add(s:terminal_info[bufnr('%')].syntax_names, l:syntax_name)

  let l:highlight = ''
  for l:color_code in split(matchstr(a:matchstr, '[0-9;]\+'), ';')
    if l:color_code == 0"{{{
      let l:highlight .= ' cterm=NONE ctermfg=NONE ctermbg=NONE gui=NONE guifg=NONE guibg=NONE'
    elseif l:color_code == 1
      let l:highlight .= ' cterm=BOLD gui=BOLD'
    elseif l:color_code == 4
      let l:highlight .= ' cterm=UNDERLINE gui=UNDERLINE'
    elseif l:color_code == 7
      let l:highlight .= ' cterm=REVERSE gui=REVERSE'
    elseif l:color_code == 8
      let l:highlight .= ' ctermfg=0 ctermbg=0 guifg=#000000 guibg=#000000'
    elseif 30 <= l:color_code && l:color_code <= 37 
      " Foreground color.
      let l:highlight .= printf(' ctermfg=%d guifg=%s', l:color_code - 30, g:vimshell_escape_colors[l:color_code - 30])
    elseif l:color_code == 38
      " Foreground 256 colors.
      let l:color = split(matchstr(a:matchstr, '[0-9;]\+'), ';')[2]
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

        let l:highlight .= printf(' ctermfg=%d guifg=#%02x%02x%02x', l:color, l:red, l:green, l:blue)
      else
        let l:highlight .= printf(' ctermfg=%d guifg=%s', l:color, g:vimshell_escape_colors[l:color])
      endif
      break
    elseif l:color_code == 39
      " TODO
    elseif 40 <= l:color_code && l:color_code <= 47 
      " Background color.
      let l:highlight .= printf(' ctermbg=%d guibg=%s', l:color_code - 40, g:vimshell_escape_colors[l:color_code - 40])
    elseif l:color_code == 48
      " Background 256 colors.
      let l:color = split(matchstr(a:matchstr, '[0-9;]\+'), ';')[2]
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

        let l:highlight .= printf(' ctermbg=%d guibg=#%02x%02x%02x', l:color, l:red, l:green, l:blue)
      else
        let l:highlight .= printf(' ctermbg=%d guibg=%s', l:color, g:vimshell_escape_colors[l:color])
      endif
      break
    elseif l:color_code == 49
      " TODO
    endif"}}}
  endfor
  if l:highlight != ''
    execute 'highlight link' l:syntax_name 'Normal'
    execute 'highlight' l:syntax_name l:highlight
  endif
endfunction"}}}
function! s:escape.move_cursor(matchstr)"{{{
  let l:args = split(matchstr(a:matchstr, '[0-9;]\+'), ';')
  
  let s:line = l:args[0]
  let s:col = l:args[1]
endfunction"}}}
function! s:escape.clear_entire_screen(matchstr)"{{{
  let l:reg = @x
  1,$ delete x
  let @x = l:reg

  let s:lines = {}
endfunction"}}}
function! s:escape.clear_screen_from_cursor_down(matchstr)"{{{
  if line('.') == line('$')
    return
  endif
  
  let l:reg = @x
  .+1,$ delete x
  let @x = l:reg
endfunction"}}}
function! s:escape.move_head()"{{{
  let s:col = 1
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
function! s:control.carriage_return()"{{{
  let s:col = 1
endfunction"}}}
function! s:control.clear_entire_screen()"{{{
  let l:reg = @x
  1,$ delete x
  let @x = l:reg

  let s:lines = {}
endfunction"}}}

" escape sequence list. {{{
" pattern: function
let s:escape_sequence_match = {
      \ '^\[?\dh' : s:escape.ignore,
      \ '^\[?\dl' : s:escape.ignore,
      \ '^(\a' : s:escape.ignore,
      \ '^)\a' : s:escape.ignore,
      \ '^(\d' : s:escape.ignore,
      \ '^)\d' : s:escape.ignore,
      \ 
      \ '^\[\%(\d\+;\)*\d\+m' : s:escape.highlight,
      \
      \ '^\[\d\+;\d\+r' : s:escape.ignore,
      \
      \ '^\[\d\+A' : s:escape.ignore,
      \ '^\[\d\+B' : s:escape.ignore,
      \ '^\[\d\+C' : s:escape.ignore,
      \ '^\[\d\+D' : s:escape.ignore,
      \ '^\[\d\+;\d\+H' : s:escape.move_cursor,
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
      \ '^\[>\dl' : s:escape.ignore,
      \ '^\[>\dh' : s:escape.ignore,
      \}
let s:escape_sequence_simple = {
      \ 'N' : s:escape.ignore,
      \ 'O' : s:escape.ignore,
      \ 
      \ '[m' : s:escape.ignore,
      \
      \ '[H' : s:escape.ignore,
      \ '[;H' : s:escape.ignore,
      \ '[f' : s:escape.ignore,
      \ '[;f' : s:escape.ignore,
      \ 'M' : s:escape.ignore,
      \ 'E' : s:escape.ignore,
      \ '7' : s:escape.ignore,
      \ '8' : s:escape.ignore,
      \
      \ '[g' : s:escape.ignore,
      \
      \ '[K' : s:escape.ignore,
      \ '[0K' : s:escape.ignore,
      \ '[1K' : s:escape.ignore,
      \ '[2K' : s:escape.ignore,
      \
      \ '[J' : s:escape.clear_screen_from_cursor_down,
      \ '[0J' : s:escape.ignore,
      \ '[1J' : s:escape.ignore,
      \ '[2J' : s:escape.clear_entire_screen,
      \
      \ '[c' : s:escape.ignore,
      \ '[0c' : s:escape.ignore,
      \
      \ 'c' : s:escape.ignore,
      \
      \ '<' : s:escape.ignore,
      \ '=' : s:escape.ignore,
      \ '>' : s:escape.ignore,
      \ 'F' : s:escape.ignore,
      \ 'G' : s:escape.ignore,
      \
      \ 'A' : s:escape.move_head,
      \ 'B' : s:escape.ignore,
      \ 'C' : s:escape.ignore,
      \ 'D' : s:escape.ignore,
      \ 'H' : s:escape.ignore,
      \ 'I' : s:escape.ignore,
      \
      \ 'K' : s:escape.ignore,
      \ 'J' : s:escape.ignore,
      \
      \ 'Z' : s:escape.ignore,
      \ '/Z' : s:escape.ignore,
      \
      \ '[0G' : s:escape.ignore,
      \}
"}}}
" control sequence list. {{{
" pattern: function
let s:control_sequence = {
      \ "\<LF>" : s:control.newline,
      \ "\<CR>" : s:control.carriage_return,
      \ "\<C-h>" : s:control.ignore,
      \ "\<BS>" : s:control.ignore,
      \ "\<Del>" : s:control.ignore,
      \ "\<C-l>" : s:control.clear_entire_screen,
      \}
"}}}

" vim: foldmethod=marker
