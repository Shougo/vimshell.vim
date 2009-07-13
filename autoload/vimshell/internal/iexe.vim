"=============================================================================
" FILE: iexe.vim
" AUTHOR: Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 11 Jul 2009
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
" Version: 1.10, for Vim 7.0
"-----------------------------------------------------------------------------
" ChangeLog: "{{{
"   1.10: 
"     - Improved behavior.
"     - Kill zombee process.
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
            " Use system().
            let l:cmdline = ''
            for arg in a:args
                let l:cmdline .= substitute(arg, '"', '\\""', 'g') . ' '
            endfor

            " Set redirection.
            if a:fd.stdin != ''
                let l:stdin = '<' . a:fd.stdin
            else
                let l:stdin = ''
            endif

            call vimshell#print(a:fd, system(printf('%s %s', l:cmdline, l:stdin)))

            let b:vimshell_system_variables['status'] = v:shell_error
            return 0
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

            if a:other_info.is_interactive
                call vimshell#error_line(a:fd, l:error)
            else
                echohl WarningMsg | echomsg l:error | echohl None
            endif

            return 0
        endtry
    endfor

    if exists('b:vimproc_sub')
        " Delete zombee process.
        call interactive#force_exit()
    endif

    if a:other_info.is_background
        call s:init_bg(l:proc, l:sub, a:args, a:other_info.is_interactive)
    endif

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

    if a:other_info.is_background
        if has('win32') || has('win64')
            call interactive#execute_pipe_out()
        else
            call interactive#execute_pty_out()
        endif
        startinsert!

        return 1
    else
        if has('win32') || has('win64')
            call interactive#execute_pipe_out()
            while exists('b:vimproc_sub')
                call interactive#execute_pipe_inout(1)
            endwhile
        else
            call interactive#execute_pty_out()
            while exists('b:vimproc_sub')
                call interactive#execute_pty_inout(1)
            endwhile
        endif
        let b:vimshell_system_variables['status'] = b:vimproc_status

        return 0
    endif
endfunction"}}}

function! vimshell#internal#iexe#vimshell_iexe(args)"{{{
    call vimshell#internal#iexe#execute('iexe', a:args, {'stdin' : '', 'stdout' : '', 'stderr' : ''}, {'is_interactive' : 0, 'is_background' : 1})
endfunction"}}}

function! s:init_bg(proc, sub, args, is_interactive)"{{{
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
    setlocal buftype=nofile
    setlocal noswapfile

    nnoremap <buffer><silent><C-c>       :<C-u>call <sid>on_exit()<CR>
    inoremap <buffer><silent><C-c>       <ESC>:<C-u>call <sid>on_exit()<CR>
    augroup vimshell_iexe
        autocmd BufDelete <buffer>   call s:on_exit()
    augroup END

    if has('win32') || has('win64')
        nnoremap <buffer><silent><CR>       :<C-u>call interactive#execute_pipe_inout(0)<CR>
        inoremap <buffer><silent><CR>       <ESC>:<C-u>call interactive#execute_pipe_inout(0)<CR>
        autocmd vimshell_iexe CursorHold <buffer>  call interactive#execute_pipe_out()
        call interactive#execute_pipe_out()
    else
        nnoremap <buffer><silent><CR>       :<C-u>call interactive#execute_pty_inout(0)<CR>
        inoremap <buffer><silent><CR>       <ESC>:<C-u>call interactive#execute_pty_inout(0)<CR>
        autocmd vimshell_iexe CursorHold <buffer>  call interactive#execute_pty_out()
        call interactive#execute_pty_out()
    endif
endfunction"}}}

function! s:on_exit()
    augroup vimshell_iexe
        autocmd! BufDelete <buffer>
        autocmd! CursorHold <buffer>
    augroup END

    call interactive#force_exit()
endfunction

