"=============================================================================
" FILE: iexe.vim
" AUTHOR: Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 19 Sep 2011.
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

let s:update_time_save = &updatetime

let s:command = {
      \ 'name' : 'iexe',
      \ 'kind' : 'execute',
      \ 'description' : 'iexe [{options}...] {command}',
      \}
function! s:command.execute(commands, context)"{{{
  " Interactive execute command.

  let commands = a:commands
  let [commands[0].args, options] = vimshell#parser#getopt(commands[0].args, {
        \ 'arg=' : ['--encoding', '--split'],
        \ }, {
        \ '--split' : g:vimshell_split_command,
        \ })

  let args = commands[0].args

  if empty(args)
    return
  endif

  if has_key(g:vimshell_interactive_cygwin_commands, fnamemodify(args[0], ':r'))
    " Use Cygwin pty.
    call insert(args, 'fakecygpty')
  endif

  let use_cygpty = vimshell#iswin() && args[0] =~ '^fakecygpty\%(\.exe\)\?$'
  if use_cygpty
    if !executable('fakecygpty')
      call vimshell#error_line(a:context.fd, 'iexe: "fakecygpty.exe" is required. Please install it.')
      return
    endif

    " Get program path from g:vimshell_interactive_cygwin_path.
    if len(args) < 2
      call vimshell#error_line(a:context.fd, 'iexe: command is required.')
      return
    endif

    let args[1] = vimproc#get_command_name(args[1], g:vimshell_interactive_cygwin_path)
  endif

  let cmdname = fnamemodify(args[0], ':r')
  if !has_key(options, '--encoding')
    let options['--encoding'] = has_key(g:vimshell_interactive_encodings, cmdname) ?
          \ g:vimshell_interactive_encodings[cmdname] : &termencoding
  endif

  if !use_cygpty && has_key(g:vimshell_interactive_command_options, cmdname)
    for arg in vimproc#parser#split_args(g:vimshell_interactive_command_options[cmdname])
      call add(args, arg)
    endfor
  endif

  if vimshell#iswin() && cmdname == 'cmd'
    " Run cmdproxy.exe instead of cmd.exe.
    if !executable('cmdproxy.exe')
      call vimshell#error_line(a:context.fd, 'iexe: "cmdproxy.exe" is not found. Please install it.')
      return
    endif

    let args[0] = 'cmdproxy.exe'
  endif

  " Encoding conversion.
  if options['--encoding'] != '' && options['--encoding'] != &encoding
    for command in commands
      call map(command.args, 'iconv(v:val, &encoding, options["--encoding"])')
    endfor
  endif

  if exists('b:interactive') && !empty(b:interactive.process) && b:interactive.process.is_valid
    " Delete zombie process.
    call vimshell#interactive#force_exit()
  endif

  " Initialize.
  if use_cygpty && g:vimshell_interactive_cygwin_home != ''
    " Set $HOME.
    let home_save = vimshell#set_variables({
          \ '$HOME' : g:vimshell_interactive_cygwin_home,
          \})
  endif

  let [new_pos, old_pos] = vimshell#split(options['--split'])

  " Set environment variables.
  let environments_save = vimshell#set_variables({
        \ '$TERM' : g:vimshell_environment_term,
        \ '$TERMCAP' : 'COLUMNS=' . winwidth(0)-5,
        \ '$VIMSHELL' : 1,
        \ '$COLUMNS' : winwidth(0)-5,
        \ '$LINES' : winheight(0),
        \ '$VIMSHELL_TERM' : 'interactive',
        \ '$EDITOR' : g:vimshell_cat_command,
        \ '$PAGER' : g:vimshell_cat_command,
        \})

  " Initialize.
  let sub = vimproc#ptyopen(commands)

  " Restore environment variables.
  call vimshell#restore_variables(environments_save)

  if use_cygpty && g:vimshell_interactive_cygwin_home != ''
    " Restore $HOME.
    call vimshell#restore_variables(home_save)
  endif

  " Set variables.
  let interactive = {
        \ 'type' : 'interactive',
        \ 'process' : sub,
        \ 'fd' : a:context.fd,
        \ 'encoding' : options['--encoding'],
        \ 'is_secret': 0,
        \ 'prompt_history' : {},
        \ 'is_pty' : (!vimshell#iswin() || use_cygpty),
        \ 'args' : args,
        \ 'echoback_linenr' : 0,
        \ 'width' : winwidth(0),
        \ 'height' : winheight(0),
        \ 'stdout_cache' : '',
        \ 'stderr_cache' : '',
        \ 'command' : fnamemodify(use_cygpty ? args[1] : args[0], ':t:r'),
        \ 'is_close_immediately' : has_key(a:context, 'is_close_immediately')
        \    && a:context.is_close_immediately,
        \ 'hook_functions_table' : {},
        \}

  call vimshell#commands#iexe#init(a:context, interactive,
        \ new_pos, old_pos, 1)

  call vimshell#interactive#execute_process_out(1)

  if b:interactive.process.is_valid
    startinsert!
  endif
endfunction"}}}
function! s:command.complete(args)"{{{
  if len(a:args) == 1
    return vimshell#complete#helper#executables(a:args[-1])
  elseif vimshell#iswin() && len(a:args) > 1 && a:args[1] == 'fakecygpty'
    return vimshell#complete#helper#executables(a:args[-1], g:vimshell_interactive_cygwin_path) :
  endif

  return []
endfunction"}}}

function! vimshell#commands#iexe#define()
  return s:command
endfunction

" Set interactive options."{{{
if vimshell#iswin()
  " Windows only options.
  call vimshell#set_dictionary_helper(g:vimshell_interactive_command_options, 'bash,bc,gosh,python,zsh', '-i')
  call vimshell#set_dictionary_helper(g:vimshell_interactive_command_options, 'irb', '--inf-ruby-mode')
  call vimshell#set_dictionary_helper(g:vimshell_interactive_command_options, 'powershell', '-Command -')
  call vimshell#set_dictionary_helper(g:vimshell_interactive_command_options, 'scala', '-Xnojline')
  call vimshell#set_dictionary_helper(g:vimshell_interactive_command_options, 'nyaos', '-t')
  call vimshell#set_dictionary_helper(g:vimshell_interactive_command_options, 'fsi', '--gui- --readline-')
  call vimshell#set_dictionary_helper(g:vimshell_interactive_command_options, 'sbt', '-Djline.WindowsTerminal.directConsole=false')

  call vimshell#set_dictionary_helper(g:vimshell_interactive_encodings, 'gosh,fakecygpty', 'utf8')

  call vimshell#set_dictionary_helper(g:vimshell_interactive_cygwin_commands, 'tail,zsh,ssh', 1)
endif
call vimshell#set_dictionary_helper(g:vimshell_interactive_command_options, 'termtter', '--monochrome')

" Set interpreter commands.
call vimshell#set_dictionary_helper(g:vimshell_interactive_interpreter_commands, 'ruby', 'irb')
call vimshell#set_dictionary_helper(g:vimshell_interactive_interpreter_commands, 'python', 'python')
call vimshell#set_dictionary_helper(g:vimshell_interactive_interpreter_commands, 'perl', 'perlsh')
call vimshell#set_dictionary_helper(g:vimshell_interactive_interpreter_commands, 'perl6', 'perl6')
call vimshell#set_dictionary_helper(g:vimshell_interactive_interpreter_commands, 'sh', 'sh')
call vimshell#set_dictionary_helper(g:vimshell_interactive_interpreter_commands, 'zsh', 'zsh')
call vimshell#set_dictionary_helper(g:vimshell_interactive_interpreter_commands, 'bash', 'bash')
call vimshell#set_dictionary_helper(g:vimshell_interactive_interpreter_commands, 'erlang', 'erl')
call vimshell#set_dictionary_helper(g:vimshell_interactive_interpreter_commands, 'scheme', 'gosh')
call vimshell#set_dictionary_helper(g:vimshell_interactive_interpreter_commands, 'clojure', 'clj')
call vimshell#set_dictionary_helper(g:vimshell_interactive_interpreter_commands, 'lisp', 'clisp')
call vimshell#set_dictionary_helper(g:vimshell_interactive_interpreter_commands, 'ps1', 'powershell')
call vimshell#set_dictionary_helper(g:vimshell_interactive_interpreter_commands, 'haskell', 'ghci')
call vimshell#set_dictionary_helper(g:vimshell_interactive_interpreter_commands, 'dosbatch', 'cmdproxy')
call vimshell#set_dictionary_helper(g:vimshell_interactive_interpreter_commands, 'scala', vimshell#iswin() ? 'scala.bat' : 'scala')
call vimshell#set_dictionary_helper(g:vimshell_interactive_interpreter_commands, 'ocaml', 'ocaml')
call vimshell#set_dictionary_helper(g:vimshell_interactive_interpreter_commands, 'sml', 'sml')
call vimshell#set_dictionary_helper(g:vimshell_interactive_interpreter_commands, 'javascript', 'js')
call vimshell#set_dictionary_helper(g:vimshell_interactive_prompts, 'termtter', '> ')
call vimshell#set_dictionary_helper(g:vimshell_interactive_monochrome_commands, 'earthquake', '1')
"}}}

function! s:default_settings()"{{{
  " Common.
  setlocal nocompatible
  setlocal nolist
  setlocal modifiable
  setlocal buftype=nofile
  setlocal noswapfile
  setlocal tabstop=8
  setlocal foldcolumn=0
  setlocal foldmethod=manual
  if has('conceal')
    setlocal conceallevel=3
    setlocal concealcursor=nvi
  endif

  " For interactive.
  setlocal wrap
  setlocal omnifunc=vimshell#complete#interactive_history_complete#omnifunc

  " Define mappings.
  call vimshell#int_mappings#define_default_mappings()
endfunction"}}}

function! s:default_syntax()"{{{
  " Set syntax.
  syn region   InteractiveError   start=+!!!+ end=+!!!+ contains=InteractiveErrorHidden oneline
  hi def link InteractiveError Error

  if has('conceal')
    " Supported conceal features.
    syn match   InteractiveErrorHidden            '!!!' contained conceal
  else
    syn match   InteractiveErrorHidden            '!!!' contained
    hi def link InteractiveErrorHidden Ignore
  endif
endfunction"}}}

function! vimshell#commands#iexe#init(context, interactive, new_pos, old_pos, is_insert)"{{{
  " Save current directiory.
  let cwd = getcwd()

  edit `='iexe-'.substitute(join(a:interactive.args),
        \ '[<>|]', '_', 'g').'@'.(bufnr('$')+1)`
  let [a:new_pos[2], a:new_pos[3]] = [bufnr('%'), getpos('.')]

  call vimshell#cd(cwd)

  let b:interactive = a:interactive

  call s:default_settings()

  let syntax = 'int-' . a:interactive.command
  let &filetype = syntax
  let b:interactive.syntax = syntax

  call s:default_syntax()

  " Set autocommands.
  augroup vimshell
    autocmd InsertEnter <buffer>       call s:insert_enter()
    autocmd InsertLeave <buffer>       call s:insert_leave()
    autocmd BufDelete <buffer>       call vimshell#interactive#hang_up(expand('<afile>'))
    autocmd CursorHoldI <buffer>     call vimshell#interactive#check_insert_output()
    autocmd CursorMovedI <buffer>    call vimshell#interactive#check_moved_output()
    autocmd BufWinEnter,WinEnter <buffer> call s:event_bufwin_enter()
  augroup END

  " Set send buffer.
  call vimshell#interactive#set_send_buffer(bufnr('%'))

  let bufnr = bufnr('%')
  call vimshell#restore_pos(a:old_pos)

  if has_key(a:context, 'is_single_command') && a:context.is_single_command
    call vimshell#next_prompt(a:context, a:is_insert)
    call vimshell#restore_pos(a:new_pos)
  endif
endfunction"}}}

function! s:insert_enter()"{{{
  if &updatetime > g:vimshell_interactive_update_time
    let s:update_time_save = &updatetime
    let &updatetime = g:vimshell_interactive_update_time
  endif

  if winwidth(0) != b:interactive.width || winheight(0) != b:interactive.height
    " Set new window size.
    call b:interactive.process.set_winsize(winwidth(0), winheight(0))
  endif
endfunction"}}}
function! s:insert_leave()"{{{
  if &updatetime < s:update_time_save
    let &updatetime = s:update_time_save
  endif
endfunction"}}}
function! s:event_bufwin_enter()"{{{
  if has('conceal')
    setlocal conceallevel=3
    setlocal concealcursor=nvi
  endif
endfunction"}}}

" vim: foldmethod=marker
