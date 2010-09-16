"=============================================================================
" FILE: which.vim
" AUTHOR: Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 17 Aug 2010
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
      \ 'name' : 'which',
      \ 'kind' : 'internal',
      \ 'description' : 'which command',
      \}
function! s:command.execute(command, args, fd, context)"{{{
  if empty(a:args)
    return
  endif

  let l:name = a:args[0]
  if vimshell#get_alias(l:name) != ''
    let l:line = printf('which: %s: aliased to %s', l:name, vimshell#get_alias(l:name))
  else
    let l:path = vimshell#get_command_path(l:name)
    if l:path != ''
      let l:line = printf('which: %s', l:path)
    else
      let l:line = printf('which: %s is not found', l:name)
    endif
  endif
  
  call vimshell#print_line(a:fd, l:line)
endfunction"}}}

function! vimshell#commands#which#define()
  return s:command
endfunction
