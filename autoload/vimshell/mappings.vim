"=============================================================================
" FILE: mappings.vim
" AUTHOR: Shougo Matsushita <Shougo.Matsu@gmail.com>(Modified)
" Last Modified: 08 Jun 2010
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

" VimShell key-mappings functions."{{{
function! vimshell#mappings#push_current_line()"{{{
    " Check current line.
    if match(getline('.'), vimshell#escape_match(vimshell#get_prompt())) < 0
        return
    endif

    call add(b:vimshell_commandline_stack, getline('.'))

    " Set prompt line.
    call setline(line('.'), vimshell#get_prompt())

    startinsert!
endfunction"}}}
function! vimshell#mappings#push_and_execute(command)"{{{
    " Check current line.
    if match(getline('.'), vimshell#escape_match(vimshell#get_prompt())) < 0
        return
    endif

    call add(b:vimshell_commandline_stack, getline('.'))

    " Set prompt line.
    call setline(line('.'), vimshell#get_prompt() . a:command)

    call vimshell#process_enter()
endfunction"}}}

function! vimshell#mappings#previous_prompt()"{{{
    call search('^' . vimshell#escape_match(vimshell#get_prompt()), 'bWe')
endfunction"}}}
function! vimshell#mappings#next_prompt()"{{{
    call search('^' . vimshell#escape_match(vimshell#get_prompt()), 'We')
endfunction"}}}
function! vimshell#mappings#delete_previous_output()"{{{
    let l:prompt = vimshell#escape_match(vimshell#get_prompt())
    if vimshell#get_user_prompt() != ''
        let l:nprompt = '^\[%\] '
    else
        let l:nprompt = '^' . l:prompt
    endif
    let l:pprompt = '^' . l:prompt
    
    " Search next prompt.
    if getline('.') =~ l:nprompt
        let l:next_line = line('.')
    elseif vimshell#get_user_prompt() != '' && getline('.') =~ '^' . l:prompt
        let [l:next_line, l:next_col] = searchpos(l:nprompt, 'bWn')
    else
        let [l:next_line, l:next_col] = searchpos(l:nprompt, 'Wn')
    endif
    while getline(l:next_line-1) =~ l:nprompt
        let l:next_line -= 1
    endwhile

    normal! 0
    let [l:prev_line, l:prev_col] = searchpos(l:pprompt, 'bWn')
    if l:prev_line > 0 && l:next_line - l:prev_line > 1
        execute printf('%s,%sdelete', l:prev_line+1, l:next_line-1)
        call append(line('.')-1, "* Output was deleted *")
    endif
    call vimshell#mappings#next_prompt()
endfunction"}}}
function! vimshell#mappings#insert_last_word()"{{{
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
function! vimshell#mappings#run_help()"{{{
    if match(getline('.'), vimshell#escape_match(vimshell#get_prompt())) < 0
        startinsert!
        return
    endif

    " Delete prompt string.
    let l:line = substitute(getline('.'), '^' . vimshell#escape_match(vimshell#get_prompt()), '', '')
    if l:line =~ '^\s*$'
        startinsert!
        return
    endif

    let l:program = split(l:line)[0]
    if l:program !~ '\h\w*'
        startinsert!
        return
    elseif has_key(b:vimshell_alias_table, l:program)
        let l:program = b:vimshell_alias_table[l:program]
    elseif has_key(b:vimshell_galias_table, l:program)
        let l:program = b:vimshell_galias_table[l:program]
    endif

    if exists(':Man')
        execute 'Man' l:program
    elseif exists(':Ref')
        execute 'Ref man' l:program
    else
        call vimshell#execute_internal_command('bg', ['man', '-P', 'cat', l:program], 
                    \{}, {'is_interactive' : 0, 'is_background' : 1})
    endif
endfunction"}}}
function! vimshell#mappings#paste_prompt()"{{{
    if match(getline('.'), vimshell#escape_match(vimshell#get_prompt())) < 0
        return
    endif

    if match(getline('$'), vimshell#escape_match(vimshell#get_prompt())) < 0
        " Insert prompt line.
        call append(line('$'), getline('.'))
    else
        " Set prompt line.
        call setline(line('$'), getline('.'))
    endif
    normal! G
endfunction"}}}
function! vimshell#mappings#move_head()"{{{
    call search(vimshell#escape_match(vimshell#get_prompt()), 'be', line('.'))
    if col('.') != col('$')-1
        normal! l
    endif
    startinsert
endfunction"}}}
function! vimshell#mappings#move_end_argument()"{{{
    normal! 0
    call search('\\\@<!\s\zs[^[:space:]]*$', '', line('.'))
endfunction"}}}
function! vimshell#mappings#delete_line()"{{{
    let l:col = col('.')
    let l:mcol = col('$')
    call setline(line('.'), vimshell#get_prompt() . getline('.')[l:col :])
    call vimshell#mappings#move_head()
    if l:col == l:mcol-1
        startinsert!
    endif
endfunction"}}}
function! vimshell#mappings#clear()"{{{
    " Clean up the screen.
    let l:line = getline('.')
    let l:pos = getpos('.')
    % delete _

    if vimshell#get_user_prompt() != ''
        " Insert user prompt line.
        for l:user in split(vimshell#get_user_prompt(), "\\n")
            let l:secondary = '[%] ' . eval(l:user)
            if line('$') == 1 && getline('.') == ''
                call setline(line('$'), l:secondary)
            else
                call append(line('$'), l:secondary)
                normal! j$
            endif
        endfor
    endif

    call append(line('.'), l:line)
    call setpos('.', l:pos)
    if col('.')+1 < col('$')
        normal! l
        startinsert
    else
        startinsert!
    endif
endfunction"}}}
function! vimshell#mappings#expand_wildcard()"{{{
    " Wildcard.
    let l:wildcard = matchstr(vimshell#get_cur_text(), '[^[:blank:]]*$')
    let l:expanded = vimshell#parser#expand_wildcard(l:wildcard)
    
    return (pumvisible() ? "\<C-e>" : '')
                \ . repeat("\<BS>", len(l:wildcard)) . join(l:expanded)
endfunction"}}}

"}}}
" vim: foldmethod=marker
