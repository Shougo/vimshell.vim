"=============================================================================
" FILE: vimdiff.vim
" AUTHOR: Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 14 Oct 2010
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
      \ 'name' : 'vimdiff',
      \ 'kind' : 'internal',
      \ 'description' : 'vimdiff {filename1} {filename2}',
      \}
function! s:command.execute(program, args, fd, context)"{{{
  " Diff file1 file2.

  if len(a:args) != 2
    " Error.
    call vimshell#error_line(a:fd, 'Usage: vimdiff file1 file2')
    return
  endif

  " Save current directiory.
  let l:cwd = getcwd()

  let l:save_winnr = winnr()

  " Split nicely.
  call vimshell#split_nicely()

  try
    edit `=a:args[0]`
  catch
    echohl Error | echomsg v:errmsg | echohl None
  endtry

  lcd `=l:cwd`

  vertical diffsplit `=a:args[1]`

  execute l:save_winnr.'wincmd w'

  if has_key(a:context, 'is_single_command') && a:context.is_single_command
    stopinsert
  endif
endfunction"}}}

function! vimshell#commands#vimdiff#define()
  return s:command
endfunction
