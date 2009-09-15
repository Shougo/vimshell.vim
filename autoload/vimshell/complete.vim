"=============================================================================
" FILE: complete.vim
" AUTHOR: Shougo Matsushita <Shougo.Matsu@gmail.com>(Modified)
" Last Modified: 13 Sep 2009
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

function! vimshell#complete#history_complete(findstart, base)"{{{
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
function! vimshell#complete#insert_command_completion()"{{{
    let &iminsert = 0
    let &imsearch = 0

    let l:save_ve = &l:virtualedit
    setlocal virtualedit=all
    let l:cur_text = substitute(getline('.')[: virtcol('.')-1], '^' . g:VimShell_Prompt . '\s*', '', '')
    let &l:virtualedit = l:save_ve
    if l:cur_text =~ '^.\+/\|^[^\\]\+\s'
        " Filename completion.
        if exists(':NeoComplCacheDisable') && exists('*neocomplcache#manual_filename_complete')
            return neocomplcache#manual_filename_complete()
        else
            return "\<C-x>\<C-f>"
        endif
    endif

    " Command completion.

    " Set complete function.
    let &l:omnifunc = 'vimshell#complete#smart_omni_completion'

    if exists(':NeoComplCacheDisable') && exists('*neocomplcache#manual_omni_complete')
        return neocomplcache#manual_omni_complete()
    else
        return "\<C-x>\<C-o>\<C-p>"
    endif
endfunction"}}}
function! vimshell#complete#smart_omni_completion(findstart, base)"{{{
    if a:findstart
        " Get cursor word.
        let l:save_ve = &l:virtualedit
        setlocal virtualedit=all
        let l:cur_text = getline('.')[: virtcol('.')-1]
        let &l:virtualedit = l:save_ve

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

    " Restore option.
    let &l:omnifunc = 'vimshell#complete#history_complete'

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

    if len(a:cur_keyword_str) >= 2
        " External commands.
        if has('win32') || has('win64')
            let l:path = substitute($PATH, '\\\?;', ',', 'g')
        else
            let l:path = substitute($PATH, '/\?:', ',', 'g')
        endif

        for keyword in map(filter(split(globpath(l:path, a:cur_keyword_str . '*'), '\n'),
                    \'executable(v:val)'), 'fnamemodify(v:val, ":t")')
            let l:dict = { 'word' : keyword, 'abbr' : keyword, 'menu' : '[Command]', 'icase' : 1, 'rank' : 5 }
            call add(l:ret, l:dict)
        endfor 
    endif

    return sort(l:ret, 's:compare_rank')
endfunction"}}}

function! s:compare_rank(i1, i2)"{{{
    return a:i1.rank < a:i2.rank ? 1 : a:i1.rank == a:i2.rank ? 0 : -1
endfunction"}}}

" vim: foldmethod=marker
