"=============================================================================
" FILE: exe.vim
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

let s:command = {
      \ 'name' : 'exe',
      \ 'kind' : 'execute',
      \ 'description' : 'exe [{option}...] {command}',
      \}
function! s:command.execute(commands, context)"{{{
  let commands = a:commands
  let [commands[0].args, options] = vimshell#parser#getopt(commands[0].args, {
        \ 'arg=' : ['--encoding'],
        \ }, {
        \ '--encoding' : &termencoding,
        \ })

  if empty(commands[0].args)
    return
  endif

  " Encoding conversion.
  if options['--encoding'] != '' && options['--encoding'] != &encoding
    for command in commands
      call map(command.args, 'iconv(v:val, &encoding, options["--encoding"])')
    endfor
  endif

  " Execute command.
  call s:init_process(commands, a:context, options)

  " Move line.
  call append(line('.'), '')
  normal! j

  let b:interactive.output_pos = getpos('.')

  if a:context.is_interactive
    throw 'exe: Process started.'
  endif

  echo 'Running command.'
  let is_insert = mode() ==# 'i'
  while b:interactive.process.is_valid
    call vimshell#interactive#execute_process_out(is_insert)

    " Get input key.
    let char = getchar(0)
    if char != 0
      let char = nr2char(char)
      if char == "\<C-z>"
        call vimshell#error_line(a:context.fd, 'exe: Background executed.')

        " Background execution.
        let options = { '--syntax' : 'vimshell-bg',
              \ '--split' : g:vimshell_split_command }
        call vimshell#commands#bg#init(commands, a:context,
              \ options, b:interactive)

        unlet b:interactive
      elseif char == "\<C-d>"
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
  if !empty(b:interactive.process) && b:interactive.process.is_valid
    " Delete zombie process.
    call vimshell#interactive#force_exit()
  endif

  " Set environment variables.
  let environments_save = vimshell#set_variables({
        \ '$TERM' : g:vimshell_environment_term,
        \ '$TERMCAP' : 'COLUMNS=' . winwidth(0)-5,
        \ '$VIMSHELL' : 1,
        \ '$COLUMNS' : winwidth(0)-5,
        \ '$LINES' : winheight(0),
        \ '$VIMSHELL_TERM' : 'execute',
        \ '$EDITOR' : g:vimshell_cat_command,
        \ '$PAGER' : g:vimshell_cat_command,
        \})

  " Initialize.
  " let sub = vimproc#plineopen3(a:commands)
  let sub = vimproc#ptyopen(a:commands)

  " Restore environment variables.
  call vimshell#restore_variables(environments_save)

  let cmdline = []
  for command in a:commands
    call add(cmdline, join(command.args))
  endfor

  " Set variables.
  let b:interactive.syntax = b:interactive.syntax
  let b:interactive.process = sub
  let b:interactive.args = a:commands[0].args
  let b:interactive.fd = a:context.fd
  let b:interactive.encoding = a:options['--encoding']
  let b:interactive.is_pty = !vimshell#iswin()
  let b:interactive.echoback_linenr = -1
  let b:interactive.stdout_cache = ''
  let b:interactive.stderr_cache = ''
  let b:interactive.cmdline = join(cmdline, '|')
  let b:interactive.width = winwidth(0)
  let b:interactive.height = winheight(0)
  let b:interactive.prompt_history = {}
  let b:interactive.echoback_linenr = 0
  let b:interactive.command = fnamemodify(a:commands[0].args[0], ':t:r')
endfunction"}}}
