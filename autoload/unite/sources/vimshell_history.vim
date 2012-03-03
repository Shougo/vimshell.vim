"=============================================================================
" FILE: vimshell_history.vim
" AUTHOR:  Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 27 Feb 2012.
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

function! unite#sources#vimshell_history#define() "{{{
  return s:source
endfunction "}}}

let s:source = {
      \ 'name': 'vimshell/history',
      \ 'hooks' : {},
      \ 'max_candidates' : 100,
      \ 'action_table' : {},
      \ 'syntax' : 'uniteSource__VimshellHistory',
      \ 'is_listed' : 0,
      \ 'filters' : ['matcher_default', 'sorter_nothing', 'converter_default'],
      \ }

let s:current_histories = []

function! s:source.hooks.on_init(args, context) "{{{
  call unite#sources#vimshell_history#_change_histories(
        \ vimshell#history#read())
  let a:context.source__cur_keyword_pos = len(vimshell#get_prompt())
endfunction"}}}
function! s:source.hooks.on_syntax(args, context)"{{{
  syntax match uniteSource__VimshellHistorySpaces />-*\ze\s*$/
        \ containedin=uniteSource__VimshellHistory
  highlight default link uniteSource__VimshellHistorySpaces Comment
endfunction"}}}
function! s:source.hooks.on_close(args, context) "{{{
  let a:context.source__cur_keyword_pos = len(vimshell#get_prompt())
  if vimshell#history#read() != s:current_histories
    call vimshell#history#write(s:current_histories)
  endif
endfunction"}}}
function! s:source.hooks.on_post_filter(args, context)"{{{
  let cnt = 0

  for candidate in a:context.candidates
    let candidate.abbr =
          \ substitute(candidate.word, '\s\+$', '>-', '')
    let candidate.kind = 'vimshell/history'
    let candidate.action__complete_word = candidate.word
    let candidate.action__complete_pos =
          \ a:context.source__cur_keyword_pos
    let candidate.action__source_history_number = cnt
    let candidate.action__current_histories = s:current_histories
    let candidate.action__is_external = 0

    let cnt += 1
  endfor
endfunction"}}}

function! s:source.gather_candidates(args, context) "{{{
  return map(copy(s:current_histories),
        \ '{ "word" : v:val }')
endfunction "}}}

function! unite#sources#vimshell_history#start_complete(is_insert) "{{{
  if !exists(':Unite')
    call vimshell#echo_error('unite.vim is not installed.')
    call vimshell#echo_error('Please install unite.vim Ver.1.5 or above.')
    return ''
  elseif unite#version() < 300
    call vimshell#echo_error('Your unite.vim is too old.')
    call vimshell#echo_error('Please install unite.vim Ver.3.0 or above.')
    return ''
  endif

  return unite#start_complete(['vimshell/history', 'vimshell/external_history'], {
        \ 'start_insert' : a:is_insert,
        \ 'input' : vimshell#get_cur_text(),
        \ })
endfunction "}}}

function! unite#sources#vimshell_history#_change_histories(histories) "{{{
  let s:current_histories = a:histories
endfunction "}}}

" ies foldmethod=marker
