"=============================================================================
" FILE: parser.vim
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
"=============================================================================

function! vimshell#parser#eval_script(script, program)
    let l:script = a:script
    let l:program = a:program

    " Check alias."{{{
    if has_key(b:vimshell_alias_table, l:program) && !empty(b:vimshell_alias_table[l:program])
        let l:alias = split(b:vimshell_alias_table[l:program])

        let l:program = l:alias[0]
        let l:script = join(l:alias[1:]) . '' . l:script
    endif"}}}

    if has_key(g:vimshell#special_func_table, l:program)
        " Special commands.
        let l:fd = { 'stdin' : '', 'stdout' : '', 'stderr' : '' }
        let l:args = split(l:script)
    else
        if l:script =~ '[|]'
            let l:script = s:convert_pipe(l:script)
        endif
        if l:script =~ '[<>]'
            let [l:fd, l:script] = s:get_redirection(l:script)
        else
            let l:fd = { 'stdin' : '', 'stdout' : '', 'stderr' : '' }
        endif
        let l:args = s:get_args(l:script)
    endif

    if l:fd.stdout != ''
        if l:fd.stdout =~ '^>'
            let l:fd.stdout = l:fd.stdout[1:]
        elseif l:fd.stdout != '/dev/null'
            " Open file.
            call writefile([], l:fd.stdout)
        endif
    endif

    if l:program == '' && l:fd.stdin != ''
        " Echo file.
        let l:program = 'cat'
    endif

    return [l:program, l:args, l:fd]
endfunction

function! s:convert_pipe(string)"{{{
    let l:i = 0
    let l:string = ''
    let l:max = len(a:string)
    while l:i <= l:max
        if a:string[l:i] == '|'
            let l:string .= ' | '
            let l:i += 1
        elseif a:string[l:i] == "'"
            " Single quote.
            let l:end = matchend(a:string, "'\\zs[^']*'", l:i)
            if l:end == -1
                throw 'Quote error.'
            endif
            let l:string .= a:string[l:i : l:end-1]
            let l:i = l:end
        elseif a:string[l:i] == '"'
            " Double quote.
            let l:end = matchend(a:string, '"\zs\%([^"]\|\"\)*"', l:i)
            if l:end == -1
                throw 'Quote error.'
            endif
            let l:string .= substitute(a:string[l:i : l:end-1], '\\"', '"', 'g')
            let l:i = l:end
        elseif a:string[l:i] == '`'
            " Back quote.
            if a:string[l:i :] =~ '`='
                let l:quote = matchstr(a:string, '^`=\zs[^`]*\ze`', l:i)
                let l:end = matchend(a:string, '^`=[^`]*`', l:i)
            else
                let l:quote = matchstr(a:string, '^`\zs[^`]*\ze`', l:i)
                let l:end = matchend(a:string, '^`[^`]*`', l:i)
            endif
            let l:string .= a:string[l:i : l:end-1]
            let l:i = l:end
        elseif a:string[i] == '\'
            " Escape.
            let l:string .= a:string[i]
            let l:i += 1

            if l:i <= l:max
                let l:string .= a:string[i]
                let l:i += 1
            endif
        else
            let l:string .= a:string[i]
            let l:i += 1
        endif
    endwhile

    return l:string
endfunction"}}}

function! s:get_redirection(string)"{{{
    let l:i = 0
    let l:string = a:string
    let l:max = len(l:string)
    let l:fd = { 'stdin' : '', 'stdout' : '', 'stderr' : '' }
    while l:i <= l:max
        if l:string[l:i] == "'"
            let l:end = matchend(l:string, "'\\zs[^']*'", l:i)
            if l:end == -1
                throw 'Quote error.'
            endif
            let l:i = l:end
        elseif l:string[l:i] == '"'
            let l:end = matchend(l:string, '"\zs[^"]*"', l:i)
            if l:end == -1
                throw 'Quote error.'
            endif
            let l:i = l:end
        elseif l:string[l:i] == '<'
            let l:fd.stdin = matchstr(l:string, '<\s*\zs\f*', l:i)
            let l:end = matchend(l:string, '<\s*\zs\f*', l:i)

            let l:string = l:string[: l:i-1] . l:string[l:end :]
            let l:i = l:end
        elseif l:string[l:i] == '>'
            if l:string[l:i :] =~ '^>&'
                let l:fd.stderr = matchstr(l:string, '>&\s*\zs\f*', l:i)
                let l:end = matchend(l:string, '>&\s*\zs\f*', l:i)
            elseif l:string[l:i :] =~ '^>>'
                let l:fd.stdout = '>' . matchstr(l:string, '>>\s*\zs\f*', l:i)
                let l:end = matchend(l:string, '>>\s*\zs\f*', l:i)
            else
                let l:fd.stdout = matchstr(l:string, '>\s*\zs\f*', l:i)
                let l:end = matchend(l:string, '>\s*\zs\f*', l:i)
            endif
            let l:string = l:string[: l:i-1] . l:string[l:end :]
            let l:i = l:end
        else
            let l:i += 1
        endif
    endwhile

    return [l:fd, l:string]
endfunction"}}}

function! s:get_args(string)"{{{
    let l:i = 0
    let l:max = len(a:string)
    let l:list = []
    let l:arg = ''
    let l:arg = ''
    while l:i <= l:max
        if a:string[l:i] == "'"
            " Single quote.
            let l:end = matchend(a:string, "'\\zs[^']*'", l:i)
            if l:end == -1
                throw 'Quote error.'
            endif
            let l:arg .= a:string[l:i+1 : l:end-2]
            let l:i = l:end
        elseif a:string[l:i] == '"'
            " Double quote.
            let l:end = matchend(a:string, '"\zs\%([^"]\|\"\)*"', l:i)
            if l:end == -1
                throw 'Quote error.'
            endif
            let l:arg .= substitute(a:string[l:i+1 : l:end-2], '\\"', '"', 'g')
            let l:i = l:end
        elseif a:string[l:i] == '`'
            " Back quote.
            if a:string[l:i :] =~ '`='
                let l:quote = matchstr(a:string, '^`=\zs[^`]*\ze`', l:i)
                let l:end = matchend(a:string, '^`=[^`]*`', l:i)
                let l:arg .= string(eval(l:quote))
            else
                let l:quote = matchstr(a:string, '^`\zs[^`]*\ze`', l:i)
                let l:end = matchend(a:string, '^`[^`]*`', l:i)
                let l:arg .= substitute(system(l:quote), '\n', ' ', 'g')
            endif
            let l:i = l:end
        elseif a:string[l:i] != ' '
            let l:arg .= a:string[l:i]
            let l:i += 1
        else
            let l:eval = s:eval_arg(l:arg)
            if !empty(l:eval)
                call extend(l:list, l:eval)
            endif
            let l:arg = ''

            let l:i += 1
        endif
    endwhile

    let l:eval = s:eval_arg(l:arg)
    if !empty(l:eval)
        call extend(l:list, l:eval)
    endif

    return l:list
endfunction"}}}

function! s:eval_arg(arg)"{{{
    let l:i = 0
    let l:string = ''
    let l:max = len(a:arg)
    let l:is_wildcard = 0
    while l:i <= l:max
        if a:arg[i] == '~' && i == 0
            " Expand home directory.
            let l:string .= $HOME
            let l:i += 1
        elseif a:arg[i] == '[' || a:arg[i] == '*' || a:arg[i] == '?' 
            let l:is_wildcard = 1
            let l:string .= a:arg[i]
            let l:i += 1
        elseif a:arg[i] == '$'
            " Eval variables.
            if a:arg =~ '^$\l'
                let l:string .= string(eval(printf("b:vimshell_variables['%s']", matchstr(a:arg, '^$\zs\l\w*', l:i))))
            elseif a:arg =~ '^$$\h'
                let l:string .= string(eval(printf("b:vimshell_system_variables['%s']", matchstr(a:arg, '^$$\zs\h\w*', l:i))))
            else
                let l:string .= string(eval(matchstr(a:arg, '^$\u\w*', l:i)))
            endif
            let l:i = matchend(a:arg, '^$$\?\h\w*', l:i)
        elseif a:arg[i] == '\'
            let l:i += 1

            if l:i <= l:max
                let l:string .= a:arg[i]
                let l:i += 1
            endif
        else
            let l:string .= a:arg[i]
            let l:i += 1
        endif
    endwhile

    if l:is_wildcard
        " Expand wildcard.
        return split(glob(l:string), '\n')
    elseif l:string == ''
        return []
    else
        return [l:string]
    endif
endfunction"}}}

" vim: foldmethod=marker
