"=============================================================================
" FILE: terminal.vim
" AUTHOR:  Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 06 Jun 2010
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
  while l:pos < l:max
    let l:matched = 0

    let l:char = l:string[l:pos]
    if l:char !~ '[[:cntrl:]]'
      let l:newstr .= l:char
      let l:pos += 1

      continue
    endif

    if l:char == "\<ESC>"
      " Check escape sequence.
      for [l:pattern, l:Func] in items(s:escape_sequence)
        let l:matchstr = matchstr(l:string, '^'.l:pattern, l:pos)
        if l:matchstr != ''
          " Print rest string.
          call s:output_string(l:newstr)
          let l:newstr = ''

          call call(l:Func, [l:matchstr])
          
          let l:matched = 1
          let l:pos += len(l:matchstr)
          break
        endif
      endfor

      if !l:matched
        let l:newstr .= l:char
        let l:pos += 1
      endif
    elseif has_key(s:control_sequence, l:char)
      " Check other pattern.
      " Print rest string.
      call s:output_string(l:newstr)
      let l:newstr = ''

      call call(s:control_sequence[l:char], [])

      let l:pos += 1
    endif
  endwhile

  " Print rest string.
  call s:output_string(l:newstr)

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
  
  let l:line = getline('.') 
  let l:left_line = l:line[: col('.') - 1]
  let l:right_line = l:line[col('.') :]
  if col('.') == 1
    call setline('.', a:string . l:right_line)
  else
    call setline('.', l:left_line . a:string . l:right_line)
  endif
  
  execute 'normal!' len(a:string).'l'
endfunction"}}}

" Escape sequence functions.
function! s:ignore_escape(matchstr)"{{{
endfunction"}}}
function! s:highlight_escape_sequence(matchstr)"{{{
  let l:color_table = [ 0x00, 0x5F, 0x87, 0xAF, 0xD7, 0xFF ]
  let l:grey_table = [
        \0x08, 0x12, 0x1C, 0x26, 0x30, 0x3A, 0x44, 0x4E, 
        \0x58, 0x62, 0x6C, 0x76, 0x80, 0x8A, 0x94, 0x9E, 
        \0xA8, 0xB2, 0xBC, 0xC6, 0xD0, 0xDA, 0xE4, 0xEE
        \]

  let [l:lnum, l:col] = [line('.'), (getline('.') == '')? 1: col('.')+1]
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
function! s:move_cursor(matchstr)"{{{
  let l:args = split(matchstr(a:matchstr, '[0-9;]\+'), ';')
  let l:pos = getpos('.')
  let l:pos[1] = l:args[0]
  let l:pos[2] = l:args[1]
  call setpos('.', l:pos)
endfunction"}}}
function! s:clear_entire_screen_escape(matchstr)"{{{
  let l:reg = @x
  1,$ delete x
  let @x = l:reg
endfunction"}}}
function! s:clear_screen_from_cursor_down(matchstr)"{{{
  if col('.') == col('$')
    return
  endif
  
  let l:reg = @x
  .+1,$ delete x
  let @x = l:reg
endfunction"}}}
function! s:move_head()"{{{
  normal! 0
endfunction"}}}

" Control sequence functions.
function! s:ignore_control()"{{{
endfunction"}}}
function! s:newline()"{{{
  call append('.', '')
  normal! j0
endfunction"}}}
function! s:carriage_return()"{{{
  normal! 0
endfunction"}}}
function! s:clear_entire_screen_control()"{{{
  let l:reg = @x
  1,$ delete x
  let @x = l:reg
endfunction"}}}

function! s:SID_PREFIX()
  return matchstr(expand('<sfile>'), '<SNR>\d\+_\zeSID_PREFIX$')
endfunction

" Get funcref.
function! s:funcref(funcname)
  return function(s:SID_PREFIX().a:funcname)
endfunction

" escape sequence list. {{{
" pattern: function
let s:escape_sequence = {
      \ '\e\[?\dh' : s:funcref('ignore_escape'),
      \ '\e\[?\dl' : s:funcref('ignore_escape'),
      \ '\e(\a' : s:funcref('ignore_escape'),
      \ '\e)\a' : s:funcref('ignore_escape'),
      \ '\e(\d' : s:funcref('ignore_escape'),
      \ '\e)\d' : s:funcref('ignore_escape'),
      \ '\eN' : s:funcref('ignore_escape'),
      \ '\eO' : s:funcref('ignore_escape'),
      \ 
      \ '\e\[m' : s:funcref('ignore_escape'),
      \ '\e\[\%(\d\+;\)*\d\+m' : s:funcref('highlight_escape_sequence'),
      \
      \ '\e\[\d\+;\d\+r' : s:funcref('ignore_escape'),
      \
      \ '\e\[\d\+A' : s:funcref('ignore_escape'),
      \ '\e\[\d\+B' : s:funcref('ignore_escape'),
      \ '\e\[\d\+C' : s:funcref('ignore_escape'),
      \ '\e\[\d\+D' : s:funcref('ignore_escape'),
      \ '\e\[H' : s:funcref('ignore_escape'),
      \ '\e\[;H' : s:funcref('ignore_escape'),
      \ '\e\[\d\+;\d\+H' : s:funcref('move_cursor'),
      \ '\e\[f' : s:funcref('ignore_escape'),
      \ '\e\[;f' : s:funcref('ignore_escape'),
      \ '\eM' : s:funcref('ignore_escape'),
      \ '\eE' : s:funcref('ignore_escape'),
      \ '\e7' : s:funcref('ignore_escape'),
      \ '\e8' : s:funcref('ignore_escape'),
      \
      \ '\e[g' : s:funcref('ignore_escape'),
      \ '\e[\dg' : s:funcref('ignore_escape'),
      \
      \ '\e#\d' : s:funcref('ignore_escape'),
      \
      \ '\e\[K' : s:funcref('ignore_escape'),
      \ '\e\[0K' : s:funcref('ignore_escape'),
      \ '\e\[1K' : s:funcref('ignore_escape'),
      \ '\e\[2K' : s:funcref('ignore_escape'),
      \
      \ '\e\[J' : s:funcref('clear_screen_from_cursor_down'),
      \ '\e\[0J' : s:funcref('ignore_escape'),
      \ '\e\[1J' : s:funcref('ignore_escape'),
      \ '\e\[2J' : s:funcref('clear_entire_screen_escape'),
      \
      \ '\e\dn' : s:funcref('ignore_escape'),
      \ '\e\d\+;\d\+R' : s:funcref('ignore_escape'),
      \
      \ '\e\[c' : s:funcref('ignore_escape'),
      \ '\e\[0c' : s:funcref('ignore_escape'),
      \ '\e\[?1;\d\+0c' : s:funcref('ignore_escape'),
      \
      \ '\ec' : s:funcref('ignore_escape'),
      \ '\e\[2;\dy' : s:funcref('ignore_escape'),
      \
      \ '\e\[\dq' : s:funcref('ignore_escape'),
      \
      \ '\e<' : s:funcref('ignore_escape'),
      \ '\e=' : s:funcref('ignore_escape'),
      \ '\e>' : s:funcref('ignore_escape'),
      \ '\eF' : s:funcref('ignore_escape'),
      \ '\eG' : s:funcref('ignore_escape'),
      \
      \ '\eA' : s:funcref('move_head'),
      \ '\eB' : s:funcref('ignore_escape'),
      \ '\eC' : s:funcref('ignore_escape'),
      \ '\eD' : s:funcref('ignore_escape'),
      \ '\eH' : s:funcref('ignore_escape'),
      \ '\e\d\+;\d\+' : s:funcref('ignore_escape'),
      \ '\eI' : s:funcref('ignore_escape'),
      \
      \ '\eK' : s:funcref('ignore_escape'),
      \ '\eJ' : s:funcref('ignore_escape'),
      \
      \ '\eZ' : s:funcref('ignore_escape'),
      \ '\e/Z' : s:funcref('ignore_escape'),
      \
      \ '\e\[0G' : s:funcref('ignore_escape'),
      \ '\e\[>\dl' : s:funcref('ignore_escape'),
      \ '\e\[>\dh' : s:funcref('ignore_escape'),
      \}
let s:control_sequence = {
      \ "\<C-h>" : s:funcref('ignore_escape'),
      \ "\<BS>" : s:funcref('ignore_escape'),
      \ "\<Del>" : s:funcref('ignore_escape'),
      \ "\<C-l>" : s:funcref('ignore_escape'),
      \}
"}}}
" control sequence list. {{{
" pattern: function
let s:control_sequence = {
      \ "\<LF>" : s:funcref('newline'),
      \ "\<CR>" : s:funcref('carriage_return'),
      \ "\<C-h>" : s:funcref('ignore_control'),
      \ "\<BS>" : s:funcref('ignore_control'),
      \ "\<Del>" : s:funcref('ignore_control'),
      \ "\<C-l>" : s:funcref('clear_entire_screen_control'),
      \}
"}}}

" vim: foldmethod=marker
