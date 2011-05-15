"=============================================================================
" FILE: bg.vim
" AUTHOR: Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 16 Sep 2010
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
      \ 'name' : 'bg',
      \ 'kind' : 'execute',
      \ 'description' : 'bg [{option}...] {command}',
      \}
function! s:command.execute(commands, context)"{{{
  " Execute command in background.
  let l:commands = a:commands
  let [l:commands[0].args, l:options] = vimshell#parser#getopt(l:commands[0].args, 
        \{ 'arg=' : ['--encoding', '--syntax']
        \})
  if !has_key(l:options, '--encoding')
    let l:options['--encoding'] = &termencoding
  endif
  if !has_key(l:options, '--syntax')
    let l:options['--syntax'] = 'vimshell-bg'
  endif
  
  if empty(l:commands[0].args)
    return
  endif

  " Background execute.
  if exists('b:interactive') && !empty(b:interactive.process) && b:interactive.process.is_valid
    " Delete zombie process.
    call vimshell#interactive#force_exit()
  endif
  
  " Encoding conversion.
  if l:options['--encoding'] != '' && l:options['--encoding'] != &encoding
    for l:command in l:commands
      call map(l:command.args, 'iconv(v:val, &encoding, l:options["--encoding"])')
    endfor
  endif

  " Set environment variables.
  let l:environments_save = vimshell#set_variables({
        \ '$TERM' : g:vimshell_environment_term, 
        \ '$TERMCAP' : 'COLUMNS=' . winwidth(0), 
        \ '$VIMSHELL' : 1, 
        \ '$COLUMNS' : winwidth(0)-5,
        \ '$LINES' : winheight(0),
        \ '$VIMSHELL_TERM' : 'background',
        \ '$EDITOR' : g:vimshell_cat_command,
        \ '$PAGER' : g:vimshell_cat_command,
        \})

  " Initialize.
  let l:sub = vimproc#plineopen3(l:commands)
  
  " Restore environment variables.
  call vimshell#restore_variables(l:environments_save)

  " Set variables.
  let l:interactive = {
        \ 'type' : 'background', 
        \ 'syntax' : &syntax,
        \ 'process' : l:sub, 
        \ 'fd' : a:context.fd, 
        \ 'encoding' : l:options['--encoding'], 
        \ 'is_pty' : 0, 
        \ 'echoback_linenr' : 0,
        \ 'stdout_cache' : '',
        \ 'stderr_cache' : '',
        \}

  " Input from stdin.
  if l:interactive.fd.stdin != ''
    call l:interactive.process.stdin.write(vimshell#read(a:context.fd))
  endif
  call l:interactive.process.stdin.close()

  return vimshell#commands#bg#init(a:commands, a:context, l:options['--syntax'], l:interactive)
endfunction"}}}
function! s:command.complete(args)"{{{
    return vimshell#complete#helper#command_args(a:args)
endfunction"}}}

function! vimshell#commands#bg#define()
  return s:command
endfunction

function! vimshell#commands#bg#init(commands, context, syntax, interactive)"{{{
  " Save current directiory.
  let l:cwd = getcwd()

  let l:save_winnr = winnr()

  " Split nicely.
  call vimshell#split_nicely()

  let l:args = ''
  for l:command in a:commands
    let l:args .= join(l:command.args)
  endfor
  edit `='bg-'.substitute(l:args, '[<>|]', '_', 'g').'@'.(bufnr('$')+1)`
  call vimshell#cd(l:cwd)

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

  " For bg.
  setlocal wrap
  setlocal nomodifiable
  setlocal filetype=vimshell-bg
  let &syntax = a:syntax

  let b:interactive = a:interactive

  " Set syntax.
  syn region   InteractiveError   start=+!!!+ end=+!!!+ contains=InteractiveErrorHidden oneline
  if v:version >= 703
    " Supported conceal features.
    syn match   InteractiveErrorHidden            '!!!' contained conceal
  else
    syn match   InteractiveErrorHidden            '!!!' contained
  endif
  hi def link InteractiveErrorHidden Error

  augroup vimshell
    autocmd BufUnload <buffer>       call vimshell#interactive#hang_up(expand('<afile>'))
    autocmd BufWinEnter,WinEnter <buffer> call s:event_bufwin_enter()
  augroup END

  nnoremap <buffer><silent> <Plug>(vimshell_interactive_execute_line)  :<C-u>call <SID>on_execute()<CR>
  nnoremap <buffer><silent> <Plug>(vimshell_interactive_interrupt)       :<C-u>call vimshell#interactive#hang_up(bufname('%'))<CR>
  nnoremap <buffer><silent> <Plug>(vimshell_interactive_exit)       :<C-u>call vimshell#interactive#quit_buffer()<CR>

  nmap <buffer><CR>      <Plug>(vimshell_interactive_execute_line)
  nmap <buffer><C-c>     <Plug>(vimshell_interactive_interrupt)
  nmap <buffer>q         <Plug>(vimshell_interactive_exit)

  call s:on_execute()

  let l:last_winnr = winnr()
  execute l:save_winnr.'wincmd w'

  if has_key(a:context, 'is_single_command') && a:context.is_single_command
    call vimshell#print_prompt(a:context)
    execute l:last_winnr.'wincmd w'
    stopinsert
  endif
endfunction"}}}

function! s:on_execute()"{{{
  setlocal modifiable
  echo 'Running command.'
  call vimshell#interactive#execute_pipe_out()
  redraw
  echo ''
  setlocal nomodifiable
endfunction"}}}
function! s:on_exit()"{{{
  if !b:interactive.process.is_valid
    bdelete
  endif  
endfunction "}}}
function! s:event_bufwin_enter()"{{{
  if has('conceal')
    setlocal conceallevel=3
    setlocal concealcursor=nvi
  endif
endfunction"}}}
