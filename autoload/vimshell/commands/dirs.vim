"=============================================================================
" FILE: dirs.vim
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
      \ 'name' : 'dirs',
      \ 'kind' : 'internal',
      \ 'description' : 'dirs [{max}]',
      \}
function! s:command.execute(command, args, fd, other_info)"{{{
  " Print directory stack.

  let l:cnt = 0
  let l:arguments = join(a:args)
  if empty(l:arguments)
    " Default max value.
    let l:max = 20
  elseif l:arguments =~ '^\d\+$'
    let l:max = str2nr(l:arguments)
  else
    " Ignore arguments.
    let l:max = len(b:vimshell.directory_stack)
  endif
  if l:max > len(b:vimshell.directory_stack)
    " Overflow.
    let l:max = len(b:vimshell.directory_stack)
  endif

  while l:cnt < l:max
    call vimshell#print_line(a:fd, printf('%2d: %s', l:cnt, fnamemodify(b:vimshell.directory_stack[l:cnt], ':~')))
    let l:cnt += 1
  endwhile
endfunction"}}}

function! vimshell#commands#dirs#define()
  return s:command
endfunction
