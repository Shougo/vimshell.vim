"=============================================================================
" FILE: gendoc.vim
" AUTHOR: Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 23 Dec 2010.
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
      \ 'name' : 'gendoc',
      \ 'kind' : 'internal',
      \ 'description' : 'gendoc {command} {args}',
      \}
function! s:command.execute(command, args, fd, context)"{{{
  " Generate cached doc.

  if empty(a:args)
    return
  endif

  " Get description.
  let l:command_name = fnamemodify(a:args[0], ':t:r')
  let l:output = split(vimproc#system(a:args).vimproc#get_last_errmsg(), '\n')
  let l:description = empty(l:output) ? '' : l:output[0]

  " Set cached doc.
  let l:cached_doc = vimshell#help#get_cached_doc()
  let l:cached_doc[l:command_name] = l:description
  call vimshell#help#set_cached_doc(l:cached_doc)
endfunction"}}}

function! vimshell#commands#gendoc#define()
  return s:command
endfunction
