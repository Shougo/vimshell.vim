"=============================================================================
" FILE: parser.vim
" AUTHOR: Shougo Matsushita <Shougo.Matsu@gmail.com>(Modified)
" Last Modified: 12 Oct 2009
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
"=============================================================================

function! vimshell#parser#eval_script(script, other_info)"{{{
    let l:skip_prompt = 0
    " Split statements.
    for l:statement in vimshell#parser#split_statements(a:script)
        " Get program.
        let l:program = matchstr(l:statement, '^\s*\zs[^[:blank:]]*')
        let l:script = substitute(l:statement, '^\s*'.l:program, '', '')

        for galias in keys(b:vimshell_galias_table)
            let l:script = substitute(l:script, '\s\zs'.galias.'\ze\%(\s\|$\)', b:vimshell_galias_table[galias], 'g')
        endfor

        " Check alias."{{{
        if has_key(b:vimshell_alias_table, l:program) && !empty(b:vimshell_alias_table[l:program])
            let l:alias_prog = matchstr(b:vimshell_alias_table[l:program], '^\s*\zs[^[:blank:]]*')

            if l:program != l:alias_prog
                " Expand alias.
                let l:skip_prompt = vimshell#parser#eval_script(b:vimshell_alias_table[l:program] . ' ' . l:script, a:other_info)
                continue
            endif
        endif"}}}

        if has_key(g:vimshell#special_func_table, l:program)
            " Special commands.
            let l:fd = { 'stdin' : '', 'stdout' : '', 'stderr' : '' }
            let l:args = split(l:script)
        else
            " Expand block.
            if l:script =~ '{'
                let l:script = s:parse_block(l:script)
            endif

            " Expand tilde.
            if l:script =~ ' \~'
                let l:script = s:parse_tilde(l:script)
            endif

            " Expand filename.
            if l:script =~ ' ='
                let l:script = s:parse_equal(l:script)
            endif

            " Expand variables.
            if l:script =~ '$'
                let l:script = s:parse_variables(l:script)
            endif

            " Expand wildcard.
            if l:script =~ '[[*?]\|\\[()|]'
                let l:script = s:parse_wildcard(l:script)
            endif

            " Parse redirection.
            if l:script =~ '[<>]'
                let [l:fd, l:script] = s:parse_redirection(l:script)
            else
                let l:fd = { 'stdin' : '', 'stdout' : '', 'stderr' : '' }
            endif

            " Parse pipe.
            if l:script =~ '|'
                let l:script = s:parse_pipe(l:script)
            endif

            " Split args.
            let l:args = vimshell#parser#split_args(l:script)
        endif

        if l:fd.stdout != ''
            if l:fd.stdout =~ '^>'
                let l:fd.stdout = l:fd.stdout[1:]
            elseif l:fd.stdout == '/dev/null'
                " Nothing.
            elseif l:fd.stdout == '/dev/clip'
                " Clear.
                let @+ = ''
            else
                " Create file.
                call writefile([], l:fd.stdout)
            endif
        endif

        if l:program == ''
            " Echo file.
            let l:program = 'cat'
        endif

        let l:skip_prompt = vimshell#execute_command(l:program, l:args, l:fd, a:other_info)
        call interactive#highlight_escape_sequence()
        redraw
    endfor

    return l:skip_prompt
endfunction"}}}

function! vimshell#parser#split_statements(script)"{{{
    let l:max = len(a:script)
    let l:statements = []
    let l:statement = ''
    let l:i = 0
    while l:i < l:max
        if a:script[l:i] == ';'
            if l:statement != ''
                call add(l:statements, l:statement)
            endif
            let l:statement = ''
            let l:i += 1
        elseif a:script[l:i] == "'"
            " Single quote.
            let [l:string, l:i] = s:skip_quote(a:script, l:i)
            let l:statement .= l:string
        elseif a:script[l:i] == '"'
            " Double quote.
            let [l:string, l:i] = s:skip_double_quote(a:script, l:i)
            let l:statement .= l:string
        elseif a:script[l:i] == '`'
            " Back quote.
            let [l:string, l:i] = s:skip_back_quote(a:script, l:i)
            let l:statement .= l:string
        elseif a:script[l:i] == '\'
            " Escape.
            let l:statement .= '\'
            let l:i += 1

            if l:i >= len(a:script)
                throw 'Escape error'
            endif

            let l:statement .= a:script[l:i]
            let l:i += 1
        else
            let l:statement .= a:script[l:i]
            let l:i += 1
        endif
    endwhile

    if l:statement != ''
        call add(l:statements, l:statement)
    endif

    return l:statements
endfunction"}}}
function! vimshell#parser#split_args(script)"{{{
    " Substitute modifier.
    let l:script = ''
    for val in split(a:script)
        let l:modify = split(val, ':[/\\]\@!')
        let l:script .= ' ' . fnamemodify(l:modify[0], ':' . join(l:modify[1:], ':'))
    endfor
    let l:max = len(l:script)
    let l:args = []
    let l:arg = ''
    let l:i = 0
    while l:i < l:max
        if l:script[l:i] == "'"
            " Single quote.
            let l:end = matchend(l:script, "^'\\zs[^']*'", l:i)
            if l:end == -1
                throw 'Quote error'
            endif

            let l:arg .= l:script[l:i+1 : l:end-2]
            if l:arg == ''
                call add(l:args, '')
            endif

            let l:i = l:end
        elseif l:script[l:i] == '"'
            " Double quote.
            let l:end = matchend(l:script, '^"\zs\%([^"]\|\"\)*"', l:i)
            if l:end == -1
                throw 'Quote error'
            endif

            let l:arg .= substitute(l:script[l:i+1 : l:end-2], '\\"', '"', 'g')
            if l:arg == ''
                call add(l:args, '')
            endif

            let l:i = l:end
        elseif l:script[l:i] == '`'
            " Back quote.
            if l:script[l:i :] =~ '^`='
                let l:quote = matchstr(l:script, '^`=\zs[^`]*\ze`', l:i)
                let l:end = matchend(l:script, '^`=[^`]*`', l:i)
                let l:arg .= string(eval(l:quote))
            else
                let l:quote = matchstr(l:script, '^`\zs[^`]*\ze`', l:i)
                let l:end = matchend(l:script, '^`[^`]*`', l:i)
                let l:arg .= substitute(system(l:quote), '\n', ' ', 'g')
            endif
            if l:arg == ''
                call add(l:args, '')
            endif

            let l:i = l:end
        elseif l:script[i] == '\'
            " Escape.
            let l:i += 1

            if l:i > l:max
                throw 'Escape error'
            endif

            let l:arg .= l:script[i]
            let l:i += 1
        elseif l:script[i] == '#'
            " Comment.
            break
        elseif l:script[l:i] != ' '
            let l:arg .= l:script[l:i]
            let l:i += 1
        else
            " Space.
            if l:arg != ''
                call add(l:args, l:arg)
            endif

            let l:arg = ''

            let l:i += 1
        endif
    endwhile

    if l:arg != ''
        call add(l:args, l:arg)
    endif

    return l:args
endfunction"}}}

" Parse helper.
function! s:parse_block(script)"{{{
    let l:script = ''

    let l:i = 0
    let l:max = len(a:script)
    while l:i < l:max
        if a:script[l:i] == '{'
            " Block.
            let l:head = matchstr(a:script[: l:i-1], '[^[:blank:]]*$')
            " Trunk l:script.
            let l:script = l:script[: -len(l:head)-1]
            let l:block = matchstr(a:script, '{\zs.*[^\\]\ze}', l:i)
            if l:block == ''
                throw 'Block error'
            elseif l:block =~ '^\d\+\.\.\d\+$'
                " Range block.
                let l:start = matchstr(l:block, '^\d\+')
                let l:end = matchstr(l:block, '\d\+$')
                let l:zero = len(matchstr(l:block, '^0\+'))
                let l:pattern = '%0' . l:zero . 'd'
                for l:b in range(l:start, l:end)
                    " Concat.
                    let l:script .= l:head . printf(l:pattern, l:b) . ' '
                endfor
            else
                " Normal block.
                for l:b in split(l:block, ',', 1)
                    " Concat.
                    let l:script .= l:head . escape(l:b, ' ') . ' '
                endfor
            endif
            let l:i = matchend(a:script, '{.*[^\\]}', l:i)
        else
            let [l:script, l:i] = s:skip_else(l:script, a:script, l:i)
        endif
    endwhile

    return l:script
endfunction"}}}
function! s:parse_tilde(script)"{{{
    let l:script = ''

    let l:i = 0
    let l:max = len(a:script)
    while l:i < l:max
        if a:script[i] == ' ' && a:script[i+1] == '~'
            " Tilde.
            " Expand home directory.
            let l:script .= ' ' . escape($HOME, '\ ')
            let l:i += 2
        else
            let [l:script, l:i] = s:skip_else(l:script, a:script, l:i)
        endif
    endwhile

    return l:script
endfunction"}}}
function! s:parse_equal(script)"{{{
    let l:script = ''

    let l:i = 0
    let l:max = len(a:script)
    while l:i < l:max - 1
        if a:script[i] == ' ' && a:script[i+1] == '='
            " Expand filename.
            let l:prog = matchstr(a:script, '^=\zs[^[:blank:]]*', l:i+1)
            if l:prog == ''
                let [l:script, l:i] = s:skip_else(l:script, a:script, l:i)
            else
                let l:filename = vimshell#getfilename(l:prog)
                if l:filename == ''
                    throw printf('File: "%s" is not found.', l:prog)
                else
                    let l:script .= l:filename
                endif

                let l:i += matchend(a:script, '^=[^[:blank:]]*', l:i+1)
            endif
        else
            let [l:script, l:i] = s:skip_else(l:script, a:script, l:i)
        endif
    endwhile

    return l:script
endfunction"}}}
function! s:parse_variables(script)"{{{
    let l:script = ''

    let l:i = 0
    let l:max = len(a:script)
    while l:i < l:max
        if a:script[l:i] == '$'
            " Eval variables.
            if match(a:script, '^$\l', l:i) >= 0
                let l:script .= string(eval(printf("b:vimshell_variables['%s']", matchstr(a:script, '^$\zs\l\w*', l:i))))
            elseif match(a:script, '^$$', l:i) >= 0
                let l:script .= string(eval(printf("b:vimshell_system_variables['%s']", matchstr(a:script, '^$$\zs\h\w*', l:i))))
            else
                let l:script .= string(eval(matchstr(a:script, '^$\h\w*', l:i)))
            endif
            let l:i = matchend(a:script, '^$$\?\h\w*', l:i)
        else
            let [l:script, l:i] = s:skip_else(l:script, a:script, l:i)
        endif
    endwhile

    return l:script
endfunction"}}}
function! s:parse_wildcard(script)"{{{
    let l:script = ''

    let l:i = 0
    let l:max = len(a:script)
    while l:i < l:max
        if a:script[l:i] == '[' || a:script[l:i] == '*' || a:script[l:i] == '?' || a:script[l:i :] =~ '^\\[()|]'
            " Wildcard.
            let l:head = matchstr(a:script[: l:i-1], '[^[:blank:]]*$')
            let l:wildcard = l:head . matchstr(a:script, '^[^[:blank:]]*', l:i)
            " Trunk l:script.
            let l:script = l:script[: -len(l:wildcard)+1]

            " Exclude wildcard.
            let l:exclude = matchstr(l:wildcard, '\~.*$')
            if l:exclude != ''
                " Trunk l:wildcard.
                let l:wildcard = l:wildcard[: len(l:wildcard)-len(l:exclude)-1]
            endif

            " Expand wildcard.
            let l:expanded = split(escape(glob(l:wildcard), ' '), '\n')
            let l:exclude_wilde = split(escape(glob(l:exclude[1:]), ' '), '\n')
            if !empty(l:exclude_wilde)
                let l:candidates = l:expanded
                let l:expanded = []
                for candidate in l:candidates
                    let l:found = 0

                    for ex in l:exclude_wilde
                        if candidate == ex
                            let l:found = 1
                            break
                        endif
                    endfor

                    if l:found == 0
                        call add(l:expanded, candidate)
                    endif
                endfor
            endif

            let l:script .= join(filter(l:expanded, 'v:val != "." && v:val != ".."'))
            let l:i = matchend(a:script, '^[^[:blank:]]*', l:i)
        else
            let [l:script, l:i] = s:skip_else(l:script, a:script, l:i)
        endif
    endwhile

    return l:script
endfunction"}}}
function! s:parse_redirection(script)"{{{
    let l:script = ''
    let l:fd = { 'stdin' : '', 'stdout' : '', 'stderr' : '' }

    let l:i = 0
    let l:max = len(a:script)
    while l:i < l:max
        if a:script[l:i] == '<'
            " Input redirection.
            let l:fd.stdin = matchstr(a:script, '<\s*\zs\f*', l:i)
            let l:i = matchend(a:script, '<\s*\zs\f*', l:i)
        elseif a:script[l:i] == '>'
            " Output redirection.
            if a:script[l:i :] =~ '^>&'
                let l:fd.stderr = matchstr(a:script, '>&\s*\zs\f*', l:i)
                let l:i = matchend(a:script, '>&\s*\zs\f*', l:i)
            elseif a:script[l:i :] =~ '^>>'
                let l:fd.stdout = '>' . matchstr(a:script, '>>\s*\zs\f*', l:i)
                let l:i = matchend(a:script, '>>\s*\zs\f*', l:i)
            else
                let l:fd.stdout = matchstr(a:script, '>\s*\zs\f*', l:i)
                let l:i = matchend(a:script, '>\s*\zs\f*', l:i)
            endif
        else
            let [l:script, l:i] = s:skip_else(l:script, a:script, l:i)
        endif
    endwhile

    return [l:fd, l:script]
endfunction"}}}
function! s:parse_pipe(script)"{{{
    let l:script = ''

    let l:i = 0
    let l:max = len(a:script)
    while l:i < l:max
        if a:script[l:i] == '|'
            " Pipe.
            let l:script .= ' | '
            let l:i += 1
        else
            let [l:script, l:i] = s:skip_else(l:script, a:script, l:i)
        endif
    endwhile

    return l:script
endfunction"}}}

" Skip helper.
function! s:skip_quote(script, i)"{{{
    let l:end = matchend(a:script, "^'[^']*'", a:i)
    if l:end == -1
        throw 'Quote error'
    endif
    return [matchstr(a:script, "^'[^']*'", a:i), l:end]
endfunction"}}}
function! s:skip_double_quote(script, i)"{{{
    let l:end = matchend(a:script, '^"\%([^"]\|\"\)*"', a:i)
    if l:end == -1
        throw 'Quote error'
    endif
    return [matchstr(a:script, '^"\%([^"]\|\"\)*"', a:i), l:end]
endfunction"}}}
function! s:skip_back_quote(script, i)"{{{
    let l:end = matchend(a:script, '^`[^`]*`', a:i)
    if l:end == -1
        throw 'Quote error'
    endif
    return [matchstr(a:script, '^`[^`]*`', a:i), l:end]
endfunction"}}}
function! s:skip_else(args, script, i)"{{{
    if a:script[a:i] == "'"
        " Single quote.
        let [l:string, l:i] = s:skip_quote(a:script, a:i)
        let l:script = a:args . l:string
    elseif a:script[a:i] == '"'
        " Double quote.
        let [l:string, l:i] = s:skip_double_quote(a:script, a:i)
        let l:script = a:args . l:string
    elseif a:script[a:i] == '`'
        " Back quote.
        let [l:string, l:i] = s:skip_back_quote(a:script, a:i)
        let l:script = a:args . l:string
    elseif a:script[a:i] == '\'
        " Escape.
        let l:script = a:args . '\' . a:script[a:i+1]
        let l:i = a:i + 2
    else
        let l:script = a:args . a:script[a:i]
        let l:i = a:i + 1
    endif

    return [l:script, l:i]
endfunction"}}}

" vim: foldmethod=marker
