"=============================================================================
" FILE: iexe.vim
" AUTHOR: Shougo Matsushita <Shougo.Matsu@gmail.com>
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
" Version: 1.21, for Vim 7.0
"-----------------------------------------------------------------------------
" ChangeLog: "{{{
"   1.21: 
"     - Implemented auto update.
"
"   1.20: 
"     - Implemented execute line.
"     - Improved irb option.
"
"   1.19: 
"     - Improved autocommand.
"     - Improved completion.
"     - Added powershell.exe and cmd.exe support.
"
"   1.18: 
"     - Implemented Windows pty support.
"     - Improved CursorHoldI event.
"     - Set interactive option in Windows.
"
"   1.17: 
"     - Use updatetime.
"     - Deleted CursorHold event.
"     - Deleted echo.
"     - Improved filetype.
"
"   1.16: 
"     - Improved kill processes.

"     - Send interrupt when press <C-c>.
"     - Improved tab completion.
"     - Use vimproc.vim.
"
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
            return vimshell#internal#sexe#execute('sexe', a:args, a:fd, a:other_info)
        endif
    endif

    if empty(a:args)
        return 0
    endif

    let l:args = a:args
    if has_key(s:interactive_option, fnamemodify(a:args[0], ':r'))
        call add(l:args, s:interactive_option[fnamemodify(a:args[0], ':r')])
    endif
    
    if vimshell#iswin() && a:args[0] =~ 'cmd\%(\.exe\)\?'
        " Run cmdproxy.exe instead of cmd.exe.
        if !executable('cmdproxy.exe')
            call vimshell#error_line(a:fd, 'cmdproxy.exe is not found. Please install it.')
            return 0
        endif
        
        let l:args[0] = 'cmdproxy.exe'
    endif

    " Initialize.
    try
        let l:sub = [vimproc#ptyopen(l:args)]
    catch 'list index out of range'
        let l:error = printf('File: "%s" is not found.', command[0])

        call vimshell#error_line(a:fd, l:error)

        return 0
    endtry

    if exists('b:vimproc_sub')
        " Delete zombee process.
        call vimshell#interactive#force_exit()
    endif

    call s:init_bg(l:sub, l:args, a:other_info.is_interactive)

    " Set variables.
    let b:vimproc_sub = l:sub
    let b:vimproc_fd = a:fd
    let b:vimproc_is_secret = 0

    " Input from stdin.
    if b:vimproc_fd.stdin != ''
        call b:vimproc_sub[0].write(vimshell#read(a:fd))
    endif

    call vimshell#interactive#execute_pty_out()
    if getline(line('$')) =~ '^\s*$'
        call setline(line('$'), '...')
    endif
    
    startinsert!

    return 1
endfunction"}}}

function! vimshell#internal#iexe#default_settings()"{{{
    setlocal buftype=nofile
    setlocal noswapfile
    setlocal wrap
    setlocal tabstop=8

    " Set syntax.
    syn region   VimShellError   start=+!!!+ end=+!!!+ contains=VimShellErrorHidden oneline
    syn match   VimShellErrorHidden            '!!!' contained
    hi def link VimShellError Error
    hi def link VimShellErrorHidden Ignore

    nnoremap <buffer><silent><C-c>       :<C-u>call <SID>on_exit()<CR>
    inoremap <buffer><silent><C-c>       <C-o>:<C-u>call vimshell#interactive#interrupt()<CR>

    inoremap <buffer><silent><CR>       <ESC>:<C-u>call <SID>on_execute()<CR>

    " Plugin key-mappings.
    inoremap <buffer><silent><expr> <Plug>(vimshell_iexe_delete_backword_char)  <SID>delete_backword_char()
    inoremap <buffer><silent> <Plug>(vimshell_iexe_previous_history)  <ESC>:<C-u>call <SID>previous_command()<CR>
    inoremap <buffer><silent> <Plug>(vimshell_iexe_next_history)  <ESC>:<C-u>call <SID>next_command()<CR>
    inoremap <buffer><silent> <Plug>(vimshell_iexe_paste_prompt)  <ESC>:<C-u>call <SID>paste_prompt()<CR>
    inoremap <buffer><silent> <Plug>(vimshell_iexe_move_head)  <ESC>:<C-u>call <SID>move_head()<CR>
    inoremap <buffer><silent> <Plug>(vimshell_iexe_delete_line)  <ESC>:<C-u>call <SID>delete_line()<CR>
    
    imap <buffer><C-h>     <Plug>(vimshell_iexe_delete_backword_char)
    imap <buffer><BS>     <Plug>(vimshell_iexe_delete_backword_char)
    imap <buffer><expr><TAB>   pumvisible() ? "\<C-n>" : vimshell#complete#interactive_command_complete#complete()
    imap <buffer><C-p>     <Plug>(vimshell_iexe_previous_history)
    imap <buffer><C-n>     <Plug>(vimshell_iexe_next_history)
    imap <buffer><C-y>     <Plug>(vimshell_iexe_paste_prompt)
    imap <buffer><C-a>     <Plug>(vimshell_iexe_move_head)
    imap <buffer><C-u>     <Plug>(vimshell_iexe_delete_line)

    nnoremap <buffer><silent> <Plug>(vimshell_iexe_previous_prompt)  <ESC>:<C-u>call <SID>previous_prompt()<CR>
    nnoremap <buffer><silent> <Plug>(vimshell_iexe_next_prompt)  <ESC>:<C-u>call <SID>next_prompt()<CR>
    nnoremap <buffer><silent> <Plug>(vimshell_iexe_execute_line)  <ESC>:<C-u>call <SID>execute_line()<CR>
    
    nmap <buffer><C-p>     <Plug>(vimshell_iexe_previous_prompt)
    nmap <buffer><C-n>     <Plug>(vimshell_iexe_next_prompt)
    nmap <buffer><CR>      <Plug>(vimshell_iexe_execute_line)

    augroup vimshell_iexe
        autocmd BufUnload <buffer>   call s:on_exit()
        autocmd CursorMovedI <buffer>  call s:on_moved()
        autocmd CursorHoldI <buffer>  call s:on_hold()
        autocmd InsertEnter <buffer>  call s:on_insert_enter()
        autocmd InsertLeave <buffer>  call s:on_insert_leave()
    augroup END
endfunction"}}}

function! s:init_bg(sub, args, is_interactive)"{{{
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

    edit `=fnamemodify(a:args[0], ':r').'@'.(bufnr('$')+1)`
    lcd `=l:cwd`
    "setfiletype `='int_'.fnamemodify(a:args[0], ':r')`
    execute 'setfiletype' 'int_'.fnamemodify(a:args[0], ':r')

    call vimshell#internal#iexe#default_settings()

    $
    
    startinsert!
endfunction"}}}

function! s:on_execute()
    call vimshell#interactive#execute_pty_inout()
endfunction

function! s:on_insert_enter()
    let s:save_updatetime = &updatetime
    let &updatetime = 500
endfunction

function! s:on_insert_leave()
    let &updatetime = s:save_updatetime
endfunction

function! s:on_hold()
    let [l:linenr, l:prev_line] = [line('.'), getline('.')]
    
    call vimshell#interactive#execute_pty_out()
    
    if !exists('b:vimproc_sub')
        stopinsert
    else
        call feedkeys("\<C-l>\<BS>\<C-e>", 'n')
    endif
endfunction

function! s:on_moved()
    let l:line = getline('.')
    if l:line =~ '^\.\.\.\.\?[^.]\+$'
        " Set prompt.
        call setline('.', '-> ' . l:line[len(matchstr(l:line, '^\.\.\.\.\?')) :])
    endif
endfunction

function! s:on_exit()
    call vimshell#interactive#hang_up()
endfunction

" Interactive option.
if vimshell#iswin()
    " Windows only.
    let s:interactive_option = {
                \ 'bash' : '-i', 'bc' : '-i', 'irb' : '--inf-ruby-mode', 
                \ 'gosh' : '-i', 'python' : '-i', 
                \ 'powershell' : '-Command -'
                \}
else
    let s:interactive_option = {}
endif

" Key-mappings functions."{{{
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

    $

    call vimshell#interactive#execute_pty_inout()
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

    $
endfunction"}}}
function! s:previous_prompt()"{{{
    let l:prompts = sort(map(filter(keys(b:prompt_history), 'v:val < line(".")'), 'str2nr(v:val)'), 's:compare_func')
    if !empty(l:prompts)
        execute ':'.l:prompts[-1]
    endif
endfunction"}}}
function! s:next_prompt()"{{{
    let l:prompts = sort(map(filter(keys(b:prompt_history), 'v:val > line(".")'), 'str2nr(v:val)'), 's:compare_func')
    if !empty(l:prompts)
        execute ':'.l:prompts[0]
    endif
endfunction"}}}
function! s:move_head()"{{{
    if !exists('b:prompt_history[line(".")]')
        return
    endif
    call search(vimshell#escape_match(b:prompt_history[line('.')]), 'be', line('.'))
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
function! s:execute_line()"{{{
    if exists('b:prompt_history[line(".")]')
        " Execute history.
        call s:execute_history()
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
"}}}

function! s:compare_func(i1, i2)
    return a:i1 == a:i2 ? 0 : a:i1 > a:i2 ? 1 : -1
endfunction
