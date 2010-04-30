"=============================================================================
" FILE: terminal.vim
" AUTHOR:  Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 30 Apr 2010
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

function! vimshell#terminal#interpret_escape_sequence()"{{{
  let l:lnum = line('.')
  while l:lnum <= line('$')
    let l:line = getline(l:lnum)

    if l:line =~ '[[:cntrl:]]'
      let l:newline = ''
      let l:pos = 0
      let l:max = len(l:line)
      while l:pos < l:max
        let l:matched = 0
        
        if l:line[l:pos] == "\<ESC>"
          " Check escape sequence.
          for [l:pattern, l:Func] in items(s:escape_sequence)
            let l:matchend = matchend(l:line, '^'.l:pattern, l:pos)
            if l:matchend >= 0
              let l:pos = l:matchend
              let l:matched = 1
              
              " Interpret.
              call call(l:Func, [])
              
              break
            endif
          endfor
        else
          " Check other pattern.
          for [l:pattern, l:Func] in items(s:control_sequence)
            let l:matchend = matchend(l:line, '^'.l:pattern, l:pos)
            if l:matchend >= 0
              let l:pos = l:matchend
              let l:matched = 1

              " Interpret.
              call call(l:Func, [])

              break
            endif
          endfor
        endif

        if !l:matched
          let l:newline .= l:line[l:pos]
          let l:pos += 1
        endif
      endwhile

      call setline(l:lnum, l:newline)
    endif
    
    let l:lnum += 1
  endwhile
endfunction"}}}

" Escape sequence functions.
function! s:ignore()"{{{
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
      \ '\e(A' : s:funcref('ignore'),
      \ '\e)A' : s:funcref('ignore'),
      \ '\e(B' : s:funcref('ignore'),
      \ '\e)B' : s:funcref('ignore'),
      \ '\e(0' : s:funcref('ignore'),
      \ '\e)0' : s:funcref('ignore'),
      \ '\e(1' : s:funcref('ignore'),
      \ '\e)1' : s:funcref('ignore'),
      \ '\e(2' : s:funcref('ignore'),
      \ '\e)2' : s:funcref('ignore'),
      \ '\eN' : s:funcref('ignore'),
      \ '\eO' : s:funcref('ignore'),
      \ 
      \ '\e\[m' : s:funcref('ignore'),
      \ '\e\[\d\+m' : s:funcref('ignore'),
      \
      \ '\e\[\d\+;\d\+r' : s:funcref('ignore'),
      \
      \ '\e\[\d\+A' : s:funcref('ignore'),
      \ '\e\[\d\+B' : s:funcref('ignore'),
      \ '\e\[\d\+C' : s:funcref('ignore'),
      \ '\e\[\d\+D' : s:funcref('ignore'),
      \ '\e\[H' : s:funcref('ignore'),
      \ '\e\[;H' : s:funcref('ignore'),
      \ '\e\[\d\+;\d\+H' : s:funcref('ignore'),
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
      \ '\e\[J' : s:funcref('ignore'),
      \ '\e\[0J' : s:funcref('ignore'),
      \ '\e\[1J' : s:funcref('ignore'),
      \ '\e\[2J' : s:funcref('ignore'),
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
      \ '\e\[>5l' : s:funcref('ignore'),
      \}
let s:control_sequence = {
      \ "\<C-h>" : s:funcref('ignore'),
      \ "\<BS>" : s:funcref('ignore'),
      \ "\<Del>" : s:funcref('ignore'),
      \ "\<C-l>" : s:funcref('ignore'),
      \}
"}}}

" vim: foldmethod=marker
