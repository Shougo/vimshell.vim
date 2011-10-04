"=============================================================================
" FILE: parser.vim
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

function! vimshell#parser#check_script(script)"{{{
  " Parse check only.
  " Split statements.
  for statement in vimproc#parser#split_statements(a:script)
    let args = vimproc#parser#split_args(statement)
  endfor
endfunction"}}}
function! vimshell#parser#eval_script(script, context)"{{{
  " Split statements.
  let statements = vimproc#parser#parse_statements(a:script)
  let max = len(statements)

  let context = a:context
  let context.is_single_command = (context.is_interactive && max == 1)

  let i = 0
  while i < max
    try
      let ret =  s:execute_statement(statements[i].statement, a:context)
    catch /^exe: Process started./
      " Change continuation.
      let b:vimshell.continuation = {
            \ 'statements' : statements[i : ], 'context' : a:context,
            \ 'script' : a:script,
            \ }
      return 1
    endtry

    let condition = statements[i].condition
    if (condition ==# 'true' && ret)
          \ || (condition ==# 'false' && !ret)
      break
    endif

    let i += 1
  endwhile

  " Call postexec hook.
  call vimshell#hook#call('postexec', context, a:script)

  return 0
endfunction"}}}
function! vimshell#parser#execute_command(commands, context)"{{{
  if empty(a:commands)
    return 0
  endif

  let internal_commands = vimshell#available_commands()

  let commands = a:commands
  let program = commands[0].args[0]
  let args = commands[0].args[1:]
  let fd = commands[0].fd
  let context = a:context
  let context.fd = fd

  " Check pipeline.
  if has_key(internal_commands, program)
        \ && internal_commands[program].kind ==# 'execute'
    " Execute execute commands.
    let commands[0].args = args
    return internal_commands[program].execute(commands, context)
  elseif a:commands[-1].args[-1] =~ '&$'
    " Convert to internal bg command.
    let commands[-1].args[-1] = commands[-1].args[-1][:-2]
    if commands[-1].args[-1] == ''
      " Delete empty arg.
      call remove(commands[-1].args, -1)
    endif

    return internal_commands['bg'].execute(commands, context)
  elseif len(a:commands) > 1
    if a:commands[-1].args[0] == 'less'
      " Execute less(Syntax sugar).
      let commands = a:commands[: -2]
      if !empty(a:commands[-1].args[1:])
        let commands[0].args = a:commands[-1].args[1:] + commands[0].args
      endif
      return internal_commands['less'].execute(commands, context)
    else
      " Execute external commands.
      return internal_commands['exe'].execute(a:commands, context)
    endif
  else"{{{
    let line = join(a:commands[0].args)
    let dir = substitute(substitute(line, '^\~\ze[/\\]', substitute($HOME, '\\', '/', 'g'), ''), '\\\(.\)', '\1', 'g')
    let command = vimshell#get_command_path(program)
    let ext = fnamemodify(program, ':e')

    " Check internal commands.
    if has_key(internal_commands, program)"{{{
      " Internal commands.
      return internal_commands[program].execute(args, a:context)
      "}}}
    elseif isdirectory(dir)"{{{
      " Directory.
      " Change the working directory like zsh.

      " Call internal cd command.
      return vimshell#execute_internal_command('cd', [dir], a:context)
      "}}}
    elseif !empty(ext) && has_key(g:vimshell_execute_file_list, ext)
      " Suffix execution.
      let args = extend(split(g:vimshell_execute_file_list[ext]), a:commands[0].args)
      let commands = [ { 'args' : args, 'fd' : fd } ]
      return vimshell#parser#execute_command(commands, a:context)
    elseif command != '' || executable(program)
      let args = insert(args, program)

      if has_key(g:vimshell_terminal_commands, program)
            \ && g:vimshell_terminal_commands[program]
        " Execute terminal commands.
        return internal_commands['texe'].execute(a:commands, context)
      else
        " Execute external commands.
        return internal_commands['exe'].execute(a:commands, context)
      endif
    else
      throw printf('Error: File "%s" is not found.', program)
    endif
  endif"}}}
endfunction
"}}}
function! vimshell#parser#execute_continuation(is_insert)"{{{
  if empty(b:vimshell.continuation)
    return
  endif

  " Execute pipe.
  call vimshell#interactive#execute_process_out(a:is_insert)

  if b:interactive.process.is_valid
    return 1
  endif

  let b:vimshell.system_variables['status'] = b:interactive.status
  let ret = b:interactive.status

  let statements = b:vimshell.continuation.statements
  let condition = statements[0].condition
  if (condition ==# 'true' && ret)
        \ || (condition ==# 'false' && !ret)
    " Exit.
    let b:vimshell.continuation.statements = []
    let statements = []
  endif

  if ret != 0
    " Print exit value.
    let context = b:vimshell.continuation.context
    if b:interactive.cond ==# 'signal'
      let message = printf('vimshell: %s %d(%s) "%s"', b:interactive.cond, b:interactive.status,
            \ vimshell#interactive#decode_signal(b:interactive.status), b:interactive.cmdline)
    else
      let message = printf('vimshell: %s %d "%s"', b:interactive.cond, b:interactive.status, b:interactive.cmdline)
    endif

    call vimshell#error_line(context.fd, message)
  endif

  " Execute rest commands.
  let statements = statements[1:]
  let max = len(statements)
  let context = b:vimshell.continuation.context

  let i = 0

  while i < max
    try
      let ret = s:execute_statement(statements[i].statement, context)
    catch /^exe: Process started./
      " Change continuation.
      let b:vimshell.continuation.statements = statements[i : ]
      let b:vimshell.continuation.context = context
      return 1
    endtry

    let condition = statements[i].condition
    if (condition ==# 'true' && ret)
          \ || (condition ==# 'false' && !ret)
      break
    endif

    let i += 1
  endwhile

  if b:interactive.syntax !=# &filetype
    " Set highlight.
    let start = searchpos('^' . vimshell#escape_match(vimshell#get_prompt()), 'bWen')[0]
    if start > 0
      call s:highlight_with(start + 1, line('$'), b:interactive.syntax)
    endif

    let b:interactive.syntax = &filetype
  endif

  " Call postexec hook.
  call vimshell#hook#call('postexec', context, b:vimshell.continuation.script)

  let b:vimshell.continuation = {}

  call vimshell#next_prompt(context, a:is_insert)
endfunction
"}}}
function! s:execute_statement(statement, context)"{{{
  let statement = vimshell#parser#parse_alias(a:statement)

  " Call preexec filter.
  let statement = vimshell#hook#call_filter('preexec', a:context, statement)

  let program = vimshell#parser#parse_program(statement)

  let internal_commands = vimshell#available_commands()
  if program =~ '^\s*:'
    " Convert to vexe special command.
    let fd = { 'stdin' : '', 'stdout' : '', 'stderr' : '' }
    let commands = [ { 'args' : split(substitute(statement, '^:', 'vexe ', '')), 'fd' : fd } ]
  elseif has_key(internal_commands, program)
        \ && internal_commands[program].kind ==# 'special'
    " Special commands.
    let fd = { 'stdin' : '', 'stdout' : '', 'stderr' : '' }
    let commands = [ { 'args' : split(statement), 'fd' : fd } ]
  else
    let commands = vimproc#parser#parse_pipe(statement)
  endif

  return vimshell#parser#execute_command(commands, a:context)
endfunction
"}}}

" Parse helper.
function! vimshell#parser#parse_alias(statement)"{{{
  let pipes = []

  for statement in vimproc#parser#split_pipe(a:statement)
    " Get program.
    let statement = s:parse_galias(statement)
    let program = matchstr(statement, vimshell#get_program_pattern())
    if program  == ''
      throw 'Error: Invalid command name.'
    endif

    if exists('b:vimshell') && has_key(b:vimshell.alias_table, program) && !empty(b:vimshell.alias_table[program])
      " Expand alias.
      let args = vimproc#parser#split_args_through(statement[matchend(statement, vimshell#get_program_pattern()) :])
      let statement = s:recursive_expand_alias(program, args)
    endif

    call add(pipes, statement)
  endfor

  return join(pipes, '|')
endfunction"}}}
function! vimshell#parser#parse_program(statement)"{{{
  " Get program.
  let program = matchstr(a:statement, vimshell#get_program_pattern())
  if program  == ''
    throw 'Error: Invalid command name.'
  endif

  if program != '' && program[0] == '~'
    " Parse tilde.
    let program = substitute($HOME, '\\', '/', 'g') . program[1:]
  endif

  return program
endfunction"}}}
function! s:parse_galias(script)"{{{
  if !exists('b:vimshell')
    return a:script
  endif

  let script = a:script
  let max = len(script)
  let args = []
  let arg = ''
  let i = 0
  while i < max
    if script[i] == '\'
      " Escape.
      let i += 1

      if i > max
        throw 'Exception: Join to next line (\).'
      endif

      let arg .= '\' .  script[i]
      let i += 1
    elseif script[i] != ' '
      let arg .= script[i]
      let i += 1
    else
      " Space.
      if arg != ''
        call add(args, arg)
      endif

      let arg = ''

      let i += 1
    endif
  endwhile

  if arg != ''
    call add(args, arg)
  endif

  " Expand global alias.
  let i = 0
  for arg in args
    if has_key(b:vimshell.galias_table, arg)
      let args[i] = b:vimshell.galias_table[arg]
    endif

    let i += 1
  endfor

  return join(args)
endfunction"}}}
function! s:recursive_expand_alias(alias_name, args)"{{{
  " Recursive expand alias.
  let alias = b:vimshell.alias_table[a:alias_name]
  let expanded = {}
  while 1
    let key = vimproc#parser#split_args(alias)[-1]
    if has_key(expanded, alias) || !has_key(b:vimshell.alias_table, alias)
      break
    endif

    let expanded[alias] = 1
    let alias = b:vimshell.alias_table[alias]
  endwhile

  " Expand variables.
  let script = ''

  let i = 0
  let max = len(alias)
  let args = insert(copy(a:args), a:alias_name)
  try
    while i < max
      let matchlist = matchlist(alias,
            \'^$$args\(\[\d\+\%(:\%(\d\+\)\?\)\?\]\)\?', i)
      if empty(matchlist)
        let script .= alias[i]
        let i += 1
      else
        let index = matchlist[1]

        if index == ''
          " All args.
          let script .= join(args[1:])
        elseif index =~ '^\[\d\+\]$'
          let script .= get(args, index[1: -2], '')
        else
          " Some args.
          let script .= join(eval('args' . index))
        endif

        let i += len(matchlist[0])
      endif
    endwhile
  endtry

  if script ==# alias
    let script .= ' ' . join(a:args)
  endif

  return script
endfunction"}}}

" Misc.
function! vimshell#parser#check_wildcard()"{{{
  let args = vimshell#get_current_args()
  return !empty(args) && args[-1] =~ '[[*?]\|^\\[()|]'
endfunction"}}}
function! vimshell#parser#getopt(args, optsyntax, ...)"{{{
  let default_values = get(a:000, 0, {})

  " Initialize.
  let optsyntax = a:optsyntax
  if !has_key(optsyntax, 'noarg')
    let optsyntax['noarg'] = []
  endif
  if !has_key(optsyntax, 'noarg_short')
    let optsyntax['noarg_short'] = []
  endif
  if !has_key(optsyntax, 'arg1')
    let optsyntax['arg1'] = []
  endif
  if !has_key(optsyntax, 'arg1_short')
    let optsyntax['arg1_short'] = []
  endif
  if !has_key(optsyntax, 'arg=')
    let optsyntax['arg='] = []
  endif

  let args = []
  let options = {}
  for arg in a:args
    let found = 0

    for opt in optsyntax['arg=']
      if vimshell#head_match(arg, opt.'=')
        let found = 1

        " Get argument value.
        let options[opt] = arg[len(opt.'='):]

        break
      endif
    endfor
    if found
      " Next argument.
      continue
    endif

    if !found
      call add(args, arg)
    endif
  endfor

  " Set default value.
  for [opt, default] in items(default_values)
    if !has_key(options, opt)
      let options[opt] = default
    endif
  endfor

  return [args, options]
endfunction"}}}
function! s:highlight_with(start, end, syntax)"{{{
  let cnt = get(b:, 'highlight_count', 0)
  if globpath(&runtimepath, 'syntax/' . a:syntax . '.vim') == ''
    return
  endif
  unlet! b:current_syntax
  let save_isk= &l:iskeyword  " For scheme.
  execute printf('syntax include @highlightWith%d syntax/%s.vim',
        \              cnt, a:syntax)
  let &l:iskeyword = save_isk
  execute printf('syntax region highlightWith%d start=/\%%%dl/ end=/\%%%dl$/ '
        \            . 'contains=@highlightWith%d,VimShellError',
        \             cnt, a:start, a:end, cnt)
  let b:highlight_count = cnt + 1
endfunction"}}}

" vim: foldmethod=marker
