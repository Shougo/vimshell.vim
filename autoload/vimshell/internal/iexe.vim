"=============================================================================
" FILE: iexe.vim
" AUTHOR: Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 22 May 2009
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
"   1.2:
"     - Implemented background execution.
"   1.1:
"     - Use vimproc.
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

function! vimshell#internal#iexe#execute(program, args, fd, other_info)"{{{
    " Interactive execute command.
    if empty(globpath(&runtimepath, 'autoload/proc.vim'))
        " Error.
        call vimshell#error_line('Must have vimproc plugin.')
        return 0
    endif

    if empty(a:args)
        return 0
    endif

    if a:other_info.is_background
        return s:init_bg(a:args, a:other_info.is_interactive)
    elseif has('win32') || has('win64')
        call s:execute_windows(a:args)
    else
        call s:execute_linux(a:args)
    endif

    return 0
endfunction"}}}

function! vimshell#internal#iexe#vimshell_iexe(args)"{{{
    " Interactive execute command.
    if empty(globpath(&runtimepath, 'autoload/proc.vim'))
        " Error.
        echohl WarningMsg | echo "Must have vimproc plugin." | echohl None
        return
    endif

    call s:init_bg(a:args, 0)
endfunction"}}}

function! s:init_bg(args, is_interactive)"{{{
    if a:args[0] !~ '^[./]'
        if has('win32') || has('win64')
            let l:path = substitute($PATH, ';', ',', 'g')
        else
            let l:path = substitute($PATH, ':', ',', 'g')
        endif

        let l:args = insert(a:args[1:], globpath(l:path, a:args[0]))
    else
        let l:args = a:args
    endif

    let l:proc = proc#import()

    try
        if has('win32') || has('win64')
            let l:sub = l:proc.popen2(a:args)
        else
            let l:sub = l:proc.ptyopen(l:args)
        endif
    catch
        if a:is_interactive
            call vimshell#error_line('File not found.')
        else
            echohl WarningMsg | echo "File not found." | echohl None
        endif
        return
    endtry

    " Init buffer.
    if a:is_interactive
        call vimshell#print_prompt()
    endif
    split
    edit `=join(a:args).'@'.(bufnr('$')+1)`
    setlocal buftype=nofile
    setlocal noswapfile

    " Set variables.
    let b:proc = l:proc
    let b:sub = l:sub

    if has('win32') || has('win64')
        nnoremap <buffer><silent><CR>       :<C-u>call <SID>execute_bg_windows()<CR>
        inoremap <buffer><silent><CR>       <ESC>:<C-u>call <SID>execute_bg_windows()<CR>
    else
        nnoremap <buffer><silent><CR>       :<C-u>call <SID>execute_bg_linux()<CR>
        inoremap <buffer><silent><CR>       <ESC>:<C-u>call <SID>execute_bg_linux()<CR>
    endif
    autocmd BufDelete <buffer>   *    call s:bg_exit()
    autocmd CursorHold <buffer>  *     call s:execute_bg_print()
    nnoremap <buffer><silent><C-c>       :<C-u>call <SID>bg_exit()<CR>
    inoremap <buffer><silent><C-c>       <ESC>:<C-u>call <SID>bg_exit()<CR>

    call s:execute_bg_print()

    if exists('b:sub')
        call append(line('.'), '> ')
        normal! G
        startinsert!
    endif

    return 1
endfunction"}}}

function! s:execute_windows(args)"{{{
    if a:args[0] !~ '^[./]'
        let l:path = substitute($PATH, ';', ',', 'g')
        let l:args = insert(a:args[1:], globpath(l:path, a:args[0]))
    else
        let l:args = a:args
    endif

    let l:proc = proc#import()
    try
        let l:sub = l:proc.popen2(a:args)
    catch
        call vimshell#error_line('File not found.')
        return
    endtry

    while !l:sub.stdout.eof
        for line in split(l:sub.stdout.read(-1, 0), '\r\n\|\r\|\n')
            call vimshell#print_line(line)
        endfor
        redraw

        if l:sub.stdin.fd > 0
            let l:in = input('Input: ')
            try
                if l:in =~ ""
                    call l:sub.stdin.write(substitute(l:in, "", '', 'g'))
                    call l:sub.stdin.close()
                    call vimshell#print_line('>' . substitute(l:in, "", '', 'g'))
                else
                    call l:sub.stdin.write(l:in . "\<CR>")
                    call vimshell#print_line('>' . l:in)
                endif
            catch
                call l:sub.stdin.close()
            endtry
        endif
    endwhile

    let [l:cond, l:status] = l:proc.api.vp_waitpid(l:sub.pid)
endfunction"}}}

function! s:execute_linux(args)"{{{
    if a:args[0] !~ '^[./]'
        let l:path = substitute($PATH, ':', ',', 'g')
        let l:args = insert(a:args[1:], globpath(l:path, a:args[0]))
    else
        let l:args = a:args
    endif

    let l:proc = proc#import()
    try
        let l:sub = l:proc.ptyopen(l:args)
    catch
        call vimshell#error_line('File not found.')
        return
    endtry

    while !l:sub.eof
        for line in split(l:sub.read(-1, 3000), '\r\n\|\r\|\n')
            call vimshell#print_line(line)
        endfor
        for line in split(l:sub.read(-1, 3000), '\r\n\|\r\|\n')
            call vimshell#print_line(line)
        endfor
        redraw

        let l:in = input('Input: ')
        try
            if l:in =~ ""
                call l:sub.write(substitute(l:in, "", '', 'g'))

                for line in split(l:sub.read(-1, 0), '\r\n\|\r\|\n')
                    call vimshell#print_line(line)
                endfor
                redraw

                call l:sub.close()
                break
            else
                call l:sub.write(l:in . "\<CR>")
            endif
        catch
            call l:sub.close()
        endtry
    endwhile

    let [l:cond, l:status] = l:proc.api.vp_waitpid(l:sub.pid)
endfunction"}}}

function! s:execute_bg_windows()"{{{
    if !exists('b:sub')
        return
    endif

    if !b:sub.stdout.eof
        for line in split(b:sub.stdout.read(-1, 0), '\r\n\|\r\|\n')
            call vimshell#print_line(line)
        endfor
        redraw

        if b:sub.stdin.fd > 0
            let l:in = getline('.')
            if l:in !~ '^> '
                echohl WarningMsg | echo "Invalid input." | echohl None
                return
            endif
            let l:in = l:in[2:]

            try
                if l:in =~ ""
                    call b:sub.stdin.write(substitute(l:in, "", '', 'g'))
                    call b:sub.stdin.close()
                else
                    call b:sub.stdin.write(l:in . "\<CR>")
                endif
            catch
                call b:sub.stdin.close()
            endtry
        endif

        for line in split(b:sub.stdout.read(-1, 0), '\r\n\|\r\|\n')
            call vimshell#print_line(line)
        endfor
        redraw
    endif

    if b:sub.stdout.eof
        call s:bg_exit()
    else
        call append(line('$'), '> ')
        normal! G
        startinsert!
    endif
endfunction"}}}

function! s:execute_bg_linux()"{{{
    if !exists('b:sub')
        return
    endif

    if !b:sub.eof
        let l:in = getline('.')
        if l:in !~ '^> '
            echohl WarningMsg | echo "Invalid input." | echohl None
            call append(line('$'), '> ')
            normal! G
            startinsert!
            return
        endif
        let l:in = l:in[2:]
        try
            if l:in =~ ""
                call b:sub.write(substitute(l:in, "", '', 'g'))

                for line in split(b:sub.read(-1, 0), '\r\n\|\r\|\n')
                    call vimshell#print_line(line)
                endfor
                redraw

                call b:sub.close()
                return
            else
                call b:sub.write(l:in . "\<CR>")
            endif
        catch
            call b:sub.close()
        endtry

        for line in split(b:sub.read(-1, 2000), '\r\n\|\r\|\n')
            call vimshell#print_line(line)
        endfor
        for line in split(b:sub.read(-1, 2000), '\r\n\|\r\|\n')
            call vimshell#print_line(line)
        endfor
        redraw
    endif

    if b:sub.eof
        call s:bg_exit()
    else
        call append(line('$'), '> ')
        normal! G
        startinsert!
    endif
endfunction"}}}

function! s:execute_bg_print()"{{{
    if !exists('b:sub')
        return
    endif

    if has('win32') || has('win64')
        if !b:sub.stdout.eof
            for line in split(b:sub.stdout.read(-1, 0), '\r\n\|\r\|\n')
                call vimshell#print_line(line)
            endfor
            redraw
        endif

        if b:sub.stdout.eof
            call s:bg_exit()
        endif
    else
        if !b:sub.eof
            for line in split(b:sub.read(-1, 2000), '\r\n\|\r\|\n')
                call vimshell#print_line(line)
            endfor
            redraw
        endif

        if b:sub.eof
            call s:bg_exit()
        endif
    endif
endfunction"}}}

function! s:bg_exit()"{{{
    if !exists('b:sub')
        return
    endif

    let [l:cond, l:status] = b:proc.api.vp_waitpid(b:sub.pid)
    call append(line('$'), '*Exit*')
    normal! G

    unlet b:sub
    unlet b:proc
    setlocal nomodifiable
endfunction"}}}
