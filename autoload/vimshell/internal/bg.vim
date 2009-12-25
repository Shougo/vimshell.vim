"=============================================================================
" FILE: bg.vim
" AUTHOR: Shougo Matsushita <Shougo.Matsu@gmail.com>
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
" Version: 1.15, for Vim 7.0
"-----------------------------------------------------------------------------
" ChangeLog: "{{{
"   1.15:
"     - Improved kill processes.
"     - Use vimproc.vim.
"
"   1.14:
"     - Improved error message.
"     - Set syntax.
"     - Improved execute message.
"
"   1.13:
"     - Extend current directory.
"
"   1.12:
"     - Set filetype.
"
"   1.11:
"     - Kill zombee process.
"
"   1.10: Improved CursorHold event.
"
"   1.9: Fixed error on Linux.
"
"   1.8: Supported pipe.
"
"   1.7: Improved error catch.
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
"   1.2:
"     - Use vimproc.
"
"   1.1:
"     - Fixed in *nix.
"
"   1.0:
"     - Initial version.
""}}}
"=============================================================================

augroup vimshell_bg
    autocmd!
augroup END

function! vimshell#internal#bg#execute(program, args, fd, other_info)"{{{
    " Execute program in background.

    if empty(a:args)
        return 
    elseif a:args[0] == 'shell'
        " Background shell.
        if has('win32') || has('win64')
            if g:VimShell_UseCkw
                " Use ckw.
                silent execute printf('!start ckw -e %s', &shell)
            else
                silent execute printf('!start %s', &shell)
            endif
        elseif &term =~ '^screen'
            silent execute printf('!screen %s', &shell)
        else
            " Can't Background execute.
            shell
        endif
    elseif a:args[0] == 'iexe'
        " Background iexe.
        let l:other_info = a:other_info
        let l:other_info.is_background = 1
        return vimshell#internal#iexe#execute(a:args[0], a:args[1:], a:fd, l:other_info)
    elseif g:VimShell_EnableInteractive
        " Background execute.
        return s:init_bg(a:fd, a:args, a:other_info.is_interactive)
    else
        " Execute in screen.
        let l:other_info = a:other_info
        return vimshell#internal#screen#execute(a:args[0], a:args[1:], a:fd, l:other_info)
    endif
endfunction"}}}

function! vimshell#internal#bg#vimshell_bg(args)"{{{
    call vimshell#internal#bg#execute('bg', a:args, {'stdin' : '', 'stdout' : '', 'stderr' : ''}, {'is_interactive' : 0, 'is_background' : 1})
endfunction"}}}

function! s:init_bg(fd, args, is_interactive)"{{{
    if exists('b:vimproc_sub')
        " Delete zombee process.
        call vimshell#interactive#force_exit()
    endif

    " Initialize.
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
            if g:VimShell_UsePopen2
                call add(l:sub, vimproc#popen2(command))
            else
                call add(l:sub, vimproc#popen3(command))
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

    " Init buffer.
    if a:is_interactive
        call vimshell#print_prompt()
    endif

    " Save current directiory.
    let l:cwd = getcwd()

    " Split nicely.
    if winheight(0) > &winheight
        split
    else
        vsplit
    endif

    edit `=join(a:args).'&'.(bufnr('$')+1)`
    lcd `=l:cwd`
    setlocal buftype=nofile
    setlocal noswapfile
    setlocal nowrap
    execute 'setfiletype ' . a:args[0]

    " Set syntax.
    syn region   VimShellError   start=+!!!+ end=+!!!+ contains=VimShellErrorHidden oneline
    syn match   VimShellErrorHidden            '!!!' contained
    hi def link VimShellError Error
    hi def link VimShellErrorHidden Ignore

    " Set variables.
    let b:vimproc_sub = l:sub
    let b:vimproc_fd = a:fd

    " Input from stdin.
    if b:vimproc_fd.stdin != ''
        if has('win32') || has('win64')
            call b:vimproc_sub[0].stdin.write(vimshell#read(a:fd))
            call b:vimproc_sub[0].stdin.close()
        else
            call b:vimproc_sub[0].write(vimshell#read(a:fd))
        endif
    endif

    autocmd vimshell_bg BufUnload <buffer>       call <SID>on_exit()
    autocmd vimshell_bg CursorHold <buffer>  call <SID>on_execute()
    nnoremap <buffer><silent><C-c>       :<C-u>call vimshell#interactive#interrupt()<CR>
    inoremap <buffer><silent><C-c>       <ESC>:<C-u>call <SID>on_exit()<CR>
    nnoremap <buffer><silent><CR>       :<C-u>call <SID>on_execute()<CR>
    call s:on_execute()

    return 1
endfunction"}}}

function! s:on_execute()
    echo 'Running command.'
    call vimshell#interactive#execute_pipe_out()
    redraw
    echo ''
endfunction

function! s:on_exit()
    augroup vimshell_bg
        autocmd! CursorHold <buffer>
        autocmd! BufUnload <buffer>
    augroup END

    call vimshell#interactive#hang_up()
endfunction
