"=============================================================================
" FILE: vimshell.vim
" AUTHOR: Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 18 Jun 2010
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

if v:version < 700
  echoerr 'vimshell does not work this version of Vim "' . v:version . '".'
  finish
elseif exists('g:loaded_vimshell')
  finish
endif

let s:save_cpo = &cpo
set cpo&vim

" Obsolute options check."{{{
if exists('g:VimShell_Prompt')
  echoerr 'g:VimShell_Prompt option does not work this version of vimshell.'
endif
if exists('g:VimShell_SecondaryPrompt')
  echoerr 'g:VimShell_SecondaryPrompt option does not work this version of vimshell.'
endif
if exists('g:VimShell_UserPrompt')
  echoerr 'g:VimShell_UserPrompt option does not work this version of vimshell.'
endif
if exists('g:VimShell_EnableInteractive')
  echoerr 'g:VimShell_EnableInteractive option does not work this version of vimshell.'
endif
"}}}
" Global options definition."{{{
if !exists('g:vimshell_ignore_case')
  let g:vimshell_ignore_case = &ignorecase
endif
if !exists('g:vimshell_smart_case')
  let g:vimshell_smart_case = 0
endif
if !exists('g:vimshell_max_list')
  let g:vimshell_max_list = 100
endif
if !exists('g:vimshell_use_ckw')
  let g:vimshell_use_ckw = 0
endif
if !exists('g:vimshell_split_height')
  let g:vimshell_split_height = 30
endif
if !exists('g:vimshell_temporary_directory')
  let g:vimshell_temporary_directory = expand('~/.vimshell')
endif
if !isdirectory(fnamemodify(g:vimshell_temporary_directory, ':p'))
  call mkdir(fnamemodify(g:vimshell_temporary_directory, ':p'), 'p')
endif
if !exists('g:vimshell_history_max_size')
  let g:vimshell_history_max_size = 1000
endif
if !exists('g:vimshell_vimshrc_path')
  let g:vimshell_vimshrc_path = '~/.vimshrc'
endif
let g:vimshell_vimshrc_path = expand(g:vimshell_vimshrc_path)
if !isdirectory(fnamemodify(g:vimshell_vimshrc_path, ':p:h'))
  call mkdir(fnamemodify(g:vimshell_vimshrc_path, ':p:h'), 'p')
endif
if !exists('g:vimshell_escape_colors')
  let g:vimshell_escape_colors = [
        \'#3c3c3c', '#ff6666', '#66ff66', '#ffd30a', '#1e95fd', '#ff13ff', '#1bc8c8', '#C0C0C0',
        \'#686868', '#ff6666', '#66ff66', '#ffd30a', '#6699ff', '#f820ff', '#4ae2e2', '#ffffff',
        \]
endif
if !exists('g:vimshell_no_save_history_programs')
  let g:vimshell_no_save_history_programs = {}
endif
if !exists('g:vimshell_interactive_update_time')
  let g:vimshell_interactive_update_time = 500
endif
if !exists('g:vimshell_cat_command')
  let g:vimshell_cat_command = 'cat'
endif
"}}}

command! -nargs=? -complete=dir VimShell call vimshell#switch_shell(0, <q-args>)
command! -nargs=? -complete=dir VimShellCreate call vimshell#create_shell(0, <q-args>)
command! -nargs=? -complete=dir VimShellPop call vimshell#switch_shell(1, <q-args>)
command! -nargs=+ -complete=customlist,vimshell#complete#vimshell_execute_complete#completefunc VimShellExecute call vimshell#internal#bg#vimshell_bg(<q-args>)
command! -nargs=+ -complete=customlist,vimshell#complete#vimshell_execute_complete#completefunc VimShellInteractive call vimshell#internal#iexe#vimshell_iexe(<q-args>)
command! -nargs=+ -complete=customlist,vimshell#complete#vimshell_execute_complete#completefunc VimShellBang call s:bang(<q-args>)
command! -nargs=+ -complete=customlist,vimshell#complete#vimshell_execute_complete#completefunc VimShellRead call s:read(<q-args>)

" Plugin keymappings"{{{
nnoremap <silent> <Plug>(vimshell_split_switch)  :<C-u>call vimshell#switch_shell(1, '')<CR>
nnoremap <silent> <Plug>(vimshell_split_create)  :<C-u>call vimshell#create_shell(1, '')<CR>
nnoremap <silent> <Plug>(vimshell_switch)  :<C-u>call vimshell#switch_shell(0, '')<CR>
nnoremap <silent> <Plug>(vimshell_create)  :<C-u>call vimshell#create_shell(0, '')<CR>
"}}}

" Command functions:
function! s:bang(cmdline)"{{{
  let [l:program, l:script] = vimshell#parser#parse_alias(a:cmdline)
  echo vimshell#system(l:program . ' ' . l:script)
endfunction"}}}
function! s:read(cmdline)"{{{
  let [l:program, l:script] = vimshell#parser#parse_alias(a:cmdline)
  call append('.', split(vimshell#system(l:program . ' ' . l:script), '\n'))
endfunction"}}}

augroup VimShell
  " Detect vimshell rc file.
  autocmd BufNewFile,BufRead *.vimsh,.vimshrc set filetype=vimshrc
augroup END

let &cpo = s:save_cpo
unlet s:save_cpo

let g:loaded_vimshell = 1

" vim: foldmethod=marker
