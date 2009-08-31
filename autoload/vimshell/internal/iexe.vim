"=============================================================================
" FILE: iexe.vim
" AUTHOR: Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 29 Aug 2009
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
" Version: 1.15, for Vim 7.0
"-----------------------------------------------------------------------------
" ChangeLog: "{{{
"   1.15: 
"     - Implemented delete line and move head.
"     - Deleted normal iexe.
"
"   1.14: 
"     - Use plugin Key-mappings.
"     - Improved execute message.
"     - Use sexe.
"     - Setfiletype iexe.
"
"   1.13: 
"     - Improved error message.
"     - Set syntax.
"
"   1.12: 
"     - Applyed backspace patch(Thanks Nico!).
"     - Implemented paste prompt.
"     - Implemented move to prompt.
"
"   1.11: 
"     - Improved completion.
"     - Set filetype.
"     - Improved initialize on pty.
"
"   1.10: 
"     - Improved behavior.
"     - Kill zombee process.
"     - Supported completion on pty.
"     - Improved initialize program.
"     - Implemented command history on pty.
"     - <C-c> as <C-v><C-d>.
"
"   1.9: 
"     - Fixed error when file not found.
"     - Improved in console.
"
"   1.8: 
"     - Supported pipe.
"
"   1.7: Refactoringed.
"     - Get status. 
"
"   1.6: Use interactive.
"
"   1.5: Improved autocmd.
"
"   1.4: Split nicely.
"
"   1.3:
"     - Use g:VimShell_EnableInteractive option.
"     - Use utls/process.vim.
"
"   1.2: Implemented background execution.
"
"   1.1: Use vimproc.
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

function! vimshell#internal#iexe#execute(program, args, fd, other_info)"{{{
    " Interactive execute command.
    if !g:VimShell_EnableInteractive
        if has('gui_running')
            " Error.
            call vimshell#error_line(a:fd, 'Must use vimproc plugin.')
            return 0
        else
            " Use sexe.
            return vimshell#internal#sexe#execute('sexe', a:args, l:fd, a:other_info)
        endif
    endif

    if empty(a:args)
        return 0
    endif

    " Initialize.
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
            if has('win32') || has('win64')
                call add(l:sub, l:proc.popen3(command))
            else
                call add(l:sub, l:proc.ptyopen(command))
            endif
        catch 'list index out of range'
            if empty(command)
                let l:error = 'Wrong pipe used.'
            else
                let l:error = printf('File: "%s" is not found.', command[0])
            endif

            call vimshell#error_line(a:fd, l:error)

            return 0
        endtry
    endfor

    if exists('b:vimproc_sub')
        " Delete zombee process.
        call interactive#force_exit()
    endif

    call s:init_bg(l:proc, l:sub, a:args, a:other_info.is_interactive)

    " Set variables.
    let b:vimproc = l:proc
    let b:vimproc_sub = l:sub
    let b:vimproc_fd = a:fd
    let b:vimproc_is_secret = 0

    " Input from stdin.
    if b:vimproc_fd.stdin != ''
        if has('win32') || has('win64')
            call b:vimproc_sub[0].stdin.write(vimshell#read(a:fd))
            call b:vimproc_sub[0].stdin.close()
        else
            call b:vimproc_sub[0].write(vimshell#read(a:fd))
        endif
    endif

    echo 'Running command.'
    if has('win32') || has('win64')
        call interactive#execute_pipe_out()
    else
        let l:cnt = 0
        while line('$') == 1 && col('.') == 1 && l:cnt < 15
            call interactive#execute_pty_out()
            let l:cnt += 1
        endwhile
    endif
    redraw
    echo ''

    startinsert!

    return 1
endfunction"}}}

function! vimshell#internal#iexe#vimshell_iexe(args)"{{{
    call vimshell#internal#iexe#execute('iexe', a:args, {'stdin' : '', 'stdout' : '', 'stderr' : ''}, {'is_interactive' : 0, 'is_background' : 1})
endfunction"}}}

function! s:init_bg(proc, sub, args, is_interactive)"{{{
    " Save current directiory.
    let l:cwd = getcwd()

    " Init buffer.
    if a:is_interactive
        call vimshell#print_prompt()
    endif
    " Split nicely.
    if winheight(0) > &winheight
        split
    else
        vsplit
    endif

    edit `=substitute(join(a:args), '|', '_', 'g').'@'.(bufnr('$')+1)`
    lcd `=l:cwd`
    setlocal buftype=nofile
    setlocal noswapfile
    setfiletype iexe
    execute 'setfiletype ' . a:args[0]

    " Set syntax.
    syn region   VimShellError   start=+!!!+ end=+!!!+ contains=VimShellErrorHidden oneline
    syn match   VimShellErrorHidden            '!!!' contained
    hi def link VimShellError Error
    hi def link VimShellErrorHidden Ignore

    nnoremap <buffer><silent><C-c>       :<C-u>call <SID>on_exit()<CR>
    augroup vimshell_iexe
        autocmd BufDelete <buffer>   call s:on_exit()
    augroup END

    if has('win32') || has('win64')
        nnoremap <buffer><silent><CR>        :<C-u>call <SID>on_execute()<CR>
        inoremap <buffer><silent><CR>       <ESC>:<C-u>call <SID>on_execute()<CR>
        autocmd vimshell_iexe CursorHold <buffer>  call s:on_hold()
    else
        nnoremap <buffer><silent><CR>           :<C-u>call <SID>execute_history()<CR>
        inoremap <buffer><silent><CR>       <ESC>:<C-u>call <SID>on_execute()<CR>

        " Plugin key-mappings.
        inoremap <buffer><silent><expr> <Plug>(vimshell_iexe_delete_backword_char)  <SID>delete_backword_char()
        imap <buffer><C-h>     <Plug>(vimshell_iexe_delete_backword_char)
        imap <buffer><BS>     <Plug>(vimshell_iexe_delete_backword_char)
        inoremap <buffer><silent> <Plug>(vimshell_iexe_tab_completion)  <ESC>:<C-u>call <SID>pty_completion()<CR>
        imap <buffer><C-t>     <Plug>(vimshell_iexe_tab_completion)
        inoremap <buffer><silent> <Plug>(vimshell_iexe_previous_history)  <ESC>:<C-u>call <SID>previous_command()<CR>
        imap <buffer><C-p>     <Plug>(vimshell_iexe_previous_history)
        inoremap <buffer><silent> <Plug>(vimshell_iexe_next_history)  <ESC>:<C-u>call <SID>next_command()<CR>
        imap <buffer><C-n>     <Plug>(vimshell_iexe_next_history)
        inoremap <buffer><silent> <Plug>(vimshell_iexe_paste_prompt)  <ESC>:<C-u>call <SID>paste_prompt()<CR>
        imap <buffer><C-y>     <Plug>(vimshell_iexe_paste_prompt)
        inoremap <buffer><silent> <Plug>(vimshell_iexe_move_head)  <ESC>:<C-u>call <SID>move_head()<CR>
        imap <buffer><C-a>     <Plug>(vimshell_iexe_move_head)
        inoremap <buffer><silent> <Plug>(vimshell_iexe_delete_line)  <ESC>:<C-u>call <SID>delete_line()<CR>
        imap <buffer><C-u>     <Plug>(vimshell_iexe_delete_line)

        nnoremap <buffer><silent> <Plug>(vimshell_iexe_previous_prompt)  <ESC>:<C-u>call <SID>previous_prompt()<CR>
        nmap <buffer><C-p>     <Plug>(vimshell_iexe_previous_prompt)
        nnoremap <buffer><silent> <Plug>(vimshell_iexe_next_prompt)  <ESC>:<C-u>call <SID>next_prompt()<CR>
        nmap <buffer><C-n>     <Plug>(vimshell_iexe_next_prompt)

        autocmd vimshell_iexe CursorHold <buffer>  call s:on_hold()
        autocmd vimshell_iexe CursorHoldI <buffer>  call s:on_hold()
    endif

    normal! G$
    startinsert!
endfunction"}}}

function! s:on_execute()
    echo 'Running command.'
    if has('win32') || has('win64')
        call interactive#execute_pipe_inout(0)
    else
        call interactive#execute_pty_inout(0)
    endif
    redraw
    echo ''
endfunction

function! s:on_hold()
    echo 'Running command.'
    if has('win32') || has('win64')
        call interactive#execute_pipe_out()
    else
        call interactive#execute_pty_out()
    endif
    redraw
    echo ''
endfunction

function! s:on_exit()
    augroup vimshell_iexe
        autocmd! BufDelete <buffer>
        autocmd! CursorHold <buffer>
        autocmd! CursorHoldI <buffer>
    augroup END

    call interactive#force_exit()
endfunction

" Key-mappings functions."{{{

function! s:pty_completion()"{{{
    " Insert <TAB>.
    if exists('b:prompt_history[line(".")]')
        let l:prev_prompt = b:prompt_history[line('.')]
    else
        let l:prev_prompt = ''
    endif
    let l:prompt = getline('.')
    call setline(line('.'), getline('.') . "\<TAB>")

    " Do command completion.
    call interactive#execute_pty_inout(0)

    let l:candidate = getline('$')
    if l:candidate !~ l:prompt
        if l:candidate =~ '\\\@<!\s.\+'
            call append(line('$'), l:prompt)
            let b:prompt_history[line('.')] = l:prompt
            normal! j
        else
            call setline(line('$'), l:prompt . l:candidate)
            let b:prompt_history[line('.')] = l:prompt . l:candidate
        endif
        normal! $
    elseif l:candidate =~ '\t$'
        " Failed completion.
        call setline(line('$'), l:prompt)
        let b:prompt_history[line('$')] = l:prev_prompt
    endif

    startinsert!
endfunction"}}}
function! s:previous_command()"{{{
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
function! s:next_command()"{{{
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
function! s:delete_backword_char()"{{{
    " Prevent backspace over prompt
    if !exists("b:prompt_history['".line('.')."']") || getline(line('.')) != b:prompt_history[line('.')]
        return "\<BS>"
    else
        return ""
    endif
endfunction"}}}
function! s:execute_history()"{{{
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

    normal! G

    call interactive#execute_pty_inout(0)
endfunction"}}}
function! s:paste_prompt()"{{{
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

    normal! G
endfunction"}}}
function! s:previous_prompt()"{{{
    let l:prompts = sort(map(filter(keys(b:prompt_history), 'v:val < line(".")'), 'str2nr(v:val)'), 's:compare_func')
    if !empty(l:prompts)
        execute ':'.l:prompts[-1]
    endif
endfunction"}}}
function! s:move_head()"{{{
    if !exists('b:prompt_history[line(".")]')
        return
    endif
    call search(b:prompt_history[line('.')], 'be', line('.'))
    normal! l
    startinsert
endfunction"}}}
function! s:delete_line()"{{{
    if !exists('b:prompt_history[line(".")]')
        return
    endif

    let l:col = col('.')
    let l:mcol = col('$')
    call setline(line('.'), b:prompt_history[line('.')] . getline('.')[l:col :])
    call s:move_head()

    if l:col == l:mcol-1
        startinsert!
    endif
endfunction"}}}
"}}}

function! s:compare_func(i1, i2)
    return a:i1 == a:i2 ? 0 : a:i1 > a:i2 ? 1 : -1
endfunction
