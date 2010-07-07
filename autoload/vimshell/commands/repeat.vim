"=============================================================================
" FILE: repeat.vim
" AUTHOR: Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 07 Jul 2010
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

let s:command = {
      \ 'name' : 'repeat',
      \ 'kind' : 'internal',
      \ 'description' : 'repeat {cnt} {command}',
      \}
function! s:command.execute(program, args, fd, other_info)"{{{
  " Repeat command.

  if len(a:args) < 2 || a:args[0] !~ '\d\+'
    call vimshell#error_line(a:fd, 'repeat: Arguments error.')
  else
    " Repeat.
    let l:max = a:args[0]
    let l:i = 0
    while l:i < l:max
      call vimshell#parser#execute_command(a:args[1], a:args[2:], a:fd, a:other_info) 
      let l:i += 1
    endwhile
  endif
endfunction"}}}

function! vimshell#commands#repeat#define()
  return s:command
endfunction
