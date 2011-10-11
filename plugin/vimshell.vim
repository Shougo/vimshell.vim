"=============================================================================
" FILE: vimshell.vim
" AUTHOR: Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 11 Oct 2011.
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

if v:version < 702
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
let g:vimshell_ignore_case =
      \ get(g:, 'vimshell_ignore_case', &ignorecase)
let g:vimshell_smart_case =
      \ get(g:, 'vimshell_smart_case', &smartcase)
let g:vimshell_max_list =
      \ get(g:, 'vimshell_max_list', 100)
let g:vimshell_use_terminal_command =
      \ get(g:, 'vimshell_use_terminal_command', '')
let g:vimshell_split_height =
      \ get(g:, 'vimshell_split_height', 30)
let g:vimshell_temporary_directory =
      \ get(g:, 'vimshell_temporary_directory', expand('~/.vimshell'))
if !isdirectory(fnamemodify(g:vimshell_temporary_directory, ':p'))
  call mkdir(fnamemodify(g:vimshell_temporary_directory, ':p'), 'p')
endif
let g:vimshell_max_command_history =
      \ get(g:, 'vimshell_max_command_history', 1000)
let g:vimshell_max_directory_stack =
      \ get(g:, 'vimshell_max_directory_stack', 100)
let g:vimshell_vimshrc_path =
      \ get(g:, 'vimshell_vimshrc_path', expand('~/.vimshrc'))
if !isdirectory(fnamemodify(g:vimshell_vimshrc_path, ':p:h'))
  call mkdir(fnamemodify(g:vimshell_vimshrc_path, ':p:h'), 'p')
endif
let g:vimshell_escape_colors =
      \ get(g:, 'vimshell_escape_colors', [
        \ '#6c6c6c', '#ff6666', '#66ff66', '#ffd30a',
        \ '#1e95fd', '#ff13ff', '#1bc8c8', '#C0C0C0',
        \ '#383838', '#ff4444', '#44ff44', '#ffb30a',
        \ '#6699ff', '#f820ff', '#4ae2e2', '#ffffff',
        \])
let g:vimshell_disable_escape_highlight =
      \ get(g:, 'vimshell_disable_escape_highlight', 0)
let g:vimshell_cat_command =
      \ get(g:, 'vimshell_cat_command', 'cat')
let g:vimshell_environment_term =
      \ get(g:, 'vimshell_environment_term', 'vt100')
let g:vimshell_split_command =
      \ get(g:, 'vimshell_split_command', 'nicely')
let g:vimshell_cd_command =
      \ get(g:, 'vimshell_cd_command', 'lcd')
let g:vimshell_external_history_path =
      \ get(g:, 'vimshell_external_history_path', '')
let g:vimshell_no_save_history_commands =
      \ get(g:, 'vimshell_no_save_history_commands', {
      \     'history' : 1, 'h' : 1, 'histdel' : 1
      \ })
let g:vimshell_scrollback_limit =
      \ get(g:, 'vimshell_scrollback_limit', 1000)

" For interactive commands.
let g:vimshell_interactive_no_save_history_commands =
      \ get(g:, 'vimshell_no_save_history_commands', {})
let g:vimshell_interactive_update_time =
      \ get(g:, 'vimshell_update_time', 500)
let g:vimshell_interactive_command_options =
      \ get(g:, 'vimshell_command_options', {})
let g:vimshell_interactive_interpreter_commands =
      \ get(g:, 'vimshell_interpreter_commands', {})
let g:vimshell_interactive_encodings =
      \ get(g:, 'vimshell_interactive_encodings', {})
let g:vimshell_interactive_prompts =
      \ get(g:, 'vimshell_interactive_prompts', {})
let g:vimshell_interactive_echoback_commands =
      \ get(g:, 'vimshell_interactive_echoback_commands',
      \ (has('win32') || has('win64')) ? {
      \   'bash' : 1, 'bc' : 1,
      \   } : {})
let g:vimshell_interactive_monochrome_commands =
      \ get(g:, 'vimshell_interactive_monochrome_commands', {})

" For terminal commands.
let g:vimshell_terminal_cursor =
      \ get(g:, 'vimshell_terminal_cursor', 'i:block-Cursor/lCursor')
let g:vimshell_terminal_commands =
      \ get(g:, 'vimshell_terminal_commands', {
      \     'more' : 1, 'screen' : 1, 'tmux' : 1,
      \     'vi' : 1, 'emacs' : 1, 'sl' : 1,
      \ })

" For Cygwin commands.
let g:vimshell_interactive_cygwin_commands =
      \ get(g:, 'vimshell_interactive_cygwin_commands', {})
let g:vimshell_interactive_cygwin_path =
      \ get(g:, 'vimshell_interactive_cygwin_path', 'c:/cygwin/bin')
let g:vimshell_interactive_cygwin_home =
      \ get(g:, 'vimshell_interactive_cygwin_home', '')
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
