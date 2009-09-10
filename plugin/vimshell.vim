"=============================================================================
" FILE: vimshell.vim
" AUTHOR: Janakiraman .S <prince@india.ti.com>(Original)
"         Shougo Matsushita <Shougo.Matsu@gmail.com>(Modified)
" Last Modified: 03 Sep 2009
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
" Version: 5.33, for Vim 7.0
"=============================================================================

if exists('g:loaded_vimshell') || v:version < 700
  finish
endif

" Plugin keymapping"{{{
nnoremap <silent> <Plug>(vimshell_split_switch)  :<C-u>call vimshell#switch_shell(1)<CR>
nnoremap <silent> <Plug>(vimshell_split_create)  :<C-u>call vimshell#create_shell(1)<CR>
nnoremap <silent> <Plug>(vimshell_switch)  :<C-u>call vimshell#switch_shell(0)<CR>
nnoremap <silent> <Plug>(vimshell_create)  :<C-u>call vimshell#create_shell(0)<CR>
nnoremap <silent> <Plug>(vimshell_enter)  :<C-u>call vimshell#process_enter()<CR>
nnoremap <silent> <Plug>(vimshell_previous_prompt)  :<C-u>call vimshell#previous_prompt()<CR>
nnoremap <silent> <Plug>(vimshell_next_prompt)  :<C-u>call vimshell#next_prompt()<CR>
nnoremap <silent> <Plug>(vimshell_delete_previous_output)  :<C-u>call vimshell#delete_previous_output()<CR>
nnoremap <silent> <Plug>(vimshell_paste_prompt)  :<C-u>call vimshell#paste_prompt()<CR>

inoremap <silent> <Plug>(vimshell_insert_command_completion)  <C-o>:<C-u>call vimshell#complete#insert_command_completion()<CR>
inoremap <silent> <Plug>(vimshell_push_current_line)  <ESC>:<C-u>call vimshell#push_current_line()<CR>
inoremap <silent> <Plug>(vimshell_insert_last_word)  <ESC>:<C-u>call vimshell#insert_last_word()<CR>
inoremap <silent> <Plug>(vimshell_run_help)  <ESC>:<C-u>call vimshell#run_help()<CR>
inoremap <silent> <Plug>(vimshell_move_head)  <ESC>:<C-u>call vimshell#move_head()<CR>
inoremap <silent> <Plug>(vimshell_delete_line)  <ESC>:<C-u>call vimshell#delete_line()<CR>
inoremap <silent> <Plug>(vimshell_clear)  <ESC>:<C-u>call vimshell#clear()<CR>

nmap <silent> <Leader>sp     <Plug>(vimshell_split_switch)
nmap <silent> <Leader>sn     <Plug>(vimshell_split_create)
nmap <silent> <Leader>sh     <Plug>(vimshell_switch)
nmap <silent> <Leader>sc     <Plug>(vimshell_create)
"}}}

" Global options definition."{{{
if !exists('g:VimShell_Prompt')
    let g:VimShell_Prompt = 'vimshell% '
endif
if !exists('g:VimShell_SecondaryPrompt')
    let g:VimShell_SecondaryPrompt = '%% '
endif
if !exists('g:VimShell_HistoryPath')
    if has('win32') || has('win64')
        let g:VimShell_HistoryPath = $HOME.'\.vimshell_hist'
    else
        let g:VimShell_HistoryPath = $HOME.'/.vimshell_hist'
    endif

    if !isdirectory(fnamemodify(g:VimShell_HistoryPath, ':p:h'))
        call mkdir(fnamemodify(g:VimShell_HistoryPath, ':p:h'), 'p')
    endif
endif
if !exists('g:VimShell_HistoryMaxSize')
    let g:VimShell_HistoryMaxSize = 1000
endif
if !exists('g:VimShell_VimshrcPath')
    if has('win32') || has('win64')
        let g:VimShell_VimshrcPath = $HOME.'\.vimshrc'
    else
        let g:VimShell_VimshrcPath = $HOME.'/.vimshrc'
    endif

    if !isdirectory(fnamemodify(g:VimShell_VimshrcPath, ':p:h'))
        call mkdir(fnamemodify(g:VimShell_VimshrcPath, ':p:h'), 'p')
    endif
endif
if !exists('g:VimShell_IgnoreCase')
    let g:VimShell_IgnoreCase = 1
endif
if !exists('g:VimShell_SmartCase')
    let g:VimShell_SmartCase = 0
endif
if !exists('g:VimShell_MaxHistoryWidth')
    let g:VimShell_MaxHistoryWidth = 40
endif
if !exists('g:VimShell_UseCkw')
    let g:VimShell_UseCkw = 0
endif
if !exists('g:VimShell_ExecuteFileList')
    let g:VimShell_ExecuteFileList = {}
endif
if !exists('g:VimShell_EnableInteractive')
    let g:VimShell_EnableInteractive = 0
endif
if !exists('g:VimShell_SplitHeight')
    let g:VimShell_SplitHeight = 30
endif
if !exists('g:VimShell_UsePopen2')
    let g:VimShell_UsePopen2 = 0
endif
if !exists('g:VimShell_EnableAutoLs')
    let g:VimShell_EnableAutoLs = 0
endif
"}}}

command! -nargs=0 VimShell call vimshell#switch_shell(0)
command! -nargs=+ -complete=shellcmd VimShellExecute call vimshell#internal#bg#vimshell_bg(split(<q-args>))
command! -nargs=+ -complete=shellcmd VimShellInteractive call vimshell#internal#iexe#vimshell_iexe(split(<q-args>))

let g:loaded_vimshell = 1

" vim: foldmethod=marker
