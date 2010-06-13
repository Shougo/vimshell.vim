"=============================================================================
" FILE: popd.vim
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

function! vimshell#internal#popd#execute(program, args, fd, other_info)
  " Pop directory.

  if empty(b:vimshell.directory_stack)
    " Error.
    call vimshell#error_line(a:fd, 'popd: Directory stack is empty.')
    return
  endif

  let l:cnt = 0
  let l:arguments = join(a:args)
  if l:arguments =~ '^\d\+$'
    let l:pop = str2nr(l:arguments)
  elseif empty(l:arguments)
    " Default pop value.
    let l:pop = 0
  else
    " Error.
    call vimshell#error_line(a:fd, 'popd: Arguments error.')
    return
  endif

  if l:pop >= len(b:vimshell.directory_stack)
    " Overflow.
    call vimshell#error_line(a:fd, printf("popd: Not found '%d' in directory stack.", l:pop))
    return
  endif

  lcd `=b:vimshell.directory_stack[l:pop]`
  if a:other_info.is_interactive
    " Call chpwd hook.
    let l:context = a:other_info
    let l:context.fd = a:fd
    call vimshell#hook#call('chpwd', l:context)
  endif

  " Pop from stack.
  let b:vimshell.directory_stack = b:vimshell.directory_stack[l:pop+1:]
endfunction
