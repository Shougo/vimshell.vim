"=============================================================================
" FILE: vimshell.vim
" AUTHOR: Janakiraman .S <prince@india.ti.com>(Original)
"         Shougo Matsushita <Shougo.Matsu@gmail.com>(Modified)
" Last Modified: 07 Feb 2009
" Usage: Just source this file.
"        source vimshell.vim
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
" Version: 4.7, for Vim 7.0
"=============================================================================

function! vimshell#switch_shell(split_flag)"{{{
    if getbufvar(bufnr('%'), '&filetype') == 'vimshell'
        echo 'Already there.'
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

            " Enter insert mode.
            startinsert!
            set iminsert=0 imsearch=0

            call s:print_prompt()
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
            else
                execute 'buffer' . l:cnt
            endif

            " Change current directory.
            let b:vimshell_save_dir = l:current
            execute 'lcd ' . l:current

            " Enter insert mode.
            startinsert!
            set iminsert=0 imsearch=0

            call s:print_prompt()
            return
        endif

        let l:cnt += 1
    endwhile

    " Create window.
    call vimshell#create_shell(a:split_flag)
endfunction"}}}

function! vimshell#create_shell(split_flag)"{{{
    let l:bufname = 'VimShell'
    let l:cnt = 2
    while bufexists(l:bufname)
        let l:bufname = printf('[%d]VimShell', l:cnt)
        let l:cnt += 1
    endwhile

    if a:split_flag
        execute 'split ' . l:bufname
    else
        execute 'edit ' . l:bufname
    endif

    setlocal buftype=nofile
    setlocal noswapfile
    let &l:omnifunc = 'vimshell#history_complete'
    setfiletype vimshell

    " Save current directory.
    let b:vimshell_save_dir = getcwd()

    " Load history.
    if !filereadable(g:VimShell_HistoryPath)
        " Create file.
        call writefile([], g:VimShell_HistoryPath)
    endif
    let s:hist_buffer = readfile(g:VimShell_HistoryPath)
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
                    \ 'exit' : 's:special_exit',
                    \ 'command' : 's:special_command',
                    \ 'internal' : 's:special_internal',
                    \ 'vim' : 's:special_vim',
                    \ 'view' : 's:special_view',
                    \ 'vimsh' : 's:special_vimsh',
                    \ 'histdel' : 's:special_histdel',
                    \ 'h' : 's:special_h',
                    \}
    endif
    if !exists('w:vimshell_directory_stack')
        let w:vimshell_directory_stack = []
        let w:vimshell_directory_stack[0] = getcwd()
    endif
    " Load rc file.
    if filereadable(g:VimShell_VimshrcPath) && !exists('b:vimshell_loaded_vimshrc')
        call s:special_vimsh('vimsh ' . g:VimShell_VimshrcPath, 'vimsh', g:VimShell_VimshrcPath, 0, 0)
        let b:vimshell_loaded_vimshrc = 1
    endif

    call s:print_prompt()

    " Enter insert mode.
    startinsert!
    set iminsert=0 imsearch=0
endfunction"}}}

function! s:print_prompt()"{{{
    let l:escaped = escape(getline('.'), "\'")
    " Search prompt
    if match(l:escaped, g:VimShell_Prompt) < 0
        " Prompt not found
        if !empty(l:escaped)
            " Insert prompt line.
            call append(line('.'), g:VimShell_Prompt)
            normal! j
        else
            " Set prompt line.
            call setline(line('.'), g:VimShell_Prompt)
        endif
        normal! $
    else
        " Insert prompt line.
        call append(line('.'), g:VimShell_Prompt)
        normal! j$
    endif
    let &modified = 0
endfunction"}}}

function! vimshell#process_enter()"{{{
    "let l:escaped = escape(getline('.'), "\"\'")
    let l:escaped = getline('.')
    let l:prompt_pos = match(l:escaped, g:VimShell_Prompt)
    if l:prompt_pos < 0
        " Prompt not found
        echo "Not on the command line."
        normal! j
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

    " Not append history if starts spaces or dups.
    if l:line !~ '^\s' && (empty(s:hist_buffer) || l:line != s:hist_buffer[0])
        let l:now_hist_size = getfsize(g:VimShell_HistoryPath)
        if l:now_hist_size != s:hist_size
            " Reload.
            let s:hist_buffer = readfile(g:VimShell_HistoryPath)
        endif

        " Append history.
        call insert(s:hist_buffer, l:line)

        " Trunk.
        let s:hist_buffer = s:hist_buffer[:g:VimShell_HistoryMaxSize-1]

        call writefile(s:hist_buffer, g:VimShell_HistoryPath)

        let s:hist_size = getfsize(g:VimShell_HistoryPath)
    endif

    let l:has_head_spaces = (l:line =~ '^\s\+')
    " Delete head spaces.
    let l:line = substitute(l:line, '^\s\+', '', '')
    let l:program = (empty(l:line))? '' : split(l:line)[0]
    let l:arguments = substitute(l:line, '^' . l:program . '\s*', '', '')

    " Interactive execute.
    let l:skip_prompt = s:process_execute(l:line, l:program, l:arguments, 1, l:has_head_spaces)

    if l:skip_prompt
        " Skip prompt.
        return
    endif

    call s:print_prompt()
    call s:highlight_escape_sequence()

    " Enter insert mode.
    startinsert!
    set iminsert=0 imsearch=0
endfunction"}}}

function s:process_execute(line, program, arguments, is_interactive, has_head_spaces)"{{{
    let l:line = a:line
    let l:program = a:program
    let l:arguments = a:arguments

    " Check alias."{{{
    if has_key(b:vimshell_alias_table, l:program) && !empty(b:vimshell_alias_table[l:program])
        let l:alias = split(b:vimshell_alias_table[l:program])
        let l:program = l:alias[0]
        if len(l:alias) > 1
            " Join arguments.
            let l:arguments = join(l:alias[1:], ' ') . ' ' . l:arguments
        endif
        let l:line = l:program . ' ' . l:arguments
    endif"}}}

    " Special commands.
    if empty(l:program) && a:is_interactive"{{{
        " Ignore empty command line.
        call setline(line('.'), g:VimShell_Prompt)

        " Enter insert mode.
        startinsert!
        set iminsert=0 imsearch=0
        return 1"}}}
    elseif l:program =~ '^\h\w*='"{{{
        " Variables substitution.
        execute 'silent let $' . l:program"}}}
    elseif l:line =~ '&\s*$'"{{{
        " Background execution.
        if l:line =~ '^shell\s*&'
            " Background shell.
            if has('win32') || has('win64')
                if g:VimShell_UseCkw
                    " Use ckw.
                    silent execute printf('!start ckw -e %s', &shell)
                else
                    silent execute printf('!start %s', &shell)
                endif
            elseif &term =~ '^screen'
                silent execute printf('!screen %s', &shell)
            else
                " Can't Background execute.
                shell
            endif
        elseif has('win32') || has('win64')
            if g:VimShell_UseCkw
                " Use ckw.
                silent execute printf('!start ckw -e %s %s %s', &shell, &shellcmdflag, substitute(l:line, '&\s*$', '', ''))
            else
                silent execute printf('!start %s', substitute(l:line, '&\s*$', '', ''))
            endif
        elseif &term =~ "^screen"
            silent execute printf('!screen %s', substitute(l:line, '&\s*$', '', ''))
        else
            " Can't Background execute.
            execute printf('!%s', substitute(a:line, '&\s*$', '', ''))
        endif"}}}
    elseif l:program =~ '^!'"{{{
        if l:program == '!!' && a:is_interactive
            " Previous command execution.
            if get(s:hist_buffer, 0) =~ '^!!'
                " Delete from history.
                call remove(s:hist_buffer, 0)
            endif

            return s:special_h('h 0', 'h', '0', a:is_interactive, a:has_head_spaces)
        elseif l:program =~ '!\d\+$' && a:is_interactive
            " History command execution.
            if get(s:hist_buffer, 0) =~ '^!\d\+'
                " Delete from history.
                call remove(s:hist_buffer, 0)
            endif

            return s:special_h('h' . str2nr(l:program[1:]), 'h', str2nr(l:program[1:]), a:is_interactive, a:has_head_spaces)
        else
            " Shell execution.
            execute printf('%s %s', l:program, l:arguments)
        endif"}}}
    elseif has_key(s:special_func_table, l:program)"{{{
        " Other special commands.
        execute printf('let l:skip_prompt = %s(l:line, l:program, l:arguments, a:is_interactive, a:has_head_spaces)', 
                    \ s:special_func_table[l:program])
        return l:skip_prompt"}}}
    elseif has_key(s:internal_func_table, l:program)"{{{
        " Internal commands.
        let l:other_info = { 'hist_buffer': s:hist_buffer }
        execute printf('call %s(l:line, l:program, l:arguments, a:is_interactive, a:has_head_spaces, l:other_info)', 
                    \ s:internal_func_table[l:program])
        "}}}
    elseif isdirectory(l:program)"{{{
        " Directory.
        " Change the working directory like zsh.

        " Filename escape.
        let l:arguments = escape(a:program, "\\*?[]{}`$%#&'\"|!<>+")

        execute 'lcd ' . l:arguments
        "}}}
    else"{{{
        " External commands.
        silent execute printf('read! %s %s', l:program, l:arguments)
    endif
    "}}}

    return 0
endfunction"}}}

" Special functions."{{{
function! s:special_exit(line, program, arguments, is_interactive, has_head_spaces)"{{{
    " Exit vimshell.
    if a:is_interactive
        " Insert prompt line.
        call s:print_prompt()
        buffer #
        return 1
    else
        return 0
    endif
endfunction"}}}
function! s:special_command(line, program, arguments, is_interactive, has_head_spaces)"{{{
    execute 'silent read! ' . a:arguments
    return 0
endfunction"}}}
function! s:special_internal(line, program, arguments, is_interactive, has_head_spaces)"{{{
    if !empty(a:arguments)
        let l:program = split(a:arguments)[0]
        let l:arguments = substitute(a:arguments, '^' . l:program . '\s*', '', '')
        if has_key(s:internal_func_table, l:program)
            " Internal commands.
            let l:other_info = { 'hist_buffer': s:hist_buffer }
            execute printf('call %s(a:arguments, l:program, l:arguments, a:is_interactive, a:has_head_spaces, l:other_info)', 
                        \ s:internal_func_table[l:program])
            execute 'silent read! ' . l:arguments
        else
            " Error.
            call append(line('.'), printf('Not found internal command "%s".', l:program))
            normal! j
        endif
    endif
    return 0
endfunction"}}}
function! s:special_vim(line, program, arguments, is_interactive, has_head_spaces)"{{{
    " Edit file.

    call s:print_prompt()

    " Filename escape
    let l:arguments = escape(a:arguments, "\\*?[]{}`$%#&'\"|!<>+")

    if empty(l:arguments)
        new
    else
        split
        execute 'edit ' . l:arguments
    endif

    return 1
endfunction"}}}
function! s:special_view(line, program, arguments, is_interactive, has_head_spaces)"{{{
    " View file.

    call s:print_prompt()

    " Filename escape
    let l:arguments = escape(a:arguments, "\\*?[]{}`$%#&'\"|!<>+")

    if empty(l:arguments)
        call append(line('.'), 'Filename required.')
        normal! j
    else
        split
        execute 'edit ' . l:arguments
        setlocal nomodifiable
    endif
endfunction"}}}
function! s:special_vimsh(line, program, arguments, is_interactive, has_head_spaces)"{{{
    if empty(a:arguments)
        call s:print_prompt()
        call vimshell#create_shell(0)
        return 1
    else
        " Filename escape.
        let l:filename = escape(a:arguments, "\\*?[]{}`$%#&'\"|!<>+")

        if filereadable(l:filename)
            let l:scripts = readfile(l:filename)

            for script in l:scripts
                " Delete head spaces.
                let l:line = substitute(script, '^\s\+', '', '')
                let l:program = (empty(script))? '' : split(script)[0]
                let l:arguments = substitute(script, '^' . l:program . '\s*', '', '')

                call s:process_execute(l:line, l:program, l:arguments, 0, 0)
                normal! j
            endfor
        else
            " Error.
            call append(line('.'), printf('Not found the script "%s".', l:filename))
            normal! j
        endif
    endif

    return 0
endfunction"}}}
function! s:special_histdel(line, program, arguments, is_interactive, has_head_spaces)"{{{
    if get(s:hist_buffer, 0) =~ '^histdel'
        " Delete from history.
        call remove(s:hist_buffer, 0)
    endif

    if !empty(a:arguments)
        let l:del_hist = {}
        for d in split(a:arguments)
            let l:del_hist[d] = 1
        endfor

        let l:new_hist = []
        let l:cnt = 0
        for h in s:hist_buffer
            if !has_key(l:del_hist, l:cnt)
                call add(l:new_hist, h)
            endif
            let l:cnt += 1
        endfor
        let s:hist_buffer = l:new_hist
    else
        call append(line('.'), 'Arguments required.')
        normal! j
    endif
endfunction"}}}
function! s:special_h(line, program, arguments, is_interactive, has_head_spaces)"{{{
    if get(s:hist_buffer, 0) =~ '^h\s' || get(s:hist_buffer, 0) == 'h'
        " Delete from history.
        call remove(s:hist_buffer, 0)
    endif

    let l:args = split(a:arguments)
    if empty(l:args)
        let l:num = 0
    else
        let l:num = str2nr(l:args[0])
    endif

    if len(s:hist_buffer) > l:num
        if !empty(a:arguments[1:])
            " Join arguments.
            let l:line = s:hist_buffer[l:num] . ' ' . join(l:args[1:], ' ')
        else
            let l:line = s:hist_buffer[l:num]
        endif

        if a:has_head_spaces
            " Don't append history.
            call setline(line('.'), printf('%s %s', g:VimShell_Prompt, l:line))
        else
            call setline(line('.'), g:VimShell_Prompt . l:line)
        endif

        call vimshell#process_enter()
        return 1
    else
        " Error.
        call append(line('.'), 'Not found in history.')
        normal! j
        return 0
    endif
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
    let &l:ignorecase = g:VimShell_IgnoreCase
    " Ignore head spaces.
    let l:cur_keyword_str = substitute(a:base, '^\s\+', '', '')
    let l:complete_words = []
    for hist in s:hist_buffer
        if len(hist) > len(l:cur_keyword_str) && hist =~ l:cur_keyword_str
            call add(l:complete_words, { 'word' : hist, 'abbr' : hist, 'dup' : 0 })
        endif
    endfor

    " Restore options.
    let &l:ignorecase = l:ignorecase_save

    if g:VimShell_QuickMatchEnable
        " Append numbered list.
        if match(l:cur_keyword_str, '\d$') >= 0
            " Get numbered list.
            let l:numbered = get(s:prev_numbered_list, str2nr(matchstr(l:cur_keyword_str, '\d$')))
            if type(l:numbered) == type({})
                call insert(l:complete_words, l:numbered)
            endif

            " Get next numbered list.
            if match(l:cur_keyword_str, '\d\d$') >= 0
                let l:num = str2nr(matchstr(l:cur_keyword_str, '\d\d$'))-10
                if l:num >= 0
                    unlet l:numbered
                    let l:numbered = get(s:prepre_numbered_list, l:num)
                    if type(l:numbered) == type({})
                        call insert(l:complete_words, l:numbered)
                    endif
                endif
            endif
        endif

        " Check dup.
        let l:dup_check = {}
        let l:num = 0
        let l:numbered_words = []
        for history in l:complete_words[:g:VimShell_QuickMatchMaxLists]
            if !empty(history.word) && !has_key(l:dup_check, history.word)
                let l:dup_check[history.word] = 1

                call add(l:numbered_words, history)
            endif
            let l:num += 1
        endfor

        " Add number.
        let l:num = 0
        let l:abbr_pattern_d = '%2d: %.' . g:VimShell_MaxHistoryWidth . 's'
        for history in l:numbered_words
            let history.abbr = printf(l:abbr_pattern_d, l:num, history.word)

            let l:num += 1
        endfor
        let l:abbr_pattern_n = '    %.' . g:VimShell_MaxHistoryWidth . 's'
        for history in l:complete_words[g:VimShell_QuickMatchMaxLists :]
            let history.abbr = printf(l:abbr_pattern_n, history.word)
        endfor

        " Append list.
        let l:complete_words = extend(l:numbered_words, l:complete_words)

        " Save numbered lists.
        let s:prepre_numbered_list = s:prev_numbered_list[10:g:VimShell_QuickMatchMaxLists-1]
        let s:prev_numbered_list = l:complete_words[:g:VimShell_QuickMatchMaxLists-1]
    endif

    return l:complete_words
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

function! vimshell#insert_command()"{{{
    let l:in = input('Command name completion: ', expand('<cword>'), 'shellcmd')
    " For ATOK X3.
    set iminsert=0 imsearch=0

    if !empty(l:in)
        execute 'normal! ciw' . l:in
    endif
endfunction"}}}

function! vimshell#save_current_dir()"{{{
    let l:current_dir = getcwd()
    execute 'lcd ' . b:vimshell_save_dir
    let b:vimshell_save_dir = l:current_dir
endfunction"}}}
function! vimshell#restore_current_dir()"{{{
    let l:current_dir = getcwd()
    if l:current_dir != b:vimshell_save_dir
        execute 'lcd ' . b:vimshell_save_dir
        let b:vimshell_save_dir = l:current_dir
    endif
endfunction"}}}

augroup VimShell"{{{
    autocmd!
    autocmd Filetype vimshell nmap <buffer><silent> <CR> <Plug>(vimshell_enter)
    autocmd Filetype vimshell imap <buffer><silent> <CR> <ESC><CR>
    autocmd Filetype vimshell nnoremap <buffer><silent> q :<C-u>hide<CR>
    autocmd Filetype vimshell inoremap <buffer> <C-j> <C-x><C-o><C-p>
    autocmd Filetype vimshell inoremap <buffer> <C-p> <C-o>:<C-u>call vimshell#insert_command()<CR>
    autocmd Filetype vimshell nmap <buffer><silent> <CR> <Plug>(vimshell_enter)
    autocmd BufEnter * if &filetype == 'vimshell' | call vimshell#save_current_dir() | endif
    autocmd BufLeave * if &filetype == 'vimshell' | call vimshell#restore_current_dir() | endif
augroup end"}}}

" Global options definition."{{{
if !exists('g:VimShell_Prompt')
    let g:VimShell_Prompt = 'VimShell% '
endif
if !exists('g:VimShell_HistoryPath')
    let g:VimShell_HistoryPath = $HOME.'/.vimshell_hist'
endif
if !exists('g:VimShell_HistoryMaxSize')
    let g:VimShell_HistoryMaxSize = 1000
endif
if !exists('g:VimShell_VimshrcPath')
    let g:VimShell_VimshrcPath = $HOME.'/.vimshrc'
endif
if !exists('g:VimShell_IgnoreCase')
    let g:VimShell_IgnoreCase = 1
endif
if !exists('g:VimShell_MaxHistoryWidth')
    let g:VimShell_MaxHistoryWidth = 40
endif
if !exists('g:VimShell_QuickMatchEnable')
    let g:VimShell_QuickMatchEnable = 1
endif
if !exists('g:VimShell_QuickMatchMaxLists')
    let g:VimShell_QuickMatchMaxLists = 50
endif
if !exists('g:VimShell_UseCkw')
    let g:VimShell_UseCkw = 0
endif
"}}}

" vim: foldmethod=marker
