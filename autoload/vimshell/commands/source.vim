"=============================================================================
" FILE: source.vim
" AUTHOR: Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 29 May 2011.
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
      \ 'name' : 'source',
      \ 'kind' : 'internal',
      \ 'description' : 'source files...',
      \}
function! s:command.execute(program, args, fd, context)"{{{
  if len(a:args) < 1
    return
  endif

  let l:output = vimshell#iswin() ?
        \ system(printf('cmd /c "%s& set"', join(map(a:args, '"\"".v:val."\""'), '& '))) :
        \ vimproc#system(printf('%s -c ''%s; env''', &shell, join(map(a:args, '"source ".v:val.""'), '; ')))
  let l:output = vimproc#util#iconv(l:output, vimproc#util#termencoding(), &encoding)
  let l:variables = {}
  for l:line in split(l:output, '\n\|\r\n')
    if l:line =~ '^\u\w*='
      let l:name = '$'.matchstr(l:line, '^\u\w*')
      let l:val = matchstr(l:line, '^\u\w*=\zs.*')
      let l:variables[l:name] = l:val
    endif
  endfor

  call vimshell#set_variables(l:variables)
endfunction"}}}

function! vimshell#commands#source#define()
  return s:command
endfunction
