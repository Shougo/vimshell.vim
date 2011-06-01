"=============================================================================
" FILE: vimshell.vim
" AUTHOR: Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 01 Jun 2011.
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
  return '800'
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
if s:exists_vimproc_version < 502
  echoerr 'Your vimproc is too old.'
  echoerr 'Please install vimproc Ver.5.2 or above.'
  finish
endif"}}}

" Initialize."{{{
let s:prompt = exists('g:vimshell_prompt') ? g:vimshell_prompt : 'vimshell% '
let s:secondary_prompt = exists('g:vimshell_secondary_prompt') ? g:vimshell_secondary_prompt : '%% '
let s:user_prompt = exists('g:vimshell_user_prompt') ? g:vimshell_user_prompt : ''
let s:right_prompt = exists('g:vimshell_right_prompt') ? g:vimshell_right_prompt : ''
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

" Check prompt value."{{{
if vimshell#head_match(s:prompt, s:secondary_prompt) || vimshell#head_match(s:secondary_prompt, s:prompt)
  echoerr printf('Head matched g:vimshell_prompt("%s") and your g:vimshell_secondary_prompt("%s").', s:prompt, s:secondary_prompt)
  finish
elseif vimshell#head_match(s:prompt, '[%] ') || vimshell#head_match('[%] ', s:prompt)
  echoerr printf('Head matched g:vimshell_prompt("%s") and your g:vimshell_user_prompt("[%] ").', s:prompt)
  finish
elseif vimshell#head_match('[%] ', s:secondary_prompt) || vimshell#head_match(s:secondary_prompt, '[%] ')
  echoerr printf('Head matched g:vimshell_user_prompt("[%] ") and your g:vimshell_secondary_prompt("%s").', s:secondary_prompt)
  finish
endif"}}}

" User utility functions.
function! s:default_settings()"{{{
  " Common.
  setlocal nolist
  setlocal buftype=nofile
  setlocal noswapfile
  setlocal tabstop=8
  setlocal foldcolumn=0
  setlocal foldmethod=manual
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
    autocmd InsertEnter <buffer>    call s:insert_enter()
    autocmd InsertLeave <buffer>    call s:insert_leave()
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
  let l:bufname = '[1]vimshell'
  let l:cnt = 2
  while buflisted(l:bufname)
    let l:bufname = printf('[%d]vimshell', l:cnt)
    let l:cnt += 1
  endwhile

  if a:split_flag
    execute winheight(0)*g:vimshell_split_height/100 'split `=l:bufname`'
  else
    edit `=l:bufname`
  endif

  if empty(s:internal_commands)
    call s:init_internal_commands()
  endif

  " Load history.
  let g:vimshell#hist_buffer = vimshell#history#read()

  " Initialize variables.
  let b:vimshell = {}

  " Change current directory.
  let l:current = (a:directory != '')? fnamemodify(a:directory, ':p') : getcwd()
  let b:vimshell.save_dir = l:current
  call vimshell#cd(l:current)

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

  let l:context = {
        \ 'has_head_spaces' : 0,
        \ 'is_interactive' : 1,
        \ 'is_insert' : 1,
        \ 'fd' : { 'stdin' : '', 'stdout': '', 'stderr': ''},
        \}
  call vimshell#set_context(l:context)

  " Set interactive variables.
  let b:interactive = {
        \ 'type' : 'vimshell',
        \ 'syntax' : 'vimshell',
        \ 'process' : {},
        \ 'fd' : l:context.fd,
        \ 'encoding' : &encoding,
        \ 'is_pty' : 0,
        \ 'echoback_linenr' : -1,
        \ 'stdout_cache' : '',
        \ 'stderr_cache' : '',
        \}
  let b:interactive.hook_functions_table = {
        \ 'preprompt' : [], 'preparse' : [],
        \ 'preexec' : [], 'postexec' : [],
        \ 'emptycmd' : [], 'notfound' : [],
        \ 'chpwd' : [],
        \}

  " Load rc file.
  if filereadable(g:vimshell_vimshrc_path)
    call vimshell#execute_internal_command('vimsh', [g:vimshell_vimshrc_path], {},
          \{ 'has_head_spaces' : 0, 'is_interactive' : 0 })
    let b:vimshell.loaded_vimshrc = 1
  endif

  setfiletype vimshell

  call vimshell#help#init()

  call vimshell#print_prompt(l:context)

  call vimshell#start_insert()
  call vimshell#interactive#set_send_buffer(bufname('%'))

  " Set undo point.
  call feedkeys("\<C-g>u", 'n')
endfunction"}}}
function! vimshell#switch_shell(split_flag, directory)"{{{
  let l:context = {
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
    let l:cnt = 1
    while l:cnt <= bufnr('$')
      if getbufvar(l:cnt, '&filetype') ==# 'vimshell'
        \ && (!exists('t:unite_buffer_dictionary') || has_key(t:unite_buffer_dictionary, l:cnt))
        call s:switch_vimshell(l:cnt, a:split_flag, a:directory)
        return
      endif

      let l:cnt += 1
    endwhile
  endif

  " Create window.
  call vimshell#create_shell(a:split_flag, a:directory)
endfunction"}}}

function! vimshell#available_commands()"{{{
  return s:internal_commands
endfunction"}}}
function! vimshell#execute_internal_command(command, args, fd, context)"{{{
  if empty(s:internal_commands)
    call s:init_internal_commands()
  endif

  if empty(a:fd)
    let l:fd = { 'stdin' : '', 'stdout' : '', 'stderr' : '' }
  else
    let l:fd = a:fd
  endif

  let l:commands = [ { 'args' : insert(a:args, a:command), 'fd' : l:fd } ]

  if empty(a:context)
    let l:context = { 'has_head_spaces' : 0, 'is_interactive' : 1 }
  else
    let l:context = a:context
  endif

  return vimshell#parser#execute_command(l:commands, l:context)
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
      let l:ff = "\<CR>\<LF>"
    else
      let l:ff = "\<LF>"
      return join(readfile(a:fd.stdin), l:ff) . l:ff
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

  let l:context = a:0 >= 1? a:1 : vimshell#get_context()

  " Call preprompt hook.
  call vimshell#hook#call('preprompt', l:context, [])

  " Search prompt
  if empty(b:vimshell.commandline_stack)
    let l:new_prompt = vimshell#get_prompt()
  else
    let l:new_prompt = b:vimshell.commandline_stack[-1]
    call remove(b:vimshell.commandline_stack, -1)
  endif

  if s:user_prompt != '' || s:right_prompt != ''
    " Insert user prompt line.
    for l:user in split(s:user_prompt, "\\n")
      let l:secondary = '[%] ' . eval(l:user)
      if line('$') == 1 && getline('.') == ''
        call setline('$', l:secondary)
      else
        call append('$', l:secondary)
      endif
    endfor

    " Insert user prompt line.
    if s:right_prompt != ''
      let l:right_prompt = eval(s:right_prompt)
      if l:right_prompt != ''
        let l:user_prompt_last = (s:user_prompt != '')? getline('$') : '[%] '
        let l:winwidth = winwidth(0) - 10
        let l:padding_len = (len(l:user_prompt_last)+len(s:right_prompt)+1 > l:winwidth)? 1 : l:winwidth - (len(l:user_prompt_last)+len(l:right_prompt))
        let l:secondary = printf('%s%s%s', l:user_prompt_last, repeat(' ', l:padding_len), l:right_prompt)
        if s:user_prompt != ''
          call setline('$', l:secondary)
        else
          call append('$', l:secondary)
        endif
      endif
    endif
  endif

  " Insert prompt line.
  if line('$') == 1 && getline('.') == ''
    call setline('$', l:new_prompt)
  else
    call append('$', l:new_prompt)
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

  let l:is_insert = (a:0 == 0)? 1 : a:1

  if l:is_insert
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
  return &filetype == 'vimshell' ? s:prompt : vimshell#interactive#get_prompt(line('.'))
endfunction"}}}
function! vimshell#get_secondary_prompt()"{{{
  return s:secondary_prompt
endfunction"}}}
function! vimshell#get_user_prompt()"{{{
  return s:user_prompt
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
    let [l:lnum, l:col] = searchpos('^' . vimshell#escape_match(vimshell#get_prompt()), 'bnW')
  else
    let l:lnum = '.'
  endif
  let l:line = getline(l:lnum)[len(vimshell#get_prompt()):]

  let l:lnum += 1
  let l:secondary_prompt = vimshell#get_secondary_prompt()
  while l:lnum <= line('$') && !vimshell#check_prompt(l:lnum)
    if vimshell#check_secondary_prompt(l:lnum)
      " Append secondary command.
      let l:line .= "\<NL>" . getline(l:lnum)[len(l:secondary_prompt):]
    endif

    let l:lnum += 1
  endwhile

  return l:line
endfunction"}}}
function! vimshell#set_prompt_command(string)"{{{
  if !vimshell#check_prompt()
    " Search prompt.
    let [l:lnum, l:col] = searchpos('^' . vimshell#escape_match(vimshell#get_prompt()), 'bnW')
  else
    let l:lnum = '.'
  endif

  call setline(l:lnum, vimshell#get_prompt() . a:string)
endfunction"}}}
function! vimshell#get_cur_line()"{{{
  let l:cur_text = matchstr(getline('.'), '^.*\%' . col('.') . 'c' . (mode() ==# 'i' ? '' : '.'))
  return l:cur_text
endfunction"}}}
function! vimshell#get_current_args(...)"{{{
  let l:cur_text = a:0 == 0 ? vimshell#get_cur_text() : a:1
  let l:statements = vimproc#parser#split_statements(l:cur_text)
  if empty(l:statements)
    return []
  endif

  let l:commands = vimproc#parser#split_commands(l:statements[-1])
  if empty(l:commands)
    return []
  endif

  let l:args = vimproc#parser#split_args_through(l:commands[-1])
  if vimshell#get_cur_text() =~ '\\\@!\s\+$'
    " Add blank argument.
    call add(l:args, '')
  endif

  return l:args
endfunction"}}}
function! vimshell#check_prompt(...)"{{{
  if &filetype !=# 'vimshell'
    return call('vimshell#interactive#get_prompt', a:000) != ''
  endif

  let l:line = a:0 == 0 ? getline('.') : getline(a:1)
  return vimshell#head_match(l:line, vimshell#get_prompt())
endfunction"}}}
function! vimshell#get_prompt_linenr()"{{{
  let [l:line, l:col] = searchpos('^' . vimshell#escape_match(vimshell#get_prompt()), 'bcW')
  return l:line
endfunction"}}}
function! vimshell#check_secondary_prompt(...)"{{{
  let l:line = a:0 == 0 ? getline('.') : getline(a:1)
  return vimshell#head_match(l:line, vimshell#get_secondary_prompt())
endfunction"}}}
function! vimshell#set_execute_file(exts, program)"{{{
  for ext in split(a:exts, ',')
    let g:vimshell_execute_file_list[ext] = a:program
  endfor
endfunction"}}}
function! vimshell#system(str, ...)"{{{
  let l:command = a:str
  let l:input = a:0 >= 1 ? a:1 : ''
  if &termencoding != '' && &termencoding != &encoding
    let l:command = iconv(l:command, &encoding, &termencoding)
    let l:input = iconv(l:input, &encoding, &termencoding)
  endif

  if a:0 == 0
    let l:output = vimproc#system(l:command)
  elseif a:0 == 1
    let l:output = vimproc#system(l:command, l:input)
  else
    let l:output = vimproc#system(l:command, l:input, a:2)
  endif

  if &termencoding != '' && &termencoding != &encoding
    let l:output = iconv(l:output, &termencoding, &encoding)
  endif

  return l:output
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
function! vimshell#split_nicely()"{{{
  " Split nicely.
  if g:vimshell_split_command != ''
    execute g:vimshell_split_command
  elseif winwidth(0) > 2 * &winwidth
    vsplit
  else
    split
  endif
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
  let l:cnt = 0
  let l:pos = 1
  let l:current = 0
  while l:pos <= bufnr('$')
    if buflisted(l:pos)
      if l:pos == bufnr('%')
        let l:current = l:cnt
      endif

      let l:cnt += 1
    endif

    let l:pos += 1
  endwhile

  if l:current > l:cnt / 2
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
  let l:variables_save = {}
  for [key, value] in items(a:variables)
    let l:save_value = exists(key) ? eval(key) : ''

    let l:variables_save[key] = l:save_value
    execute 'let' key '= value'
  endfor

  return l:variables_save
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
"}}}

" User helper functions.
function! vimshell#execute(cmdline, ...)"{{{
  let l:context = a:0 >= 1? a:1 : vimshell#get_context()
  try
    call vimshell#parser#eval_script(a:cmdline, l:context)
  catch /.*/
    let l:message = v:exception . ' ' . v:throwpoint
    call vimshell#error_line(l:context.fd, l:message)
    return 1
  endtry

  return b:vimshell.system_variables.status
endfunction"}}}
function! vimshell#set_context(context)"{{{
  let s:context = a:context
endfunction"}}}
function! vimshell#get_context()"{{{
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
    let l:command_name = fnamemodify(list, ':t:r')
    if !has_key(s:internal_commands, l:command_name)
      let l:command = {'vimshell#commands#'.l:command_name.'#define'}()

      if !has_key(l:command, 'description')
        let l:command.description = ''
      endif

      let s:internal_commands[l:command_name] = l:command
    endif
  endfor
endfunction"}}}
function! s:switch_vimshell(bufnr, split_flag, directory)"{{{
  if a:split_flag
    execute winheight(0)*g:vimshell_split_height / 100 'sbuffer' a:bufnr
  else
    execute 'buffer' a:bufnr
  endif

  if a:directory != '' && isdirectory(a:directory)
    " Change current directory.
    let l:current = fnamemodify(a:directory, ':p')
    let b:vimshell.save_dir = l:current
    call vimshell#cd(l:current)

    call vimshell#print_prompt()
  endif
  call vimshell#start_insert()
endfunction"}}}

" Auto commands function.
function! s:event_bufwin_enter()"{{{
  if has('conceal')
    setlocal conceallevel=3
    setlocal concealcursor=nvi
  endif

  if !exists('b:vimshell') ||
        \ !isdirectory(b:vimshell.save_dir)
    return
  endif

  call vimshell#cd(fnamemodify(b:vimshell.save_dir, ':p'))
endfunction"}}}
function! s:event_bufwin_leave()"{{{
  let s:last_vimshell_bufnr = bufnr('%')
endfunction"}}}
function! s:insert_enter()"{{{
  if &updatetime > g:vimshell_interactive_update_time
    let s:update_time_save = &updatetime
    let &updatetime = g:vimshell_interactive_update_time
  endif
endfunction"}}}
function! s:insert_leave()"{{{
  if &updatetime < s:update_time_save
    let &updatetime = s:update_time_save
  endif
endfunction"}}}

" vim: foldmethod=marker
