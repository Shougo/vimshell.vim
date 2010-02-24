"=============================================================================
" FILE: iexe.vim
" AUTHOR: Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 24 Feb 2010
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
" Version: 1.23, for Vim 7.0
"-----------------------------------------------------------------------------
" ChangeLog: "{{{
"   1.23: 
"     - Supported vimproc Ver.3.
"     - Fixed interactive filetype.
"
"   1.22: 
"     - Reimplemented vimshell#internal#iexe#vimshell_iexe().
"     - Improved keymappings.
"     - Implemented CursorHold event.
"     - Fixed update timing.
"     - Fixed no prompt behavior bug.
"     - Fixed interactive option bug.
"     - Improved prompt. 
"     - Improved syntax.
"     - Supported encoding.
"
"   1.21: 
"     - Implemented auto update.
"     - Splited mappings functions.
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
  let [l:args, l:options] = vimshell#parser#getopt(a:args, 
        \{ 'arg=' : ['--encoding']
        \})
  if !has_key(l:options, '--encoding')
    let l:options['--encoding'] = &termencoding
  endif
  
  if !g:VimShell_EnableInteractive
    if has('gui_running')
      " Error.
      call vimshell#error_line(a:fd, 'Must use vimproc plugin.')
      return 0
    else
      " Use sexe.
      return vimshell#internal#sexe#execute('sexe', l:args, a:fd, a:other_info)
    endif
  endif

  if empty(l:args)
    return 0
  endif

  let l:args = l:args
  if has_key(s:interactive_option, fnamemodify(l:args[0], ':r'))
    for l:arg in vimshell#parser#split_args(s:interactive_option[fnamemodify(l:args[0], ':r')])
      call add(l:args, l:arg)
    endfor
  endif

  if vimshell#iswin() && l:args[0] =~ 'cmd\%(\.exe\)\?'
    " Run cmdproxy.exe instead of cmd.exe.
    if !executable('cmdproxy.exe')
      call vimshell#error_line(a:fd, 'cmdproxy.exe is not found. Please install it.')
      return 0
    endif

    let l:args[0] = 'cmdproxy.exe'
  endif

  " Initialize.
  try
    let l:sub = vimproc#ptyopen(join(l:args))
  catch 'list index out of range'
    let l:error = printf('File: "%s" is not found.', l:args[0])

    call vimshell#error_line(a:fd, l:error)

    return 0
  endtry

  if exists('b:interactive') && b:interactive.process.is_valid
    " Delete zombee process.
    call vimshell#interactive#force_exit()
  endif

  call s:init_bg(l:sub, l:args, a:other_info.is_interactive)

  " Set variables.
  let b:interactive = {
        \ 'process' : l:sub, 
        \ 'fd' : a:fd, 
        \ 'encoding' : l:options['--encoding'],
        \ 'is_secret': 0, 
        \ 'prompt_history' : {}, 
        \ 'command_history' : []
        \}

  " Input from stdin.
  if b:interactive.fd.stdin != ''
    call b:interactive.process.write(vimshell#read(a:fd))
  endif

  call vimshell#interactive#execute_pty_out(1)
  if getline(line('$')) =~ '^\s*$'
    let b:interactive.prompt_history[line('$')] = ''
    call setline(line('$'), '...')
  endif

  startinsert!

  return 1
endfunction"}}}

function! vimshell#internal#iexe#vimshell_iexe(args)"{{{
  call vimshell#internal#iexe#execute('iexe', vimshell#parser#split_args(a:args), {'stdin' : '', 'stdout' : '', 'stderr' : ''}, {'is_interactive' : 0, 'is_background' : 1})
endfunction"}}}

function! vimshell#internal#iexe#default_settings()"{{{
  setlocal buftype=nofile
  setlocal noswapfile
  setlocal wrap
  setlocal tabstop=8

  " Set syntax.
  syn region   InteractiveError   start=+!!!+ end=+!!!+ contains=InteractiveErrorHidden oneline
  syn match   InteractiveErrorHidden            '!!!' contained
  syn match   InteractivePrompt         '^->\s\|^\.\.\.$'
  syn match   InteractiveMessage   '\*\%(Exit\|Killed\)\*'
  
  hi def link InteractiveMessage WarningMsg
  hi def link InteractiveError Error
  hi def link InteractiveErrorHidden Ignore
  if has('gui_running')
    hi InteractivePrompt  gui=UNDERLINE guifg=#80ffff guibg=NONE
  else
    hi def link InteractivePrompt Identifier
  endif

  " Plugin key-mappings.
  inoremap <buffer><silent><expr> <Plug>(vimshell_interactive_delete_backword_char)  vimshell#int_mappings#delete_backword_char()
  inoremap <buffer><silent> <Plug>(vimshell_interactive_previous_history)  <ESC>:<C-u>call vimshell#int_mappings#previous_command()<CR>
  inoremap <buffer><silent> <Plug>(vimshell_interactive_next_history)  <ESC>:<C-u>call vimshell#int_mappings#next_command()<CR>
  inoremap <buffer><silent> <Plug>(vimshell_interactive_move_head)  <ESC>:<C-u>call vimshell#int_mappings#move_head()<CR>
  inoremap <buffer><silent> <Plug>(vimshell_interactive_delete_line)  <ESC>:<C-u>call vimshell#int_mappings#delete_line()<CR>
  inoremap <buffer><expr> <Plug>(vimshell_interactive_close_popup)  vimshell#int_mappings#close_popup()
  inoremap <buffer><silent> <Plug>(vimshell_interactive_execute_line)       <ESC>:<C-u>call vimshell#int_mappings#execute_line(1)<CR>
  inoremap <buffer><silent> <Plug>(vimshell_interactive_interrupt)       <C-o>:<C-u>call vimshell#interactive#interrupt()<CR>

  imap <buffer><C-h>     <Plug>(vimshell_interactive_delete_backword_char)
  imap <buffer><BS>     <Plug>(vimshell_interactive_delete_backword_char)
  imap <buffer><expr><TAB>   pumvisible() ? "\<C-n>" : vimshell#complete#interactive_command_complete#complete()
  imap <buffer><C-a>     <Plug>(vimshell_interactive_move_head)
  imap <buffer><C-u>     <Plug>(vimshell_interactive_delete_line)
  imap <buffer><C-e>     <Plug>(vimshell_interactive_close_popup)
  imap <buffer><CR>      <Plug>(vimshell_interactive_execute_line)
  imap <buffer><C-c>     <Plug>(vimshell_interactive_interrupt)

  nnoremap <buffer><silent> <Plug>(vimshell_interactive_previous_prompt)  :<C-u>call vimshell#int_mappings#previous_prompt()<CR>
  nnoremap <buffer><silent> <Plug>(vimshell_interactive_next_prompt)  :<C-u>call vimshell#int_mappings#next_prompt()<CR>
  nnoremap <buffer><silent> <Plug>(vimshell_interactive_execute_line)  :<C-u>call vimshell#int_mappings#execute_line(0)<CR><ESC>
  nnoremap <buffer><silent> <Plug>(vimshell_interactive_paste_prompt)  :<C-u>call vimshell#int_mappings#paste_prompt()<CR>
  nnoremap <buffer><silent> <Plug>(vimshell_interactive_interrupt)       :<C-u>call <SID>on_exit()<CR>

  nmap <buffer><C-p>     <Plug>(vimshell_interactive_previous_prompt)
  nmap <buffer><C-n>     <Plug>(vimshell_interactive_next_prompt)
  nmap <buffer><CR>      <Plug>(vimshell_interactive_execute_line)
  nmap <buffer><C-y>     <Plug>(vimshell_interactive_paste_prompt)
  nmap <buffer><C-c>     <Plug>(vimshell_interactive_interrupt)

  augroup vimshell_iexe
    autocmd BufUnload <buffer>   call s:on_exit()
    autocmd CursorMovedI <buffer>  call s:on_moved()
    autocmd CursorHoldI <buffer>  call s:on_hold_i()
    autocmd CursorHold <buffer>  call s:on_hold()
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
  call vimshell#split_nicely()

  edit `=fnamemodify(a:args[0], ':r').'@'.(bufnr('$')+1)`
  lcd `=l:cwd`
  execute 'setfiletype' 'int-'.fnamemodify(a:args[0], ':r')

  call vimshell#internal#iexe#default_settings()

  $

  startinsert!
endfunction"}}}

function! s:on_insert_enter()
  let s:save_updatetime = &updatetime
  let &updatetime = 700
endfunction

function! s:on_insert_leave()
  let &updatetime = s:save_updatetime
endfunction

function! s:on_hold_i()
  call vimshell#interactive#execute_pty_out(1)

  if !b:interactive.process.is_valid
    stopinsert
  else
    call feedkeys("\<C-l>\<BS>", 'n')

    if pumvisible()
      call feedkeys("\<C-y>", 'n')
    endif
  endif
endfunction

function! s:on_hold()
  call vimshell#interactive#execute_pty_out(0)

  if b:interactive.process.is_valid
    normal! hl
  endif
endfunction

function! s:on_moved()
  let l:line = getline('.')
  if l:line =~ '^\.\.\.\.\?[^.]\+$\|^$'
    " Set prompt.
    call setline('.', '-> ' . l:line[len(matchstr(l:line, '^\.\.\.\.\?')) :])
    startinsert!
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
        \ 'gosh' : '-i', 'python' : '-i', 'zsh' : '-i', 
        \ 'powershell' : '-Command -', 
        \ 'termtter'   : '--monochrome'
        \}
else
  let s:interactive_option = {
        \'termtter' : '--monochrome'
        \}
endif

