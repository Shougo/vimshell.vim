"=============================================================================
" FILE: history.vim
" AUTHOR: Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 07 Jul 2010
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
      \ 'name' : 'history',
      \ 'kind' : 'internal',
      \ 'description' : 'history [{search-string}]',
      \}
function! s:command.execute(command, args, fd, other_info)"{{{
  let l:cnt = 0
  let l:arguments = join(a:args, ' ')
  if l:arguments =~ '^\d\+$'
    let l:search = ''
    let l:max = str2nr(l:arguments)
  elseif empty(l:arguments)
    " Default max value.
    let l:search = ''
    let l:max = 20
  else
    let l:search = l:arguments
    let l:max = len(g:vimshell#hist_buffer)
  endif
  
  if l:max <=0 || l:max >= len(g:vimshell#hist_buffer)
    " Overflow.
    let l:max = len(g:vimshell#hist_buffer)
  endif
  
  let l:list = []
  let l:cnt = 1
  for l:hist in g:vimshell#hist_buffer
    if vimshell#head_match(l:hist, l:search)
      call add(l:list, [l:cnt, l:hist])
    endif

    let l:cnt += 1
  endfor
  
  for [l:cnt, l:hist] in l:list[: l:max-1]
    call vimshell#print_line(a:fd, printf('%3d: %s', l:cnt, l:hist))
  endfor
endfunction"}}}

function! vimshell#commands#history#define()
  return s:command
endfunction
