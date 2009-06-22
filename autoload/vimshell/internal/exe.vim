"=============================================================================
" FILE: exe.vim
" AUTHOR: Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 17 Jun 2009
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
        call s:init_process(a:fd, a:args, a:other_info.is_interactive)

        if has('win32') || has('win64')
            while exists('b:vimproc_sub')
                call interactive#execute_out()
            endwhile
        else
            while exists('b:vimproc_sub')
                call interactive#execute_pipe_out()
            endwhile
        endif
        let b:vimshell_system_variables['status'] = b:vimproc_status
    else
        let l:cmdline = ''
        for arg in a:args
            let l:cmdline .= substitute(arg, '"', '\\""', 'g') . ' '
        endfor

        " Set redirection.
        if a:fd.stdin != ''
            let l:stdin = '<' . a:fd.stdin
        else
            let l:null = tempname()
            call writefile([], l:null)

            let l:stdin = '<' . l:null
        endif

        if a:fd.stdout != ''
            silent execute printf('!%s %s %s', l:cmdline, l:stdin, '>' . a:fd.stdout)
        else
            silent execute printf('read! %s %s', l:cmdline, l:stdin)
        endif

        if a:fd.stdin == ''
            call delete(l:null)
        endif

        let b:vimshell_system_variables['status'] = v:shell_error
    endif

    return 0
endfunction"}}}

function! s:init_process(fd, args, is_interactive)
    if exists('b:vimproc_sub')
        " Delete zombee process.
        call interactive#exit()
    endif

    let l:proc = proc#import()

    try
        let l:sub = l:proc.popen3(a:args)
    catch 'list index out of range'
        if a:is_interactive
            call vimshell#error_line(a:fd, printf('File: "%s" is not found.', a:args[0]))
        else
            echohl WarningMsg | echo printf('File: "%s" is not found.', a:args[0]) | echohl None
        endif

        return
    endtry

    " Set variables.
    let b:vimproc = l:proc
    let b:vimproc_sub = l:sub
    let b:vimproc_fd = a:fd

    " Input from stdin.
    if b:vimproc_fd.stdin != ''
        call b:vimproc_sub.stdin.write(vimshell#read(a:fd))
    endif
    call b:vimproc_sub.stdin.close()
endfunction
