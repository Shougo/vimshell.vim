"=============================================================================
" FILE: vimshell_history.vim
" AUTHOR:  Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 25 Mar 2011.
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

if !exists(':Unite')
  echoerr 'unite.vim is not installed.'
  echoerr 'Please install unite.vim Ver.1.5 or above.'
  finish
elseif unite#version() < 100
  echoerr 'Your unite.vim is too old.'
  echoerr 'Please install unite.vim Ver.1.5 or above.'
  finish
endif

function! unite#sources#vimshell_history#define() "{{{
  return s:source
endfunction "}}}

let s:source = {
      \ 'name': 'vimshell/history',
      \ 'hooks' : {},
      \ 'max_candidates' : 100,
      \ 'default_action' : { '*' : 'execute' },
      \ 'action_table' : {},
      \ 'syntax' : 'uniteSource__VimshellHistory',
      \ 'alias_table' : { '*' : { 'ex' : 'nop', 'narrow' : 'edit' } },
      \ }

let s:current_histories = []
function! s:source.hooks.on_init(args, context) "{{{
  let s:current_histories = copy(vimshell#history#read())
  let a:context.source__cur_keyword_pos = len(vimshell#get_prompt())
endfunction"}}}
function! s:source.hooks.on_close(args, context) "{{{
  call vimshell#history#write(s:current_histories)
endfunction"}}}
function! s:source.hooks.on_syntax(args, context)"{{{
  syntax match uniteSource__VimshellHistorySpaces />-*\ze\s*$/ containedin=uniteSource__VimshellHistory
  highlight default link uniteSource__VimshellHistorySpaces Comment
endfunction"}}}

function! s:source.gather_candidates(args, context) "{{{
  let l:keyword_pos = a:context.source__cur_keyword_pos

  let l:cnt = 0
  let l:candidates = []
  for l:history in s:current_histories
    call add(l:candidates, {
          \   'word' : l:history,
          \   'abbr' : substitute(l:history, '\s\+$', '>-', ''),
          \   'kind': 'completion',
          \   'action__complete_word' : l:history,
          \   'action__complete_pos' : l:keyword_pos,
          \   'action__source_history_number' : l:cnt,
          \ })

    let l:cnt += 1
  endfor

  return l:candidates
endfunction "}}}

function! unite#sources#vimshell_history#start_complete() "{{{
  return printf("\<ESC>:call unite#start(['vimshell/history'],
        \ { 'col' : %d, 'complete' : 1,
        \   'input' : vimshell#get_cur_text(),
        \   'buffer_name' : 'completion', })\<CR>", len(vimshell#get_prompt()))
endfunction "}}}

" Actions"{{{
let s:action_table = {}

let s:action_table.delete = {
      \ 'description' : 'delete from vimshell history',
      \ 'is_invalidate_cache' : 1,
      \ 'is_quit' : 0,
      \ 'is_selectable' : 1,
      \ }
function! s:action_table.delete.func(candidates)"{{{
  for l:candidate in a:candidates
    call filter(s:current_histories, 'v:val !=# l:candidate.action__complete_word')
  endfor
endfunction"}}}

let s:action_table.edit = {
      \ 'description' : 'edit history',
      \ 'is_invalidate_cache' : 1,
      \ 'is_quit' : 0,
      \ }
function! s:action_table.edit.func(candidate)"{{{
  let l:history = input('Please edit history: ', a:candidate.action__complete_word)
  if l:history != ''
    let s:current_histories[a:candidate.action__source_history_number] = l:history
  endif
endfunction"}}}

let s:action_table.execute = {
      \ 'description' : 'execute history',
      \ }
function! s:action_table.execute.func(candidate)"{{{
  if !vimshell#check_prompt()
    echoerr 'Not in command line.'
    return
  endif

  call setline('.', vimshell#get_prompt() . a:candidate.action__complete_word)
  call vimshell#execute_current_line(unite#get_current_unite().context.complete)
endfunction"}}}

let s:source.action_table['*'] = s:action_table
unlet! s:action_table
"}}}

" vim: foldmethod=marker
