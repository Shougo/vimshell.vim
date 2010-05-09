"=============================================================================
" FILE: terminal.vim
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

let s:terminal_info = {}

function! vimshell#terminal#interpret_escape_sequence()"{{{
  if !has_key(s:terminal_info, bufnr('%'))
    " Initialize.
    let s:terminal_info[bufnr('%')] = {
          \ 'syntax_names' : [],
          \ }
  endif
  
  let l:lnum = line('.')
  while l:lnum <= line('$')
    let l:line = getline(l:lnum)

    if l:line =~ '[[:cntrl:]]'
      let l:newline = ''
      let l:pos = 0
      let l:col = 1
      let l:max = len(l:line)
      while l:pos < l:max
        let l:matched = 0
        
        if l:line[l:pos] == "\<ESC>"
          " Check escape sequence.
          for [l:pattern, l:Func] in items(s:escape_sequence)
            let l:matchstr = matchstr(l:line, '^'.l:pattern, l:pos)
            if l:matchstr != ''
              let l:pos += len(l:matchstr)
              let l:matched = 1

              " Interpret.
              call call(l:Func, [l:matchstr, l:lnum, l:col])

              break
            endif
          endfor
        else
          " Check other pattern.
          for [l:pattern, l:Func] in items(s:control_sequence)
            let l:matchstr = matchstr(l:line, '^'.l:pattern, l:pos)
            if l:matchstr != ''
              let l:pos += len(l:matchstr)
              let l:matched = 1

              " Interpret.
              call call(l:Func, [l:matchstr, l:lnum, l:col])

              break
            endif
          endfor
        endif

        if !l:matched
          let l:newline .= l:line[l:pos]
          let l:pos += 1
          let l:col += 1
        endif
      endwhile

      call setline(l:lnum, l:newline)
    endif
    
    let l:lnum += 1
  endwhile
endfunction"}}}
function! vimshell#terminal#clear_highlight()"{{{
  if !has_key(s:terminal_info, bufnr('%'))
    return
  endif
  
  for l:syntax_name in s:terminal_info[bufnr('%')].syntax_names
    execute 'highlight clear' l:syntax_name
    execute 'syntax clear' l:syntax_name
  endfor
endfunction"}}}

" Escape sequence functions.
function! s:ignore(matchstr, lnum, col)"{{{
endfunction"}}}
function! s:highlight_escape_sequence(matchstr, lnum, col)"{{{
  let l:color_table = [ 0x00, 0x5F, 0x87, 0xAF, 0xD7, 0xFF ]
  let l:grey_table = [
        \0x08, 0x12, 0x1C, 0x26, 0x30, 0x3A, 0x44, 0x4E, 
        \0x58, 0x62, 0x6C, 0x76, 0x80, 0x8A, 0x94, 0x9E, 
        \0xA8, 0xB2, 0xBC, 0xC6, 0xD0, 0xDA, 0xE4, 0xEE
        \]

  let l:syntax_name = 'EscapeSequenceAt_' . bufnr('%') . '_' . a:lnum . '_' . a:col
  execute 'syntax region' l:syntax_name 'start=+\%' . a:lnum . 'l\%' . a:col . 'c+ end=+\%$+' 'contains=ALL'
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
      let l:highlight .= printf(' ctermfg=%d guifg=%s', l:color_code - 30, g:VimShell_EscapeColors[l:color_code - 30])
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
        let l:highlight .= printf(' ctermfg=%d guifg=%s', l:color, g:VimShell_EscapeColors[l:color])
      endif
      break
    elseif l:color_code == 39
      " TODO
    elseif 40 <= l:color_code && l:color_code <= 47 
      " Background color.
      let l:highlight .= printf(' ctermbg=%d guibg=%s', l:color_code - 40, g:VimShell_EscapeColors[l:color_code - 40])
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
        let l:highlight .= printf(' ctermbg=%d guibg=%s', l:color, g:VimShell_EscapeColors[l:color])
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
function! s:move_cursor(matchstr, lnum, col)"{{{
  let l:args = split(matchstr(a:matchstr, '[0-9;]\+'), ';')
  let l:pos = getpos('.')
  let l:pos[1] = l:args[0]
  let l:pos[2] = l:args[1]
  call setpos('.', l:pos)
endfunction"}}}
function! s:clear_entire_screen(matchstr, lnum, col)"{{{
  let l:reg = @x
  1,$ delete x
  let @x = l:reg
endfunction"}}}
function! s:clear_screen_from_cursor_down(matchstr, lnum, col)"{{{
  let l:reg = @x
  .+1,$ delete x
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
      \ '\e\[?\dh' : s:funcref('ignore'),
      \ '\e\[?\dl' : s:funcref('ignore'),
      \ '\e(\a' : s:funcref('ignore'),
      \ '\e)\a' : s:funcref('ignore'),
      \ '\e(\d' : s:funcref('ignore'),
      \ '\e)\d' : s:funcref('ignore'),
      \ '\eN' : s:funcref('ignore'),
      \ '\eO' : s:funcref('ignore'),
      \ 
      \ '\e\[m' : s:funcref('ignore'),
      \ '\e\[\%(\d\+;\)*\d\+m' : s:funcref('highlight_escape_sequence'),
      \
      \ '\e\[\d\+;\d\+r' : s:funcref('ignore'),
      \
      \ '\e\[\d\+A' : s:funcref('ignore'),
      \ '\e\[\d\+B' : s:funcref('ignore'),
      \ '\e\[\d\+C' : s:funcref('ignore'),
      \ '\e\[\d\+D' : s:funcref('ignore'),
      \ '\e\[H' : s:funcref('ignore'),
      \ '\e\[;H' : s:funcref('ignore'),
      \ '\e\[\d\+;\d\+H' : s:funcref('move_cursor'),
      \ '\e\[f' : s:funcref('ignore'),
      \ '\e\[;f' : s:funcref('ignore'),
      \ '\eM' : s:funcref('ignore'),
      \ '\eE' : s:funcref('ignore'),
      \ '\e7' : s:funcref('ignore'),
      \ '\e8' : s:funcref('ignore'),
      \
      \ '\e[g' : s:funcref('ignore'),
      \ '\e[\dg' : s:funcref('ignore'),
      \
      \ '\e#\d' : s:funcref('ignore'),
      \
      \ '\e\[K' : s:funcref('ignore'),
      \ '\e\[0K' : s:funcref('ignore'),
      \ '\e\[1K' : s:funcref('ignore'),
      \ '\e\[2K' : s:funcref('ignore'),
      \
      \ '\e\[J' : s:funcref('clear_screen_from_cursor_down'),
      \ '\e\[0J' : s:funcref('ignore'),
      \ '\e\[1J' : s:funcref('ignore'),
      \ '\e\[2J' : s:funcref('clear_entire_screen'),
      \
      \ '\e\dn' : s:funcref('ignore'),
      \ '\e\d\+;\d\+R' : s:funcref('ignore'),
      \
      \ '\e\[c' : s:funcref('ignore'),
      \ '\e\[0c' : s:funcref('ignore'),
      \ '\e\[?1;\d\+0c' : s:funcref('ignore'),
      \
      \ '\ec' : s:funcref('ignore'),
      \ '\e\[2;\dy' : s:funcref('ignore'),
      \
      \ '\e\[\dq' : s:funcref('ignore'),
      \
      \ '\e<' : s:funcref('ignore'),
      \ '\e=' : s:funcref('ignore'),
      \ '\e>' : s:funcref('ignore'),
      \ '\eF' : s:funcref('ignore'),
      \ '\eG' : s:funcref('ignore'),
      \
      \ '\eA' : s:funcref('ignore'),
      \ '\eB' : s:funcref('ignore'),
      \ '\eC' : s:funcref('ignore'),
      \ '\eD' : s:funcref('ignore'),
      \ '\eH' : s:funcref('ignore'),
      \ '\e\d\+;\d\+' : s:funcref('ignore'),
      \ '\eI' : s:funcref('ignore'),
      \
      \ '\eK' : s:funcref('ignore'),
      \ '\eJ' : s:funcref('ignore'),
      \
      \ '\eZ' : s:funcref('ignore'),
      \ '\e/Z' : s:funcref('ignore'),
      \
      \ '\e\[0G' : s:funcref('ignore'),
      \ '\e\[>\dl' : s:funcref('ignore'),
      \ '\e\[>\dh' : s:funcref('ignore'),
      \}
let s:control_sequence = {
      \ "\<C-h>" : s:funcref('ignore'),
      \ "\<BS>" : s:funcref('ignore'),
      \ "\<Del>" : s:funcref('ignore'),
      \ "\<C-l>" : s:funcref('ignore'),
      \}
"}}}

" vim: foldmethod=marker
