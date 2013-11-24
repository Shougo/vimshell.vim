"=============================================================================
" FILE: view.vim
" AUTHOR: Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 24 Nov 2013.
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

function! vimshell#view#_close(buffer_name) "{{{
  let quit_winnr = vimshell#util#get_vimshell_winnr(a:buffer_name)
  if quit_winnr > 0
    " Hide unite buffer.
    silent execute quit_winnr 'wincmd w'

    if winnr('$') != 1
      close
    else
      call vimshell#util#alternate_buffer()
    endif
  endif

  return quit_winnr > 0
endfunction"}}}
function! vimshell#view#_print_prompt(...) "{{{
  if &filetype !=# 'vimshell' || line('.') != line('$')
        \ || !empty(b:vimshell.continuation)
    return
  endif

  " Save current directory.
  let b:vimshell.prompt_current_dir[vimshell#get_prompt_linenr()] = getcwd()

  let context = a:0 >= 1? a:1 : vimshell#get_context()

  " Call preprompt hook.
  call vimshell#hook#call('preprompt', context, [])

  " Search prompt
  if empty(b:vimshell.commandline_stack)
    let new_prompt = vimshell#get_prompt()
  else
    let new_prompt = b:vimshell.commandline_stack[-1]
    call remove(b:vimshell.commandline_stack, -1)
  endif

  if vimshell#get_user_prompt() != '' ||
        \ vimshell#get_right_prompt() != ''
    " Insert user prompt line.
    call s:insert_user_and_right_prompt()
  endif

  " Insert prompt line.
  if getline('$') == ''
    call setline('$', new_prompt)
  else
    call append('$', new_prompt)
  endif

  $
  let &modified = 0
endfunction"}}}

function! s:insert_user_and_right_prompt() "{{{
  let user_prompt = vimshell#get_user_prompt()
  if user_prompt != ''
    for user in split(eval(user_prompt), "\\n", 1)
      try
        let secondary = '[%] ' . user
      catch
        let message = v:exception . ' ' . v:throwpoint
        echohl WarningMsg | echomsg message | echohl None

        let secondary = '[%] '
      endtry

      if getline('$') == ''
        call setline('$', secondary)
      else
        call append('$', secondary)
      endif
    endfor
  endif

  " Insert right prompt line.
  if vimshell#get_right_prompt() == ''
    return
  endif

  try
    let right_prompt = eval(vimshell#get_right_prompt())
    let b:vimshell.right_prompt = right_prompt
  catch
    let message = v:exception . ' ' . v:throwpoint
    echohl WarningMsg | echomsg message | echohl None

    let right_prompt = ''
  endtry

  if right_prompt == ''
    return
  endif

  let user_prompt_last = (user_prompt != '') ?
        \   getline('$') : '[%] '
  let winwidth = (winwidth(0)+1)/2*2 - 5
  let padding_len =
        \ (len(user_prompt_last)+len(vimshell#get_right_prompt())+1
        \          > winwidth) ?
        \ 1 : winwidth - (len(user_prompt_last)+len(right_prompt))
  let secondary = printf('%s%s%s', user_prompt_last,
        \ repeat(' ', padding_len), right_prompt)
  if getline('$') == '' || vimshell#get_user_prompt() != ''
    call setline('$', secondary)
  else
    call append('$', secondary)
  endif

  let prompts_save = {}
  let prompts_save.right_prompt = right_prompt
  let prompts_save.user_prompt_last = user_prompt_last
  let prompts_save.winwidth = winwidth
  let b:vimshell.prompts_save[line('$')] = prompts_save
endfunction"}}}

let &cpo = s:save_cpo
unlet s:save_cpo

" vim: foldmethod=marker
