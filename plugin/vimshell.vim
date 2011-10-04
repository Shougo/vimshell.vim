"=============================================================================
" FILE: vimshell.vim
" AUTHOR: Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 04 Oct 2011.
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
if !exists('g:vimshell_use_terminal_command')
  let g:vimshell_use_terminal_command = ''
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
if !exists('g:vimshell_max_command_history')
  let g:vimshell_max_command_history = 1000
endif
if !exists('g:vimshell_max_directory_stack')
  let g:vimshell_max_directory_stack = 100
endif
if !exists('g:vimshell_vimshrc_path')
  let g:vimshell_vimshrc_path = expand('~/.vimshrc')
endif
let g:vimshell_vimshrc_path = expand(g:vimshell_vimshrc_path)
if !isdirectory(fnamemodify(g:vimshell_vimshrc_path, ':p:h'))
  call mkdir(fnamemodify(g:vimshell_vimshrc_path, ':p:h'), 'p')
endif
if !exists('g:vimshell_escape_colors')
  let g:vimshell_escape_colors = [
        \'#6c6c6c', '#ff6666', '#66ff66', '#ffd30a', '#1e95fd', '#ff13ff', '#1bc8c8', '#C0C0C0',
        \'#383838', '#ff4444', '#44ff44', '#ffb30a', '#6699ff', '#f820ff', '#4ae2e2', '#ffffff',
        \]
endif
if !exists('g:vimshell_disable_escape_highlight')
  let g:vimshell_disable_escape_highlight = 0
endif
if !exists('g:vimshell_cat_command')
  let g:vimshell_cat_command = 'cat'
endif
if !exists('g:vimshell_environment_term')
  let g:vimshell_environment_term = 'vt100'
endif
if !exists('g:vimshell_split_command')
  let g:vimshell_split_command = 'nicely'
endif
if !exists('g:vimshell_cd_command')
  let g:vimshell_cd_command = 'lcd'
endif
if !exists('g:vimshell_external_history_path')
  let g:vimshell_external_history_path = ''
endif
if !exists('g:vimshell_no_save_history_commands')
  let g:vimshell_no_save_history_commands = { 'history' : 1, 'h' : 1, 'histdel' : 1 }
endif
if !exists('g:vimshell_interactive_no_save_history_commands')
  let g:vimshell_interactive_no_save_history_commands = {}
endif
if !exists('g:vimshell_interactive_update_time')
  let g:vimshell_interactive_update_time = 500
endif
if !exists('g:vimshell_interactive_command_options')
  let g:vimshell_interactive_command_options = {}
endif
if !exists('g:vimshell_interactive_interpreter_commands')
  let g:vimshell_interactive_interpreter_commands = {}
endif
if !exists('g:vimshell_interactive_encodings')
  let g:vimshell_interactive_encodings = {}
endif
if !exists('g:vimshell_interactive_prompts')
  let g:vimshell_interactive_prompts = {}
endif
if !exists('g:vimshell_interactive_no_echoback_commands')
  " Note: MinGW gosh and scala is no echoback. Why?
  if has('win32') || has('win64')
    let g:vimshell_interactive_no_echoback_commands = {
          \ 'gosh' : 1, 'python' : 1, 'scala' : 1, 'maxima' : 1,
          \ 'fsi' : 1, 'clj' : 1, 'gdb' : 1,
          \}
  else
    let g:vimshell_interactive_no_echoback_commands = {}
  endif
endif
if !exists('g:vimshell_terminal_cursor')
  let g:vimshell_terminal_cursor = 'i:block-Cursor/lCursor'
endif
if !exists('g:vimshell_terminal_commands')
  let g:vimshell_terminal_commands = {
        \ 'more' : 1, 'screen' : 1, 'tmux' : 1,
        \ 'vi' : 1, 'emacs' : 1, 'sl' : 1,
        \}
endif
if !exists('g:vimshell_interactive_monochrome_commands')
  let g:vimshell_interactive_monochrome_commands = {}
endif

" For Cygwin commands.
if !exists('g:vimshell_interactive_cygwin_commands')
  let g:vimshell_interactive_cygwin_commands = {}
endif
if !exists('g:vimshell_interactive_cygwin_path')
  let g:vimshell_interactive_cygwin_path = 'c:/cygwin/bin'
endif
if !exists('g:vimshell_interactive_cygwin_home')
  let g:vimshell_interactive_cygwin_home = ''
endif
"}}}

command! -nargs=? -complete=dir VimShell call vimshell#switch_shell(0, <q-args>)
command! -nargs=? -complete=dir VimShellCreate call vimshell#create_shell(0, <q-args>)
command! -nargs=? -complete=dir VimShellPop call s:vimshell_popup(<q-args>)
command! -nargs=? -complete=dir VimShellTab tabnew | call vimshell#create_shell(0, <q-args>)
command! -nargs=+ -complete=customlist,s:execute_completefunc VimShellExecute call s:vimshell_execute(<q-args>)
command! -nargs=* -complete=customlist,s:execute_completefunc VimShellInteractive call s:vimshell_interactive(<q-args>)
command! -nargs=+ -complete=customlist,s:execute_completefunc VimShellTerminal call s:vimshell_terminal(<q-args>)

" Plugin keymappings"{{{
nnoremap <silent> <Plug>(vimshell_split_switch)  :<C-u>call vimshell#switch_shell(1, '')<CR>
nnoremap <silent> <Plug>(vimshell_split_create)  :<C-u>call vimshell#create_shell(1, '')<CR>
nnoremap <silent> <Plug>(vimshell_switch)  :<C-u>call vimshell#switch_shell(0, '')<CR>
nnoremap <silent> <Plug>(vimshell_create)  :<C-u>call vimshell#create_shell(0, '')<CR>
"}}}

" Command functions:
function! s:execute_completefunc(lead, cmd, pos)"{{{
  silent! let keys = vimshell#complete#vimshell_execute_complete#completefunc(a:lead, a:cmd, a:pos)
  return keys
endfunction"}}}
function! s:vimshell_execute(args)"{{{
  let context = {
        \ 'has_head_spaces' : 0,
        \ 'is_interactive' : 0,
        \ 'is_single_command' : 1,
        \ 'fd' : { 'stdin' : '', 'stdout': '', 'stderr': ''},
        \}
  call vimshell#set_context(context)

  let args = vimproc#parser#split_args(a:args)

  call vimshell#execute_internal_command('bg', args, context)
endfunction"}}}
function! s:vimshell_interactive(args)"{{{
  if a:args == ''
    call vimshell#commands#iexe#init()

    " Search interpreter.
    if &filetype == '' || !has_key(g:vimshell_interactive_interpreter_commands, &filetype)
      echoerr 'Interpreter is not found.'
      return
    endif

    let command_line = g:vimshell_interactive_interpreter_commands[&filetype]
  else
    let command_line = a:args
  endif

  let args = vimproc#parser#split_args(command_line)

  let context = {
        \ 'has_head_spaces' : 0,
        \ 'is_interactive' : 0,
        \ 'is_single_command' : 1,
        \ 'fd' : { 'stdin' : '', 'stdout': '', 'stderr': ''},
        \}
  call vimshell#set_context(context)

  call vimshell#execute_internal_command('iexe', args, context)
endfunction"}}}
function! s:vimshell_terminal(args)"{{{
  let context = {
        \ 'has_head_spaces' : 0,
        \ 'is_interactive' : 0,
        \ 'is_single_command' : 1,
        \ 'fd' : { 'stdin' : '', 'stdout': '', 'stderr': ''},
        \}
  call vimshell#set_context(context)

  call vimshell#execute_internal_command('texe',
        \ vimproc#parser#split_args(a:args), context)
endfunction"}}}
function! s:vimshell_popup(args)"{{{
  if &filetype ==# 'vimshell'
    " Quit vimshell.
    hide
    return
  endif

  " Popup vimshell buffer.
  call vimshell#switch_shell(1, a:args)
endfunction"}}}

augroup vimshell
  " Detect vimshell rc file.
  autocmd BufNewFile,BufRead *.vimsh,.vimshrc set filetype=vimshrc
augroup END

let &cpo = s:save_cpo
unlet s:save_cpo

let g:loaded_vimshell = 1

" vim: foldmethod=marker
