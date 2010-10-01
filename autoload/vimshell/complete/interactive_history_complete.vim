"=============================================================================
" FILE: interactive_history_complete.vim
" AUTHOR: Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 23 Sep 2010
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

function! vimshell#complete#interactive_history_complete#complete()"{{{
  return vimshell#complete#helper#call_omnifunc('vimshell#complete#interactive_history_complete#omnifunc')
endfunction"}}}

function! vimshell#complete#interactive_history_complete#omnifunc(findstart, base)"{{{
  if a:findstart
    return len(vimshell#interactive#get_prompt(line('.')))
  endif

  " Save option.
  let l:ignorecase_save = &ignorecase

  " Complete.
  if g:vimshell_smart_case && a:base =~ '\u'
    let &ignorecase = 0
  else
    let &ignorecase = g:vimshell_ignore_case
  endif

  " Collect words.
  let l:complete_words = []
  if a:base != ''
    let l:bases = split(a:base)
    if &ignorecase
      let l:bases = map(l:bases, 'tolower(v:val)')
    endif
    
    for hist in b:interactive.command_history
      let l:matched = 1
      for l:str in l:bases
        if stridx(hist, l:str) == -1
          let l:matched = 0
          break
        endif
      endfor

      if l:matched
        call add(l:complete_words, { 'word' : hist, 'menu' : 'int-history' })
      endif
    endfor
    let l:complete_words = l:complete_words[: g:vimshell_max_list]
  else
    for hist in b:interactive.command_history
      call add(l:complete_words, { 'word' : hist, 'menu' : 'int-history' })
    endfor
  endif

  " Restore option.
  let &ignorecase = l:ignorecase_save
  call vimshell#complete#helper#restore_omnifunc('')

  return l:complete_words
endfunction"}}}

" vim: foldmethod=marker
