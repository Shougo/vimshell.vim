"=============================================================================
" FILE: command_complete.vim
" AUTHOR: Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 18 Nov 2009
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

function! vimshell#complete#command_complete#omnifunc(findstart, base)"{{{
    if a:findstart
        " Get cursor word.
        let l:cur_text = (col('.') < 2)? '' : getline('.')[: col('.')-2]

        return match(l:cur_text, '\%([[:alnum:]_+~-]\|\\[ ]\)*$')
    endif

    " Save option.
    let l:ignorecase_save = &ignorecase

    " Complete.
    if g:VimShell_SmartCase && a:base =~ '\u'
        let &ignorecase = 0
    else
        let &ignorecase = g:VimShell_IgnoreCase
    endif

    let l:complete_words = s:get_complete_commands(a:base)

    " Restore option.
    let &ignorecase = l:ignorecase_save
    let &l:omnifunc = ''

    return l:complete_words
endfunction"}}}

function! s:get_complete_commands(cur_keyword_str)"{{{
    let l:ret = []
    let l:pattern = printf('v:val =~ "^%s"', a:cur_keyword_str)

    let l:home_pattern = '^'.substitute($HOME, '\\', '/', 'g').'/'
    " Check dup.
    let l:check = {}
    for keyword in filter(split(substitute(globpath(&cdpath, a:cur_keyword_str . '*'), '\\', '/', 'g'), '\n'), 'isdirectory(v:val)')
        if !has_key(l:check, keyword)
            let l:check[keyword] = keyword
        endif
    endfor
    for keyword in values(l:check)
        if keyword !~ '/'
            let l:dict = { 'word' : './' . keyword, 'abbr' : keyword . '/', 'menu' : '[Dir]', 'icase' : 1, 'rank' : 6 }
        else
            let l:menu = '[CD]'
            if !filewritable(keyword)
                let l:menu .= ' [-]'
            endif

            " Substitute home path.
            let keyword = substitute(keyword, l:home_pattern, '\~/', '')
            let l:dict = { 'word' : keyword, 'abbr' : keyword . '/', 'menu' : l:menu, 'icase' : 1, 'rank' : 5 }
        endif
        call add(l:ret, l:dict)
    endfor

    for keyword in filter(keys(b:vimshell_alias_table), l:pattern)
        let l:dict = { 'word' : keyword, 'abbr' : keyword, 'icase' : 1, 'rank' : 5 }
        if len(b:vimshell_alias_table[keyword]) > 15
            let l:dict.menu = '[Alias] ' . printf("%s..%s", b:vimshell_alias_table[keyword][:8], b:vimshell_alias_table[keyword][-4:])
        else
            let l:dict.menu = '[Alias] ' . b:vimshell_alias_table[keyword]
        endif
        call add(l:ret, l:dict)
    endfor 

    for keyword in filter(keys(g:vimshell#special_func_table), l:pattern)
        let l:dict = { 'word' : keyword, 'abbr' : keyword, 'menu' : '[Special]', 'icase' : 1, 'rank' : 5 }
        call add(l:ret, l:dict)
    endfor 

    for keyword in filter(keys(g:vimshell#internal_func_table), l:pattern)
        let l:dict = { 'word' : keyword, 'abbr' : keyword, 'menu' : '[Internal]', 'icase' : 1, 'rank' : 5 }
        call add(l:ret, l:dict)
    endfor 

    if len(a:cur_keyword_str) >= 1
        " External commands.
        if has('win32') || has('win64')
            let l:path = substitute($PATH, '\\\?;', ',', 'g')
            let l:exts = escape(substitute($PATHEXT, ';', '\\|', 'g'), '.')
            let l:list = map(filter(split(globpath(l:path, a:cur_keyword_str . '*'), '\n'),
                        \'"." . fnamemodify(v:val, ":e") =~ '.string(l:exts)), 'fnamemodify(v:val, ":t")')
        else
            let l:path = substitute($PATH, '/\?:', ',', 'g')
            let l:list = map(filter(split(globpath(l:path, a:cur_keyword_str . '*'), '\n'),
                        \'executable(v:val)'), 'fnamemodify(v:val, ":t")')
        endif

        for keyword in l:list
            let l:dict = { 'word' : keyword, 'abbr' : keyword . '*', 'menu' : '[Command]', 'icase' : 1, 'rank' : 5 }
            call add(l:ret, l:dict)
        endfor 
    endif

    return sort(l:ret, 's:compare_rank')
endfunction"}}}

function! s:compare_rank(i1, i2)"{{{
    return a:i1.rank < a:i2.rank ? 1 : a:i1.rank == a:i2.rank ? 0 : -1
endfunction"}}}

" vim: foldmethod=marker
