"=============================================================================
" FILE: vimshell_complete.vim
" AUTHOR: Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 09 Feb 2013.
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

function! neocomplcache#sources#vimshell_complete#define() "{{{
  return s:source
endfunction"}}}

let s:source = {
      \ 'name' : 'vimshell_complete',
      \ 'kind' : 'ftplugin',
      \ 'filetypes' : { 'vimshell' : 1, },
      \}

function! s:source.initialize() "{{{
  " Initialize.
  call neocomplcache#set_completion_length('vimshell_complete',
        \ g:neocomplcache_auto_completion_start_length)
endfunction"}}}

function! s:source.get_keyword_pos(cur_text) "{{{
  if !vimshell#check_prompt() || !empty(b:vimshell.continuation)
    " Ignore.
    return -1
  endif

  try
    let cur_text = vimproc#parser#parse_statements(
          \ vimshell#get_cur_text())[-1].statement
    let pipe = vimproc#parser#parse_pipe(cur_text)
    let arg = empty(pipe) ? '' : get(pipe[-1].args, -1, '')
  catch /^Exception:/
    return -1
  endtry

  if a:cur_text =~ '\s\+$'
    " Add blank argument.
    call add(args, '')
  endif

  let pos = col('.')-len(arg)-1
  if arg =~ '/'
    " Filename completion.
    let pos += match(arg,
          \ '\%(\\[^[:alnum:].-]\|\f\|[:]\)\+$')
  endif

  return pos
endfunction"}}}

function! s:source.get_complete_words(cur_keyword_pos, cur_keyword_str) "{{{
  try
    let cur_text = vimproc#parser#parse_statements(
          \ vimshell#get_cur_text())[-1].statement
    let args = vimproc#parser#parse_pipe(cur_text)[-1].args
  catch /^Exception:/
    return []
  endtry

  if empty(args)
    let args = ['']
  endif
  let cur_keyword_str = args[-1]

  let _ = (len(args) <= 1) ?
        \ s:get_complete_commands(cur_keyword_str) :
        \ s:get_complete_args(cur_keyword_str, args)

  if a:cur_keyword_str =~ '^\$'
    let _ += vimshell#complete#helper#variables(a:cur_keyword_str)
  endif

  return s:get_omni_list(_)
endfunction"}}}

function! s:get_complete_commands(cur_keyword_str) "{{{
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

function! s:get_complete_args(cur_keyword_str, args) "{{{
  " Get command name.
  let command = fnamemodify(a:args[0], ':t:r')

  let a:args[-1] = a:cur_keyword_str

  return vimshell#complete#helper#args(command, a:args[1:])
endfunction"}}}

function! s:get_omni_list(list) "{{{
  let omni_list = []

  " Convert string list.
  for val in deepcopy(a:list)
    if type(val) == type('')
      let dict = { 'word' : val, 'menu' : '[sh]' }
    else
      let dict = val
      let dict.menu = has_key(dict, 'menu') ?
            \ '[sh] ' . dict.menu : '[sh]'
    endif

    call add(omni_list, dict)

    unlet val
  endfor

  return omni_list
endfunction"}}}

let &cpo = s:save_cpo
unlet s:save_cpo

" vim: foldmethod=marker
