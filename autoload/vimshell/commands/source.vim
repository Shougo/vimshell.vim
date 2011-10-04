"=============================================================================
" FILE: source.vim
" AUTHOR: Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 04 Oct 2011.
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
function! s:command.execute(args, context)"{{{
  if len(a:args) < 1
    return
  endif

  let output = vimshell#iswin() ?
        \ system(printf('cmd /c "%s& set"', join(map(a:args, '"\"".v:val."\""'), '& '))) :
        \ vimproc#system(printf('%s -c ''%s; env''', &shell, join(map(a:args, '"source ".v:val.""'), '; ')))
  let output = vimproc#util#iconv(output, vimproc#util#termencoding(), &encoding)
  let variables = {}
  for line in split(output, '\n\|\r\n')
    if line =~ '^\u\w*='
      let name = '$'.matchstr(line, '^\u\w*')
      let val = matchstr(line, '^\u\w*=\zs.*')
      let variables[name] = val
    endif
  endfor

  call vimshell#set_variables(variables)
endfunction"}}}

function! vimshell#commands#source#define()
  return s:command
endfunction
