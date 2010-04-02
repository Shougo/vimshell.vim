"=============================================================================
" FILE: exe.vim
" AUTHOR: Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 02 Apr 2010
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

function! vimshell#internal#exe#execute(program, args, fd, other_info)"{{{
  let [l:args, l:options] = vimshell#parser#getopt(a:args, 
        \{ 'arg=' : ['--encoding']
        \})
  if !has_key(l:options, '--encoding')
    let l:options['--encoding'] = &termencoding
  endif
  
  " Execute command.
  if g:VimShell_EnableInteractive
    if s:init_process(a:fd, l:args, l:options)
      return 0
    endif

    echo 'Running command.'
    call append(line('$'), '')
    
    " Move line.
    normal! j
    redraw
    while b:interactive.process.is_valid
      call vimshell#interactive#execute_pipe_out()
      
      " Get input key.
      let l:char = getchar(0)
      if l:char != 0
        let l:char = nr2char(l:char)
        if l:char == "\<C-z>"
          call vimshell#error_line(a:fd, 'Background Executed.')
          
          " Background execution.
          call vimshell#internal#bg#init(l:args, a:other_info.is_interactive)
          
          wincmd w
          unlet b:interactive
          return 1
        elseif l:char == "\<C-d>"
          " Interrupt.
          call vimshell#interactive#force_exit()
          call vimshell#error_line(a:fd, 'Interrupted.')
          return 0
        endif
      endif
    endwhile
    
    redraw
    echo ''
    
    let b:vimshell.system_variables['status'] = b:interactive.status
  else
    let l:fd = a:fd
    " Null input.
    if l:fd.stdin == ''
      let l:fd.stdin = '/dev/null'
    endif
    return vimshell#internal#sexe#execute('sexe', a:args, l:fd, a:other_info)
  endif

  return 0
endfunction"}}}

function! s:init_process(fd, args, options)
  if exists('b:interactive') && b:interactive.process.is_valid
    " Delete zombee process.
    call vimshell#interactive#force_exit()
  endif

  try
    let l:sub = vimproc#popen3(join(a:args))
  catch 'list index out of range'
    let l:error = printf('File: "%s" is not found.', a:args[0])

    call vimshell#error_line(a:fd, l:error)

    return 0
  endtry

  " Set variables.
  let b:interactive = {
        \ 'process' : l:sub, 
        \ 'fd' : a:fd, 
        \ 'encoding' : a:options['--encoding'], 
        \ 'is_pty' : !vimshell#iswin(), 
        \ 'is_background': 0, 
        \}

  " Input from stdin.
  if b:interactive.fd.stdin != ''
    call b:interactive.process.stdin.write(vimshell#read(a:fd))
  endif
  call b:interactive.process.stdin.close()

  return 0
endfunction
