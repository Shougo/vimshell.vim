"=============================================================================
" FILE: exe.vim
" AUTHOR: Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 06 Sep 2009
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
" Version: 1.7, for Vim 7.0
"-----------------------------------------------------------------------------
" ChangeLog: "{{{
"   1.7:
"     - Improved kill processes.
"
"   1.6:
"     - Improved error message.
"     - Improved execute message.
"     - Use sexe.
"
"   1.5:
"     - Fixed stdin bug when g:VimShell_EnableInteractive is 0.
"
"   1.4:
"     - Kill zombee process.
"
"   1.3:
"     - Supported pipe.
"     - Improved in console.
"
"   1.2: Improved error catch.
"     - Get status. 
"
"   1.1: Use interactive.
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

function! vimshell#internal#exe#execute(program, args, fd, other_info)"{{{
    " Execute command.
    if g:VimShell_EnableInteractive
        if s:init_process(a:fd, a:args)
            return 0
        endif

        while exists('b:vimproc_sub')
            echo 'Running command.'
            call interactive#execute_pipe_out()
            redraw
            echo ''
        endwhile
        let b:vimshell_system_variables['status'] = b:vimproc_status
    else
        let l:fd = a:fd
        " Null input.
        if l:fd.stdin == ''
            let l:fd.stdin = '/dev/null'
        endif
        return vimshell#internal#sexe#execute('sexe', a:args, l:fd, a:other_info)
    endif

    return 0
endfunction"}}}

function! s:init_process(fd, args)
    if exists('b:vimproc_sub')
        " Delete zombee process.
        call interactive#force_exit()
    endif

    let l:proc = proc#import()
    let l:sub = []

    " Search pipe.
    let l:commands = [[]]
    for arg in a:args
        if arg == '|'
            call add(l:commands, [])
        else
            call add(l:commands[-1], arg)
        endif
    endfor

    for command in l:commands
        try
            if g:VimShell_UsePopen2
                call add(l:sub, l:proc.popen2(command))
            else
                call add(l:sub, l:proc.popen3(command))
            endif
        catch 'list index out of range'
            if empty(command)
                let l:error = 'Wrong pipe used.'
            else
                let l:error = printf('File: "%s" is not found.', command[0])
            endif

            call vimshell#error_line(a:fd, l:error)

            return 1
        endtry
    endfor

    " Set variables.
    let b:vimproc = l:proc
    let b:vimproc_sub = l:sub
    let b:vimproc_fd = a:fd

    " Input from stdin.
    if b:vimproc_fd.stdin != ''
        call b:vimproc_sub[0].stdin.write(vimshell#read(a:fd))
    endif
    call b:vimproc_sub[0].stdin.close()

    return 0
endfunction
