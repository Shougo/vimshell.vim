"=============================================================================
" FILE: bcd.vim
" AUTHOR: Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 13 Jun 2010
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

function! vimshell#internal#bcd#execute(program, args, fd, other_info)
  " Change working directory with buffer directory.

  if empty(a:args)
    " Move to alternate buffer directory.
    let l:bufname = bufnr('#')
  elseif len(a:args) > 2
    call vimshell#error_line(a:fd, 'bcd: Too many arguments.')
    return
  else
    let l:bufname = bufnr(a:args[0])
  endif

  let l:bufnumber = bufnr(l:bufname)

  if l:bufnumber >= 0
    let l:bufdir = fnamemodify(bufname(l:bufnumber), ':p:h')
    return vimshell#internal#cd#execute('cd', [ l:bufdir ], a:fd, a:other_info)
  else
    call vimshell#error_line(a:fd, printf('bcd: Buffer "%s" is not found.', l:arguments))
  endif
endfunction
