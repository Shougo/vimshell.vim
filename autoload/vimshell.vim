"=============================================================================
" FILE: vimshell.vim
" AUTHOR: Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 24 Nov 2013.
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

" Initialize. "{{{
if !exists('g:vimshell_execute_file_list')
  let g:vimshell_execute_file_list = {}
endif
"}}}

" vimshell plugin utility functions. "{{{
function! vimshell#get_options() "{{{
  if !exists('s:vimshell_options')
    let s:vimshell_options = [
          \ '-buffer-name=', '-toggle', '-create',
          \ '-split', '-split-command=', '-popup',
          \ '-winwidth=', '-winminwidth=',
          \ '-prompt=', '-secondary-prompt=',
          \ '-user-prompt=', '-right-prompt=',
          \ '-prompt-expr=', '-prompt-pattern=',
          \ '-project',
          \]
  endif
  return copy(s:vimshell_options)
endfunction"}}}
function! vimshell#available_commands(...) "{{{
  call vimshell#init#_internal_commands(get(a:000, 0, ''))
  return vimshell#variables#internal_commands()
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
  return call('vimshell#view#_print_prompt', a:000)
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
  return vimshell#util#head_match(line, vimshell#get_secondary_prompt())
endfunction"}}}
function! vimshell#check_user_prompt(...) "{{{
  let line = a:0 == 0 ? line('.') : a:1
  if !vimshell#util#head_match(getline(line-1), '[%] ')
    " Not found.
    return 0
  endif

  while 1
    let line -= 1

    if !vimshell#util#head_match(getline(line-1), '[%] ')
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
  if vimshell#util#is_windows()
    " Substitute path sepatator.
    let directory = substitute(directory, '/', '\\', 'g')
  endif
  execute g:vimshell_cd_command directory

  if exists('*unite#sources#directory_mru#_append')
    " Append directory.
    call unite#sources#directory_mru#_append()
  endif
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
  let context = vimshell#init#_context(a:context)
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
