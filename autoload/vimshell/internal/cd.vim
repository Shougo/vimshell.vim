"=============================================================================
" FILE: cd.vim
" AUTHOR: Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 06 Apr 2009
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
"   1.5:
"     - Implemented exchange ~ into $HOME.
"   1.4:
"     - Fixed error.
"   1.3:
"     - Supported vimshell Ver.3.2.
"   1.2:
"     - Improved escape sequence.
"   1.1:
"     - Interpret cd of no argument as cd $HOME
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

function! vimshell#internal#cd#execute(program, args, fd, other_info)
    " Change the working directory.

    if empty(a:args)
        " Move to HOME directory.
        let l:arguments = $HOME
    else
        " Filename escape.
        let l:arguments = substitute(join(a:args, ' '), '^\~\ze[/\\]', substitute($HOME, '\\', '/', 'g'), '')
    endif
    lcd `=fnamemodify(l:arguments, ':p')`
endfunction
