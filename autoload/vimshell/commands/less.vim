"=============================================================================
" FILE: less.vim
" AUTHOR: Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 31 Jul 2010
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
      \ 'name' : 'less',
      \ 'kind' : 'execute',
      \ 'description' : 'less [{option}...] {command}',
      \}
function! s:command.execute(commands, context)"{{{
  " Execute command in background.
  let l:commands = a:commands
  let [l:commands[0].args, l:options] = vimshell#parser#getopt(l:commands[0].args, 
        \{ 'arg=' : ['--encoding', '--filetype']
        \})
  if !has_key(l:options, '--encoding')
    let l:options['--encoding'] = &termencoding
  endif
  if !has_key(l:options, '--filetype')
    let l:options['--filetype'] = 'vimshell-less'
  endif
  
  if empty(l:commands[0].args)
    return
  endif

  " Background execute.
  if exists('b:interactive') && !empty(b:interactive.process) && b:interactive.process.is_valid
    " Delete zombee process.
    call vimshell#interactive#force_exit()
  endif
  
  " Encoding conversion.
  if l:options['--encoding'] != '' && l:options['--encoding'] != &encoding
    for l:command in l:commands
      call map(l:command.args, 'iconv(v:val, &encoding, l:options["--encoding"])')
    endfor
  endif

  " Initialize.
  let l:sub = vimproc#plineopen2(l:commands)

  " Set variables.
  let l:interactive = {
        \ 'type' : 'less', 
        \ 'process' : l:sub, 
        \ 'fd' : a:context.fd, 
        \ 'encoding' : l:options['--encoding'], 
        \ 'is_pty' : 0, 
        \ 'echoback_linenr' : 0,
        \ 'stdout_cache' : '',
        \}

  " Input from stdin.
  if l:interactive.fd.stdin != ''
    call l:interactive.process.stdin.write(vimshell#read(a:context.fd))
  endif
  call l:interactive.process.stdin.close()

  return s:init(a:commands, a:context, l:options['--filetype'], l:interactive)
endfunction"}}}
function! s:command.complete(args)"{{{
    return vimshell#complete#helper#command_args(a:args)
endfunction"}}}

function! vimshell#commands#less#define()
  return s:command
endfunction

function! s:init(commands, context, filetype, interactive)"{{{
  " Save current directiory.
  let l:cwd = getcwd()

  " Split nicely.
  call vimshell#split_nicely()

  let l:args = ''
  for l:command in a:commands
    let l:args .= join(l:command.args)
  endfor
  edit `='less-'.substitute(l:args, '[<>|]', '_', 'g').'@'.(bufnr('$')+1)`
  lcd `=l:cwd`
  setlocal buftype=nofile
  setlocal noswapfile
  setlocal wrap
  setlocal nolist
  setlocal nomodifiable
  let &filetype = a:filetype
  let b:interactive = a:interactive
  if has('conceal')
    setlocal conceallevel=3
    setlocal concealcursor=n
  endif

  " Set environment variables.
  let $TERM = g:vimshell_environment_term
  let $TERMCAP = 'COLUMNS=' . winwidth(0)
  let $VIMSHELL = 1
  let $COLUMNS = winwidth(0)-5
  let $LINES = winheight(0)
  let $VIMSHELL_TERM = 'background'
  let $EDITOR = g:vimshell_cat_command
  let $PAGER = g:vimshell_cat_command

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
  augroup END
  
  nnoremap <buffer><silent> <Plug>(vimshell_less_execute_line)  :<C-u>call <SID>on_execute()<CR>
  nnoremap <buffer><silent> <Plug>(vimshell_less_interrupt)       :<C-u>call vimshell#interactive#hang_up(bufname('%'))<CR>
  nnoremap <buffer><silent> <Plug>(vimshell_less_exit)       :<C-u>call <SID>on_exit()<CR>
  nnoremap <buffer><silent> <Plug>(vimshell_less_next_line)       :<C-u>call <SID>next_line()<CR>
  nnoremap <buffer><silent> <Plug>(vimshell_less_next_screen)       :<C-u>call <SID>next_screen()<CR>
  nnoremap <buffer><silent> <Plug>(vimshell_less_next_half_screen)       :<C-u>call <SID>next_half_screen()<CR>
  
  nmap <buffer><CR>      <Plug>(vimshell_less_execute_line)
  nmap <buffer><C-c>     <Plug>(vimshell_less_interrupt)
  nmap <buffer>q         <Plug>(vimshell_less_exit)
  nmap <buffer>j         <Plug>(vimshell_less_next_line)
  nmap <buffer><C-f>     <Plug>(vimshell_less_next_screen)
  nmap <buffer><C-d>     <Plug>(vimshell_less_next_half_screen)
  
  call s:on_execute()

  if !has_key(a:context, 'is_from_command') || !a:context.is_from_command
    wincmd p
  endif
endfunction"}}}

function! s:on_execute()"{{{
  call s:print_output(winheight(0))
endfunction"}}}
function! s:on_exit()"{{{
  if !b:interactive.process.is_valid
    bdelete
  endif  
endfunction "}}}
function! s:next_line()"{{{
  if line('.') == line('$')
    call s:print_output(2)
  endif
  
  normal! j
endfunction "}}}
function! s:next_screen()"{{{
  if line('.') == line('$')
    call s:print_output(winheight(0))
  else
    execute "normal! \<C-f>"
  endif
endfunction "}}}
function! s:next_half_screen()"{{{
  if line('.') == line('$')
    call s:print_output(winheight(0)/2)
  else
    execute "normal! \<C-d>"
  endif
endfunction "}}}

function! s:print_output(line_num)"{{{
  $
  setlocal modifiable
  
  if b:interactive.stdout_cache == ''
    if b:interactive.process.stdout.eof
      call vimshell#interactive#exit()
    endif

    if !b:interactive.process.is_valid
      setlocal nomodifiable
      return
    endif
  endif
  
  " Check cache.
  let l:count = len(split(b:interactive.stdout_cache, '\n', 1))
  if !b:interactive.process.stdout.eof && l:count < a:line_num
    echo 'Running command.'
    
    while l:count < a:line_num && !b:interactive.process.stdout.eof
      " Get output.
      let b:interactive.stdout_cache .= b:interactive.process.stdout.read(-1, 40)
      let l:count = len(split(b:interactive.stdout_cache, '\n', 1))
    endwhile
    
    redraw
    echo ''
  endif
  
  if l:count > a:line_num
    let l:count = a:line_num
  endif

  let l:match = match(b:interactive.stdout_cache, '\n', 0, l:count)
  if l:match <= 0
    let l:output = b:interactive.stdout_cache
    let b:interactive.stdout_cache = ''
  else
    let l:output = b:interactive.stdout_cache[: l:match-1]
    let b:interactive.stdout_cache = b:interactive.stdout_cache[l:match :]
  endif

  call vimshell#interactive#print_buffer(b:interactive.fd, l:output)
  setlocal nomodifiable
endfunction"}}}
