"=============================================================================
" FILE: command_complete.vim
" AUTHOR: Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 19 Sep 2011.
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

  return vimshell#complete#command_complete#get_candidates(
        \ vimshell#get_cur_text(), a:findstart, a:base)
endfunction"}}}

function! vimshell#complete#command_complete#get_candidates(cur_text, findstart, base)"{{{
  try
    let args = vimshell#get_current_args(a:cur_text)
  catch /^Exception:/
    return a:findstart ? -1 : []
  endtry

  if len(args) <= 1
    return s:complete_commands(a:findstart, a:base)
  else
    if a:findstart && a:cur_text =~ '\s\+$'
      " Add blank argument.
      call add(args, '')
    endif

    return s:complete_args(a:findstart, a:base, args)
  endif
endfunction"}}}

function! s:complete_commands(findstart, base)"{{{
  if a:findstart
    return len(vimshell#get_prompt())
  endif

  " Save option.
  let ignorecase_save = &ignorecase

  " Complete.
  if g:vimshell_smart_case && a:base =~ '\u'
    let &ignorecase = 0
  else
    let &ignorecase = g:vimshell_ignore_case
  endif

  let complete_words = s:get_complete_commands(a:base)

  " Restore option.
  let &ignorecase = ignorecase_save

  return complete_words
endfunction"}}}

function! s:get_complete_commands(cur_keyword_str)"{{{
  " Save option.
  let ignorecase_save = &ignorecase

  " Complete.
  if g:vimshell_smart_case && a:cur_keyword_str =~ '\u'
    let &ignorecase = 0
  else
    let &ignorecase = g:vimshell_ignore_case
  endif

  if a:cur_keyword_str =~ '/'
    " Filename completion.
    let ret = vimshell#complete#helper#files(a:cur_keyword_str)

    " Restore option.
    let &ignorecase = ignorecase_save

    return ret
  endif

  let directories = vimshell#complete#helper#directories(a:cur_keyword_str)
  if a:cur_keyword_str =~ '^\./'
    for keyword in directories
      let keyword.word = './' . keyword.word
    endfor
  endif

  let ret =    directories
        \ + vimshell#complete#helper#cdpath_directories(a:cur_keyword_str)
        \ + vimshell#complete#helper#aliases(a:cur_keyword_str)
        \ + vimshell#complete#helper#internals(a:cur_keyword_str)

  if len(a:cur_keyword_str) >= 1
    let ret += vimshell#complete#helper#executables(a:cur_keyword_str)
  endif

  " Restore option.
  let &ignorecase = ignorecase_save

  return ret
endfunction"}}}

function! s:complete_args(findstart, base, args)"{{{
  if a:findstart
    let pos = col('.')-len(a:args[-1])-1
    if a:args[-1] =~ '/'
      " Filename completion.
      let pos += match(a:args[-1], '\%(\\[^[:alnum:].-]\|\f\)\+$')
    endif

    return pos
  endif

  " Get command name.
  let command = fnamemodify(a:args[0], ':t:r')

  " Save option.
  let ignorecase_save = &ignorecase

  " Complete.
  if g:vimshell_smart_case && a:base =~ '\u'
    let &ignorecase = 0
  else
    let &ignorecase = g:vimshell_ignore_case
  endif

  let a:args[-1] = a:base

  " Get complete words.
  let complete_words = vimshell#complete#helper#args(command, a:args[1:])

  " Restore option.
  let &ignorecase = ignorecase_save

  " Truncate many items.
  let complete_words = complete_words[: g:vimshell_max_list-1]

  return complete_words
endfunction"}}}

" vim: foldmethod=marker
