"=============================================================================
" FILE: args_complete.vim
" AUTHOR: Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 10 Jul 2010
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

function! vimshell#complete#args_complete#complete()"{{{
  call vimshell#imdisable()

  if !vimshell#check_prompt()
    " Ignore.
    return ''
  endif

  if exists(':NeoComplCacheDisable')
    return neocomplcache#sources#completefunc_complete#call_completefunc('vimshell#complete#args_complete#omnifunc')
  else
    " Set complete function.
    let &l:omnifunc = 'vimshell#complete#args_complete#omnifunc'

    return "\<C-x>\<C-o>\<C-p>"
  endif
endfunction"}}}

function! vimshell#complete#args_complete#omnifunc(findstart, base)"{{{
  if a:findstart
    if !vimshell#check_prompt()
      return -1
    endif
    
    let l:args = vimshell#get_current_args()
    if len(l:args) <= 1
      return -1
    endif

    " Get cursor word.
    return col('.')-len(l:args[-1])-1
  endif

  " Get command name.
  let l:args = vimshell#get_current_args()
  if vimshell#get_cur_text() =~ '\s\+$'
    " Add blank argument.
    call add(l:args, '')
  endif
  let l:command = fnamemodify(l:args[0], ':t:r')

  " Save option.
  let l:ignorecase_save = &ignorecase

  " Complete.
  if g:vimshell_smart_case && a:base =~ '\u'
    let &ignorecase = 0
  else
    let &ignorecase = g:vimshell_ignore_case
  endif

  " Get complete words.
  let l:complete_words = vimshell#complete#args_complete#get_complete_words(l:command, l:args[1:])

  " Restore option.
  let &ignorecase = l:ignorecase_save

  " Trunk many items.
  let l:complete_words = l:complete_words[: g:vimshell_max_list-1]

  if &l:omnifunc != 'vimshell#complete#auto_complete#omnifunc'
    let &l:omnifunc = 'vimshell#complete#auto_complete#omnifunc'
  endif

  return l:complete_words
endfunction"}}}

function! vimshell#complete#args_complete#get_complete_words(command, args)"{{{
  let l:commands = vimshell#available_commands()
  
  " Get complete words.
  let l:complete_words = has_key(l:commands, a:command) && has_key(l:commands[a:command], 'complete') ?
        \ l:commands[a:command].complete(a:args) : vimshell#complete#helper#files(a:args[-1])
  
  return l:complete_words
endfunction"}}}
" vim: foldmethod=marker
