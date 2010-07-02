"=============================================================================
" FILE: bg.vim
" AUTHOR: Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 01 Jul 2010
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

function! vimshell#internal#bg#execute(command, args, fd, other_info)"{{{
  " Execute command in background.
  let [l:args, l:options] = vimshell#parser#getopt(a:args, 
        \{ 'arg=' : ['--encoding', '--filetype']
        \})
  if !has_key(l:options, '--encoding')
    let l:options['--encoding'] = &termencoding
  endif
  if !has_key(l:options, '--filetype')
    let l:options['--filetype'] = 'vimshell-bg'
  endif

  if empty(l:args)
    return
  elseif l:args[0] == 'shell'
    " Background shell.
    if has('win32') || has('win64')
      if g:vimshell_use_ckw
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

    return
  endif
  
  " Background execute.
  if exists('b:interactive') && b:interactive.process.is_valid
    " Delete zombee process.
    call vimshell#interactive#force_exit()
  endif
  
  " Encoding conversion.
  if l:options['--encoding'] != '' && l:options['--encoding'] != &encoding
    call map(l:args, 'iconv(v:val, &encoding, l:options["--encoding"])')
  endif

  " Initialize.
  let l:sub = vimproc#popen3(l:args)

  " Set variables.
  let l:interactive = {
        \ 'process' : l:sub, 
        \ 'fd' : a:fd, 
        \ 'encoding' : l:options['--encoding'], 
        \ 'is_pty' : !vimshell#iswin(), 
        \ 'is_background' : 1, 
        \ 'cached_output' : '', 
        \}

  " Input from stdin.
  if l:interactive.fd.stdin != ''
    call l:interactive.process.stdin.write(vimshell#read(a:fd))
  endif
  call l:interactive.process.stdin.close()

  return vimshell#internal#bg#init(l:args, a:fd, a:other_info, l:options['--filetype'], l:interactive)
endfunction"}}}

function! vimshell#internal#bg#vimshell_bg(args)"{{{
  let [l:command, l:script] = vimshell#parser#parse_command(vimshell#parser#parse_alias(a:args))
  call vimshell#internal#bg#execute('bg', vimshell#parser#split_args(l:command . ' ' . l:script), {'stdin' : '', 'stdout' : '', 'stderr' : ''}, {'is_interactive' : 0})
endfunction"}}}

function! vimshell#internal#bg#init(args, fd, other_info, filetype, interactive)"{{{
  " Save current directiory.
  let l:cwd = getcwd()

  " Split nicely.
  call vimshell#split_nicely()

  edit `=substitute(join(a:args), '[<>|]', '_', 'g').'&'.(bufnr('$')+1)`
  lcd `=l:cwd`
  setlocal buftype=nofile
  setlocal noswapfile
  setlocal nowrap
  setlocal nomodifiable
  let &filetype = a:filetype
  let b:interactive = a:interactive

  " Set environment variables.
  let $TERMCAP = 'COLUMNS=' . winwidth(0)
  let $VIMSHELL = 1
  let $COLUMNS = winwidth(0)-5
  let $LINES = winheight(0)
  let $VIMSHELL_TERM = 'background'

  " Set syntax.
  syn region   InteractiveError   start=+!!!+ end=+!!!+ contains=InteractiveErrorHidden oneline
  syn match   InteractiveErrorHidden            '!!!' contained
  syn match   InteractiveMessage   '\*\%(Exit\|Killed\)\*'
  
  hi def link InteractiveMessage WarningMsg
  hi def link InteractiveError Error
  hi def link InteractiveErrorHidden Ignore

  augroup vimshell_bg
    autocmd BufUnload <buffer>       call s:on_interrupt(expand('<afile>'))
  augroup END
  
  nnoremap <buffer><silent> <Plug>(vimshell_interactive_execute_line)  :<C-u>call <SID>on_execute()<CR>
  nnoremap <buffer><silent> <Plug>(vimshell_interactive_interrupt)       :<C-u>call vimshell#interactive#hang_up(a:afile)
  nnoremap <buffer><silent> <Plug>(vimshell_interactive_exit)       :<C-u>call <SID>on_exit()<CR>
  
  nmap <buffer><CR>      <Plug>(vimshell_interactive_execute_line)
  nmap <buffer><C-c>     <Plug>(vimshell_interactive_interrupt)
  nmap <buffer>q         <Plug>(vimshell_interactive_exit)
  
  call s:on_execute()

  wincmd p
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

