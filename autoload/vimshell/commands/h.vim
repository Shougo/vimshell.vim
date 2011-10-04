"=============================================================================
" FILE: h.vim
" AUTHOR: Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 30 Jul 2010
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

let s:command = {
      \ 'name' : 'h',
      \ 'kind' : 'internal',
      \ 'description' : 'h [{pattern}]',
      \}
function! s:command.execute(args, context)"{{{
  " Execute from history.

  let histories = vimshell#history#read()
  if empty(a:args) || a:args[0] =~ '^\d\+'
    if empty(a:args)
      let num = 0
    else
      let num = str2nr(a:args[0])
    endif

    if num >= len(histories)
      " Error.
      call vimshell#error_line(a:context.fd, 'h: Not found in history.')
      return
    endif

    let hist = histories[num]
  else
    let args = join(a:args)
    for h in histories
      if vimshell#head_match(h, args)
        let hist = h
        break
      endif
    endfor

    if !exists('hist')
      " Error.
      call vimshell#error_line(a:context.fd, 'h: Not found in history.')
      return
    endif
  endif

  if a:context.has_head_spaces
    let hist = ' ' . hist
  endif
  call vimshell#set_prompt_command(hist)

  let context = a:context
  let context.is_interactive = 0
  let context.fd = a:context.fd
  try
    call vimshell#parser#eval_script(hist, context)
  catch /.*/
    call vimshell#error_line({}, v:exception)
    call vimshell#print_prompt(context)

    if has_key(context, 'is_insert') && context.is_insert
      call vimshell#start_insert()
    endif
    return
  endtry
endfunction"}}}

function! vimshell#commands#h#define()
  return s:command
endfunction
