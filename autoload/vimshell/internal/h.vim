"=============================================================================
" FILE: h.vim
" AUTHOR: Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 13 Jun 2010
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

function! vimshell#internal#h#execute(program, args, fd, other_info)
  " Execute from history.

  if empty(a:args) || a:args[0] =~ '^\d\+'
    if empty(a:args)
      let l:num = 0
    else
      let l:num = str2nr(a:args[0])
    endif

    if l:num >= len(g:vimshell#hist_buffer)
      " Error.
      call vimshell#error_line(a:fd, 'h: Not found in history.')
      return
    endif

    let l:hist = g:vimshell#hist_buffer[l:num]
  else
    let l:args = '^' . escape(join(a:args), '~" \.^$[]*')
    for h in g:vimshell#hist_buffer
      if h =~ l:args
        let l:hist = h
        break
      endif
    endfor

    if !exists('l:hist')
      " Error.
      call vimshell#error_line(a:fd, 'h: Not found in history.')
      return
    endif
  endif

  if a:other_info.has_head_spaces
    let l:hist = ' ' . l:hist
  endif
  call vimshell#set_prompt_command(l:hist)

  try
    call vimshell#parser#eval_script(l:hist, a:other_info)
  catch /.*/
    call vimshell#error_line({}, v:exception)
    let l:context = a:other_info
    let l:context.fd = a:fd
    call vimshell#print_prompt(l:context)

    if has_key(a:other_info, 'is_insert') && a:other_info.is_insert
      call vimshell#start_insert()
    endif
    return
  endtry
endfunction
