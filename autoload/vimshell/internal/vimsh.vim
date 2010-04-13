"=============================================================================
" FILE: vimsh.vim
" AUTHOR: Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 06 Apr 2010
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

function! vimshell#internal#vimsh#execute(program, args, fd, other_info)
  " Create new vimshell or execute script.
  if empty(a:args)
    let l:context = a:other_info
    let l:context.fd = a:fd
    call vimshell#print_prompt(l:context)
    call vimshell#create_shell(0)
    return 1
  else
    " Filename escape.
    let l:filename = join(a:args, ' ')

    if filereadable(l:filename)
      let l:context = { 
            \'has_head_spaces' : 0, 'is_interactive' : 0, 
            \ 'fd' : { 'stdin' : '', 'stdout': '', 'stderr': ''}, 
            \}
      let l:i = 0
      let l:skip_prompt = 0
      for l:script in readfile(l:filename)
        try
          let l:skip_prompt = vimshell#parser#eval_script(l:script, l:context)
        catch /.*/
          let l:message = (v:exception !~# '^Vim:')? v:exception : v:exception . ' ' . v:throwpoint
          call vimshell#error_line({}, printf('%s(%d): %s', join(a:args), l:i, l:message))
          return 0
        endtry

        let l:i += 1
      endfor

      if l:skip_prompt
        " Skip prompt.
        return 1
      endif
    else
      " Error.
      call vimshell#error_line(a:fd, printf('Not found the script "%s".', l:filename))
    endif
  endif

  return 0
endfunction
