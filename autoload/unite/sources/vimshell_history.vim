"=============================================================================
" FILE: vimshell_history.vim
" AUTHOR:  Shougo Matsushita <Shougo.Matsu@gmail.com>
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
      \ 'is_listed' : 0,
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
function! s:source.hooks.on_post_filter(args, context)"{{{
  let cnt = 0

  for candidate in a:context.candidates
    let candidate.abbr = substitute(candidate.word, '\s\+$', '>-', '')
    let candidate.kind = 'completion'
    let candidate.action__complete_word = candidate.word
    let candidate.action__complete_pos = a:context.source__cur_keyword_pos
    let candidate.action__source_history_number = cnt

    let cnt += 1
  endfor
endfunction"}}}

function! s:source.gather_candidates(args, context) "{{{
  return map(copy(s:current_histories), '{ "word" : v:val }')
endfunction "}}}

function! unite#sources#vimshell_history#start_complete(is_insert) "{{{
  if !exists(':Unite')
    echoerr 'unite.vim is not installed.'
    echoerr 'Please install unite.vim Ver.1.5 or above.'
    return ''
  elseif unite#version() < 300
    echoerr 'Your unite.vim is too old.'
    echoerr 'Please install unite.vim Ver.3.0 or above.'
    return ''
  endif

  return unite#start_complete(['vimshell/history'], {
        \ 'start_insert' : a:is_insert,
        \ 'input' : vimshell#get_cur_text(),
        \ })
endfunction "}}}

" Actions"{{{
let s:source.action_table.delete = {
      \ 'description' : 'delete from vimshell history',
      \ 'is_invalidate_cache' : 1,
      \ 'is_quit' : 0,
      \ 'is_selectable' : 1,
      \ }
function! s:source.action_table.delete.func(candidates)"{{{
  for candidate in a:candidates
    call filter(s:current_histories, 'v:val !=# candidate.action__complete_word')
  endfor
endfunction"}}}

let s:source.action_table.edit = {
      \ 'description' : 'edit history',
      \ 'is_invalidate_cache' : 1,
      \ 'is_quit' : 0,
      \ }
function! s:source.action_table.edit.func(candidate)"{{{
  let history = input('Please edit history: ', a:candidate.action__complete_word)
  if history != ''
    let s:current_histories[a:candidate.action__source_history_number] = history
  endif
endfunction"}}}

let s:source.action_table.execute = {
      \ 'description' : 'execute history',
      \ }
function! s:source.action_table.execute.func(candidate)"{{{
  call unite#take_action('insert', a:candidate)

  call vimshell#execute_current_line(unite#get_current_unite().context.complete)
endfunction"}}}

let s:source.action_table.insert = {
      \ 'description' : 'insert history',
      \ }
function! s:source.action_table.insert.func(candidate)"{{{
  if !vimshell#check_prompt()
    echoerr 'Not in command line.'
    return
  endif

  call setline('.', vimshell#get_prompt() . a:candidate.action__complete_word)
  if unite#get_context().complete
    startinsert!
  else
    normal! $
  endif
endfunction"}}}
"}}}

" vim: foldmethod=marker
