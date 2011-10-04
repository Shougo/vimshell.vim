"=============================================================================
" FILE: vexe.vim
" AUTHOR: Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 08 Jul 2010
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
      \ 'name' : 'vexe',
      \ 'kind' : 'special',
      \ 'description' : 'vexe {expression}',
      \}
function! s:command.execute(args, context)"{{{
  " Execute vim command.

  let context = a:context
  let context.fd = a:context.fd
  call vimshell#set_context(context)
  
  let temp = tempname()
  let save_vfile = &verbosefile
  let &verbosefile = temp
  for command in split(join(a:args), '\n')
    silent execute command
  endfor
  if &verbosefile == temp
    let &verbosefile = save_vfile
  endif
  let output = readfile(temp)
  call delete(temp)

  for line in output
    call vimshell#print_line(a:context.fd, line)
  endfor
endfunction"}}}

function! vimshell#commands#vexe#define()
  return s:command
endfunction
