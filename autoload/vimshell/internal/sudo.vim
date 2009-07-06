"=============================================================================
" FILE: sudo.vim
" AUTHOR: Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 05 Jul 2009
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
" Version: 1.1, for Vim 7.0
"-----------------------------------------------------------------------------
" ChangeLog: "{{{
"   1.1:
"     - Improved in console.
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

function! vimshell#internal#sudo#execute(program, args, fd, other_info)
    " Execute GUI program.
    if has('win32') || has('win64') || has('mac')
        call vimshell#error_line(a:fd, 'This platform is not supported.')
        return 0
    elseif empty(a:args)
        call vimshell#error_line(a:fd, 'Arguments required.')
        return 0
    elseif has('gui_running')
        return vimshell#internal#iexe#execute('iexe', insert(a:args, 'sudo'), a:fd, a:other_info)
    else
        " Console.
        let l:interactive_save = g:VimShell_EnableInteractive
        let g:VimShell_EnableInteractive = 0
        call vimshell#internal#iexe#execute('iexe', insert(a:args, 'sudo'), a:fd, a:other_info)
        let g:VimShell_EnableInteractive = l:interactive_save
    endif
endfunction
