"=============================================================================
" FILE: vim.vim
" AUTHOR: Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 08 Jun 2010
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

function! vimshell#internal#vim#execute(program, args, fd, other_info)
  " Edit file.

  if empty(a:args)
    " Read from stdin.
    let l:filename = a:fd.stdin
  else
    let l:filename = a:args[0]
  endif

  let l:context = a:other_info
  let l:context.fd = a:fd
  call vimshell#print_prompt(l:context)

  " Save current directiory.
  let l:cwd = getcwd()

  " Split nicely.
  if winwidth(0) > 2 * &winwidth
    let l:is_split = 0
  else
    let l:is_split = 1
  endif

  if l:filename == ''
    if l:is_split
      new
    else
      vnew
    endif
  else
    " Split nicely.
    call vimshell#split_nicely()

    try
      edit `=l:filename`
    catch
      echohl Error | echomsg v:errmsg | echohl None
    endtry

  endif
  
  " Call explorer.
  doautocmd BufEnter

  lcd `=l:cwd`

  return 1
endfunction
