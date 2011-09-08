"=============================================================================
" FILE: texe.vim
" AUTHOR: Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 08 Sep 2011.
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

let s:command = {
      \ 'name' : 'texe',
      \ 'kind' : 'execute',
      \ 'description' : 'texe [{options}...] {command}',
      \}
function! s:command.execute(commands, context)"{{{
  " Interactive execute command.
  if len(a:commands) > 1
    call vimshell#error_line(a:context.fd, 'iexe: this command is not supported pipe.')
    return
  endif

  let l:commands = a:commands
  let [l:commands[0].args, l:options] = vimshell#parser#getopt(l:commands[0].args, 
        \{ 'arg=' : ['--encoding']
        \})
  let l:args = l:commands[0].args

  if empty(l:args)
    return
  endif

  if vimshell#iswin()
    " Use Cygwin pty.
    call insert(l:args, 'fakecygpty')

    if !executable('fakecygpty')
      call vimshell#error_line(a:context.fd, 'texe: "fakecygpty.exe" is required. Please install it.')
      return
    endif

    if len(l:args) < 2
      call vimshell#error_line(a:context.fd, 'texe: command is required.')
      return
    endif

    " Get program path from g:vimshell_interactive_cygwin_path.
    let l:args[1] = vimproc#get_command_name(l:args[1], g:vimshell_interactive_cygwin_path)
  endif

  let l:cmdname = fnamemodify(l:args[0], ':r')
  if !has_key(l:options, '--encoding')
    if vimshell#iswin()
      " Use UTF-8 Cygwin.
      let l:options['--encoding'] = 'utf8'
    else
      let l:options['--encoding'] = has_key(g:vimshell_interactive_encodings, l:cmdname) ?
            \ g:vimshell_interactive_encodings[l:cmdname] : &termencoding
    endif
  endif

  " Encoding conversion.
  if l:options['--encoding'] != '' && l:options['--encoding'] != &encoding
    for l:command in l:commands
      call map(l:command.args, 'iconv(v:val, &encoding, l:options["--encoding"])')
    endfor
  endif

  if exists('b:interactive') && !empty(b:interactive.process) && b:interactive.process.is_valid
    " Delete zombie process.
    call vimshell#interactive#force_exit()
  endif

  if vimshell#iswin() && g:vimshell_interactive_cygwin_home != ''
    " Set $HOME.
    let l:home_save = vimshell#set_variables({
          \ '$HOME' : g:vimshell_interactive_cygwin_home, 
          \})
  endif

  let l:save_winnr = winnr()
  call s:init_bg(l:args, a:context)

  " Set environment variables.
  let l:environments_save = vimshell#set_variables({
        \ '$TERM' : g:vimshell_environment_term,
        \ '$TERMCAP' : 'COLUMNS=' . winwidth(0)-5,
        \ '$VIMSHELL' : 1,
        \ '$COLUMNS' : winwidth(0)-5,
        \ '$LINES' : winheight(0),
        \ '$VIMSHELL_TERM' : 'terminal',
        \ '$EDITOR' : g:vimshell_cat_command,
        \ '$PAGER' : g:vimshell_cat_command,
        \})

  " Initialize.
  let l:sub = vimproc#ptyopen(l:commands)

  " Restore environment variables.
  call vimshell#restore_variables(l:environments_save)

  if vimshell#iswin() && g:vimshell_interactive_cygwin_home != ''
    " Restore $HOME.
    call vimshell#restore_variables(l:home_save)
  endif


  " Set variables.
  let b:interactive = {
        \ 'type': 'terminal',
        \ 'syntax' : &syntax,
        \ 'process' : l:sub,
        \ 'fd' : a:context.fd,
        \ 'encoding' : l:options['--encoding'],
        \ 'is_secret': 0,
        \ 'prompt_history' : {},
        \ 'is_pty' : 1,
        \ 'args' : l:args,
        \ 'echoback_linenr' : 0,
        \ 'save_cursor' : getpos('.'),
        \ 'width' : winwidth(0),
        \ 'height' : winheight(0),
        \ 'stdout_cache' : '',
        \ 'stderr_cache' : '',
        \ 'command' : fnamemodify(vimshell#iswin() ? l:args[1] : l:args[0], ':t:r'),
        \ 'hook_functions_table' : {},
        \}
  call vimshell#interactive#init()

  let l:last_winnr = winnr()
  execute l:save_winnr.'wincmd w'

  if has_key(a:context, 'is_single_command') && a:context.is_single_command
    call vimshell#print_prompt(a:context)
    execute l:last_winnr.'wincmd w'
  endif

  if b:interactive.process.is_valid
    startinsert
  endif
endfunction"}}}
function! s:command.complete(args)"{{{
  return vimshell#iswin() ?
        \ vimshell#complete#helper#executables(a:args[-1], g:vimshell_interactive_cygwin_path) :
        \ vimshell#complete#helper#executables(a:args[-1])
endfunction"}}}

function! vimshell#commands#texe#define()
  return s:command
endfunction

let s:update_time_save = &updatetime

function! s:default_settings()"{{{
  " Define mappings.
  call vimshell#term_mappings#define_default_mappings()
  
  " Common.
  setlocal nocompatible
  setlocal nolist
  setlocal buftype=nofile
  setlocal noswapfile
  setlocal tabstop=8
  setlocal foldcolumn=0
  setlocal foldmethod=manual
  if has('conceal')
    setlocal conceallevel=3
    setlocal concealcursor=n
  endif
  
  " For Terminal
  setlocal nowrap
  setlocal nopaste
  setlocal nonumber
  setlocal scrolloff=0
  setlocal sidescrolloff=0
  setlocal sidescroll=1
  setfiletype vimshell-term
endfunction"}}}

function! s:init_bg(args, context)"{{{
  " Save current directiory.
  let l:cwd = getcwd()

  " Split nicely.
  call vimshell#split_nicely()

  edit `='texe-'.fnamemodify(a:args[0], ':r').'@'.(bufnr('$')+1)`
  call vimshell#cd(l:cwd)

  call s:default_settings()

  let l:use_cygpty = vimshell#iswin() && a:args[0] =~ '^fakecygpty\%(\.exe\)\?$'
  execute 'set filetype=term-'.fnamemodify(l:use_cygpty ? a:args[1] : a:args[0], ':t:r')

  " Set autocommands.
  augroup vimshell
    autocmd InsertEnter <buffer>       call s:insert_enter()
    autocmd InsertLeave <buffer>       call s:insert_leave()
    autocmd BufUnload <buffer>       call vimshell#interactive#hang_up(expand('<afile>'))
    autocmd CursorHoldI <buffer>     call vimshell#interactive#check_insert_output()
    autocmd CursorMovedI <buffer>    call vimshell#interactive#check_moved_output()
    autocmd BufWinEnter,WinEnter <buffer> call s:event_bufwin_enter()
  augroup END

  " Set send buffer.
  call vimshell#interactive#set_send_buffer(bufnr('%'))
endfunction"}}}

function! s:insert_enter()"{{{
  if &updatetime > g:vimshell_interactive_update_time
    let s:update_time_save = &updatetime
    let &updatetime = g:vimshell_interactive_update_time
  endif

  if exists(':NeoComplCacheDisable')
    " Lock neocomplcache.
    NeoComplCacheLock
  endif

  if !exists('b:interactive')
    return
  endif

  if winwidth(0) != b:interactive.width || winheight(0) != b:interactive.height
    " Set new window size.
    call b:interactive.process.set_winsize(winwidth(0), winheight(0))
  endif

  if exists('+guicursor')
    " Save guicursor.
    let s:guicursor_save = &guicursor
    let &guicursor = g:vimshell_terminal_cursor
  endif

  call setpos('.', b:interactive.save_cursor)
  startinsert
endfunction"}}}
function! s:insert_leave()"{{{
  setlocal nomodifiable
  
  if &updatetime < s:update_time_save
    let &updatetime = s:update_time_save
  endif

  if exists('+guicursor')
    let &guicursor = s:guicursor_save
  endif
endfunction"}}}
function! s:event_bufwin_enter()"{{{
  if has('conceal')
    setlocal conceallevel=3
    setlocal concealcursor=nvi
  endif
endfunction"}}}
