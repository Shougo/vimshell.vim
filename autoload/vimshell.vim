"=============================================================================
" FILE: vimshell.vim
" AUTHOR: Janakiraman .S <prince@india.ti.com>(Original)
"         Shougo Matsushita <Shougo.Matsu@gmail.com>(Modified)
" Last Modified: 20 Jun 2010
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
" Version: 6.04, for Vim 7.0
"=============================================================================

" Check vimproc.
let s:is_vimproc = exists('*vimproc#system')

" Initialize."{{{
let s:prompt = exists('g:VimShell_Prompt') ? g:VimShell_Prompt : 'vimshell% '
let s:secondary_prompt = exists('g:VimShell_SecondaryPrompt') ? g:VimShell_SecondaryPrompt : '%% '
let s:user_prompt = exists('g:VimShell_UserPrompt') ? g:VimShell_UserPrompt : ''
if !exists('g:VimShell_ExecuteFileList')
    let g:VimShell_ExecuteFileList = {}
endif
"}}}

augroup VimShellAutoCmd"{{{
    autocmd!
    autocmd BufWinEnter \[*]vimshell call s:save_current_dir()
    autocmd BufWinLeave \[*]vimshell call s:restore_current_dir()
augroup end"}}}

" Plugin keymappings"{{{
nnoremap <silent> <Plug>(vimshell_enter)  :<C-u>call vimshell#process_enter()<CR>
nnoremap <silent> <Plug>(vimshell_previous_prompt)  :<C-u>call vimshell#mappings#previous_prompt()<CR>
nnoremap <silent> <Plug>(vimshell_next_prompt)  :<C-u>call vimshell#mappings#next_prompt()<CR>
nnoremap <silent> <Plug>(vimshell_delete_previous_output)  :<C-u>call vimshell#mappings#delete_previous_output()<CR>
nnoremap <silent> <Plug>(vimshell_paste_prompt)  :<C-u>call vimshell#mappings#paste_prompt()<CR>
nnoremap <silent> <Plug>(vimshell_move_end_argument) :<C-u>call vimshell#mappings#move_end_argument()<CR>
nnoremap <silent> <Plug>(vimshell_hide) :<C-u>hide<CR>

inoremap <expr> <Plug>(vimshell_history_complete_whole)  vimshell#complete#history_complete#whole()
inoremap <expr> <Plug>(vimshell_history_complete_insert)  vimshell#complete#history_complete#insert()
inoremap <expr> <Plug>(vimshell_command_complete) pumvisible() ? "\<C-n>" : vimshell#parser#check_wildcard() ? 
            \ vimshell#mappings#expand_wildcard() : vimshell#complete#command_complete#complete()
inoremap <silent> <Plug>(vimshell_push_current_line)  <ESC>:<C-u>call vimshell#mappings#push_current_line()<CR>
inoremap <silent> <Plug>(vimshell_insert_last_word)  <ESC>:<C-u>call vimshell#mappings#insert_last_word()<CR>
inoremap <silent> <Plug>(vimshell_run_help)  <ESC>:<C-u>call vimshell#mappings#run_help()<CR>
inoremap <silent> <Plug>(vimshell_move_head)  <ESC>:<C-u>call vimshell#mappings#move_head()<CR>
inoremap <silent> <Plug>(vimshell_delete_line)  <ESC>:<C-u>call vimshell#mappings#delete_line()<CR>
inoremap <silent> <Plug>(vimshell_clear)  <ESC>:<C-u>call vimshell#mappings#clear()<CR>
"}}}

" User utility functions."{{{
function! vimshell#default_settings()"{{{
    setlocal buftype=nofile
    setlocal noswapfile
    setlocal bufhidden=hide
    setlocal noreadonly
    setlocal tabstop=8
    setlocal omnifunc=vimshell#complete#auto_complete#omnifunc

    " Normal mode key-mappings."{{{
    " Execute command.
    nmap <buffer> <CR> <Plug>(vimshell_enter)
    " Hide vimshell.
    nmap <buffer> q <Plug>(vimshell_hide)
    " Move to previous prompt.
    nmap <buffer> <C-p> <Plug>(vimshell_previous_prompt)
    " Move to next prompt.
    nmap <buffer> <C-n> <Plug>(vimshell_next_prompt)
    " Remove this output.
    nmap <buffer> <C-d> <Plug>(vimshell_delete_previous_output)
    " Paste this prompt.
    nmap <buffer> <C-y> <Plug>(vimshell_paste_prompt)
    " Search end argument.
    nmap <buffer> E <Plug>(vimshell_move_end_argument)
    "}}}

    " Insert mode key-mappings."{{{
    " Execute command.
    imap <buffer> <CR> <ESC><Plug>(vimshell_enter)
    " History completion.
    imap <buffer> <C-j>  <Plug>(vimshell_history_complete_whole)
    imap <buffer> <C-r>c  <Plug>(vimshell_history_complete_insert)
    " Command completion.
    imap <buffer> <TAB>  <Plug>(vimshell_command_complete)
    " Move to Beginning of command.
    imap <buffer> <C-a> <Plug>(vimshell_move_head)
    " Delete all entered characters in the current line
    imap <buffer> <C-u> <Plug>(vimshell_delete_line)
    " Push current line to stack.
    imap <buffer> <C-z> <Plug>(vimshell_push_current_line)
    " Insert last word.
    imap <buffer> <C-]> <Plug>(vimshell_insert_last_word)
    " Run help.
    imap <buffer> <C-r>h <Plug>(vimshell_run_help)
    " Clear.
    imap <buffer> <C-l> <Plug>(vimshell_clear)
    "}}}
endfunction"}}}
"}}}

" vimshell plugin utility functions."{{{
function! vimshell#create_shell(split_flag, directory)"{{{
    let l:bufname = '[1]vimshell'
    let l:cnt = 2
    while bufexists(l:bufname)
        let l:bufname = printf('[%d]vimshell', l:cnt)
        let l:cnt += 1
    endwhile

    if a:split_flag
        execute winheight(0)*g:VimShell_SplitHeight/100 'split `=l:bufname`'
    else
        edit `=l:bufname`
    endif

    call vimshell#default_settings()
    setfiletype vimshell

    " Change current directory.
    let b:vimshell_save_dir = getcwd()
    let l:current = (a:directory != '')? a:directory : getcwd()
    lcd `=fnamemodify(l:current, ':p')`

    " Load history.
    if !filereadable(g:VimShell_HistoryPath)
        " Create file.
        call writefile([], g:VimShell_HistoryPath)
    endif
    let g:vimshell#hist_buffer = readfile(g:VimShell_HistoryPath)
    let s:hist_size = getfsize(g:VimShell_HistoryPath)

    if !exists('b:vimshell_alias_table')
        let b:vimshell_alias_table = {}
    endif
    if !exists('b:vimshell_galias_table')
        let b:vimshell_galias_table = {}
    endif
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
    if !exists('w:vimshell_directory_stack')
        let w:vimshell_directory_stack = []
        let w:vimshell_directory_stack[0] = getcwd()
    endif
    " Load rc file.
    if filereadable(g:VimShell_VimshrcPath) && !exists('b:vimshell_loaded_vimshrc')
        call vimshell#execute_internal_command('vimsh', [g:VimShell_VimshrcPath], {}, 
                    \{ 'has_head_spaces' : 0, 'is_interactive' : 0, 'is_background' : 0 })
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
function! vimshell#switch_shell(split_flag, directory)"{{{
    if &filetype == 'vimshell'
        if winnr('$') != 1
            close
        else
            buffer #
        endif

        if a:directory != ''
            " Change current directory.
            lcd `=fnamemodify(a:directory, ':p')`
            call vimshell#print_prompt()
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
                call vimshell#print_prompt()
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
                execute winheight(0)*g:VimShell_SplitHeight / 100 'sbuffer' l:cnt
            else
                execute 'buffer' l:cnt
            endif

            if a:directory != ''
                " Change current directory.
                lcd `=fnamemodify(a:directory, ':p')`
                call vimshell#print_prompt()
            endif
            call vimshell#start_insert()
            return
        endif

        let l:cnt += 1
    endwhile

    " Create window.
    call vimshell#create_shell(a:split_flag, a:directory)
endfunction"}}}
function! vimshell#process_enter()"{{{
    if vimshell#check_prompt() == 0
        " Prompt not found

        if vimshell#check_prompt('$') == 0
            " Create prompt line.
            call append('$', vimshell#get_prompt())
        endif

        " Search cursor file.
        let l:filename = substitute(substitute(expand('<cfile>'), ' ', '\\ ', 'g'), '\\', '/', 'g')
        if l:filename == ''
            return
        endif
        
        " Execute cursor file.
        if l:filename =~ '^\%(https\?\|ftp\)://'
            " Open uri.
            call setline('$', vimshell#get_prompt() . 'open ' . l:filename)
        elseif isdirectory(expand(l:filename))
            " Change directory.
            call setline('$', vimshell#get_prompt() . 'cd ' . l:filename)
        else
            " Edit file.
            call setline('$', vimshell#get_prompt() . 'vim ' . l:filename)
        endif
    elseif line('.') != line('$')
        " History execution.
        if vimshell#check_prompt('$') == 0
            " Insert prompt line.
            call append('$', getline('.'))
        else
            " Set prompt line.
            call setline('$', getline('.'))
        endif
    endif

    $
    normal! $

    " Check current directory.
    if !exists('w:vimshell_directory_stack')
        let w:vimshell_directory_stack = []
    endif

    " Delete prompt string and comment.
    let l:line = substitute(vimshell#get_cur_text(), '#.*$', '', '')

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
        if g:VimShell_EnableAutoLs
            call setline('.', vimshell#get_prompt() . 'ls')
            call vimshell#execute_internal_command('ls', [], {}, {})

            call vimshell#print_prompt()

            call vimshell#start_insert()
        else
            " Ignore empty command line.
            call setline('.', vimshell#get_prompt())

            call vimshell#start_insert()
        endif
        return
    elseif l:line =~ '^\s*-\s*$'
        " Popd.
        call vimshell#execute_internal_command('cd', ['-'], {}, {})

        call vimshell#print_prompt()

        call vimshell#start_insert()
        return
    endif

    let l:other_info = { 'has_head_spaces' : l:line =~ '^\s\+', 'is_interactive' : 1, 'is_background' : 0 }
    try
        let l:skip_prompt = vimshell#parser#eval_script(l:line, l:other_info)
    catch /.*/
        let l:message = (v:exception !~# '^Vim:')? v:exception : v:exception . ' ' . v:throwpoint
        call vimshell#error_line({}, l:message)
        call vimshell#print_prompt()

        call vimshell#start_insert()
        return
    endtry

    if l:skip_prompt
        " Skip prompt.
        return
    endif

    call vimshell#print_prompt()
    call vimshell#start_insert()
endfunction"}}}

function! vimshell#execute_command(program, args, fd, other_info)"{{{
    if empty(a:args)
        let l:line = a:program
    else
        let l:line = printf('%s %s', a:program, join(a:args, ' '))
    endif
    let l:program = a:program
    let l:arguments = a:args
    let l:dir = substitute(substitute(l:line, '^\~\ze[/\\]', substitute($HOME, '\\', '/', 'g'), ''), '\\\(.\)', '\1', 'g')
    let l:command = vimshell#getfilename(program)

    " Special commands.
    if l:line =~ '&\s*$'"{{{
        " Background execution.
        return vimshell#execute_internal_command('bg', split(substitute(l:line, '&\s*$', '', '')), a:fd, a:other_info)
        "}}}
    elseif has_key(g:vimshell#special_func_table, l:program)"{{{
        " Other special commands.
        return call(g:vimshell#special_func_table[l:program], [l:program, l:arguments, a:fd, a:other_info])
        "}}}
    elseif has_key(g:vimshell#internal_func_table, l:program)"{{{
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
        let l:ret = call(g:vimshell#internal_func_table[l:program], [l:program, l:args, l:fd, a:other_info])

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
    elseif l:command != '' || executable(l:program)
        " Execute external commands.

        " Suffix execution.
        let l:ext = fnamemodify(l:program, ':e')
        if !empty(l:ext) && has_key(g:VimShell_ExecuteFileList, l:ext)
            " Execute file.
            let l:execute = split(g:VimShell_ExecuteFileList[l:ext])[0]
            let l:arguments = extend(split(g:VimShell_ExecuteFileList[l:ext])[1:], insert(l:arguments, l:program))
            return vimshell#execute_command(l:execute, l:arguments, a:fd, a:other_info)
        endif

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
                if !has_key(g:vimshell#special_func_table, l:prog) && !has_key(g:vimshell#internal_func_table, l:prog)
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
        let l:ret = vimshell#execute_internal_command('exe', insert(l:args, l:program), l:fd, a:other_info)

        if l:i < len(l:arguments)
            " Process pipe.
            let l:fd = copy(a:fd)
            let l:fd.stdin = temp
            let l:ret = vimshell#execute_command(l:prog, l:arguments[l:i+2 :], l:fd, a:other_info)
            call delete(l:temp)
        endif

        return l:ret
    elseif isdirectory(l:dir)"{{{
        " Directory.
        " Change the working directory like zsh.

        " Call internal cd command.
        return vimshell#execute_internal_command('cd', [l:dir], a:fd, a:other_info)
        "}}}
    else"{{{
        throw printf('File: "%s" is not found.', l:program)
    endif
    "}}}

    return 0
endfunction"}}}
function! vimshell#execute_internal_command(command, args, fd, other_info)"{{{
    if empty(a:fd)
        let l:fd = { 'stdin' : '', 'stdout' : '', 'stderr' : '' }
    else
        let l:fd = a:fd
    endif

    if empty(a:other_info)
        let l:other_info = { 'has_head_spaces' : 0, 'is_interactive' : 1, 'is_background' : 0 }
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

    " Convert encoding for system().
    if vimshell#iswin()
        let l:string = iconv(a:string, 'cp932', &encoding) 
    else
        let l:string = iconv(a:string, 'utf-8', &encoding) 
    endif

    " Strip <CR>.
    let l:string = substitute(substitute(l:string, '\r', '', 'g'), '\n$', '', '')
    let l:lines = split(l:string, '\n', 1)
    if line('$') == 1 && getline('$') == ''
        call setline('$', l:lines[0])
        let l:lines = l:lines[1:]
    endif

    for l:line in l:lines
        call append('$', l:line)
    endfor
    
    call vimshell#interactive#highlight_escape_sequence()

    " Set cursor.
    $
endfunction"}}}
function! vimshell#print_line(fd, string)"{{{
    if !empty(a:fd) && a:fd.stdout != ''
        if a:fd.stdout == '/dev/null'
            " Nothing.
        elseif a:fd.stdout == '/dev/clip'
            " Write to clipboard.
            let @+ .= a:string
        else
            " Write file.
            let l:file = add(readfile(a:fd.stdout), a:string)
            call writefile(l:file, a:fd.stdout)
        endif

        return
    elseif line('$') == 1 && getline('$') == 0
        call setline('$', a:string)
    else
        call append('$', a:string)
    endif
    
    call vimshell#interactive#highlight_escape_sequence()
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
            " Write file.
            let l:file = extend(readfile(a:fd.stderr), split(a:string, '\r\n\|\n'))
            call writefile(l:file, a:fd.stderr)
        endif

        return
    endif

    let l:string = '!!! ' . a:string . ' !!!'

    if line('$') == 1 && getline('$') == 0
        call setline('$', l:string)
    else
        call append('$', l:string)
    endif
    
    call vimshell#interactive#highlight_escape_sequence()
    $
endfunction"}}}
function! vimshell#print_prompt()"{{{
    " Search prompt
    if !exists('b:vimshell_commandline_stack')
        let b:vimshell_commandline_stack = []
    endif
    if empty(b:vimshell_commandline_stack)
        let l:new_prompt = vimshell#get_prompt()
    else
        let l:new_prompt = b:vimshell_commandline_stack[-1]
        call remove(b:vimshell_commandline_stack, -1)
    endif

    if s:user_prompt != ''
        " Insert user prompt line.
        for l:user in split(s:user_prompt, "\\n")
            let l:secondary = '[%] ' . eval(l:user)
            if line('$') == 1 && getline('.') == ''
                call setline('$', l:secondary)
            else
                call append('$', l:secondary)
                $
            endif
        endfor
    endif

    " Insert prompt line.
    if line('$') == 1 && getline('.') == ''
        call setline('$', l:new_prompt)
    else
        call append('$', l:new_prompt)
        $
    endif
    let &modified = 0
endfunction"}}}
function! vimshell#append_history(command)"{{{
    " Reduce blanks.
    let l:command = substitute(a:command, '\s\+', ' ', 'g')
    " Filtering.
    call insert(filter(g:vimshell#hist_buffer, printf("v:val != '%s'", substitute(l:command, "'", "''", 'g'))), l:command)

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
function! vimshell#start_insert()"{{{
    " Enter insert mode.
    $
    startinsert!
    set iminsert=0 imsearch=0
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
    return substitute(l:cur_text[len(vimshell#get_prompt()):], '^\s*', '', '')
endfunction"}}}
function! vimshell#get_cur_line()"{{{
    let l:pos = mode() ==# 'i' ? 2 : 1
    return col('.') < l:pos ? '' : getline('.')[: col('.') - l:pos]
endfunction"}}}
function! vimshell#check_prompt(...)"{{{
    let l:line = a:0 == 0 ? getline('.') : getline(a:1)
    return vimshell#head_match(l:line, vimshell#get_prompt())
endfunction"}}}
function! vimshell#head_match(checkstr, headstr)"{{{
    return a:headstr == '' || a:checkstr ==# a:headstr
                \|| a:checkstr[: len(a:headstr)-1] ==# a:headstr
endfunction"}}}
function! vimshell#tail_match(checkstr, tailstr)"{{{
    return a:tailstr == '' || a:checkstr ==# a:tailstr
                \|| a:checkstr[: -len(a:tailstr)-1] ==# a:tailstr
endfunction"}}}
function! vimshell#set_execute_file(exts, program)"{{{
    for ext in split(a:exts, ',')
        let g:VimShell_ExecuteFileList[ext] = a:program
    endfor
endfunction"}}}
function! vimshell#system(str, ...)"{{{
    return s:is_vimproc ? (a:0 == 0 ? vimproc#system(a:str) : vimproc#system(a:str, join(a:000)))
                \: (a:0 == 0 ? system(a:str) : system(a:str, join(a:000)))
endfunction"}}}
function! vimshell#trunk_string(string, max)"{{{
    return printf('%.' . string(a:max-10) . 's..%s', a:string, a:string[-8:])
endfunction"}}}
function! vimshell#iswin()"{{{
    return has('win32') || has('win64')
endfunction"}}}
function! vimshell#get_argument_pattern()"{{{
    return '\s\zs\%(\\[^[:alnum:].-]\|[[:alnum:]@/.-_+,#$%~=*]\)*$'
endfunction"}}}
"}}}

" Helper functions.
" Special functions."{{{
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

    return 0
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

    return 0
endfunction"}}}
"}}}


function! s:save_current_dir()"{{{
    if !exists('b:vimshell_save_dir')
        return
    endif
    
    let l:current_dir = getcwd()
    lcd `=fnamemodify(b:vimshell_save_dir, ':p')`
    let b:vimshell_save_dir = l:current_dir
endfunction"}}}
function! s:restore_current_dir()"{{{
    if !exists('b:vimshell_save_dir')
        return
    endif
    
    let l:current_dir = getcwd()
    if l:current_dir != b:vimshell_save_dir
        lcd `=fnamemodify(b:vimshell_save_dir, ':p')`
        let b:vimshell_save_dir = l:current_dir
    endif
endfunction"}}}

" vim: foldmethod=marker
