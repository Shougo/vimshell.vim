"=============================================================================
" FILE: open.vim
" AUTHOR: Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 13 Jun 2010
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
" Version: 1.2, for Vim 7.0
"-----------------------------------------------------------------------------
" ChangeLog: "{{{
"   1.2: Improved environment detect.
"
"   1.1: Improved behaivior.
"
"   1.0: Initial version.
""}}}
"-----------------------------------------------------------------------------
" TODO: "{{{
"     - Nothing.
""}}}
" Bugs"{{{
"     -
""}}}
"=============================================================================

function! vimshell#internal#open#execute(program, args, fd, other_info)"{{{
    " Open file.

    " Detect desktop environment.
    if vimshell#iswin()
        execute printf('silent ! start %s', join(a:args))
        return 0
    elseif has('mac')
        let l:args = ['open'] + a:args
    elseif exists('$KDE_FULL_SESSION') && $KDE_FULL_SESSION ==# 'true'
        " KDE.
        let l:args = ['kfmclient', 'exec'] + a:args
    elseif exists('$GNOME_DESKTOP_SESSION_ID')
        " GNOME.
        let l:args = ['gnome-open'] + a:args
    elseif executable(vimshell#getfilename('exo-open'))
        " Xfce.
        let l:args = ['exo-open'] + a:args
    else
        throw 'open: Not supported.'
    endif

    return vimshell#execute_internal_command('gexe', l:args, a:fd, a:other_info)
endfunction"}}}

