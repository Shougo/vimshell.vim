"=============================================================================
" FILE: vimshell.vim
" AUTHOR: Janakiraman .S <prince@india.ti.com>(Original)
"         Shougo Matsushita <Shougo.Matsu@gmail.com>(Modified)
" Last Modified: 17 Jan 2010
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
" Version: 6.03, for Vim 7.0
"=============================================================================

if v:version < 700
    echoerr 'vimshell does not work this version of Vim "' . v:version . '".'
    finish
elseif exists('g:loaded_vimshell')
    finish
endif

let s:save_cpo = &cpo
set cpo&vim

" Global options definition."{{{
if !exists('g:VimShell_IgnoreCase')
    let g:VimShell_IgnoreCase = 1
endif
if !exists('g:VimShell_SmartCase')
    let g:VimShell_SmartCase = 0
endif
if !exists('g:VimShell_MaxKeywordWidth')
    let g:VimShell_MaxKeywordWidth = 40
endif
if !exists('g:VimShell_MaxList')
    let g:VimShell_MaxList = 100
endif
if !exists('g:VimShell_UseCkw')
    let g:VimShell_UseCkw = 0
endif
if !exists('g:VimShell_EnableInteractive')
    let g:VimShell_EnableInteractive = 0
endif
if !exists('g:VimShell_SplitHeight')
    let g:VimShell_SplitHeight = 40
endif
if !exists('g:VimShell_UsePopen2')
    let g:VimShell_UsePopen2 = 0
endif
if !exists('g:VimShell_EnableAutoLs')
    let g:VimShell_EnableAutoLs = 0
endif

if !exists('g:VimShell_HistoryPath')
    let g:VimShell_HistoryPath = '~/.vimshell_hist'
endif
let g:VimShell_HistoryPath = expand(g:VimShell_HistoryPath)
if !isdirectory(fnamemodify(g:VimShell_HistoryPath, ':p:h'))
    call mkdir(fnamemodify(g:VimShell_HistoryPath, ':p:h'), 'p')
endif
if !exists('g:VimShell_HistoryMaxSize')
    let g:VimShell_HistoryMaxSize = 1000
endif
if !exists('g:VimShell_VimshrcPath')
    let g:VimShell_VimshrcPath = '~/.vimshrc'
endif
let g:VimShell_VimshrcPath = expand(g:VimShell_VimshrcPath)
if !isdirectory(fnamemodify(g:VimShell_VimshrcPath, ':p:h'))
    call mkdir(fnamemodify(g:VimShell_VimshrcPath, ':p:h'), 'p')
endif
if !exists('g:VimShell_EscapeColors')
    let g:VimShell_EscapeColors = [
                \'#3c3c3c', '#ff6666', '#66ff66', '#ffd30a', '#1e95fd', '#ff13ff', '#1bc8c8', '#C0C0C0', 
                \'#686868', '#ff6666', '#66ff66', '#ffd30a', '#6699ff', '#f820ff', '#4ae2e2', '#ffffff'
                \]
endif
"}}}

" Plugin keymappings"{{{
nnoremap <silent> <Plug>(vimshell_split_switch)  :<C-u>call vimshell#switch_shell(1, '')<CR>
nnoremap <silent> <Plug>(vimshell_split_create)  :<C-u>call vimshell#create_shell(1, '')<CR>
nnoremap <silent> <Plug>(vimshell_switch)  :<C-u>call vimshell#switch_shell(0, '')<CR>
nnoremap <silent> <Plug>(vimshell_create)  :<C-u>call vimshell#create_shell(0, '')<CR>

if !(exists('g:VimShell_NoDefaultKeyMappings') && g:VimShell_NoDefaultKeyMappings)
    silent! nmap <unique> <Leader>sp     <Plug>(vimshell_split_switch)
    silent! nmap <unique> <Leader>sn     <Plug>(vimshell_split_create)
    silent! nmap <unique> <Leader>sh     <Plug>(vimshell_switch)
    silent! nmap <unique> <Leader>sc     <Plug>(vimshell_create)
endif
"}}}

command! -nargs=? -complete=dir VimShell call vimshell#switch_shell(0, <q-args>)
command! -nargs=? -complete=dir VimShellCreate call vimshell#create_shell(0, <q-args>)
command! -nargs=? -complete=dir VimShellPop call vimshell#switch_shell(1, <q-args>)
command! -nargs=+ -complete=shellcmd VimShellExecute call vimshell#internal#bg#vimshell_bg(vimshell#parser#split_args(<q-args>))
command! -nargs=+ -complete=shellcmd VimShellInteractive call vimshell#internal#iexe#vimshell_iexe(vimshell#parser#split_args(<q-args>))

let &cpo = s:save_cpo
unlet s:save_cpo

let g:loaded_vimshell = 1

" vim: foldmethod=marker
