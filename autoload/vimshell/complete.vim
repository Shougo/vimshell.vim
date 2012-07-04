"=============================================================================
" FILE: complete.vim
" AUTHOR: Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 04 Jul 2012.
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

" Complete function. This provides simple file completion.
function! vimshell#complete#start()"{{{
  if len(&omnifunc) == 0
    setlocal omnifunc=vimshell#complete#candidate
  endif
  call feedkeys("\<c-x>\<c-o>", "n")
  return ''
endfunction"}}}
function! vimshell#complete#candidate(findstart, base)"{{{
  let line = getline('.')
  let prompt_len = len(vimshell#get_prompt())
  if a:findstart
    let part = matchstr(line, '\(\\\s\|[^ \\]\+\)*$')
    if len(part) == 0
      let pos = col('.')
    else
      let pos = strridx(line, part)
    endif
    return pos
  endif
  let files = filter(map(map(split(glob(a:base . '*'), "\n"),
  \ "isdirectory(v:val)?v:val.'/':v:val"),
  \ "fnameescape(substitute(v:val, '\\', '/', 'g'))"),
  \ 'stridx(v:val, a:base)==0')

  if line[prompt_len :] =~ '^\s*cd\s'
    call filter(files, 'v:val=~"/$"')
  endif
  return files
endfunction"}}}

" vim: foldmethod=marker
