"=============================================================================
" FILE: history_complete.vim
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

function! vimshell#complete#history_complete#whole()"{{{
  call vimshell#imdisable()

  if !vimshell#check_prompt()
    " Ignore.
    return ''
  endif

  return vimshell#complete#helper#call_omnifunc('vimshell#complete#history_complete#omnifunc_whole')
endfunction"}}}
function! vimshell#complete#history_complete#insert()"{{{
  call vimshell#imdisable()

  if !vimshell#check_prompt()
    " Ignore.
    return ''
  endif

  return vimshell#complete#helper#call_omnifunc('vimshell#complete#history_complete#omnifunc_insert')
endfunction"}}}

function! vimshell#complete#history_complete#omnifunc_whole(findstart, base)"{{{
  if a:findstart
    if !vimshell#check_prompt()
      " Not found prompt.
      return -1
    endif

    return len(vimshell#get_prompt())
  endif

  " Save options.
  let l:ignorecase_save = &ignorecase

  " Complete.
  if g:vimshell_smart_case && a:base =~ '\u'
    let &ignorecase = 0
  else
    let &ignorecase = g:vimshell_ignore_case
  endif

  let l:complete_words = s:collect_words(a:base)

  " Restore options.
  let &ignorecase = l:ignorecase_save
  call vimshell#complete#helper#restore_omnifunc('vimshell#complete#command_complete#omnifunc')

  return l:complete_words
endfunction"}}}
function! vimshell#complete#history_complete#omnifunc_insert(findstart, base)"{{{
  if a:findstart
    " Get cursor word.
    return match(vimshell#get_cur_text(), '\%([[:alnum:]_+~-]\|\\[ ]\)*$')
  endif

  " Save options.
  let l:ignorecase_save = &ignorecase

  " Complete.
  if g:vimshell_smart_case && a:base =~ '\u'
    let &ignorecase = 0
  else
    let &ignorecase = g:vimshell_ignore_case
  endif
  
  let l:complete_words = s:collect_words(a:base)

  " Restore options.
  let &ignorecase = l:ignorecase_save
  call vimshell#complete#helper#restore_omnifunc('vimshell#complete#command_complete#omnifunc')

  return l:complete_words
endfunction"}}}

function! s:collect_words(base)"{{{
  let l:complete_words = []
  
  if a:base != ''
    let l:bases = split(a:base)
    if &ignorecase
      let l:bases = map(l:bases, 'tolower(v:val)')
    endif
    
    for hist in g:vimshell#hist_buffer
      let l:matched = 1
      for l:str in l:bases
        if stridx(hist, l:str) == -1
          let l:matched = 0
          break
        endif
      endfor

      if l:matched
        call add(l:complete_words, { 'word' : hist, 'menu' : 'history' })
      endif
    endfor
    for hist in vimshell#history#external_read(g:vimshell_external_history_path)
      let l:matched = 1
      for l:str in l:bases
        if stridx(hist, l:str) == -1
          let l:matched = 0
          break
        endif
      endfor

      if l:matched
        call add(l:complete_words, { 'word' : hist, 'menu' : 'external-history' })
      endif
    endfor
    
    let l:complete_words = l:complete_words[: g:vimshell_max_list]
  else
    for hist in g:vimshell#hist_buffer[: g:vimshell_max_list]
      call add(l:complete_words, { 'word' : hist, 'menu' : 'history' })
    endfor
  endif

  return l:complete_words
endfunction"}}}
" vim: foldmethod=marker
