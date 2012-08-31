"=============================================================================
" FILE: vimshell_zsh_complete.vim
" AUTHOR:  Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 31 Aug 2012.
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

let s:script_path = expand('<sfile>:p:h')
      \ .'/vimshell_zsh_complete/complete.zsh'

function! unite#sources#vimshell_zsh_complete#define() "{{{
  return s:source
endfunction "}}}

let s:source = {
      \ 'name': 'vimshell/zsh_complete',
      \ 'hooks' : {},
      \ 'max_candidates' : 100,
      \ 'action_table' : {},
      \ 'syntax' : 'uniteSource__VimshellHistory',
      \ 'is_listed' : 0,
      \ }

let s:current_histories = []

function! s:source.hooks.on_init(args, context) "{{{
  let a:context.source__cur_keyword_pos = len(vimshell#get_prompt())
  let a:context.source__input = vimshell#get_cur_text()
endfunction"}}}
function! s:source.hooks.on_syntax(args, context)"{{{
  " syntax match uniteSource__VimshellHistorySpaces />-*\ze\s*$/
  "       \ containedin=uniteSource__VimshellHistory
  " highlight default link uniteSource__VimshellHistorySpaces Comment
endfunction"}}}
function! s:source.hooks.on_close(args, context) "{{{
  if has_key(a:context, 'source__proc')
    call a:context.source__proc.waitpid()
  endif
endfunction"}}}
function! s:source.hooks.on_post_filter(args, context)"{{{
  for candidate in a:context.candidates
    let candidate.kind = 'completion'
    let candidate.action__complete_word = candidate.word
    let candidate.action__complete_pos =
          \ a:context.source__cur_keyword_pos
  endfor
endfunction"}}}
function! s:source.gather_candidates(args, context) "{{{
  let a:context.source__proc = vimproc#plineopen3('zsh -i -f', 1)

  call a:context.source__proc.stdin.write(
        \ 'source ' . string(s:script_path) . "\<LF>")

  call a:context.source__proc.stdin.write(
        \ a:context.source__input . "\<Tab>")

  return []
endfunction "}}}

function! s:source.async_gather_candidates(args, context) "{{{
  if !has_key(a:context, 'source__proc')
    return []
  endif

  let stderr = a:context.source__proc.stderr
  if !stderr.eof
    " Print error.
    let errors = filter(stderr.read_lines(-1, 100),
          \ "v:val !~ '^\\s*$'")
    if !empty(errors)
      call unite#print_source_error(errors, s:source.name)
    endif
  endif

  let stdout = a:context.source__proc.stdout
  if stdout.eof
    " Disable async.
    call unite#print_source_message('Completed.', s:source.name)
    let a:context.is_async = 0
  endif

  let output = stdout.read_lines(-1, 100)
  echomsg string(output)
  call filter(output, "v:val !~ '\\r'")

  return map(output, '{ "word" : v:val }')
endfunction "}}}

function! unite#sources#vimshell_zsh_complete#start_complete(is_insert) "{{{
  if !exists(':Unite')
    call vimshell#echo_error('unite.vim is not installed.')
    call vimshell#echo_error('Please install unite.vim Ver.1.5 or above.')
    return ''
  elseif unite#version() < 300
    call vimshell#echo_error('Your unite.vim is too old.')
    call vimshell#echo_error('Please install unite.vim Ver.3.0 or above.')
    return ''
  endif

  let cmdline = vimshell#get_cur_text()
  let args = vimproc#parser#split_args_through(cmdline)
  if empty(args) || cmdline =~ '\\\@!\s\+$'
    " Add blank argument.
    call add(args, '')
  endif

  return unite#start_complete(['vimshell/zsh_complete'], {
        \ 'start_insert' : a:is_insert,
        \ 'input' : args[-1],
        \ })
endfunction "}}}

" ies foldmethod=marker
