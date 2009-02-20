"=============================================================================
" FILE: popd.vim
" AUTHOR: Shougo Matsushita <Shougo.Matsu@gmail.com>(Modified)
" Last Modified: 25 Feb 2009
" Usage: Just source this file.
"        source vimshell.vim
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
" Version: 1.1, for Vim 7.0
"-----------------------------------------------------------------------------
" ChangeLog: "{{{
"   1.1:
"     - Use vimshell#error_line.
"   1.0:
"     - Initial version.
""}}}
"-----------------------------------------------------------------------------
" TODO: "{{{
"     - Nothing.
""}}}
" Bugs"{{{
"     -
""}}}
"=============================================================================

function! vimshell#internal#popd#execute(line, program, arguments, is_interactive, has_head_spaces, other_info)
    " Pop directory.

    if empty(w:vimshell_directory_stack)
        " Error.
        call vimshell#error_line('Directory stack is empty.')
        return
    endif

    let l:cnt = 0
    if a:arguments =~ '^\d\+$'
        let l:pop = str2nr(a:arguments)
    elseif empty(a:arguments)
        " Default pop value.
        let l:pop = 1
    else
        " Error.
        call vimshell#error_line('Error arguments.')
        return
    endif
    if l:pop >= len(w:vimshell_directory_stack)
        " Overflow.
        call vimshell#error_line('Not found in directory stack.')
        return
    endif

    execute 'cd ' . w:vimshell_directory_stack[l:pop]

    " Pop from stack.
    let w:vimshell_directory_stack = w:vimshell_directory_stack[l:pop+1:]
endfunction
