"=============================================================================
" FILE: iexe.vim
" AUTHOR: Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 16 Apr 2010
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

  call s:init_bg(l:sub, l:args, a:fd, a:other_info)

  " Set variables.
  let b:interactive = {
        \ 'process' : l:sub, 
        \ 'fd' : a:fd, 
        \ 'encoding' : l:options['--encoding'],
        \ 'is_secret': 0, 
        \ 'prompt_history' : {}, 
        \ 'command_history' : [], 
        \ 'is_pty' : (!vimshell#iswin() || (l:args[0] == 'fakecygpty')),
        \ 'is_background': 0, 
        \ 'cached_output' : '', 
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
  call vimshell#internal#iexe#execute('iexe', vimshell#parser#split_args(a:args), {'stdin' : '', 'stdout' : '', 'stderr' : ''}, {'is_interactive' : 0})
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
  inoremap <buffer><expr> <Plug>(vimshell_interactive_dummy_enter) pumvisible()? "\<C-y>\<CR>\<BS>" : "\<CR>\<BS>"

  imap <buffer><C-h>     <Plug>(vimshell_interactive_delete_backword_char)
  imap <buffer><BS>     <Plug>(vimshell_interactive_delete_backword_char)
  imap <buffer><expr><TAB>   pumvisible() ? "\<C-n>" : vimshell#complete#interactive_command_complete#complete()
  imap <buffer><C-a>     <Plug>(vimshell_interactive_move_head)
  imap <buffer><C-u>     <Plug>(vimshell_interactive_delete_line)
  imap <buffer><C-e>     <Plug>(vimshell_interactive_close_popup)
  inoremap <expr> <SID>(bs-ctrl-])    getline('.')[-1:] ==# "\<C-]>" ? "\<BS>" : ''
  imap <buffer> <C-]>               <C-]><SID>(bs-ctrl-])
  imap <buffer><CR>      <C-]><Plug>(vimshell_interactive_execute_line)
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

function! s:init_bg(sub, args, fd, other_info)"{{{
  " Save current directiory.
  let l:cwd = getcwd()

  " Init buffer.
  if a:other_info.is_interactive
    let l:context = a:other_info
    let l:context.fd = a:fd
    call vimshell#print_prompt(l:context)
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
  let l:cur_text = vimshell#interactive#get_cur_text()
  if l:cur_text != '' && l:cur_text !~# '*\%(Killed\|Exit\)*'
    return
  endif
  
  call vimshell#interactive#check_output(b:interactive, bufnr('%'), bufnr('%'))

  if !b:interactive.process.is_valid
    stopinsert
  else
    call feedkeys("\<C-r>\<ESC>", 'n')

    if pumvisible()
      call feedkeys("\<C-y>", 'n')
    endif
  endif
endfunction

function! s:on_hold()
  call vimshell#interactive#check_output(b:interactive, bufnr('%'), bufnr('%'))

  if b:interactive.process.is_valid
    call feedkeys("g\<ESC>", 'n')
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
        \ 'termtter'   : '--monochrome', 
        \ 'scala'   : '--Xnojline', 'nyaos' : '-t',
        \}
else
  let s:interactive_option = {
        \'termtter' : '--monochrome', 
        \}
endif

