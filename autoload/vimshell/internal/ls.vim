"=============================================================================
" FILE: ls.vim
" AUTHOR: Shougo Matsushita <Shougo.Matsu@gmail.com>(Modified)
" Last Modified: 26 May 2009
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
" Version: 1.4, for Vim 7.0
"-----------------------------------------------------------------------------
" ChangeLog: "{{{
"   1.4:
"     - Use exe command.
"   1.3:
"     - Supported vimshell Ver.3.2.
"   1.2:
"     - Improved on Windows.
"   1.1:
"     - Added -FC option.
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
    let l:arguments = join(a:args, ' ')
    if has('win32') || has('win64')
        " For Windows.
        if empty(l:arguments)
            let l:command = 'ls.exe -FC'
        elseif l:arguments =~ '|'
            let l:command = printf('ls.exe %s', l:arguments)
        else
            let l:command = printf('ls.exe -FC %s', l:arguments)
        endif
    else
        " For Linux.
        if empty(l:arguments)
            let l:command = 'ls -FC'
        elseif l:arguments =~ '|'
            let l:command = printf('ls %s', l:arguments)
        else
            let l:command = printf('ls -FC %s', l:arguments)
        endif
    endif
    call vimshell#internal#exe#execute('exe', split(l:command), a:fd, a:other_info)
endfunction
