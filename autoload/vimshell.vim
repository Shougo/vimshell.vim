"=============================================================================
" FILE: vimshell.vim
" AUTHOR: Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 18 Jul 2012.
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
  return '901'
endfunction"}}}

function! vimshell#echo_error(string)"{{{
  echohl Error | echo a:string | echohl None
endfunction"}}}

" Check vimproc."{{{
try
  let s:exists_vimproc_version = vimproc#version()
catch
  call vimshell#echo_error(v:errmsg)
  call vimshell#echo_error(v:exception)
  call vimshell#echo_error('Error occured while loading vimproc.')
  call vimshell#echo_error('Please install vimproc Ver.6.0 or above.')
  finish
endtry
if s:exists_vimproc_version < 600
  call vimshell#echo_error('Your vimproc is too old.')
  call vimshell#echo_error('Please install vimproc Ver.6.0 or above.')
  finish
endif"}}}

" Initialize."{{{
if !exists('g:vimshell_execute_file_list')
  let g:vimshell_execute_file_list = {}
endif
if !exists('s:internal_commands')
  let s:internal_commands = {}
endif

let s:last_vimshell_bufnr = -1

let s:vimshell_options = [
      \ '-buffer-name=', '-toggle', '-create',
      \ '-split', '-split-command=', '-popup',
      \ '-winwidth=', '-winminwidth=',
      \]
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
  setlocal bufhidden=hide
  setlocal buftype=nofile
  setlocal nolist
  setlocal noswapfile
  setlocal tabstop=8
  setlocal foldcolumn=0
  setlocal foldmethod=manual
  setlocal winfixheight
  if has('conceal')
    setlocal conceallevel=3
    setlocal concealcursor=nvi
  endif
  if exists('&colorcolumn')
    setlocal colorcolumn=
  endif

  " For vimshell.
  setlocal bufhidden=hide
  setlocal noreadonly
  setlocal iskeyword+=-,+,\\,!,~
  setlocal wrap

  " Set autocommands.
  augroup vimshell
    autocmd BufWinEnter,WinEnter <buffer> call s:event_bufwin_enter()
    autocmd BufWinLeave,WinLeave <buffer> call s:event_bufwin_leave()
    autocmd CursorMoved <buffer> call vimshell#interactive#check_current_output()
  augroup end

  call s:event_bufwin_enter()

  " Define mappings.
  call vimshell#mappings#define_default_mappings()
endfunction"}}}
function! vimshell#set_dictionary_helper(variable, keys, value)"{{{
  return vimshell#util#set_default_dictionary_helper(a:variable, a:keys, a:value)
endfunction"}}}

" vimshell plugin utility functions."{{{
function! vimshell#switch_shell(path, ...)"{{{
  if vimshell#util#is_cmdwin()
    call vimshell#echo_error(
          \ '[vimshell] Command line buffer is detected!')
    call vimshell#echo_error(
          \ '[vimshell] Please close command line buffer.')
    return
  endif

  " Detect autochdir option."{{{
  if &autochdir
    call vimshell#echo_error(
          \ '[vimshell] Detected autochdir!')
    call vimshell#echo_error(
          \ '[vimshell] vimshell don''t work if you set autochdir option.')
    return
  endif
  "}}}

  let path = a:path
  if path != ''
    let path = vimshell#util#substitute_path_separator(
          \ fnamemodify(vimshell#util#expand(a:path), ':p'))
  endif

  let context = s:initialize_context(get(a:000, 0, {}))

  if context.create
    " Create shell buffer.
    call s:create_shell(path, context)
    return
  elseif &filetype ==# 'vimshell'
    " Search vimshell buffer.
    call s:switch_vimshell(bufnr('%'), context, path)
    return
  elseif context.toggle
        \ && vimshell#close(context.buffer_name)
    return
  endif

  if buflisted(s:last_vimshell_bufnr)
        \ && getbufvar(s:last_vimshell_bufnr, '&filetype') ==# 'vimshell'
        \ && (!exists('t:unite_buffer_dictionary')
        \    || has_key(t:unite_buffer_dictionary, s:last_vimshell_bufnr))
    call s:switch_vimshell(s:last_vimshell_bufnr, context, path)
    return
  else
    for bufnr in filter(range(1, bufnr('$')),
          \ "getbufvar(v:val, '&filetype') ==# 'vimshell'")
      if (!exists('t:unite_buffer_dictionary')
            \    || has_key(t:unite_buffer_dictionary, bufnr))
        call s:switch_vimshell(bufnr, context, path)
        return
      endif
    endfor
  endif

  " Create shell buffer.
  call s:create_shell(path, context)
endfunction"}}}
function! s:create_shell(path, context)"{{{
  let path = a:path
  if path == ''
    " Use current directory.
    let path = vimshell#util#substitute_path_separator(getcwd())
  endif

  let context = a:context

  " Create new buffer.
  let prefix = vimshell#util#is_windows() ?
        \ '[vimshell]' : '*vimshell*'
  let postfix = ' - 1'
  let cnt = 1
  while buflisted(prefix.postfix)
    let cnt += 1
    let postfix = ' - ' . cnt
  endwhile
  let bufname = prefix.postfix

  if a:context.split_command != ''
    let [new_pos, old_pos] =
          \ vimshell#split(a:context.split_command)
  endif

  silent edit! `=bufname`

  call s:initialize_vimshell(path, a:context)

  call vimshell#print_prompt(a:context)

  call vimshell#start_insert()
  call vimshell#interactive#set_send_buffer(bufname('%'))

  " Check prompt value."{{{
  if vimshell#head_match(vimshell#get_prompt(), vimshell#get_secondary_prompt())
        \ || vimshell#head_match(vimshell#get_secondary_prompt(), vimshell#get_prompt())
    call vimshell#echo_error(printf('Head matched g:vimshell_prompt("%s")'.
          \ ' and your g:vimshell_secondary_prompt("%s").',
          \ vimshell#get_prompt(), vimshell#get_secondary_prompt()))
    finish
  elseif vimshell#head_match(vimshell#get_prompt(), '[%] ')
        \ || vimshell#head_match('[%] ', vimshell#get_prompt())
    call vimshell#echo_error(printf('Head matched g:vimshell_prompt("%s")'.
          \ ' and your g:vimshell_user_prompt("[%] ").', vimshell#get_prompt()))
    finish
  elseif vimshell#head_match('[%] ', vimshell#get_secondary_prompt())
        \ || vimshell#head_match(vimshell#get_secondary_prompt(), '[%] ')
    call vimshell#echo_error(printf('Head matched g:vimshell_user_prompt("[%] ")'.
          \ ' and your g:vimshell_secondary_prompt("%s").',
          \ vimshell#get_secondary_prompt()))
    finish
  endif"}}}

  " Set undo point.
  call feedkeys("\<C-g>u", 'n')
endfunction"}}}

function! vimshell#get_options()"{{{
  return copy(s:vimshell_options)
endfunction"}}}
function! vimshell#close(buffer_name)"{{{
  let buffer_name = a:buffer_name
  if buffer_name !~ '@\d\+$'
    " Add postfix.
    let prefix = vimshell#util#is_windows() ? '[vimshell] - ' : '*vimshell* - '
    let prefix .= buffer_name
    let buffer_name = prefix . s:get_postfix(prefix, 0)
  endif

  " Note: must escape file-pattern.
  let buffer_name =
        \ vimshell#util#escape_file_searching(buffer_name)

  let quit_winnr = bufwinnr(buffer_name)
  if quit_winnr > 0
    " Hide unite buffer.
    silent execute quit_winnr 'wincmd w'

    if winnr('$') != 1
      close
    else
      call vimshell#util#alternate_buffer()
    endif
  endif

  return quit_winnr > 0
endfunction"}}}
function! vimshell#available_commands()"{{{
  return s:internal_commands
endfunction"}}}
function! vimshell#execute_internal_command(command, args, context)"{{{
  if empty(s:internal_commands)
    call s:initialize_internal_commands()
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
    if vimshell#util#is_windows()
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

  if vimshell#get_user_prompt() != '' ||
        \ vimshell#get_right_prompt() != ''
    " Insert user prompt line.
    call s:insert_user_and_right_prompt()
  endif

  " Insert prompt line.
  if getline('$') == ''
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
function! vimshell#get_prompt(...)"{{{
  let line = get(a:000, 0, line('.'))
  let interactive = get(a:000, 1,
        \ (exists('b:interactive') ? b:interactive : {}))
  if empty(interactive)
    return ''
  endif

  if !exists('s:prompt')
    let s:prompt = exists('g:vimshell_prompt') ?
          \ g:vimshell_prompt : 'vimshell% '
  endif

  return &filetype ==# 'vimshell' && empty(b:vimshell.continuation) ?
        \ s:prompt :
        \ vimshell#interactive#get_prompt(line, interactive)
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
    let [lnum, col] = searchpos('^' .
          \ vimshell#escape_match(vimshell#get_prompt()), 'bnW')
  else
    let lnum = '.'
  endif
  let line = getline(lnum)[len(vimshell#get_prompt()):]

  let lnum += 1
  let secondary_prompt = vimshell#get_secondary_prompt()
  while lnum <= line('$') && !vimshell#check_prompt(lnum)
    if vimshell#check_secondary_prompt(lnum)
      " Append secondary command.
      if line =~ '\\$'
        let line = substitute(line, '\\$', '', '')
      else
        let line .= "\<NL>"
      endif

      let line .= getline(lnum)[len(secondary_prompt):]
    endif

    let lnum += 1
  endwhile

  return line
endfunction"}}}
function! vimshell#set_prompt_command(string)"{{{
  if !vimshell#check_prompt()
    " Search prompt.
    let [lnum, col] = searchpos('^'
          \ . vimshell#escape_match(vimshell#get_prompt()), 'bnW')
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
  if b:interactive.type !=# 'interactive'
        \ && b:interactive.type !=# 'vimshell'
    return 0
  endif

  let [line, col] = searchpos('^' .
        \ vimshell#escape_match(vimshell#get_prompt()), 'nbcW')
  return line
endfunction"}}}
function! vimshell#check_prompt(...)"{{{
  if &filetype !=# 'vimshell' || !empty(b:vimshell.continuation)
    return call('vimshell#get_prompt', a:000) != ''
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
  return vimshell#util#set_dictionary_helper(g:vimshell_execute_file_list,
        \ a:exts, a:program)
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
function! vimshell#is_windows()"{{{
  return has('win32') || has('win64')
endfunction"}}}
function! vimshell#resolve(filename)"{{{
  return ((vimshell#util#is_windows() && fnamemodify(a:filename, ':e') ==? 'LNK') || getftype(a:filename) ==# 'link') ?
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
  return '^\s*[[:alnum:].+#_@!%:-]\+'
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
        \'\s\?\%(\f\+\s\)*\f\+' :
        \'[[:alnum:];/?:@&=+$,_.!~*|-]\+'
  let cur_text = matchstr(getline('.'), '^.*\%'
        \ . col('.') . 'c' . (mode() ==# 'i' ? '' : '.'))
  let next_text = matchstr('a'.getline('.')[len(cur_text) :],
        \ '^'.filename_pattern)[1:]
  let filename = matchstr(cur_text, filename_pattern . '$') . next_text

  if has('conceal') && b:interactive.type ==# 'vimshell'
        \ && filename =~ '\[\%[%\]]\|^%$'
    " Skip user prompt.
    let filename = matchstr(getline('.'), filename_pattern, 3)
  endif

  return vimshell#util#expand(filename)
endfunction"}}}
function! vimshell#next_prompt(context, is_insert)"{{{
  if &filetype !=# 'vimshell'
    return
  endif

  if line('.') == line('$')
    call vimshell#print_prompt(a:context)
    call vimshell#start_insert(a:is_insert)
    return
  endif

  " Search prompt.
  call search('^' . vimshell#escape_match(vimshell#get_prompt()).'.\?', 'We')
  if a:is_insert
    if vimshell#get_prompt_command() == ''
      startinsert!
    else
      normal! l
    endif
  endif

  stopinsert
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
function! vimshell#get_editor_name()"{{{
  if !exists('g:vimshell_editor_command')
    " Set editor command.
    if has('clientserver') && (has('gui_running') || has('gui'))
      if has('gui_macvim')
        " MacVim check.
        if executable('/Applications/MacVim.app/Contents/MacOS/Vim')
          let progname = 'Applications/MacVim.app/Contents/MacOS/Vim -g'
        elseif executable(expand('~/Applications/MacVim.app/Contents/MacOS/Vim'))
          let progname = expand('~/Applications/MacVim.app/Contents/MacOS/Vim -g')               
        else
          echoerr 'You installed MacVim in not default directory! You must set g:vimshell_editor_command manually.'
          return g:vimshell_cat_command
        endif

        let progname = '/Applications/MacVim.app/Contents/MacOS/Vim -g'
      else
        let progname = has('gui_running') ? v:progname : 'vim -g'
      endif

      let g:vimshell_editor_command = printf('%s %s --remote-tab-wait-silent',
            \ progname, (v:servername == '' ? '' : ' --servername='.v:servername))
    else
      let g:vimshell_editor_command = g:vimshell_cat_command
    endif
  endif

  return g:vimshell_editor_command
endfunction"}}}
function! vimshell#is_interactive()"{{{
  let is_valid = get(get(b:interactive, 'process', {}), 'is_valid', 0)
  return b:interactive.type ==# 'interactive'
        \ || (b:interactive.type ==# 'vimshell' && is_valid)
endfunction"}}}
"}}}

" User helper functions.
function! vimshell#execute(cmdline, ...)"{{{
  let context = a:0 >= 1? a:1 : vimshell#get_context()
  try
    call vimshell#parser#eval_script(a:cmdline, context)
  catch
    let message = v:exception . ' ' . v:throwpoint
    call vimshell#error_line(context.fd, message)
    return 1
  endtry

  return b:vimshell.system_variables.status
endfunction"}}}
function! vimshell#set_context(context)"{{{
  let s:context = a:context
  if exists('b:vimshell')
    let b:vimshell.context = a:context
  endif
endfunction"}}}
function! vimshell#get_context()"{{{
  if exists('b:vimshell')
    return has_key(b:vimshell.continuation, 'context') ?
          \ b:vimshell.continuation.context : b:vimshell.context
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

function! s:initialize_vimshell(path, context)"{{{
  if empty(s:internal_commands)
    call s:initialize_internal_commands()
  endif

  " Load history.
  let g:vimshell#hist_buffer = vimshell#history#read()

  " Initialize variables.
  let b:vimshell = {}

  " Change current directory.
  let b:vimshell.current_dir = a:path
  call vimshell#cd(a:path)

  let b:vimshell.alias_table = {}
  let b:vimshell.galias_table = {}
  let b:vimshell.altercmd_table = {}
  let b:vimshell.commandline_stack = []
  let b:vimshell.variables = {}
  let b:vimshell.system_variables = { 'status' : 0 }
  let b:vimshell.directory_stack = []
  let b:vimshell.prompt_current_dir = {}
  let b:vimshell.continuation = {}
  let b:vimshell.prompts_save = {}

  " Default settings.
  call s:default_settings()

  call vimshell#set_context(a:context)

  " Set interactive variables.
  let b:interactive = {
        \ 'type' : 'vimshell',
        \ 'syntax' : 'vimshell',
        \ 'process' : {},
        \ 'continuation' : {},
        \ 'fd' : a:context.fd,
        \ 'encoding' : &encoding,
        \ 'is_pty' : 0,
        \ 'echoback_linenr' : -1,
        \ 'stdout_cache' : '',
        \ 'stderr_cache' : '',
        \ 'hook_functions_table' : {},
        \}

  " Load rc file.
  if filereadable(g:vimshell_vimshrc_path)
    call vimshell#execute_internal_command('vimsh',
          \ [g:vimshell_vimshrc_path],
          \ { 'has_head_spaces' : 0, 'is_interactive' : 0 })
    let b:vimshell.loaded_vimshrc = 1
  endif

  setfiletype vimshell

  call vimshell#help#init()
  call vimshell#interactive#init()
endfunction"}}}
function! s:initialize_context(context)"{{{
  let default_context = {
    \ 'buffer_name' : 'default',
    \ 'no_quit' : 0,
    \ 'toggle' : 0,
    \ 'create' : 0,
    \ 'simple' : 0,
    \ 'split' : 0,
    \ 'popup' : 0,
    \ 'winwidth' : 0,
    \ 'winminwidth' : 0,
    \ 'direction' : '',
    \ }
  let context = extend(default_context, a:context)

  " Complex initializer.
  if !has_key(context, 'profile_name')
    let context.profile_name = context.buffer_name
  endif
  if !has_key(context, 'split_command')
    if context.popup && g:vimshell_popup_command == ''
      " Default popup command.
      let context.split_command = 'split | resize '
            \ . winheight(0)*g:vimshell_popup_height/100
    elseif context.popup
      let context.split_command = g:vimshell_popup_command
    elseif context.split
      let context.split_command = g:vimshell_split_command
    else
      let context.split_command = ''
    endif
  endif
  if &l:modified && !&l:hidden
    " Split automatically.
    let context.split = 1
  endif

  " Initialize.
  let context.has_head_spaces = 0
  let context.is_interactive = 1
  let context.is_insert = 1
  let context.fd = { 'stdin' : '', 'stdout': '', 'stderr': ''}

  return context
endfunction"}}}
function! s:initialize_internal_commands()"{{{
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
function! s:switch_vimshell(bufnr, context, path)"{{{
  if bufwinnr(a:bufnr) > 0
    execute bufwinnr(a:bufnr) 'wincmd w'
  else
    if a:context.split_command != ''
      let [new_pos, old_pos] =
            \ vimshell#split(a:context.split_command)
    endif

    execute 'buffer' a:bufnr
  endif

  if a:path != '' && isdirectory(a:path)
    " Change current directory.
    let current = fnamemodify(a:path, ':p')
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
function! s:get_postfix(prefix, is_create)"{{{
  let postfix = '@1'
  let cnt = 1

  if a:is_create
    let tabnr = 1
    while tabnr <= tabpagenr('$')
      let buflist = map(tabpagebuflist(tabnr), 'bufname(v:val)')
      if index(buflist, a:prefix.postfix) >= 0
        let cnt += 1
        let postfix = '@' . cnt
      endif

      let tabnr += 1
    endwhile
  else
    let buflist = map(tabpagebuflist(tabpagenr()), 'bufname(v:val)')
    for bufname in buflist
      if stridx(bufname, a:prefix) >= 0
        return matchstr(bufname, '@\d\+$')
      endif
    endfor
  endif

  return postfix
endfunction"}}}
function! vimshell#complete(arglead, cmdline, cursorpos)"{{{
  let _ = []

  " Option names completion.
  try
    let _ += filter(vimfiler#get_options(),
          \ 'stridx(v:val, a:arglead) == 0')
  catch
  endtry

  " Directory name completion.
  let _ += filter(map(split(glob(a:arglead . '*'), '\n'),
        \ "isdirectory(v:val) ? v:val.'/' : v:val"),
        \ 'stridx(v:val, a:arglead) == 0')

  return sort(_)
endfunction"}}}
function! vimshell#vimshell_execute_complete(arglead, cmdline, cursorpos)"{{{
  " Get complete words.
  return map(vimshell#complete#command_complete#get_candidates(
        \ a:cmdline, 0, a:arglead), 'v:val.word')
endfunction"}}}
function! s:insert_user_and_right_prompt()"{{{
  for user in split(vimshell#get_user_prompt(), "\\n")
    try
      let secondary = '[%] ' . eval(user)
    catch
      let message = v:exception . ' ' . v:throwpoint
      echohl WarningMsg | echomsg message | echohl None

      let secondary = '[%] '
    endtry

    if getline('$') == ''
      call setline('$', secondary)
    else
      call append('$', secondary)
    endif
  endfor

  " Insert right prompt line.
  if vimshell#get_right_prompt() == ''
    return
  endif

  try
    let right_prompt = eval(vimshell#get_right_prompt())
  catch
    let message = v:exception . ' ' . v:throwpoint
    echohl WarningMsg | echomsg message | echohl None

    let right_prompt = ''
  endtry

  if right_prompt == ''
    return
  endif

  let user_prompt_last = (vimshell#get_user_prompt() != '') ?
        \   getline('$') : '[%] '
  let winwidth = (winwidth(0)+1)/2*2 - 5
  let padding_len =
        \ (len(user_prompt_last)+len(vimshell#get_right_prompt())+1
        \          > winwidth) ?
        \ 1 : winwidth - (len(user_prompt_last)+len(right_prompt))
  let secondary = printf('%s%s%s', user_prompt_last,
        \ repeat(' ', padding_len), right_prompt)
  if getline('$') == '' || vimshell#get_user_prompt() != ''
    call setline('$', secondary)
  else
    call append('$', secondary)
  endif

  let prompts_save = {}
  let prompts_save.right_prompt = right_prompt
  let prompts_save.user_prompt_last = user_prompt_last
  let prompts_save.winwidth = winwidth
  let b:vimshell.prompts_save[line('$')] = prompts_save
endfunction"}}}

" Auto commands function.
function! s:event_bufwin_enter()"{{{
  if has('conceal')
    setlocal conceallevel=3
    setlocal concealcursor=nvi
  endif

  setlocal nolist

  if !exists('b:vimshell') ||
        \ !isdirectory(b:vimshell.current_dir)
    return
  endif

  call vimshell#cd(fnamemodify(b:vimshell.current_dir, ':p'))

  " Redraw right prompt.
  let winwidth = (winwidth(0)+1)/2*2 - 5
  for [line, prompts] in items(b:vimshell.prompts_save)
    if getline(line) =~ '^\[%] .*\S$'
          \ && prompts.winwidth != winwidth
      let right_prompt = prompts.right_prompt
      let user_prompt_last = prompts.user_prompt_last

      let padding_len =
            \ (len(user_prompt_last)+
            \  len(right_prompt)+1
            \          > winwidth) ?
            \ 1 : winwidth - (len(user_prompt_last)+len(right_prompt))
      let secondary = printf('%s%s%s', user_prompt_last,
            \ repeat(' ', padding_len), right_prompt)
      call setline(line, secondary)
    endif
  endfor
endfunction"}}}
function! s:event_bufwin_leave()"{{{
  let s:last_vimshell_bufnr = bufnr('%')
endfunction"}}}

" vim: foldmethod=marker
