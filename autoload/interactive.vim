"=============================================================================
" FILE: interactive.vim
" AUTHOR:  Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 21 Jun 2009
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
" Version: 1.22, for Vim 7.0
"-----------------------------------------------------------------------------
" ChangeLog: "{{{
"   1.22: Refactoringed.
"     - Get status.
"     - Kill zombee process.
"
"   1.21: Implemented redirection.
"
"   1.20: Independent from vimshell.
"
"   1.11: Improved autocmd.
"
"   1.10: Use vimshell.
"
"   1.01: Compatible Windows and Linux.
"
"   1.00: Initial version.
" }}}
"-----------------------------------------------------------------------------
" TODO: "{{{
"     - Nothing.
""}}}
" Bugs"{{{
"     - Nothing.
""}}}
"=============================================================================

" Utility functions.

let s:password_regex = 
            \'^\s*Password:' . '\|'     "  su, ssh, ftp
            \. 'password:' . '\|'       "  ???, seen this somewhere
            \. 'Password required'      "  other ftp clients

let s:last_out = ''

if has('win32') || has('win64')
    function! interactive#execute_inout(is_interactive)"{{{
        if !exists('b:vimproc_sub')
            return
        endif

        if !b:vimproc_sub.stdout.eof || !b:vimproc_sub.stderr.eof
            if b:vimproc_sub.stdin.fd > 0
                if a:is_interactive
                    let l:in = input('Input: ')
                else
                    let l:in = getline('.')
                    if l:in !~ '^> '
                        echohl WarningMsg | echo "Invalid input." | echohl None
                        call append(line('$'), '> ')
                        normal! G
                        startinsert!

                        return
                    endif
                    let l:in = l:in[2:]
                endif

                try
                    if l:in =~ ""
                        call b:vimproc_sub.stdin.close()
                    else
                        call b:vimproc_sub.stdin.write(l:in . "\<CR>\<LF>")
                    endif

                    if a:is_interactive
                        call append(line('$'), '>' . l:in)
                        normal! j
                        redraw
                    endif
                catch
                    call b:vimproc_sub.stdin.close()
                endtry
            endif

            call interactive#execute_out()
        endif

        if !exists('b:vimproc_sub')
            return
        elseif b:vimproc_sub.stdout.eof
            call interactive#exit()
        elseif !a:is_interactive
            call append(line('$'), '> ')
            normal! G
            startinsert!
        endif
    endfunction"}}}

    function! interactive#execute_out()"{{{
        if !exists('b:vimproc_sub')
            return
        endif

        if !b:vimproc_sub.stdout.eof
            let l:read = b:vimproc_sub.stdout.read(-1, 200)
            while l:read != ''
                call s:print_buffer(b:vimproc_fd, l:read)
                redraw

                let l:read = b:vimproc_sub.stdout.read(-1, 200)
            endwhile
        endif
        if !b:vimproc_sub.stderr.eof
            let l:read = b:vimproc_sub.stderr.read(-1, 200)
            while l:read != ''
                call s:error_buffer(b:vimproc_fd, l:read)
                redraw

                let l:read = b:vimproc_sub.stderr.read(-1, 200)
            endwhile
        endif

        if b:vimproc_sub.stdout.eof && b:vimproc_sub.stderr.eof
            call interactive#exit()
        endif
    endfunction"}}}
else
    function! interactive#execute_inout(is_interactive)"{{{
        if !exists('b:vimproc_sub')
            return
        endif

        if !b:vimproc_sub.eof
            if a:is_interactive
                let l:in = input('Input: ')
            else
                let l:in = getline('.')
                if l:in !~ '^> '
                    echohl WarningMsg | echo "Invalid input." | echohl None
                    call append(line('$'), '> ')
                    normal! G
                    startinsert!

                    return
                endif

                let l:in = l:in[2:]
            endif

            try
                if l:in =~ ""
                    call b:vimproc_sub.write(l:in)
                    call interactive#execute_out()

                    call interactive#exit()
                    return
                elseif l:in != ''
                    call b:vimproc_sub.write(l:in . "\<LF>")
                endif
            catch
                call b:vimproc_sub.close()
            endtry

            call interactive#execute_out()
        endif

        if !exists('b:vimproc_sub')
            return
        elseif b:vimproc_sub.eof
            call interactive#exit()
        elseif !a:is_interactive
            call append(line('$'), '> ')
            normal! G
            startinsert!
        endif
    endfunction"}}}

    function! interactive#execute_out()"{{{
        if !exists('b:vimproc_sub')
            return
        endif

        let l:read = b:vimproc_sub.read(-1, 200)
        while l:read != ''
            call s:print_buffer(b:vimproc_fd, l:read)
            redraw

            let l:read = b:vimproc_sub.read(-1, 200)
        endwhile

        if b:vimproc_sub.eof
            call interactive#exit()
        endif
    endfunction"}}}

    function! interactive#execute_pipe_out()"{{{
        if !exists('b:vimproc_sub')
            return
        endif

        if !b:vimproc_sub.stdout.eof
            let l:read = b:vimproc_sub.stdout.read(-1, 200)
            while l:read != ''
                call s:print_buffer(b:vimproc_fd, l:read)
                redraw

                let l:read = b:vimproc_sub.stdout.read(-1, 200)
            endwhile
        endif
        if !b:vimproc_sub.stderr.eof
            let l:read = b:vimproc_sub.stderr.read(-1, 200)
            while l:read != ''
                call s:error_buffer(b:vimproc_fd, l:read)
                redraw

                let l:read = b:vimproc_sub.stderr.read(-1, 200)
            endwhile
        endif

        if b:vimproc_sub.stdout.eof && b:vimproc_sub.stderr.eof
            call interactive#exit()
        endif
    endfunction"}}}
endif

function! interactive#exit()"{{{
    if !exists('b:vimproc_sub')
        return
    endif

    " Get status.
    let [l:cond, l:status] = b:vimproc.api.vp_waitpid(b:vimproc_sub.pid)
    if l:cond != 'exit'
        " Kill process.
        " 9 == SIGKILL
        call b:vimproc.api.vp_kill(b:vimproc_sub.pid, 9)
    endif
    let b:vimproc_status = eval(l:status)
    if &filetype != 'vimshell'
        call append(line('$'), '*Exit*')
        normal! G
    endif

    let s:last_out = ''

    unlet b:vimproc
    unlet b:vimproc_sub
    unlet b:vimproc_fd
endfunction"}}}

function! s:print_buffer(fd, string)"{{{
    if a:string == ''
        return
    endif

    if a:fd.stdout != ''
        if a:fd.stdout != '/dev/null'
            " Write file.
            let l:file = extend(readfile(a:fd.stdout), split(a:string, '\r\n\|\n'))
            call writefile(l:file, a:fd.stdout)
        endif

        return
    endif

    " Convert encoding for system().
    if has('win32') || has('win64')
        let l:string = iconv(a:string, 'cp932', &encoding) 
    else
        let l:string = iconv(a:string, 'utf-8', &encoding) 
    endif

    if l:string =~ '\r[[:print:]]'
        " Set line.
        for line in split(l:string, '\r\n\|\n')
            call append(line('$'), '')

            for l in split(line, '\r')
                call setline(line('$'), l)
                redraw
            endfor
        endfor
    else
        for line in split(l:string, '\r\n\|\r\|\n')
            call append(line('$'), line)
        endfor
    endif

    " Set cursor.
    normal! G
endfunction"}}}

function! s:error_buffer(fd, string)"{{{
    if a:string == ''
        return
    endif

    if a:fd.stderr != ''
        if a:fd.stdout != '/dev/null'
            " Write file.
            let l:file = extend(readfile(a:fd.stderr), split(a:string, '\r\n\|\n'))
            call writefile(l:file, a:fd.stderr)
        endif

        return
    endif

    " Convert encoding for system().
    if has('win32') || has('win64')
        let l:string = iconv(a:string, 'cp932', &encoding) 
    else
        let l:string = iconv(a:string, 'utf-8', &encoding) 
    endif

    if l:string =~ '\r[[:print:]]'
        " Set line.
        for line in split(l:string, '\r\n\|\n')
            call append(line('$'), '')

            for l in split(line, '\r')
                call setline(line('$'), '!!! '.l.' !!!')
                redraw
            endfor
        endfor
    else
        for line in split(l:string, '\r\n\|\r\|\n')
            call append(line('$'), '!!! '.line.' !!!')
        endfor
    endif

    " Set cursor.
    normal! G
endfunction"}}}

" Command functions.

" Interactive execute command.
function! interactive#read(args)"{{{

    " Exit previous command.
    call s:on_exit()

    let l:proc = proc#import()

    try
        if has('win32') || has('win64')
            let l:sub = l:proc.popen3(a:args)
        else
            let l:sub = l:proc.ptyopen(a:args)
        endif
    catch
        echohl WarningMsg | echo printf('File: "%s" is not found.', a:args[0]) | echohl None

        return
    endtry

    " Set variables.
    let b:vimproc = l:proc
    let b:vimproc_sub = l:sub
    let b:vimproc_fd = { 'stdin' : '', 'stdout' : '', 'stderr' : '' }

    augroup interactive
        autocmd CursorHold <buffer>     call interactive#execute_out()
        autocmd BufDelete <buffer>      call s:on_exit()
    augroup END

    nnoremap <buffer><silent><C-c>       :<C-u>call <sid>on_exit()<CR>
    inoremap <buffer><silent><C-c>       <ESC>:<C-u>call <sid>on_exit()<CR>
    nnoremap <buffer><silent><CR>       :<C-u>call interactive#execute_out()<CR>

    call interactive#execute_out()
endfunction"}}}

function! s:on_exit()"{{{
    augroup interactive
        autocmd! * <buffer>
    augroup END

    call interactive#exit()
endfunction"}}}

" vim: foldmethod=marker
