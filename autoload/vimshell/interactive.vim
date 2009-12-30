"=============================================================================
" FILE: interactive.vim
" AUTHOR:  Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 25 Dec 2009
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
"=============================================================================

" Utility functions.

function! s:SID_PREFIX()
    return matchstr(expand('<sfile>'), '<SNR>\d\+_\zeSID_PREFIX$')
endfunction

let s:password_regex = 
            \"\\%(Enter \\|[Oo]ld \\|[Nn]ew \\|'s \\|login \\|'"  .
            \'Kerberos \|CVS \|UNIX \| SMB \|LDAP \|\[sudo] \|^\)' . 
            \'[Pp]assword'
let s:character_regex = 
            \"\\%(Enter \\|[Oo]ld \\|[Nn]ew \\|'s \\|login \\|'"  .
            \'Kerberos \|CVS \|UNIX \| SMB \|LDAP \|\[sudo] \|^\)' . 
            \'[Pp]assword'

let s:is_win = (has('win32') || has('win64'))

function! vimshell#interactive#execute_pty_inout(is_interactive)"{{{
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
        let l:in = getline('.')

        if l:in == ''
            " Do nothing.

        elseif l:in == '...'
            " Working

        elseif !exists('b:prompt_history')
            let l:in = ''

        elseif exists("b:prompt_history['".line('.')."']")
            let l:in = l:in[len(b:prompt_history[line('.')]) : ]

        else
            " Maybe line numbering got disrupted, search for a matching prompt.
            let l:prompt_search = 0
            for pnr in reverse(sort(keys(b:prompt_history)))
                let l:prompt_length = len(b:prompt_history[pnr])
                " In theory 0 length or ' ' prompt shouldn't exist, but still...
                if l:prompt_length > 0 && b:prompt_history[pnr] != ' '
                    " Does the current line have this prompt?
                    if l:in[: l:prompt_length - 1] == b:prompt_history[pnr]
                        let l:in = l:in[l:prompt_length : ]
                        let l:prompt_search = pnr
                    endif
                endif
            endfor
            " Still nothing? Maybe a multi-line command was pasted in.
            let l:max_prompt = max(keys(b:prompt_history)) " Only count once.
            if l:prompt_search == 0 && l:max_prompt < line('$')
                for i in range(l:max_prompt, line('$'))
                    if i == l:max_prompt && has_key(b:prompt_history, i)
                        let l:in = getline(i)
                        let l:in = l:in[len(b:prompt_history[i]) : ]
                    else
                        let l:in = l:in . getline(i)
                    endif
                endfor
                let l:prompt_search = l:max_prompt
            endif

            " Still nothing? We give up.
            if l:prompt_search == 0
                echohl WarningMsg | echo "Invalid input." | echohl None
                "normal! G$
                "startinsert!
                "return
            endif
        endif
        " Delete input string for echoback.
        call setline(line('.'), getline('.')[: -(len(l:in)+1)])

        " record command history
        if !exists('b:interactive_command_history')
            let b:interactive_command_history = []
        endif
        if l:in != '' && l:in != '...'
            call add(b:interactive_command_history, l:in)
        endif
        let b:interactive_command_position = 0

        try
            if l:in =~ "$"
                " EOF.
                call b:vimproc_sub[0].write(l:in[:-2] . s:is_win ? "" : "")
                call vimshell#interactive#execute_pty_out()

                call vimshell#interactive#exit()
                return
            elseif l:in =~ '\t$'
                " Completion.
                call b:vimproc_sub[0].write(l:in)
            elseif l:in != '...'
                if l:in =~ '^\.\.\.'
                    " Delete ...
                    let l:in = l:in[3:]
                endif

                call b:vimproc_sub[0].write(l:in . "\<NL>")
            endif
        catch
            call b:vimproc_sub[0].close()
        endtry
    endif

    call append(line('$'), '...')
    normal! G$

    call vimshell#interactive#execute_pty_out()
    if getline(line('$')) =~ '^\s*$'
        call setline(line('$'), '...')
    endif

    if exists('b:vimproc_sub') && b:vimproc_sub[-1].eof
        call vimshell#interactive#exit()
    else
        startinsert!
    endif
endfunction"}}}

function! vimshell#interactive#execute_pty_out()"{{{
    if !exists('b:vimproc_sub')
        return
    endif

    let l:i = 0
    let l:submax = len(b:vimproc_sub) - 1
    let l:outputed = 0
    for sub in b:vimproc_sub
        if !sub.eof
            let l:read = sub.read(-1, 40)
            while l:read != ''
                if l:i < l:submax
                    " Write pipe.
                    call b:vimproc_sub[l:i + 1].write(l:read)
                else
                    call s:print_buffer(b:vimproc_fd, l:read)
                    redraw
                endif

                let l:read = sub.read(-1, 40)
                let l:outputed = 1
            endwhile
        endif

        let l:i += 1
    endfor

    " record prompt used on this line
    if !exists('b:prompt_history')
        let b:prompt_history = {}
    endif
    if l:outputed
        let b:prompt_history[line('.')] = getline('.')
    endif

    if b:vimproc_sub[-1].eof
        call vimshell#interactive#exit()
    endif
endfunction"}}}

function! vimshell#interactive#execute_pipe_out()"{{{
    if !exists('b:vimproc_sub')
        return
    endif

    let l:i = 0
    let l:submax = len(b:vimproc_sub) - 1
    for sub in b:vimproc_sub
        if !sub.stdout.eof
            let l:read = sub.stdout.read(-1, 40)
            while l:read != ''
                if l:i < l:submax
                    " Write pipe.
                    call b:vimproc_sub[l:i + 1].stdin.write(l:read)
                else
                    call s:print_buffer(b:vimproc_fd, l:read)
                    redraw
                endif

                let l:read = sub.stdout.read(-1, 40)
            endwhile
        elseif l:i < l:submax && b:vimproc_sub[l:i + 1].stdin.fd > 0
            " Close pipe.
            call b:vimproc_sub[l:i + 1].stdin.close()
        endif

        if !g:VimShell_UsePopen2 && !sub.stderr.eof
            let l:read = sub.stderr.read(-1, 40)
            while l:read != ''
                call s:error_buffer(b:vimproc_fd, l:read)
                redraw

                let l:read = sub.stderr.read(-1, 40)
            endwhile
        endif

        let l:i += 1
    endfor

    if b:vimproc_sub[-1].stdout.eof && (g:VimShell_UsePopen2 || b:vimproc_sub[-1].stderr.eof)
        call vimshell#interactive#exit()
    endif
endfunction"}}}

function! vimshell#interactive#exit()"{{{
    if !exists('b:vimproc_sub')
        return
    endif

    " Get status.
    for sub in b:vimproc_sub
        let [l:cond, l:status] = sub.waitpid()
        if l:cond != 'exit'
            try
                " Kill process.
                " 15 == SIGTERM
                call sub.kill(15)
            catch
                " Ignore error.
                unlet b:vimproc_sub
                unlet b:vimproc_fd
                return
            endtry
        endif
    endfor

    let b:vimproc_status = eval(l:status)
    if &filetype != 'vimshell'
        call append(line('$'), '*Exit*')
        normal! G$
    endif

    unlet b:vimproc_sub
    unlet b:vimproc_fd
endfunction"}}}
function! vimshell#interactive#force_exit()"{{{
    if !exists('b:vimproc_sub')
        return
    endif

    " Kill processes.
    for sub in b:vimproc_sub
        try
            " 15 == SIGTERM
            call sub.vp_kill(15)
        catch /No such process/
        endtry
    endfor

    if &filetype != 'vimshell'
        call append(line('$'), '*Killed*')
        normal! G$
    endif

    unlet b:vimproc_sub
    unlet b:vimproc_fd
endfunction"}}}
function! vimshell#interactive#hang_up()"{{{
    if !exists('b:vimproc_sub')
        return
    endif

    " Kill processes.
    for sub in b:vimproc_sub
        try
            " 15 == SIGTERM
            call sub.kill(15)
            echomsg 'Killed'
        catch /No such process/
        endtry
    endfor

    if &filetype != 'vimshell'
        call append(line('$'), '*Killed*')
        normal! G$
    endif

    unlet b:vimproc_sub
    unlet b:vimproc_fd
endfunction"}}}

function! vimshell#interactive#interrupt()"{{{
    if !exists('b:vimproc_sub')
        return
    endif

    " Kill processes.
    for sub in b:vimproc_sub
        try
            " 1 == SIGINT
            call sub.kill(1)
        catch /No such process/
        endtry
    endfor

    if has('win32') || has('win64')
        call vimshell#interactive#execute_pipe_out()
    else
        call vimshell#interactive#execute_pty_out()
    endif
endfunction"}}}

function! vimshell#interactive#highlight_escape_sequence()"{{{
    let l:register_save = @"
    let l:color_table = [ 0x00, 0x5F, 0x87, 0xAF, 0xD7, 0xFF ]
    let l:grey_table = [
                \0x08, 0x12, 0x1C, 0x26, 0x30, 0x3A, 0x44, 0x4E, 
                \0x58, 0x62, 0x6C, 0x76, 0x80, 0x8A, 0x94, 0x9E, 
                \0xA8, 0xB2, 0xBC, 0xC6, 0xD0, 0xDA, 0xE4, 0xEE
                \]

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
                let highlight .= printf(' ctermfg=%d guifg=%s', color_code - 30, g:VimShell_EscapeColors[color_code - 30])
            elseif color_code == 38
                " Foreground 256 colors.
                let l:color = split(matchstr(@", '[0-9;]\+'), ';')[2]
                if l:color >= 232
                    " Grey scale.
                    let l:gcolor = l:grey_table[(l:color - 232)]
                    let highlight .= printf(' ctermfg=%d guifg=#%02x%02x%02x', l:color, l:gcolor, l:gcolor, l:gcolor)
                elseif l:color >= 16
                    " RGB.
                    let l:gcolor = l:color - 16
                    let l:red = l:color_table[l:gcolor / 36]
                    let l:green = l:color_table[(l:gcolor % 36) / 6]
                    let l:blue = l:color_table[l:gcolor % 6]

                    let highlight .= printf(' ctermfg=%d guifg=#%02x%02x%02x', l:color, l:red, l:green, l:blue)
                else
                    let highlight .= printf(' ctermfg=%d guifg=%s', l:color, g:VimShell_EscapeColors[l:color])
                endif
                break
            elseif color_code == 39
                " TODO
            elseif 40 <= color_code && color_code <= 47 
                " Background color.
                let highlight .= printf(' ctermbg=%d guibg=%s', color_code - 40, g:VimShell_EscapeColors[color_code - 40])
            elseif color_code == 48
                " Background 256 colors.
                let l:color = split(matchstr(@", '[0-9;]\+'), ';')[2]
                if l:color >= 232
                    " Grey scale.
                    let l:gcolor = l:grey_table[(l:color - 232)]
                    let highlight .= printf(' ctermbg=%d guibg=#%02x%02x%02x', l:color, l:gcolor, l:gcolor, l:gcolor)
                elseif l:color >= 16
                    " RGB.
                    let l:gcolor = l:color - 16
                    let l:red = l:color_table[l:gcolor / 36]
                    let l:green = l:color_table[(l:gcolor % 36) / 6]
                    let l:blue = l:color_table[l:gcolor % 6]

                    let highlight .= printf(' ctermbg=%d guibg=#%02x%02x%02x', l:color, l:red, l:green, l:blue)
                else
                    let highlight .= printf(' ctermbg=%d guibg=%s', l:color, g:VimShell_EscapeColors[l:color])
                endif
                break
            elseif color_code == 49
                " TODO
            endif"}}}
        endfor
        if highlight != ''
            execute 'highlight link' syntax_name 'Normal'
            execute 'highlight' syntax_name highlight
        endif
    endwhile
    let @" = l:register_save
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
        if a:fd.stdout == '/dev/null'
            " Nothing.
        elseif a:fd.stdout == '/dev/clip'
            " Write to clipboard.
            let @+ .= a:string
        else
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
    if getline(line('$')) == '...'
        $delete
    endif
    let l:last_line = getline(line('$'))
    
    $delete
    let l:lines = split(l:last_line . substitute(l:string, '\r', '', 'g'), '\n', 1)
    
    call append(line('$'), l:lines)

    call vimshell#interactive#highlight_escape_sequence()

    " Set cursor.
    normal! G$
endfunction"}}}

function! s:error_buffer(fd, string)"{{{
    if a:string == ''
        return
    endif

    if a:fd.stderr != ''
        if a:fd.stderr == '/dev/null'
            " Nothing.
        elseif a:fd.stderr == '/dev/clip'
            " Write to clipboard.
            let @+ .= a:string
        else
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

    " Print buffer.
    " Strip <CR>.
    let l:last_line = getline(line('$'))
    let l:string = (l:last_line == '...' ? '' : l:last_line) . substitute(l:string, '\r', '', 'g')
    let l:lines = map(split(l:string, '\n', 1), '"!!! " . v:val . " !!!"')
    
    call setline(line('$'), l:lines[0])
    for l:line in l:lines[1:]
        call append(line('$'), l:line)
    endfor

    " Set cursor.
    normal! G$
endfunction"}}}

" Command functions.

" Interactive execute command.
function! vimshell#interactive#read(args)"{{{
    " Exit previous command.
    call s:on_exit()

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
            call add(l:sub, vimshell#popen3(command))
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
    let b:vimproc_sub = l:sub
    let b:vimproc_fd = { 'stdin' : '', 'stdout' : '', 'stderr' : '' }

    augroup interactive
        autocmd CursorHold <buffer>     call vimshell#interactive#execute_pipe_out()
        autocmd BufDelete <buffer>      call s:on_exit()
    augroup END

    nnoremap <buffer><silent><C-c>       :<C-u>call <sid>on_exit()<CR>
    inoremap <buffer><silent><C-c>       <ESC>:<C-u>call <sid>on_exit()<CR>
    nnoremap <buffer><silent><CR>       :<C-u>call vimshell#interactive#execute_pipe_out()<CR>

    call vimshell#interactive#execute_pipe_out()
endfunction"}}}

function! s:on_exit()"{{{
    augroup interactive
        autocmd! * <buffer>
    augroup END

    call vimshell#interactive#exit()
endfunction"}}}

" Arguments completion by neocomplcache.
function! s:complete_words(arglead, cmdline, cursorpos)"{{{
    " Caching.
    call neocomplcache#keyword_complete#word_caching_current_line()
    
    let l:pattern = '\v%(' .  neocomplcache#keyword_complete#current_keyword_pattern() . ')$'
    let l:cur_keyword_str = matchstr(a:cmdline[: a:cursorpos], l:pattern)
    let l:complete_words = neocomplcache#get_complete_words(l:cur_keyword_str)
    let l:match = match(a:cmdline[: a:cursorpos], l:pattern)
    if l:cur_keyword_str != ''
        if l:match > 0
            let l:cmdline = a:cmdline[: l:match-1]
        else
            let l:cmdline = ''
        endif
    else
        let l:cmdline = a:cmdline[: a:cursorpos]
    endif

    let l:list = []
    for l:word in l:complete_words
        call add(l:list, l:cmdline.l:word.word)
    endfor
    
    return l:list
endfunction"}}}

" vim: foldmethod=marker
