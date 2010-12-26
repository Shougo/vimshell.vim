"=============================================================================
" FILE: exe.vim
" AUTHOR: Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 26 Dec 2010.
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
      \ 'name' : 'exe',
      \ 'kind' : 'execute',
      \ 'description' : 'exe [{option}...] {command}',
      \}
function! s:command.execute(commands, context)"{{{
  let l:commands = a:commands
  let [l:commands[0].args, l:options] = vimshell#parser#getopt(l:commands[0].args, 
        \{ 'arg=' : ['--encoding']
        \})
  if !has_key(l:options, '--encoding')
    let l:options['--encoding'] = &termencoding
  endif
  
  if empty(l:commands[0].args)
    return
  endif

  " Encoding conversion.
  if l:options['--encoding'] != '' && l:options['--encoding'] != &encoding
    for l:command in l:commands
      call map(l:command.args, 'iconv(v:val, &encoding, l:options["--encoding"])')
    endfor
  endif
  
  " Execute command.
  if s:init_process(l:commands, a:context, l:options)
    return
  endif

  " Move line.
  call append(line('.'), '')
  normal! j

  if a:context.is_interactive
    throw 'exe: Process started.'
  endif
  
  echo 'Running command.'
  while b:interactive.process.is_valid
    call vimshell#interactive#execute_pipe_out()

    " Get input key.
    let l:char = getchar(0)
    if l:char != 0
      let l:char = nr2char(l:char)
      if l:char == "\<C-z>"
        call vimshell#error_line(a:context.fd, 'exe: Background executed.')

        " Background execution.
        call vimshell#commands#bg#init(l:commands, a:context, 'vimshell-bg', b:interactive)

        unlet b:interactive
      elseif l:char == "\<C-d>"
        " Interrupt.
        call vimshell#interactive#force_exit()
        call vimshell#error_line(a:context.fd, 'exe: Interrupted.')
        return
      endif
    endif
  endwhile

  redraw
  echo ''

  let b:vimshell.system_variables['status'] = b:interactive.status
endfunction"}}}

function! vimshell#commands#exe#define()
  return s:command
endfunction

function! s:init_process(commands, context, options)"{{{
  if exists('b:interactive') && !empty(b:interactive.process) && b:interactive.process.is_valid
    " Delete zombie process.
    call vimshell#interactive#force_exit()
  endif
  
  " Set environment variables.
  let l:environments_save = vimshell#set_variables({
        \ '$TERM' : g:vimshell_environment_term, 
        \ '$TERMCAP' : 'COLUMNS=' . winwidth(0), 
        \ '$VIMSHELL' : 1, 
        \ '$COLUMNS' : winwidth(0)-5,
        \ '$LINES' : winheight(0),
        \ '$VIMSHELL_TERM' : 'execute',
        \ '$EDITOR' : g:vimshell_cat_command,
        \ '$PAGER' : g:vimshell_cat_command,
        \})

  " Initialize.
  let l:sub = vimproc#plineopen3(a:commands)
  
  " Restore environment variables.
  call vimshell#restore_variables(l:environments_save)

  let l:cmdline = []
  for l:command in a:commands
    call add(l:cmdline, join(l:command.args))
  endfor

  " Set variables.
  let b:interactive = {
        \ 'type' : 'execute', 
        \ 'syntax' : b:interactive.syntax,
        \ 'process' : l:sub, 
        \ 'fd' : a:context.fd, 
        \ 'encoding' : a:options['--encoding'], 
        \ 'is_pty' : !vimshell#iswin(), 
        \ 'echoback_linenr' : -1,
        \ 'stdout_cache' : '',
        \ 'stderr_cache' : '',
        \ 'cmdline' : join(l:cmdline, '|'), 
        \}

  " Input from stdin.
  if b:interactive.fd.stdin != ''
    call b:interactive.process.stdin.write(vimshell#read(a:context.fd))
  endif
  call b:interactive.process.stdin.close()

  return
endfunction"}}}
