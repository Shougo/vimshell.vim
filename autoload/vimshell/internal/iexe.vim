"=============================================================================
" FILE: iexe.vim
" AUTHOR: Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 05 Jun 2009
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
" Version: 1.6, for Vim 7.0
"-----------------------------------------------------------------------------
" ChangeLog: "{{{
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
        " Error.
        call vimshell#error_line('Must use vimproc plugin.')
        return 0
    endif

    if empty(a:args)
        return 0
    endif

    " Initialize.
    let l:proc = proc#import()

    try
        if has('win32') || has('win64')
            let l:sub = l:proc.popen3(a:args)
        else
            let l:sub = l:proc.ptyopen(a:args)
        endif
    catch 'list index out of range'
        if a:other_info.is_interactive
            call vimshell#error_line(a:fd, printf('File: "%s" is not found.', a:args[0]))
        else
            echohl WarningMsg | echo printf('File: "%s" is not found.', a:args[0]) | echohl None
        endif

        return
    endtry

    if a:other_info.is_background
        call s:init_bg(l:proc, l:sub, a:args, a:other_info.is_interactive)
        call interactive#execute_inout(0)

        return 1
    else
        " Set variables.
        let b:vimproc = l:proc
        let b:subproc = l:sub
        let b:proc_fd = a:fd

        " Input from stdin.
        if b:proc_fd.stdin != ''
            if has('win32') || has('win64')
                call b:subproc.stdin.write(vimshell#read(a:fd))
                call b:subproc.stdin.close()
            else
                call b:subproc.write(vimshell#read(a:fd))
            endif
        endif

        while exists('b:subproc')
            call interactive#execute_out()
            call interactive#execute_inout(1)
        endwhile

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
    edit `=join(a:args).'@'.(bufnr('$')+1)`
    setlocal buftype=nofile
    setlocal noswapfile

    " Set variables.
    let b:vimproc = a:proc
    let b:subproc = a:sub
    let b:proc_fd = a:fd

    " Input from stdin.
    if b:proc_fd.stdin != ''
        if has('win32') || has('win64')
            call b:subproc.stdin.write(vimshell#read(a:fd))
            call b:subproc.stdin.close()
        else
            call b:subproc.write(vimshell#read(a:fd))
        endif
    endif

    nnoremap <buffer><silent><CR>       :<C-u>call interactive#execute_inout(0)<CR>
    inoremap <buffer><silent><CR>       <ESC>:<C-u>call interactive#execute_inout(0)<CR>
    nnoremap <buffer><silent><C-c>       :<C-u>call <sid>on_exit()<CR>
    inoremap <buffer><silent><C-c>       <ESC>:<C-u>call <sid>on_exit()<CR>
    augroup vimshell_iexe
        autocmd BufDelete <buffer>   call s:on_exit()
        autocmd CursorHold <buffer>  call interactive#execute_out()
    augroup END

    call interactive#execute_out()

    return 1
endfunction"}}}

function! s:on_exit()
    augroup vimshell_iexe
        autocmd! * <buffer>
    augroup END

    call interactive#exit()
endfunction

