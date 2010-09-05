"=============================================================================
" FILE: vimshell_execute_complete.vim
" AUTHOR: Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 12 Apr 2010
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

function! vimshell#complete#vimshell_execute_complete#completefunc(arglead, cmdline, cursorpos)"{{{
  " Get complete words.
  let l:complete_words = {}
  " Get command name.
  let l:args = vimproc#parser#split_args(a:cmdline)
  if a:cmdline =~ '\s\+$'
    " Add blank argument.
    call add(l:args, '')
  endif
  for l:dict in vimshell#complete#internal#iexe#get_complete_words(l:args)
    if !has_key(l:complete_words, l:dict.word)
      let l:complete_words[l:dict.word] = 1
    endif
  endfor

  return keys(l:complete_words)
endfunction"}}}
" vim: foldmethod=marker
