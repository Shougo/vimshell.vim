"=============================================================================
" FILE: sudo.vim
" AUTHOR: Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 09 Jul 2010
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
      \ 'name' : 'sudo',
      \ 'kind' : 'internal',
      \ 'description' : 'sudo {command}',
      \}
function! s:command.execute(program, args, fd, other_info)"{{{
  " Execute GUI program.
  if empty(a:args)
    call vimshell#error_line(a:fd, 'sudo: Arguments required.')
    return
  elseif a:args[0] == 'vim'
    let l:args = a:args[1:]
    let l:args[0] = 'sudo:' . l:args[0]
    call vimshell#execute_internal_command('vim', l:args, a:fd, a:other_info)
  else
    call vimshell#execute_internal_command('iexe', insert(a:args, 'sudo'), a:fd, a:other_info)
  endif
endfunction"}}}
function! s:command.complete(args)"{{{
    return vimshell#complete#helper#command_args(a:args)
endfunction"}}}

function! vimshell#commands#sudo#define()
  return s:command
endfunction
