"=============================================================================
" FILE: vimshell_complete.vim
" AUTHOR: Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 26 Mar 2012.
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

let s:save_cpo = &cpo
set cpo&vim

function! neocomplcache#sources#vimshell_complete#define()"{{{
  return s:source
endfunction"}}}

let s:source = {
      \ 'name' : 'vimshell_complete',
      \ 'kind' : 'ftplugin',
      \ 'filetypes' : { 'vimshell' : 1, },
      \}

function! s:source.initialize()"{{{
  " Initialize.
  call neocomplcache#set_completion_length('vimshell_complete',
        \ g:neocomplcache_auto_completion_start_length)
endfunction"}}}

function! s:source.get_keyword_pos(cur_text)"{{{
  if !vimshell#check_prompt()
    " Ignore.
    return -1
  endif

  try
    let args = vimshell#get_current_args(vimshell#get_cur_text())
  catch /^Exception:/
    return -1
  endtry

  if len(args) <= 1
    return len(vimshell#get_prompt())
  endif

  if a:cur_text =~ '\s\+$'
    " Add blank argument.
    call add(args, '')
  endif

  let pos = col('.')-len(args[-1])-1
  if args[-1] =~ '/'
    " Filename completion.
    let pos += match(args[-1], '\%(\\[^[:alnum:].-]\|\f\)\+$')
  endif

  return pos
endfunction"}}}

function! s:source.get_complete_words(cur_keyword_pos, cur_keyword_str)"{{{
  try
    let args = vimshell#get_current_args(vimshell#get_cur_text())
  catch /^Exception:/
    return []
  endtry

  let _ = (len(args) <= 1) ?
        \ s:get_complete_commands(a:cur_keyword_str) :
        \ s:get_complete_args(a:cur_keyword_str, args)

  if a:cur_keyword_str =~ '^\$'
    let _ += vimshell#complete#helper#variables(a:cur_keyword_str)
  endif

  return s:get_omni_list(_)
endfunction"}}}

function! s:get_complete_commands(cur_keyword_str)"{{{
  if a:cur_keyword_str =~ '/'
    " Filename completion.
    return vimshell#complete#helper#files(a:cur_keyword_str)
  endif

  let directories =
        \ vimshell#complete#helper#directories(a:cur_keyword_str)
  if a:cur_keyword_str =~ '^\./'
    for keyword in directories
      let keyword.word = './' . keyword.word
    endfor
  endif

  let _ = directories
        \ + vimshell#complete#helper#cdpath_directories(a:cur_keyword_str)
        \ + vimshell#complete#helper#aliases(a:cur_keyword_str)
        \ + vimshell#complete#helper#internals(a:cur_keyword_str)

  if len(a:cur_keyword_str) >= 1
    let _ += vimshell#complete#helper#executables(a:cur_keyword_str)
  endif

  return _
endfunction"}}}

function! s:get_complete_args(cur_keyword_str, args)"{{{
  " Get command name.
  let command = fnamemodify(a:args[0], ':t:r')

  let a:args[-1] = a:cur_keyword_str

  return vimshell#complete#helper#args(command, a:args[1:])
endfunction"}}}

function! s:get_omni_list(list)"{{{
  let omni_list = []

  " Convert string list.
  for str in filter(copy(a:list), 'type(v:val) == '.type(''))
    let dict = { 'word' : str, 'menu' : '[sh]' }

    call add(omni_list, dict)
  endfor

  for omni in filter(a:list, 'type(v:val) != '.type(''))
    let dict = {
          \'word' : omni.word, 'menu' : '[sh]',
          \'abbr' : has_key(omni, 'abbr')? omni.abbr : omni.word,
          \}

    if has_key(omni, 'kind')
      let dict.kind = omni.kind
    endif

    if has_key(omni, 'menu')
      let dict.menu .= ' ' . omni.menu
    endif

    if has_key(omni, 'info')
      let dict.info = omni.info
    endif

    call add(omni_list, dict)
  endfor

  return omni_list
endfunction"}}}

let &cpo = s:save_cpo
unlet s:save_cpo

" vim: foldmethod=marker
