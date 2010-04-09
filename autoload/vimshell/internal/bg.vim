"=============================================================================
" FILE: bg.vim
" AUTHOR: Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 09 Apr 2010
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

augroup vimshell_bg
  autocmd!
augroup END

function! vimshell#internal#bg#execute(program, args, fd, other_info)"{{{
  " Execute program in background.
  let [l:args, l:options] = vimshell#parser#getopt(a:args, 
        \{ 'arg=' : ['--encoding', '--filetype']
        \})
  if !has_key(l:options, '--encoding')
    let l:options['--encoding'] = &termencoding
  endif
  if !has_key(l:options, '--filetype')
    let l:options['--filetype'] = 'background'
  endif

  if empty(l:args)
    return 
  elseif l:args[0] == 'shell'
    " Background shell.
    if has('win32') || has('win64')
      if g:VimShell_UseCkw
        " Use ckw.
        silent execute printf('!start ckw -e %s', &shell)
      else
        silent execute printf('!start %s', &shell)
      endif
    elseif &term =~ '^screen'
      silent execute printf('!screen %s', &shell)
    else
      " Can't Background execute.
      shell
    endif
  elseif g:VimShell_EnableInteractive
    " Background execute.
    if exists('b:interactive') && b:interactive.process.is_valid
      " Delete zombee process.
      call vimshell#interactive#force_exit()
    endif

    " Initialize.
    try
      let l:sub = vimproc#popen3(join(l:args))
    catch 'list index out of range'
      let l:error = printf('File: "%s" is not found.', l:args[0])

      call vimshell#error_line(a:fd, l:error)

      return 0
    endtry

    " Set variables.
    let l:interactive = {
          \ 'process' : l:sub, 
          \ 'fd' : a:fd, 
          \ 'encoding' : l:options['--encoding'], 
          \ 'is_pty' : !vimshell#iswin(), 
          \ 'is_background' : 1, 
          \}

    " Input from stdin.
    if l:interactive.fd.stdin != ''
      call l:interactive.process.stdin.write(vimshell#read(a:fd))
    endif
    call l:interactive.process.stdin.close()
    
    return vimshell#internal#bg#init(l:args, a:fd, a:other_info, l:options['--filetype'], interactive)
  else
    " Execute in screen.
    let l:other_info = a:other_info
    return vimshell#internal#screen#execute(l:args[0], l:args[1:], a:fd, l:other_info)
  endif
endfunction"}}}

function! vimshell#internal#bg#vimshell_bg(args)"{{{
  call vimshell#internal#bg#execute('bg', vimshell#parser#split_args(a:args), {'stdin' : '', 'stdout' : '', 'stderr' : ''}, {'is_interactive' : 0})
endfunction"}}}

function! vimshell#internal#bg#init(args, fd, other_info, filetype, interactive)"{{{
  " Init buffer.
  if a:other_info.is_interactive
    let l:context = a:other_info
    let l:context.fd = a:fd
    call vimshell#print_prompt(l:context)
  endif

  " Save current directiory.
  let l:cwd = getcwd()

  " Split nicely.
  call vimshell#split_nicely()

  edit `=substitute(join(a:args), '[<>|]', '_', 'g').'&'.(bufnr('$')+1)`
  lcd `=l:cwd`
  setlocal buftype=nofile
  setlocal noswapfile
  setlocal nowrap
  let &filetype = a:filetype
  let b:interactive = a:interactive

  " Set syntax.
  syn region   InteractiveError   start=+!!!+ end=+!!!+ contains=InteractiveErrorHidden oneline
  syn match   InteractiveErrorHidden            '!!!' contained
  syn match   InteractiveMessage   '\*\%(Exit\|Killed\)\*'
  
  hi def link InteractiveMessage WarningMsg
  hi def link InteractiveError Error
  hi def link InteractiveErrorHidden Ignore

  autocmd vimshell_bg BufUnload <buffer>       call s:on_exit()
  autocmd vimshell_bg CursorHold <buffer>       call s:on_hold()
  nnoremap <buffer><silent><C-c>       :<C-u>call vimshell#interactive#interrupt()<CR>
  inoremap <buffer><silent><C-c>       <ESC>:<C-u>call <SID>on_exit()<CR>
  nnoremap <buffer><silent><CR>       :<C-u>call <SID>on_execute()<CR>
  call s:on_execute()

  wincmd w
  if has_key(a:other_info, 'is_insert') && a:other_info.is_insert
    call vimshell#start_insert()
  endif

  return 1
endfunction"}}}

function! s:on_execute()
  echo 'Running command.'
  call vimshell#interactive#execute_pipe_out()
  redraw
  echo ''
endfunction

function! s:on_hold()
  call vimshell#interactive#execute_pipe_out()

  if b:interactive.process.is_valid
    normal! hl
  endif
endfunction

function! s:on_exit()
  augroup vimshell_bg
    autocmd! BufUnload <buffer>
  augroup END

  call vimshell#interactive#hang_up()
endfunction
