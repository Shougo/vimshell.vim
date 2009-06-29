"=============================================================================
" FILE: ls.vim
" AUTHOR: Shougo Matsushita <Shougo.Matsu@gmail.com>(Modified)
" Last Modified: 26 Jun 2009
" Usage: Just source this file.
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
" Version: 1.6, for Vim 7.0
"-----------------------------------------------------------------------------
" ChangeLog: "{{{
"   1.6:
"     - Check pipe.
"
"   1.5:
"     - Optimized.
"
"   1.4:
"     - Use exe command.
"
"   1.3:
"     - Supported vimshell Ver.3.2.
"
"   1.2:
"     - Improved on Windows.
"
"   1.1:
"     - Added -FC option.
"
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

function! vimshell#internal#ls#execute(program, args, fd, other_info)
    let l:arguments = a:args

    " Check pipe.
    let l:pipe_found = 0
    for arg in a:args
        if arg == '|'
            let l:pipe_found = 1
            break
        endif
    endfor

    if a:fd.stdout == '' && !l:pipe_found
        call insert(l:arguments, '-FC')
    endif

    if has('win32') || has('win64')
        call insert(l:arguments, 'ls.exe')
    else
        call insert(l:arguments, 'ls')
    endif

    call vimshell#internal#exe#execute('exe', l:arguments, a:fd, a:other_info)
endfunction
