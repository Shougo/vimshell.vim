"=============================================================================
" FILE: vimshell.vim
" AUTHOR: Janakiraman .S <prince@india.ti.com>(Original)
"         Shougo Matsushita <Shougo.Matsu@gmail.com>(Modified)
" Last Modified: 26 May 2009
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
" Version: 5.12, for Vim 7.0
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
            call vimshell#error_line(printf('Not found internal command "%s".', l:program))
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

    " Check alias."{{{
    if has_key(b:vimshell_alias_table, l:program) && !empty(b:vimshell_alias_table[l:program])
        let l:alias = split(b:vimshell_alias_table[l:program])
        let l:program = l:alias[0]
        let l:arguments = l:alias[1:]
        let l:line = l:program . ' ' . join(l:arguments)
    endif"}}}

    " Eval environment variable."{{{
    "let l:match = matchstr(l:line, '\$\w\+')
    "if !empty(l:match)
        "while !empty(l:match)
            "let l:line = substitute(l:line, l:match, eval(l:match), 'g')
            "let l:match = matchstr(l:line, '\$\w\+')
        "endwhile

        "let l:program = (empty(l:line))? '' : split(l:line)[0]
        "let l:arguments = substitute(l:line, '^' . l:program . '\s*', '', '')
    "endif
    if l:program =~ '^\s*\$\w\+$'
        let l:program = eval(l:program)
    endif
    "}}}

    " Special commands.
    if l:program =~ '^\w*=' "{{{
        " Variables substitution.
        execute 'silent let $' . l:program
        "}}}
    elseif l:line =~ '&\s*$'"{{{
        " Background execution.
        return vimshell#internal#bg#execute('bg', split(substitute(l:line, '&\s*$', '', '')), a:fd, a:other_info)
        "}}}
    elseif l:program =~ '^!'"{{{
        if l:program == '!!' && a:other_info.is_interactive
            " Previous command execution.
            if get(g:vimshell#hist_buffer, 0) =~ '^!!'
                " Delete from history.
                call remove(g:vimshell#hist_buffer, 0)
            endif

            return vimshell#internal#h#execute('h', '0', a:fd, a:other_info)
        elseif l:program =~ '!\d\+$' && a:other_info.is_interactive
            " History command execution.
            if get(g:vimshell#hist_buffer, 0) =~ '^!\d\+'
                " Delete from history.
                call remove(g:vimshell#hist_buffer, 0)
            endif

            return vimshell#internal#h#execute('h', str2nr(l:program[1:]), a:fd, a:other_info)
        else
            " Shell execution.
            execute printf('%s %s', l:program, join(l:arguments, ' '))
        endif"}}}
    elseif has_key(s:special_func_table, l:program)"{{{
        " Other special commands.
        return call(s:special_func_table[l:program], [l:program, l:arguments, a:fd, a:other_info])
        "}}}
    elseif has_key(s:internal_func_table, l:program)"{{{
        " Internal commands.
        return call(s:internal_func_table[l:program], [l:program, l:arguments, a:fd, a:other_info])
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
            return vimshell#execute_command(g:VimShell_ExecuteFileList[l:ext], insert(l:arguments, l:program), a:fd, a:other_info)
        else
            " External commands.
            call vimshell#internal#exe#execute('exe', insert(l:arguments, l:program), a:fd, a:other_info)
        endif
    endif
    "}}}

    return 0
endfunction"}}}
function! vimshell#process_enter()"{{{
    "let l:escaped = escape(getline('.'), "\"\'")
    let l:escaped = getline('.')
    let l:prompt_pos = match(l:escaped, g:VimShell_Prompt)
    if l:prompt_pos < 0
        " Prompt not found
        if match(getline('$'), g:VimShell_Prompt) < 0
            " Create prompt line.
            call append(line('$'), g:VimShell_Prompt)
            normal! G$
            call vimshell#start_insert()
        else
            echo "Not on the command line."
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
    let l:line = substitute(l:escaped, g:VimShell_Prompt, '', '')

    " Ignore empty command line."{{{
    if l:line =~ '^\s*$'
        call setline(line('.'), g:VimShell_Prompt)

        call vimshell#start_insert()
        return
    endif
    "}}}

    " Delete comment.
    let l:line = substitute(l:line, '#.*$', '', '')

    " Not append history if starts spaces or dups.
    if l:line !~ '^\s' && (empty(g:vimshell#hist_buffer) || l:line !=# g:vimshell#hist_buffer[0])
        let l:now_hist_size = getfsize(g:VimShell_HistoryPath)
        if l:now_hist_size != s:hist_size
            " Reload.
            let g:vimshell#hist_buffer = readfile(g:VimShell_HistoryPath)
        endif

        " Append history.
        call insert(g:vimshell#hist_buffer, l:line)

        " Trunk.
        let g:vimshell#hist_buffer = g:vimshell#hist_buffer[:g:VimShell_HistoryMaxSize-1]

        call writefile(g:vimshell#hist_buffer, g:VimShell_HistoryPath)

        let s:hist_size = getfsize(g:VimShell_HistoryPath)
    endif

    " Delete head spaces.
    let l:line = substitute(l:line, '^\s\+', '', '')
    let l:program = (empty(l:line))? '' : split(l:line)[0]
    let l:args = split(l:line)[1:]
    let l:fd = {}
    let l:other_info = { 'has_head_spaces' : l:line =~ '^\s\+', 'is_interactive' : 1, 'is_background' : 0 }

    " Interactive execute.
    let l:skip_prompt = vimshell#execute_command(l:program, l:args, l:fd, l:other_info)

    if l:skip_prompt
        " Skip prompt.
        return
    endif

    call vimshell#print_prompt()
    call s:highlight_escape_sequence()

    call vimshell#start_insert()
endfunction"}}}

function! vimshell#print(string)
    if a:string == ''
        return
    endif

    " Convert encoding for system().
    if has('win32') || has('win64')
        let l:string = iconv(a:string, 'cp932', &encoding) 
    else

        "let l:string = iconv(a:string, 'utf-8', &encoding) 
        let l:string = a:string
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
endfunction
function! vimshell#print_line(string)
    call append(line('$'), a:string)
    normal! j
endfunction
function! vimshell#error_line(string)
    call append(line('$'), '!!!'.a:string.'!!!')
    normal! j
endfunction
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

function! vimshell#start_insert()
    " Enter insert mode.
    startinsert!
    set iminsert=0 imsearch=0
endfunction
"}}}

" VimShell key-mappings function."{{{
function! vimshell#insert_command_completion()"{{{
    let l:in = input('Command name completion: ', expand('<cword>'), 'shellcmd')
    " For ATOK X3.
    set iminsert=0 imsearch=0

    if !empty(l:in)
        execute 'normal! ciw' . l:in
    endif
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
            execute 'lcd ' . l:current

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
            execute 'lcd ' . l:current

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
    echo printf('%s,%s', l:next_line, l:prev_line)
    if l:next_line - l:prev_line > 1
        execute printf('%s,%sdelete', l:prev_line+1, l:next_line-1)
        call append(line('.')-1, "* Output was deleted *")
    endif
    normal! $
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
        let l:internal_list = split(globpath(&runtimepath, 'autoload/vimshell/internal/*.vim'), '\n')
        for list in l:internal_list
            let l:func_name = fnamemodify(list, ':t:r')
            let s:internal_func_table[l:func_name] = 'vimshell#internal#' . l:func_name . '#execute'
        endfor
    endif
    if !exists('s:special_func_table')
        " Initialize table.
        let s:special_func_table = {
                    \ 'command' : 's:special_command',
                    \ 'internal' : 's:special_internal',
                    \}
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

    call vimshell#print_prompt()

    call vimshell#start_insert()
endfunction"}}}

"}}}

function! s:save_current_dir()"{{{
    let l:current_dir = getcwd()
    execute 'lcd ' . b:vimshell_save_dir
    let b:vimshell_save_dir = l:current_dir
endfunction"}}}
function! s:restore_current_dir()"{{{
    let l:current_dir = getcwd()
    if l:current_dir != b:vimshell_save_dir
        execute 'lcd ' . b:vimshell_save_dir
        let b:vimshell_save_dir = l:current_dir
    endif
endfunction"}}}

function! s:highlight_escape_sequence()"{{{
    let register_save = @"
    "while search('\[[0-9;]*m', 'c')
    while search("\<ESC>\\[[0-9;]*m", 'c')
        normal! dfm

        let [lnum, col] = getpos('.')[1:2]
        if len(getline('.')) == col
            let col += 1
        endif
        let syntax_name = 'EscapeSequenceAt_' . bufnr('%') . '_' . lnum . '_' . col
        execute 'syntax region' syntax_name 'start=+\%' . lnum . 'l\%' . col . 'c+ end=+\%$+' 'contains=ALL'

        let highlight = ''
        for color_code in split(matchstr(@", '[0-9;]\+'), ';')
            if color_code == 0
                let highlight .= ' ctermfg=NONE ctermbg=NONE guifg=NONE guibg=NONE'
            elseif color_code == 1
                let highlight .= ' cterm=bold gui=bold'
            elseif 30 <= color_code && color_code <= 37
                let highlight .= ' ctermfg=' . (color_code - 30)
            elseif color_code == 38
                " TODO
            elseif color_code == 39
                " TODO
            elseif 40 <= color_code && color_code <= 47
                let highlight .= ' ctermbg=' . (color_code - 40)
            elseif color_code == 48
                " TODO
            elseif color_code == 49
                " TODO
            endif
        endfor
        if len(highlight)
            execute 'highlight' syntax_name highlight
        endif
    endwhile
    let @" = register_save
endfunction"}}}

augroup VimShellAutoCmd"{{{
    autocmd!
    autocmd BufEnter * if &filetype == 'vimshell' | call s:save_current_dir()
    autocmd BufLeave * if &filetype == 'vimshell' | call s:restore_current_dir()
augroup end"}}}

" vim: foldmethod=marker
