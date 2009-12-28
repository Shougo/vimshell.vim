"=============================================================================
" FILE: args_complete.vim
" AUTHOR: Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 27 Dec 2009
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

" Initialize funcs table."{{{
let s:special_funcs = {}
for list in split(globpath(&runtimepath, 'autoload/vimshell/complete/special/*.vim'), '\n')
    let func_name = fnamemodify(list, ':t:r')
    let s:special_funcs[func_name] = 'vimshell#complete#special#' . func_name . '#'
endfor
let s:internal_funcs = {}
for list in split(globpath(&runtimepath, 'autoload/vimshell/complete/internal/*.vim'), '\n')
    let func_name = fnamemodify(list, ':t:r')
    let s:internal_funcs[func_name] = 'vimshell#complete#internal#' . func_name . '#'
endfor
let s:command_funcs = {}
for list in split(globpath(&runtimepath, 'autoload/vimshell/complete/command/*.vim'), '\n')
    let func_name = fnamemodify(list, ':t:r')
    let s:command_funcs[func_name] = 'vimshell#complete#command#' . func_name . '#'
endfor
unlet func_name
unlet list
"}}}
    
function! vimshell#complete#args_complete#complete()"{{{
    " Args completion.

    " Get command name.
    let l:args = vimshell#parser#split_args(vimshell#get_cur_text())
    if vimshell#get_cur_text() =~ '\s\+$'
        " Add blank argument.
        call add(l:args, '')
    endif
    let l:command = fnamemodify(l:args[0], ':t:r')
    
    " Save option.
    let l:ignorecase_save = &ignorecase

    " Complete.
    if g:VimShell_SmartCase && a:base =~ '\u'
        let &ignorecase = 0
    else
        let &ignorecase = g:VimShell_IgnoreCase
    endif

    " Get complete words.
    if has_key(s:special_funcs, l:command)
        let l:complete_words = call(s:special_funcs[l:command] . 'get_complete_words', [l:args[1:]])
    elseif has_key(s:internal_funcs, l:command)
        let l:complete_words = call(s:internal_funcs[l:command] . 'get_complete_words', [l:args[1:]])
    elseif has_key(s:command_funcs, l:command)
        let l:complete_words = call(s:command_funcs[l:command] . 'get_complete_words', [l:args[1:]])
    else
        let l:complete_words = vimshell#complete#helper#files(l:args[-1])
    endif
    
    " Restore option.
    let &ignorecase = l:ignorecase_save
    let &l:omnifunc = ''
    
    " Trunk many items.
    let s:complete_words = l:complete_words[: g:VimShell_MaxList-1]

    " Set complete function.
    let &l:omnifunc = 'vimshell#complete#args_complete#omnifunc'

    return "\<C-x>\<C-o>\<C-p>"
    if exists(':NeoComplCacheDisable') && exists('*neocomplcache#manual_omni_complete')
        return neocomplcache#manual_omni_complete()
    else
        return "\<C-x>\<C-o>\<C-p>"
    endif
endfunction"}}}

function! vimshell#complete#args_complete#omnifunc(findstart, base)"{{{
    if a:findstart
        " Get cursor word.
        return len(vimshell#get_prompt()) + match(vimshell#get_cur_text(), '\%(\f\|\\\s\)*$')
    endif

    return s:complete_words
endfunction"}}}

" vim: foldmethod=marker
