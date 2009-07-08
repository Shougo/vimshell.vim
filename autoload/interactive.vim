"=============================================================================
" FILE: interactive.vim
" AUTHOR:  Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 08 Jul 2009
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
" Version: 1.27, for Vim 7.0
"-----------------------------------------------------------------------------
" ChangeLog: "{{{
"   1.27:
"     - Fixed prompt in background pty(Thanks Nico!).
"     - Stripped <CR>(Thanks Nico!).
"     - Improved output in background program.
"
"   1.26:
"     - Improved error highlight.
"     - Implemented password input.
"
"   1.25: Fixed escape sequence.
"     - Improved highlight timing.
"     - Implemented error highlight.
"     - Added g:Interactive_EscapeColors option.
"     - Refactoringed.
"
"   1.24: Supported escape sequence.
"
"   1.23: Supported pipe.
"
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
            \"\\%(Enter \\|[Oo]ld \\|[Nn]ew \\|'s \\|login \\|'"  .
            \'Kerberos \|CVS \|UNIX \| SMB \|LDAP \|\[sudo] \|^\)' . 
            \'[Pp]assword'

function! interactive#execute_pipe_inout(is_interactive)"{{{
    if !exists('b:vimproc_sub')
        return
    endif

    if b:vimproc_is_secret
        " Password input.
        set imsearch=0
        let l:in = inputsecret('Input Secret : ')
        call b:vimproc_sub[0].stdin.write(l:in . "\<NL>")

        let b:vimproc_is_secret = 0
    elseif b:vimproc_sub[0].stdin.fd > 0
        if a:is_interactive
            set imsearch=0
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
                call b:vimproc_sub[0].stdin.close()
            else
                call b:vimproc_sub[0].stdin.write(l:in . "\<NL>")
            endif

            if a:is_interactive
                call append(line('$'), '>' . l:in)
                normal! j
                redraw
            endif
        catch
            call b:vimproc_sub[0].stdin.close()
        endtry
    endif

    call interactive#execute_pipe_out()

    if !exists('b:vimproc_sub')
        return
    elseif b:vimproc_sub[-1].stdout.eof
        call interactive#exit()
    elseif !a:is_interactive
        call append(line('$'), '> ')
        normal! G
        startinsert!
    endif
endfunction"}}}

function! interactive#execute_pty_inout(is_interactive)"{{{
    if !exists('b:vimproc_sub')
        return
    endif

    if b:vimproc_is_secret
        " Password input.
        set imsearch=0
        let l:in = inputsecret('Input Secret : ')
        call b:vimproc_sub[0].write(l:in . "\<NL>")
        let b:vimproc_is_secret = 0
    elseif !b:vimproc_sub[0].eof
        if a:is_interactive
            set imsearch=0
            let l:in = input('Input: ')

            if l:in !~ ""
                call setline(line('$'), getline('$') . l:in)
            endif
        else
            let l:in = getline('.')
            if exists("b:prompt_history") && !exists("b:prompt_history['".line('.')."']")
                echohl WarningMsg | echo "Invalid input." | echohl None
                normal! G
                startinsert!

                return
            endif

            if len(l:in) && exists("b:prompt_history")
              let l:in = l:in[ len(b:prompt_history[line('.')]) : ]
              echo 'Running command ' . l:in
              call cursor(line('.'), len(b:prompt_history[line('.')]) + 1)
            else
              let l:in = ''
            endif
        endif

        try
            if l:in =~ ""
                call b:vimproc_sub[0].write(l:in)
                call interactive#execute_pty_out()

                call interactive#exit()
                return
            else
                call b:vimproc_sub[0].write(l:in . "\<NL>")
            endif
        catch
            call b:vimproc_sub[0].close()
        endtry
    endif

    call interactive#execute_pty_out()

    if !exists('b:vimproc_sub')
        return
    elseif b:vimproc_sub[-1].eof
        call interactive#exit()
    elseif !a:is_interactive
        normal! G
        startinsert!
    endif
endfunction"}}}

function! interactive#execute_pty_out()"{{{
    if !exists('b:vimproc_sub')
        return
    endif

    let l:i = 0
    let l:submax = len(b:vimproc_sub) - 1
    for sub in b:vimproc_sub
        if !sub.eof
            let l:read = sub.read(-1, 300)
            while l:read != ''
                if l:i < l:submax
                    " Write pipe.
                    call b:vimproc_sub[l:i + 1].write(l:read)
                else
                    call s:print_buffer(b:vimproc_fd, l:read)
                    redraw
                endif

                let l:read = sub.read(-1, 300)
            endwhile
        endif

        let l:i += 1
    endfor

    " record prompt used on this line
    if !exists('b:prompt_history')
        let b:prompt_history = {}
    endif
    let b:prompt_history[line('.')] = getline('.')

    if b:vimproc_sub[-1].eof
        call interactive#exit()
    endif
endfunction"}}}

function! interactive#execute_pipe_out()"{{{
    if !exists('b:vimproc_sub')
        return
    endif

    let l:i = 0
    let l:submax = len(b:vimproc_sub) - 1
    for sub in b:vimproc_sub
        if !sub.stdout.eof
            let l:read = sub.stdout.read(-1, 300)
            while l:read != ''
                if l:i < l:submax
                    " Write pipe.
                    call b:vimproc_sub[l:i + 1].stdin.write(l:read)
                else
                    call s:print_buffer(b:vimproc_fd, l:read)
                    redraw
                endif

                let l:read = sub.stdout.read(-1, 300)
            endwhile
        elseif l:i < l:submax && b:vimproc_sub[l:i + 1].stdin.fd > 0
            " Close pipe.
            call b:vimproc_sub[l:i + 1].stdin.close()
        endif

        if !g:VimShell_UsePopen2 && !sub.stderr.eof
            let l:read = sub.stderr.read(-1, 300)
            while l:read != ''
                call s:error_buffer(b:vimproc_fd, l:read)
                redraw

                let l:read = sub.stderr.read(-1, 300)
            endwhile
        endif

        let l:i += 1
    endfor

    if b:vimproc_sub[-1].stdout.eof && (g:VimShell_UsePopen2 || b:vimproc_sub[-1].stderr.eof)
        call interactive#exit()
    endif
endfunction"}}}

function! interactive#exit()"{{{
    if !exists('b:vimproc_sub')
        return
    endif

    " Get status.
    for sub in b:vimproc_sub
        let [l:cond, l:status] = b:vimproc.api.vp_waitpid(sub.pid)
        if l:cond != 'exit'
            " Kill process.
            " 9 == SIGKILL
            call b:vimproc.api.vp_kill(sub.pid, 9)
        endif
    endfor

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

function! interactive#highlight_escape_sequence()"{{{
    let register_save = @"
    while search("\<ESC>\\[[0-9;]*m", 'c')
        normal! dfm

        let [lnum, col] = getpos('.')[1:2]
        if len(getline('.')) == col
            let col += 1
        endif
        let syntax_name = 'EscapeSequenceAt_' . bufnr('%') . '_' . lnum . '_' . col
        execute 'syntax region' syntax_name 'start=+\%' . lnum . 'l\%' . col . 'c+ end=+\%$+' 'contains=ALL'

        let highlight = ''
        for color_code in split(matchstr(@", '[0-9;]\+'), ';')
            if color_code == 0"{{{
                let highlight .= ' cterm=NONE ctermfg=NONE ctermbg=NONE gui=NONE guifg=NONE guibg=NONE'
            elseif color_code == 1
                let highlight .= ' cterm=BOLD gui=BOLD'
            elseif color_code == 4
                let highlight .= ' cterm=UNDERLINE gui=UNDERLINE'
            elseif color_code == 7
                let highlight .= ' cterm=REVERSE gui=REVERSE'
            elseif color_code == 8
                let highlight .= ' ctermfg=0 ctermbg=0 guifg=#000000 guibg=#000000'
            elseif 30 <= color_code && color_code <= 37 
                " Foreground color.
                let highlight .= printf(' ctermfg=%d guifg=%s', color_code - 30, g:Interactive_EscapeColors[color_code - 30])
            elseif color_code == 38
                " Foreground 256 colors.
                let l:color = split(matchstr(@", '[0-9;]\+'), ';')[2]
                if l:color >= 232
                    let l:gcolor = (l:color - 232) * 11
                    if l:gcolor != 0
                        let l:gcolor += 2
                    endif
                    let highlight .= printf(' ctermfg=%d guifg=#%02x%02x%02x', l:color, l:gcolor, l:gcolor, l:gcolor)
                elseif l:color >= 16
                    let l:gcolor = l:color - 16
                    let l:red = l:gcolor / 36 * 40
                    let l:green = (l:gcolor - l:gcolor/36 * 36) / 6 * 40
                    let l:blue = l:gcolor % 6 * 40

                    if l:red != 0
                        let l:red += 15
                    endif
                    if l:blue != 0
                        let l:blue += 15
                    endif
                    if l:green != 0
                        let l:green += 15
                    endif
                    let highlight .= printf(' ctermfg=%d guifg=#%02x%02x%02x', l:color, l:red, l:green, l:blue)
                else
                    let highlight .= printf(' ctermfg=%d guifg=%s', l:color, g:Interactive_EscapeColors[l:color])
                endif
                break
            elseif color_code == 39
                " TODO
            elseif 40 <= color_code && color_code <= 47 
                " Background color.
                let highlight .= printf(' ctermbg=%d guibg=%s', color_code - 40, g:Interactive_EscapeColors[color_code - 40])
            elseif color_code == 48
                " Background 256 colors.
                let l:color = split(matchstr(@", '[0-9;]\+'), ';')[2]
                if l:color >= 232
                    let l:gcolor = (l:color - 232) * 11
                    if l:gcolor != 0
                        let l:gcolor += 2
                    endif
                    let highlight .= printf(' ctermbg=%d guibg=#%02x%02x%02x', l:color, l:gcolor, l:gcolor, l:gcolor)
                elseif l:color >= 16
                    let l:gcolor = l:color - 16
                    let l:red = l:gcolor / 36 * 40
                    let l:green = (l:gcolor - l:gcolor/36 * 36) / 6 * 40
                    let l:blue = l:gcolor % 6 * 40

                    if l:red != 0
                        let l:red += 15
                    endif
                    if l:blue != 0
                        let l:blue += 15
                    endif
                    if l:green != 0
                        let l:green += 15
                    endif
                    let highlight .= printf(' ctermbg=%d guibg=#%02x%02x%02x', l:color, l:red, l:green, l:blue)
                else
                    let highlight .= printf(' ctermbg=%d guibg=%s', l:color, g:Interactive_EscapeColors[l:color])
                endif
                break
            elseif color_code == 49
                " TODO
            endif"}}}
        endfor
        if len(highlight)
            execute 'highlight' syntax_name highlight
        endif
    endwhile
    let @" = register_save
endfunction"}}}

function! s:print_buffer(fd, string)"{{{
    if a:string == ''
        return
    endif

    if a:string =~ s:password_regex
        " Set secret flag.
        let b:vimproc_is_secret = 1
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

    " Strip <CR>.
    let l:string = substitute(l:string, '\r', '', 'g')
    let l:lines = split(l:string, '\n', 1)
    for i in range(len(l:lines))
        if line('$') == 1 && empty(getline('$'))
            call setline(line('$'), l:lines[i])
        else
            call append(line('$'), l:lines[i])
        endif
    endfor
    call interactive#highlight_escape_sequence()

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

    if &filetype != 'vimshell'
        syn region   VimShellError   start=+!!!+ end=+!!!+ contains=VimShellErrorHidden oneline
        syn match   VimShellErrorHidden            '!!!' contained
        hi def link VimShellError Error
        hi def link VimShellErrorHidden Ignore
    endif

    " Print buffer.
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
    let l:sub = []

    " Search pipe.
    let l:commands = [[]]
    for arg in a:args
        if arg == '|'
            call add(l:commands, [])
        elseif arg =~ '^|'
            call add(l:commands, [arg[1:]])
        else
            call add(l:commands[-1], arg)
        endif
    endfor

    for command in l:commands
        try
            call add(l:sub, l:proc.popen3(command))
        catch
            if empty(command)
                let l:error = 'Wrong pipe used.'
            else
                let l:error = printf('File: "%s" is not found.'
            endif

            echohl WarningMsg | echo l:error | echohl None

            return
        endtry
    endfor

    " Set variables.
    let b:vimproc = l:proc
    let b:vimproc_sub = l:sub
    let b:vimproc_fd = { 'stdin' : '', 'stdout' : '', 'stderr' : '' }

    augroup interactive
        autocmd CursorHold <buffer>     call interactive#execute_pipe_out()
        autocmd BufDelete <buffer>      call s:on_exit()
    augroup END

    nnoremap <buffer><silent><C-c>       :<C-u>call <sid>on_exit()<CR>
    inoremap <buffer><silent><C-c>       <ESC>:<C-u>call <sid>on_exit()<CR>
    nnoremap <buffer><silent><CR>       :<C-u>call interactive#execute_pipe_out()<CR>

    call interactive#execute_pipe_out()
endfunction"}}}

function! s:on_exit()"{{{
    augroup interactive
        autocmd! * <buffer>
    augroup END

    call interactive#exit()
endfunction"}}}

" vim: foldmethod=marker
