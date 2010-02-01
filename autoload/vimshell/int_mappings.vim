"=============================================================================
" FILE: int_mappings.vim
" AUTHOR: Shougo Matsushita <Shougo.Matsu@gmail.com>(Modified)
" Last Modified: 28 Jun 2010
" License: MIT license  {{{
"     Permission is hereby granted, free of charge, to any person obtaining
"     a copy of this software and associated documentation files (the
"     "Software"), to deal in the Software without restriction, including
"     without limitation the rights to use, copy, modify, merge, publish,
"     distribute, sublicense, and/or sell copies of the Software, and to
"     permit persons to whom the Software is furnished to do so, subject to
"     the following conditionvimshell#int_mappings#
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

" vimshell interactive key-mappings functions.
function! vimshell#int_mappings#previous_command()"{{{
    " If this is the first up arrow use, save what's been typed in so far.
    if b:interactive_command_position == 0
        let b:current_working_command = strpart(getline('.'), len(b:prompt_history[line('.')]))
    endif
    " If there are no more previous commands.
    if len(b:interactive_command_history) == b:interactive_command_position
        echo 'End of history'
        startinsert!
        return
    endif
    let b:interactive_command_position = b:interactive_command_position + 1
    let l:prev_command = b:interactive_command_history[len(b:interactive_command_history) - b:interactive_command_position]
    call setline(line('.'), b:prompt_history[max(keys(b:prompt_history))] . l:prev_command)
    startinsert!
endfunction"}}}
function! vimshell#int_mappings#next_command()"{{{
    " If we're already at the last command.
    if b:interactive_command_position == 0
        echo 'End of history'
        startinsert!
        return
    endif
    let b:interactive_command_position = b:interactive_command_position - 1
    " Back at the beginning, put back what had been typed.
    if b:interactive_command_position == 0
        call setline(line('.'), b:prompt_history[max(keys(b:prompt_history))] . b:current_working_command)
        startinsert!
        return
    endif
    let l:next_command = b:interactive_command_history[len(b:interactive_command_history) - b:interactive_command_position]
    call setline(line('.'), b:prompt_history[max(keys(b:prompt_history))] . l:next_command)
    startinsert!
endfunction"}}}
function! vimshell#int_mappings#delete_backword_char()"{{{
    " Prevent backspace over prompt
    if !exists("b:prompt_history['".line('.')."']") || getline(line('.')) != b:prompt_history[line('.')]
        return "\<BS>"
    else
        return ""
    endif
endfunction"}}}
function! vimshell#int_mappings#execute_history()"{{{
    " Search prompt.
    if !exists('b:prompt_history[line(".")]')
        return
    endif

    let l:command = strpart(getline('.'), len(b:prompt_history[line('.')]))

    if !exists('b:prompt_history[line("$")]')
        " Insert prompt line.
        call append(line('$'), l:command)
    else
        " Set prompt line.
        call setline(line('$'), b:prompt_history[line("$")] . l:command)
    endif

    $

    call vimshell#interactive#execute_pty_inout()
endfunction"}}}
function! vimshell#int_mappings#previous_prompt()"{{{
    let l:prompts = reverse(sort(map(filter(keys(b:prompt_history), 'v:val < line(".")'), 'str2nr(v:val)')))
    if !empty(l:prompts)
        execute ':'.l:prompts[-1]
    endif
endfunction"}}}
function! vimshell#int_mappings#next_prompt()"{{{
    let l:prompts = sort(map(filter(keys(b:prompt_history), 'v:val > line(".")'), 'str2nr(v:val)'))
    if !empty(l:prompts)
        execute ':'.l:prompts[0]
    endif
endfunction"}}}
function! vimshell#int_mappings#move_head()"{{{
    if !exists('b:prompt_history[line(".")]')
        return
    endif
    call search(vimshell#escape_match(b:prompt_history[line('.')]), 'be', line('.'))
    startinsert
endfunction"}}}
function! vimshell#int_mappings#delete_line()"{{{
    if !exists('b:prompt_history[line(".")]')
        return
    endif

    let l:col = col('.')
    let l:mcol = col('$')
    call setline(line('.'), b:prompt_history[line('.')] . getline('.')[l:col :])
    call vimshell#int_mappings#move_head()

    if l:col == l:mcol-1
        startinsert!
    endif
endfunction"}}}
function! vimshell#int_mappings#execute_line()"{{{
    if exists('b:prompt_history[line(".")]')
        " Execute history.
        call vimshell#int_mappings#execute_history()
        return
    endif
    
    " Search cursor file.
    let l:filename = substitute(substitute(expand('<cfile>'), ' ', '\\ ', 'g'), '\\', '/', 'g')
    if l:filename == ''
        return
    endif

    " Execute cursor file.
    if l:filename =~ '^\%(https\?\|ftp\)://'
        " Open uri.
        
        " Detect desktop environment.
        if vimshell#iswin()
            execute printf('silent ! start "" "%s"', l:filename)
        elseif has('mac')
            call system('open ' . l:filename . '&')
        elseif exists('$KDE_FULL_SESSION') && $KDE_FULL_SESSION ==# 'true'
            " KDE.
            call system('kfmclient exec ' . l:filename . '&')
        elseif exists('$GNOME_DESKTOP_SESSION_ID')
            " GNOME.
            call system('gnome-open ' . l:filename . '&')
        elseif executable(vimshell#getfilename('exo-open'))
            " Xfce.
            call system('exo-open ' . l:filename . '&')
        else
            throw 'Not supported.'
        endif
    endif
endfunction"}}}
function! vimshell#int_mappings#paste_prompt()"{{{
    if !exists('b:prompt_history[line(".")]')
        return
    endif

    " Set prompt line.
    let l:cur_text = vimshell#interactive#get_cur_line(line('.'))
    call setline(line('$'), vimshell#interactive#get_prompt(line('$')) . l:cur_text)
    $
endfunction"}}}
function! vimshell#int_mappings#close_popup()"{{{
    if !pumvisible()
        return ''
    endif
    
    if !exists('*neocomplcache#close_popup')
        let l:ret = neocomplcache#close_popup()
    else
        let l:ret = "\<C-y>"
    endif
    let l:ret .= "\<C-l>\<BS>"

    return l:ret
endfunction"}}}

" vim: foldmethod=marker
