"=============================================================================
" FILE: vimshell.vim
" AUTHOR: Janakiraman .S <prince@india.ti.com>(Original)
"         Shougo Matsushita <Shougo.Matsu@gmail.com>(Modified)
" Last Modified: 05 Jul 2009
" Usage: Just source this file.
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
" Version: 5.22, for Vim 7.0
"=============================================================================

" Helper functions.
function! vimshell#set_execute_file(exts, program)"{{{
    for ext in split(a:exts, ',')
        let g:VimShell_ExecuteFileList[ext] = a:program
    endfor
endfunction"}}}

" Special functions."{{{
function! s:special_command(program, args, fd, other_info)"{{{
    let l:program = a:args[0]
    let l:arguments = a:args[1:]
    if has_key(s:internal_func_table, l:program)
        " Internal commands.
        execute printf('call %s(l:program, l:arguments, a:is_interactive, a:has_head_spaces, a:other_info)', 
                    \ s:internal_func_table[l:program])
    else
        call vimshell#internal#exe#execute('exe', insert(l:arguments, l:program), a:fd, a:other_info)
    endif

    return 0
endfunction"}}}
function! s:special_internal(program, args, fd, other_info)"{{{
    if empty(a:args)
        " Print internal commands.
        for func_name in keys(s:internal_func_table)
            call vimshell#print_line(func_name)
        endfor
    else
        let l:program = a:args[0]
        let l:arguments = a:args[1:]
        if has_key(s:internal_func_table, l:program)
            " Internal commands.
            execute printf('call %s(l:program, l:arguments, a:is_interactive, a:has_head_spaces, a:other_info)', 
                        \ s:internal_func_table[l:program])
        else
            " Error.
            call vimshell#error_line('', printf('Not found internal command "%s".', l:program))
        endif
    endif

    return 0
endfunction"}}}
"}}}

function! vimshell#history_complete(findstart, base)"{{{
    if a:findstart
        let l:escaped = escape(getline('.'), '"')
        let l:prompt_pos = match(substitute(l:escaped, "'", "''", 'g'), g:VimShell_Prompt)
        if l:prompt_pos < 0
            " Not found prompt.
            return -1
        endif
        
        return len(g:VimShell_Prompt)
    endif

    " Save options.
    let l:ignorecase_save = &l:ignorecase

    " Complete.
    if g:VimShell_SmartCase && a:base =~ '\u'
        let &l:ignorecase = 0
    else
        let &l:ignorecase = g:VimShell_IgnoreCase
    endif
    " Ignore head spaces.
    let l:cur_keyword_str = substitute(a:base, '^\s\+', '', '')
    let l:complete_words = []
    for hist in g:vimshell#hist_buffer
        if len(hist) > len(l:cur_keyword_str) && hist =~ l:cur_keyword_str
            call add(l:complete_words, { 'word' : hist, 'abbr' : hist, 'dup' : 0 })
        endif
    endfor

    " Restore options.
    let &l:ignorecase = l:ignorecase_save

    return l:complete_words
endfunction"}}}

" VimShell plugin utility functions."{{{
function! vimshell#execute_command(program, args, fd, other_info)"{{{
    if empty(a:args)
        let l:line = a:program
    else
        let l:line = printf('%s %s', a:program, join(a:args, ' '))
    endif
    let l:program = a:program
    let l:arguments = a:args

    " Special commands.
    if l:line =~ '&\s*$'"{{{
        " Background execution.
        return vimshell#internal#bg#execute('bg', split(substitute(l:line, '&\s*$', '', '')), a:fd, a:other_info)
        "}}}
    elseif has_key(g:vimshell#special_func_table, l:program)"{{{
        " Other special commands.
        return call(g:vimshell#special_func_table[l:program], [l:program, l:arguments, a:fd, a:other_info])
        "}}}
    elseif has_key(s:internal_func_table, l:program)"{{{
        " Internal commands.

        " Search pipe.
        let l:args = []
        let l:i = 0
        let l:fd = copy(a:fd)
        for arg in l:arguments
            if arg == '|'
                if l:i+1 == len(l:arguments) 
                    call vimshell#error_line(a:fd, 'Wrong pipe used.')
                    return 0
                endif

                " Create temporary file.
                let l:temp = tempname()
                let l:fd.stdout = l:temp
                call writefile([], l:temp)
                break
            endif
            call add(l:args, arg)
            let l:i += 1
        endfor
        let l:ret = call(s:internal_func_table[l:program], [l:program, l:args, l:fd, a:other_info])

        if l:i < len(l:arguments)
            " Process pipe.
            let l:prog = l:arguments[l:i + 1]
            let l:fd = copy(a:fd)
            let l:fd.stdin = temp
            let l:ret = vimshell#execute_command(l:prog, l:arguments[l:i+2 :], l:fd, a:other_info)
            call delete(l:temp)
        endif

        return l:ret
        "}}}
    elseif isdirectory(substitute(l:line, '^\~\ze[/\\]', substitute($HOME, '\\', '/', 'g'), ''))"{{{
        " Directory.
        " Change the working directory like zsh.

        " Call internal cd command.
        call vimshell#internal#cd#execute('cd', split(l:line), a:fd, a:other_info)
        "}}}
    else"{{{
        let l:ext = fnamemodify(l:program, ':e')
        if !empty(l:ext) && has_key(g:VimShell_ExecuteFileList, l:ext)
            " Execute file.
            let l:execute = split(g:VimShell_ExecuteFileList[l:ext])[0]
            let l:arguments = extend(split(g:VimShell_ExecuteFileList[l:ext])[1:], insert(l:arguments, l:program))
            return vimshell#execute_command(l:execute, l:arguments, a:fd, a:other_info)
        else
            " External commands.

            " Search pipe.
            let l:args = []
            let l:i = 0
            let l:fd = copy(a:fd)
            for arg in l:arguments
                if arg == '|'
                    if l:i+1 == len(l:arguments) 
                        call vimshell#error_line(a:fd, 'Wrong pipe used.')
                        return 0
                    endif

                    " Check internal command.
                    let l:prog = l:arguments[l:i + 1]
                    if !has_key(g:vimshell#special_func_table, l:prog) && !has_key(s:internal_func_table, l:prog)
                        " Create temporary file.
                        let l:temp = tempname()
                        let l:fd.stdout = l:temp
                        call writefile([], l:temp)
                        break
                    endif
                endif
                call add(l:args, arg)
                let l:i += 1
            endfor
            let l:ret = vimshell#internal#exe#execute('exe', insert(l:args, l:program), l:fd, a:other_info)

            if l:i < len(l:arguments)
                " Process pipe.
                let l:fd = copy(a:fd)
                let l:fd.stdin = temp
                let l:ret = vimshell#execute_command(l:prog, l:arguments[l:i+2 :], l:fd, a:other_info)
                call delete(l:temp)
            endif

            return l:ret
        endif
    endif
    "}}}

    return 0
endfunction"}}}
function! vimshell#process_enter()"{{{
    let l:prompt_pos = match(getline('.'), g:VimShell_Prompt)
    if l:prompt_pos < 0
        " Prompt not found
        if match(getline('$'), g:VimShell_Prompt) < 0
            " Create prompt line.
            call append(line('$'), g:VimShell_Prompt)
            normal! G$
            call vimshell#start_insert()
        else
            echohl WarningMsg | echo "Not on the command line." | echohl None
            normal! G$
        endif
        return
    endif

    if line('.') != line('$')
        " History execution.
        if match(getline('$'), g:VimShell_Prompt) < 0
            " Insert prompt line.
            call append(line('$'), getline('.'))
        else
            " Set prompt line.
            call setline(line('$'), getline('.'))
        endif
        normal! G$
    endif

    " Check current directory.
    if !exists('w:vimshell_directory_stack')
        let w:vimshell_directory_stack = []
        let w:vimshell_directory_stack[0] = getcwd()
    endif
    if empty(w:vimshell_directory_stack) || getcwd() != w:vimshell_directory_stack[0]
        " Push current directory.
        call insert(w:vimshell_directory_stack, getcwd())
    endif

    " Delete prompt string.
    let l:line = substitute(getline('.'), g:VimShell_Prompt, '', '')

    " Delete comment.
    let l:line = substitute(l:line, '#.*$', '', '')

    if getfsize(g:VimShell_HistoryPath) != s:hist_size
        " Reload.
        let g:vimshell#hist_buffer = readfile(g:VimShell_HistoryPath)
    endif
    " Not append history if starts spaces or dups.
    if l:line !~ '^\s'
        call vimshell#append_history(l:line)
    endif

    " Delete head spaces.
    let l:line = substitute(l:line, '^\s\+', '', '')
    if l:line =~ '^\s*$'
        " Ignore empty command line.
        call setline(line('.'), g:VimShell_Prompt)

        call vimshell#start_insert()
        return
    endif

    try
        let l:program = split(l:line)[0]
        let l:string = substitute(l:line, '^'.l:program, '', '')
        let [l:program, l:args, l:fd] = vimshell#parser#eval_script(l:string, l:program)
    catch /^Quote/
        call vimshell#error_line('', 'Quote error.')
        call vimshell#print_prompt()
        call interactive#highlight_escape_sequence()

        call vimshell#start_insert()
        return
    endtry

    let l:other_info = { 'has_head_spaces' : l:line =~ '^\s\+', 'is_interactive' : 1, 'is_background' : 0 }

    " Interactive execute.
    let l:skip_prompt = vimshell#execute_command(l:program, l:args, l:fd, l:other_info)
    call interactive#highlight_escape_sequence()

    if l:skip_prompt
        " Skip prompt.
        return
    endif

    call vimshell#print_prompt()
    call vimshell#start_insert()
endfunction"}}}

function! vimshell#read(fd)"{{{
    if has('win32') || has('win64')
        let l:ff = "\<CR>\<LF>"
    else
        let l:ff = "\<LF>"
    endif

    return join(readfile(a:fd.stdin), l:ff) . l:ff
endfunction"}}}
function! vimshell#print(fd, string)"{{{
    if a:string == ''
        return
    endif

    if a:fd.stdout != ''
        if a:fd.stdout != '/dev/null'
            " Write file.
            let l:file = extend(readfile(a:fd.stdout), split(a:string, '\r\n\|\n'))
            call writefile(l:file, a:fd.stdout)
        endif

        return
    endif

    " Convert encoding for system().
    if has('win32') || has('win64')
        let l:string = iconv(a:string, 'cp932', &encoding) 
    else
        let l:string = iconv(a:string, 'utf-8', &encoding) 
    endif

    if l:string =~ '\r[[:print:]]'
        " Set line.
        for line in split(l:string, '\r\n\|\n')
            call append(line('$'), '')

            for l in split(line, '\r')
                call setline(line('$'), l)
                redraw
            endfor
        endfor
    else
        for line in split(l:string, '\r\n\|\r\|\n')
            call append(line('$'), line)
        endfor
    endif

    " Set cursor.
    normal! G
endfunction"}}}
function! vimshell#print_line(fd, string)"{{{
    if a:fd.stdout != ''
        if a:fd.stdout != '/dev/null'
            " Write file.
            let l:file = add(readfile(a:fd.stdout), a:string)
            call writefile(l:file, a:fd.stdout)
        endif

        return
    else
        call append(line('$'), a:string)
        normal! j
    endif
endfunction"}}}
function! vimshell#error_line(fd, string)"{{{
    if a:fd.stderr != ''
        if a:fd.stdout != '/dev/null'
            " Write file.
            let l:file = extend(readfile(a:fd.stderr), split(a:string, '\r\n\|\n'))
            call writefile(l:file, a:fd.stderr)
        endif

        return
    else
        call append(line('$'), '!!! '.a:string.' !!!')
        normal! j
    endif
endfunction"}}}
function! vimshell#print_prompt()"{{{
    let l:escaped = escape(getline('.'), "\'")
    " Search prompt
    if !exists('b:vimshell_commandline_stack')
        let b:vimshell_commandline_stack = []
    endif
    if empty(b:vimshell_commandline_stack)
        let l:new_prompt = g:VimShell_Prompt
    else
        let l:new_prompt = b:vimshell_commandline_stack[-1]
        call remove(b:vimshell_commandline_stack, -1)
    endif
    if match(l:escaped, g:VimShell_Prompt) < 0
        " Prompt not found
        if !empty(l:escaped)
            " Insert prompt line.
            call append(line('$'), l:new_prompt)
            normal! j
        else
            " Set prompt line.
            call setline(line('$'), l:new_prompt)
        endif
        normal! $
    else
        " Insert prompt line.
        call append(line('$'), l:new_prompt)
        normal! j$
    endif
    let &modified = 0
endfunction"}}}
function! vimshell#append_history(command)"{{{
    " Reduce blanks.
    let l:command = substitute(a:command, '\s\+', ' ', 'g')
    " Filtering.
    call insert(filter(g:vimshell#hist_buffer, printf("v:val != '%s'", l:command)), l:command)

    " Trunk.
    let g:vimshell#hist_buffer = g:vimshell#hist_buffer[:g:VimShell_HistoryMaxSize-1]

    call writefile(g:vimshell#hist_buffer, g:VimShell_HistoryPath)

    let s:hist_size = getfsize(g:VimShell_HistoryPath)
endfunction"}}}
function! vimshell#remove_history(command)"{{{
    " Filtering.
    call filter(g:vimshell#hist_buffer, printf("v:val !~ '^%s\s*'", a:command))

    call writefile(g:vimshell#hist_buffer, g:VimShell_HistoryPath)

    let s:hist_size = getfsize(g:VimShell_HistoryPath)
endfunction"}}}

function! vimshell#start_insert()"{{{
    " Enter insert mode.
    startinsert!
    set iminsert=0 imsearch=0
endfunction"}}}
"}}}

" VimShell key-mappings function."{{{
function! vimshell#insert_command_completion()"{{{
    " Set function.
    let &l:omnifunc = 'vimshell#smart_omni_completion'
endfunction"}}}
function! vimshell#smart_omni_completion(findstart, base)"{{{
    if a:findstart
        " Get cursor word.
        let l:cur_text = strpart(getline('.'), 0, col('.') - 1) 

        return match(l:cur_text, '\f\+$')
    endif

    " Save option.
    let l:ignorecase_save = &ignorecase

    " Complete.
    if g:VimShell_SmartCase && a:base =~ '\u'
        let &ignorecase = 0
    else
        let &ignorecase = g:VimShell_IgnoreCase
    endif

   let l:complete_words = s:get_complete_words(a:base)

    " Restore option.
    let &ignorecase = l:ignorecase_save

    " Restore option.
    let &l:omnifunc = 'vimshell#history_complete'

    return l:complete_words
endfunction"}}}

function! vimshell#push_current_line()"{{{
    " Check current line.
    if match(getline('.'), g:VimShell_Prompt) < 0
        return
    endif

    call add(b:vimshell_commandline_stack, getline('.'))

    " Set prompt line.
    call setline(line('.'), g:VimShell_Prompt)
endfunction"}}}

function! vimshell#previous_prompt()"{{{
    call search('^' . substitute(escape(g:VimShell_Prompt, '"\.^$*[]'), "'", "''", 'g'), 'bWe')
endfunction"}}}
function! vimshell#next_prompt()"{{{
    call search('^' . substitute(escape(g:VimShell_Prompt, '"\.^$*[]'), "'", "''", 'g'), 'We')
endfunction"}}}
function! vimshell#switch_shell(split_flag)"{{{
    if &filetype == 'vimshell'
        if winnr('$') != 1
            close
        else
            buffer #
        endif

        return
    endif

    " Search VimShell window.
    let l:cnt = 1
    while l:cnt <= winnr('$')
        if getwinvar(l:cnt, '&filetype') == 'vimshell'
            let l:current = getcwd()

            execute l:cnt . 'wincmd w'

            " Change current directory.
            let b:vimshell_save_dir = l:current
            lcd `=fnamemodify(l:current, ':p')`

            call vimshell#start_insert()

            call vimshell#print_prompt()
            return
        endif

        let l:cnt += 1
    endwhile

    " Search VimShell buffer.
    let l:cnt = 1
    while l:cnt <= bufnr('$')
        if getbufvar(l:cnt, '&filetype') == 'vimshell'
            let l:current = getcwd()

            if a:split_flag
                execute 'sbuffer' . l:cnt
                execute 'resize' . winheight(0)*g:VimShell_SplitHeight / 100
            else
                execute 'buffer' . l:cnt
            endif

            " Change current directory.
            let b:vimshell_save_dir = l:current
            lcd `=fnamemodify(l:current, ':p')`

            call vimshell#start_insert()

            call vimshell#print_prompt()
            return
        endif

        let l:cnt += 1
    endwhile

    " Create window.
    call vimshell#create_shell(a:split_flag)
endfunction"}}}
function! vimshell#delete_previous_prompt()"{{{
    let l:prompt = substitute(escape(g:VimShell_Prompt, '"\.^$*[]'), "'", "''", 'g')
    if getline('.') =~ l:prompt
        let l:next_line = line('.')
        normal! 0
    else
        let [l:next_line, l:next_col] = searchpos('^' . l:prompt, 'Wn')
    endif
    let [l:prev_line, l:prev_col] = searchpos('^' . l:prompt, 'bWn')
    if l:next_line - l:prev_line > 1
        execute printf('%s,%sdelete', l:prev_line+1, l:next_line-1)
        call append(line('.')-1, "* Output was deleted *")
    endif
    normal! $
endfunction"}}}
function! vimshell#insert_last_word()"{{{
    let l:word = ''
    if !empty(g:vimshell#hist_buffer)
        for w in reverse(split(g:vimshell#hist_buffer[0], '[^\\]\zs\s'))
            if w =~ '[[:alpha:]_/\\]\{2,}'
                let l:word = w
                break
            endif
        endfor
    endif
    call setline(line('.'), getline('.') . l:word)
    startinsert!
endfunction"}}}
function! vimshell#run_help()"{{{
    if match(getline('.'), g:VimShell_Prompt) < 0
        startinsert!
        return
    endif

    " Delete prompt string.
    let l:line = substitute(getline('.'), g:VimShell_Prompt, '', '')
    if l:line =~ '^\s*$'
        startinsert!
        return
    endif

    let l:program = split(l:line)[0]
    if l:program !~ '\h\w*'
        startinsert!
        return
    endif

    call vimshell#internal#bg#execute('bg', ['man', '-p', 'cat', l:program], 
                \{'stdin' : '', 'stdout' : '', 'stderr' : ''}, {'is_interactive' : 0, 'is_background' : 1})
    startinsert!
endfunction"}}}

function! vimshell#create_shell(split_flag)"{{{
    let l:bufname = 'vimshell'
    let l:cnt = 2
    while bufexists(l:bufname)
        let l:bufname = printf('[%d]vimshell', l:cnt)
        let l:cnt += 1
    endwhile

    if a:split_flag
        execute 'split +setfiletype\ vimshell ' . l:bufname
        execute 'resize' . winheight(0)*g:VimShell_SplitHeight / 100
    else
        execute 'edit +setfiletype\ vimshell ' . l:bufname
    endif

    setlocal buftype=nofile
    setlocal noswapfile
    let &l:omnifunc = 'vimshell#history_complete'

    " Save current directory.
    let b:vimshell_save_dir = getcwd()

    " Load history.
    if !filereadable(g:VimShell_HistoryPath)
        " Create file.
        call writefile([], g:VimShell_HistoryPath)
    endif
    let g:vimshell#hist_buffer = readfile(g:VimShell_HistoryPath)
    let s:hist_size = getfsize(g:VimShell_HistoryPath)

    if !exists('s:prev_numbered_list')
        let s:prev_numbered_list = []
    endif
    if !exists('s:prepre_numbered_list')
        let s:prepre_numbered_list = []
    endif
    if !exists('b:vimshell_alias_table')
        let b:vimshell_alias_table = {}
    endif
    if !exists('s:internal_func_table')
        let s:internal_func_table = {}

        " Search autoload.
        for list in split(globpath(&runtimepath, 'autoload/vimshell/internal/*.vim'), '\n')
            let l:func_name = fnamemodify(list, ':t:r')
            let s:internal_func_table[l:func_name] = 'vimshell#internal#' . l:func_name . '#execute'
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
    if !exists('w:vimshell_directory_stack')
        let w:vimshell_directory_stack = []
        let w:vimshell_directory_stack[0] = getcwd()
    endif
    " Load rc file.
    if filereadable(g:VimShell_VimshrcPath) && !exists('b:vimshell_loaded_vimshrc')
        let l:fd = {}
        let l:other_info = { 'has_head_spaces' : 0, 'is_interactive' : 0 }
        call vimshell#internal#vimsh#execute('vimsh', [g:VimShell_VimshrcPath], l:fd, l:other_info)
        let b:vimshell_loaded_vimshrc = 1
    endif
    if !exists('b:vimshell_commandline_stack')
        let b:vimshell_commandline_stack = []
    endif
    if !exists('b:vimshell_variables')
        let b:vimshell_variables = {}
    endif
    if !exists('b:vimshell_system_variables')
        let b:vimshell_system_variables = { 'status' : 0 }
    endif

    " Set environment variables.
    let $TERM = "dumb"
    let $TERMCAP = "COLUMNS=" . winwidth(0)
    let $VIMSHELL = 1
    let $COLUMNS = winwidth(0) * 8 / 10
    let $LINES = winheight(0) * 8 / 10

    call vimshell#print_prompt()

    call vimshell#start_insert()
endfunction"}}}

"}}}

function! s:save_current_dir()"{{{
    let l:current_dir = getcwd()
    lcd `=fnamemodify(b:vimshell_save_dir, ':p')`
    let b:vimshell_save_dir = l:current_dir
endfunction"}}}
function! s:restore_current_dir()"{{{
    let l:current_dir = getcwd()
    if l:current_dir != b:vimshell_save_dir
        lcd `=fnamemodify(b:vimshell_save_dir, ':p')`
        let b:vimshell_save_dir = l:current_dir
    endif
endfunction"}}}

function! s:get_complete_words(cur_keyword_str)"{{{
    let l:ret = []
    let l:pattern = printf('v:val =~ "^%s"', a:cur_keyword_str)

    for keyword in filter(keys(b:vimshell_alias_table), l:pattern)
        let l:dict = { 'word' : keyword . ' ', 'abbr' : keyword, 'menu' : '[Alias]', 'icase' : 1 }
        call add(l:ret, l:dict)
    endfor 

    for keyword in filter(keys(g:vimshell#special_func_table), l:pattern)
        let l:dict = { 'word' : keyword . ' ', 'abbr' : keyword, 'menu' : '[Special]', 'icase' : 1 }
        call add(l:ret, l:dict)
    endfor 

    for keyword in filter(keys(s:internal_func_table), l:pattern)
        let l:dict = { 'word' : keyword . ' ', 'abbr' : keyword, 'menu' : '[Internal]', 'icase' : 1 }
        call add(l:ret, l:dict)
    endfor 

    for keyword in filter(split(glob(a:cur_keyword_str . '*'), '\n'), 'isdirectory(v:val)')
        let l:dict = { 'word' : keyword, 'abbr' : keyword . '/', 'menu' : '[Dir]', 'icase' : 1 }
        call add(l:ret, l:dict)
    endfor 

    if a:cur_keyword_str =~ '\h\w\+$'
        " External commands.
        if has('win32') || has('win64')
            let l:path = substitute($PATH, '\\\?;', ',', 'g')
        else
            let l:path = substitute($PATH, '/\?:', ',', 'g')
        endif

        for keyword in map(filter(split(globpath(l:path, a:cur_keyword_str . '*'), '\n'),
                    \'executable(v:val)'), 'fnamemodify(v:val, ":t")')
            let l:dict = { 'word' : keyword . ' ', 'abbr' : keyword, 'menu' : '[Command]', 'icase' : 1 }
            call add(l:ret, l:dict)
        endfor 
    endif

    return l:ret
endfunction"}}}

augroup VimShellAutoCmd"{{{
    autocmd!
    autocmd BufEnter * if &filetype == 'vimshell' | call s:save_current_dir()
    autocmd BufLeave * if &filetype == 'vimshell' | call s:restore_current_dir()
augroup end"}}}

" vim: foldmethod=marker
