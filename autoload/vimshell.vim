"=============================================================================
" FILE: vimshell.vim
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

function! vimshell#version()"{{{
  return '900'
endfunction"}}}

" Check vimproc."{{{
try
  let s:exists_vimproc_version = vimproc#version()
catch
  echoerr v:errmsg
  echoerr v:exception
  echoerr 'Error occured while loading vimproc.'
  echoerr 'Please install vimproc Ver.5.0 or above.'
  finish
endtry
if s:exists_vimproc_version < 600
  echoerr 'Your vimproc is too old.'
  echoerr 'Please install vimproc Ver.6.0 or above.'
  finish
endif"}}}

" Initialize."{{{
if !exists('g:vimshell_execute_file_list')
  let g:vimshell_execute_file_list = {}
endif
if !exists('s:internal_commands')
  let s:internal_commands = {}
endif
let s:update_time_save = &updatetime

" Disable bell.
set vb t_vb=

let s:last_vimshell_bufnr = -1
"}}}

function! vimshell#head_match(checkstr, headstr)"{{{
  return stridx(a:checkstr, a:headstr) == 0
endfunction"}}}
function! vimshell#tail_match(checkstr, tailstr)"{{{
  return a:tailstr == '' || a:checkstr ==# a:tailstr
        \|| a:checkstr[: -len(a:tailstr)-1] ==# a:tailstr
endfunction"}}}

" User utility functions.
function! s:default_settings()"{{{
  " Common.
  setlocal nolist
  setlocal buftype=nofile
  setlocal noswapfile
  setlocal tabstop=8
  setlocal foldcolumn=0
  setlocal foldmethod=manual
  setlocal winfixheight
  if has('conceal')
    setlocal conceallevel=3
    setlocal concealcursor=nvi
  endif

  " For vimshell.
  setlocal bufhidden=hide
  setlocal noreadonly
  setlocal iskeyword+=-,+,\\,!,~
  setlocal wrap
  setlocal omnifunc=vimshell#complete#command_complete#omnifunc

  " Set autocommands.
  augroup vimshell
    autocmd BufWinEnter,WinEnter <buffer> call s:event_bufwin_enter()
    autocmd BufWinLeave,WinLeave <buffer> call s:event_bufwin_leave()
    autocmd CursorHoldI <buffer>     call vimshell#interactive#check_insert_output()
    autocmd CursorMovedI <buffer>    call vimshell#interactive#check_moved_output()
    autocmd ColorScheme <buffer>    call s:color_scheme()
  augroup end

  " Define mappings.
  call vimshell#mappings#define_default_mappings()
endfunction"}}}
function! vimshell#set_dictionary_helper(variable, keys, value)"{{{
  for key in split(a:keys, ',')
    if !has_key(a:variable, key)
      let a:variable[key] = a:value
    endif
  endfor
endfunction"}}}

" vimshell plugin utility functions."{{{
function! vimshell#create_shell(split_flag, directory)"{{{
  if vimshell#is_cmdwin()
    echoerr 'Command line buffer is detected!'
    echoerr 'Please close command line buffer.'
    return
  endif

  " Create new buffer.
  let prefix = vimshell#iswin() ? '[vimshell]' : '*vimshell*'
  let postfix = ' - 1'
  let cnt = 1
  while buflisted(prefix.postfix)
    let cnt += 1
    let postfix = ' - ' . cnt
  endwhile
  let bufname = prefix.postfix

  let winheight = a:split_flag ?
        \ winheight(0)*g:vimshell_split_height/100 : 0
  if a:split_flag
    execute winheight 'split `=bufname`'
  else
    edit! `=bufname`
  endif

  if empty(s:internal_commands)
    call s:init_internal_commands()
  endif

  " Load history.
  let g:vimshell#hist_buffer = vimshell#history#read()

  " Initialize variables.
  let b:vimshell = {}

  " Change current directory.
  let current = (a:directory != '')? fnamemodify(a:directory, ':p') : getcwd()
  let b:vimshell.current_dir = current
  call vimshell#cd(current)

  let b:vimshell.alias_table = {}
  let b:vimshell.galias_table = {}
  let b:vimshell.altercmd_table = {}
  let b:vimshell.commandline_stack = []
  let b:vimshell.variables = {}
  let b:vimshell.system_variables = { 'status' : 0 }
  let b:vimshell.directory_stack = []
  let b:vimshell.prompt_current_dir = {}
  let b:vimshell.continuation = {}

  " Default settings.
  call s:default_settings()

  let context = {
        \ 'has_head_spaces' : 0,
        \ 'is_interactive' : 1,
        \ 'is_insert' : 1,
        \ 'fd' : { 'stdin' : '', 'stdout': '', 'stderr': ''},
        \}
  call vimshell#set_context(context)

  " Set interactive variables.
  let b:interactive = {
        \ 'type' : 'vimshell',
        \ 'syntax' : 'vimshell',
        \ 'process' : {},
        \ 'fd' : context.fd,
        \ 'encoding' : &encoding,
        \ 'is_pty' : 0,
        \ 'echoback_linenr' : -1,
        \ 'stdout_cache' : '',
        \ 'stderr_cache' : '',
        \ 'hook_functions_table' : {},
        \}

  " Load rc file.
  if filereadable(g:vimshell_vimshrc_path)
    call vimshell#execute_internal_command('vimsh', [g:vimshell_vimshrc_path],
          \{ 'has_head_spaces' : 0, 'is_interactive' : 0 })
    let b:vimshell.loaded_vimshrc = 1
  endif

  setfiletype vimshell

  call vimshell#help#init()

  call vimshell#print_prompt(context)

  call vimshell#start_insert()
  call vimshell#interactive#set_send_buffer(bufname('%'))

  " Check prompt value."{{{
  if vimshell#head_match(vimshell#get_prompt(), vimshell#get_secondary_prompt())
        \ || vimshell#head_match(vimshell#get_secondary_prompt(), vimshell#get_prompt())
    echoerr printf('Head matched g:vimshell_prompt("%s")'.
          \ ' and your g:vimshell_secondary_prompt("%s").',
          \ vimshell#get_prompt(), vimshell#get_secondary_prompt())
    finish
  elseif vimshell#head_match(vimshell#get_prompt(), '[%] ')
        \ || vimshell#head_match('[%] ', vimshell#get_prompt())
    echoerr printf('Head matched g:vimshell_prompt("%s")'.
          \ ' and your g:vimshell_user_prompt("[%] ").', vimshell#get_prompt())
    finish
  elseif vimshell#head_match('[%] ', vimshell#get_secondary_prompt())
        \ || vimshell#head_match(vimshell#get_secondary_prompt(), '[%] ')
    echoerr printf('Head matched g:vimshell_user_prompt("[%] ")'.
          \ ' and your g:vimshell_secondary_prompt("%s").',
          \ vimshell#get_secondary_prompt())
    finish
  endif"}}}

  " Set undo point.
  call feedkeys("\<C-g>u", 'n')
endfunction"}}}
function! vimshell#switch_shell(split_flag, directory)"{{{
  if vimshell#is_cmdwin()
    echoerr 'Command line buffer is detected!'
    echoerr 'Please close command line buffer.'
    return
  endif

  let context = {
        \ 'has_head_spaces' : 0,
        \ 'is_interactive' : 1,
        \ 'is_insert' : 1,
        \ 'fd' : { 'stdin' : '', 'stdout': '', 'stderr': ''},
        \}

  " Search vimshell buffer.
  if &filetype ==# 'vimshell'
    call s:switch_vimshell(bufnr('%'), a:split_flag, a:directory)
    return
  endif

  if buflisted(s:last_vimshell_bufnr)
        \ && getbufvar(s:last_vimshell_bufnr, '&filetype') ==# 'vimshell'
        \ && (!exists('t:unite_buffer_dictionary') || has_key(t:unite_buffer_dictionary, s:last_vimshell_bufnr))
    call s:switch_vimshell(s:last_vimshell_bufnr, a:split_flag, a:directory)
    return
  else
    let cnt = 1
    while cnt <= bufnr('$')
      if getbufvar(cnt, '&filetype') ==# 'vimshell'
        \ && (!exists('t:unite_buffer_dictionary') || has_key(t:unite_buffer_dictionary, cnt))
        call s:switch_vimshell(cnt, a:split_flag, a:directory)
        return
      endif

      let cnt += 1
    endwhile
  endif

  " Create window.
  call vimshell#create_shell(a:split_flag, a:directory)
endfunction"}}}

function! vimshell#available_commands()"{{{
  return s:internal_commands
endfunction"}}}
function! vimshell#execute_internal_command(command, args, context)"{{{
  if empty(s:internal_commands)
    call s:init_internal_commands()
  endif

  if empty(a:context)
    let context = { 'has_head_spaces' : 0, 'is_interactive' : 1 }
  else
    let context = a:context
  endif

  if !has_key(context, 'fd') || empty(context.fd)
    let context.fd = { 'stdin' : '', 'stdout' : '', 'stderr' : '' }
  endif

  let commands = [ { 'args' : insert(a:args, a:command),
        \            'fd' : context.fd } ]

  return vimshell#parser#execute_command(commands, context)
endfunction"}}}
function! vimshell#read(fd)"{{{
  if empty(a:fd) || a:fd.stdin == ''
    return ''
  endif

  if a:fd.stdout == '/dev/null'
    " Nothing.
    return ''
  elseif a:fd.stdout == '/dev/clip'
    " Write to clipboard.
    return @+
  else
    " Read from file.
    if vimshell#iswin()
      let ff = "\<CR>\<LF>"
    else
      let ff = "\<LF>"
      return join(readfile(a:fd.stdin), ff) . ff
    endif
  endif
endfunction"}}}
function! vimshell#print(fd, string)"{{{
  return vimshell#interactive#print_buffer(a:fd, a:string)
endfunction"}}}
function! vimshell#print_line(fd, string)"{{{
  return vimshell#interactive#print_buffer(a:fd, a:string . "\n")
endfunction"}}}
function! vimshell#error_line(fd, string)"{{{
  return vimshell#interactive#error_buffer(a:fd, a:string . "\n")
endfunction"}}}
function! vimshell#echo_error(string)"{{{
  echohl Error | echo a:string | echohl None
endfunction"}}}
function! vimshell#print_prompt(...)"{{{
  if &filetype !=# 'vimshell' || line('.') != line('$')
    return
  endif

  " Save current directory.
  let b:vimshell.prompt_current_dir[vimshell#get_prompt_linenr()] = getcwd()

  let context = a:0 >= 1? a:1 : vimshell#get_context()

  " Call preprompt hook.
  call vimshell#hook#call('preprompt', context, [])

  " Search prompt
  if empty(b:vimshell.commandline_stack)
    let new_prompt = vimshell#get_prompt()
  else
    let new_prompt = b:vimshell.commandline_stack[-1]
    call remove(b:vimshell.commandline_stack, -1)
  endif

  if vimshell#get_user_prompt() != '' || vimshell#get_right_prompt() != ''
    " Insert user prompt line.
    for user in split(vimshell#get_user_prompt(), "\\n")
      let secondary = '[%] ' . eval(user)
      if line('$') == 1 && getline('.') == ''
        call setline('$', secondary)
      else
        call append('$', secondary)
      endif
    endfor

    " Insert user prompt line.
    if vimshell#get_right_prompt() != ''
      let right_prompt = eval(vimshell#get_right_prompt())
      if right_prompt != ''
        let user_prompt_last = (vimshell#get_user_prompt() != '') ?
              \   getline('$') : '[%] '
        let winwidth = winwidth(0) - 10
        let padding_len =
              \ (len(user_prompt_last)+len(vimshell#get_right_prompt())+1
              \          > winwidth) ?
              \ 1 : winwidth - (len(user_prompt_last)+len(right_prompt))
        let secondary = printf('%s%s%s', user_prompt_last,
              \ repeat(' ', padding_len), right_prompt)
        if vimshell#get_user_prompt() != ''
          call setline('$', secondary)
        else
          call append('$', secondary)
        endif
      endif
    endif
  endif

  " Insert prompt line.
  if line('$') == 1 && getline('.') == ''
    call setline('$', new_prompt)
  else
    call append('$', new_prompt)
  endif

  $
  let &modified = 0
endfunction"}}}
function! vimshell#print_secondary_prompt()"{{{
  if &filetype !=# 'vimshell' || line('.') != line('$')
    return
  endif

  " Insert secondary prompt line.
  call append('$', vimshell#get_secondary_prompt())
  $
  let &modified = 0
endfunction"}}}
function! vimshell#get_command_path(program)"{{{
  " Command search.
  try
    return vimproc#get_command_name(a:program)
  catch /File ".*" is not found./
    " Not found.
    return ''
  endtry
endfunction"}}}
function! vimshell#start_insert(...)"{{{
  if &filetype !=# 'vimshell'
    return
  endif

  let is_insert = (a:0 == 0)? 1 : a:1

  if is_insert
    " Enter insert mode.
    $
    startinsert!

    call vimshell#imdisable()
  else
    normal! $
  endif
endfunction"}}}
function! vimshell#escape_match(str)"{{{
  return escape(a:str, '~" \.^$[]')
endfunction"}}}
function! vimshell#get_prompt()"{{{
  if !exists('s:prompt')
    let s:prompt = exists('g:vimshell_prompt') ?
          \ g:vimshell_prompt : 'vimshell% '
  endif

  return &filetype ==# 'vimshell' && empty(b:vimshell.continuation) ?
        \ s:prompt : exists('b:interactive') ?
        \ vimshell#interactive#get_prompt(line('.'))
        \ : ''
endfunction"}}}
function! vimshell#get_secondary_prompt()"{{{
  if !exists('s:secondary_prompt')
    let s:secondary_prompt = exists('g:vimshell_secondary_prompt') ?
          \ g:vimshell_secondary_prompt : '%% '
  endif

  return s:secondary_prompt
endfunction"}}}
function! vimshell#get_user_prompt()"{{{
  if !exists('s:user_prompt')
    let s:user_prompt = exists('g:vimshell_user_prompt') ?
          \ g:vimshell_user_prompt : ''
  endif

  return s:user_prompt
endfunction"}}}
function! vimshell#get_right_prompt()"{{{
  if !exists('s:right_prompt')
    let s:right_prompt = exists('g:vimshell_right_prompt') ?
          \ g:vimshell_right_prompt : ''
  endif

  return s:right_prompt
endfunction"}}}
function! vimshell#get_cur_text()"{{{
  " Get cursor text without prompt.
  return &filetype == 'vimshell' ?
        \ vimshell#get_cur_line()[len(vimshell#get_prompt()):]
        \ : vimshell#interactive#get_cur_text()
endfunction"}}}
function! vimshell#get_prompt_command(...)"{{{
  " Get command without prompt.
  if a:0 > 0
    return a:1[len(vimshell#get_prompt()):]
  endif

  if !vimshell#check_prompt()
    " Search prompt.
    let [lnum, col] = searchpos('^' . vimshell#escape_match(vimshell#get_prompt()), 'bnW')
  else
    let lnum = '.'
  endif
  let line = getline(lnum)[len(vimshell#get_prompt()):]

  let lnum += 1
  let secondary_prompt = vimshell#get_secondary_prompt()
  while lnum <= line('$') && !vimshell#check_prompt(lnum)
    if vimshell#check_secondary_prompt(lnum)
      " Append secondary command.
      let line .= "\<NL>" . getline(lnum)[len(secondary_prompt):]
    endif

    let lnum += 1
  endwhile

  return line
endfunction"}}}
function! vimshell#set_prompt_command(string)"{{{
  if !vimshell#check_prompt()
    " Search prompt.
    let [lnum, col] = searchpos('^' . vimshell#escape_match(vimshell#get_prompt()), 'bnW')
  else
    let lnum = '.'
  endif

  call setline(lnum, vimshell#get_prompt() . a:string)
endfunction"}}}
function! vimshell#get_cur_line()"{{{
  let cur_text = matchstr(getline('.'), '^.*\%' . col('.') . 'c' . (mode() ==# 'i' ? '' : '.'))
  return cur_text
endfunction"}}}
function! vimshell#get_current_args(...)"{{{
  let cur_text = a:0 == 0 ? vimshell#get_cur_text() : a:1
  let statements = vimproc#parser#split_statements(cur_text)
  if empty(statements)
    return []
  endif

  let commands = vimproc#parser#split_commands(statements[-1])
  if empty(commands)
    return []
  endif

  let args = vimproc#parser#split_args_through(commands[-1])
  if vimshell#get_cur_text() =~ '\\\@!\s\+$'
    " Add blank argument.
    call add(args, '')
  endif

  return args
endfunction"}}}
function! vimshell#get_prompt_linenr()"{{{
  let [line, col] = searchpos('^' . vimshell#escape_match(vimshell#get_prompt()), 'bcW')
  return line
endfunction"}}}
function! vimshell#check_prompt(...)"{{{
  if &filetype !=# 'vimshell' || !empty(b:vimshell.continuation)
    return call('vimshell#interactive#get_prompt', a:000) != ''
  endif

  let line = a:0 == 0 ? getline('.') : getline(a:1)
  return vimshell#head_match(line, vimshell#get_prompt())
endfunction"}}}
function! vimshell#check_secondary_prompt(...)"{{{
  let line = a:0 == 0 ? getline('.') : getline(a:1)
  return vimshell#head_match(line, vimshell#get_secondary_prompt())
endfunction"}}}
function! vimshell#check_user_prompt(...)"{{{
  let line = a:0 == 0 ? line('.') : a:1
  if !vimshell#head_match(getline(line-1), '[%] ')
    " Not found.
    return 0
  endif

  while 1
    let line -= 1

    if !vimshell#head_match(getline(line-1), '[%] ')
      break
    endif
  endwhile

  return line
endfunction"}}}
function! vimshell#set_execute_file(exts, program)"{{{
  for ext in split(a:exts, ',')
    let g:vimshell_execute_file_list[ext] = a:program
  endfor
endfunction"}}}
function! vimshell#system(...)"{{{
  let V = vital#of('vimshell')
  return call(V.system, a:000)
endfunction"}}}
function! vimshell#open(filename)"{{{
  call vimproc#open(a:filename)
endfunction"}}}
function! vimshell#trunk_string(string, max)"{{{
  return printf('%.' . string(a:max-10) . 's..%s', a:string, a:string[-8:])
endfunction"}}}
function! vimshell#iswin()"{{{
  return has('win32') || has('win64')
endfunction"}}}
function! vimshell#resolve(filename)"{{{
  return ((vimshell#iswin() && fnamemodify(a:filename, ':e') ==? 'LNK') || getftype(a:filename) ==# 'link') ?
        \ substitute(resolve(a:filename), '\\', '/', 'g') : a:filename
endfunction"}}}
function! vimshell#get_program_pattern()"{{{
  return
        \'^\s*\%([^[:blank:]]\|\\[^[:alnum:]._-]\)\+\ze\%($\|\s*\%(=\s*\)\?\)'
endfunction"}}}
function! vimshell#get_argument_pattern()"{{{
  return
        \'[^\\]\s\zs\%([^[:blank:]]\|\\[^[:alnum:].-]\)\+$'
endfunction"}}}
function! vimshell#get_alias_pattern()"{{{
  return '^\s*[[:alnum:].+#_@!%-]\+'
endfunction"}}}
function! vimshell#cd(directory)"{{{
  execute g:vimshell_cd_command '`=a:directory`'

  if exists('*unite#sources#directory_mru#_append')
    " Append directory.
    call unite#sources#directory_mru#_append()
  endif
endfunction"}}}
function! vimshell#compare_number(i1, i2)"{{{
  return a:i1 == a:i2 ? 0 : a:i1 > a:i2 ? 1 : -1
endfunction"}}}
function! vimshell#alternate_buffer()"{{{
  if bufnr('%') != bufnr('#') && buflisted(bufnr('#'))
    buffer #
    return
  endif

  " Search other buffer.
  let cnt = 0
  let pos = 1
  let current = 0
  while pos <= bufnr('$')
    if buflisted(pos)
      if pos == bufnr('%')
        let current = cnt
      endif

      let cnt += 1
    endif

    let pos += 1
  endwhile

  if current > cnt / 2
    bprevious
  else
    bnext
  endif
endfunction"}}}
function! vimshell#imdisable()"{{{
  " Disable input method.
  if exists('g:loaded_eskk') && (!exists('g:eskk_disable') || !g:eskk_disable) && eskk#is_enabled()
    call eskk#disable()
  elseif exists('b:skk_on') && b:skk_on && exists('*SkkDisable')
    call SkkDisable()
  elseif exists('&iminsert')
    let &l:iminsert = 0
  endif
endfunction"}}}
function! vimshell#set_variables(variables)"{{{
  let variables_save = {}
  for [key, value] in items(a:variables)
    let save_value = exists(key) ? eval(key) : ''

    let variables_save[key] = save_value
    execute 'let' key '= value'
  endfor

  return variables_save
endfunction"}}}
function! vimshell#restore_variables(variables)"{{{
  for [key, value] in items(a:variables)
    execute 'let' key '= value'
  endfor
endfunction"}}}
function! vimshell#check_cursor_is_end()"{{{
  return vimshell#get_cur_line() ==# getline('.')
endfunction"}}}
function! vimshell#execute_current_line(is_insert)"{{{
  return &filetype ==# 'vimshell' ?
        \ vimshell#mappings#execute_line(a:is_insert) :
        \ vimshell#int_mappings#execute_line(a:is_insert)
endfunction"}}}
function! vimshell#get_cursor_filename()"{{{
  let filename_pattern = (b:interactive.type ==# 'vimshell') ?
        \ '\%([[:alnum:];/?:@&=+$,_.!~*''|()-]\+[ ]\)*[[:alnum:];/?:@&=+$,_.!~*''|()-]\+' :
        \ '[[:alnum:];/?:@&=+$,_.!~*''|()-]\+'
  let filename = matchstr(getline('.')[: col('.')-1], filename_pattern . '$')
        \ . matchstr(getline('.')[col('.') :], '^'.filename_pattern)

  if has('conceal') && b:interactive.type ==# 'vimshell' && filename =~ '\[\%[%\]]\|^%$'
    " Skip user prompt.
    let filename = matchstr(getline('.'), filename_pattern, 3)
  endif

  return expand(filename)
endfunction"}}}
function! vimshell#is_cmdwin()"{{{
  silent! noautocmd wincmd p
  silent! noautocmd wincmd p
  return v:errmsg =~ '^E11:'
endfunction"}}}
function! vimshell#next_prompt(context, is_insert)"{{{
  if &filetype !=# 'vimshell'
    return
  endif

  if line('.') == line('$')
    call vimshell#print_prompt(a:context)
    call vimshell#start_insert(a:is_insert)
  else
    call search('^' . vimshell#escape_match(vimshell#get_prompt()).'.\?', 'We')
    if a:is_insert
      if vimshell#get_prompt_command() == ''
        startinsert!
      else
        normal! l
      endif
    endif

    stopinsert
  endif
endfunction"}}}
function! vimshell#split(command)"{{{
  let old_pos = [ tabpagenr(), winnr(), bufnr('%'), getpos('.') ]
  if a:command != ''
    let command =
          \ a:command !=# 'nicely' ? a:command :
          \ winwidth(0) > 2 * &winwidth ? 'vsplit' : 'split'
    execute command
  endif

  let new_pos = [ tabpagenr(), winnr(), bufnr('%'), getpos('.')]

  return [new_pos, old_pos]
endfunction"}}}
function! vimshell#restore_pos(pos)"{{{
  if tabpagenr() != a:pos[0]
    execute 'tabnext' a:pos[0]
  endif

  if winnr() != a:pos[1]
    execute a:pos[1].'wincmd w'
  endif

  if bufnr('%') != a:pos[2]
    execute 'buffer' a:pos[2]
  endif

  call setpos('.', a:pos[3])
endfunction"}}}
"}}}

" User helper functions.
function! vimshell#execute(cmdline, ...)"{{{
  let context = a:0 >= 1? a:1 : vimshell#get_context()
  try
    call vimshell#parser#eval_script(a:cmdline, context)
  catch /.*/
    let message = v:exception . ' ' . v:throwpoint
    call vimshell#error_line(context.fd, message)
    return 1
  endtry

  return b:vimshell.system_variables.status
endfunction"}}}
function! vimshell#set_context(context)"{{{
  let s:context = a:context
endfunction"}}}
function! vimshell#get_context()"{{{
  if exists('b:vimshell') && has_key(b:vimshell.continuation, 'context')
    return b:vimshell.continuation.context
  elseif !exists('s:context')
    " Set context.
    let context = {
      \ 'has_head_spaces' : 0,
      \ 'is_interactive' : 0,
      \ 'is_insert' : 0,
      \ 'fd' : { 'stdin' : '', 'stdout': '', 'stderr': ''},
      \}

    call vimshell#set_context(context)
  endif

  return s:context
endfunction"}}}
function! vimshell#set_alias(name, value)"{{{
  if !exists('b:vimshell')
    let b:vimshell = {}
  endif
  if !has_key(b:vimshell, 'alias_table')
    let b:vimshell.alias_table = {}
  endif

  if a:value == ''
    " Delete alias.
    call remove(b:vimshell.alias_table, a:name)
  else
    let b:vimshell.alias_table[a:name] = a:value
  endif
endfunction"}}}
function! vimshell#get_alias(name)"{{{
  return get(b:vimshell.alias_table, a:name, '')
endfunction"}}}
function! vimshell#set_galias(name, value)"{{{
  if !exists('b:vimshell')
    let b:vimshell = {}
  endif
  if !has_key(b:vimshell, 'galias_table')
    let b:vimshell.galias_table = {}
  endif

  if a:value == ''
    " Delete alias.
    call remove(b:vimshell.galias_table, a:name)
  else
    let b:vimshell.galias_table[a:name] = a:value
  endif
endfunction"}}}
function! vimshell#get_galias(name)"{{{
  return get(b:vimshell.galias_table, a:name, '')
endfunction"}}}
function! vimshell#set_syntax(syntax_name)"{{{
  let b:interactive.syntax = a:syntax_name
endfunction"}}}

function! s:init_internal_commands()"{{{
  " Initialize internal commands table.
  let s:internal_commands= {}

  " Search autoload.
  for list in split(globpath(&runtimepath, 'autoload/vimshell/commands/*.vim'), '\n')
    let command_name = fnamemodify(list, ':t:r')
    if !has_key(s:internal_commands, command_name)
      let result = {'vimshell#commands#'.command_name.'#define'}()

      for command in (type(result) == type([])) ?
            \ result : [result]
        if !has_key(command, 'description')
          let command.description = ''
        endif

        let s:internal_commands[command.name] = command
      endfor

      unlet result
    endif
  endfor
endfunction"}}}
function! s:switch_vimshell(bufnr, split_flag, directory)"{{{
  let winheight = a:split_flag ?
        \ winheight(0)*g:vimshell_split_height/100 : 0
  if a:split_flag
    execute winheight 'sbuffer' a:bufnr
  else
    execute 'buffer' a:bufnr
  endif

  if a:directory != '' && isdirectory(a:directory)
    " Change current directory.
    let current = fnamemodify(a:directory, ':p')
    let b:vimshell.current_dir = current
    call vimshell#cd(current)
  endif

  if getline('$') ==# vimshell#get_prompt()
    " Delete current prompt.
    let promptnr = vimshell#check_user_prompt(line('$')) > 0 ?
          \ vimshell#check_user_prompt(line('$')) . ',' : ''
    execute 'silent ' . promptnr . '$delete _'
  endif

  call vimshell#print_prompt()
  call vimshell#start_insert()
endfunction"}}}

" Auto commands function.
function! s:event_bufwin_enter()"{{{
  if &updatetime > g:vimshell_interactive_update_time
    let s:update_time_save = &updatetime
    let &updatetime = g:vimshell_interactive_update_time
  endif

  if has('conceal')
    setlocal conceallevel=3
    setlocal concealcursor=nvi
  endif

  if !exists('b:vimshell') ||
        \ !isdirectory(b:vimshell.current_dir)
    return
  endif

  call vimshell#cd(fnamemodify(b:vimshell.current_dir, ':p'))
endfunction"}}}
function! s:event_bufwin_leave()"{{{
  let s:last_vimshell_bufnr = bufnr('%')

  if &updatetime < s:update_time_save
    let &updatetime = s:update_time_save
  endif
endfunction"}}}
function! s:color_scheme()"{{{
  if has('gui_running')
    hi VimShellPrompt  gui=UNDERLINE guifg=#80ffff guibg=NONE
  else
    hi def link VimShellPrompt Identifier
  endif
endfunction"}}}

" vim: foldmethod=marker
