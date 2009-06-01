"=============================================================================
" FILE: process.vim
" AUTHOR: Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 30 May 2009
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
" Version: 1.3, for Vim 7.0
"-----------------------------------------------------------------------------
" ChangeLog: "{{{
"   1.3:
"     - Implemented inout in Linux.
"     - Improved output.
"   1.2:
"     - Implemented cancel input in Linux.
"   1.1:
"     - Improved output.
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

if has('win32') || has('win64')
    function! vimshell#utils#process#execute_inout(is_interactive)"{{{
        if !exists('b:sub')
            return
        endif

        if !b:sub.stdout.eof
            if b:sub.stdin.fd > 0
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
                        call b:sub.stdin.close()
                    else
                        call b:sub.stdin.write(l:in . "\<CR>")
                    endif

                    if a:is_interactive
                        call vimshell#print_line('>' . l:in)
                        redraw
                    endif
                catch
                    call b:sub.stdin.close()
                endtry
            endif

            let l:read = b:sub.stdout.read(-1, 1000)
            while l:read != ''
                call vimshell#print(l:read)
                redraw

                let l:read = b:sub.stdout.read(-1, 1000)
            endwhile
        endif

        if b:sub.stdout.eof
            call vimshell#utils#process#exit()
        elseif !a:is_interactive
            call append(line('$'), '> ')
            normal! G
            startinsert!
        endif
    endfunction"}}}

    function! vimshell#utils#process#execute_out()"{{{
        if !exists('b:sub')
            return
        endif

        if !b:sub.stdout.eof
            call vimshell#print(b:sub.stdout.read(-1, 0))
            redraw
        endif

        if b:sub.stdout.eof
            call vimshell#utils#process#exit()
        endif
    endfunction"}}}
else
    function! vimshell#utils#process#execute_inout(is_interactive)"{{{
        if !exists('b:sub')
            return
        endif

        if !b:sub.eof
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
                    call b:sub.write(l:in)
                    call vimshell#print(b:sub.read(-1, 1000))

                    call vimshell#utils#process#exit()
                    return
                elseif l:in != ''
                    call b:sub.write(l:in . "\<CR>")
                endif
            catch
                call b:sub.close()
            endtry

            let l:read = b:sub.read(-1, 1000)
            while l:read != ''
                call vimshell#print(l:read)
                redraw

                let l:read = b:sub.read(-1, 1000)
            endwhile
        endif

        if b:sub.eof
            call vimshell#utils#process#exit()
        elseif !a:is_interactive
            call append(line('$'), '> ')
            normal! G
            startinsert!
        endif
    endfunction"}}}

    function! vimshell#utils#process#execute_out()"{{{
        if !exists('b:sub')
            return
        endif

        if !b:sub.eof
            call vimshell#print(b:sub.read(-1, 1000))
            redraw
        endif

        if b:sub.eof
            call vimshell#utils#process#exit()
        endif
    endfunction"}}}

    function! vimshell#utils#process#execute_pipe_out()"{{{
        if !exists('b:sub')
            return
        endif

        if !b:sub.stdout.eof
            call vimshell#print(b:sub.stdout.read(-1, 0))
            redraw
        endif

        if b:sub.stdout.eof
            call vimshell#utils#process#exit()
        endif
    endfunction"}}}
endif

function! vimshell#utils#process#exit()"{{{
    if !exists('b:sub')
        return
    endif

    let [l:cond, l:status] = b:proc.api.vp_waitpid(b:sub.pid)
    if &filetype != 'vimshell'
        call append(line('$'), '*Exit*')
        normal! G
    endif

    unlet b:sub
    unlet b:proc
endfunction"}}}
