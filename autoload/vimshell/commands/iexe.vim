"=============================================================================
" FILE: iexe.vim
" AUTHOR: Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 25 Jul 2010
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
  
  if len(a:commands) > 1
    call vimshell#error_line(a:context.fd, 'iexe: this command is not supported pipe.')
    return
  endif
  
  let l:commands = a:commands
  let [l:args, l:options] = vimshell#parser#getopt(l:commands[0].args, 
        \{ 'arg=' : ['--encoding']
        \})
  
  if empty(l:args)
    return
  endif

  if has_key(g:vimshell_interactive_cygwin_commands, fnamemodify(l:args[0], ':r'))
    " Use Cygwin pty.
    call insert(l:args, 'fakecygpty')
  endif

  let l:use_cygpty = vimshell#iswin() && l:args[0] =~ '^fakecygpty\%(\.exe\)\?$'
  if l:use_cygpty
    if !executable('fakecygpty')
      call vimshell#error_line(a:context.fd, 'iexe: "fakecygpty.exe" is required. Please install it.')
      return
    endif
    
    " Get program path from g:vimshell_interactive_cygwin_path.
    if len(l:args) < 2
      call vimshell#error_line(a:context.fd, 'iexe: command is required.')
      return
    endif

    let l:args[1] = vimproc#get_command_name(l:args[1], g:vimshell_interactive_cygwin_path)
  endif

  let l:cmdname = fnamemodify(l:args[0], ':r')
  if !has_key(l:options, '--encoding')
    let l:options['--encoding'] = has_key(g:vimshell_interactive_encodings, l:cmdname) ?
          \ g:vimshell_interactive_encodings[l:cmdname] : &termencoding
  endif

  if !l:use_cygpty && has_key(g:vimshell_interactive_command_options, l:cmdname)
    for l:arg in vimshell#parser#split_args(g:vimshell_interactive_command_options[l:cmdname])
      call add(l:args, l:arg)
    endfor
  endif

  if vimshell#iswin() && l:cmdname == 'cmd'
    " Run cmdproxy.exe instead of cmd.exe.
    if !executable('cmdproxy.exe')
      call vimshell#error_line(a:context.fd, 'iexe: "cmdproxy.exe" is not found. Please install it.')
      return
    endif

    let l:args[0] = 'cmdproxy.exe'
  endif
  
  " Encoding conversion.
  if l:options['--encoding'] != '' && l:options['--encoding'] != &encoding
    for l:command in l:commands
      call map(l:command.args, 'iconv(v:val, &encoding, l:options["--encoding"])')
    endfor
  endif

  if exists('b:interactive') && !empty(b:interactive.process) && b:interactive.process.is_valid
    " Delete zombee process.
    call vimshell#interactive#force_exit()
  endif

  " Initialize.
  if l:use_cygpty
    if g:vimshell_interactive_cygwin_home != ''
      " Set $HOME.
      let l:home_save = $HOME
      let $HOME = g:vimshell_interactive_cygwin_home
    endif
  endif

  call s:init_bg(l:args, a:context)
  
  let l:sub = vimproc#ptyopen(l:args)

  if l:use_cygpty
    if g:vimshell_interactive_cygwin_home != ''
      " Restore $HOME.
      let $HOME = l:home_save
    endif
  endif

  " Set variables.
  let b:interactive = {
        \ 'type' : 'interactive', 
        \ 'process' : l:sub, 
        \ 'fd' : a:context.fd, 
        \ 'encoding' : l:options['--encoding'],
        \ 'is_secret': 0, 
        \ 'prompt_history' : {}, 
        \ 'command_history' : vimshell#history#interactive_read(), 
        \ 'is_pty' : (!vimshell#iswin() || l:use_cygpty),
        \ 'args' : l:args,
        \ 'echoback_linenr' : 0,
        \ 'stdout_cache' : '',
        \}

  call vimshell#interactive#execute_pty_out(1)

  if !has_key(a:context, 'is_from_command') || !a:context.is_from_command
    wincmd p
  elseif b:interactive.process.is_valid
    startinsert!
  endif
endfunction"}}}
function! s:command.complete(args)"{{{
  return vimshell#iswin() && len(a:args) > 1 && a:args[1] == 'fakecygpty' ?
        \ vimshell#complete#helper#executables(a:args[-1], g:vimshell_interactive_cygwin_path) : 
        \ vimshell#complete#helper#executables(a:args[-1])
endfunction"}}}

function! vimshell#commands#iexe#define()
  return s:command
endfunction

" Dummy.
function! vimshell#commands#iexe#init()
endfunction

" Set interactive options."{{{
if vimshell#iswin()
  " Windows only options.
  call vimshell#set_dictionary_helper(g:vimshell_interactive_command_options, 'bash,bc,gosh,python,zsh', '-i')
  call vimshell#set_dictionary_helper(g:vimshell_interactive_command_options, 'irb', '--inf-ruby-mode')
  call vimshell#set_dictionary_helper(g:vimshell_interactive_command_options, 'powershell', '-Command -')
  call vimshell#set_dictionary_helper(g:vimshell_interactive_command_options, 'scala', '--Xnojline')
  call vimshell#set_dictionary_helper(g:vimshell_interactive_command_options, 'nyaos', '-t')
  
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
call vimshell#set_dictionary_helper(g:vimshell_interactive_interpreter_commands, 'scala', 'cmdproxy')
call vimshell#set_dictionary_helper(g:vimshell_interactive_interpreter_commands, 'ocaml', 'ocaml')
call vimshell#set_dictionary_helper(g:vimshell_interactive_interpreter_commands, 'sml', 'sml')
call vimshell#set_dictionary_helper(g:vimshell_interactive_interpreter_commands, 'javascript', 'js')
"}}}

function! s:default_settings()"{{{
  " Set environment variables.
  let $TERM = g:vimshell_environment_term
  let $TERMCAP = 'COLUMNS=' . winwidth(0)
  let $VIMSHELL = 1
  let $COLUMNS = winwidth(0)-5
  let $LINES = winheight(0)
  let $VIMSHELL_TERM = 'interactive'
  let $EDITOR = g:vimshell_cat_command
  let $PAGER = g:vimshell_cat_command


  setlocal buftype=nofile
  setlocal noswapfile
  setlocal wrap
  setlocal nolist
  setlocal tabstop=8
  setlocal omnifunc=vimshell#complete#interactive_history_complete#omnifunc

  " Set syntax.
  syn region   InteractiveError   start=+!!!+ end=+!!!+ contains=InteractiveErrorHidden oneline
  syn match   InteractiveErrorHidden            '!!!' contained
  hi def link InteractiveError Error
  hi def link InteractiveErrorHidden Ignore

  " Define mappings.
  call vimshell#int_mappings#define_default_mappings()
endfunction"}}}

function! s:init_bg(args, context)"{{{
  " Save current directiory.
  let l:cwd = getcwd()

  if !has_key(a:context, 'is_split') || a:context.is_split
    " Split nicely.
    call vimshell#split_nicely()
  endif

  edit `=fnamemodify(a:args[0], ':r').'@'.(bufnr('$')+1)`
  lcd `=l:cwd`
  
  call s:default_settings()
  
  let l:use_cygpty = vimshell#iswin() && a:args[0] =~ '^fakecygpty\%(\.exe\)\?$'
  execute 'set filetype=int-'.fnamemodify(l:use_cygpty ? a:args[1] : a:args[0], ':t:r')

  " Set autocommands.
  augroup vimshell
    autocmd InsertEnter <buffer>       call s:insert_enter()
    autocmd InsertLeave <buffer>       call s:insert_leave()
    autocmd BufUnload <buffer>       call vimshell#interactive#hang_up(expand('<afile>'))
    autocmd CursorHoldI <buffer>     call vimshell#interactive#check_insert_output()
    autocmd CursorMovedI <buffer>    call vimshell#interactive#check_moved_output()
  augroup END

  " Set send buffer.
  call vimshell#interactive#set_send_buffer(bufnr('%'))
endfunction"}}}

function! s:insert_enter()"{{{
  if &updatetime > g:vimshell_interactive_update_time
    let s:update_time_save = &updatetime
    let &updatetime = g:vimshell_interactive_update_time
  endif
endfunction"}}}
function! s:insert_leave()"{{{
  if &updatetime < s:update_time_save
    let &updatetime = s:update_time_save
  endif
endfunction"}}}
