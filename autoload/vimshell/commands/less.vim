"=============================================================================
" FILE: less.vim
" AUTHOR: Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 04 Oct 2011.
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
  let commands = a:commands
  let [commands[0].args, options] = vimshell#parser#getopt(commands[0].args, {
        \ 'arg=' : ['--encoding', '--syntax', '--split'],
        \ }, {
        \ '--encoding' : &termencoding,
        \ '--syntax' : 'vimshell-less',
        \ '--split' : g:vimshell_split_command,
        \ })

  if empty(commands[0].args)
    return
  endif

  if !executable(commands[0].args[0])
    return vimshell#execute_internal_command('view', commands[0].args, a:context)
  endif

  " Background execute.
  if exists('b:interactive') && !empty(b:interactive.process) && b:interactive.process.is_valid
    " Delete zombie process.
    call vimshell#interactive#force_exit()
  endif

  " Encoding conversion.
  if options['--encoding'] != '' && options['--encoding'] != &encoding
    for command in commands
      call map(command.args, 'iconv(v:val, &encoding, options["--encoding"])')
    endfor
  endif

  " Set variables.
  let interactive = {
        \ 'type' : 'less',
        \ 'syntax' : options['--syntax'],
        \ 'fd' : a:context.fd,
        \ 'encoding' : options['--encoding'],
        \ 'is_pty' : 0,
        \ 'echoback_linenr' : 0,
        \ 'stdout_cache' : '',
        \}

  return s:init(a:commands, a:context, options, interactive)
endfunction"}}}
function! s:command.complete(args)"{{{
    return vimshell#complete#helper#command_args(a:args)
endfunction"}}}

function! vimshell#commands#less#define()
  return s:command
endfunction

function! s:init(commands, context, options, interactive)"{{{
  " Save current directiory.
  let cwd = getcwd()

  let [new_pos, old_pos] = vimshell#split(a:options['--split'])

  " Set environment variables.
  let environments_save = vimshell#set_variables({
        \ '$TERM' : g:vimshell_environment_term,
        \ '$TERMCAP' : 'COLUMNS=' . winwidth(0),
        \ '$VIMSHELL' : 1,
        \ '$COLUMNS' : winwidth(0)-5,
        \ '$LINES' : winheight(0),
        \ '$VIMSHELL_TERM' : 'less',
        \ '$EDITOR' : g:vimshell_cat_command,
        \ '$PAGER' : g:vimshell_cat_command,
        \})

  " Initialize.
  let a:interactive.process = vimproc#plineopen2(a:commands)

  " Restore environment variables.
  call vimshell#restore_variables(environments_save)

  " Input from stdin.
  if a:interactive.fd.stdin != ''
    call a:interactive.process.stdin.write(vimshell#read(a:context.fd))
  endif
  call a:interactive.process.stdin.close()

  let a:interactive.width = winwidth(0)
  let a:interactive.height = winheight(0)

  let args = ''
  for command in a:commands
    let args .= join(command.args)
  endfor

  edit `='less-'.substitute(args, '[<>|]', '_', 'g').'@'.(bufnr('$')+1)`

  let [new_pos[2], new_pos[3]] = [bufnr('%'), getpos('.')]

  call vimshell#cd(cwd)

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

  " For less.
  setlocal wrap
  setlocal nomodifiable

  setlocal filetype=vimshell-less
  let &syntax = a:options['--syntax']
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
    autocmd BufDelete <buffer>       call vimshell#interactive#hang_up(expand('<afile>'))
  augroup END

  nnoremap <buffer><silent> <Plug>(vimshell_less_execute_line)  :<C-u>call <SID>on_execute()<CR>
  nnoremap <buffer><silent> <Plug>(vimshell_less_interrupt)       :<C-u>call vimshell#interactive#hang_up(bufname('%'))<CR>
  nnoremap <buffer><silent> <Plug>(vimshell_less_exit)       :<C-u>call vimshell#interactive#quit_buffer()<CR>
  nnoremap <buffer><silent> <Plug>(vimshell_less_next_line)       :<C-u>call <SID>next_line()<CR>
  nnoremap <buffer><silent> <Plug>(vimshell_less_next_screen)       :<C-u>call <SID>next_screen()<CR>
  nnoremap <buffer><silent> <Plug>(vimshell_less_next_half_screen)       :<C-u>call <SID>next_half_screen()<CR>

  nmap <buffer><CR>      <Plug>(vimshell_less_execute_line)
  nmap <buffer><C-c>     <Plug>(vimshell_less_interrupt)
  nmap <buffer>q         <Plug>(vimshell_less_exit)
  nmap <buffer>j         <Plug>(vimshell_less_next_line)
  nmap <buffer>f         <Plug>(vimshell_less_next_screen)
  nmap <buffer><C-f>     <Plug>(vimshell_less_next_screen)
  nmap <buffer>d         <Plug>(vimshell_less_next_half_screen)
  nmap <buffer><C-d>     <Plug>(vimshell_less_next_half_screen)
  nmap <buffer><Space>   <Plug>(vimshell_less_next_screen)
  nnoremap <buffer>b     <C-b>
  nnoremap <buffer>u     <C-u>

  call s:print_output(winheight(0))

  call vimshell#restore_pos(old_pos)

  if has_key(a:context, 'is_single_command') && a:context.is_single_command
    call vimshell#next_prompt(a:context, 0)
    call vimshell#restore_pos(new_pos)
    stopinsert
  endif
endfunction"}}}

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
  setlocal modifiable

  if winwidth(0) != b:interactive.width || winheight(0) != b:interactive.height
    " Set new window size.
    call b:interactive.process.set_winsize(winwidth(0), winheight(0))
  endif

  $

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
  let cnt = len(split(b:interactive.stdout_cache, '\n', 1))
  if !b:interactive.process.stdout.eof && cnt < a:line_num
    echo 'Running command.'

    while cnt < a:line_num && !b:interactive.process.stdout.eof
      let b:interactive.stdout_cache .= b:interactive.process.stdout.read(100, 40)
      let cnt = len(split(b:interactive.stdout_cache, '\n', 1))
    endwhile

    redraw
    echo ''
  endif

  if cnt > a:line_num
    let cnt = a:line_num
  endif

  let match = match(b:interactive.stdout_cache, '\n', 0, cnt)
  if match <= 0
    let output = b:interactive.stdout_cache
    let b:interactive.stdout_cache = ''
  else
    let output = b:interactive.stdout_cache[: match-1]
    let b:interactive.stdout_cache = b:interactive.stdout_cache[match :]
  endif

  call vimshell#interactive#print_buffer(b:interactive.fd, output)
  setlocal nomodifiable
endfunction"}}}
