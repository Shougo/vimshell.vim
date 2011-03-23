"=============================================================================
" FILE: vimshell_history.vim
" AUTHOR:  Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 23 Mar 2011.
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
  if !exists('*unite#version') || unite#version() <= 100
    echoerr 'Your unite.vim is too old.'
    echoerr 'Please install unite.vim Ver.1.1 or above.'
    return []
  endif

  return s:source
endfunction "}}}

let s:source = {
      \ 'name': 'vimshell/history',
      \ 'hooks' : {},
      \ 'max_candidates' : 100,
      \ 'action_table' : {},
      \ }

let s:current_filetype = 'dummy'

function! s:source.hooks.on_init(args, context) "{{{
  let s:current_filetype = &filetype
  let a:context.source__cur_keyword_pos = len(vimshell#get_prompt())
  let a:context.source__candidates = s:current_filetype ==# 'vimshell' ?
        \ g:vimshell#hist_buffer + vimshell#history#external_read(g:vimshell_external_history_path) :
        \ b:interactive.command_history
endfunction"}}}

function! s:source.gather_candidates(args, context) "{{{
  let l:keyword_pos = a:context.source__cur_keyword_pos

  return map(copy(a:context.source__candidates), '{
        \   "word" : v:val,
        \   "kind": "completion",
        \   "action__complete_word" : v:val,
        \   "action__complete_pos" : l:keyword_pos,
        \ }')
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
  let l:histories = s:current_filetype ==# 'vimshell' ?
        \ g:vimshell#hist_buffer :
        \ b:interactive.command_history

  for l:candidate in a:candidates
    call filter(l:histories, 'v:val !=# l:candidate.action__complete_word')
  endfor
endfunction"}}}

let s:source.action_table['*'] = s:action_table
unlet! s:action_table
"}}}

" vim: foldmethod=marker
