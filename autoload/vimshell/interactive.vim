"=============================================================================
" FILE: interactive.vim
" AUTHOR:  Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 26 Jun 2010
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
            \'\%(Enter \\|[Oo]ld \\|[Nn]ew \\|''s \\|login \\|'''  .
            \'Kerberos \|CVS \|UNIX \| SMB \|LDAP \|\[sudo] \|^\)' . 
            \'[Pp]assword\|\%(^\|\n\)[Pp]assword'
let s:character_regex = ''

let s:is_win = has('win32') || has('win64')

augroup VimShellInteractive
    autocmd!
    autocmd CursorHold * call s:check_output()
augroup END


function! vimshell#interactive#get_cur_text()"{{{
    if getline('.') == '...'
        " Skip input.
        return ''
    endif
    
    " Get cursor text without prompt.
    let l:pos = mode() ==# 'i' ? 2 : 1

    let l:cur_text = col('.') < l:pos ? '' : getline('.')[: col('.') - l:pos]
    if l:cur_text != '' && char2nr(l:cur_text[-1:]) >= 0x80
        let l:len = len(getline('.'))

        " Skip multibyte
        let l:pos -= 1
        let l:cur_text = getline('.')[: col('.') - l:pos]
        let l:fchar = char2nr(l:cur_text[-1:])
        while col('.')-l:pos+1 < l:len && l:fchar >= 0x80
            let l:pos -= 1

            let l:cur_text = getline('.')[: col('.') - l:pos]
            let l:fchar = char2nr(l:cur_text[-1:])
        endwhile
    endif

    if exists("b:prompt_history['".line('.')."']")
        let l:cur_text = l:cur_text[len(b:prompt_history[line('.')]) : ]
    elseif exists('b:prompt_history')
        " Maybe line numbering got disrupted, search for a matching prompt.
        let l:prompt_search = 0
        for pnr in reverse(sort(keys(b:prompt_history)))
            let l:prompt_length = len(b:prompt_history[pnr])
            " In theory 0 length or ' ' prompt shouldn't exist, but still...
            if l:prompt_length > 0 && b:prompt_history[pnr] != ' '
                " Does the current line have this prompt?
                if l:cur_text[: l:prompt_length - 1] == b:prompt_history[pnr]
                    let l:cur_text = l:cur_text[l:prompt_length : ]
                    let l:prompt_search = pnr
                endif
            endif
        endfor
        
        " Still nothing? Maybe a multi-line command was pasted in.
        let l:max_prompt = max(keys(b:prompt_history)) " Only count once.
        if l:prompt_search == 0 && l:max_prompt < line('$')
            for i in range(l:max_prompt, line('$'))
                if i == l:max_prompt && has_key(b:prompt_history, i)
                    let l:cur_text = getline(i)
                    let l:cur_text = l:cur_text[len(b:prompt_history[i]) : ]
                else
                    let l:cur_text = l:cur_text . getline(i)
                endif
            endfor
            let l:prompt_search = l:max_prompt
        endif

        " Still nothing? We give up.
        if l:prompt_search == 0
            echohl WarningMsg | echo "Invalid input." | echohl None
        endif
    endif

    return l:cur_text
endfunction"}}}
function! vimshell#interactive#get_cur_line(line)"{{{
    if getline('.') == '...'
        " Skip input.
        return ''
    endif
    
    " Get cursor text without prompt.
    let l:cur_text = getline(a:line)

    if exists("b:prompt_history['".a:line."']")
        let l:cur_text = l:cur_text[len(b:prompt_history[a:line]) : ]
    elseif exists('b:prompt_history')
        " Maybe line numbering got disrupted, search for a matching prompt.
        let l:prompt_search = 0
        for pnr in reverse(sort(keys(b:prompt_history)))
            let l:prompt_length = len(b:prompt_history[pnr])
            " In theory 0 length or ' ' prompt shouldn't exist, but still...
            if l:prompt_length > 0 && b:prompt_history[pnr] != ' '
                " Does the current line have this prompt?
                if l:cur_text[: l:prompt_length - 1] == b:prompt_history[pnr]
                    let l:cur_text = l:cur_text[l:prompt_length : ]
                    let l:prompt_search = pnr
                endif
            endif
        endfor
        
        " Still nothing? Maybe a multi-line command was pasted in.
        let l:max_prompt = max(keys(b:prompt_history)) " Only count once.
        if l:prompt_search == 0 && l:max_prompt < line('$')
            for i in range(l:max_prompt, line('$'))
                if i == l:max_prompt && has_key(b:prompt_history, i)
                    let l:cur_text = getline(i)
                    let l:cur_text = l:cur_text[len(b:prompt_history[i]) : ]
                else
                    let l:cur_text = l:cur_text . getline(i)
                endif
            endfor
            let l:prompt_search = l:max_prompt
        endif

        " Still nothing? We give up.
        if l:prompt_search == 0
            echohl WarningMsg | echo "Invalid input." | echohl None
        endif
    endif

    return l:cur_text
endfunction"}}}
function! vimshell#interactive#get_prompt(line)"{{{
    " Get prompt line.
    
    if getline('.') == '...'
        " Skip input.
        return ''
    endif
    
    if !exists("b:prompt_history['".a:line."']")
        return ''
    endif

    return b:prompt_history[a:line]
endfunction"}}}

function! vimshell#interactive#execute_pty_inout()"{{{
    if !exists('b:vimproc_sub')
        return
    endif

    if b:vimproc_sub[0].eof
        call vimshell#interactive#exit()
        return
    endif
    
    let l:in = vimshell#interactive#get_cur_line(line('.'))

    " record command history
    if !exists('b:interactive_command_history')
        let b:interactive_command_history = []
    endif
    
    if l:in != ''
        call add(b:interactive_command_history, l:in)
    endif

    if &termencoding != '' && &encoding != &termencoding
        " Convert encoding.
        let l:in = iconv(l:in, &encoding, &termencoding)
    endif

    try
        if l:in =~ "\<C-d>$"
            " EOF.
            call b:vimproc_sub[0].write(l:in[:-2] . s:is_win ? "\<C-z>" : "\<C-z>")
            let b:skip_echoback = l:in[:-2]
            call vimshell#interactive#execute_pty_out()

            call vimshell#interactive#exit()
            return
        elseif getline('.') != '...'
            if l:in =~ '^-> '
                " Delete ...
                let l:in = l:in[3:]
            endif

            call b:vimproc_sub[0].write(l:in . "\<NL>")
            let b:skip_echoback = l:in
        endif
    catch
        call vimshell#interactive#exit()
        return
    endtry

    if getline('$') != '...'
        call append('$', '...')
        $
    endif

    call vimshell#interactive#execute_pty_out()
    
    if getline('$') =~ '^\s*$'
        call setline('$', '...')
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
    let l:output = ''
    try
        for sub in b:vimproc_sub
            if !sub.eof
                let l:read = sub.read(-1, 40)
                while l:read != ''
                    let l:outputed = 1
                    
                    call s:print_buffer(b:vimproc_fd, l:read)
                    redraw

                    let l:read = sub.read(-1, 40)
                endwhile
            endif

            let l:i += 1
        endfor
    catch
        call vimshell#interactive#exit()
        return
    endtry

    " record prompt used on this line
    if !exists('b:prompt_history')
        let b:prompt_history = {}
    endif

    if exists('b:skip_echoback') && line('.') < line('$') && b:skip_echoback ==# getline(line('.'))
        delete
        redraw
    endif

    if b:vimproc_sub[-1].eof
        call vimshell#interactive#exit()
    endif
    
    if l:outputed
        let b:prompt_history[line('$')] = getline('$')
        $
        startinsert!
    endif
endfunction"}}}

function! vimshell#interactive#execute_pipe_out()"{{{
    if !exists('b:vimproc_sub')
        return
    endif

    let l:i = 0
    let l:submax = len(b:vimproc_sub) - 1
    try
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
    catch
        call vimshell#interactive#exit()
        return
    endtry

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
        $
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
        catch
        endtry
    endfor

    if &filetype != 'vimshell'
        call append(line('$'), '*Killed*')
        $
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
        $
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

    call vimshell#interactive#execute_pty_out()
endfunction"}}}

function! vimshell#interactive#highlight_escape_sequence()"{{{
    let l:pos = getpos('.')
    
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

    call setpos('.', l:pos)
endfunction"}}}

function! s:print_buffer(fd, string)"{{{
    if a:string == ''
        return
    endif

    " Convert encoding.
    let l:string = (&termencoding != '' && &encoding != &termencoding) ?
                \ iconv(a:string, &termencoding, &encoding) : a:string

    if a:fd.stdout != ''
        if a:fd.stdout == '/dev/null'
            " Nothing.
        elseif a:fd.stdout == '/dev/clip'
            " Write to clipboard.
            let @+ .= l:string
        else
            " Write file.
            let l:file = extend(readfile(a:fd.stdout), split(l:string, '\r\n\|\n'))
            call writefile(l:file, a:fd.stdout)
        endif

        return
    endif

    if getline('$') == '...'
        call setline('$', '')
    endif
    
    " Strip <CR>.
    let l:string = substitute(l:string, '\r\n', '\n', 'g')
    if l:string =~ '\r'
        for l:line in split(getline('$') . l:string, '\n', 1)
            call append('$', '')
            for l:l in split(l:line, '\r', 1)
                call setline('$', l:l)
                redraw
            endfor
        endfor
    else
        let l:lines = split(getline('$') . l:string, '\n', 1)

        call setline('$', l:lines[0])
        call append('$', l:lines[1:])
    endif

    if getline('$') =~ s:password_regex
        redraw
        
        " Password input.
        set imsearch=0
        let l:in = inputsecret('Input Secret : ')

        if &termencoding != '' && &encoding != &termencoding
            " Convert encoding.
            let l:in = iconv(l:in, &encoding, &termencoding)
        endif
        
        call b:vimproc_sub[0].write(l:in . "\<NL>")
    endif
    
    call vimshell#interactive#highlight_escape_sequence()
endfunction"}}}

function! s:error_buffer(fd, string)"{{{
    if a:string == ''
        return
    endif

    " Convert encoding.
    let l:string = (&termencoding != '' && &encoding != &termencoding) ?
                \ iconv(a:string, &termencoding, &encoding) : a:string

    if a:fd.stderr != ''
        if a:fd.stderr == '/dev/null'
            " Nothing.
        elseif a:fd.stderr == '/dev/clip'
            " Write to clipboard.
            let @+ .= l:string
        else
            " Write file.
            let l:file = extend(readfile(a:fd.stderr), split(l:string, '\r\n\|\n'))
            call writefile(l:file, a:fd.stderr)
        endif
        
        return
    endif

    " Print buffer.
    if getline('$') == '...'
        call setline('$', '')
    endif

    " Strip <CR>.
    let l:string = substitute(l:string, '\r\n', '\n', 'g')
    if l:string =~ '\r'
        for l:line in split(getline('$') . l:string, '\n', 1)
            call append('$', '')
            for l:l in split(l:line, '\r', 1)
                call setline('$', '!!! ' . l:l . ' !!!')
                redraw
            endfor
        endfor
    else
        let l:lines = map(split(getline('$') . l:string, '\n', 1), '"!!! " . v:val . " !!!"')

        call setline('$', l:lines[0])
        call append('$', l:lines[1:])
    endif

    call vimshell#interactive#highlight_escape_sequence()

    " Set cursor.
    $
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

" Autocmd functions.
function! s:check_output()"{{{
    let l:bufnr = 1
    while l:bufnr <= bufnr('$')
        if l:bufnr != bufnr('%') && buflisted(l:bufnr) && type(getbufvar(l:bufnr, 'vimproc_sub')) != type('')
            " Check output.
            let l:filetype = getbufvar(l:bufnr, '&filetype')
            if l:filetype == 'background' || l:filetype =~ '^int_'
                let l:pos = getpos('.')
                
                execute 'buffer' l:bufnr
                
                if l:filetype  == 'background'
                    " Background execute.
                    call vimshell#interactive#execute_pipe_out()
                else
                    " Interactive execute.
                    call vimshell#interactive#execute_pty_out()
                endif
                
                buffer #
            endif
        endif

        let l:bufnr += 1
    endwhile
endfunction"}}}

" vim: foldmethod=marker
