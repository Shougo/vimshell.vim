"=============================================================================
" FILE: command_complete.vim
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

function! vimshell#complete#command_complete#complete()"{{{
  call vimshell#imdisable()

  if !vimshell#check_prompt()
    " Ignore.
    return ''
  endif

  " Command completion.
  return vimshell#complete#helper#call_omnifunc('vimshell#complete#command_complete#omnifunc')
endfunction"}}}

function! vimshell#complete#command_complete#omnifunc(findstart, base)"{{{
  if !vimshell#check_prompt()
    " Ignore.
    return -1
  endif

  try
    let l:args = vimshell#get_current_args()
  catch /^Exception: Quote/
    return []
  endtry

  if len(l:args) <= 1
    return s:complete_commands(a:findstart, a:base)
  else
    if vimshell#get_cur_text() =~ '\s\+$'
      " Add blank argument.
      call add(l:args, '')
    endif

    return s:complete_args(a:findstart, a:base, l:args)
  endif
endfunction"}}}

function! s:complete_commands(findstart, base)"{{{
  if a:findstart
    return len(vimshell#get_prompt())
  endif

  " Save option.
  let l:ignorecase_save = &ignorecase

  " Complete.
  if g:vimshell_smart_case && a:base =~ '\u'
    let &ignorecase = 0
  else
    let &ignorecase = g:vimshell_ignore_case
  endif

  let l:complete_words = s:get_complete_commands(a:base)

  " Restore option.
  let &ignorecase = l:ignorecase_save

  return l:complete_words
endfunction"}}}

function! s:get_complete_commands(cur_keyword_str)"{{{
  " Save option.
  let l:ignorecase_save = &ignorecase

  " Complete.
  if g:vimshell_smart_case && a:base =~ '\u'
    let &ignorecase = 0
  else
    let &ignorecase = g:vimshell_ignore_case
  endif

  if a:cur_keyword_str =~ '/'
    " Filename completion.
    let l:ret = vimshell#complete#helper#files(a:cur_keyword_str)
    
    " Restore option.
    let &ignorecase = l:ignorecase_save

    return l:ret
  endif

  let l:directories = vimshell#complete#helper#directories(a:cur_keyword_str)
  if a:cur_keyword_str =~ '^\./'
    for l:keyword in l:directories
      let l:keyword.word = './' . l:keyword.word
    endfor
  endif
  
  let l:ret =    l:directories
        \+ vimshell#complete#helper#cdpath_directories(a:cur_keyword_str)
        \+ vimshell#complete#helper#aliases(a:cur_keyword_str)
        \+ vimshell#complete#helper#internals(a:cur_keyword_str)

  if len(a:cur_keyword_str) >= 1
    let l:ret += vimshell#complete#helper#executables(a:cur_keyword_str)
  endif

  " Restore option.
  let &ignorecase = l:ignorecase_save

  return l:ret
endfunction"}}}

function! s:complete_args(findstart, base, args)"{{{
  if a:findstart
    " Get cursor word.
    return col('.')-len(a:args[-1])-1
  endif

  " Get command name.
  let l:command = fnamemodify(a:args[0], ':t:r')

  " Save option.
  let l:ignorecase_save = &ignorecase

  " Complete.
  if g:vimshell_smart_case && a:base =~ '\u'
    let &ignorecase = 0
  else
    let &ignorecase = g:vimshell_ignore_case
  endif

  " Get complete words.
  let l:complete_words = vimshell#complete#helper#args(l:command, a:args[1:])

  " Restore option.
  let &ignorecase = l:ignorecase_save

  " Truncate many items.
  let l:complete_words = l:complete_words[: g:vimshell_max_list-1]

  return l:complete_words
endfunction"}}}

" vim: foldmethod=marker
