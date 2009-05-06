"=============================================================================
" FILE: bg.vim
" AUTHOR: Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 29 Apr 2009
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
" Version: 1.0, for Vim 7.0
"-----------------------------------------------------------------------------
" ChangeLog: "{{{
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

function! vimshell#internal#bg#execute(program, args, fd, other_info)
    " Execute program in background.

    if empty(a:args)
        return 
    elseif a:args[0] == 'shell'
        " Background shell.
        if has('win32') || has('win64')
            if g:VimShell_UseCkw
                " Use ckw.
                silent execute printf('!start ckw -e %s', &shell)
            else
                silent execute printf('!start %s', &shell)
            endif
        elseif &term =~ '^screen'
            silent execute printf('!screen %s', &shell)
        else
            " Can't Background execute.
            shell
        endif
    elseif a:args[0] == 'iexe'
        " Background iexe.
        let l:other_info = a:other_info
        let l:other_info.is_background = 1
        return vimshell#internal#iexe#execute(a:args[0], a:args[1:], a:fd, l:other_info)
    elseif has('win32') || has('win64')
        if g:VimShell_UseCkw
            " Use ckw.
            silent execute printf('!start ckw -e %s %s %s', &shell, &shellcmdflag, join(a:args))
        else
            silent execute printf('!start %s', join(a:args))
        endif
    else
        " For *nix.

        let l:tmpfile = tempname()
        " Background execute.
        execute printf('!%s & > %s', join(a:args), l:tmpfile)

        " Edit redirect file.
        split
        edit `=l:tmpfile`
        setlocal autoread
        wincmd w
    endif"}}}
endfunction
