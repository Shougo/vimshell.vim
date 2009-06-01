"=============================================================================
" FILE: bg.vim
" AUTHOR: Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 31 May 2009
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
" Version: 1.5, for Vim 7.0
"-----------------------------------------------------------------------------
" ChangeLog: "{{{
"   1.5:
"     - Improved autocmd.
"   1.4:
"     - Split nicely.
"   1.3:
"     - Use g:VimShell_EnableInteractive option.
"     - Use utls/process.vim.
"   1.2:
"     - Use vimproc.
"   1.1:
"     - Fixed in *nix.
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

let s:background_programs = 0
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
        return s:init_bg(a:args, a:other_info.is_interactive)
    else
        " Execute in screen.
        return vimshell#internal#screen#execute(a:args[0], a:args[1:], a:fd, l:other_info)
    endif
endfunction"}}}

function! vimshell#internal#bg#vimshell_bg(args)"{{{
    call vimshell#internal#bg#execute('bg', a:args, {}, {'is_interactive' : 0, 'is_background' : 1})
endfunction"}}}

function! s:init_bg(args, is_interactive)"{{{
    let l:proc = proc#import()

    try
        if has('win32') || has('win64')
            let l:sub = l:proc.popen2(a:args)
        else
            let l:sub = l:proc.ptyopen(a:args)
        endif
    catch
        if a:is_interactive
            call vimshell#error_line(printf('File: "%s" is not found.', a:args[0]))
        else
            echohl WarningMsg | echo printf('File: "%s" is not found.', a:args[0]) | echohl None
        endif

        return
    endtry

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
    edit `=join(a:args).'&'.(bufnr('$')+1)`
    setlocal buftype=nofile
    setlocal noswapfile

    " Set variables.
    let b:proc = l:proc
    let b:sub = l:sub

    if s:background_programs <= 0
        autocmd vimshell_bg CursorHold * call s:check_bg()
    endif
    let s:background_programs += 1
    autocmd vimshell_bg BufDelete <buffer>       call s:on_exit()
    nnoremap <buffer><silent><C-c>       :<C-u>call <sid>on_exit()<CR>
    inoremap <buffer><silent><C-c>       <ESC>:<C-u>call <sid>on_exit()<CR>
    nnoremap <buffer><silent><CR>       :<C-u>call vimshell#utils#process#execute_out()<CR>

    call vimshell#utils#process#execute_out()

    return 1
endfunction"}}}

function! s:on_exit()
    let s:background_programs -= 1

    augroup vimshell_bg
        autocmd! * <buffer>
    augroup END

    if s:background_programs <= 0
        autocmd! vimshell_bg CursorHold
    endif

    call vimshell#utils#process#exit()
endfunction

function! s:check_bg()"{{{
    let l:save_cursor = getpos('.')
    let l:bufnumber = 1
    let l:current_buf = bufnr('%')
    while l:bufnumber <= bufnr('$')
        if buflisted(l:bufnumber) && string(getbufvar(l:bufnumber, 'sub')) != ''
            execute 'buffer ' . l:bufnumber
            call vimshell#utils#process#execute_out()
        endif
        let l:bufnumber += 1
    endwhile
    execute 'buffer ' . l:current_buf
    call setpos('.', l:save_cursor)
endfunction"}}}
