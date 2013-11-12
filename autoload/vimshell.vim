"=============================================================================
" FILE: vimshell.vim
" AUTHOR: Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 12 Nov 2013.
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

if !exists('g:loaded_vimshell')
  runtime! plugin/vimshell.vim
endif

function! vimshell#version() "{{{
  return '1000'
endfunction"}}}

function! vimshell#echo_error(string) "{{{
  echohl Error | echo a:string | echohl None
endfunction"}}}

" Check vimproc. "{{{
if !vimshell#util#has_vimproc()
  call vimshell#echo_error(v:errmsg)
  call vimshell#echo_error(v:exception)
  call vimshell#echo_error('Error occured while loading vimproc.')
  call vimshell#echo_error('Please install vimproc Ver.6.0 or above.')
  finish
endif

if vimproc#version() < 600
  call vimshell#echo_error('Your vimproc is too old.')
  call vimshell#echo_error('Please install vimproc Ver.6.0 or above.')
  finish
endif"}}}

" Initialize. "{{{
if !exists('g:vimshell_execute_file_list')
  let g:vimshell_execute_file_list = {}
endif
if !exists('s:internal_commands')
  let s:internal_commands = {}
endif

let s:vimshell_options = [
      \ '-buffer-name=', '-toggle', '-create',
      \ '-split', '-split-command=', '-popup',
      \ '-winwidth=', '-winminwidth=',
      \ '-prompt=', '-secondary-prompt=',
      \ '-user-prompt=', '-right-prompt=',
      \ '-prompt-expr=', '-prompt-pattern=',
      \ '-project',
      \]

let s:BM = vimshell#util#get_vital().import('Vim.BufferManager')
let s:manager = s:BM.new()  " creates new manager
call s:manager.config('opener', 'silent edit')
call s:manager.config('range', 'current')
"}}}

function! vimshell#head_match(checkstr, headstr) "{{{
  return stridx(a:checkstr, a:headstr) == 0
endfunction"}}}
function! vimshell#tail_match(checkstr, tailstr) "{{{
  return a:tailstr == '' || a:checkstr ==# a:tailstr
        \|| a:checkstr[: -len(a:tailstr)-1] ==# a:tailstr
endfunction"}}}

" User utility functions.
function! s:default_settings() "{{{
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

  " Set autocommands.
  augroup vimshell
    autocmd BufDelete,VimLeavePre <buffer>
          \ call vimshell#interactive#hang_up(expand('<afile>'))
    autocmd BufEnter,BufWinEnter,WinEnter <buffer>
          \ call vimshell#handlers#_on_bufwin_enter(expand('<abuf>'))
    autocmd BufLeave,BufWinLeave,WinLeave <buffer>
          \ call vimshell#handlers#_on_bufwin_leave()
    autocmd CursorMoved <buffer>
          \ call vimshell#interactive#check_current_output()
  augroup end

  call vimshell#handlers#_on_bufwin_enter(bufnr('%'))

  " Define mappings.
  call vimshell#mappings#define_default_mappings()
endfunction"}}}
function! vimshell#set_dictionary_helper(variable, keys, value) "{{{
  return vimshell#util#set_default_dictionary_helper(a:variable, a:keys, a:value)
endfunction"}}}

" vimshell plugin utility functions. "{{{
function! vimshell#start(path, ...) "{{{
  if vimshell#util#is_cmdwin()
    call vimshell#echo_error(
          \ '[vimshell] Command line buffer is detected!')
    call vimshell#echo_error(
          \ '[vimshell] Please close command line buffer.')
    return
  endif

  " Detect autochdir option. "{{{
  if exists('+autochdir') && &autochdir
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
  elseif context.toggle
        \ && vimshell#close(context.buffer_name)
    return
  elseif &filetype ==# 'vimshell'
    " Search vimshell buffer.
    call s:switch_vimshell(bufnr('%'), context, path)
    return
  endif

  if !exists('t:vimshell')
    call vimshell#initialize_tab_variable()
  endif
  for bufnr in filter(insert(range(1, bufnr('$')),
        \ t:vimshell.last_vimshell_bufnr),
        \ "buflisted(v:val) &&
        \  getbufvar(v:val, '&filetype') ==# 'vimshell'")
    if (!exists('t:unite_buffer_dictionary')
          \    || has_key(t:unite_buffer_dictionary, bufnr))
      call s:switch_vimshell(bufnr, context, path)
      return
    endif
  endfor

  " Create shell buffer.
  call s:create_shell(path, context)
endfunction"}}}
function! s:create_shell(path, context) "{{{
  let path = a:path
  if path == ''
    " Use current directory.
    let path = vimshell#util#substitute_path_separator(getcwd())
  endif

  if a:context.project
    let path = vimshell#util#path2project_directory(path)
  endif

  let context = a:context

  " Create new buffer.
  let prefix = '[vimshell] - '
  let prefix .= a:context.profile_name
  let postfix = s:get_postfix(prefix, 1)
  let bufname = prefix . postfix

  if a:context.split_command != ''
    let [new_pos, old_pos] =
          \ vimshell#split(a:context.split_command)
  endif

  " Save swapfile option.
  let swapfile_save = &swapfile
  set noswapfile

  try
    let ret = s:manager.open(bufname)
  finally
    let &swapfile = swapfile_save
  endtry

  if !ret.loaded
    call vimshell#echo_error(
          \ '[vimshell] Failed to open Buffer.')
    return
  endif

  call s:initialize_vimshell(path, a:context)
  call vimshell#interactive#set_send_buffer(bufname('%'))

  call vimshell#print_prompt(a:context)

  call vimshell#start_insert()

  " Check prompt value. "{{{
  let prompt = vimshell#get_prompt()
  if vimshell#head_match(prompt, vimshell#get_secondary_prompt())
        \ || vimshell#head_match(vimshell#get_secondary_prompt(), prompt)
    call vimshell#echo_error(printf('Head matched g:vimshell_prompt("%s")'.
          \ ' and your g:vimshell_secondary_prompt("%s").',
          \ prompt, vimshell#get_secondary_prompt()))
    finish
  elseif vimshell#head_match(prompt, '[%] ')
        \ || vimshell#head_match('[%] ', prompt)
    call vimshell#echo_error(printf('Head matched g:vimshell_prompt("%s")'.
          \ ' and your g:vimshell_user_prompt("[%] ").', prompt))
    finish
  elseif vimshell#head_match('[%] ', vimshell#get_secondary_prompt())
        \ || vimshell#head_match(vimshell#get_secondary_prompt(), '[%] ')
    call vimshell#echo_error(printf('Head matched g:vimshell_user_prompt("[%] ")'.
          \ ' and your g:vimshell_secondary_prompt("%s").',
          \ vimshell#get_secondary_prompt()))
    finish
  endif"}}}
endfunction"}}}

function! vimshell#get_options() "{{{
  return copy(s:vimshell_options)
endfunction"}}}
function! vimshell#close(buffer_name) "{{{
  let quit_winnr = vimshell#util#get_vimshell_winnr(a:buffer_name)
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
function! vimshell#available_commands(...) "{{{
  let command = get(a:000, 0, '')
  call s:initialize_internal_commands(command)

  return s:internal_commands
endfunction"}}}
function! vimshell#execute_internal_command(command, args, context) "{{{
  if !has_key(s:internal_commands, a:command)
    call s:initialize_internal_commands(a:command)
  endif

  if empty(a:context)
    let context = { 'has_head_spaces' : 0, 'is_interactive' : 1 }
  else
    let context = a:context
  endif

  if !has_key(context, 'fd') || empty(context.fd)
    let context.fd = { 'stdin' : '', 'stdout' : '', 'stderr' : '' }
  endif

  if !has_key(s:internal_commands, a:command)
    call vimshell#error_line(context.fd,
          \ printf('Internal command : "%s" is not found.', a:command))
    return
  endif

  let internal = s:internal_commands[a:command]
  if internal.kind ==# 'execute'
    " Convert args.
    let args = type(get(a:args, 0, '')) == type('') ?
          \ [{ 'args' : a:args, 'fd' : context.fd}] : a:args
    return internal.execute(args, context)
  else
    return internal.execute(a:args, context)
  endif
endfunction"}}}
function! vimshell#read(fd) "{{{
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
function! vimshell#print(fd, string) "{{{
  return vimshell#interactive#print_buffer(a:fd, a:string)
endfunction"}}}
function! vimshell#print_line(fd, string) "{{{
  return vimshell#interactive#print_buffer(a:fd, a:string . "\n")
endfunction"}}}
function! vimshell#error_line(fd, string) "{{{
  return vimshell#interactive#error_buffer(a:fd, a:string . "\n")
endfunction"}}}
function! vimshell#print_prompt(...) "{{{
  if &filetype !=# 'vimshell' || line('.') != line('$')
        \ || !empty(b:vimshell.continuation)
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
function! vimshell#print_secondary_prompt() "{{{
  if &filetype !=# 'vimshell' || line('.') != line('$')
    return
  endif

  " Insert secondary prompt line.
  call append('$', vimshell#get_secondary_prompt())
  $
  let &modified = 0
endfunction"}}}
function! vimshell#get_command_path(program) "{{{
  " Command search.
  try
    return vimproc#get_command_name(a:program)
  catch /File ".*" is not found./
    " Not found.
    return ''
  endtry
endfunction"}}}
function! vimshell#start_insert(...) "{{{
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
function! vimshell#escape_match(str) "{{{
  return escape(a:str, '~" \.^$[]')
endfunction"}}}
function! vimshell#get_prompt(...) "{{{
  let line = get(a:000, 0, line('.'))
  let interactive = get(a:000, 1,
        \ (exists('b:interactive') ? b:interactive : {}))
  if empty(interactive)
    return ''
  endif

  if &filetype ==# 'vimshell' &&
        \ empty(b:vimshell.continuation)
    let context = vimshell#get_context()
    if context.prompt_expr != '' && context.prompt_pattern != ''
      return eval(context.prompt_expr)
    endif

    return context.prompt
  endif

  return vimshell#interactive#get_prompt(line, interactive)
endfunction"}}}
function! vimshell#get_secondary_prompt() "{{{
  return get(vimshell#get_context(),
        \ 'secondary_prompt', get(g:, 'vimshell_secondary_prompt', '%% '))
endfunction"}}}
function! vimshell#get_user_prompt() "{{{
  return get(vimshell#get_context(),
        \ 'user_prompt', get(g:, 'vimshell_user_prompt', ''))
endfunction"}}}
function! vimshell#get_right_prompt() "{{{
  return get(vimshell#get_context(),
        \ 'right_prompt', get(g:, 'vimshell_right_prompt', ''))
endfunction"}}}
function! vimshell#get_cur_text() "{{{
  " Get cursor text without prompt.
  if &filetype !=# 'vimshell'
    return vimshell#interactive#get_cur_text()
  endif

  let cur_line = vimshell#get_cur_line()
  return cur_line[vimshell#get_prompt_length(cur_line) :]
endfunction"}}}
function! vimshell#get_prompt_command(...) "{{{
  " Get command without prompt.
  if a:0 > 0
    return a:1[vimshell#get_prompt_length(a:1) :]
  endif

  if !vimshell#check_prompt()
    " Search prompt.
    let [lnum, col] = searchpos(
          \ vimshell#get_context().prompt_pattern, 'bnW')
  else
    let lnum = '.'
  endif
  let line = getline(lnum)[vimshell#get_prompt_length(getline(lnum)) :]

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
function! vimshell#set_prompt_command(string) "{{{
  if !vimshell#check_prompt()
    " Search prompt.
    let [lnum, col] = searchpos(
          \ vimshell#get_context().prompt_pattern, 'bnW')
  else
    let lnum = '.'
  endif

  call setline(lnum, vimshell#get_prompt() . a:string)
endfunction"}}}
function! vimshell#get_cur_line() "{{{
  let cur_text = matchstr(getline('.'), '^.*\%' . col('.') . 'c' . (mode() ==# 'i' ? '' : '.'))
  return cur_text
endfunction"}}}
function! vimshell#get_current_args(...) "{{{
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
function! vimshell#get_prompt_linenr() "{{{
  if b:interactive.type !=# 'interactive'
        \ && b:interactive.type !=# 'vimshell'
    return 0
  endif

  let [line, col] = searchpos(
        \ vimshell#get_context().prompt_pattern, 'nbcW')
  return line
endfunction"}}}
function! vimshell#check_prompt(...) "{{{
  if &filetype !=# 'vimshell' || !empty(b:vimshell.continuation)
    return call('vimshell#get_prompt', a:000) != ''
  endif

  let line = a:0 == 0 ? getline('.') : getline(a:1)
  return line =~# vimshell#get_context().prompt_pattern
endfunction"}}}
function! vimshell#check_secondary_prompt(...) "{{{
  let line = a:0 == 0 ? getline('.') : getline(a:1)
  return vimshell#head_match(line, vimshell#get_secondary_prompt())
endfunction"}}}
function! vimshell#check_user_prompt(...) "{{{
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
function! vimshell#set_execute_file(exts, program) "{{{
  return vimshell#util#set_dictionary_helper(g:vimshell_execute_file_list,
        \ a:exts, a:program)
endfunction"}}}
function! vimshell#system(...) "{{{
  return call(vimshell#util#get_vital().system, a:000)
endfunction"}}}
function! vimshell#open(filename) "{{{
  call vimproc#open(a:filename)
endfunction"}}}
function! vimshell#trunk_string(string, max) "{{{
  return printf('%.' . string(a:max-10) . 's..%s', a:string, a:string[-8:])
endfunction"}}}
function! vimshell#is_windows() "{{{
  return has('win32') || has('win64')
endfunction"}}}
function! vimshell#resolve(filename) "{{{
  return ((vimshell#util#is_windows() && fnamemodify(a:filename, ':e') ==? 'LNK') || getftype(a:filename) ==# 'link') ?
        \ substitute(resolve(a:filename), '\\', '/', 'g') : a:filename
endfunction"}}}
function! vimshell#get_program_pattern() "{{{
  return
        \'^\s*\%([^[:blank:]]\|\\[^[:alnum:]._-]\)\+\ze\%(\s*\%(=\s*\)\?\)'
endfunction"}}}
function! vimshell#get_argument_pattern() "{{{
  return
        \'[^\\]\s\zs\%([^[:blank:]]\|\\[^[:alnum:].-]\)\+$'
endfunction"}}}
function! vimshell#get_alias_pattern() "{{{
  return '^\s*[[:alnum:].+#_@!%:-]\+'
endfunction"}}}
function! vimshell#cd(directory) "{{{
  let directory = fnameescape(a:directory)
  if vimshell#is_windows()
    " Substitute path sepatator.
    let directory = substitute(directory, '/', '\\', 'g')
  endif
  execute g:vimshell_cd_command directory

  if exists('*unite#sources#directory_mru#_append')
    " Append directory.
    call unite#sources#directory_mru#_append()
  endif
endfunction"}}}
function! vimshell#compare_number(i1, i2) "{{{
  return a:i1 == a:i2 ? 0 : a:i1 > a:i2 ? 1 : -1
endfunction"}}}
function! vimshell#imdisable() "{{{
  " Disable input method.
  if exists('g:loaded_eskk') && eskk#is_enabled()
    call eskk#disable()
  elseif exists('b:skk_on') && b:skk_on && exists('*SkkDisable')
    call SkkDisable()
  elseif exists('&iminsert')
    let &l:iminsert = 0
  endif
endfunction"}}}
function! vimshell#set_variables(variables) "{{{
  let variables_save = {}
  for [key, value] in items(a:variables)
    let save_value = exists(key) ? eval(key) : ''

    let variables_save[key] = save_value
    execute 'let' key '= value'
  endfor

  return variables_save
endfunction"}}}
function! vimshell#restore_variables(variables) "{{{
  for [key, value] in items(a:variables)
    execute 'let' key '= value'
  endfor
endfunction"}}}
function! vimshell#check_cursor_is_end() "{{{
  return vimshell#get_cur_line() ==# getline('.')
endfunction"}}}
function! vimshell#execute_current_line(is_insert) "{{{
  return &filetype ==# 'vimshell' ?
        \ vimshell#mappings#execute_line(a:is_insert) :
        \ vimshell#int_mappings#execute_line(a:is_insert)
endfunction"}}}
function! vimshell#get_cursor_filename() "{{{
  let filename_pattern = (b:interactive.type ==# 'vimshell') ?
        \'\s\?\%(\f\+\s\)*\f\+' :
        \'[[:alnum:];/?:@&=+$,_.!~*|#-]\+'
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
function! vimshell#next_prompt(context, ...) "{{{
  if &filetype !=# 'vimshell'
    return
  endif

  let is_insert = get(a:000, 0, get(a:context, 'is_insert', 1))

  if line('.') == line('$')
    call vimshell#print_prompt(a:context)
    call vimshell#start_insert(is_insert)
    return
  endif

  " Search prompt.
  call search(vimshell#get_context().prompt_pattern.'.\?', 'We')
  if is_insert
    if vimshell#get_prompt_command() == ''
      startinsert!
    else
      normal! l
    endif
  endif

  stopinsert
endfunction"}}}
function! vimshell#split(command) "{{{
  let old_pos = [ tabpagenr(), winnr(), bufnr('%'), getpos('.') ]
  if a:command != ''
    let command =
          \ a:command !=# 'nicely' ? a:command :
          \ winwidth(0) > 2 * &winwidth ? 'vsplit' : 'split'
    execute command
  endif

  let new_pos = [ tabpagenr(), winnr(), bufnr('%'), getpos('.') ]

  return [new_pos, old_pos]
endfunction"}}}
function! vimshell#restore_pos(pos) "{{{
  if tabpagenr() != a:pos[0]
    execute 'tabnext' a:pos[0]
  endif

  if winnr() != a:pos[1]
    execute a:pos[1].'wincmd w'
  endif

  if bufnr('%') !=# a:pos[2]
    execute 'buffer' a:pos[2]
  endif

  call setpos('.', a:pos[3])
endfunction"}}}
function! vimshell#get_editor_name() "{{{
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
function! vimshell#is_interactive() "{{{
  let is_valid = get(get(b:interactive, 'process', {}), 'is_valid', 0)
  return b:interactive.type ==# 'interactive'
        \ || (b:interactive.type ==# 'vimshell' && is_valid)
endfunction"}}}
function! vimshell#get_data_directory()
  if !isdirectory(g:vimshell_temporary_directory) && !vimshell#util#is_sudo()
    call mkdir(g:vimshell_temporary_directory, 'p')
  endif

  return g:vimshell_temporary_directory
endfunction
"}}}

" User helper functions.
function! vimshell#execute(cmdline, ...) "{{{
  if !empty(b:vimshell.continuation)
    " Kill process.
    call vimshell#interactive#hang_up(bufname('%'))
  endif

  let context = a:0 >= 1? a:1 : vimshell#get_context()
  let context.is_interactive = 0
  try
    call vimshell#parser#eval_script(a:cmdline, context)
  catch
    if v:exception !~# '^Vim:Interrupt'
      let message = v:exception . ' ' . v:throwpoint
      call vimshell#error_line(context.fd, message)
    endif
    return 1
  endtry

  return b:vimshell.system_variables.status
endfunction"}}}
function! vimshell#execute_async(cmdline, ...) "{{{
  if !empty(b:vimshell.continuation)
    " Kill process.
    call vimshell#interactive#hang_up(bufname('%'))
  endif

  let context = a:0 >= 1 ? a:1 : vimshell#get_context()
  let context.is_interactive = 1
  try
    return vimshell#parser#eval_script(a:cmdline, context)
  catch
    if v:exception !~# '^Vim:Interrupt'
      let message = v:exception . ' ' . v:throwpoint
      call vimshell#error_line(context.fd, message)
    endif

    let context = vimshell#get_context()
    let b:vimshell.continuation = {}
    call vimshell#print_prompt(context)
    call vimshell#start_insert(mode() ==# 'i')
    return 1
  endtry
endfunction"}}}
function! vimshell#set_context(context) "{{{
  let context = s:initialize_context(a:context)
  let s:context = context
  if exists('b:vimshell')
    let b:vimshell.context = context
  endif
endfunction"}}}
function! vimshell#get_context() "{{{
  if exists('b:vimshell')
    return extend(copy(b:vimshell.context),
          \ get(b:vimshell.continuation, 'context', {}))
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
function! vimshell#set_alias(name, value) "{{{
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
function! vimshell#get_alias(name) "{{{
  return get(b:vimshell.alias_table, a:name, '')
endfunction"}}}
function! vimshell#set_galias(name, value) "{{{
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
function! vimshell#get_galias(name) "{{{
  return get(b:vimshell.galias_table, a:name, '')
endfunction"}}}
function! vimshell#set_syntax(syntax_name) "{{{
  let b:interactive.syntax = a:syntax_name
endfunction"}}}
function! vimshell#get_status_string() "{{{
  return !exists('b:vimshell') ? '' : (
        \ (!empty(b:vimshell.continuation) ? '[async] ' : '') .
        \ b:vimshell.current_dir)
endfunction"}}}

function! s:initialize_vimshell(path, context) "{{{
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
  let b:vimshell.statusline = '*vimshell* : %{vimshell#get_status_string()}'
        \ . "\ %=%{printf('%s %4d/%d',b:vimshell.right_prompt, line('.'), line('$'))}"
  let b:vimshell.right_prompt = ''

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
        \ 'width' : winwidth(0),
        \ 'height' : g:vimshell_scrollback_limit,
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

  call vimshell#handlers#_restore_statusline()
endfunction"}}}
function! vimshell#set_highlight() "{{{
  " Set syntax.
  let prompt_pattern = '/' .
        \ escape(vimshell#get_context().prompt_pattern, '/') . '/'
  let secondary_prompt_pattern = '/^' .
        \ escape(vimshell#escape_match(
        \ vimshell#get_secondary_prompt()), '/') . '/'
  execute 'syntax match vimshellPrompt'
        \ prompt_pattern 'nextgroup=vimshellCommand'
  execute 'syntax match vimshellPrompt'
        \ secondary_prompt_pattern 'nextgroup=vimshellCommand'
  syntax match   vimshellCommand '\f\+'
        \ nextgroup=vimshellLine contained
  syntax region vimshellLine start='' end='$' keepend contained
        \ contains=vimshellDirectory,vimshellConstants,
        \vimshellArguments,vimshellQuoted,vimshellString,
        \vimshellVariable,vimshellSpecial,vimshellComment
endfunction"}}}
function! s:initialize_context(context) "{{{
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
    \ 'project' : 0,
    \ 'direction' : '',
    \ 'prompt' : get(g:,
    \      'vimshell_prompt', 'vimshell% '),
    \ 'prompt_expr' : get(g:,
    \      'vimshell_prompt_expr', ''),
    \ 'prompt_pattern' : get(g:,
    \      'vimshell_prompt_pattern', ''),
    \ 'secondary_prompt' : get(g:,
    \      'vimshell_secondary_prompt', '%% '),
    \ 'user_prompt' : get(g:,
    \      'vimshell_user_prompt', ''),
    \ 'right_prompt' : get(g:,
    \      'vimshell_right_prompt', ''),
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

  " Set prompt pattern.
  if context.prompt_pattern == ''
    if context.prompt_expr != ''
      " Error.
      call vimshell#echo_error(
            \ 'Your prompt_pattern is invalid. '.
            \ 'You must set prompt_pattern in vimshell.')
    endif

    let context.prompt_pattern =
          \ '^' . vimshell#escape_match(context.prompt)
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
function! s:initialize_internal_commands(command) "{{{
  " Initialize internal commands table.
  if a:command =~ '\.'
    " Search pattern error.
    return
  endif

  " Search autoload.
  for list in split(globpath(&runtimepath,
        \ 'autoload/vimshell/commands/' . a:command . '*.vim'), '\n')
    let command_name = fnamemodify(list, ':t:r')
    if command_name == '' ||
          \ has_key(s:internal_commands, command_name)
      continue
    endif

    let result = {'vimshell#commands#'.command_name.'#define'}()

    for command in (type(result) == type([])) ?
          \ result : [result]
      if !has_key(command, 'description')
        let command.description = ''
      endif

      let s:internal_commands[command.name] = command
    endfor

    unlet result
  endfor
endfunction"}}}
function! vimshell#initialize_tab_variable() "{{{
  let t:vimshell = {
        \ 'last_vimshell_bufnr' : -1,
        \ 'last_interactive_bufnr' : -1,
        \ }
endfunction"}}}
function! s:switch_vimshell(bufnr, context, path) "{{{
  if bufwinnr(a:bufnr) > 0
    execute bufwinnr(a:bufnr) 'wincmd w'
  else
    if a:context.split_command != ''
      let [new_pos, old_pos] =
            \ vimshell#split(a:context.split_command)
    endif

    execute 'buffer' a:bufnr
  endif

  if !empty(b:vimshell.continuation)
    return
  endif

  if a:path != '' && isdirectory(a:path)
    " Change current directory.
    let current = fnamemodify(a:path, ':p')
    let b:vimshell.current_dir = current
    call vimshell#cd(current)
  endif

  if getline('$') =~# a:context.prompt_pattern.'$'
    " Delete current prompt.
    let promptnr = vimshell#check_user_prompt(line('$')) > 0 ?
          \ vimshell#check_user_prompt(line('$')) . ',' : ''
    execute 'silent ' . promptnr . '$delete _'
  endif

  normal! zb

  call vimshell#print_prompt()
  call vimshell#start_insert()
endfunction"}}}
function! s:get_postfix(prefix, is_create) "{{{
  let buffers = get(a:000, 0, range(1, bufnr('$')))
  let buflist = vimshell#util#sort_by(filter(map(buffers,
        \ 'bufname(v:val)'), 'stridx(v:val, a:prefix) >= 0'),
        \ "str2nr(matchstr(v:val, '\\d\\+$'))")
  if empty(buflist)
    return ''
  endif

  let num = matchstr(buflist[-1], '@\zs\d\+$')
  return num == '' && !a:is_create ? '' :
        \ '@' . (a:is_create ? (num + 1) : num)
endfunction"}}}
function! vimshell#complete(arglead, cmdline, cursorpos) "{{{
  let _ = []

  " Option names completion.
  try
    let _ += filter(vimshell#get_options(),
          \ 'stridx(v:val, a:arglead) == 0')
  catch
  endtry

  " Directory name completion.
  let _ += filter(map(split(glob(a:arglead . '*'), '\n'),
        \ "isdirectory(v:val) ? v:val.'/' : v:val"),
        \ 'stridx(v:val, a:arglead) == 0')

  return sort(_)
endfunction"}}}
function! vimshell#vimshell_execute_complete(arglead, cmdline, cursorpos) "{{{
  " Get complete words.
  let cmdline = a:cmdline[len(matchstr(
        \ a:cmdline, vimshell#get_program_pattern())):]

  let args = vimproc#parser#split_args_through(cmdline)
  if empty(args) || cmdline =~ '\\\@!\s\+$'
    " Add blank argument.
    call add(args, '')
  endif

  return map(vimshell#complete#helper#command_args(args), 'v:val.word')
endfunction"}}}
function! s:insert_user_and_right_prompt() "{{{
  let user_prompt = vimshell#get_user_prompt()
  if user_prompt != ''
    for user in split(eval(user_prompt), "\\n", 1)
      try
        let secondary = '[%] ' . user
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
  endif

  " Insert right prompt line.
  if vimshell#get_right_prompt() == ''
    return
  endif

  try
    let right_prompt = eval(vimshell#get_right_prompt())
    let b:vimshell.right_prompt = right_prompt
  catch
    let message = v:exception . ' ' . v:throwpoint
    echohl WarningMsg | echomsg message | echohl None

    let right_prompt = ''
  endtry

  if right_prompt == ''
    return
  endif

  let user_prompt_last = (user_prompt != '') ?
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
function! vimshell#get_prompt_length(...) "{{{
  return len(matchstr(get(a:000, 0, getline('.')),
        \ vimshell#get_context().prompt_pattern))
endfunction"}}}

" vim: foldmethod=marker
