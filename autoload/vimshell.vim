"=============================================================================
" FILE: vimshell.vim
" AUTHOR: Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 12 Jun 2010
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
  return '7.0'
endfunction"}}}

" Check vimproc.
let s:is_vimproc = exists('*vimproc#system')
let s:is_version = exists('*vimproc#version')
if !s:is_vimproc
  echoerr 'vimproc is not installed. Please install vimproc Ver.4.0 or above.'
  finish
elseif !s:is_version
  echoerr 'Please install vimproc Ver.4.0 or above.'
  finish
endif

" Initialize."{{{
let s:prompt = exists('g:vimshell_prompt') ? g:vimshell_prompt : 'vimshell% '
let s:secondary_prompt = exists('g:vimshell_secondary_prompt') ? g:vimshell_secondary_prompt : '%% '
let s:user_prompt = exists('g:vimshell_user_prompt') ? g:vimshell_user_prompt : ''
let s:right_prompt = exists('g:vimshell_right_prompt') ? g:vimshell_right_prompt : ''
if !exists('g:vimshell_execute_file_list')
  let g:vimshell_execute_file_list = {}
endif

" Disable bell.
set vb t_vb=
"}}}

function! vimshell#head_match(checkstr, headstr)"{{{
  return a:headstr == '' || a:checkstr ==# a:headstr
        \|| a:checkstr[: len(a:headstr)-1] ==# a:headstr
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

augroup vimshell
  autocmd!
  autocmd GUIEnter * set vb t_vb=
augroup end

" User utility functions.
function! vimshell#default_settings()"{{{
  setlocal buftype=nofile
  setlocal noswapfile
  setlocal bufhidden=hide
  setlocal noreadonly
  setlocal nolist
  setlocal tabstop=8
  setlocal iskeyword+=-,+,.,\\,!,~
  setlocal omnifunc=vimshell#complete#auto_complete#omnifunc
  
  " Set autocommands.
  augroup vimshell
    autocmd BufWinEnter,WinEnter <buffer> call s:restore_current_dir()
  augroup end

  " Define mappings.
  call vimshell#mappings#define_default_mappings()
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

  " Initialize functions table.
  if !exists('g:vimshell#internal_func_table')
    let g:vimshell#internal_func_table = {}

    " Search autoload.
    for list in split(globpath(&runtimepath, 'autoload/vimshell/internal/*.vim'), '\n')
      let l:func_name = fnamemodify(list, ':t:r')
      let g:vimshell#internal_func_table[l:func_name] = 'vimshell#internal#' . l:func_name . '#execute'
    endfor
  endif
  if !exists('g:vimshell#special_func_table')
    " Initialize table.
    let g:vimshell#special_func_table = {
          \ 'command' : 's:special_command',
          \ 'internal' : 's:special_internal',
          \}

    " Search autoload.
    for list in split(globpath(&runtimepath, 'autoload/vimshell/special/*.vim'), '\n')
      let l:func_name = fnamemodify(list, ':t:r')
      let g:vimshell#special_func_table[l:func_name] = 'vimshell#special#' . l:func_name . '#execute'
    endfor
  endif

  " Load history.
  let l:history_path = g:vimshell_temporary_directory . '/command-history'
  if !filereadable(l:history_path)
    " Create file.
    call writefile([], l:history_path)
  endif
  let g:vimshell#hist_buffer = readfile(l:history_path)
  let g:vimshell#hist_size = getfsize(l:history_path)

  " Initialize variables.
  let b:vimshell = {}

  " Change current directory.
  let b:vimshell.save_dir = getcwd()
  let l:current = (a:directory != '')? a:directory : getcwd()
  lcd `=fnamemodify(l:current, ':p')`

  let b:vimshell.alias_table = {}
  let b:vimshell.galias_table = {}
  let b:vimshell.altercmd_table = {}
  let b:vimshell.commandline_stack = []
  let b:vimshell.variables = {}
  let b:vimshell.system_variables = { 'status' : 0 }
  let b:vimshell.directory_stack = []
  let b:vimshell.prompt_current_dir = {}
  let b:vimshell.hook_functions_table = {
        \ 'preprompt' : [], 'preparse' : [], 'preexec' : [], 'emptycmd' : [], 
        \ 'chpwd' : [], 'notfound' : [],
        \}

  " Set environment variables.
  let $TERM = 'vt100'
  let $TERMCAP = 'COLUMNS=' . winwidth(0)
  let $VIMSHELL = 1
  let $COLUMNS = winwidth(0) * 8 / 10
  let $LINES = winheight(0) * 8 / 10
  let $SHELL = 'vimshell'
  let $EDITOR = 'cat'
  
  " Default settings.
  call vimshell#default_settings()

  let l:context = {
        \ 'has_head_spaces' : 0,
        \ 'is_interactive' : 1, 
        \ 'is_insert' : 1, 
        \ 'fd' : { 'stdin' : '', 'stdout': '', 'stderr': ''}, 
        \}
  call vimshell#set_context(l:context)
  
  " Load rc file.
  if filereadable(g:vimshell_vimshrc_path)
    call vimshell#execute_internal_command('vimsh', [g:vimshell_vimshrc_path], {}, 
          \{ 'has_head_spaces' : 0, 'is_interactive' : 0 })
    let b:vimshell.loaded_vimshrc = 1
  endif
  
  setfiletype vimshell
  
  call vimshell#print_prompt(l:context)

  call vimshell#start_insert()

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
  
  if &filetype == 'vimshell'
    if winnr('$') != 1
      close
    else
      buffer #
    endif

    if a:directory != ''
      " Change current directory.
      lcd `=fnamemodify(a:directory, ':p')`

      call vimshell#print_prompt(l:context)
    endif
    call vimshell#start_insert()
    return
  endif

  " Search VimShell window.
  let l:cnt = 1
  while l:cnt <= winnr('$')
    if getwinvar(l:cnt, '&filetype') == 'vimshell'

      execute l:cnt . 'wincmd w'

      if a:directory != ''
        " Change current directory.
        lcd `=fnamemodify(a:directory, ':p')`
        call vimshell#print_prompt(l:context)
      endif
      call vimshell#start_insert()
      return
    endif

    let l:cnt += 1
  endwhile

  " Search VimShell buffer.
  let l:cnt = 1
  while l:cnt <= bufnr('$')
    if getbufvar(l:cnt, '&filetype') == 'vimshell'
      if a:split_flag
        execute winheight(0)*g:vimshell_split_height / 100 'sbuffer' l:cnt
      else
        execute 'buffer' l:cnt
      endif

      if a:directory != ''
        " Change current directory.
        lcd `=fnamemodify(a:directory, ':p')`
        call vimshell#print_prompt(l:context)
      endif
      call vimshell#start_insert()
      return
    endif

    let l:cnt += 1
  endwhile

  " Create window.
  call vimshell#create_shell(a:split_flag, a:directory)
endfunction"}}}

function! vimshell#execute_internal_command(command, args, fd, other_info)"{{{
  if empty(a:fd)
    let l:fd = { 'stdin' : '', 'stdout' : '', 'stderr' : '' }
  else
    let l:fd = a:fd
  endif

  if empty(a:other_info)
    let l:other_info = { 'has_head_spaces' : 0, 'is_interactive' : 1 }
  else
    let l:other_info = a:other_info
  endif

  return call('vimshell#internal#' . a:command . '#execute', [a:command, a:args, l:fd, l:other_info])
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
  if a:string == ''
    return
  endif

  if !empty(a:fd) && a:fd.stdout != ''
    if a:fd.stdout == '/dev/null'
      " Nothing.
    elseif a:fd.stdout == '/dev/clip'
      " Write to clipboard.
      let @+ .= a:string
    else
      " Write file.
      let l:file = extend(readfile(a:fd.stdout), split(a:string, '\r\n\|\n'))
      call writefile(l:file, a:fd.stdout)
    endif

    return
  endif

  call vimshell#terminal#print(a:string)
endfunction"}}}
function! vimshell#print_line(fd, string)"{{{
  if !empty(a:fd) && a:fd.stdout != ''
    if a:fd.stdout == '/dev/null'
      " Nothing.
    elseif a:fd.stdout == '/dev/clip'
      " Write to clipboard.
      let @+ .= a:string
    else
      let l:string = (&termencoding != '' && &encoding != &termencoding) ?
            \ iconv(a:string, &encoding, &termencoding) : a:string
      
      " Write file.
      let l:file = add(readfile(a:fd.stdout), a:string)
      call writefile(l:file, a:fd.stdout)
    endif

    return
  elseif line('$') == 1 && getline('$') == ''
    call setline('$', a:string)
  else
    call append('$', a:string)
  endif

  $
endfunction"}}}
function! vimshell#error_line(fd, string)"{{{
  if !empty(a:fd) && a:fd.stderr != ''
    if a:fd.stderr == '/dev/null'
      " Nothing.
    elseif a:fd.stderr == '/dev/clip'
      " Write to clipboard.
      let @+ .= a:string
    else
      let l:string = (&termencoding != '' && &encoding != &termencoding) ?
            \ iconv(a:string, &encoding, &termencoding) : a:string
      
      " Write file.
      let l:file = extend(readfile(a:fd.stderr), split(a:string, '\r\n\|\n'))
      call writefile(l:file, a:fd.stderr)
    endif

    return
  endif

  let l:string = '!!!' . a:string . '!!!'

  if line('$') == 1 && getline('$') == ''
    call setline('$', l:string)
  else
    call append('$', l:string)
  endif

  $
endfunction"}}}
function! vimshell#print_prompt(...)"{{{
  " Save current directory.
  let b:vimshell.prompt_current_dir[vimshell#get_prompt_linenr()] = getcwd()

  let l:context = a:0 >= 1? a:1 : vimshell#get_context()
  
  $
  
  " Call preprompt hook.
  call vimshell#hook#call('preprompt', l:context)
  
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
  " Insert secondary prompt line.
  call append('$', vimshell#get_secondary_prompt())
  $
  let &modified = 0
endfunction"}}}
function! vimshell#append_history(command)"{{{
  " Reduce blanks.
  let l:command = substitute(a:command, '\s\+', ' ', 'g')
  " Filtering.
  call insert(filter(g:vimshell#hist_buffer, printf("v:val != '%s'", substitute(l:command, "'", "''", 'g'))), l:command)

  " Trunk.
  let g:vimshell#hist_buffer = g:vimshell#hist_buffer[:g:vimshell_history_max_size-1]

  let l:history_path = g:vimshell_temporary_directory . '/command-history'
  call writefile(g:vimshell#hist_buffer, l:history_path)

  let vimshell#hist_size = getfsize(l:history_path)
endfunction"}}}
function! vimshell#remove_history(command)"{{{
  " Filtering.
  call filter(g:vimshell#hist_buffer, printf("v:val !~ '^%s\s*'", a:command))

  let l:history_path = g:vimshell_temporary_directory . '/command-history'
  call writefile(g:vimshell#hist_buffer, l:history_path)

  let vimshell#hist_size = getfsize(l:history_path)
endfunction"}}}
function! vimshell#getfilename(program)"{{{
  " Command search.
  if vimshell#iswin()
    let l:path = substitute($PATH, '\\\?;', ',', 'g')
    let l:files = ''
    for ext in ['', '.bat', '.cmd', '.exe']
      let l:files = globpath(l:path, a:program.ext)
      if !empty(l:files)
        break
      endif
    endfor

    let l:namelist = filter(split(l:files, '\n'), 'executable(v:val)')
  else
    let l:path = substitute($PATH, '/\?:', ',', 'g')
    let l:namelist = filter(split(globpath(l:path, a:program), '\n'), 'executable(v:val)')
  endif

  if empty(l:namelist)
    return ''
  else
    return l:namelist[0]
  endif
endfunction"}}}
function! vimshell#start_insert(...)"{{{
  let l:is_insert = (a:0 == 0)? 1 : a:1

  if l:is_insert
    " Enter insert mode.
    $
    startinsert!

    if exists('&iminsert')
      let &l:iminsert = 0
    endif
  else
    normal! $
  endif
endfunction"}}}
function! vimshell#escape_match(str)"{{{
  return escape(a:str, '~" \.^$[]')
endfunction"}}}
function! vimshell#get_prompt()"{{{
  return s:prompt
endfunction"}}}
function! vimshell#get_secondary_prompt()"{{{
  return s:secondary_prompt
endfunction"}}}
function! vimshell#get_user_prompt()"{{{
  return s:user_prompt
endfunction"}}}
function! vimshell#get_cur_text()"{{{
  " Get cursor text without prompt.
  let l:pos = mode() ==# 'i' ? 2 : 1

  let l:cur_text = col('.') < l:pos ? '' : getline('.')[: col('.') - l:pos]

  if l:cur_text != '' && char2nr(l:cur_text[-1:]) >= 0x80
    let l:len = len(getline('.'))

    " Skip multibyte
    let l:pos -= 1
    let l:cur_text = getline('.')[: col('.') - l:pos]
    let l:fchar = char2nr(l:cur_text[-1:])
    while col('.')-l:pos+1 < l:len && l:fchar >= 0x80
      let l:pos -= 1

      let l:cur_text = getline('.')[: col('.') - l:pos]
      let l:fchar = char2nr(l:cur_text[-1:])
    endwhile
  endif
  return l:cur_text[len(vimshell#get_prompt()):]
endfunction"}}}
function! vimshell#get_prompt_command()"{{{
  " Get command without prompt.
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
  let l:pos = mode() ==# 'i' ? 2 : 1
  return col('.') < l:pos ? '' : getline('.')[: col('.') - l:pos]
endfunction"}}}
function! vimshell#get_current_args()"{{{
  let l:statements = vimshell#parser#split_statements(vimshell#get_cur_text())
  if empty(l:statements)
    return []
  endif
  
  let l:commands = vimshell#parser#split_commands(l:statements[-1])
  if empty(l:commands)
    return []
  endif
  
  let l:args = vimshell#parser#split_args_through(l:commands[-1])
  if vimshell#get_cur_text() =~ '\\\@!\s\+$'
    " Add blank argument.
    call add(l:args, '')
  endif
  return l:args
endfunction"}}}
function! vimshell#check_prompt(...)"{{{
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
  let l:input = join(a:000)
  if &termencoding != '' && &termencoding != &encoding
    let l:command = iconv(l:command, &encoding, &termencoding)
    let l:input = iconv(l:input, &encoding, &termencoding)
  endif
  let l:output = a:0 == 0 ? vimproc#system(l:command) : vimproc#system(l:command, l:input)
  if &termencoding != '' && &termencoding != &encoding
    let l:output = iconv(l:output, &termencoding, &encoding)
  endif
  return l:output
endfunction"}}}
function! vimshell#open(filename)"{{{
  let l:filename = a:filename
  if &termencoding != '' && &encoding != &termencoding
    " Convert encoding.
    let l:filename = iconv(l:filename, &encoding, &termencoding)
  endif
  
  " Detect desktop environment.
  if vimshell#iswin()
    if !isdirectory(a:filename) && executable('fiber.exe')
      call vimshell#system('fiber "' . l:filename . '"')
    else
      execute printf('silent ! start "" "%s"', l:filename)
    endif
  elseif has('win32unix')
    " Cygwin.
    call vimshell#system('cygstart ''' . l:filename . '''')
  elseif executable('xdg-open')
    " Linux.
    call vimshell#system('xdg-open ''' . l:filename . ''' &')
  elseif exists('$KDE_FULL_SESSION') && $KDE_FULL_SESSION ==# 'true'
    " KDE.
    call vimshell#system('kioclient exec ''' . l:filename . '''')
  elseif exists('$GNOME_DESKTOP_SESSION_ID')
    " GNOME.
    call vimshell#system('gnome-open ''' . l:filename . ''' &')
  elseif executable('exo-open')
    " Xfce.
    call vimshell#system('exo-open ''' . l:filename . ''' &')
  elseif (has('macunix') || system('uname') =~? '^darwin') && executable('open')
    " Mac OS.
    call vimshell#system('open ''' . l:filename . ''' &')
  else
    throw 'Not supported.'
  endif
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
        \'^\s*\%([^[:blank:]]\|\\[^[:alnum:].-]\)\+\ze\%($\|\s*\%(=\s*\)\?\)'
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
  if winwidth(0) > 2 * &winwidth
    vsplit
  else
    split
  endif
endfunction"}}}
function! vimshell#compare_number(i1, i2)"{{{
  return a:i1 == a:i2 ? 0 : a:i1 > a:i2 ? 1 : -1
endfunction"}}}
function! vimshell#alternate_buffer()"{{{
  if bufnr('%') != bufnr('#') && buflisted(bufnr('#'))
    buffer #
  else
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
  endif
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

" Special functions.
function! s:special_command(program, args, fd, other_info)"{{{
  let l:program = a:args[0]
  let l:arguments = a:args[1:]
  if has_key(g:vimshell#internal_func_table, l:program)
    " Internal commands.
    execute printf('call %s(l:program, l:arguments, a:is_interactive, a:has_head_spaces, a:other_info)', 
          \ g:vimshell#internal_func_table[l:program])
  else
    call vimshell#execute_internal_command('exe', insert(l:arguments, l:program), a:fd, a:other_info)
  endif

  return
endfunction"}}}
function! s:special_internal(program, args, fd, other_info)"{{{
  if empty(a:args)
    " Print internal commands.
    for func_name in keys(g:vimshell#internal_func_table)
      call vimshell#print_line(func_name)
    endfor
  else
    let l:program = a:args[0]
    let l:arguments = a:args[1:]
    if has_key(g:vimshell#internal_func_table, l:program)
      " Internal commands.
      execute printf('call %s(l:program, l:arguments, a:is_interactive, a:has_head_spaces, a:other_info)', 
            \ g:vimshell#internal_func_table[l:program])
    else
      " Error.
      call vimshell#error_line('', printf('Not found internal command "%s".', l:program))
    endif
  endif

  return
endfunction"}}}


function! s:restore_current_dir()"{{{
  if !exists('b:vimshell')
    return
  endif

  lcd `=fnamemodify(b:vimshell.save_dir, ':p')`
endfunction"}}}

" vim: foldmethod=marker
